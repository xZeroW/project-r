---
status: confirmed
---

# Code — Spells & Mana (Phase B)

Phase B's skill layer. `SpellDefinition` resources describe spells; `SpellCaster`
owns the spellbook, the shared global cooldown, per-spell cooldowns, and mana
spend; the `Hotbar` binds spells to the 1–0 slots and the player wires slot
activation into casting. Everything reuses the existing `MeleeCombat` damage
pipeline, so spell hits share aggro, damage popups, armour, and EXP credit.

## Confirmed — Spell data (`SpellDefinition`)

`scripts/components/spell_definition.gd` is a `Resource` blueprint. Two spell
resources ship in `resources/spells/`:

| Resource | id | behavior | tags | power | radius | MP | own CD |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `aoe_damage.tres` | `aoe_damage` | `AREA_DAMAGE` | `AOE` | 25 | 4.0 | 10 | 3.0s |
| `heal.tres` | `heal` | `HEAL` | `HEAL` | 25 | — | 10 | 1.0s |

- `enum SpellTag { AOE, HEAL, FIRE }` and `enum Behavior { AREA_DAMAGE, HEAL }`. Tags
  are stored as `Array[int]` and drive POE-style increases: an increase keyed to
  a tag scales every spell carrying that tag.
- **Icons are square by contract.** `icon` is an optional `Texture2D`; when null
  `get_icon()` generates a 64×64 placeholder filled with `icon_color`, so the
  hotbar slot always has square art and can never distort a non-square texture.
- `hotbar_tooltip()` renders name, `MP · cd (tags)`, and the effect line.

## Confirmed — SpellCaster

`scripts/components/spell_caster.gd` (`SpellCaster`, a `Node`) is composed into
`scenes/player.tscn` (`%SpellCaster`). Exports `stats`, `combat`, `targeting`,
`body`, and the `spells` array; `combat` is mandatory — it is the attacker passed
to `take_damage`, which is what earns EXP and aggro.

### Mana and casting gate

`CharacterStats` already carried `mana` / `max_mana` (base 100, `+5·INT` via
`StatusPoints`); Phase B is the first consumer. `try_cast(spell)` denies in a
strict order, emitting `cast_denied(spell, reason)` with `&"unknown"`,
`&"global_cooldown"`, `&"cooldown"`, or `&"mana"`, then spends `mana_cost`,
executes, and starts cooldowns. `can_cast(spell)` mirrors the gate.

### Cooldown model (RO behavior)

- `GLOBAL_COOLDOWN = 1.0`. Any successful cast starts the global cooldown, so
  every spell enters it — casting one locks all of them for 1s.
- Each spell's own cooldown is `max(GLOBAL_COOLDOWN, spell.cooldown)`. A shorter
  spell (heal) clears with the global cooldown; a longer one (AoE, 3s) keeps
  running after the global cooldown has cleared.
- `get_cooldown_remaining(spell) = max(global remaining, own remaining)`;
  `get_cooldown_total(spell)` returns the spell's own (longer) duration while its
  own cooldown runs, otherwise `GLOBAL_COOLDOWN` — the denominator must match the
  timer actually driving the remaining time, so a spell locked only by the global
  cooldown sweeps a full rotation instead of drawing a fraction of its own
  longer cooldown. `cooldowns_changed` fires each `_process` tick so slices drain
  and clear.

### POE-style tag increases

Damaging spells first calculate `base_power = power + magic_attack *
magic_attack_coefficient`. The coefficient is authored per spell (default 1.0;
zero opts out), and INT derives the caster's MATK using the classic RO range
midpoint (see `status-points.md`). Healing uses `power` directly. Tooltips show
base damage and the MATK coefficient rather than presenting base damage as the
final result.

`add_increase(tag, percent)` accumulates a percentage per tag on that caster.
Skills can carry multiple tags. `get_total_power(spell)` sums all matching
increases, then calculates `base_power * max(0, 1 + total_increase/100)`.
These are additive **increased** bonuses, not multiplicative **more** modifiers.
Duplicate tags count once; tag order does not matter. Definition power is never
mutated, and bonuses on one caster do not affect another.

For example, simulated sources granting +20% fire, +10% fire, and +30% AoE give
a 25-power `AOE / FIRE` skill at zero MATK 40 damage (+60%). A fire-only skill receives +30%,
an AoE-only skill receives +30%, and an untagged skill receives neither bonus.
Pass the opposite percentage to undo a source's contribution. Items are not
implemented; tests inject these bonuses directly through `add_increase`.

Tags select **power** modifiers in this prototype: `HEAL` scales healing and
`AOE` scales power, not radius. `FIRE` is a matching tag, not an elemental damage
or resistance system. The two shipped skills retain their existing tags;
multi-tag fire skills are test fixtures.

### Effects

