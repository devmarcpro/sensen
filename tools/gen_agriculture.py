# -*- coding: utf-8 -*-
"""L'agriculture refondue (designer 2026-09-07, 18 h 45 : « rajoute du bétail, des grains, des légumes, des fruits, etc.
Refonte de l'agriculture pour que chaque plant ait des stats uniques — temps de pousse, conditions, stats »).

Écrit, à partir d'une table lisible :
  - data/plants/<categorie>/<id>.json  — chaque plante avec SES nombres : duree_jours, recolte_base, nutrition, saisons,
    besoin_eau, famille (la rotation change de famille ; une légumineuse rend de la fertilité), conditions
    (biomes où elle pousse à plein, fertilite_min sous laquelle on ne la sème pas), wuxing, bonus_potentiel ;
  - data/items/consommable/<id>.json    — le fruit de la récolte, cru, empilable ;
  - data/creatures/bete/<id>.json       — le bétail domestique, avec son bloc `elevage` (produits, fourrage, naissances,
    abattage, biomes) ;
  - locale/fr.csv, locale/en.csv        — plant.<id>.name, item.<id>.name, creature.<id>.name ;
  - data/villes.json                    — champs.cultures_par_biome, vergers (espèces), enclos.especes_par_biome, DÉRIVÉS
    des conditions des plantes et des biomes du bétail (une table de moins à tenir à la main).
Idempotent : il n'écrit que ses identifiants ; ce qui a été ajouté à la main ailleurs reste. Les fichiers existants des
huit cultures d'origine reçoivent famille et conditions sans perdre le reste.

    python tools/gen_agriculture.py
"""
import collections
import io
import json
import os

RACINE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'godot')
DATA = os.path.join(RACINE, 'data')

