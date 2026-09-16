class_name CombatResolver
extends RefCounted
## Rolls incoming-attack outcomes (accuracy, block, crit) for the shared melee
## component. The dice source is injectable so tests can drive fixed rolls.

const CRIT_DAMAGE_MULTIPLIER: float = 1.5
## A successful block halves the incoming damage instead of negating it.
const BLOCK_DAMAGE_MULTIPLIER: float = 0.5
const MIN_HIT_CHANCE: float = 0.05
const MAX_HIT_CHANCE: float = 0.95
## RO pre-renewal contested hit formula: hit% = 95 + acc + level − evasion,
## clamped 5–95%. Equal-stat investment gives the classic 95% base chance.
## Level modifiers in percentage points (same as before): each of the first two
## levels above the attacker costs 0.5%; beyond two levels the penalty escalates
## by 2% per level. Targets below the attacker grant a flat 0.5% per level.
## Same level contributes zero.
const RO_HIT_BASE_PERCENT: float = 95.0
const LEVEL_HIT_MODIFIER_PERCENT: float = 0.5
const LEVEL_HIT_GAP_ESCALATION_PERCENT: float = 2.0

## HIT: the contested accuracy roll succeeded (may be a crit).
## EVADED: the contested roll failed and the defender's evasion score exceeds
## the attacker's accuracy (the defender dodged on merit).
## MISS: the contested roll failed but evasion did not outscore accuracy
## (an attacker miss rather than a dodge).
## BLOCKED: the hit was landed but the defender's block roll succeeded;
## damage is halved.
enum ResultKind { HIT, MISS, EVADED, BLOCKED }

class Result:
	var kind: ResultKind = ResultKind.HIT
	var hit_chance: float = 1.0
	var is_crit: bool = false

## Injectable dice, returning a value in [0, 1). Tests replace this to force
## deterministic outcomes (e.g. always 0.0 disables misses, 1.0 always misses).
var dice: Callable = _default_randf

func _default_randf() -> float:
	return randf()

## Resolves one incoming attack with a single RO-contested accuracy roll.
## hit% = clamp(95 + acc + level_mod − evasion, 5%, 95%). A failed roll is
## tagged EVADED when the defender's evasion outscores the attacker's accuracy,
## or MISS otherwise. On a landed hit the defender rolls block (halving damage),
## then the attacker rolls crit. [attacker_stats] may be null for non-character
## sources (auto-hit, never miss/evade/crit), but the defender's block still
## applies; [defender_stats] always own the block roll.
func resolve_incoming(attacker_stats: CharacterStats, defender_stats: CharacterStats) -> Result:
	var result := Result.new()
	if attacker_stats != null:
		result.hit_chance = clampf((RO_HIT_BASE_PERCENT + attacker_stats.acc + _level_hit_modifier(attacker_stats.level, defender_stats.level) - defender_stats.evasion) / 100.0, MIN_HIT_CHANCE, MAX_HIT_CHANCE)
		if not _roll(result.hit_chance):
			result.kind = ResultKind.EVADED if defender_stats.evasion > attacker_stats.acc else ResultKind.MISS
			return result
	if defender_stats.block > 0.0 and _roll(defender_stats.block / 100.0):
		result.kind = ResultKind.BLOCKED
		return result
	# A critical only counts on a landed hit, and block failures reopen the roll.
	if attacker_stats != null and attacker_stats.crit > 0.0 and _roll(attacker_stats.crit / 100.0):
		result.is_crit = true
	return result

func _roll(chance: float) -> bool:
	return dice.call() < chance

func _level_hit_modifier(attacker_level: int, defender_level: int) -> float:
	var diff := defender_level - attacker_level
	if diff <= 0:
		return LEVEL_HIT_MODIFIER_PERCENT * float(-diff)
	if diff <= 2:
		return -LEVEL_HIT_MODIFIER_PERCENT * float(diff)
	return -(LEVEL_HIT_MODIFIER_PERCENT * 2.0 + LEVEL_HIT_GAP_ESCALATION_PERCENT * float(diff - 2))
