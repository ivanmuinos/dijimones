extends Node
## Elección del menú principal (nombre del tamer y Digimon) y su guardado local.

const PROFILE_PATH := "user://perfil.cfg"
const CHARACTERS := [
	preload("res://data/characters/agumon.tres"),
	preload("res://data/characters/gabumon.tres"),
	preload("res://data/characters/patamon.tres"),
]

var player_name := "Tamer"
var character: CharacterData


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) == OK:
		player_name = cfg.get_value("perfil", "nombre", player_name)
		var id: String = cfg.get_value("perfil", "digimon", "")
		for c in CHARACTERS:
			if c.id == id:
				character = c
	if character == null:
		character = CHARACTERS[0]


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("perfil", "nombre", player_name)
	cfg.set_value("perfil", "digimon", character.id)
	cfg.save(PROFILE_PATH)
