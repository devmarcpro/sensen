class_name Etres
extends RefCounted
## Instanciation d'un être depuis sa fiche (Blocs de l'être, Schéma créature).
## Le joueur n'est PAS un type à part (Contraintes permanentes, règle 5) : même dictionnaire
## pour tout être, `controle` est un attribut. Les systèmes testent la présence d'un bloc ou
## d'un tag, jamais l'espèce.


## Crée l'instance sérialisable d'un être. `def` = entrée de data/creatures.
static func instancier(id: String, def: Dictionary, pos: Vector2i, controle: String, regles: Regles, items: Dictionary) -> Dictionary:
	var stats: Dictionary = def.corps.stats
	var equip := {}
	for item_id: String in def.get("equipement", []):
		var item: Dictionary = items.get(item_id, {})
		if item.is_empty():
			push_error("Etres : objet « %s » inconnu pour %s" % [item_id, id])
			continue
		equip[item.equip_slot] = item_id
	return {
		"id": id,
		"def": def.id,
		"name_key": def.name_key,
		"race": def.race,
		"controle": controle,                      # "joueur" | "ia" — un attribut, pas un type
		"camp": "joueur" if controle == "joueur" or def.ai_profile == "compagnon" else "hostile",
		"pos": pos,
		"ancre": pos,                              # point d'ancrage (Décision — Fuite et désengagement)
		"orientation": Vector2i(0, 1),
		"compteur": 0,
		"horloge": "monde",
		"corps": {"stats": stats.duplicate(), "silhouette": def.corps.silhouette},
		"sante": regles.sante_max(stats),
		"sante_max": regles.sante_max(stats),
		"endurance": int(regles.r.endurance.max),
		"endurance_max": int(regles.r.endurance.max),
		"mana": regles.mana_max(stats),
		"mana_max": regles.mana_max(stats),
		"tick_endurance": 0,                       # dernier tick où la régénération a été appliquée
		"equipement": equip,
		"ratelier": def.get("ratelier", []).duplicate(),
		"actions": def.get("actions", []).duplicate(),
		"ai_profile": def.ai_profile,
		"chain_gauge": def.get("chain_gauge", false),   # porteurs de jauge : joueur, élites, boss
		"elements": def.get("elements"),
		"teinte": def.get("teinte", [0.8, 0.8, 0.8]),
		"tags": def.get("tags", []).duplicate(),
		"vivant": true,
		"garde": false,
		"action_en_cours": {},                     # télégraphe : action engagée, résolue à l'échéance
		"statuts": [],
		"cible": "",
		"tick_derniere_vue": -1,
		"pos_connue": pos,
		"tick_decision": -1,
		"fuite": false,
	}


static func est_volant(e: Dictionary) -> bool:
	return e.corps.silhouette == "volant"


static func a_bouclier(e: Dictionary, items: Dictionary) -> bool:
	var id: String = e.equipement.get("main_secondaire", "")
	return not id.is_empty() and items.get(id, {}).get("type", "") == "bouclier"


static func arme(e: Dictionary, items: Dictionary) -> Dictionary:
	return items.get(e.equipement.get("main_principale", ""), {})


## La pièce d'armure couvrant la zone, ou {} (zone nue = 0).
static func piece_zone(e: Dictionary, zone: String, items: Dictionary) -> Dictionary:
	for item_id: String in e.equipement.values():
		var it: Dictionary = items.get(item_id, {})
		if it.get("type", "") == "armure" and it.get("zone", "") == zone:
			return it
	return {}
