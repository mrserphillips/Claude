from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def test_job_name_reactive_rerender_is_scoped_to_point_forms():
    js = read('web/app.js')
    # Changing job_name in Jobs/Businesses must not be routed into the point draft.
    assert "form.dataset.kind==='point'" in js or 'form.dataset.kind === \'point\'' in js


def test_blank_point_entity_model_falls_back_to_defaults():
    points = read('client/points.lua')
    placement = read('client/placement.lua')
    # Empty NUI strings are truthy in Lua; production code must explicitly normalize them.
    assert "model ~= ''" in placement or "model == ''" in placement
    assert "model == ''" in points and 'Config.DefaultPedModel' in points
    assert "presentationType == 'prop' and (type(model) ~= 'string' or model == '')" in placement
