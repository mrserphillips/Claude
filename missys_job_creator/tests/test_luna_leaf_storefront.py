from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def text(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_every_npc_shop_uses_custom_customer_storefront():
    lua = text('client/interactions.lua')
    block = lua.split('function MJC.Client.interactNpc(npc)', 1)[1].split('function MJC.Client.clearBusinessZones()', 1)[0]
    assert "return MJC.Client.openCustomerShop(shop.id)" in block
    assert "openInventory('shop'" not in block


def test_saved_shops_are_marked_custom_ui():
    lua = text('server/shops.lua')
    assert "local uiMode = 'custom'" in lua


def test_customer_payload_identifies_business_for_shop_theme():
    lua = text('server/shops.lua')
    view = lua.split('function S.businessView(source, id)', 1)[1].split('function S.purchaseBusiness', 1)[0]
    assert 'business_job = shop.business_job' in view


def test_luna_leaf_storefront_brand_and_theme_exist():
    html = text('web/index.html')
    css = text('web/styles.css')
    js = text('web/app.js')
    assert 'id="customerShopBrand"' in html
    assert 'id="customerShopKicker"' in html
    assert 'Luna Leaf' in js
    assert "whitewidow" in js
    assert "dataset.theme" in js
    assert '.shopShell[data-theme="luna"]' in css
    assert '.lunaLeafMark' in css
    assert '.shopPrice' in css
    assert '.shopStock' in css


def test_release_version_is_2_0_10():
    assert "version '2.0.11'" in text('fxmanifest.lua')


def test_world_point_shops_use_custom_customer_storefront():
    client = text('client/point_actions.lua')
    open_block = client.split('local function openPointShop(point, data)', 1)[1].split('local function openSellMenu', 1)[0]
    assert "SendNUIMessage({ action = 'openCustomerShop'" in open_block
    assert 'lib.registerContext' not in open_block
    assert 'lib.showContext' not in open_block


def test_world_point_shop_view_has_storefront_routing_fields():
    server = text('server/point_actions.lua')
    action = server.split('local function actionShop(source, point, player, payload)', 1)[1].split('local function actionSell', 1)[0]
    assert "source_type='point'" in action
    assert 'point_id=point.id' in action
    assert 'business_job=' in action
    assert 'stock_mode=' in action
    assert 'unlimited=' in action
    assert 'max_purchase_count=Config.MaxPurchaseCount' in action


def test_customer_storefront_can_purchase_world_point_items():
    js = text('web/app.js')
    lua = text('client/main.lua')
    assert "source_type==='point'?'purchasePointShop':'purchaseBusiness'" in js
    assert "RegisterNUICallback('purchasePointShop'" in lua
    assert "'missys_job_creator:server:usePoint'" in lua


def test_release_version_is_2_0_11():
    assert "version '2.0.11'" in text('fxmanifest.lua')
