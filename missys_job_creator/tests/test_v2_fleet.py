from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def r(p): return (ROOT/p).read_text(encoding='utf-8')

def test_fleet_crud_and_leases_are_server_authoritative():
    p=ROOT/'server'/'fleet.lua'; assert p.exists(); t=p.read_text(encoding='utf-8')
    for token in ['F.save','F.delete','F.requestLease','F.releaseLease','activeLeases','MJC.Points.canUse','missys_job_creator_fleet']:
        assert token in t

def test_client_fleet_menu_spawns_and_returns_temporary_vehicle():
    p=ROOT/'client'/'fleet.lua'; assert p.exists(); t=p.read_text(encoding='utf-8')
    for token in ['MJC.Client.openFleet','CreateVehicle','SetPedIntoVehicle','returnFleet','requestFleet']:
        assert token in t

def test_fleet_callbacks_and_manifest_are_wired():
    main=r('server/main.lua'); fx=r('fxmanifest.lua')
    for token in ['saveFleet','deleteFleet','requestFleet','registerFleetVehicle','returnFleet']:
        assert token in main
    assert "'server/fleet.lua'" in fx and "'client/fleet.lua'" in fx
