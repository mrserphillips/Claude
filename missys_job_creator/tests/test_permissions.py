from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PERMS = (ROOT / 'server' / 'permissions.lua').read_text(encoding='utf-8')
CONFIG = (ROOT / 'config.lua').read_text(encoding='utf-8')


def test_qbox_admin_checks_admin_ace_object_not_group_principal():
    assert "hasAce(source, 'admin')" in PERMS
    assert "IsPlayerAceAllowed(source, 'group.admin')" not in PERMS


def test_custom_jobcreator_ace_remains_supported():
    assert 'Config.AdminAce' in PERMS
    assert "Config.AdminAce = 'missys.jobcreator'" in CONFIG


def test_permission_diagnostic_command_exists():
    assert "jobcreatorperm" in PERMS
    assert "GetPlayerIdentifiers" in PERMS