# id, categorie, famille, fr, en, duree_jours, recolte_base, nutrition, saisons, besoin_eau, biomes, fertilite_min
PLANTES = [
    # les huit d'origine : famille et conditions seulement (le reste est gardé tel quel)
    ("ble", "culture", "cereale", None, None, None, None, None, None, None, ["tempere", "plaine"], 30),
    ("orge", "culture", "cereale", None, None, None, None, None, None, None, ["froid", "tempere", "montagne"], 25),
    ("carotte", "culture", "racine", None, None, None, None, None, None, None, [], 20),
    ("chou", "culture", "legume", None, None, None, None, None, None, None, ["froid", "tempere", "humide"], 25),
    ("oignon", "culture", "legume", None, None, None, None, None, None, None, [], 20),
    ("pomme_de_terre", "culture", "racine", None, None, None, None, None, None, None, ["froid", "tempere", "montagne"], 15),
    ("tomate", "culture", "legume", None, None, None, None, None, None, None, ["chaud", "tempere"], 30),
    ("citrouille", "culture", "legume", None, None, None, None, None, None, None, ["humide", "tempere"], 30),
    # les céréales
    ("seigle", "culture", "cereale", "Seigle", "Rye", 6, 4, 9, ["automne"], 0.4, ["froid", "montagne", "tempere"], 15),
    ("avoine", "culture", "cereale", "Avoine", "Oats", 5, 4, 9, ["printemps"], 0.5, ["froid", "tempere", "humide"], 20),
    ("millet", "culture", "cereale", "Millet", "Millet", 4, 3, 8, ["printemps", "ete"], 0.2, ["chaud", "desert", "plaine"], 15),
    ("riz", "culture", "cereale", "Riz", "Rice", 6, 5, 10, ["printemps"], 0.9, ["humide", "marecage", "chaud"], 30),
    ("mais", "culture", "cereale", "Maïs", "Maize", 6, 6, 11, ["printemps"], 0.6, ["chaud", "tempere", "plaine"], 35),
    ("sarrasin", "culture", "cereale", "Sarrasin", "Buckwheat", 3, 3, 8, ["ete"], 0.4, ["froid", "montagne", "tempere"], 10),
    ("epeautre", "culture", "cereale", "Épeautre", "Spelt", 6, 3, 10, ["automne"], 0.4, ["tempere", "montagne"], 20),
    # les racines
    ("navet", "culture", "racine", "Navet", "Turnip", 3, 4, 6, ["printemps", "automne"], 0.5, ["froid", "tempere"], 15),
    ("betterave", "culture", "racine", "Betterave", "Beetroot", 5, 4, 8, ["printemps"], 0.5, ["tempere", "plaine"], 25),
    ("radis", "culture", "racine", "Radis", "Radish", 1, 3, 3, ["printemps", "ete", "automne"], 0.6, [], 10),
    ("panais", "culture", "racine", "Panais", "Parsnip", 6, 4, 7, ["printemps"], 0.5, ["froid", "tempere"], 20),
    # les légumes
    ("poireau", "culture", "legume", "Poireau", "Leek", 6, 3, 5, ["printemps"], 0.5, ["tempere", "froid", "cote"], 25),
    ("ail", "culture", "legume", "Ail", "Garlic", 7, 3, 4, ["automne"], 0.3, ["tempere", "chaud"], 20),
    ("laitue", "culture", "legume", "Laitue", "Lettuce", 2, 3, 3, ["printemps", "automne"], 0.7, ["tempere", "humide"], 20),
    ("epinard", "culture", "legume", "Épinard", "Spinach", 2, 3, 5, ["printemps", "automne"], 0.6, ["tempere", "froid"], 25),
    ("courgette", "culture", "legume", "Courgette", "Courgette", 3, 5, 5, ["printemps", "ete"], 0.7, ["chaud", "tempere"], 30),
    ("concombre", "culture", "legume", "Concombre", "Cucumber", 3, 5, 3, ["ete"], 0.8, ["chaud", "humide"], 30),
    ("aubergine", "culture", "legume", "Aubergine", "Aubergine", 5, 4, 5, ["printemps", "ete"], 0.6, ["chaud"], 35),
    ("poivron", "culture", "legume", "Poivron", "Pepper", 5, 4, 5, ["printemps"], 0.6, ["chaud"], 35),
    # les légumineuses : elles rendent de la fertilité à la terre
    ("haricot", "culture", "legumineuse", "Haricot", "Bean", 4, 4, 8, ["printemps", "ete"], 0.5, ["tempere", "chaud"], 15),
    ("pois", "culture", "legumineuse", "Pois", "Pea", 3, 4, 8, ["printemps"], 0.5, ["tempere", "froid"], 15),
    ("lentille", "culture", "legumineuse", "Lentille", "Lentil", 4, 3, 9, ["printemps"], 0.3, ["chaud", "desert", "tempere"], 10),
    ("feve", "culture", "legumineuse", "Fève", "Broad bean", 4, 4, 8, ["automne", "printemps"], 0.5, ["tempere", "cote"], 15),
    # les fibres et les oléagineux
    ("lin", "culture", "fibre", "Lin", "Flax", 4, 3, 2, ["printemps"], 0.5, ["tempere", "froid"], 25),
    ("chanvre", "culture", "fibre", "Chanvre", "Hemp", 4, 3, 3, ["printemps"], 0.5, ["tempere", "humide"], 20),
    ("tournesol", "culture", "oleagineux", "Tournesol", "Sunflower", 5, 3, 6, ["printemps"], 0.4, ["chaud", "tempere", "plaine"], 25),
    ("colza", "culture", "oleagineux", "Colza", "Rapeseed", 6, 3, 4, ["automne"], 0.5, ["tempere", "froid"], 30),
    ("canne_a_sucre", "culture", "cereale", "Canne à sucre", "Sugar cane", 8, 5, 8, ["printemps"], 0.9, ["chaud", "humide"], 35),
    # les fruits : des buissons et des arbres, plantés une fois (le verger)
    ("fraisier", "buisson", "fruit", "Fraisier", "Strawberry", 3, 3, 4, ["printemps"], 0.6, ["tempere", "froid", "humide"], 20),
    ("groseillier", "buisson", "fruit", "Groseillier", "Currant bush", 4, 3, 3, ["printemps"], 0.5, ["froid", "tempere"], 15),
    ("cassissier", "buisson", "fruit", "Cassissier", "Blackcurrant bush", 4, 3, 4, ["printemps"], 0.6, ["froid", "tempere", "humide"], 15),
    ("pommier", "buisson", "fruit", "Pommier", "Apple tree", 8, 6, 6, ["printemps"], 0.5, ["tempere", "froid"], 20),
    ("poirier", "buisson", "fruit", "Poirier", "Pear tree", 8, 5, 6, ["printemps"], 0.5, ["tempere"], 25),
    ("prunier", "buisson", "fruit", "Prunier", "Plum tree", 7, 5, 5, ["printemps"], 0.5, ["tempere", "chaud"], 20),
    ("cerisier", "buisson", "fruit", "Cerisier", "Cherry tree", 6, 4, 5, ["printemps"], 0.5, ["tempere", "froid", "montagne"], 20),
    ("figuier", "buisson", "fruit", "Figuier", "Fig tree", 7, 4, 7, ["printemps", "ete"], 0.3, ["chaud", "cote"], 15),
    ("olivier", "buisson", "fruit", "Olivier", "Olive tree", 10, 3, 8, ["printemps"], 0.2, ["chaud", "cote", "desert"], 10),
    ("oranger", "buisson", "fruit", "Oranger", "Orange tree", 9, 5, 5, ["printemps"], 0.5, ["chaud", "littoral", "cote"], 25),
    ("dattier", "buisson", "fruit", "Dattier", "Date palm", 12, 5, 11, ["ete"], 0.3, ["desert", "chaud"], 5),
    ("noisetier", "buisson", "fruit", "Noisetier", "Hazel", 8, 3, 9, ["printemps"], 0.4, ["tempere", "foret", "froid"], 15),
    ("noyer", "buisson", "fruit", "Noyer", "Walnut tree", 12, 4, 12, ["printemps"], 0.5, ["tempere", "foret"], 25),
    ("amandier", "buisson", "fruit", "Amandier", "Almond tree", 9, 3, 10, ["printemps"], 0.2, ["chaud", "desert", "cote"], 10),
    ("bananier", "buisson", "fruit", "Bananier", "Banana plant", 6, 6, 9, ["printemps", "ete"], 0.9, ["chaud", "humide", "marecage"], 30),
]

