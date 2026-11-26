"""Run the baseline's private Cloud process with its actual database identity."""
import argparse
import os
from pathlib import Path
import resource
import sys


def main():
    from src.config import get_settings

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("migrate", "serve"))
    parser.add_argument("--fd", type=int)
    args = parser.parse_args()
    root = Path.cwd().resolve()
    settings = get_settings()
    expected = os.environ["DATABASE_URL"]
    if settings.database_url != expected or not (
        expected == "sqlite:///" + str(root / "qa.db")
        or expected == f"postgresql+psycopg://qa@/qa_sync?host={root / 'socket'}"
    ):
        raise ValueError("Cloud database is outside the isolated run")
    for key in ("attachment_storage_dir", "backup_storage_dir", "backup_staging_dir",
                "restore_dir", "rclone_config_path", "rag_index_cache_dir", "web_static_dir"):
        if root not in Path(getattr(settings, key)).resolve().parents:
            raise ValueError(f"Cloud storage is outside the isolated run: {key}")
    if args.mode == "migrate":
        from alembic import command
        from alembic.config import Config

        source = Path(os.environ["PYTHONPATH"])
        config = Config(str(source / "alembic.ini"))
        config.set_main_option("script_location", str(source / "alembic"))
        command.upgrade(config, "head")
        return

    import uvicorn
    from fastapi.routing import APIRoute
    from sqlalchemy import text
    from src.database import engine
    from src.main import app

    with engine.connect() as connection:
        dialect = engine.dialect.name
        if dialect == "postgresql":
            database, timezone, version = connection.execute(text(
                "SELECT current_database(), current_setting('TimeZone'), current_setting('server_version')"
            )).one()
            if database != "qa_sync" or timezone != "Asia/Shanghai":
                raise ValueError("PostgreSQL database or time zone differs from the run configuration")
        else:
            filename = connection.execute(text("PRAGMA database_list")).first()[2]
            if Path(filename).resolve() != root / "qa.db":
                raise ValueError("Unexpected SQLite file")
            version = connection.scalar(text("SELECT sqlite_version()"))
            timezone = None
    metadata = {"run_id": os.environ["QA_RUN_ID"], "cloud_sha": os.environ["QA_CLOUD_SHA"],
                "database_is_isolated": True, "database": dialect, "version": version,
                "session_timezone": timezone}

    async def identity():
        return metadata

    counts = {"requests": 0, "request_body_bytes": 0, "response_body_bytes": 0}

    async def traffic():
        rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        return {**counts, "cloud_peak_rss_bytes": rss if sys.platform == "darwin" else rss * 1024}

    app.router.routes.insert(0, APIRoute("/__qa__/identity", identity, methods=["GET"],
                                         include_in_schema=False))
    app.router.routes.insert(0, APIRoute("/__qa__/traffic", traffic, methods=["GET"], include_in_schema=False))

    async def measured(scope, receive, send):
        if scope["type"] != "http" or not scope["path"].startswith("/api/"):
            return await app(scope, receive, send)
        counts["requests"] += 1

        async def read():
            message = await receive()
            counts["request_body_bytes"] += len(message.get("body", b""))
            return message

        async def write(message):
            counts["response_body_bytes"] += len(message.get("body", b""))
            await send(message)

        await app(scope, read, write)

    uvicorn.run(measured, fd=args.fd, access_log=False)


if __name__ == "__main__":
    main()
