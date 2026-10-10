from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def r(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_manifest_and_readme_are_v2_release_ready():
    fx = r('fxmanifest.lua')
    readme = r('README.md')
    assert "version '2.0.11'" in fx
    assert "description 'In-city QBX job, world point, NPC and business creator'" in fx
    assert "# Missy's Job Creator v2" in readme
    for phrase in [
        'World Points',
        'AddAccountMoney',
        'Duplicate Job',
        'Import / Export',
        'Integrations',
        'legacy boss',
        'temporary job vehicles',
    ]:
        assert phrase.lower() in readme.lower()


def test_selftest_covers_v2_modules_and_key_optional_integrations():
    text = r('server/selftest.lua')
    for token in [
        'permissions module', 'state loaded', 'points module', 'point actions module',
        'blips module', 'fleet module', 'integrations module', 'qbx_management', 'lation_banking'
    ]:
        assert token in text