WUXING = {"cereale": {"bois": 0.6, "terre": 0.4}, "legume": {"bois": 0.8, "eau": 0.2}, "racine": {"terre": 0.6, "bois": 0.4},
          "legumineuse": {"bois": 0.7, "terre": 0.3}, "fruit": {"bois": 0.5, "eau": 0.3, "feu": 0.2}, "fibre": {"bois": 1.0},
          "oleagineux": {"feu": 0.4, "bois": 0.6}}
POTENTIEL = {"cereale": {"endurance": 1}, "legume": {"volonte": 1}, "racine": {"endurance": 1}, "legumineuse": {"force": 1},
             "fruit": {"charisme": 1}, "fibre": {}, "oleagineux": {"perception": 1}}
# ce que le fruit rend en plus au sac : la fibre n'est pas un aliment mais on en mange les graines
NOM_FRUIT = {"pommier": ("Pomme", "Apple"), "poirier": ("Poire", "Pear"), "prunier": ("Prune", "Plum"), "cerisier": ("Cerise", "Cherry"),
             "figuier": ("Figue", "Fig"), "olivier": ("Olive", "Olive"), "oranger": ("Orange", "Orange"), "dattier": ("Datte", "Date"),
             "noisetier": ("Noisette", "Hazelnut"), "noyer": ("Noix", "Walnut"), "amandier": ("Amande", "Almond"), "bananier": ("Banane", "Banana"),
             "fraisier": ("Fraise", "Strawberry"), "groseillier": ("Groseille", "Currant"), "cassissier": ("Cassis", "Blackcurrant"),
             "lin": ("Graines de lin", "Flax seeds"), "chanvre": ("Graines de chanvre", "Hemp seeds"), "tournesol": ("Graines de tournesol", "Sunflower seeds"),
             "colza": ("Graines de colza", "Rapeseed"), "canne_a_sucre": ("Canne à sucre", "Sugar cane")}

