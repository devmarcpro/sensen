class_name Horloge
extends RefCounted
## Une horloge de jeu (Temporalités parallèles) : le monde en a une, chaque combat la sienne.
## TEMPS_REEL : avance seule (10 ticks/s hors combat — Boucle de tick).
## ACTION : n'avance que quand une action pousse des ticks. Réfléchir est gratuit.

enum Mode { TEMPS_REEL, ACTION }

signal avancee(de: int, a: int)

var nom: String
var mode: Mode
var ticks: int = 0
var ticks_par_seconde: float
var active := true
var _frac := 0.0


func _init(p_nom: String, p_mode: Mode, tps: float = 0.0) -> void:
	nom = p_nom
	mode = p_mode
	ticks_par_seconde = tps


## Temps réel uniquement — appelé par le TickManager, jamais par la logique.
func accumuler(delta: float) -> void:
	_frac += delta * ticks_par_seconde
	var n := int(_frac)
	if n > 0:
		_frac -= n
		avancer(n)


func avancer(n: int) -> void:
	if n <= 0:
		return
	var de := ticks
	ticks += n
	avancee.emit(de, ticks)


## Saute à l'instant `t` (mode action : l'entité au plus petit compteur agit).
func sauter_a(t: int) -> void:
	if t > ticks:
		avancer(t - ticks)
