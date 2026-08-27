extends Node
## EventBus — les systèmes communiquent par signaux, jamais par appel direct.
## Règle (docs/08 - Technique/EventBus.md) : aucun système n'appelle un autre système de
## gameplay ; tout couplage passe par les données (tags) ou par ces signaux.
## Les signaux sont émis par la simulation en phase 3 d'un tick (Boucle de tick) : ils sont
## mis en file pendant la résolution puis dispatchés d'un bloc.

signal damage_dealt(source_id: String, cible_id: String, degats: int, detail: Dictionary)
signal creature_killed(id: String, tueur_id: String)
signal skill_xp_gained(id: String, competence: String, xp: int)
signal skill_level_up(id: String, competence: String, niveau: int)
signal combat_started(horloge: String, participants: Array)
signal combat_ended(horloge: String)
signal action_engaged(id: String, action: Dictionary)      # télégraphe : intention visible
signal action_resolved(id: String, action: Dictionary)
signal journal(cle: String, params: Dictionary)             # une ligne de journal, localisée côté client
signal locale_changed(locale: String)
signal book_read(id: String, livre: String, succes: bool)
signal tile_changed(pos: Vector2i)                            # mutation de tuile (hauteur, contenu)

var _file: Array = []


## Met un événement en file ; `dispatcher()` les émet en fin de tick.
func emettre(nom: StringName, args: Array) -> void:
	_file.append([nom, args])


func dispatcher() -> void:
	var lot := _file
	_file = []
	for ev in lot:
		callv("emit_signal", [ev[0]] + ev[1])
