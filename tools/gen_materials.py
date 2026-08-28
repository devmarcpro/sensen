# -*- coding: utf-8 -*-
"""Transcrit les 11 catalogues de matériaux (docs: Catalogue matériaux — *) en data/materials/*.json.

    python tools/gen_materials.py

Sources (la note fait foi, jamais ce script) :
  - les tables des 11 catalogues (13 stats, colonnes Dur…Fri) — « la table fait foi » ;
  - la palette (data/palette_materiaux.json, transcrite de Palette de couleurs des matériaux) ;
  - les surcharges Wu Xing (docs: Décision — Surcharges Wu Xing des matériaux) ;
  - les catégories (data/material_categories.json : outil, compétence, station).
Écrit aussi les clés `material.<id>.name` dans locale/fr.csv (section dédiée, régénérée).
"""
import io, json, os, re, unicodedata, glob

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DOCS = os.path.join(RACINE, "docs", "09 - Contenu")
SORTIE = os.path.join(RACINE, "godot", "data", "materials")
PALETTE = os.path.join(RACINE, "godot", "data", "palette_materiaux.json")
CATEGORIES = os.path.join(RACINE, "godot", "data", "material_categories.json")
LOCALE = os.path.join(RACINE, "godot", "locale", "fr.csv")
STATS = ["durete", "densite", "valeur_base", "conductivite_mana", "flammabilite", "isolation",
         "conductivite_electrique", "flottabilite", "luminosite", "fertilite", "transparence", "elasticite", "friction"]
# fichier de catalogue → catégorie (Catégories de matériaux : 11 catégories figées)
CATALOGUES = {
    "Bois": "bois", "Métaux": "metal", "Roches": "roche", "Minéraux": "mineral", "Gemmes": "gemme",
    "Terres": "terre", "Végétaux et fibres": "vegetal", "Liquides": "liquide", "Fossiles": "fossile",
    "Météorologiques": "meteorologique", "Synthétiques": "synthetique",
}
ORGANIQUES = {"bois", "vegetal"}


def slug(n):
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


def nom_court(nom):
    # « Aluminium (bauxite) » → id `aluminium` ; « Guano/salpêtre de grotte » → `guano` ; nom affiché complet
    return re.sub(r"\s*\(.*?\)\s*", "", nom).split("/")[0].strip()


palette = json.load(io.open(PALETTE, encoding="utf-8"))
categories = json.load(io.open(CATEGORIES, encoding="utf-8"))

# ---------------------------------------------------------------- surcharges Wu Xing
note_wx = glob.glob(os.path.join(RACINE, "docs", "**", "Décision — Surcharges Wu Xing des matériaux.md"), recursive=True)[0]
surcharges = {}
for ligne in io.open(note_wx, encoding="utf-8"):
    if not ligne.startswith("|") or "wuxing" in ligne or ligne.startswith("|---"):
        continue
    cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
    # une ligne peut porter deux paires (table des gemmes)
    for i in range(0, len(cellules) - 1, 3 if len(cellules) >= 5 else 2):
        noms, vec = cellules[i], cellules[i + 1]
        if not noms or not vec or "[[" in noms:
            continue
        v = {}
        for el, val in re.findall(r"(bois|feu|terre|metal|eau)\s*([0-9.]+)", vec):
            v[el] = float(val)
        if not v:
            continue
        for n in noms.split(","):
            n = re.sub(r"\s*\(.*?\)", "", n).replace("*", "").strip()
            surcharges[slug(n)] = v
surcharges["os"] = surcharges.get("os_fossile", {"bois": 0.4, "terre": 0.6})

# ---------------------------------------------------------------- tables
materiaux = {}
for fichier, cat in CATALOGUES.items():
    chemin = os.path.join(DOCS, "Catalogue matériaux — %s.md" % fichier)
    for ligne in io.open(chemin, encoding="utf-8"):
        if not ligne.startswith("|") or ligne.startswith("|---") or ligne.startswith("| Matériau"):
            continue
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if len(cellules) < 14:
            continue
        nom = cellules[0].replace("**", "").strip()
        valeurs = cellules[1:14]
        stats = {}
        for cle, v in zip(STATS, valeurs):
            stats[cle] = 0 if v in ("—", "-", "") else int(v)
        ident = slug(nom_court(nom))
        if ident not in palette:
            raise SystemExit("couleur absente de la palette pour « %s » (%s)" % (nom, ident))
        c = categories[cat]
        tags = ["organique"] if cat in ORGANIQUES else []
        if cat == "vegetal" and ident in ("cuir", "fourrure", "laine", "soie"):
            tags = ["organique", "animal"]
        m = {
            "name_key": "material.%s.name" % ident,
            "category": cat,
            "stats": stats,
            "tags": tags,
            "color": palette[ident]["hex"],
            "noise": {"type": "procedural", "seed_offset": len(materiaux) + 1, "amplitude": 0.08, "scale": 4},
            "harvest": {"tool_category": c["tool"], "skill": c["harvest_skill"]},
            "world_gen": {"mode": "biome", "biome_tags": []},
            "wuxing": surcharges.get(ident),
            "composition": None,
        }
        if cat == "liquide" and cellules[8] == "—":
            m["tags"].append("liquide")
        materiaux[ident] = (nom, m)

# ---------------------------------------------------------------- écriture
for f in glob.glob(os.path.join(SORTIE, "**", "*.json"), recursive=True):
    if not os.path.basename(f).startswith("_"):
        os.remove(f)
for ident, (nom, m) in materiaux.items():
    dossier = os.path.join(SORTIE, str(m.get("category", "divers")))   # range par categorie (2026-08-29)
    if not os.path.isdir(dossier):
        os.makedirs(dossier)
    with io.open(os.path.join(dossier, ident + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(m, f, ensure_ascii=False, indent=2)
        f.write("\n")

# locale : une section régénérée, entre deux marqueurs
s = io.open(LOCALE, encoding="utf-8").read()
debut, fin = "# --- matériaux (tools/gen_materials.py) ---\n", "# --- fin matériaux ---\n"
bloc = debut + "".join('material.%s.name,%s\n' % (i, ('"%s"' % n) if "," in n else n) for i, (n, _) in materiaux.items()) + fin
if debut in s:
    s = s[:s.index(debut)] + bloc + s[s.index(fin) + len(fin):]
else:
    s = s.rstrip("\n") + "\n" + bloc
io.open(LOCALE, "w", encoding="utf-8", newline="\n").write(s)
print("%d matériaux -> %s ; %d surcharges Wu Xing appliquées" % (len(materiaux), SORTIE, sum(1 for _, m in materiaux.values() if m["wuxing"])))
