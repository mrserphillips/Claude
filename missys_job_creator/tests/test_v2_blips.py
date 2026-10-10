from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p): return (ROOT/p).read_text(encoding='utf-8')

def test_blip_crud_and_client_visibility_exist():
    assert (ROOT/'server'/'blips.lua').exists()
    assert (ROOT/'client'/'blips.lua').exists()
    s=r('server/blips.lua'); c=r('client/blips.lua')
    for token in ['B.save','B.delete','missys_job_creator_blips','access_json']:
        assert token in s
    for token in ['AddBlipForCoord','SetBlipSprite','SetBlipColour','SetBlipScale','RemoveBlip','access.mode']:
        assert token in c

def test_blip_callbacks_and_manifest_are_wired():
    main=r('server/main.lua'); fx=r('fxmanifest.lua')
    assert 'saveBlip' in main and 'deleteBlip' in main
    assert "'server/blips.lua'" in fx and "'client/blips.lua'" in fx
