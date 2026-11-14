"""Locations for optional design tooling after the independent-repository split."""
import os
from pathlib import Path

APP_ROOT = Path(__file__).resolve().parents[2]


def design_root(app_root=APP_ROOT):
    """Return BeeCount-Design/card-refresh; App builds never call this helper."""
    explicit = os.environ.get('BEECOUNT_DESIGN_ROOT')
    return Path(explicit).expanduser().resolve() if explicit else Path(app_root).parent / 'BeeCount-Design/card-refresh'


def development_root(app_root=APP_ROOT):
    return Path(app_root) / '.docs/development'
