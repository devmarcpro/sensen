class_name WuXing
extends RefCounted
## Le Wu Xing — vecteurs, domination, jauge de chaîne. Formules de « Domination et
## multiplicateurs » et « Jauge de chaîne Wu Xing », chiffres lus dans `data/wuxing.json`.
## Tout porte un VECTEUR ({metal: 0.75, bois: 0.25}), jamais un élément unique.

var w: Dictionary   # la configuration wuxing


func _init(config: Dictionary) -> void:
	w = config


# ---------------------------------------------------------------- vecteurs

## L'élément dominant d'un vecteur ("" si vide). Départage : l'ordre canonique des éléments.
func dominante(v: Variant) -> String:
	if not (v is Dictionary) or v.is_empty():
		return ""
	var meilleur := ""
	var part := -1.0
	for e: String in w.elements:
		if float(v.get(e, 0.0)) > part:
			part = float(v.get(e, 0.0))
			meilleur = e
	return meilleur


## Relation de l'élément attaquant vers l'élément cible : domine · domine_par · engendre · neutre.
func relation(att: String, cible: String) -> String:
	if att.is_empty() or cible.is_empty():
		return "neutre"
	if w.domine[att] == cible:
		return "domine"
	if w.domine[cible] == att:
		return "domine_par"
	if w.engendre[att] == cible:
		return "engendre"
	return "neutre"


## Multiplicateur entre deux vecteurs : double somme pondérée (1.0 si l'un est vide).
## `table` = "offensif" (alignement d'une créature) ou "defensif" (vecteur d'une pièce d'armure).
func multiplicateur(v_att: Variant, v_cible: Variant, table: String = "offensif") -> float:
	if not (v_att is Dictionary) or v_att.is_empty() or not (v_cible is Dictionary) or v_cible.is_empty():
		return 1.0
	var t: Dictionary = w[table]
	var total := 0.0
	var poids := 0.0
	for a: String in v_att.keys():
		for c: String in v_cible.keys():
			var p := float(v_att[a]) * float(v_cible[c])
			total += p * float(t[relation(a, c)])
			poids += p
	return total / poids if poids > 0.0 else 1.0


# ---------------------------------------------------------------- jauge de chaîne

## Une jauge neuve : segments [{element, tick}], bonus accumulé, capacité.
func jauge_neuve() -> Dictionary:
	return {"segments": [], "capacite": int(w.chaine.capacite_base), "tick_ref": 0}


## Bonus de la transition `precedent → nouveau` (Jauge de chaîne Wu Xing).
func bonus_transition(precedent: String, nouveau: String) -> float:
	if precedent.is_empty():
		return 0.0
	if precedent == nouveau:
		return float(w.chaine.bonus_meme_element)
	if w.engendre[precedent] == nouveau:
		return float(w.chaine.bonus_engendrement)
	return float(w.chaine.bonus_hors_ordre)


## Somme des bonus de transition d'une liste de segments.
func bonus_de(segments: Array) -> float:
	var b := 0.0
	for i in range(1, segments.size()):
		b += bonus_transition(segments[i - 1].element, segments[i].element)
	return b


## Décroissance : un segment se vide tous les 30 ticks écoulés, le dernier posé en premier.
## Déterministe et calculable — appelée avant toute lecture ou pose.
func decroitre(jauge: Dictionary, tick: int) -> void:
	var periode := int(w.chaine.decroissance_ticks)
	while not jauge.segments.is_empty() and tick - int(jauge.tick_ref) >= periode:
		jauge.segments.pop_back()
		jauge.tick_ref = int(jauge.tick_ref) + periode
	if jauge.segments.is_empty():
		jauge.tick_ref = tick


## Le gain intermédiaire : +5 % par segment présent dans la barre.
func gain_intermediaire(jauge: Dictionary) -> float:
	return 1.0 + float(w.chaine.gain_par_segment) * jauge.segments.size()


## Ce que donnerait la pose d'un segment `element` maintenant, SANS la faire :
## {position, transition, bonus_total, resout, multiplicateur}.
func prevoir(jauge: Dictionary, element: String) -> Dictionary:
	var precedent: String = jauge.segments.back().element if not jauge.segments.is_empty() else ""
	var transition := bonus_transition(precedent, element)
	var total := bonus_de(jauge.segments) + transition
	var position: int = jauge.segments.size() + 1
	var resout: bool = position >= int(jauge.capacite)
	return {"position": position, "transition": transition, "bonus_total": total, "resout": resout,
		"multiplicateur": (1.0 + total) if resout else 1.0, "gain": gain_intermediaire(jauge)}


## Pose un segment ; si c'est le dernier, la chaîne RÉSOUT (bonus rendu) et la barre retombe à 0.
## Retourne la prévision appliquée.
func poser(jauge: Dictionary, element: String, tick: int) -> Dictionary:
	var p := prevoir(jauge, element)
	if p.resout:
		jauge.segments.clear()
	else:
		jauge.segments.append({"element": element, "tick": tick})
	jauge.tick_ref = tick
	return p


## Interruption (Décision — Chaîne côté ennemis) : retire le dernier segment posé.
func interrompre(jauge: Dictionary) -> bool:
	if jauge.segments.is_empty():
		return false
	jauge.segments.pop_back()
	return true


func teinte(element: String) -> Color:
	var t: Array = w.teintes.get(element, [0.6, 0.6, 0.6])
	return Color(t[0], t[1], t[2])