# id, gabarit (l'espèce sauvage dont on copie le corps), fr, en, teinte, stats (force, dex, end, vol, per, cha),
# elevage : produits [(materiau, n, saison)], fourrage, naissance_chance, abattage {…}, biomes
BETAIL = [
    ("vache", "bison", "Vache", "Cow", [0.55, 0.45, 0.35], (11, 6, 12, 4, 8, 4), [("lait", 3, "")], 2, 0.08, {"viande_crue": 8, "cuir": 2, "suif": 2}, ["tempere", "plaine", "humide", "froid"]),
    ("mouton", "mouflon", "Mouton", "Sheep", [0.85, 0.82, 0.75], (7, 8, 9, 4, 9, 4), [("laine", 2, "printemps"), ("lait", 1, "")], 1, 0.12, {"viande_crue": 3, "cuir": 1, "suif": 1}, ["tempere", "froid", "montagne", "plaine"]),
    ("chevre", "mouflon", "Chèvre", "Goat", [0.6, 0.55, 0.5], (8, 11, 10, 6, 11, 5), [("lait", 2, "")], 1, 0.14, {"viande_crue": 2, "cuir": 1}, ["montagne", "chaud", "desert", "tempere"]),
    ("cochon", "sanglier", "Cochon", "Pig", [0.9, 0.7, 0.7], (10, 7, 11, 4, 9, 3), [], 2, 0.25, {"viande_crue": 6, "cuir": 1, "suif": 3}, ["tempere", "humide", "foret", "plaine"]),
    ("poule", "canard_sauvage", "Poule", "Hen", [0.75, 0.5, 0.3], (3, 9, 5, 3, 9, 3), [("oeuf", 3, "")], 1, 0.3, {"viande_crue": 1, "plume": 1}, ["tempere", "chaud", "plaine", "humide"]),
    ("oie", "canard_sauvage", "Oie", "Goose", [0.9, 0.9, 0.9], (5, 8, 7, 5, 11, 4), [("oeuf", 1, ""), ("plume", 2, "ete")], 1, 0.15, {"viande_crue": 2, "plume": 1}, ["froid", "tempere", "humide"]),
    ("canard", "canard_sauvage", "Canard", "Duck", [0.4, 0.5, 0.35], (4, 9, 6, 4, 10, 4), [("oeuf", 2, ""), ("plume", 1, "")], 1, 0.2, {"viande_crue": 1, "plume": 1}, ["humide", "marecage", "cote", "tempere"]),
    ("lapin", "lievre", "Lapin", "Rabbit", [0.7, 0.65, 0.6], (3, 12, 6, 3, 11, 5), [], 1, 0.35, {"viande_crue": 1, "cuir": 1}, ["tempere", "plaine", "foret"]),
    ("ane", "cheval_sauvage", "Âne", "Donkey", [0.5, 0.45, 0.4], (11, 7, 13, 6, 9, 4), [], 2, 0.05, {"viande_crue": 4, "cuir": 2}, ["chaud", "montagne", "desert", "tempere"]),
    ("cheval", "cheval_sauvage", "Cheval", "Horse", [0.5, 0.35, 0.25], (12, 11, 13, 6, 10, 6), [("crin", 1, "ete")], 2, 0.05, {"viande_crue": 6, "cuir": 2}, ["plaine", "tempere"]),
    ("buffle", "bison", "Buffle", "Water buffalo", [0.3, 0.3, 0.3], (14, 5, 14, 4, 7, 3), [("lait", 2, "")], 3, 0.07, {"viande_crue": 9, "cuir": 3, "suif": 2}, ["humide", "marecage", "chaud"]),
    ("yak", "bison", "Yak", "Yak", [0.25, 0.2, 0.18], (13, 5, 14, 5, 8, 3), [("lait", 1, ""), ("laine", 2, "printemps")], 2, 0.07, {"viande_crue": 7, "cuir": 2, "suif": 2}, ["froid", "montagne", "toundra"]),
    ("lama", "mouflon", "Lama", "Llama", [0.8, 0.7, 0.55], (8, 9, 11, 5, 10, 5), [("laine", 2, "printemps")], 1, 0.08, {"viande_crue": 3, "cuir": 1}, ["montagne", "froid"]),
    ("dromadaire", "chameau", "Dromadaire", "Dromedary", [0.75, 0.6, 0.4], (12, 7, 15, 6, 9, 4), [("lait", 2, "")], 2, 0.05, {"viande_crue": 8, "cuir": 2, "suif": 3}, ["desert", "chaud"]),
]

