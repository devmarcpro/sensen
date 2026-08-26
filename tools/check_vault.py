# -*- coding: utf-8 -*-
"""Vérifie l'intégrité du coffre docs/ : liens morts, frontmatter, comptages annoncés.

    python tools/check_vault.py

Sortie non nulle si une erreur est trouvée. À lancer avant chaque commit.
"""
import io, os, re, sys, glob

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs")
ROOT = os.path.normpath(ROOT)
FRONT = ("aliases", "tags", "domaine", "statut", "etape")
erreurs, avertis = [], []

# --- 1. index des notes et de leurs alias -----------------------------------
cibles, notes = {}, {}
for p in glob.glob(os.path.join(ROOT, "*", "*.md")):
    nom = os.path.splitext(os.path.basename(p))[0]
    t = io.open(p, encoding="utf-8").read()
    notes[p] = t
    cibles[nom.lower()] = nom
    m = re.search(r'^aliases:\s*\[(.*?)\]\s*$', t, re.M)
    if m:
        for a in re.findall(r'"([^"]*)"', m.group(1)):
            cibles.setdefault(a.lower(), nom)

# --- 2. frontmatter obligatoire ---------------------------------------------
for p, t in notes.items():
    rel = os.path.relpath(p, ROOT)
    if not t.startswith("---\n"):
        erreurs.append("%s : pas de frontmatter" % rel); continue
    tete = t.split("---", 2)[1]
    for champ in FRONT:
        if not re.search(r'^%s:' % champ, tete, re.M):
            erreurs.append("%s : champ « %s » manquant" % (rel, champ))
    if "## Liens" not in t:
        avertis.append("%s : pas de section « ## Liens »" % rel)

# --- 3. liens morts (hors blocs de code) ------------------------------------
for p, t in notes.items():
    rel = os.path.relpath(p, ROOT)
    sans_code = re.sub(r'```.*?```', '', t, flags=re.S)
    sans_code = re.sub(r'`[^`\n]*`', '', sans_code)
    for lien in re.findall(r'\[\[([^\]|#]+)', sans_code):
        cle = lien.strip().lower()
        if cle and cle not in cibles:
            erreurs.append("%s : lien mort [[%s]]" % (rel, lien.strip()))

# --- 4. comptages annoncés vs réels -----------------------------------------
DOMAINES = ["Vision", "Monde", "Combat", "Progression", "Objets",
            "Êtres", "Société", "Technique", "Contenu", "Ouvert"]
DOSSIER = {"Vision": "01 - Vision", "Monde": "02 - Monde", "Combat": "03 - Combat",
           "Progression": "04 - Progression", "Objets": "05 - Objets",
           "Êtres": "06 - Êtres", "Société": "07 - Société",
           "Technique": "08 - Technique", "Contenu": "09 - Contenu",
           "Ouvert": "99 - Ouvert"}
index = io.open(os.path.join(ROOT, "00 - Index", "Sensen — Index général.md"),
                encoding="utf-8").read()
for dom in DOMAINES:
    reel = len(glob.glob(os.path.join(ROOT, DOSSIER[dom], "*.md")))
    carte = os.path.join(ROOT, "00 - Index", "Carte — %s.md" % dom)
    t = io.open(carte, encoding="utf-8").read()
    m = re.search(r'\b(\d+) notes\.', t)
    if not m:
        avertis.append("Carte — %s : n'annonce aucun compte" % dom)
    elif int(m.group(1)) != reel:
        erreurs.append("Carte — %s : annonce %s notes, il y en a %d"
                       % (dom, m.group(1), reel))
    m = re.search(r'\| \*\*\[\[Carte — %s\]\]\*\* \|[^|]*\| (\d+) \|' % re.escape(dom), index)
    if m and int(m.group(1)) != reel:
        erreurs.append("Index général : annonce %s notes pour %s, il y en a %d"
                       % (m.group(1), dom, reel))

# --- rapport -----------------------------------------------------------------
total = sum(len(glob.glob(os.path.join(ROOT, d, "*.md"))) for d in DOSSIER.values())
total += len(glob.glob(os.path.join(ROOT, "00 - Index", "*.md")))
print("%d notes, %d cibles de lien" % (total, len(cibles)))
for a in avertis: print("  avertissement : %s" % a)
for e in erreurs: print("  ERREUR : %s" % e)
print("OK" if not erreurs else "%d erreur(s)" % len(erreurs))
sys.exit(1 if erreurs else 0)
