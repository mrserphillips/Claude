from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p):return (ROOT/p).read_text(encoding='utf-8')

def test_v2_ui_has_workspace_filters_and_editors():
    html=r('web/index.html'); js=r('web/app.js'); css=r('web/styles.css')
    for label in ['Overview','Grades','Locations','Fleet','Blips','Settings','Export / Duplicate']:
        assert label in js
    for token in ['filterBar','searchInput','enabledFilter','jobFilter','typeFilter']:
        assert token in html or token in js
    for token in ['renderPointForm','renderFleetForm','renderBlipForm','renderIntegrations','renderJobWorkspace']:
        assert token in js
    assert '.workspaceSubnav' in css

def test_point_editor_exposes_all_action_types_and_in_world_placement():
    js=r('web/app.js')
    for action in ['stash','boss','duty','wardrobe','outfit','crafting','shop','sell','harvest','process','teleport','garage']:
        assert f"value=\"{action}\"" in js
    assert "post('placePoint'" in js
    assert 'pointPlacementResult' in js

def test_package_ui_and_callbacks_exist_without_native_dialogs():
    js=r('web/app.js'); client=r('client/main.lua')
    for token in ['duplicateJob','exportJob','previewImport','importJob','packageJson']:
        assert token in js or token in client
    for forbidden in ['window.confirm','window.alert','window.prompt']:
        assert forbidden not in js

def test_client_nui_wires_v2_crud():
    c=r('client/main.lua')
    for name in ['savePoint','deletePoint','saveBlip','deleteBlip','saveFleet','deleteFleet','exportJob','duplicateJob','previewImport','importJob']:
        assert f"RegisterNUICallback('{name}'" in c
