extends Control

const Row = preload("res://features/collection/collection_row.tscn")
signal opened
signal closed
@onready var collection: Node = get_node("/root/FishCollection")

func _ready() -> void:
 $Card/Content/Scroll.resized.connect(_queue_fit)
 visibility_changed.connect(_queue_fit)
 get_viewport().size_changed.connect(_queue_fit)

var _fit_queued := false

func _queue_fit() -> void:
 if not _fit_queued:
  _fit_queued = true
  _fit_grid.call_deferred()

func _fit_grid() -> void:
 _fit_queued = false
 if not visible:
  return
 var rows: GridContainer = $Card/Content/Scroll/Rows
 var scroll: ScrollContainer = $Card/Content/Scroll
 rows.columns = clampi(floori((scroll.size.x + 8.0) / 138.0), 1, 4)
 var row_count := maxi(1, ceili(rows.get_child_count() / float(rows.columns)))
 var spacing := (row_count - 1) * rows.get_theme_constant("v_separation")
 var height := maxf(100.0, floorf((scroll.size.y - spacing) / row_count))
 # Give the ScrollContainer an explicit content extent, including while the
 # game is paused and container sorting has not yet run on a mobile frame.
 rows.custom_minimum_size.y = row_count * height + spacing
 for row in rows.get_children():
  row.custom_minimum_size.y = height

func open() -> void:
 for child in $Card/Content/Scroll/Rows.get_children():
  child.free()
 var discovered := 0
 for species in collection.SPECIES:
  var stats: Dictionary = collection.stats(species.id)
  var unlocked: bool = stats.count > 0
  var row := Row.instantiate()
  $Card/Content/Scroll/Rows.add_child(row)
  row.bind(species, stats)
  if unlocked:
   discovered += 1
 $Card/Content/Header/Summary.text = "%d / %d" % [discovered, collection.SPECIES.size()]
 $Card/Content/SaveStatus.text = collection.save_error
 $Card/Content/SaveStatus.visible = not collection.save_error.is_empty()
 $Card/Content/Scroll.scroll_vertical = 0
 show()
 _fit_grid()
 opened.emit()
 _queue_fit()

func close() -> void:
 if not visible:
  return
 hide()
 closed.emit()

func _input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  close()
  get_viewport().set_input_as_handled()
