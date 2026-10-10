from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
validation = (ROOT / 'shared' / 'validation.lua').read_text()
shops_server = (ROOT / 'server' / 'shops.lua').read_text()
businesses_server = (ROOT / 'server' / 'businesses.lua').read_text()
interactions_client = (ROOT / 'client' / 'interactions.lua').read_text()
npcs_server = (ROOT / 'server' / 'npcs.lua').read_text()


def test_enabled_helper_accepts_boolean_and_numeric_flags():
    assert 'function V.isEnabled(value)' in validation
    assert 'value == true' in validation
    assert 'tonumber(value) == 1' in validation


def test_business_shop_uses_tolerant_enabled_checks():
    critical = shops_server + businesses_server + interactions_client + npcs_server
    assert 'MJC.Validation.isEnabled' in critical
    assert '.enabled ~= 1' not in critical
    assert '.enabled == 1' not in critical
