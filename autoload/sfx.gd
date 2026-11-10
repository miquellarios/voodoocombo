extends Node

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)

func play_tone(frequency: float = 660.0, duration: float = 0.08, loudness: float = 0.14) -> void:
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
