# Lobby Upgrade 3-Axis Design

## Goal

Use three permanent tracks per tower:
- `identity`: reinforce the tower's fantasy/mechanic
- `operations`: improve convenience/economy
- `synergy`: improve combo value with other towers/effects

This is fully data-driven by JSON to allow easy balance edits without code rewrites.

## Files

- `assets/data/lobby_upgrades/config.json`
  - global caps, level cap, cost curve, track weights
- `assets/data/lobby_upgrades/presets_by_tower.json`
  - per-tower 3-axis modifier definitions
- `assets/data/lobby_upgrades/default_player_state.json`
  - player save shape for each tower track level

## Recommended Runtime Formula

For each applicable modifier:

```text
appliedValue = min(cap, perLevel * trackLevel)
```

Then combine with combat/tower base stats by key type:
- `_pct` keys: multiplicative bonus (e.g. `base * (1 + appliedValue)`)
- `_flat` keys: additive bonus
- boolean/threshold style keys: compare against accumulated value

## Suggested Integration Points

- Load definitions with `DefinitionRepository` style loader (new repository).
- Add lobby track levels to account save model (or separate save block).
- Apply resolved bonuses when creating `TowerRuntimeState` and when applying status effects.

## Balance Rules

- Keep strong effects capped (`config.json > modifierCaps`).
- Use diminishing feeling through higher shard cost at higher levels.
- Keep `identity` strongest, `operations` medium, `synergy` situational.

## Next Implementation Step

1. Add a `LobbyUpgradeRepository` to read new JSON files.
2. Extend account progress model with `playerLobbyUpgrades`.
3. Build a lobby UI panel for 3-axis level-up per tower.
4. Apply modifiers in `Tower._applyStatsFromState()` and effect application blocks.
