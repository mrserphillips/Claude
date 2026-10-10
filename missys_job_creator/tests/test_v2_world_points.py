from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf-8')

def test_client_world_point_renderer_supports_all_presentations():
    p=ROOT/'client'/'points.lua'; assert p.exists(); t=p.read_text(encoding='utf-8')
    for word in ['addSphereZone','CreatePed','CreateObject','DrawMarker','MJC.Client.usePoint','removeZone']:
        assert word in t
    assert 'Config.Points.streamDistance' in t

def test_placement_supports_point_mode_and_nui_callback():
    placement=read('client/placement.lua'); main=read('client/main.lua')
    assert 'startPointPlacement' in placement
    assert "RegisterNUICallback('placePoint'" in main
    assert "action = 'pointPlacementResult'" in main

def test_manifest_loads_points_renderer():
    assert "'client/points.lua'" in read('fxmanifest.lua')
