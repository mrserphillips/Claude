from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_payment_types_include_black_money_and_ui_exposes_it():
    constants = read('shared/constants.lua')
    ui = read('web/app.js')
    assert 'black_money = true' in constants
    assert 'Black Money' in ui
    assert 'value="black_money"' in ui


def test_server_payment_bridge_handles_black_money_as_inventory_item():
    payments = read('server/payments.lua')
    assert "paymentType == 'black_money'" in payments
    assert "GetItemCount(source, 'black_money'" in payments
    assert "RemoveItem(source, 'black_money'" in payments
    assert "AddItem(source, 'black_money'" in payments


def test_npc_and_world_point_shops_use_payment_bridge():
    shops = read('server/shops.lua')
    points = read('server/point_actions.lua')
    assert 'MJC.Payments.take' in shops
    assert 'MJC.Payments.refund' in shops
    assert 'MJC.Payments.take' in points
    assert 'MJC.Payments.refund' in points
    assert 'MJC.Payments.give' in points


def test_infinite_black_money_shop_uses_ox_currency_item():
    shops = read('server/shops.lua')
    assert "paymentType == 'black_money' and 'black_money' or nil" in shops
    assert 'currency = currency' in shops


def test_black_money_item_is_validated_when_selected():
    shops = read('server/shops.lua')
    points = read('server/points.lua')
    assert "paymentType == 'black_money' and not itemExists('black_money')" in shops
    assert "point.config.paymentType == 'black_money'" in points
    assert "exports.ox_inventory:Items('black_money')" in points


def test_infinite_custom_view_never_reads_a_missing_business_inventory():
    shops = read('server/shops.lua')
    assert "local count\n            if not unlimited then" in shops
    assert "GetItemCount(inventory.id" in shops


def test_payment_bridge_loads_before_shop_actions():
    manifest = read('fxmanifest.lua')
    assert "'server/payments.lua'" in manifest
    assert manifest.index("'server/payments.lua'") < manifest.index("'server/point_actions.lua'")
    assert manifest.index("'server/payments.lua'") < manifest.index("'server/shops.lua'")
