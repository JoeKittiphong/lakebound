extends Button
signal selected(index: int)
var record_index := -1

func _ready() -> void:
 pressed.connect(func(): selected.emit(record_index))

func bind(record: Dictionary, index: int, active: bool) -> void:
 disabled = false
 $Content.alignment = BoxContainer.ALIGNMENT_BEGIN
 $Content/Icon.show()
 $Content/Weight.show()
 record_index = index
 var species := FishCatalog.find(StringName(record.species))
 $Content/Icon.texture = species.collection_icon if species != null else null
 $Content/Name.text = str(record.name)
 $Content/Weight.text = "%.2f กก." % float(record.weight)
 button_pressed = active

func bind_empty() -> void:
 record_index = -1
 disabled = true
 set_pressed_no_signal(false)
 $Content/Icon.texture = null
 $Content/Icon.hide()
 $Content/Weight.hide()
 $Content.alignment = BoxContainer.ALIGNMENT_CENTER
 $Content/Name.text = "ว่าง"
 $Content/Weight.text = ""
