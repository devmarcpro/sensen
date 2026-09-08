# -*- coding: utf-8 -*-
"""Complete la note de palette depuis les fiches de materiau (2026-09-08).

Meme constat que pour les onze catalogues : les 247 fiches portent 247 couleurs DISTINCTES, la note n en declare que
156. Les 91 autres ont ete posees dans la donnee sans jamais etre reversees. Ce script ajoute a chaque ligne de la note
les materiaux de sa categorie qui lui manquent, dans l ordre des fiches, sans toucher a ceux qui y sont deja.

C est le chemin INVERSE de tools/gen_palette.py, qui lui ecrit le JSON DEPUIS la note. Comme pour regen_catalogues.py,
les deux ne doivent pas tourner l un apres l autre sans que le designer ait tranche le sens de la verite (voir « Vers la
production », ligne 46).

    python tools/regen_palette.py [--verifier]
"""
import collections
import glob
import io
import json
import os
import re
import sys
import unicodedata

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
NOTE = os.path.join(RACINE, "docs", "09 - Contenu", "Palette de couleurs des matériaux.md")
MATS = os.path.join(RACINE, "godot", "data", "materials")
LOCALE = os.path.join(RACINE, "godot", "locale", "fr.csv")

# la ligne de la note qui accueille chaque categorie de fiche
LIGNES = {
    "bois": "**Bois :**", "metal": "**Métaux :**", "roche": "**Roches :**", "terre": "**Terres :**",
    "vegetal": "**Végétaux/fibres :**", "liquide": "**Liquides :**", "mineral": "**Minéraux :**",
    "meteorologique": "**Météorologiques :**", "fossile": "**Fossiles :**", "gemme": "**Gemmes :**",
    "synthetique": "**Synthétiques :**", "animal": "**Animal :**",
}


def slug(n):
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


noms = {}
for l in io.open(LOCALE, encoding="utf-8"):
    if l.startswith("material.") and ".name," in l:
        noms[l.split(",", 1)[0][len("material."):-len(".name")]] = l.split(",", 1)[1].strip().strip('"')

par_cat = collections.defaultdict(list)
couleurs = {}
for f in sorted(glob.glob(os.path.join(MATS, "**", "*.json"), recursive=True)):
    i = os.path.basename(f)[:-5]
    if i.startswith("_"):
        continue
    d = json.load(io.open(f, encoding="utf-8"))
    par_cat[d.get("category", "divers")].append(i)
    couleurs[i] = str(d.get("color", ""))   # la casse de la fiche fait foi : la changer diffuse un diff inutile

s = io.open(NOTE, encoding="utf-8").read()
deja = set()
for nom, hexa in re.findall(r"([A-ZÉÈ][\wéèêàâîôûç' \-]*?) (#[0-9A-Fa-f]{6})", s):
    deja.add(slug(nom))
# les quatre fiches a l id abrege : la note les ecrit sous leur nom long
ALIAS = {"acier_inoxydable": "acier_inox", "acier_au_tungstene": "acier_tungstene",
         "acier_au_vanadium": "acier_vanadium", "essence_de_terebenthine": "essence_terebenthine"}
for long_id, court in ALIAS.items():
    if long_id in deja:
        deja.add(court)

verifier = "--verifier" in sys.argv
total = 0
for cat, ids in sorted(par_cat.items()):
    manquants = [i for i in ids if i not in deja and couleurs.get(i)]
    if not manquants:
        continue
    total += len(manquants)
    # La note écrit les noms avec une majuscule (son motif de lecture l'exige : `[A-ZÉÈ]...`), et quelques
    # matières animales sont en minuscule dans la locale — « croc », « écaille ».
    def _maj(n):
        return n[:1].upper() + n[1:] if n else n
    ajout = " · ".join("%s %s" % (_maj(noms.get(i, i)), couleurs[i]) for i in manquants)
    entete = LIGNES.get(cat)
    print("%-16s %3d à ajouter" % (cat, len(manquants)))
    if verifier:
        continue
    if entete and entete in s:
        i0 = s.index(entete)
        i1 = s.index("\n", i0)
        s = s[:i1] + " · " + ajout + s[i1:]
    else:   # une catégorie que la note n'a jamais eue (l'animal) : on lui écrit sa ligne
        ancre = "\n**Validation au boot"
        s = s.replace(ancre, "\n**%s :** %s\n%s" % (cat.capitalize(), ajout, ancre), 1)

if not verifier:
    io.open(NOTE, "w", encoding="utf-8", newline="").write(s)
print("%d couleur(s) reversée(s) dans la note" % total)
