class_name EcransAtelier
extends RefCounted
## L'atelier : les recettes, leur texte, les piles, les filtres, l'obtention des composants.
## Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans
## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis
## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.


static func _construire_atelier(ec: Ecrans, j: Dictionary) -> void:
	var plans: Array = ec.main.sim.recettes_disponibles(j)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.faisable != b.faisable:
			return a.faisable
		return str(a.kind) < str(b.kind))
	var stations: Dictionary = ec.main.sim.stations_de(j)
	var noms: Array[String] = []
	for st in stations.keys():
		noms.append(ec.tr(GameData.entree("stations", st).name_key))
	ec.titre.text = ec.tr("ui.ecran.atelier").format({"stations": " · ".join(noms) if not noms.is_empty() else "—"})
	for pl in plans:
		var niv_r: int = ec.main.sim.niveau_recette(ec.main.joueur(), str(pl.get("id", "")))   # Axe des niveaux de recette : le niveau se lit
		ec.liste.add_item(("✓ " if pl.faisable else "✗ ") + _titre_plan(ec, pl) + ((" " + ec.tr("ui.atelier.niveau_recette").format({"n": niv_r})) if niv_r > 1 else "") + "   [" + ec.tr(GameData.entree("stations", pl.station).name_key) + "]")
		if not pl.faisable:
			ec.liste.set_item_custom_fg_color(ec.liste.item_count - 1, Color(0.6, 0.6, 0.6))
		ec.entrees.append({"kind": "recette", "plan": pl})
		if str(pl.kind) == "plate":   # les ingrédients optionnels d'un plat : à cocher (Décision — Affinités de cuisine)
			for cand in ec.main.sim.candidats_optionnels(j, pl.recette):
				ec.liste.add_item(ec.tr("ui.atelier.ingredient").format({"coche": "☑" if cand.inclus else "☐", "nom": ec.main.nom_objet(ec.main.sim.nom_objet(str(cand.uid)))}))
				ec.entrees.append({"kind": "ingredient", "rid": str(pl.id), "uid": str(cand.uid), "plan": pl})
	if plans.is_empty():
		ec.liste.add_item(ec.tr("ui.atelier.vide"))
		ec.entrees.append({"kind": "texte", "texte": ec.tr("ui.atelier.vide")})
	EcransListe._bouton(ec, ec.tr("ui.ecran.fabriquer"), func() -> void: EcransListe._action_principale(ec))


static func _titre_plan(ec: Ecrans, pl: Dictionary) -> String:
	match str(pl.kind):
		"composant":
			return ec.tr(GameData.entree("components", pl.recette.component).name_key) + " ← " + ec.tr("famille." + str(pl.recette.material_family))
		_:
			return ec.tr(pl.recette.name_key)


## Le détail d'une recette ; pour un objet, l'obtention de chaque composant se déplie (Navigation des recettes).
static func texte_recette(ec: Ecrans, pl: Dictionary) -> String:
	var l: Array[String] = ["[b]%s[/b]  (%s)" % [_titre_plan(ec, pl), ec.tr("ui.atelier.kind." + str(pl.kind))]]
	l.append(ec.tr("ui.recette.station").format({"station": ec.tr(GameData.entree("stations", pl.station).name_key), "competence": ec.tr(ec.main.sim._nom_competence(_competence_plan(ec, pl)))}))
	l.append(ec.tr("ui.recette.entrees"))
	for en in pl.entrees:
		match str(pl.kind):
			"objet":
				var c: Dictionary = GameData.entree("components", en.filtre)
				l.append("   %s : %s — %s" % [ec.tr("slotc." + str(en.slot)), ec.tr(c.name_key), (ec.main.nom_objet(ec.main.sim.nom_objet(en.pile.uid)) if not en.pile.is_empty() else "[color=#c66]" + ec.tr("ui.recette.manque") + "[/color]")])
				l.append_array(_obtention_composant(ec, str(en.filtre), "      "))
			"composant":
				l.append("   1 × %s — %s" % [ec.tr("famille." + en.filtre), _nom_pile(ec, en)])
				l.append_array(_obtention_famille(ec, str(en.filtre), "      "))
			_:
				l.append("   %d × %s — %s%s" % [int(en.besoin), _nom_filtre(ec, en), _nom_pile(ec, en), ec.tr("ui.recette.optionnel") if bool(en.get("optionnel", false)) else ""])
	if str(pl.kind) == "plate" and GameData.catalogues.items.has(str(pl.sortie.get("item", ""))) and GameData.catalogues.items[str(pl.sortie.item)].get("type", "") == "consommable":
		var hp: Dictionary = ec.main.sim.harmonie_prevue(pl)
		if not hp.is_empty():
			var parts: Array[String] = []
			for el in hp.vecteur.keys():
				if float(hp.vecteur[el]) > 0.0:
					parts.append("%s %.2f" % [ec.tr("element." + str(el)), float(hp.vecteur[el])])
			l.append(ec.tr("ui.recette.harmonie").format({"vecteur": " · ".join(parts), "harmonie": ec.tr("ui.recette.harmonie_oui") if bool(hp.harmonie) else ec.tr("ui.recette.harmonie_non").format({"n": int(hp.elements)})}))
	l.append(ec.tr("ui.recette.sortie"))
	match str(pl.kind):
		"plate":
			var mat_s: String = ec.tr(GameData.entree("materials", pl.sortie.materiau).name_key) if GameData.catalogues.materials.has(pl.sortie.materiau) else "?"
			l.append("   %d × %s" % [int(pl.sortie.quantite), ec.tr("forme." + str(pl.sortie.forme)).format({"materiau": mat_s})])
		"composant":
			l.append("   " + ec.tr(GameData.entree("components", pl.sortie.composant).name_key) + " " + ec.tr("ui.recette.qualite_composant"))
		"objet":
			l.append("   " + ec.tr(pl.recette.name_key) + " " + ec.tr("ui.recette.assemblage"))
	return "\n".join(l)


