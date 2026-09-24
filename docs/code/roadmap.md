---
status: active
---

# Code — Roadmap

## Working today (confirmed)

Movement (WASD/click), camera (orbit/zoom), knight+poring sprites, melee combat
(click-to-attack, targeting ring, damage numbers, health bars, armour), poring AI
(aggro/leash/return/death/respawn), player death+respawn with 5% EXP penalty,
Base leveling (classic RO 1–99 table), status points (STR/AGI/VIT/INT/DEX/LUK →
derived stats), hotbar + spell casting (AoE/heal, mana, 1s global cooldown).

## Deferred — sprite-related (later passes)

Attack/hurt/dying clips, poring walk/attack mapping, new monster art, animations.
Placeholder visuals only until then.

## Priority 1 — Complete combat math (Phase A) — DONE

Closed the data-only gap in `character_stats.gd` / `status_points.gd`. Confirmed
formulas (simple prototype defaults):

| Stat | Derived / role |
| --- | --- |
| DEX | accuracy `1·DEX`, contested 1-for-1 with evasion |
| AGI | evasion `1·AGI`, contested in the same roll as accuracy |
| LUK | crit chance `0.3·LUK` percent on a **landed** hit, damage ×1.5 |
| block | still 0 until shields exist |

- `MeleeCombat.take_damage` resolves through an injectable `CombatResolver` with
  a single RO-contested roll (`hit% = clamp(95 + acc + level modifier − evasion,
  5%, 95%)`): DEX and AGI both give 1 point and cancel 1-for-1, so equal
  investment sits at the classic 95% base. A failed roll reads `MISS` or
  `EVADED` (when evasion outscores accuracy); landed hits roll block (halving
  damage) then crit. Tests pin `dice` for each stage.
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

## Priority 3 — Skills & mana, hotbar first (Phase B) — DONE

- `Hotbar` (`scripts/components/hotbar.gd`, `docs/code/hotbar.md`) renders a
  centered 10-slot bar bound to the 1–0 keys; `hotbar_1`…`hotbar_0` actions live
  in `project.godot`. Empty slots are dimmed and click-through; keys always emit
  `slot_activated(index)`. Slots hold `SpellDefinition`s and a lock button
  (default locked) gates rearrangement, which moves/swaps spells between slots.
- `SpellDefinition` (`scripts/components/spell_definition.gd`,
  `docs/code/spells-mana.md`) is a data resource with POE-style tags
  (`AOE`/`HEAL`) and square icons (generated placeholders until art exists).
  Two spells ship: **AoE Blast** (`aoe_damage`: 25 dmg in a 4.0 radius, tag
  `AOE`) and **Heal** (`heal`: 25 health, tag `HEAL`).
- `SpellCaster` (`scripts/components/spell_caster.gd`) owns the spellbook, mana
  spend, tag-scaled power, and the shared **1s global cooldown**: any cast locks
  every spell for 1s, and a spell's own longer cooldown continues past it
  (`remaining = max(gcd, own)`) — drawn as a Ragnarok **pizza-slice shadow** with
  seconds remaining. Spells execute through `MeleeCombat.take_damage`, sharing
  aggro, popups, and EXP credit. `player.gd` binds slots 0/1 and wires
  `slot_activated` → `try_cast`.
- `tests/hotbar_test.gd` and `tests/spells_test.gd` (both green) cover layout,
  key/click/lock/rearrange semantics, damage + radius + EXP credit, mana, the
  global-cooldown matrix, and tag increases.

## Priority 4 — Inventory foundation (Phase C) — DONE

- `ItemDefinition` Resources define immutable ids, names, descriptions, and
  square icons. Three starter resources use regions of the supplied Raven
  Fantasy 64×64 sprite atlas.
- `Inventory` owns a 20-slot, one-item-per-slot bag. It emits one
  `inventory_changed` signal for a move/swap; its UI never edits the slot array.
- **I** toggles `InventoryUI`, which reuses a 5×4 grid of native drag-and-drop
  `InventorySlot` Controls. Dragging to an empty slot moves an item; dragging
  over a full one swaps them. Stacking, drops, equipment effects, and saves are
  deliberately deferred to follow-on item passes.

