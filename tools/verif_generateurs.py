# -*- coding: utf-8 -*-
"""Le generateur de materiaux est-il encore fidele ? (2026-09-08)

    python tools/verif_generateurs.py

Le 2026-09-08 on a decouvert que `tools/gen_materials.py` DETRUIRAIT 24 des 247 fiches s il tournait (les 20 matieres
animales, dont aucun catalogue n etait declare, et 4 aciers dont l id abrege ne se deduit pas du nom), et effacerait
sept champs ajoutes apres lui : palier, stats_base, sous_categorie, tags, noise.seed_offset, wuxing, harvest. Il ne
s en apercevait pas parce qu il MOURAIT avant, sur la premiere couleur de palette manquante — un garde-fou accidentel.

Cet outil relance la chaine (palette puis materiaux) et compare CHAQUE CHAMP de CHAQUE fiche a ce qu elle etait. Il
sort en echec a la moindre difference. A lancer apres toute retouche d un catalogue, de la palette ou du generateur.
"""
import collections
import glob
import io
import json
import os
import subprocess
import sys

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MATS = os.path.join(RACINE, "godot", "data", "materials")


def lire_tout():
    d = {}
    for f in glob.glob(os.path.join(MATS, "**", "*.json"), recursive=True):
        b = os.path.basename(f)
        if b.startswith("_"):
            continue
        d[b[:-5]] = json.load(io.open(f, encoding="utf-8"))
    return d


avant = lire_tout()
print("%d fiches avant" % len(avant))
for outil in ("gen_palette.py", "gen_materials.py"):
    r = subprocess.run([sys.executable, os.path.join(RACINE, "tools", outil)],
                       capture_output=True, cwd=RACINE)
    if r.returncode != 0:
        print("ÉCHEC : %s est sorti en erreur\n%s" % (outil, r.stdout.decode("utf-8", "replace")))
        raise SystemExit(1)
apres = lire_tout()

perdus = sorted(set(avant) - set(apres))
neufs = sorted(set(apres) - set(avant))
diffs = collections.Counter()
exemples = collections.defaultdict(list)
for i in sorted(set(avant) & set(apres)):
    for k in set(avant[i]) | set(apres[i]):
        if avant[i].get(k) != apres[i].get(k):
            diffs[k] += 1
            if len(exemples[k]) < 3:
                exemples[k].append("%s : %r → %r" % (i, avant[i].get(k), apres[i].get(k)))

if perdus:
    print("ÉCHEC : %d fiche(s) DÉTRUITE(S) : %s" % (len(perdus), " ".join(perdus)))
if neufs:
    print("ÉCHEC : %d fiche(s) créée(s) en double : %s" % (len(neufs), " ".join(neufs)))
for k, v in diffs.most_common():
    print("ÉCHEC : le champ « %s » change sur %d fiche(s)" % (k, v))
    for e in exemples[k]:
        print("    " + e[:200])
if perdus or neufs or diffs:
    print("\nLe générateur n'est plus fidèle à la donnée. Ne pas commiter tel quel.")
    raise SystemExit(1)
print("%d fiches après : le générateur les reproduit toutes, champ par champ" % len(apres))
