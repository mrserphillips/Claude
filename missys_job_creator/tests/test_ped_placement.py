from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
placement = (ROOT / 'client' / 'placement.lua').read_text()
npcs = (ROOT / 'client' / 'npcs.lua').read_text()

# Placement and persistent spawn must use the exact selected Z coordinate.
assert 'z - 1.0' not in placement, 'placement still sinks preview ped by 1m'
assert 'tonumber(npc.z) - 1.0' not in npcs, 'persistent NPC spawn still sinks ped by 1m'

# A brand-new placement should be put visibly in front of the player.
assert 'GetOffsetFromEntityInWorldCoords' in placement, 'new NPC placement does not start in front of player'

# Failed ped creation must be surfaced rather than silently storing a zero handle.
assert 'ped == 0' in placement, 'placement does not handle CreatePed failure'
assert 'ped == 0' in npcs, 'persistent spawn does not handle CreatePed failure'

print('ped placement regression checks passed')
