from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


def test_business_stash_registers_every_valid_stock_access_coordinate():
    businesses = read('server/businesses.lua')
    assert 'function B.stockCoords(business)' in businesses
    assert 'shop.stock_mode == \'business\'' in businesses
    assert 'shop.business_job == business.job_name' in businesses
    assert 'MJC.State.npcs[tonumber(shop.npc_id)]' in businesses
    assert 'coords[#coords + 1] = vector3' in businesses
    assert 'local coords = B.stockCoords(business)' in businesses


def test_stock_open_re_registers_stash_on_server_before_client_open():
    businesses = read('server/businesses.lua')
    server_main = read('server/main.lua')
    client = read('client/interactions.lua')

    assert 'function B.prepareStock(source, businessJob)' in businesses
    assert "lib.callback.register('missys_job_creator:server:prepareBusinessStock'" in server_main
    assert 'MJC.Businesses.prepareStock(source, businessJob)' in server_main
    assert 'function MJC.Client.openBusinessStock(businessJob, fallbackStashId)' in client
    assert "lib.callback.await('missys_job_creator:server:prepareBusinessStock'" in client
    assert "exports.ox_inventory:openInventory('stash', stashId)" in client


def test_npc_and_dedicated_stock_targets_use_same_safe_open_path():
    client = read('client/interactions.lua')
    assert 'MJC.Client.openBusinessStock(shop.business_job, shop.stash_id)' in client
    assert 'MJC.Client.openBusinessStock(business.job_name, business.stash_id)' in client
    assert "onSelect = function() exports.ox_inventory:openInventory('stash', shop.stash_id) end" not in client
    assert "onSelect = function() exports.ox_inventory:openInventory('stash', business.stash_id) end" not in client