## Later (after A, D & B, sprite work allowed to expand)

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
| 2026-09-16 | Confirmed | RAISED the RO-contested hit-roll base from 80 to 95 (`hit% = clamp(95 + acc + level mod − evasion, 5, 95)`). Equal DEX/AGI investment now cancels to the 95% base (previously 80%); level curve unchanged (95 / 94.5 / 94 / 92% at par acc). | Owner's accuracy-base request. |
| 2026-09-16 | Confirmed | Combat resolves in a strict pipeline: stage-one accuracy (acc + level modifier, no evasion) → plain MISS on failure; then target evasion → block → crit. A blocked hit halves damage instead of negating it; MISS/EVADE/BLOCK popups. | Owner's combat-order brief. |
| 2026-09-16 | Confirmed | Monsters get a static definition level (no EXP gain) that shifts hit chance via a level curve: +0.5%/level below, −0.5%/level for the first two levels above, then −2%/level beyond (95 / 94.5 / 94 / 92% at par acc). | Owner's hit-chance brief. |
| 2026-09-16 | Confirmed | Fresh players start with all base stats at 0, zero unspent points, and the derived baseline loadout (20 ATK / 1.0 ASPD / 100 HP); levels grant +5 points. | Owner's correction to the starting stats. |
| 2026-09-16 | Confirmed | Phase D: data-driven `MonsterDefinition` resources drive per-instance stats/EXP/behavior/tint; `combat.stats` unifies with the root; tints live on `base_modulate`. | Phase D implementation. |
| 2026-09-16 | Confirmed | Phase A formulas: DEX `90 + 2·DEX` accuracy (5–95% clamp), AGI evasion subtracts, LUK `0.3·LUK` crit at ×1.5 on landed hits only, block stays 0. Resolver dice are injectable for tests. | Owner's stat-calculation choices. |
| 2026-09-16 | Confirmed | AGI rebalanced to RO values: evasion `1·AGI` (was `2·AGI`) and attack speed `+0.004`/point (was `+0.03`), matching RO's +1% dodge and `4·AGI/1000` delay reduction. | Owner's AGI balance pass. |
| 2026-09-16 | Confirmed | Attack speed ported to Ragnarok M: Eternal Love's square-root model (`stat_aspd = 156 − (√205 − √AGI)/7.15 + √(9.9999·AGI)·0.76`, hits/sec `= 50/(200 − stat_aspd)`), giving diminishing AGI returns (≈2.22× at 99 AGI) under the 480% panel cap. Evasion stays `1·AGI` — ET's own value. | Owner's choice after Eternal-Love research. |
| 2026-09-16 | Confirmed | Evasion reworked into RO's single contested accuracy roll: `hit% = clamp(80 + acc + level mod − evasion, 5, 95)`. DEX and AGI both give 1 point so they cancel 1-for-1 (equal investment ⇒ 80% base), replacing the old 90-base accuracy and flat post-hit dodge that made evaders feel overpowered. Failed rolls read MISS or EVADED (when evasion outscores accuracy). | Owner's AGI balance pass. |
| 2026-09-15 | Proposed | Prioritize combat-math completion, then monster diversity; sprite work deferred. | Owner's roadmap request. |
| 2026-09-15 | Proposed | Simple prototype-default formulas over faithful RO mechanics; one feature at a time. | Owner scope choice. |
| 2026-09-17 | Confirmed | Phase B opens with the hotbar shell: centered 10 slots (1–0), `hotbar_1`…`hotbar_0` actions, empty slots click-through + keys always emit `slot_activated`, filled slots interactive. | Hotbar implementation. |
| 2026-09-17 | Confirmed | Phase B spells: data-driven `SpellDefinition` with POE-style tags + square icons; `SpellCaster` executes AoE (25 dmg / 4.0 radius) and heal (25) through the melee pipeline with mana costs and a shared 1s global cooldown whose per-spell longer cooldowns continue past it. | Owner's Phase B spell brief. |
| 2026-09-17 | Confirmed | Hotbar slots hold spells and a lock button (default locked) gates drag-rearrangement while locked clicks cast; cooldowns render as a clockwise pizza-slice shadow with remaining seconds. | Owner's hotbar move/cooldown brief. |
| 2026-09-17 | Confirmed | Repaired seven stale integration tests that still addressed the pre-Phase-D `Monster`/`Monster2` world nodes (they hung before reaching any assertion); they now read `Poring`/`Poporing`. Poring stays passive, so `monster_diversity_test` expects `aggressive = false`. `aggro_test` remains a nav/timing flake. | Phase B verification caught the stale refs. |
| 2026-09-24 | Confirmed | Phase C begins with a 20-slot non-stacking inventory. Each item uses exactly one slot; native UI dragging moves to empty slots and swaps onto occupied slots. | Owner's inventory-first request. |
