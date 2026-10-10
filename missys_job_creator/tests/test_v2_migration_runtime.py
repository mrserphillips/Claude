from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = (ROOT / 'server' / 'main.lua').read_text(encoding='utf-8')


def test_legacy_boss_migration_runs_before_state_load():
    migration = MAIN.index('MJC.Migrations.legacyBossPoints()')
    load = MAIN.index('MJC.Persistence.loadAll()')
    assert migration < load
