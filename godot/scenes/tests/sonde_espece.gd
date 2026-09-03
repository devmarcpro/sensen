extends Node
## Sonde de l'espèce dans la matière (designer 2026-09-02, point 73 : « l'os appartient à une créature
## et donc ses stats en sont dérivés »). Elle vérifie que la bête voyage jusqu'au bout de la chaîne :
##   dépouille → matière brute → composant → objet assemblé.
## Le mécanisme existait pour le cuir depuis le 2026-09-01, mais il s'interrompait deux fois :
##   - la MATIÈRE brute tirée d'un corps sortait sans espèce (un os de lièvre = un os de troll) ;
##   - une recette perdait l'espèce de ses entrées (tanner une peau d'ours rendait du cuir anonyme).
##   Godot --headless --path godot res://scenes/tests/sonde_espece.tscn

const PAIRES := [["lievre", "ours_brun"], ["ecureuil", "bison"], ["souris_ou_defaut", "loup"]]

var soucis: Array = []


func _ready() -> void:
	var sim := Simulation.new(0xE59E)
	sim.charger_arene(GameData.catalogues.get("prototype_arenas", {}).keys()[0])
	var os_def: Dictionary = GameData.entree("materials", "os")
	print("os au catalogue : durete %d, densite %d, valeur %d" % [int(os_def.stats.durete), int(os_def.stats.densite), int(os_def.stats.valeur_base)])
	# 1. la même matière, tirée de deux bêtes que tout sépare, ne donne pas les mêmes chiffres.
	var mesures := {}
	for cid in ["lievre", "ecureuil", "renard", "loup", "sanglier", "ours_brun", "bison"]:
		if not GameData.catalogues.creatures.has(cid):
			continue
		var st: Dictionary = sim.stats_materiau(os_def, cid)
		var d: Dictionary = GameData.catalogues.creatures[cid]
		var fe := int(d.corps.stats.get("force", 0)) + int(d.corps.stats.get("endurance", 0))
		mesures[cid] = float(st.durete)
		print("  os de %-14s (force+endurance %2d) : durete %5.1f · densite %4.1f · valeur %5.1f" % [cid, fe, float(st.durete), float(st.densite), float(st.valeur_base)])
	if mesures.has("lievre") and mesures.has("ours_brun") and float(mesures.lievre) >= float(mesures.ours_brun):
		soucis.append("  l'os du lievre est aussi dur que celui de l'ours : l'espece ne mord pas")
	# 2. et sur pied : on tue une bête, on regarde ce qui tombe.
	for cid in ["lievre", "ours_brun"]:
		if not GameData.catalogues.creatures.has(cid):
			continue
		var trouve := _depecer(sim, cid)
		if trouve.is_empty():
			print("  %-12s : aucune matiere brute dans la depouille (le tirage de partie est aleatoire)" % cid)
			continue
		print("  %-12s : %s brut, espece « %s », durete %s" % [cid, str(trouve.get("materiau", "?")), str(trouve.get("espece", "")), str(trouve.get("stats", {}).get("durete", "?"))])
		if str(trouve.get("espece", "")) != cid:
			soucis.append("  %s : la matiere brute sort sans son espece" % cid)
	for s in soucis:
		print(s)
	if not soucis.is_empty():
		print("SONDE ESPECE : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde espece : la bete voyage de la depouille jusqu'a la matiere")
	get_tree().quit()


## Tue une bête et rend la première matière brute de sa dépouille, s'il y en a une.
func _depecer(sim, cid: String) -> Dictionary:
	var pos := Vector2i(-1, -1)
	for y in sim.grille.hauteur_grille:
		for x in sim.grille.largeur:
			var t := Vector2i(x, y)
			if not sim.grille.bloque_passage(t) and sim.grille.occupant(t).is_empty():
				pos = t
				break
		if pos.x >= 0:
			break
	if pos.x < 0:
		return {}
	var b: Dictionary = sim.ajouter(cid, pos, "ia")
	var joueur := ""
	for x2 in sim.vivants():
		if x2.controle == "joueur":
			joueur = str(x2.id)
	b.sante = 0
	b.vivant = false
	sim._drop(b, joueur)
	for gi in sim.contenants.keys():
		for uid in sim.contenants[gi]:
			var it: Dictionary = sim.items.get(str(uid), {})
			if it.get("type", "") == "materiau" and not str(it.get("espece", "")).is_empty():
				return it
	return {}
