extends Control
signal region_selected(id: String)
func _ready() -> void:
 $Panel/Content/Scroll.resized.connect(_fit)
 get_viewport().size_changed.connect(_fit)
 _fit()
func _fit() -> void:
 var narrow: bool = DisplayServer.window_get_size().x < 960 or $Panel/Content/Scroll.size.x < 650
 $Panel/Content/Scroll/Cards.columns = 1 if narrow else 2
 for card: Button in $Panel/Content/Scroll/Cards.get_children():
  card.custom_minimum_size.y = 164 if narrow else 134
  card.add_theme_font_size_override("font_size", 28 if narrow else 20)
func open() -> void:
 show();$Panel/Content/Scroll.scroll_vertical=0
func close() -> void:
 $Panel/Content/Scroll.stop_scrolling();hide()
func _choose(id: String) -> void:
 region_selected.emit(id);close()
