---
status: active
---

# Code — Roadmap

## Working today (confirmed)

Movement (WASD/click), camera (orbit/zoom), knight+poring sprites, melee combat
(click-to-attack, targeting ring, damage numbers, health bars, armour), poring AI
(aggro/leash/return/death/respawn), player death+respawn with 5% EXP penalty,
Base leveling (classic RO 1–99 table), status points (STR/AGI/VIT/INT/DEX/LUK →
derived stats).

## Deferred — sprite-related (later passes)

Attack/hurt/dying clips, poring walk/attack mapping, new monster art, animations.
Placeholder visuals only until then.

## Priority 1 — Complete combat math (Phase A) — DONE

Closed the data-only gap in `character_stats.gd` / `status_points.gd`. Confirmed
formulas (simple prototype defaults):

| Stat | Derived / role |
| --- | --- |
| DEX | accuracy `90 + 2·DEX` percent |
| AGI | evasion `2·AGI`, rolled as a dodge after the stage-one hit succeeds |
| LUK | crit chance `0.3·LUK` percent on a **landed** hit, damage ×1.5 |
| block | still 0 until shields exist |

- `MeleeCombat.take_damage` resolves through an injectable `CombatResolver` in a
  fixed pipeline: stage-one accuracy (`acc` + level modifier, no evasion) → plain
  `MISS` on failure; on success target evasion → block (halves damage) → crit.
  Tests pin `dice` for each stage.
- `damage_numbers.gd` shows Miss/Evade/Block popups and colors crits.
- `StatusUI`/derivation updated; `tests/combat_math_test.gd` adds coverage.
- NOTE: `prototype_test`, `aggro_test`, and `click_movement_test` fail
  identically on the pre-Phase-A baseline in this environment — pre-existing
  nav/camera timing flakes, unrelated to this pass. Verified 2026-09-16:
  the seven feature tests (`combat`, `targeting`, `status_points`,
  `experience`, `death_respawn`, `combat_math`, `monster_diversity`) all print
  `PASS` and exit cleanly; `prototype` / `click_movement` / `aggro` remain the
  flaky nav/camera checks.

## Priority 2 — Monster diversity (Phase D) — DONE

- New `MonsterDefinition` Resource
  (`scripts/components/monster_definition.gd`) carries name, stats (health,
  movement/attack speed, damage, armour, evasion, acc, crit, block), EXP
  reward, aggressive/aggro/leash/respawn, attack range/duration, and a tint.
- `monster.gd` reads one definition in `_ready`, filling its stats, combat
  reward, behavior fields, and tint; `combat.stats` is unified with the root
  stats resource. The tint lives on `MeleeCombat.base_modulate` so the damage
  flash restores it instead of erasing it.
- `scenes/world.tscn` hosts a weak **Poring** (white) and a stronger
  **Poporing** (green tint, higher HP/damage/EXP, wider aggro) defined in
  `resources/monsters/*.tres` — no new art.
- `tests/monster_diversity_test.gd` verifies per-instance definitions,
  independent stats/health, per-instance EXP (stacking into a level), distinct
  aggro radii, tints, and tint-preserving respawn.

## Later (after A & D, sprite work allowed to expand)

B. Skills & mana (hotbar, bolt+heal, mana costs)
C. Items, loot, inventory, equipment
E. World expansion + NPCs/shops
F. Job levels/class change
G. Save persistence

## Sequencing rule

One feature fully implemented, tested, and recorded before the next. Rework of
earlier systems is in scope when a later phase requires it.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-16 | Confirmed | Combat resolves in a strict pipeline: stage-one accuracy (acc + level modifier, no evasion) → plain MISS on failure; then target evasion → block → crit. A blocked hit halves damage instead of negating it; MISS/EVADE/BLOCK popups. | Owner's combat-order brief. |
| 2026-09-16 | Confirmed | Monsters get a static definition level (no EXP gain) that shifts hit chance via a level curve: +0.5%/level below, −0.5%/level for the first two levels above, then −2%/level beyond (95 / 94.5 / 94 / 92% at par acc). | Owner's hit-chance brief. |
| 2026-09-16 | Confirmed | Fresh players start with all base stats at 0, zero unspent points, and the derived baseline loadout (20 ATK / 1.0 ASPD / 100 HP); levels grant +5 points. | Owner's correction to the starting stats. |
| 2026-09-16 | Confirmed | Phase D: data-driven `MonsterDefinition` resources drive per-instance stats/EXP/behavior/tint; `combat.stats` unifies with the root; tints live on `base_modulate`. | Phase D implementation. |
| 2026-09-16 | Confirmed | Phase A formulas: DEX `90 + 2·DEX` accuracy (5–95% clamp), AGI evasion subtracts, LUK `0.3·LUK` crit at ×1.5 on landed hits only, block stays 0. Resolver dice are injectable for tests. | Owner's stat-calculation choices. |
| 2026-09-15 | Proposed | Prioritize combat-math completion, then monster diversity; sprite work deferred. | Owner's roadmap request. |
| 2026-09-15 | Proposed | Simple prototype-default formulas over faithful RO mechanics; one feature at a time. | Owner scope choice. |