static func _competence_plan(ec: Ecrans, pl: Dictionary) -> String:
	match str(pl.kind):
		"plate":
			return str(pl.recette.craft_skill)
		"composant":
			return str(GameData.entree("stations", pl.station).craft_skill)
		_:
			return str(pl.recette.recipe.craft_skill)


static func _nom_pile(ec: Ecrans, en: Dictionary) -> String:
	if en.pile.is_empty():
		return "[color=#c66]" + ec.tr("ui.recette.manque") + "[/color]"
	return EcransInventaire._nom_court(ec, str(en.pile.uid))


static func _nom_filtre(ec: Ecrans, en: Dictionary) -> String:
	var nom: String = ec.tr("material.%s.name" % en.filtre) if GameData.catalogues.materials.has(en.filtre) else ec.tr("categorie." + str(en.filtre))
	return ec.tr("forme." + str(en.forme)).format({"materiau": nom})


## Les recettes d'obtention d'un composant : connues en clair, exotiques en silhouette.
static func _obtention_composant(ec: Ecrans, cid: String, indent: String) -> Array[String]:
	var res: Array[String] = []
	var j: Dictionary = ec.main.joueur()
	var ids: Array = GameData.catalogues.component_recipes.keys()
	ids.sort()
	for rid in ids:
		var r: Dictionary = GameData.catalogues.component_recipes[rid]
		if str(r.component) != cid:
			continue
		var st_nom: String = ec.tr(GameData.entree("stations", r.station).name_key) if GameData.catalogues.stations.has(r.station) else str(r.station)
		if bool(r.unlocked_by_default) or rid in j.get("recettes_connues", []):
			res.append(indent + "← %s [%s]" % [ec.tr("famille." + str(r.material_family)), st_nom])
			res.append_array(_obtention_famille(ec, str(r.material_family), indent + "   "))
		else:
			res.append(indent + "[color=#777]??? — %s (%s)[/color]" % [ec.tr("ui.recette.inconnue"), ", ".join(r.unlock_sources)])
	return res


## D'où vient une famille : la transformation plate qui produit sa forme, et ce qu'elle consomme.
static func _obtention_famille(ec: Ecrans, fam_id: String, indent: String) -> Array[String]:
	var res: Array[String] = []
	var fam: Dictionary = GameData.config("material_families").get(fam_id, {})
	if fam.has("tag"):
		res.append(indent + "[color=#777]" + ec.tr("ui.recette.sans_source") + "[/color]")
		return res
	var forme := str(fam.get("forme", "brut"))
	if forme == "brut":
		res.append(indent + ec.tr("ui.recette.recolte"))
		return res
	for rid in GameData.catalogues.recipes.keys():
		var r: Dictionary = GameData.catalogues.recipes[rid]
		if str(r.output.get("forme", "")) == forme and not r.output.has("material"):
			var entrees_txt: Array[String] = []
			for en in r.inputs:
				entrees_txt.append("%d × %s" % [int(en.amount), ec.tr("categorie." + str(en.get("category", en.get("material", ""))))])
			res.append(indent + "← %s [%s] : %s" % [ec.tr(r.name_key), ec.tr(GameData.entree("stations", r.station).name_key), " + ".join(entrees_txt)])
	return res


# ---------------------------------------------------------------- feuille
