class_name Progression
extends RefCounted
## La progression par l'usage (Progression par l'usage, Potentiel, Double niveau combat et
## général, Astrologie) : une courbe unique, un potentiel par stat et par compétence, deux
## niveaux dérivés. Rien ici ne dépend du type d'être : joueur, PNJ et compagnons progressent pareil.

var r: Dictionary               # combat_rules.progression
var competences: Dictionary     # catalogue data/competences
var astro: Dictionary           # data/astrologie.json


func _init(regles: Dictionary, p_competences: Dictionary, p_astro: Dictionary) -> void:
	r = regles
	competences = p_competences
	astro = p_astro


## XP requise pour passer du niveau N au niveau N+1 : base × (N + 1)^1.6.
func xp_next(niveau: int) -> int:
	return roundi(float(r.xp_base) * pow(float(niveau + 1), float(r.xp_exposant)))


## Le potentiel de base d'une compétence pour une race et une classe : moyenne des deux quand elles
## diffèrent (défaut 80), plus les +10 de l'astrologie ; borné 50-130 (Potentiel).
func potentiel_base(cle: String, race: Dictionary, classe: Dictionary, signe: Dictionary) -> int:
	var famille := str(competences.get(cle, {}).get("famille", ""))
	var pr := _potentiel_de(race.get("base_potentials", {}), cle, famille)
	var pc := _potentiel_de(classe.get("base_potentials", {}), cle, famille)
	var base := roundi((float(pr) + float(pc)) * 0.5) if pr != pc else pr
	if not signe.is_empty():
		var bonus := int(astro.get("bonus_potentiel", 10))
		if cle in astro.element_competences.get(str(signe.get("element", "")), []):
			base += bonus
		if cle in astro.animal_competences.get(str(signe.get("animal", "")), []):
			base += bonus
	return clampi(base, int(r.potentiel_min), int(r.potentiel_max_base))


func _potentiel_de(table: Dictionary, cle: String, famille: String) -> int:
	if table.has(cle):
		return int(table[cle])
	if not famille.is_empty() and table.has(famille):
		return int(table[famille])
	return int(table.get("_defaut", r.potentiel_defaut))


## Verse de l'XP à une compétence (ou une stat) ; retourne le nombre de niveaux gagnés.
## xp_effective = xp × potentiel/100 ; au level up : potentiel = max(base, potentiel − (10 + N/10)).
func verser(e: Dictionary, cle: String, xp: int) -> int:
	if xp <= 0:
		return 0
	var pot: Dictionary = e.potentiels
	var potentiel := int(pot.get(cle, int(r.potentiel_defaut)))
	var base := int(e.potentiels_base.get(cle, int(r.potentiel_defaut)))
	var effective := float(xp) * float(potentiel) / 100.0 * float(e.get("xp_mult", 1.0))
	e.xp_competences[cle] = float(e.xp_competences.get(cle, 0.0)) + effective
	var gagnes := 0
	var niveau := int(e.competences.get(cle, 0))
	while float(e.xp_competences[cle]) >= float(xp_next(niveau)):
		e.xp_competences[cle] = float(e.xp_competences[cle]) - float(xp_next(niveau))
		niveau += 1
		gagnes += 1
		potentiel = maxi(base, potentiel - (int(r.potentiel_cout_base) + niveau / int(r.potentiel_cout_div)))
	if gagnes > 0:
		e.competences[cle] = niveau
		pot[cle] = potentiel
	return gagnes


## La stat associée à une compétence reçoit la moitié de l'XP versée (décision du 2026-08-27).
func stat_associee(cle: String) -> String:
	if competences.has(cle):
		return str(competences[cle].get("stat", ""))
	return "volonte"   # un module : la Volonté


## Niveau de combat / général : moyenne des 5 meilleures compétences de chaque catégorie.
func niveaux_derives(e: Dictionary) -> Dictionary:
	var combat: Array[int] = []
	var general: Array[int] = []
	for cle: String in e.competences.keys():
		var n := int(e.competences[cle])
		var cat := str(competences.get(cle, {}).get("category", "combat"))
		if cat == "general":
			general.append(n)
		else:
			combat.append(n)
	return {"combat": _moyenne_top(combat, int(r.top_n)), "general": _moyenne_top(general, int(r.top_n))}


static func _moyenne_top(valeurs: Array[int], n: int) -> float:
	if valeurs.is_empty():
		return 0.0
	valeurs.sort()
	valeurs.reverse()
	var somme := 0
	var k := mini(n, valeurs.size())
	for i in k:
		somme += valeurs[i]
	return float(somme) / float(k)


## Le signe d'une année de naissance : élément (cycle de 5) et animal (cycle de 12).
func signe(annee: int) -> Dictionary:
	var els: Array = astro.elements
	var ans: Array = astro.animaux
	return {"element": els[posmod(annee, els.size())], "animal": ans[posmod(annee, ans.size())], "annee": annee}
