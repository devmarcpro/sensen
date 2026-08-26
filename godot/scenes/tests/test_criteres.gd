extends Node
## Les critères MESURABLES de « Prototype de combat — spécification » § 5, calculés sur les
## dégâts moyens avec les vraies règles et les vraies données (pas de dés) :
##   1. rotation parfaite vs construction/détonation : totaux à ±15 % ?
##   2. le swap d'arme (4 ticks pour +0.35) est-il rentable dans certains cas seulement ?
## Imprime un rapport ; n'échoue que si le calcul lui-même casse. Le jugement reste humain.
##   & Godot --headless --path godot res://scenes/tests/test_criteres.tscn --quit-after 3

var sim: Simulation
var cible: Dictionary   # un mannequin : le sanglier (Terre/Métal, sans armure), PV infinis


func _ready() -> void:
	sim = Simulation.new(1)
	sim.charger_arene("plaine_au_talus")
	cible = sim.ajouter("sanglier", Vector2i(10, 10), "ia")
	var rapport: Array[String] = ["=== Critères mesurables (dégâts moyens, mannequin : sanglier) ==="]
	rapport.append_array(critere_deux_voies())
	rapport.append_array(critere_swap())
	for l in rapport:
		print(l)
	get_tree().quit(0)


## Dégâts moyens d'un coup d'arme `item` contre le mannequin, avec l'état de jauge donné.
func coup_arme(item_id: String, lourde: bool, jauge: Dictionary) -> Dictionary:
	var arme: Dictionary = sim.items[item_id]
	var fonct: Dictionary = sim.fonctionnalites[arme.functionality]
	var f := Des.fourchette(fonct.degats_des)
	var moy := float(f.x + f.y) * 0.5
	var stats: Dictionary = sim.entites[joueur_id()].corps.stats
	var bruts := moy * float(arme.durete_base) / float(sim.regles.r.degats.durete_reference) + float(int(stats.force) / int(sim.regles.r.degats.stat_div))
	if lourde:
		bruts *= float(sim.regles.r.actions.lourde_mult_degats)
	var v := sim.vecteur_arme(arme)
	var el := sim.wuxing.dominante(v)
	var dom := sim.wuxing.multiplicateur(v, cible.elements)
	var p := sim.wuxing.prevoir(jauge, el)
	var total := bruts * dom * float(p.gain) * float(p.multiplicateur)
	sim.wuxing.poser(jauge, el, 0)
	return {"degats": total, "ticks": sim.regles.ticks_attaque(fonct, lourde), "element": el, "resout": p.resout, "mult": p.multiplicateur}


## Dégâts moyens d'une capacité (index dans la fiche du joueur) contre le mannequin.
func coup_capacite(index: int, jauge: Dictionary) -> Dictionary:
	var j: Dictionary = sim.entites[joueur_id()]
	var plan := sim.plan_capacite(j, index)
	var f := Des.fourchette(plan.des, int(plan.des_bonus))
	var moy := float(f.x + f.y) * 0.5
	var el := sim.wuxing.dominante(plan.elements)
	var dom := sim.wuxing.multiplicateur(plan.elements, cible.elements)
	var p := sim.wuxing.prevoir(jauge, el)
	var total := moy * dom * float(p.gain) * float(p.multiplicateur)
	sim.wuxing.poser(jauge, el, 0)
	return {"degats": total, "ticks": int(plan.ticks), "element": el, "resout": p.resout, "mult": p.multiplicateur}


func joueur_id() -> String:
	for e in sim.vivants():
		if e.controle == "joueur":
			return e.id
	return ""


func sequence(nom: String, coups: Array) -> Dictionary:
	var jauge := sim.wuxing.jauge_neuve()
	var total := 0.0
	var ticks := 0
	var detail: Array[String] = []
	for c in coups:
		var r: Dictionary
		if c[0] == "arme":
			r = coup_arme(c[1], c[2], jauge)
		elif c[0] == "swap":
			ticks += int(sim.regles.r.actions.changer_arme)
			detail.append("swap(4t)")
			continue
		else:
			r = coup_capacite(c[1], jauge)
		total += r.degats
		ticks += r.ticks
		detail.append("%s %.1f%s" % [r.element, r.degats, " ×%.2f RÉSOUT" % r.mult if r.resout else ""])
	return {"nom": nom, "total": total, "ticks": ticks, "par_tick": total / maxf(1.0, float(ticks)), "detail": " → ".join(detail)}


