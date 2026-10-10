from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / 'web' / 'state.js'
APP = ROOT / 'web' / 'app.js'


def node_eval(source: str):
    result = subprocess.run(['node', '--input-type=module', '-e', source], cwd=ROOT, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def test_sparse_state_rows_are_compacted_before_rendering():
    uri = STATE.resolve().as_uri()
    out = node_eval(f"""
        const m = await import('{uri}');
        const rows = m.compactRows({{0:null,1:{{id:2,label:'Market'}},2:null,3:{{id:9,label:'Garage'}}}});
        console.log(JSON.stringify(rows.map(r => r.id)));
    """)
    assert out == '[2,9]'


def test_rows_can_be_found_by_database_id_without_array_indexing():
    uri = STATE.resolve().as_uri()
    out = node_eval(f"""
        const m = await import('{uri}');
        const state = {{0:null,1:{{id:4,label:'Point 4'}},4:{{id:17,label:'Point 17'}}}};
        console.log(m.findRowById(state, 17)?.label || 'missing');
    """)
    assert out == 'Point 17'


def test_app_uses_sparse_safe_state_helpers():
    source = APP.read_text(encoding='utf-8')
    assert 'compactRows' in source
    assert 'findRowById' in source
    assert "ui.bootstrap.state[key]?.[Number(b.dataset.id)]" not in source
    assert "ui.bootstrap.state.shops?.[Number(b.dataset.id)]" not in source
