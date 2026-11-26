"""Render the public result files from one baseline invocation, including incomplete runs."""
import hashlib
from html import escape
import json
from pathlib import Path
import zipfile

NAMES = {
    "full-upload": "本地全量上传", "incremental-upload": "本地增量上传",
    "full-pull": "本地全量拉取", "delta-pull": "本地增量拉取",
    "relations": "父子分类、多标签、共用小票与冷恢复", "shared-ledger": "共享账本与同名个人字典",
    "recovery": "回执重试、删除与游标", "mode-switch": "切换本地存储后重新启用 Cloud",
    "same-device-restore": "同设备重建、跨页与恢复", "compatibility": "跨版本双设备同步",
}


def render(directory, summary):
    rows, links = [], []
    for name, db in summary["databases"].items():
        identity = db.get("identity", {})
        environment = name + " " + str(identity.get("version", ""))
        if identity.get("session_timezone"):
            environment += " / " + identity["session_timezone"]
        if identity.get("schema_revision"):
            environment += " / " + identity["schema_revision"]
        for suite in db["suites"]:
            for case in suite["expected"]:
                path = directory / name / suite["suite"] / (case + ".json")
                if path.is_file():
                    doc = json.loads(path.read_text())
                    status = str(doc.get("status", "MISSING_STATUS"))
                    href = path.relative_to(directory).as_posix()
                    detail = f'<a href="{escape(href, quote=True)}">逐项记录</a>'
                    links.append(f"- [{environment} · {NAMES.get(case, case)}]({href})")
                else:
                    status, detail = "未生成", ""
                rows.append(f"<tr><td>{escape(environment)}</td><td>{escape(NAMES.get(case, case))}</td>"
                            f"<td>{escape(status)}</td><td>{detail}</td></tr>")
        if db.get("error"):
            rows.append(f"<tr><td>{escape(environment)}</td><td>环境或执行错误</td>"
                        f"<td>FAIL</td><td>见 summary.json</td></tr>")
        for suite in summary["selected"]:
            if not any(s["suite"] == suite for s in db["suites"]):
                rows.append(f"<tr><td>{escape(environment)}</td><td>{escape(suite)}</td>"
                            "<td>未执行</td><td>见 summary.json</td></tr>")
    identity = (f"App {summary['app_sha']} · Cloud {summary['cloud_sha']} · "
                f"套件 {summary['suite']} · 配置样本 {summary['transactions']:,} 笔 · 种子 {summary['seed']}")
    if summary["app_dirty"]:
        identity += " · App 工作区含未提交变更"
    if summary.get("provisioning_sha"):
        identity += " · 已有安装模拟的迁移代码 " + summary["provisioning_sha"]
    body = "".join(rows)
    (directory / "index.html").write_text(f"""<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>BeeCount 双向同步复测</title>
<style>body{{font:16px/1.65 system-ui,sans-serif;color:#202731;max-width:920px;margin:32px auto;padding:0 14px}}
table{{width:100%;border-collapse:collapse}}th,td{{text-align:left;border-bottom:1px solid #ddd;padding:.55em}}
code,p{{overflow-wrap:anywhere}}a{{color:#145c9c}}@media(max-width:550px){{th,td{{padding:.25em;font-size:14px}}}}</style>
<h1>BeeCount 双向同步复测</h1><p>{escape(identity)}</p>
<p>Flutter 宿主运行正式同步引擎，通过 HTTP 连接临时 Cloud。数据库、测试账号和附件目录均为本轮独立创建。
网页写接口和设备界面分开验收。本报告只记录已执行的场景。</p>
<table><thead><tr><th>Cloud 数据库</th><th>场景</th><th>结果</th><th>证据</th></tr></thead><tbody>{body}</tbody></table>
<p><a href="summary.json">版本、执行状态与时长</a> · <a href="SHA256SUMS">文件校验表</a></p></html>""")
    (directory / "README.md").write_text(
        "# BeeCount 双向同步复测\n\n" + identity + "\n\n解压后打开 index.html。"
        "单个 JSON 记录相应场景，summary.json 记录运行环境与退出状态。\n\n" + "\n".join(links) + "\n")
    files = sorted([directory / "index.html", directory / "README.md", *directory.rglob("*.json")])
    checks = "".join(f"{hashlib.sha256(f.read_bytes()).hexdigest()}  {f.relative_to(directory).as_posix()}\n"
                     for f in files)
    checksum = directory / "SHA256SUMS"
    checksum.write_text(checks)
    with zipfile.ZipFile(directory / "cloud-sync-results.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for f in [*files, checksum]:
            archive.write(f, f.relative_to(directory))
