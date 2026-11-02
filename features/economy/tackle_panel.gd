extends Control
signal opened
signal closed
var profile:AnglerProfile
var fishing:FishingController
var pond:PondEcosystem
var commerce:CommerceGateway
var map_id:="river"
@export var equipment_trials_enabled:=true
func _ready()->void:$Shop.close_requested.connect(close)
func bind(value:AnglerProfile,controller:FishingController,ecosystem:PondEcosystem,gateway:CommerceGateway)->void:
 profile=value;fishing=controller;pond=ecosystem;commerce=gateway
 $Shop.trials_enabled=equipment_trials_enabled
 $Shop.bind(profile,fishing,commerce)
func open()->void:
 if profile==null:return
 show();$Shop.set_category(2);$Shop.enter();opened.emit()
func open_category(index:int)->void:
 if profile==null:return
 show();$Shop.set_category(index);$Shop.enter();opened.emit()
func close()->void:
 if not visible:return
 $Shop.leave();hide();closed.emit()
func refresh()->void:$Shop.refresh()
func close_top_layer()->void:
 if not $Shop.pop_layer():close()
func _unhandled_key_input(event:InputEvent)->void:
 if visible and event.is_action_pressed("ui_cancel"):
  if not $Shop.pop_layer():close()
  get_viewport().set_input_as_handled()