func ligne(s: Dictionary) -> String:
	return "  %-28s %6.1f dégâts en %3d ticks (%.2f/tick) : %s" % [s.nom, s.total, s.ticks, s.par_tick, s.detail]


func critere_deux_voies() -> Array[String]:
	# Rotation parfaite : Bois → Feu → Terre → Métal → Eau, dans l'ordre d'engendrement.
	var rotation := sequence("rotation parfaite", [
		["arme", "proto_lance", false], ["capacite", 0], ["swap"], ["arme", "proto_masse", false],
		["swap"], ["arme", "proto_epee", false], ["capacite", 1]])
	# Construction/détonation : 4 coups rapides de dague (Métal) puis la lourde engendrée… l'Eau n'a pas
	# d'arme : la détonation est Gel en ligne (Eau, 3d6). Variante toute arme : 4 × masse puis épée lourde.
	var construction := sequence("construction/détonation", [
		["arme", "proto_dague", false], ["arme", "proto_dague", false], ["arme", "proto_dague", false],
		["arme", "proto_dague", false], ["capacite", 1]])
	var construction_arme := sequence("construction (masse→épée lourde)", [
		["arme", "proto_masse", false], ["arme", "proto_masse", false], ["arme", "proto_masse", false],
		["arme", "proto_masse", false], ["swap"], ["arme", "proto_epee", true]])
	var meme_arme := sequence("même arme ×5 (épée)", [
		["arme", "proto_epee", false], ["arme", "proto_epee", false], ["arme", "proto_epee", false],
		["arme", "proto_epee", false], ["arme", "proto_epee", true]])
	var ecart := absf(rotation.total - construction.total) / maxf(rotation.total, construction.total) * 100.0
	var ecart2 := absf(rotation.total - construction_arme.total) / maxf(rotation.total, construction_arme.total) * 100.0
	return [
		"1. Les deux voies de chaîne — cible : totaux à ±15 %",
		ligne(rotation), ligne(construction), ligne(construction_arme), ligne(meme_arme),
		"   écart rotation vs construction (dague→Gel) : %.0f %% · vs construction (masse→épée lourde) : %.0f %% %s" % [
			ecart, ecart2, "✓" if (ecart <= 15.0 or ecart2 <= 15.0) else "✗ (retoucher les bonus de transition)"],
	]


func critere_swap() -> Array[String]:
	# Enchaîner avec la même arme (+0.10, 0 tick) ou payer 4 ticks pour changer d'élément (+0.35) ?
	var a := sequence("épée ×5 sans swap", [
		["arme", "proto_epee", false], ["arme", "proto_epee", false], ["arme", "proto_epee", false],
		["arme", "proto_epee", false], ["arme", "proto_epee", false]])
	var b := sequence("épée→swap masse→… (2 swaps)", [
		["arme", "proto_epee", false], ["arme", "proto_epee", false], ["swap"], ["arme", "proto_masse", false],
		["swap"], ["arme", "proto_epee", false], ["arme", "proto_epee", false]])
	var c := sequence("dague ×5 sans swap", [
		["arme", "proto_dague", false], ["arme", "proto_dague", false], ["arme", "proto_dague", false],
		["arme", "proto_dague", false], ["arme", "proto_dague", false]])
	var d := sequence("dague ×4 → swap épée lourde", [
		["arme", "proto_dague", false], ["arme", "proto_dague", false], ["arme", "proto_dague", false],
		["arme", "proto_dague", false], ["swap"], ["arme", "proto_epee", true]])
	var verdicts: Array[String] = []
	verdicts.append("swap rentable par tick : %s (épée) · %s (dague→épée lourde)" % [
		"oui" if b.par_tick > a.par_tick else "non", "oui" if d.par_tick > c.par_tick else "non"])
	return [
		"2. Le swap d'arme — cible : rentable dans certains cas seulement",
		ligne(a), ligne(b), ligne(c), ligne(d),
		"   " + verdicts[0] + (" ✓ (mixte)" if (b.par_tick > a.par_tick) != (d.par_tick > c.par_tick) else " — à revoir si toujours la même réponse"),
	]
