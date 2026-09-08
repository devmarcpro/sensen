# -*- coding: utf-8 -*-
"""Remet les catalogues de materiaux en accord avec les fiches (2026-09-08).

ATTENTION — c est le chemin INVERSE de tools/gen_materials.py, qui lui ecrit les fiches DEPUIS les tables.
Les deux ne doivent jamais tourner l un apres l autre sans que le designer ait tranche le sens de la verite
(voir « Vers la production », ligne 46). Celui-ci existe parce que la donnee portait des decisions plus
recentes que la note — la passe d equilibrage du 2026-09-02, l etirement des stats, 94 materiaux ajoutes
sans jamais etre reverses dans les catalogues.

Mesure de depart : 94 materiaux sur 248 n avaient plus aucune ligne de table, et sur les 154 restants la durete
divergeait sur 140 fiches (le diamant : 40 dans la note, 140 dans la donnee). La donnee porte des decisions plus
recentes et deliberees que la note — la passe d equilibrage du 2026-09-02, l etirement des stats, les materiaux
ajoutes depuis. Ce script rend donc les tables conformes a la donnee, SANS toucher a la prose ni aux callouts.

L ordre editorial des lignes existantes est preserve (Pierre avant Granit : c est voulu) ; les manquants sont ajoutes
a la fin, par ordre alphabetique. La categorie `animal`, qui n avait aucun catalogue, en recoit un.

    python regen_catalogues.py [--verifier]
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
DOCS = os.path.join(RACINE, 'docs', '09 - Contenu')
MATS = os.path.join(RACINE, 'godot', 'data', 'materials')
LOCALE = os.path.join(RACINE, 'godot', 'locale', 'fr.csv')

STATS = ["durete", "densite", "valeur_base", "conductivite_mana", "flammabilite", "isolation",
         "conductivite_electrique", "flottabilite", "luminosite", "fertilite", "transparence", "elasticite", "friction"]
ENTETE = "| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |"
SEPAR = "|---|--|--|--|--|--|--|--|--|--|--|--|--|--|"

CAT_FICHIER = {
    "bois": "Bois", "metal": "Métaux", "roche": "Roches", "mineral": "Minéraux", "gemme": "Gemmes",
    "terre": "Terres", "vegetal": "Végétaux et fibres", "liquide": "Liquides", "fossile": "Fossiles",
    "meteorologique": "Météorologiques", "synthetique": "Synthétiques", "animal": "Animal",
}


def slug(n):
    n = unicodedata.normalize('NFD', n)
    n = ''.join(c for c in n if unicodedata.category(c) != 'Mn')
    n = re.sub(r"\s*\(.*?\)", "", n).replace("*", "").strip().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


# ------------------------------------------------------------------ les donnees font foi
noms = {}
for l in io.open(LOCALE, encoding='utf-8'):
    if l.startswith('material.') and '.name,' in l:
        noms[l.split(',', 1)[0][len('material.'):-len('.name')]] = l.split(',', 1)[1].strip().strip('"')

fiches = {}
par_cat = collections.defaultdict(list)
for f in sorted(glob.glob(os.path.join(MATS, '**', '*.json'), recursive=True)):
    i = os.path.basename(f)[:-5]
    if i.startswith('_'):
        continue
    d = json.load(io.open(f, encoding='utf-8'))
    fiches[i] = d
    par_cat[d.get('category', 'divers')].append(i)


def ligne(i):
    st = fiches[i].get('stats', {})
    return "| %s | %s |" % (noms.get(i, i), " | ".join(str(int(st.get(k, 0))) for k in STATS))


verifier = '--verifier' in sys.argv
rapport = []

for cat, fich in sorted(CAT_FICHIER.items()):
    chemin = os.path.join(DOCS, 'Catalogue matériaux — %s.md' % fich)
    ids = par_cat.get(cat, [])
    if not ids:
        continue
    if not os.path.exists(chemin):
        rapport.append(('CRÉÉ', fich, len(ids), 0))
        if not verifier:
            titre = fich if fich != 'Animal' else 'Animal'
            s = ("""---
aliases: ["Catalogue %s", "%s"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les matières d'origine animale du catalogue — ce que le dépeçage rend, et ce que l'artisanat en fait. Elles existaient
dans les données depuis l'origine sans avoir jamais eu de catalogue : la table ci-dessous a été écrite le 2026-09-08 à
partir des fiches, quand la vérification a montré que 94 matériaux sur 248 n'avaient aucune ligne de note.

*Colonnes : Dur, Den, Val, CMa, Fla, Iso, CÉl, Flo, Lum, Fer, Tra, Éla, Fri — voir [[Matériaux — 13 stats]].*

**%s (%d) — outil : couteau, compétence Dépeçage**

%s
%s
%s

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Craft compositionnel]], [[Récolte]]
- **Voir aussi** : [[Application des stats de matériau]], [[Dépeçage]]
""" % (titre, titre, titre, len(ids), ENTETE, SEPAR, "\n".join(ligne(i) for i in sorted(ids, key=lambda x: noms.get(x, x)))))
            io.open(chemin, 'w', encoding='utf-8', newline='').write(s)
        continue

    src = io.open(chemin, encoding='utf-8').read()
    lignes = src.split('\n')
    # reperer la table : l entete, le separateur, puis les lignes qui commencent par « | »
    try:
        i0 = next(k for k, l in enumerate(lignes) if l.startswith('| Matériau |'))
    except StopIteration:
        rapport.append(('SANS TABLE', fich, len(ids), 0))
        continue
    i1 = i0 + 2
    while i1 < len(lignes) and lignes[i1].startswith('|'):
        i1 += 1
    ordre, vus = [], set()
    for l in lignes[i0 + 2:i1]:
        c = [x.strip() for x in l.strip().strip('|').split('|')]
        s_id = slug(c[0].replace('**', ''))
        if s_id in fiches and fiches[s_id].get('category') == cat and s_id not in vus:
            ordre.append(s_id)
            vus.add(s_id)
    ajouts = sorted([i for i in ids if i not in vus], key=lambda x: noms.get(x, x))
    corriges = sum(1 for i in ordre
                   if ligne(i) != next((l for l in lignes[i0 + 2:i1] if slug(l.strip().strip('|').split('|')[0].replace('**', '').strip()) == i), None))
    rapport.append(('à jour' if not ajouts and not corriges else 'refait', fich, len(ajouts), corriges))
    if verifier:
        continue
    table = [ENTETE, SEPAR] + [ligne(i) for i in ordre + ajouts]
    lignes[i0:i1] = table
    src = '\n'.join(lignes)
    # le compte annonce au-dessus de la table (« **Roches (20) — outil : … **»)
    src = re.sub(r"\*\*([^*(]+) \((\d+)\)( — outil)", lambda m: "**%s (%d)%s" % (m.group(1), len(ids), m.group(3)), src, count=1)
    io.open(chemin, 'w', encoding='utf-8', newline='').write(src)

print("%-12s %-24s %8s %10s" % ('état', 'catalogue', 'ajoutés', 'corrigés'))
for e, f, a, c in rapport:
    print("%-12s %-24s %8d %10d" % (e, f, a, c))
print("\n%d matériaux en données, %d dans les tables après passage" % (len(fiches), sum(len(v) for v in par_cat.values())))
