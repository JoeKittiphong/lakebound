extends PanelContainer

const Silhouette = preload("res://features/collection/fish_silhouette.tres")

func bind(species: FishSpecies, stats: Dictionary) -> void:
 var unlocked: bool = stats.count > 0
 $Content/Name.text = species.display_name if unlocked else ""
 $Content/Name.visible = unlocked
 $Content/Stats.visible = unlocked
 $Content/Stats.text = "สูงสุด %.2f กก. • %d ตัว" % [stats.best, stats.count] if unlocked else ""
 $Content/Preview.texture = species.collection_icon
 $Content/Preview.material = null if unlocked else Silhouette
 $Content/Preview/Question.visible = not unlocked
