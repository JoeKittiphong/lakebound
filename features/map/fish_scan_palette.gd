extends Resource
## Absolute weight bands, shared by echoes and the on-screen legend.
@export var medium_min_kg := 1.0
@export var large_min_kg := 5.0
@export var colossal_min_kg := 20.0
@export var small_color := Color("56d9ff")
@export var medium_color := Color("73ed98")
@export var large_color := Color("ff984c")
@export var colossal_color := Color("d695ff")
@export var boss_color := Color("ffda58")

func classify(weight: float, is_boss: bool = false) -> int:
 if is_boss: return 4
 if weight >= colossal_min_kg: return 3
 if weight >= large_min_kg: return 2
 if weight >= medium_min_kg: return 1
 return 0

func color_for(tier: int) -> Color:
 return [small_color, medium_color, large_color, colossal_color, boss_color][clampi(tier, 0, 4)]

func legend_for(tier: int) -> String:
 match tier:
  0: return "● เล็ก < %s กก." % String.num(medium_min_kg, 2).trim_suffix(".0")
  1: return "● กลาง %s–<%s กก." % [String.num(medium_min_kg, 2).trim_suffix(".0"), String.num(large_min_kg, 2).trim_suffix(".0")]
  2: return "● ใหญ่ %s–<%s กก." % [String.num(large_min_kg, 2).trim_suffix(".0"), String.num(colossal_min_kg, 2).trim_suffix(".0")]
  3: return "● มหึมา %s+ กก." % String.num(colossal_min_kg, 2).trim_suffix(".0")
 return "◆ จ้าวบ่อ"
