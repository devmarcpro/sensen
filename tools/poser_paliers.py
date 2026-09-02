#!/usr/bin/env python3
"""Pose le champ `palier` (1..5) sur chaque fiche de matériau — designer, 2026-09-02.

Le palier commande où un matériau tombe, ce qu'il vaut une fois assemblé, et ce qu'il coûte à
extraire (voir « Catégories de matériaux »). Il est DÉRIVÉ, pas écrit à la main :

  - un minerai listé dans `minerais_par_etage.tiers` hérite de son tier (plafonné à 5) : ces bandes
    ont été posées par le designer, elles font foi ;
  - les autres sont classés DANS LEUR CATÉGORIE par un score de puissance, puis répartis en cinq
    quintiles. Par catégorie, parce qu'un bois de palier 5 reste un bois : on compare un chêne aux
    autres bois, pas au platine.

Le script est rejouable : il recalcule et réécrit. Une valeur corrigée à la main sera donc écrasée
au prochain passage — pour figer un palier, écrire `"palier_fixe": true` dans la fiche.
"""
import json, io, os, glob, collections

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MATS = os.path.join(RACINE, "godot", "data", "materials")

# Le score de puissance : ce qui fait qu'un matériau est convoité. La dureté pèse le plus (elle
# commande les dégâts et l'armure), la valeur marchande dit la rareté que le monde lui reconnaît,
# la conductivité de mana départage les matières magiques qui ne sont ni dures ni chères.
POIDS = {"durete": 1.0, "valeur_base": 0.8, "conductivite_mana": 0.4}


def score(stats):
    return sum(POIDS[k] * float(stats.get(k, 0)) for k in POIDS)


def main():
    tiers = {}
    chemin_tiers = os.path.join(RACINE, "godot", "data", "minerais_par_etage.json")
    for k, ids in json.load(io.open(chemin_tiers, encoding="utf-8")).get("tiers", {}).items():
        for m in ids:
            tiers[m] = min(5, max(1, int(k)))

    fiches = {}
    par_cat = collections.defaultdict(list)
    for f in glob.glob(os.path.join(MATS, "**", "*.json"), recursive=True):
        nom = os.path.basename(f)[:-5]
        if nom.startswith("_"):
            continue
        d = json.load(io.open(f, encoding="utf-8"))
        fiches[f] = (nom, d)
        par_cat[d.get("category", "?")].append((score(d.get("stats", {})), nom))

    rang = {}
    for cat, v in par_cat.items():
        v.sort()
        n = len(v)
        for i, (_, nom) in enumerate(v):
            rang[nom] = min(5, 1 + (i * 5) // max(1, n))

    change = 0
    repart = collections.Counter()
    for f, (nom, d) in sorted(fiches.items()):
        if d.get("palier_fixe"):
            repart[int(d.get("palier", 1))] += 1
            continue
        p = tiers.get(nom, rang.get(nom, 1))
        repart[p] += 1
        if d.get("palier") == p:
            continue
        # Le palier se range juste après la catégorie : on lit une fiche de haut en bas.
        neuf = {}
        for k, v in d.items():
            neuf[k] = v
            if k == "category":
                neuf["palier"] = p
        if "palier" not in neuf:
            neuf["palier"] = p
        io.open(f, "w", encoding="utf-8", newline="\n").write(
            json.dumps(neuf, ensure_ascii=False, indent=2) + "\n")
        change += 1

    print("paliers poses : %d fiches modifiees sur %d" % (change, len(fiches)))
    print("repartition :", " · ".join("palier %d : %d" % (k, repart[k]) for k in sorted(repart)))


if __name__ == "__main__":
    main()
