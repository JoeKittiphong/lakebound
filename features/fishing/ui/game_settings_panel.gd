class_name GameSettingsPanel
extends Control

signal opened
signal closed
signal menu_requested
signal help_requested
const SAVE_PATH := "user://lakebound_settings.cfg"

func _ready() -> void:
 var config := ConfigFile.new()
 var volume := AudioServer.get_bus_volume_linear(0)
 if config.load(SAVE_PATH)==OK:
  volume = clampf(float(config.get_value("audio","volume",volume)),0,1)
 %Volume.value = volume*100
 _volume_changed(%Volume.value)
 %Volume.value_changed.connect(_volume_changed)
 %Close.pressed.connect(close)
 %Resume.pressed.connect(close)
 %Help.pressed.connect(func(): help_requested.emit())
 %BackToSettings.pressed.connect(func(): %HelpView.hide(); %Menu.show())
 %Home.pressed.connect(func(): close(); menu_requested.emit())

func open() -> void:
 if visible: return
 %HelpView.hide()
 %Menu.show()
 show()
 opened.emit()

func close() -> void:
 if not visible: return
 var config := ConfigFile.new()
 config.set_value("audio","volume",%Volume.value/100.0)
 AtomicConfig.save(config,SAVE_PATH)
 hide()
 closed.emit()

func show_help(text: String) -> void:
 %Instructions.text = text
 %Menu.hide()
 %HelpView.show()

func _volume_changed(value: float) -> void:
 AudioServer.set_bus_volume_linear(0,value/100.0)
 %VolumeValue.text = "%d%%"%roundi(value)

func _input(event: InputEvent) -> void:
 if visible and event.is_action_pressed("ui_cancel"):
  if %HelpView.visible:
   %HelpView.hide()
   %Menu.show()
  else:
   close()
  get_viewport().set_input_as_handled()
