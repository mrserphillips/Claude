from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PERMS = (ROOT / 'server' / 'permissions.lua').read_text(encoding='utf-8')
CLIENT = (ROOT / 'client' / 'main.lua').read_text(encoding='utf-8')
CONFIG = (ROOT / 'config.lua').read_text(encoding='utf-8')


def test_txadmin_auth_event_is_tracked_server_side():
    assert "txAdmin:events:adminAuth" in PERMS
    assert "isTxAdmin" in PERMS


def test_txadmin_admin_is_an_authorized_fallback():
    assert "Config.AllowTxAdmin" in PERMS
    assert "MJC.Permissions.isTxAdmin(source)" in PERMS
    assert "Config.AllowTxAdmin = true" in CONFIG


def test_client_requests_txadmin_auth_before_retrying_denied_open():
    assert "txsv:checkIfAdmin" in CLIENT
    assert CLIENT.count("missys_job_creator:server:bootstrap") >= 2


def test_permission_diagnostic_reports_txadmin_state():
    assert "txadmin=" in PERMS


def test_jobcreator_command_allows_client_txadmin_reauth_before_bootstrap_gate():
    server = (ROOT / 'server' / 'main.lua').read_text(encoding='utf-8')
    start = server.index("RegisterCommand(Config.Command or 'jobcreator'")
    end = server.index("end, false)", start)
    command_block = server[start:end]

    # A freshly restarted resource has an empty txAdmin auth cache. The command
    # must reach the client so openAdmin() can request txAdmin auth and retry the
    # server-authoritative bootstrap callback.
    assert "MJC.Permissions.requireAdmin(source)" not in command_block
    assert "missys_job_creator:client:openCreator" in command_block

    # Security remains server-side: bootstrap itself must still deny callers
    # that do not pass the permission check after the retry.
    assert "if not MJC.Permissions.isAdmin(source) then return { admin = false } end" in server
