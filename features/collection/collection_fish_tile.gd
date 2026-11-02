extends Control
const Silhouette = preload("res://features/collection/fish_silhouette.tres")
var species_id := ""
var revealed := false

func bind(species: FishSpecies, stats: Dictionary, _show_history := false, per_map := false) -> void:
	species_id = String(species.id)
	revealed = stats.count > 0
	$Content/Preview.texture = species.collection_icon
	$Content/Preview.material = null if revealed else Silhouette
	$Content/Preview/Question.visible = not revealed
	$Content/Name.text = species.display_name if revealed else ""
	$Content/Name.hide()
	$Content/Stats.text = ("สูงสุดในแผนที่นี้ %.2f กก." % stats.best if per_map else "สูงสุด %.2f กก. • %d ตัว" % [stats.best,stats.count]) if revealed else ""
	$Content/Stats.hide()
	tooltip_text = species.display_name if revealed else "ยังไม่ค้นพบ"

func set_selected(value: bool) -> void:
	$Selected.visible = value