# les matières et objets que le bétail rend et qui doivent exister
OEUF = collections.OrderedDict([("name_key", "item.oeuf.name"), ("type", "consommable"), ("equip_slot", ""), ("nutrition", 6),
    ("soin_des", ""), ("mana", 0), ("statut", ""), ("statut_ticks", 0), ("risque", {}), ("potentiel", {"endurance": 1}), ("cru", True),
    ("poids", 0), ("quantite", 1), ("tags", ["consommable", "empilable", "ingredient", "animal"]), ("wuxing", {"eau": 0.5, "terre": 0.5})])


def lire(p):
    with io.open(p, encoding='utf-8') as f:
        return json.load(f, object_pairs_hook=collections.OrderedDict)


def ecrire(p, d):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with io.open(p, 'w', encoding='utf-8', newline='') as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write('\n')


def locale(cles):
    """cles : {loc: [(cle, texte)]} — ajoute ce qui manque, remplace ce qui existe pour ces clés."""
    for loc, lignes in cles.items():
        p = os.path.join(RACINE, 'locale', loc + '.csv')
        with io.open(p, encoding='utf-8') as f:
            contenu = f.read().split('\n')
        voulues = collections.OrderedDict((k, v) for k, v in lignes)
        sortie = []
        for l in contenu:
            k = l.split(',')[0]
            if k in voulues:
                continue
            sortie.append(l)
        while sortie and sortie[-1] == '':
            sortie.pop()
        for k, v in voulues.items():
            sortie.append('%s,"%s"' % (k, v) if (',' in v or "'" in v) else '%s,%s' % (k, v))
        with io.open(p, 'w', encoding='utf-8', newline='') as f:
            f.write('\n'.join(sortie) + '\n')


