# -*- coding: utf-8 -*-
"""Transcrit les 11 catalogues de matériaux (docs: Catalogue matériaux — *) en data/materials/*.json.

    python tools/gen_materials.py

Sources (la note fait foi, jamais ce script) :
  - les tables des 12 catalogues (16 stats, colonnes Dur…Abs) — « la table fait foi » ;
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
# LA 14e COLONNE, `fusion` (ordre de travail 23, 2026-09-09) : la temperature en DEGRES CELSIUS ou la matiere change
# d etat, prise dans le monde reel — le champ de chaleur est deja en degres, il n y a donc pas d unite a inventer.
# Ce qui NE FOND PAS s ecrit `—` dans la table et NE_FOND_PAS ici. La note de decision disait « 0 = elle ne fond pas » :
# c etait faux, et d une facon qu on ne voit qu en ecrivant les valeurs — 0 °C est le point de fusion REEL de la glace,
# de la neige, du givre, de la grele, de l eau et du sang, c est-a-dire des six matieres que la ligne 23 cite en
# premier. Le sentinelle et la donnee se confondaient exactement la ou ca comptait.
NE_FOND_PAS = 9999
STATS = ["durete", "densite", "valeur_base", "conductivite_mana", "flammabilite", "isolation",
         "conductivite_electrique", "flottabilite", "luminosite", "fertilite", "transparence", "elasticite", "friction",
         "fusion", "portance", "absorption"]
# fichier de catalogue → catégorie (Catégories de matériaux : 11 catégories figées)
CATALOGUES = {
    "Bois": "bois", "Métaux": "metal", "Roches": "roche", "Minéraux": "mineral", "Gemmes": "gemme",
    "Terres": "terre", "Végétaux et fibres": "vegetal", "Liquides": "liquide", "Fossiles": "fossile",
    "Météorologiques": "meteorologique", "Synthétiques": "synthetique",
    "Animal": "animal",   # écrit le 2026-09-08 : les 20 matières du dépeçage n'avaient aucun catalogue, donc aucune source
}

# Quatre fiches portent un id ABRÉGÉ que le slug de leur nom ne rend pas : elles ont été renommées à la main après
# coup, et des recettes, la palette et le monde les citent sous cette forme. On ne peut donc changer ni l'id ni le nom
# affiché — la correspondance est écrite ici, une fois. Sans elle, `gen_materials.py` créait quatre fiches en double
# sous le nom long et laissait mourir les quatre vraies.
ALIAS = {
    "acier_inoxydable": "acier_inox",
    "acier_au_tungstene": "acier_tungstene",
    "acier_au_vanadium": "acier_vanadium",
    "essence_de_terebenthine": "essence_terebenthine",
    "soie_d_araignee": "soie_araignee",
}
ORGANIQUES = {"bois", "vegetal", "animal"}   # défaut pour une fiche NEUVE ; une fiche existante garde ses tags


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

# ---------------------------------------------------------------- ce que le générateur n'écrit pas, et détruirait
# `palier` (posé par tools/poser_paliers.py), `stats_base` (le témoin de l'étirement des stats, dont l'outil n'existe
# plus dans le dépôt) et `sous_categorie` (LUE PAR LE JEU — sim_objets.gd, 76 fiches) ont été ajoutées aux fiches après
# ce script. Il les effaçait en silence à chaque passage. On les relit AVANT de supprimer quoi que ce soit, et on les
# reporte sur la fiche neuve. Ajouté le 2026-09-08.
# `tags` en fait partie, et c'est le plus important : les fiches portent bien plus que le tag `organique` que ce script
# sait produire — `marin`, `toxique`, `industriel`, `os`, `os_massif`, `ivoire`, `dent_croc`, `ecaille`, `carapace`,
# `liquide`. Ils ont été posés à la main ou par un autre outil, et une exécution les rasait tous.
# `noise.seed_offset` aussi : il était dérivé du RANG d'insertion, donc le moindre matériau ajouté au milieu d'un
# catalogue décalait le bruit de tous les suivants. Préservé, il ne bouge plus jamais.
# `wuxing` et `harvest` aussi : 44 fiches portent une surcharge Wu Xing que la note de décision ne déclare pas, et
# 26 un outil de récolte plus fin que celui de leur catégorie (le corail se coupe à la dague, pas à la pioche —
# c'est à ça que sert `sous_categorie`). Comme pour les tables et la palette, la donnée porte des décisions plus
# récentes que la note : ce script ne possède plus que ce qu'il DÉDUIT des tables, et rend le reste tel quel.
CLES_PRESERVEES = ["palier", "palier_fixe", "stats_base", "sous_categorie", "tags", "noise", "wuxing", "harvest"]
sans_couleur = []
conserve = {}
for f in glob.glob(os.path.join(SORTIE, "**", "*.json"), recursive=True):
    if os.path.basename(f).startswith("_"):
        continue
    ancienne = json.load(io.open(f, encoding="utf-8"))
    garde = {k: ancienne[k] for k in CLES_PRESERVEES if k in ancienne}
    if garde:
        conserve[os.path.basename(f)[:-5]] = garde

# ---------------------------------------------------------------- tables
materiaux = {}
for fichier, cat in CATALOGUES.items():
    chemin = os.path.join(DOCS, "Catalogue matériaux — %s.md" % fichier)
    for ligne in io.open(chemin, encoding="utf-8"):
        if not ligne.startswith("|") or ligne.startswith("|---") or ligne.startswith("| Matériau"):
            continue
        cellules = [c.strip() for c in ligne.strip().strip("|").split("|")]
        if len(cellules) < 17:
            continue
        nom = cellules[0].replace("**", "").strip()
        valeurs = cellules[1:17]
        stats = {}
        for cle, v in zip(STATS, valeurs):
            # Un tiret vaut zero partout — sauf pour `fusion`, ou il veut dire « ne fond pas » : 9999, que rien
            # n'atteint. Zero y serait un vrai point de fusion, celui de la glace.
            vide = v in ("—", "-", "")
            stats[cle] = (NE_FOND_PAS if cle == "fusion" else 0) if vide else int(v)
        ident = ALIAS.get(slug(nom_court(nom)), slug(nom_court(nom)))
        if ident not in palette:
            sans_couleur.append("%s (%s)" % (nom, ident))
            continue
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
        garde_id = conserve.get(ident, {})
        if "tags" in garde_id:   # la règle `organique` ci-dessus n'est qu'un DÉFAUT, pour un matériau encore sans fiche
            # (une liste VIDE est un état voulu : treize fiches n'ont délibérément aucun tag)
            m["tags"] = garde_id["tags"]
        m.update({k: v for k, v in garde_id.items() if k != "tags"})   # ce que ce script n'écrit pas, et détruisait
        materiaux[ident] = (nom, m)

if sans_couleur:
    # Mourir sur la PREMIÈRE couleur manquante cachait l'ampleur du trou (76 des 227 lignes le 2026-09-08) et faisait
    # passer ce script pour un destructeur alors qu'il ne dépassait jamais cette ligne. Il dit maintenant tout ce qui
    # manque, et refuse toujours d'écrire — mais sans avoir rien supprimé.
    raise SystemExit("%d matériau(x) sans couleur de palette, rien n'a été écrit :\n  %s"
                     % (len(sans_couleur), "\n  ".join(sans_couleur)))

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
    # Une clé écrite À LA MAIN dans le bloc régénéré est une bombe à retardement : `arena.banc_objets.name` y vivait
    # depuis on ne sait quand, et le premier passage du générateur l'a effacée en silence (constaté le 2026-09-08).
    # On refuse désormais d'écraser un bloc qui contient autre chose que des clés `material.`.
    ancien = s[s.index(debut) + len(debut):s.index(fin)]
    intrus = [l.split(",", 1)[0] for l in ancien.splitlines() if l.strip() and not l.startswith("material.")]
    if intrus:
        raise SystemExit("clé(s) écrite(s) à la main dans le bloc régénéré de %s — les déplacer AVANT le marqueur, "
                         "sinon ce script les efface : %s" % (LOCALE, ", ".join(intrus)))
    s = s[:s.index(debut)] + bloc + s[s.index(fin) + len(fin):]
else:
    s = s.rstrip("\n") + "\n" + bloc
io.open(LOCALE, "w", encoding="utf-8", newline="\n").write(s)
print("%d matériaux -> %s ; %d surcharges Wu Xing appliquées" % (len(materiaux), SORTIE, sum(1 for _, m in materiaux.values() if m["wuxing"])))
