from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_world_point_markets_offer_standalone_no_job():
    ui = read('web/app.js')
    assert 'Standalone / No Job' in ui
    assert 'pointJobOptions' in ui
    assert 'pointJobOptions(d.job_name,d.point_type,d.access?.mode)' in ui


def test_point_validation_allows_no_job_only_for_shop_and_sell():
    validation = read('shared/validation.lua')
    assert "pointType == 'shop' or pointType == 'sell'" in validation
    assert "jobName = ''" in validation
    assert "if jobName == '' and not playerOwnedStash then normalizedAccess.mode = 'public' end" in validation


def test_point_save_skips_qbx_job_requirement_for_standalone_market():
    points = read('server/points.lua')
    assert "point.job_name ~= '' and not exports.qbx_core:GetJob(point.job_name)" in points


def test_standalone_shop_can_link_business_separately():
    ui = read('web/app.js')
    actions = read('server/point_actions.lua')
    points = read('server/points.lua')
    assert 'name="market_business"' in ui
    assert "businessJob:fd.get('market_business')" in ui
    assert 'config.businessJob or point.job_name' in actions
    assert 'point.config.businessJob' in points


def test_standalone_market_label_is_clear_in_list():
    ui = read('web/app.js')
    assert "r.job_name||'Standalone'" in ui

def test_standalone_market_ui_forces_public_access_and_reacts_to_job_change():
    ui = read('web/app.js')
    assert "const standaloneMarket=['shop','sell'].includes(d.point_type)&&!d.job_name" in ui
    assert "standaloneMarket?'<option value=\"public\" selected>Public</option>'" in ui
    assert "['point_type','presentation_type','job_name','access_mode'].includes(e.target.name)" in ui
