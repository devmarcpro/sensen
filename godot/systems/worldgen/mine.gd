class_name Mine
extends RefCounted
## La mine sous une cellule du joueur (designer 2026-09-02 : « le minage en profondeur se fait sur une
## cellule au joueur », façon Dwarf Fortress — « on rajoute un escalier pour descendre et l'étage du
## dessous est généré »). Voir [[Mine sous une cellule]].
##
## Une mine n'est PAS un donjon, et ce générateur est court pour cette raison : un donjon est fait de
## salles et de couloirs qu'on parcourt ; une mine est un bloc de roche PLEINE dans lequel il n'y a
## rien, sauf ce qu'on y creuse. Il n'y a donc ni salle, ni couloir, ni graphe à mailler — seulement
## une petite chambre d'arrivée au pied de l'échelle, et de la pierre partout ailleurs.
##
## Ce qui fait la profondeur n'est pas ici : c'est `Simulation.materiau_mur_etage` qui décide de la
## roche par bande d'étage, `_poches_de_strates` qui la fait varier par taches, et `_creuser` qui fait
## payer la dureté et le PALIER du matériau. La mine se contente de dire OÙ est le vide.

const H_BASE := 10   # la hauteur de référence du terrain, comme les étages de donjon
const CHAMBRE := 3   # le côté de la chambre d'arrivée : de quoi se tenir et poser un puits, pas plus


## Un étage de mine : plein, sauf une chambre carrée au centre où l'on débouche.
## `taille` vaut par défaut une cellule du monde, comme un étage de donjon (Grille continue).
static func generer_etage(graine: int, id_mine: int, etage: int, taille: int = -1) -> Dictionary:
	if taille < 0:
		taille = int(GameData.config("planete").taille_cellule)
	var e := {"largeur": taille, "hauteur": taille, "hauteurs": PackedByteArray(), "sol": {}, "bord": {},
		"pieces": [], "entree": Vector2i.ZERO, "escalier": null, "boss": null,
		"spawns": [], "coffres": [], "filons": {}, "graphe": {}, "etage": etage, "mine": true}
	e.hauteurs.resize(taille * taille)
	e.hauteurs.fill(H_BASE)
	# Le bord est en roche : une mine ne s'ouvre pas sur le vide, elle est ENTOURÉE. C'est aussi ce qui
	# empêche de creuser jusqu'au bord de la grille et de tomber hors du monde.
	for i in taille:
		for b in [Vector2i(i, 0), Vector2i(i, taille - 1), Vector2i(0, i), Vector2i(taille - 1, i)]:
			e.bord[b.y * taille + b.x] = true
	# La chambre d'arrivée, au centre. On y débouche par l'échelle, et c'est le seul vide offert :
	# tout le reste, c'est au joueur de l'ouvrir. Une mine se mérite à la pioche.
	var c := Vector2i(taille / 2, taille / 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([graine, id_mine, etage, "mine"])
	var demi := CHAMBRE / 2
	for dy in range(-demi, demi + 1):
		for dx in range(-demi, demi + 1):
			var p := c + Vector2i(dx, dy)
			e.sol[p.y * taille + p.x] = true
	e.entree = c
	return e


## L'identifiant d'une mine : une cellule du monde, une mine, pour toujours. Deux joueurs qui
## revendiquent la même cellule creusent la même mine — c'est le sol qui la porte, pas la partie.
static func id_de(graine: int, cell: Vector2i) -> int:
	return int(hash([graine, cell.x, cell.y, "mine"]) & 0x7fffffff)


## La profondeur ÉQUIVALENTE d'un étage de mine, pour les bandes de matériau et les paliers.
## Hypothèse posée en attendant l'arbitrage du designer ([[Mine sous une cellule]]) : un étage de mine
## vaut la MOITIÉ d'un étage de gouffre, parce qu'on y descend à la pioche et non par un escalier déjà
## construit. Si le designer veut la même échelle, c'est ce seul chiffre qui change.
static func profondeur_de(etage: int) -> int:
	var m: Dictionary = GameData.config("planete").get("mine", {})
	return maxi(1, roundi(float(etage) * float(m.get("profondeur_par_etage", 0.5))))
