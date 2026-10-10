from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p):return (ROOT/p).read_text(encoding='utf-8')

def test_integrations_reports_required_and_optional_resources():
    p=ROOT/'server'/'integrations.lua'; assert p.exists(); t=p.read_text(encoding='utf-8')
    for token in ['qbx_core','ox_lib','ox_inventory','ox_target','oxmysql','qbx_management','lation_banking','illenium-appearance','fivem-appearance','GetResourceState']:
        assert token in t
    assert 'I.status' in t

def test_bootstrap_includes_integrations_and_manifest_wires_module():
    main=r('server/main.lua'); fx=r('fxmanifest.lua')
    assert 'integrations = MJC.Integrations.status()' in main
    assert "'server/integrations.lua'" in fx
