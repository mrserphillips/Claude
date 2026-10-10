from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JS = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')


def test_point_presentation_fields_are_editable():
    for token in ['name="interaction_text"', 'name="scenario"', 'name="marker_type"']:
        assert token in JS
    for token in [
        "interactionText:fd.get('interaction_text')",
        "scenario:fd.get('scenario')",
        "markerType:safeInt(fd.get('marker_type')",
    ]:
        assert token in JS
