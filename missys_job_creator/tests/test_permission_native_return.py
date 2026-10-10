from pathlib import Path

PERMS = Path('server/permissions.lua').read_text()


def test_ace_helper_accepts_boolean_and_numeric_success():
    assert 'result == true or result == 1' in PERMS


def test_ace_helper_normalizes_player_source_to_number():
    assert 'tonumber(source) or source' in PERMS


def test_permission_diagnostic_exposes_raw_ace_values():
    assert 'rawCustom=' in PERMS
    assert 'rawAdmin=' in PERMS
    assert 'rawGod=' in PERMS
