from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_single_purchase_limit_is_200():
    config = read('config.lua')
    assert 'Config.MaxPurchaseCount = 200' in config


def test_customer_shop_receives_configured_purchase_limit():
    shops = read('server/shops.lua')
    ui = read('web/app.js')
    assert 'max_purchase_count = Config.MaxPurchaseCount' in shops
    assert 'shop.max_purchase_count' in ui
    assert 'max="20"' not in ui
    assert 'safeInt(input.value,1,20,1)' not in ui


def test_world_point_shop_uses_configured_purchase_limit_without_20_fallback():
    server = read('server/point_actions.lua')
    ui = read('web/app.js')
    assert 'max_purchase_count=Config.MaxPurchaseCount' in server
    assert 'purchaseLimit(ui.customerShop)' in ui
    assert 'Config.MaxPurchaseCount or 20' not in server
    assert 'safeInt(input.value,1,20,1)' not in ui
