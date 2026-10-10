from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JS = (ROOT / 'web' / 'app.js').read_text(encoding='utf-8')


def test_contextual_npc_shop_keeps_v1_shop_controls():
    for token in [
        'Business + tax split',
        'Business staff',
        'name="access_job"',
        'name="business_percent"',
        'name="hours_enabled"',
        'name="hours_start"',
        'name="hours_finish"',
        'businessOptions(d.business_job)',
    ]:
        assert token in JS


def test_shop_payload_preserves_access_hours_and_split_percentage():
    for token in [
        "job:fd.get('access_job')",
        "enabled:fd.has('hours_enabled')",
        "start:safeInt(fd.get('hours_start')",
        "finish:safeInt(fd.get('hours_finish')",
        "businessPercent:safeInt(fd.get('business_percent')",
    ]:
        assert token in JS