def main():
    fr, en = [], []
    modele_item = lire(os.path.join(DATA, 'items', 'consommable', 'ble.json'))
    n_plantes = 0
    for (pid, cat, fam, nfr, nen, duree, recolte, nutrition, saisons, eau, biomes, fert) in PLANTES:
        p = os.path.join(DATA, 'plants', cat, pid + '.json')
        if os.path.exists(p):
            d = lire(p)
        else:
            d = collections.OrderedDict([("name_key", "plant.%s.name" % pid), ("categorie", cat), ("nutrition", nutrition),
                ("bonus_potentiel", POTENTIEL[fam]), ("wuxing", WUXING[fam]), ("duree_jours", duree), ("recolte_base", recolte),
                ("tags", [cat] if cat == "culture" else ["buisson", "verger"]), ("saisons", saisons), ("besoin_eau", eau)])
        d["famille"] = fam
        d["conditions"] = collections.OrderedDict([("biomes", biomes), ("fertilite_min", fert)])
        ecrire(p, d)
        n_plantes += 1
        pi = os.path.join(DATA, 'items', 'consommable', pid + '.json')
        if not os.path.exists(pi):
            it = collections.OrderedDict(modele_item)
            it["name_key"] = "item.%s.name" % pid
            it["nutrition"] = nutrition
            it["potentiel"] = POTENTIEL[fam]
            it["wuxing"] = WUXING[fam]
            it["tags"] = ["consommable", "empilable", "culture" if cat == "culture" else "fruit", "ingredient"]
            ecrire(pi, it)
        if nfr is not None:
            fr.append(("plant.%s.name" % pid, nfr))
            en.append(("plant.%s.name" % pid, nen))
            ffr, fen = NOM_FRUIT.get(pid, (nfr, nen))
            fr.append(("item.%s.name" % pid, ffr))
            en.append(("item.%s.name" % pid, fen))
    # le bétail
    for (cid, gabarit, nfr, nen, teinte, stats, produits, fourrage, naissance, abattage, biomes) in BETAIL:
        base = lire(os.path.join(DATA, 'creatures', 'bete', gabarit + '.json'))
        c = collections.OrderedDict(base)
        c["name_key"] = "creature.%s.name" % cid
        c["race"] = cid
        c["teinte"] = teinte
        c["corps"] = collections.OrderedDict(base["corps"])
        c["corps"]["stats"] = collections.OrderedDict(zip(["force", "dexterite", "endurance", "volonte", "perception", "charisme"], stats))
        c["ai_profile"] = "proie"
        c["rare_chance"] = 0.0
        c["tags"] = ["bete", "paisible", "domestique"]
        c["elevage"] = collections.OrderedDict([
            ("produits", [collections.OrderedDict([("materiau", m), ("n", n)] + ([("saison", s)] if s else [])) for (m, n, s) in produits]),
            ("fourrage", fourrage), ("naissance_chance", naissance), ("abattage", collections.OrderedDict(abattage)), ("biomes", biomes)])
        c.pop("_doc", None)
        ecrire(os.path.join(DATA, 'creatures', 'bete', cid + '.json'), c)
        fr.append(("creature.%s.name" % cid, nfr))
        en.append(("creature.%s.name" % cid, nen))
    po = os.path.join(DATA, 'items', 'consommable', 'oeuf.json')
    if not os.path.exists(po):
        ecrire(po, OEUF)
    fr.append(("item.oeuf.name", "Œuf"))
    en.append(("item.oeuf.name", "Egg"))
    locale({'fr': fr, 'en': en})

    # villes.json : les tables par biome dérivées des conditions
    pv = os.path.join(DATA, 'villes.json')
    v = lire(pv)
    tags_biomes = set()
    for f in os.listdir(os.path.join(DATA, 'biomes')):
        if f.endswith('.json') and not f.startswith('_'):
            tags_biomes.update(lire(os.path.join(DATA, 'biomes', f)).get('tags', []))
    cultures = collections.OrderedDict()
    vergers = collections.OrderedDict()
    cultures["_defaut"] = [pid for (pid, cat, *_r) in PLANTES if cat == "culture" and not _r[-2]]
    vergers["_defaut"] = ["framboisier", "myrtillier"] + [pid for (pid, cat, *_r) in PLANTES if cat == "buisson" and not _r[-2]]
    for t in sorted(tags_biomes):
        lc = [pid for (pid, cat, *_r) in PLANTES if cat == "culture" and t in _r[-2]]
        lv = [pid for (pid, cat, *_r) in PLANTES if cat == "buisson" and t in _r[-2]]
        if lc:
            cultures[t] = lc
        if lv:
            vergers[t] = lv
    v["champs"]["cultures_par_biome"] = cultures
    v["champs"]["hors_climat"] = collections.OrderedDict([("rendement", 0.5)])
    v["champs"]["legumineuse"] = collections.OrderedDict([("fertilite_rendue", 6)])
    if "vergers" in v and isinstance(v["vergers"], dict):
        cle = "especes_par_biome" if "especes_par_biome" in v["vergers"] else ("buissons_par_biome" if "buissons_par_biome" in v["vergers"] else None)
        if cle:
            v["vergers"][cle] = vergers
    especes = collections.OrderedDict()
    especes["_defaut"] = ["vache", "mouton", "cochon", "poule"]
    for t in sorted(tags_biomes):
        l = [cid for (cid, *_r) in BETAIL if t in _r[-1]]
        if l:
            especes[t] = l
    v["enclos"]["especes_par_biome"] = especes
    ecrire(pv, v)
    print("plantes : %d · bétail : %d · cultures par biome : %d entrées · bétail par biome : %d entrées" % (n_plantes, len(BETAIL), len(cultures), len(especes)))


if __name__ == '__main__':
    main()
