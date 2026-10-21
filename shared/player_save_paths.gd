class_name PlayerSavePaths
extends RefCounted

# Fixed reset generation: keep these paths across subsequent app versions so
# players restart once, then retain all progress earned after this reset.
const COLLECTION := "user://fish_collection_reset_20261021.cfg"
const TUTORIAL := "user://first_catch_tutorial_reset_20261021.cfg"
