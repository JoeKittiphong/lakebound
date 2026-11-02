extends SceneTree
func _initialize() -> void:
 var definition: RainforestLakeDefinition=load("res://world/rainforest_lake/lake_definition.tres")
 definition.bake_fish_habitats()
 assert(ResourceSaver.save(definition,"res://world/rainforest_lake/lake_definition.tres")==OK)
 print("LAKE_FISH_HABITATS ",definition.fish_habitats.size())
 quit()
