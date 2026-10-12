extends Node
## Audio hooks. Drop files into res://assets/audio/sfx/<key>.(ogg|wav|mp3) and
## res://assets/audio/music/<key>.(ogg|mp3); missing files are silently skipped.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _ambient: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _cache := {}
var _ambient_key := ""
var _combat_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Music"
	add_child(_ambient)
	_combat = AudioStreamPlayer.new()
	_combat.bus = "Music"
	_combat.volume_db = -80.0
	add_child(_combat)


func _find(dir: String, key: String) -> AudioStream:
	var ck := dir + key
	if _cache.has(ck):
		return _cache[ck]
	var s: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var p := "%s%s.%s" % [dir, key, ext]
		if ResourceLoader.exists(p):
			s = load(p)
			break
	_cache[ck] = s
	return s


func play(key: String, pitch_var := 0.08) -> void:
	var s := _find(SFX_DIR, key)
	if s == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = s
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


## Biome ambience / music layer, e.g. "ambient_reef".
func play_ambient(key: String) -> void:
	if key == _ambient_key:
		return
	_ambient_key = key
	var s := _find(MUSIC_DIR, key)
	if s == null:
		_ambient.stop()
		return
	_ambient.stream = s
	_ambient.play()


## Fades the combat music layer in or out (spec §10).
func set_combat(on: bool) -> void:
	if on == _combat_on:
		return
	_combat_on = on
	var s := _find(MUSIC_DIR, "combat")
	if s == null:
		return
	if on and not _combat.playing:
		_combat.stream = s
		_combat.play()
	var tw := create_tween()
	tw.tween_property(_combat, "volume_db", 0.0 if on else -80.0, 1.5)


func apply_volumes(music: float, sfx: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music / 100.0, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx / 100.0, 0.0001)))
