extends CanvasLayer

## Pause/settings overlay. Toggled with the "pause" action (Escape).
## Fades a transparent dimmer over the game while paused and exposes basic
## display and audio settings backed by SettingsManager.

@export var fade_time: float = 0.2

@onready var root: Control = $Root
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VSyncCheck
@onready var master_slider: HSlider = %MasterSlider
@onready var master_value: Label = %MasterValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_value: Label = %SFXValue
@onready var resume_button: Button = %ResumeButton
@onready var quit_button: Button = %QuitButton

var _is_open: bool = false
var _tween: Tween

func _ready() -> void:
	visible = false
	root.modulate.a = 0.0

	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	master_slider.value_changed.connect(_on_bus_changed.bind("Master", master_value))
	music_slider.value_changed.connect(_on_bus_changed.bind("Music", music_value))
	sfx_slider.value_changed.connect(_on_bus_changed.bind("SFX", sfx_value))
	resume_button.pressed.connect(close)
	quit_button.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	if _is_open:
		return
	_is_open = true
	_sync_controls()
	visible = true
	get_tree().paused = true
	resume_button.grab_focus()
	_fade_to(1.0)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	get_tree().paused = false
	_fade_to(0.0)
	await _tween.finished
	if not _is_open:
		visible = false

func _fade_to(target_alpha: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", target_alpha, fade_time)

func _sync_controls() -> void:
	fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
	vsync_check.set_pressed_no_signal(SettingsManager.vsync)
	_set_slider(master_slider, master_value, SettingsManager.get_bus_volume("Master"))
	_set_slider(music_slider, music_value, SettingsManager.get_bus_volume("Music"))
	_set_slider(sfx_slider, sfx_value, SettingsManager.get_bus_volume("SFX"))

func _set_slider(slider: HSlider, value_label: Label, linear: float) -> void:
	slider.set_value_no_signal(linear)
	value_label.text = "%d%%" % roundi(linear * 100.0)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SettingsManager.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool) -> void:
	SettingsManager.set_vsync(pressed)

func _on_bus_changed(value: float, bus_name: String, value_label: Label) -> void:
	SettingsManager.set_bus_volume(bus_name, value)
	value_label.text = "%d%%" % roundi(value * 100.0)

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
