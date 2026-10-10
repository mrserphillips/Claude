from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def read(path): return (ROOT/path).read_text(encoding='utf-8')

def test_point_actions_are_server_authoritative():
    p = ROOT/'server'/'point_actions.lua'
    assert p.exists()
    text = p.read_text(encoding='utf-8')
    assert 'MJC.Points.canUse' in text
    assert 'exports.ox_inventory:Search' in text
    assert 'exports.ox_inventory:RemoveItem' in text
    assert 'exports.ox_inventory:AddItem' in text
    assert 'cooldowns' in text
    assert 'payload.price' not in text
    for action in ['stash','boss','duty','wardrobe','outfit','crafting','shop','sell','harvest','process','teleport','garage']:
        assert action in text

def test_point_actions_validate_public_vs_job_access():
    validation = read('shared/validation.lua')
    points = read('server/points.lua')
    assert "local normalizedMode = rawAccess.mode == 'public' and 'public' or 'job'" in validation
    assert "access.mode ~= 'public'" in points

def test_boss_and_duty_use_qbox_integrations():
    server = read('server/point_actions.lua')
    client = read('client/point_actions.lua') if (ROOT/'client'/'point_actions.lua').exists() else ''
    assert 'SetJobDuty' in server
    assert "OpenBossMenu('job')" in client

def test_server_registers_world_point_action_callback():
    main = read('server/main.lua')
    manifest = read('fxmanifest.lua')
    assert 'missys_job_creator:server:usePoint' in main
    assert "'server/point_actions.lua'" in manifest
    assert "'client/point_actions.lua'" in manifest
