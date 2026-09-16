class_name MonsterDefinition
extends Resource
## Data-driven monster blueprint. A Monster reads one definition in _ready and
## derives its stats, combat reward, behavior, and presentation tint from it.

@export var display_name: String = "Monster"
@export var level: int = 1
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var movement_speed: float = 2.5
@export var attack_speed: float = 1.0
@export var attack_damage: float = 10.0
@export var armour: float = 0.0
@export var evasion: float = 0.0
@export var acc: float = 90.0
@export var crit: float = 0.0
@export var block: float = 0.0
@export var experience_reward: int = 2
@export var aggressive: bool = true
@export_range(0.0, 50.0, 0.1, "or_greater") var aggro_radius: float = 6.0
@export_range(0.1, 100.0, 0.1, "or_greater") var leash_distance: float = 10.0
@export_range(0.7, 60.0, 0.1, "or_greater") var respawn_delay: float = 5.0
@export var attack_range: float = 1.5
@export var attack_duration: float = 2.0
@export var tint: Color = Color.WHITE
