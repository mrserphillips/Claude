from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p):return (ROOT/p).read_text(encoding='utf-8')

def test_job_packages_are_versioned_and_exclude_live_economy():
    p=ROOT/'server'/'job_packages.lua'; assert p.exists(); t=p.read_text(encoding='utf-8')
    for token in ['PACKAGE_VERSION','P.export','P.duplicate','P.import','points','blips','fleet']:
        assert token in t
    for forbidden in ['business_ledger','balance =','societyBalance']:
        assert forbidden not in t

def test_import_refuses_existing_job_and_has_size_limit():
    t=r('server/job_packages.lua')
    assert 'Config.Packages.maxBytes' in t
    assert 'already exists' in t

def test_package_callbacks_and_manifest_are_wired():
    main=r('server/main.lua'); fx=r('fxmanifest.lua')
    for token in ['exportJob','duplicateJob','importJob']:
        assert token in main
    assert "'server/job_packages.lua'" in fx
