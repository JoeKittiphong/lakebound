extends PanelContainer
signal history_requested(species_id: String)
var species_id := ""

func _ready() -> void:
 $Content/Preview/OpenHistory.pressed.connect(func(): history_requested.emit(species_id))

const Silhouette = preload("res://features/collection/fish_silhouette.tres")

func bind(species: FishSpecies, stats: Dictionary, show_history: bool = false, per_map: bool = false) -> void:
 species_id = String(species.id)
 var unlocked: bool = stats.count > 0
 $Content/Preview/OpenHistory.disabled = not (unlocked and show_history)
 $Content/Preview/OpenHistory.mouse_filter = Control.MOUSE_FILTER_STOP if unlocked and show_history else Control.MOUSE_FILTER_IGNORE
 $Content/Name.text = species.display_name if unlocked else ""
 $Content/Name.visible = unlocked
 $Content/Stats.visible = unlocked
 $Content/Stats.text = "สูงสุด %.2f กก. • %d ตัว" % [stats.best, stats.count] if unlocked else ""
 if unlocked and per_map:
  $Content/Stats.text = "สูงสุดในแผนที่นี้ %.2f กก." % stats.best
 $Content/Preview.texture = species.collection_icon
 $Content/Preview.material = null if unlocked else Silhouette
 $Content/Preview/Question.visible = not unlocked
