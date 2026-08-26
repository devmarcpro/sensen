extends Node
## TickManager — la SEULE source d'avancement du temps de jeu (Simulation à ticks).
## Il possède les horloges (une du monde, une par combat, une par donjon — Temporalités
## parallèles) : les horloges en temps réel avancent ici à fréquence fixe, les horloges
## d'action n'avancent que lorsqu'une action consomme des ticks (`Horloge.sauter_a`).
## C'est le seul endroit où `delta` est converti en ticks ; la logique ne le voit jamais.

var horloges: Dictionary = {}   # nom → Horloge


func creer(nom: String, mode: Horloge.Mode, ticks_par_seconde: float = 0.0) -> Horloge:
	var h := Horloge.new(nom, mode, ticks_par_seconde)
	horloges[nom] = h
	return h


func retirer(nom: String) -> void:
	horloges.erase(nom)


func horloge(nom: String) -> Horloge:
	return horloges.get(nom)


func _process(delta: float) -> void:
	for h: Horloge in horloges.values():
		if h.mode == Horloge.Mode.TEMPS_REEL and h.active:
			h.accumuler(delta)
