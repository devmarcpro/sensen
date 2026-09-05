class_name Calendrier
## Le calendrier du monde (Un monde réel — villes, PNJ, royaumes et calendrier, A, 2026-09-05) : une lecture
## pure du jour absolu (`Simulation.jour_courant()`), rien à sauver. Douze mois nommés par les animaux du cycle
## sexagésimal, la semaine de sept jours qui reste la cadence de tout l'hebdomadaire, les années depuis
## `annee_depart` (data/calendrier.json). Le jour de marché d'une agglomération et les fêtes sont lus ici aussi.


static func cfg() -> Dictionary:
	return GameData.config("calendrier")


static func jours_par_an() -> int:
	var n := 0
	for m in cfg().mois:
		n += int(m[1])
	return maxi(1, n)


## La date d'un jour absolu : {jour, annee, mois (id), mois_index, jour_mois (dès 1), jour_semaine (id), jour_de_l_an (dès 0)}.
static func date(jour: int) -> Dictionary:
	var c := cfg()
	var jpa := jours_par_an()
	var annee := int(c.annee_depart) + int(floor(float(jour) / float(jpa)))
	var jda := posmod(jour, jpa)
	var reste := jda
	var mois_index := 0
	for k in c.mois.size():
		var n := int(c.mois[k][1])
		if reste < n:
			mois_index = k
			break
		reste -= n
	var js: Array = c.jours_semaine
	return {"jour": jour, "annee": annee, "mois": str(c.mois[mois_index][0]), "mois_index": mois_index, "jour_mois": reste + 1,
		"jour_semaine": str(js[posmod(jour + int(c.get("decalage_semaine", 0)), js.size())]), "jour_de_l_an": jda}


## Le texte d'une date : « jour du Feu, 7 du Cheval, an 1020 » (clé calendrier.date).
static func texte(d: Dictionary) -> String:
	return TranslationServer.translate("calendrier.date").format({"jour_semaine": TranslationServer.translate("calendrier.jour." + str(d.jour_semaine)),
		"jour_mois": int(d.jour_mois), "mois": TranslationServer.translate("calendrier.mois." + str(d.mois)), "annee": int(d.annee)})


## Le jour de marché d'une agglomération : un jour de la semaine tiré de son nom — aucun état.
static func jour_de_marche(nom: String) -> String:
	var js: Array = cfg().jours_semaine
	return str(js[posmod(nom.hash(), js.size())])


## Les fêtes d'une date pour une culture de nommage (une fête sans culture est commune à toutes).
static func fetes_du_jour(d: Dictionary, culture: String) -> Array:
	var res: Array = []
	for f in cfg().fetes.liste:
		if str(f.mois) == str(d.mois) and int(f.jour) == int(d.jour_mois) and (f.cultures.is_empty() or culture in f.cultures):
			res.append(f)
	return res


## L'anniversaire d'un être : un mois et un jour tirés de son identifiant.
static func anniversaire(id: String) -> Dictionary:
	var c := cfg()
	var h := id.hash()
	var k := posmod(h, c.mois.size())
	return {"mois": str(c.mois[k][0]), "jour": posmod(h / 7, int(c.mois[k][1])) + 1}