- `AREA_DAMAGE`: cast point is the selected target's body, else the caster's
  position. Every node in the `monsters` group within `radius` (horizontal
  distance; y ignored) takes a `DamageData` through `take_damage(data, combat)`.
- `HEAL`: restores `power` health up to `max_health`, emitting `healed(amount)`.

## Confirmed — Hotbar integration

- `player.gd` binds defaults in `_ready`: slot 0 → `&"aoe_damage"`, slot 1 →
  `&"heal"`. It connects `hotbar.slot_activated(index)` to a handler that calls
  `spell_caster.try_cast(hotbar.get_slot_spell(index))` when the slot is filled.
- Keys always report the slot; empty slots simply resolve to no spell.
- A plain click casts; holding Shift turns the click into rearrangement
  (pick/place/drag between slots) — see `docs/code/hotbar.md`. There is no lock
  button.
- Heal feedback: `DamageNumbers` connects `SpellCaster.healed(amount)` and pops
  a green `+N` floating number above the caster (same anchor/rise as damage
  numbers). It only wires up when the scene owns a `SpellCaster` at
  `caster_path` (`../SpellCaster`), so monster `DamageNumbers` nodes stay
  damage-only.
- Mana bar: the player's `HealthBarUI` (`scenes/player.tscn`) adds a blue
  `ManaBar` below the health bar (player-only — monsters have no `%ManaFill`).
  `HealthBarUI` tracks `mana`/`max_mana` through `stat_changed` and scales the
  fill like health via `BAR_FILL_WIDTH * ratio`.

## Verification

`tests/spells_test.gd` (green) pins: hotbar-key casting through the player
wiring, AoE radius (near monster damaged, far untouched), EXP credit on a spell
kill, mana spend, the 1s global cooldown denying re-casts, every spell entering
the global cooldown, the AoE's own 3s cooldown continuing after the global one
clears, the pie fraction, mana denial, and POE tag scaling. Simulated bonuses
cover multiple sources and tags, unmatched skills, duplicate/reordered tags,
caster isolation, bonus removal, nonnegative power, and actual scaled cast damage.
INT integration also covers real status allocation, per-skill MATK coefficients,
repeat recomputation, healing isolation, and a 66-damage cast from 25 base power,
30 MATK (20 INT), and +20% fire damage.

Because headless process-time pacing is erratic in this environment (real-time
timers can fire early), the cooldown/i-frame assertions drive
`SpellCaster._process(delta)` and `MeleeCombat._physics_process(delta)` with
explicit deltas — the same code each real frame runs — instead of sleeping.
`tests/hotbar_test.gd` (green) covers bindings, plain-click casting, and
Shift-click/Shift-drag rearrangement.

## Decision history

| Date | Status | Decision | Source |
| --- | --- | --- | --- |
| 2026-09-19 | Confirmed | Damaging spells add INT-derived MATK times a per-skill coefficient before matching tag increases; healing keeps separate power scaling. | Owner's approval of RO-style base magic attack plus PoE-style specialization. |
| 2026-09-19 | Confirmed | Multiple skill tags match caster-local percentage increases; matching increases add before scaling base power. Add FIRE support and verify simulated equipment bonuses without an item system. | Owner's skill-tag review and PoE-style fire-bonus request. |
| 2026-09-17 | Confirmed | Spells are data-driven `SpellDefinition` resources with POE-style tags; `SpellCaster` executes them through the melee pipeline. AoE (25 dmg / 4.0 radius) and heal (25) ship first. | Owner's Phase B spell brief. |
| 2026-09-17 | Confirmed | One 1s global cooldown on every cast; each spell's own longer cooldown continues past it (`remaining = max(gcd, own)`), shown as a Ragnarok pizza-slice shadow. | Owner's hotbar cooldown brief. |
| 2026-09-17 | Confirmed | Spells carry square icons (generated placeholders until art exists) and can be dragged between hotbar slots; a lock button (default locked) blocks rearrangement while still casting on click. | Owner's hotbar brief. |
| 2026-09-17 | Confirmed | The lock button is removed: Shift+click / Shift+drag rearranges spells; a plain click always casts. | Owner's "remove the lock, shift + click to move spells" request. |
| 2026-09-17 | Confirmed | The cooldown-pie denominator follows the timer actually running, so a spell locked only by the 1s global cooldown sweeps a full rotation (previously it drew gcd/own_cooldown, e.g. 1/3 for the AoE after casting heal). | Owner's bug report during playtesting. |
| 2026-09-17 | Confirmed | A blue mana bar sits below the player's health bar, driven by `stat_changed(mana/max_mana)`; monsters and other bar users without `%ManaFill` are unaffected. | Owner's "mana bar below the health" request. |
| 2026-09-17 | Confirmed | `GLOBAL_COOLDOWN = 1.0` (restored from an erroneous 1.5) so the 1s global timer, pies, and tests agree. | Consistency check during mana-bar verification. |
