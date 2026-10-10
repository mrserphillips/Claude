from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def test_point_placement_reads_live_presentation_selector_and_sends_explicit_mode():
    js = read('web/app.js')
    assert "form.elements.presentation_type" in js
    assert "presentationType:" in js


def test_bootstrap_exposes_entity_presentation_defaults():
    server = read('server/main.lua')
    assert 'presentationDefaults' in server
    assert 'Config.DefaultPedModel' in server
    assert 'Config.Points.defaultProp' in server


def test_client_normalizes_entity_presentation_and_never_silently_falls_back():
    placement = read('client/placement.lua')
    assert 'normalizePresentationType' in placement
    assert "presentationType == 'npc'" in placement
    assert "presentationType == 'prop'" in placement
    assert 'Unsupported point presentation' in placement


def test_presentation_change_autofills_entity_model_defaults():
    js = read('web/app.js')
    assert 'applyPresentationDefaults' in js
    assert 'presentationDefaults' in js
