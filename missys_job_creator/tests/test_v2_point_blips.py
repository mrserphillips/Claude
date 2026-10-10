from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p): return (ROOT/p).read_text(encoding='utf-8')

def test_world_points_support_optional_inline_blips():
    client=r('client/points.lua'); ui=r('web/app.js')
    for token in ['pointBlips','AddBlipForCoord','RemoveBlip','point.blip']:
        assert token in client
    for token in ['point_blip_enabled','point_blip_sprite','point_blip_colour','point_blip_scale']:
        assert token in ui
