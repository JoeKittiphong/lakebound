class_name FishBoxView
extends PanelContainer
signal pressed
@export var icon_override: Texture2D
@export var capacity_warning_tint := true

var _profile: AnglerProfile
var _dirty := true
@onready var _weight: Label = $Row/Info/Weight

func _ready() -> void:
	if icon_override != null: $Row/Icon.texture = icon_override
	$Open.pressed.connect(func(): pressed.emit())

func bind(profile: AnglerProfile) -> void:
	if profile == _profile:
		return
	_disconnect_profile()
	_profile = profile
	if is_instance_valid(_profile):
		_profile.changed.connect(_invalidate)
	_dirty = true

func _disconnect_profile() -> void:
	if is_instance_valid(_profile) and _profile.changed.is_connected(_invalidate):
		_profile.changed.disconnect(_invalidate)

func _exit_tree() -> void:
	_disconnect_profile()

func _invalidate() -> void:
	_dirty = true

func refresh_if_needed() -> void:
	if not _dirty or not is_instance_valid(_profile):
		return
	_dirty = false
	var weight := _profile.box_weight()
	var box: TackleItem = _profile.equipped("box")
	var capacity: float = box.capacity if box != null else 0.0
	$Row/Icon.texture = icon_override if icon_override != null else box.shop_icon if box != null else null
	var remaining := maxf(0.0, capacity - weight)
	var fraction := clampf(weight / maxf(capacity, 0.01), 0.0, 1.0)
	_weight.text = "%s/%.0f" % [("%.1f"%weight).trim_suffix(".0"),capacity]
	$Open.tooltip_text = "ปลา %d ตัว · %.1f / %.0f กก." % [_profile.data.catches.size(),weight,capacity]
	var color := Color(1, 0.4, 0.35) if remaining < 0.001 else Color(1, 0.82, 0.35) if fraction >= 0.8 else Color(0.65, 1, 0.84)
	_weight.modulate = color if capacity_warning_tint else Color.WHITE
