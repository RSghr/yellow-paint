extends Node
## The ThinkBox 2009 struggling when the operator flies away from the level (added by game.gd).
##   - Inside `comfort` (the level plus some room for wide shots): nothing.
##   - Past it, over `strain_distance` metres: the picture pixelates and its colours fall apart (follows the
##     camera, so flying back clears it), and the fan spins up.
##   - The fan never calms down: it stays at the loudest it got until the level is reloaded (this node is freed with
##     the game scene). It plays on its own "Fan" bus, ignores the SFX/Music sliders, makes up for the Master slider
##     (up to `max_master_boost_db`) and keeps going while paused.
## Sound: audio/fan.wav (or .ogg/.mp3), looped. Missing = silent fan, the picture still breaks down.

const PIXEL_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strain = 0.0;  // 0 = clean, 1 = pixel mess
void fragment() {
	float px_size = mix(1.0, 56.0, strain * strain);
	vec2 px = SCREEN_PIXEL_SIZE * px_size;
	vec2 cell = floor(SCREEN_UV / px);
	// Some blocks glitch to a neighbour's colour, more and more often.
	float h = fract(sin(dot(cell + floor(TIME * 6.0), vec2(12.9898, 78.233))) * 43758.5453);
	if (h < strain * 0.35) {
		cell += vec2(floor(h * 7.0) - 3.0, 0.0);
	}
	vec3 c = texture(screen_tex, (cell + 0.5) * px).rgb;
	float levels = mix(64.0, 3.0, strain);  // Colour depth collapses too.
	c = floor(c * levels + 0.5) / levels;
	COLOR = vec4(c, 1.0);
}
"""

@export var strain_distance := 35.0  ## Metres past `comfort` until the full pixel mess (game.gd puts the wall there).
@export var fan_start := 0.25  ## Strain where the fan kicks in.
@export var fan_quiet_db := -26.0  ## Fan volume when it kicks in...
@export var fan_loud_db := 6.0  ## ...and at full strain.
@export var max_master_boost_db := 30.0  ## How much it makes up for a lowered Master volume.

var comfort := AABB()  ## Set by game.gd.
var heat := 0.0  ## Highest strain reached since the level was loaded. Only goes up.

var _layer: CanvasLayer
var _screen: ColorRect
var _mat: ShaderMaterial
var _fan: AudioStreamPlayer
var _fan_bus := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # The fan doesn't care about the pause menu.
	_layer = CanvasLayer.new()
	_layer.layer = 0  # Under the HUD (layer 1): the interface stays readable, the game doesn't.
	add_child(_layer)
	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = PIXEL_SHADER
	_screen.material = _mat
	_screen.visible = false
	_layer.add_child(_screen)

	_fan_bus = _make_fan_bus()
	_fan = AudioStreamPlayer.new()
	_fan.bus = "Fan"
	_fan.stream = _load_fan()
	add_child(_fan)


func _process(_delta: float) -> void:
	var strain := current_strain()
	heat = maxf(heat, strain)
	_screen.visible = strain > 0.01
	_mat.set_shader_parameter("strain", strain)
	_update_fan()


## How far past the comfort zone the camera is, 0..1.
func current_strain() -> float:
	var cam := get_viewport().get_camera_3d()
	if not cam or not comfort.has_volume():
		return 0.0
	var p := cam.global_position
	var inside := p.clamp(comfort.position, comfort.end)
	return clampf(p.distance_to(inside) / strain_distance, 0.0, 1.0)


func _update_fan() -> void:
	if not _fan.stream:
		return
	if heat < fan_start:
		return
	var k := inverse_lerp(fan_start, 1.0, heat)
	var master := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	# Its own bus, so only Master can turn it down: make up for that too.
	AudioServer.set_bus_volume_db(_fan_bus, clampf(-master, 0.0, max_master_boost_db))
	_fan.volume_db = lerpf(fan_quiet_db, fan_loud_db, k)
	_fan.pitch_scale = lerpf(0.85, 1.35, k)  # Spinning up.
	if not _fan.playing:
		_fan.play()


static func _make_fan_bus() -> int:
	var i := AudioServer.get_bus_index("Fan")
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Fan")
		AudioServer.set_bus_send(i, "Master")
	return i


static func _load_fan() -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://audio/fan.%s" % ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(stream.get_length() * stream.mix_rate)
			elif "loop" in stream:
				stream.loop = true
			return stream
	return null
