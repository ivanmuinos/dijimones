extends Node
## Música de fondo en loop. Los temas son originales: los genera tools/make_music.py.
## Si querés usar tus propias pistas, dejálas en game/assets/music/ como
## menu_custom.ogg / batalla_custom.ogg y el juego las prefiere. M silencia.

const TRACKS := {
	"menu": preload("res://assets/music/menu.ogg"),
	"batalla": preload("res://assets/music/batalla.ogg"),
}
## Overrides opcionales (sin importar si existen o no).
const CUSTOM := {
	"menu": ["res://assets/music/menu_custom.ogg", "res://assets/music/menu_custom.wav"],
	"batalla": ["res://assets/music/batalla_custom.ogg", "res://assets/music/batalla_custom.wav"],
}

var muted := false
var _player := AudioStreamPlayer.new()
var _current := ""
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = -7.0
	add_child(_player)
	_player.finished.connect(func(): _player.play())
	for track in TRACKS.keys():
		_streams[track] = _load_track(track)


func _load_track(track: String) -> AudioStream:
	var stream: AudioStream = TRACKS[track]
	for path in CUSTOM.get(track, []):
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	# Loop sin costura: el WAV/OGG importado se reproduce en bucle desde muestreo 0.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return stream


func play(track: String) -> void:
	if track == _current and _player.playing:
		return
	if not _streams.has(track):
		push_warning("Música desconocida: %s" % track)
		return
	_current = track
	_player.stream = _streams[track]
	if muted:
		return
	_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		muted = not muted
		if muted:
			_player.stop()
		elif _player.stream:
			_player.play()
