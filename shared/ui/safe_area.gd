extends Control
@export var minimum_margin: float = 32.0
@export_node_path("Control") var raised_control_path: NodePath
@export var control_lift: float = 0.0

func _ready() -> void:
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()

func _update_safe_area() -> void:
	var margins := Vector4(minimum_margin, minimum_margin, minimum_margin, minimum_margin)
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		var scale_factor := get_viewport_rect().size / Vector2(screen)
		margins.x = maxf(minimum_margin, safe.position.x * scale_factor.x)
		margins.y = maxf(minimum_margin, safe.position.y * scale_factor.y)
		margins.z = maxf(minimum_margin, (screen.x - safe.end.x) * scale_factor.x)
		margins.w = maxf(minimum_margin, (screen.y - safe.end.y) * scale_factor.y)
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("""JSON.stringify((() => {
			const probe = document.createElement('div');
			probe.style.cssText = 'position:fixed;visibility:hidden;padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left)';
			document.body.appendChild(probe);
			const css = getComputedStyle(probe);
			const insets = [css.paddingLeft, css.paddingTop, css.paddingRight, css.paddingBottom].map(v => parseFloat(v) || 0);
			probe.remove();
			return {insets, width: innerWidth, height: innerHeight};
		})())""")
		var browser_area = JSON.parse_string(str(result))
		if browser_area is Dictionary and browser_area.get("width", 0) > 0 and browser_area.get("height", 0) > 0:
			var scale_factor := get_viewport_rect().size / Vector2(browser_area.width, browser_area.height)
			var insets: Array = browser_area.insets
			margins.x = maxf(minimum_margin, float(insets[0]) * scale_factor.x)
			margins.y = maxf(minimum_margin, float(insets[1]) * scale_factor.y)
			margins.z = maxf(minimum_margin, float(insets[2]) * scale_factor.x)
			margins.w = maxf(minimum_margin, float(insets[3]) * scale_factor.y)
	offset_left = margins.x
	offset_top = margins.y
	offset_right = -margins.z
	offset_bottom = -margins.w
	if not raised_control_path.is_empty():
		var raised := get_node_or_null(raised_control_path) as Control
		if raised != null:
			# Lift within decorative desktop padding, never into a phone's unsafe inset.
			var available := margins.y
			if OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web"):
				available = 0.0
			var lift := minf(control_lift, available)
			var height := raised.size.y
			raised.offset_top = -lift
			raised.offset_bottom = height - lift
