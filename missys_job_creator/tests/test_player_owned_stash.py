from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_stash_editor_supports_specific_player_owner():
    js = read('web/app.js')
    assert 'Specific Player' in js
    assert 'name="owner_citizenid"' in js
    assert "ownerCitizenId:fd.get('owner_citizenid')" in js
    assert "['point_type','presentation_type','job_name','access_mode']" in js


def test_player_owned_stash_can_be_saved_without_job_but_requires_owner():
    validation = read('shared/validation.lua')
    assert "pointType == 'stash' and rawAccessMode == 'player'" in validation
    assert "Owner Citizen ID is required for a player-owned stash." in validation
    assert "ownerCitizenId = ownerCitizenId" in validation


def test_server_checks_citizenid_for_player_owned_stash():
    points = read('server/points.lua')
    assert "access.mode == 'player'" in points
    assert 'player.PlayerData.citizenid' in points
    assert 'This stash belongs to another player.' in points


def test_player_owned_stash_is_registered_with_owner_and_hook_protection():
    actions = read('server/point_actions.lua')
    assert "access.mode == 'player'" in actions
    assert 'ownerCitizenId' in actions
    assert 'RegisterStash(stashId, point.label, slots, weight, ownerCitizenId' in actions
    assert "registerHook('openInventory'" in actions
    assert 'protectedPlayerStashOwner' in actions
    assert 'payload.inventoryId' in actions


def test_client_opens_specific_owner_stash_with_owner_context():
    client = read('client/point_actions.lua')
    assert "data.stashOwner" in client
    assert "{ id = data.stashId, owner = data.stashOwner }" in client


def test_release_is_v209():
    assert "version '2.0.11'" in read('fxmanifest.lua')
