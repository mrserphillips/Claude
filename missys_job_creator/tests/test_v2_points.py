from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_all_approved_point_types_are_declared():
    path = ROOT / 'shared' / 'point_types.lua'
    assert path.exists()
    text = path.read_text(encoding='utf-8')
    for name in ('stash','boss','duty','wardrobe','outfit','crafting','shop','sell','harvest','process','teleport','garage'):
        assert name in text
    for presentation in ('target','marker','npc','prop'):
        assert presentation in text


def test_point_validator_normalizes_common_fields():
    text = (ROOT / 'shared' / 'validation.lua').read_text(encoding='utf-8')
    assert 'function V.point' in text
    for token in ('point_type', 'presentation_type', 'radius', 'minGrade', 'allowedGrades', 'duty'):
        assert token in text


def test_point_server_has_distance_grade_duty_and_hours_gates():
    path = ROOT / 'server' / 'points.lua'
    assert path.exists()
    text = path.read_text(encoding='utf-8')
    for token in ('GetPlayerPed', 'GetEntityCoords', 'minGrade', 'allowedGrades', 'duty', 'hours'):
        assert token in text
    assert 'function P.canUse' in text


def test_point_crud_is_admin_callback_backed_and_job_delete_counts_v2_dependencies():
    main = (ROOT / 'server' / 'main.lua').read_text(encoding='utf-8')
    jobs = (ROOT / 'server' / 'jobs.lua').read_text(encoding='utf-8')
    assert 'missys_job_creator:server:savePoint' in main
    assert 'missys_job_creator:server:deletePoint' in main
    for table in ('missys_job_creator_points', 'missys_job_creator_blips', 'missys_job_creator_fleet'):
        assert table in jobs
