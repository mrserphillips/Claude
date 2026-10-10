from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_production_ui_uses_native_nui_modal_not_browser_dialogs():
    app = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')
    index = (ROOT / 'web' / 'index.html').read_text(encoding='utf-8')
    assert 'window.confirm' not in app
    assert 'window.alert' not in app
    assert 'window.prompt' not in app
    assert 'id="confirmModal"' in index
    assert 'data-action="modalConfirm"' in index
    assert 'data-action="modalCancel"' in index


def test_v2_navigation_labels_are_present():
    index = (ROOT / 'web' / 'index.html').read_text(encoding='utf-8')
    for label in ('Jobs', 'World Points', 'NPCs', 'Businesses', 'Integrations'):
        assert label in index
