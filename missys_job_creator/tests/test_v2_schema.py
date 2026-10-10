from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL = (ROOT / 'sql' / 'missys_job_creator.sql').read_text(encoding='utf-8')


def test_v2_schema_is_additive():
    for table in (
        'missys_job_creator_points',
        'missys_job_creator_blips',
        'missys_job_creator_fleet',
        'missys_job_creator_migrations',
    ):
        assert f'CREATE TABLE IF NOT EXISTS `{table}`' in SQL
    assert 'DROP TABLE' not in SQL.upper()
    assert 'TRUNCATE TABLE' not in SQL.upper()


def test_legacy_boss_migration_has_marker_and_is_idempotent():
    path = ROOT / 'server' / 'migrations.lua'
    assert path.exists()
    text = path.read_text(encoding='utf-8')
    assert 'legacy_boss_points_v2' in text
    assert 'INSERT IGNORE INTO missys_job_creator_migrations' in text
    assert 'SELECT migration_key FROM missys_job_creator_migrations' in text


def test_persistence_loads_v2_state_maps():
    text = (ROOT / 'server' / 'persistence.lua').read_text(encoding='utf-8')
    for key in ('points =', 'blips =', 'fleet ='):
        assert key in text
    for helper in ('findPoint', 'pointsForJob', 'fleetForJob', 'blipsForJob'):
        assert f'function P.{helper}' in text


def test_legacy_boss_runtime_registration_is_not_owned_by_jobs_module():
    text = (ROOT / 'server' / 'jobs.lua').read_text(encoding='utf-8')
    assert 'RegisterBossMenu' not in text
