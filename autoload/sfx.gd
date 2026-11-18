extends Node

var player: AudioStreamPlayer
var layers: Array[AudioStreamPlayer] = []
var targets := [0.0,0.0,0.0]
var levels := [0.0,0.0,0.0]
var last_second := -1

func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"): return
	player = AudioStreamPlayer.new()
	add_child(player)
	for index in 3:
		var layer := AudioStreamPlayer.new()
		layer.stream = _music_loop(index)
		layer.volume_db = -80
		add_child(layer)
		layers.append(layer)
		layer.play()

func _exit_tree() -> void:
	for layer in layers:
		layer.stop()
		layer.stream = null
	if is_instance_valid(player):
		player.stop()
		player.stream = null

func _music_loop(layer: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := 44100
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for index in count:
		var t := float(index) / 22050.0
		var beat := fposmod(t, 0.5)
		var value := 0.0
		if layer == 0:
			value = sin(TAU * (55 + 65 * exp(-beat * 25)) * t) * exp(-beat * 14) * 0.2 + sin(TAU * 55 * t) * 0.08
		elif layer == 1:
			value = sin(TAU * 1800 * t) * sin(TAU * 2473 * t) * exp(-fposmod(t,0.125) * 70) * 0.12
		else:
			var note: float = [220.0,261.63,293.66,329.63][int(t / 0.5) % 4]
			value = sin(TAU * note * t) * exp(-beat * 4) * 0.1
		samples.encode_s16(index * 2, int(clampf(value,-1,1) * 32767))
	stream.data = samples
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream

func music(combo: int, frenzy: bool, seconds: float) -> void:
	targets = [1.0, 1.0 if combo >= 5 else 0.0, 1.0 if combo >= 12 else 0.0]
	for layer in layers: layer.pitch_scale = 1.25 * pow(2.0,2.0/12.0) if frenzy else 1.0
	var second := ceili(seconds)
	if second <= 10 and second != last_second: play_tone(65,0.16,0.2)
	last_second = second

func stop_music() -> void:
	targets = [0.0,0.0,0.0]
	levels = [0.0,0.0,0.0]
	for layer in layers: layer.volume_db = -80

func fanfare() -> void:
	play_tone(880,0.3,0.2)

func _process(delta: float) -> void:
	for index in layers.size():
		levels[index] = move_toward(float(levels[index]),float(targets[index]),delta / GameConfig.JUICE_MUSIC_FADE)
		layers[index].volume_db = linear_to_db(maxf(0.0001,float(levels[index]) * Settings.music_volume))

func play_tone(frequency: float = 660.0, duration: float = 0.08, loudness: float = 0.14) -> void:
	if not is_instance_valid(player): return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := PackedByteArray()
	var count := int(22050.0 * duration)
	samples.resize(count * 2)
	for i in range(count):
		var env := minf(1.0, float(i) / 180.0) * (1.0 - float(i) / count)
		var sample := int(sin(TAU * frequency * float(i) / 22050.0) * loudness * env * 32767.0)
		samples.encode_s16(i * 2, sample)
	stream.data = samples
	player.stream = stream
	player.volume_db = linear_to_db(Settings.sfx_volume)
	player.play()
