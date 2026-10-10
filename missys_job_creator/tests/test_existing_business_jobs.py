from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_shop_business_dropdown_includes_qbx_jobs():
    js = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')
    start = js.index('function businessOptions')
    business_fn = js[start:start + 700]
    assert 'availableJobs()' in business_fn, 'Linked business dropdown must include existing QBX jobs, not only creator business links.'


def test_shop_save_auto_links_existing_qbx_business_job():
    lua = (ROOT / 'server' / 'shops.lua').read_text(encoding='utf-8')
    assert 'MJC.Businesses.ensureLink' in lua, 'Shop save should auto-create a business link for a valid existing QBX job.'


def test_business_stock_npc_has_staff_restock_target():
    lua = (ROOT / 'client' / 'interactions.lua').read_text(encoding='utf-8')
    assert 'mjc_restock_' in lua and "openInventory('stash'" in lua, 'Business-stock NPC should give staff a direct restock target.'
