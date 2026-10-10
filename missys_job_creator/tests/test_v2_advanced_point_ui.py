from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JS = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')


def test_point_editor_exposes_explicit_allowed_grades():
    assert 'name="allowed_grades"' in JS
    assert "allowedGrades:parseGradeList(fd.get('allowed_grades'))" in JS


def test_crafting_recipe_editor_exposes_duration():
    assert 'data-recipe="durationSeconds"' in JS
    assert "duration:Math.round(Number(r.querySelector('[data-recipe=\"durationSeconds\"]')" in JS
