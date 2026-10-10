from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVENUE = (ROOT / 'server' / 'revenue.lua').read_text(encoding='utf-8')
CONFIG = (ROOT / 'config.lua').read_text(encoding='utf-8')
INTEGRATIONS = (ROOT / 'server' / 'integrations.lua').read_text(encoding='utf-8')
SELFTEST = (ROOT / 'server' / 'selftest.lua').read_text(encoding='utf-8')


def test_lation_provider_is_configured_for_society_banking():
    assert "provider = 'lation'" in CONFIG


def test_lation_banking_receives_society_sales_by_job_name():
    assert "GetResourceState('lation_banking')" in REVENUE
    assert "exports['lation_banking']:AddAccountMoney" in REVENUE
    assert "targetAccount, amount, depositReason" in REVENUE
    assert "addJobBalance" not in REVENUE
    assert "exports['sky_base']" not in REVENUE
    assert "exports['Renewed-Banking']" not in REVENUE


def test_lation_failure_does_not_fall_back_to_creator_ledger():
    assert "Revenue provider is set to lation but lation_banking is not started." in REVENUE
    assert "if provider == 'lation' then return false end" in REVENUE


def test_integrations_and_selftest_report_lation_banking():
    assert "resource='lation_banking'" in INTEGRATIONS
    assert "adapter='Lation Banking'" in INTEGRATIONS
    assert "GetResourceState('lation_banking')" in SELFTEST
    assert "sky_base" not in INTEGRATIONS
    assert "sky_base" not in SELFTEST


def test_whitewidow_account_key_is_not_rewritten():
    assert "local targetAccount = (Config.Revenue.accountPrefix or '') .. account" in REVENUE
    assert "accountPrefix = ''" in CONFIG
