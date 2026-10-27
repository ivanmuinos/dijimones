extends Node
## Música de fondo en loop (temas chiptune originales de tools/make_music.py). M silencia.

const TRACKS := {
	"menu": preload("res://assets/music/menu.wav"),
	"batalla": preload("res://assets/music/batalla.wav"),
}

var muted := false
var _player := AudioStreamPlayer.new()
var _current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.volume_db = -8.0
	add_child(_player)
	_player.finished.connect(func(): _player.play())


func play(track: String) -> void:
	if track == _current and _player.playing:
		return
	_current = track
	_player.stream = TRACKS[track]
	if not muted:
		_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		muted = not muted
		if muted:
			_player.stop()
		else:
			_player.play()
