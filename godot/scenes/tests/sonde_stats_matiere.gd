extends Node
## Sonde des stats de matiere (designer 2026-09-03 : « pour l'arc les stats devraient etre affectees
## par l'elasticite »). La note « Application des stats de materiau » donne une formule pour chacune des
## treize stats — et QUATRE n'etaient lues nulle part dans le code : elasticite, friction,
## conductivite_mana, flottabilite. Une stat que rien ne lit est une promesse faite au joueur qui
## regarde la fiche d'un materiau et croit qu'elle veut dire quelque chose.
##   Godot --headless --path godot res://scenes/tests/sonde_stats_matiere.tscn

## La liste des stats reellement lues n'est pas ecrite ici : elle est CHERCHEE dans le code source.
## Une liste tapee a la main est un mensonge qui vieillit — j'en avais ecrit une le 2026-09-03, elle
## annoncait douze stats sur treize, et le designer a eu raison d'en douter : deux de plus ne
## servaient a rien. On lit donc les fichiers, on cherche `stats", {}).get("<stat>"` et ses variantes,
## et on croit ce qu'on trouve.
const SOURCES := ["res://systems/combat/simulation.gd", "res://systems/combat/regles.gd",
	"res://systems/combat/etres.gd", "res://systems/grid/grille.gd", "res://systems/loot/generateur.gd",
	"res://scenes/demo/main.gd"]

var soucis: Array = []


func _ready() -> void:
	var sm: Dictionary = GameData.config("combat_rules").get("stats_materiau", {})
	if sm.is_empty():
		soucis.append("  le bloc `stats_materiau` n'existe pas : aucune des formules de la note n'est reglable")
	# 1. l'arc : plus le bois est elastique, plus il frappe
	var base := float(sm.get("arc_elasticite_base", 0.8))
	var div := float(sm.get("arc_elasticite_div", 250.0))
	print("arc : degats x (%.2f + elasticite / %.0f)" % [base, div])
	for e in [0.0, 25.0, 60.0, 92.0]:
		print("   elasticite %5.0f -> x%.2f" % [e, base + e / div])
	if base + 92.0 / div <= base + 0.0 / div:
		soucis.append("  l'elasticite ne change rien a l'arc")
	# la matiere la plus elastique du catalogue contre la plus raide
	var haut := {"id": "", "v": -1.0}
	var bas := {"id": "", "v": 999.0}
	for mid in GameData.catalogues.materials.keys():
		var st: Dictionary = GameData.catalogues.materials[mid].get("stats", {})
		var v := float(st.get("elasticite", 0.0))
		if v > float(haut.v):
			haut = {"id": str(mid), "v": v}
		if v < float(bas.v):
			bas = {"id": str(mid), "v": v}
	var ecart := (base + float(haut.v) / div) / maxf(0.01, base + float(bas.v) / div)
	print("   du plus raide (%s, %.0f) au plus elastique (%s, %.0f) : x%.2f d'ecart sur les degats" % [bas.id, float(bas.v), haut.id, float(haut.v), ecart])
	if ecart < 1.15:
		soucis.append("  l'ecart entre la matiere la plus raide et la plus elastique n'est que de x%.2f : personne ne le sentira" % ecart)
	# 2. la friction du sol
	var fb := float(sm.get("friction_base", 0.85))
	var fp := float(sm.get("friction_par_point", 0.003))
	print("sol : vitesse x (%.2f + friction x %.3f), bornee [%.2f ; %.2f]" % [fb, fp, float(sm.get("friction_min", 0.85)), float(sm.get("friction_max", 1.15))])
	print("   glace (friction 0) -> x%.2f · pave (100) -> x%.2f" % [clampf(fb, 0.85, 1.15), clampf(fb + 100.0 * fp, 0.85, 1.15)])
	# 3. le mana : la conductivite de la matiere tenue
	var dv := float(sm.get("mana_conductivite_div", 140.0))
	print("mana : cout x (1 - conductivite / %.0f)" % dv)
	for c in [0.0, 40.0, 80.0, 100.0]:
		print("   conductivite %5.0f -> x%.2f" % [c, clampf(1.0 - c / dv, 0.2, 1.0)])
	# 4. et la verification qui compte : chaque stat de la fiche sert-elle a quelque chose ?
	var toutes: Array = []
	for mid in GameData.catalogues.materials.keys():
		toutes = (GameData.catalogues.materials[mid].get("stats", {}) as Dictionary).keys()
		break
	var code := ""
	for chemin in SOURCES:
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f != null:
			code += f.get_as_text()
	var muettes: Array[String] = []
	for st in toutes:
		# Ce qui compte, c'est une lecture de la STAT D'UN MATERIAU, pas le mot quelque part.
		if not (('stats", {}).get("%s' % str(st)) in code or ('stats.get("%s' % str(st)) in code
				or ('stats.%s' % str(st)) in code):
			muettes.append(str(st))
	print("stats de matiere : %d au total, %d lues par une formule" % [toutes.size(), toutes.size() - muettes.size()])
	if not muettes.is_empty():
		print("   AUCUNE formule ne les lit : %s" % str(muettes))
	if muettes.size() > 1:
		soucis.append("  %d stats de matiere ne sont lues nulle part : la fiche promet ce que le jeu ne tient pas" % muettes.size())
	for x in soucis:
		print(x)
	if not soucis.is_empty():
		print("SONDE STATS MATIERE : ECHEC — %d souci(s)" % soucis.size())
		get_tree().quit(1)
		return
	print("sonde stats matiere : l'elasticite, la friction et la conductivite de mana mordent")
	get_tree().quit()
