# -*- coding: utf-8 -*-
"""Les sprites d'objets attendus et présents (Direction artistique, 2026-09-05) : compare `godot/assets/objets/`
à ce que les données demandent — un fichier par objet (id sans craft_ ni proto_), par composant, par forme de matière.

    python -X utf8 tools/verif_sprites.py

Sortie : attendus, présents, manquants, en trop. Code de sortie 0 (c'est un état, pas un échec : les sprites
arrivent au rythme du designer).
"""
import csv, glob, io, os, json

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "godot", "data")
ASSETS = os.path.join(RACINE, "godot", "assets", "objets")


def nom_sprite(iid):
    for p in ("craft_", "proto_"):
        if iid.startswith(p):
            return iid[len(p):]
    return iid


def attendus():
    res = {"objets": set(), "composants": set(), "matieres": set()}
    for f in glob.glob(os.path.join(DATA, "items", "*", "*.json")):
        iid = os.path.basename(f)[:-5]
        if iid.startswith("_"):
            continue
        d = json.load(io.open(f, encoding="utf-8"))
        if d.get("type") in ("composant", "materiau"):
            continue   # les composants et les matières ont leur propre dossier
        if d.get("slots") or iid.startswith("proto_"):
            continue   # un objet assemblé se compose de ses composants ; un objet de fortune garde son pictogramme (2026-09-05, 9 h)
        res["objets"].add(nom_sprite(iid))
    for f in glob.glob(os.path.join(DATA, "components", "*.json")):
        cid = os.path.basename(f)[:-5]
        if not cid.startswith("_"):
            res["composants"].add(cid)
    with io.open(os.path.join(RACINE, "godot", "locale", "fr.csv"), encoding="utf-8", newline="") as fh:
        for ligne in csv.reader(fh):
            if ligne and ligne[0].startswith("forme."):
                res["matieres"].add(ligne[0][len("forme."):])
    return res


def presents():
    res = {"objets": set(), "composants": set(), "matieres": set()}
    for f in glob.glob(os.path.join(ASSETS, "*.png")):
        res["objets"].add(os.path.basename(f)[:-4])
    for f in glob.glob(os.path.join(ASSETS, "composants", "*.png")):
        res["composants"].add(os.path.basename(f)[:-4])
    for f in glob.glob(os.path.join(ASSETS, "matieres", "*.png")):
        res["matieres"].add(os.path.basename(f)[:-4])
    return res


def main():
    a, p = attendus(), presents()
    for cle in ("objets", "composants", "matieres"):
        manquants = sorted(a[cle] - p[cle])
        en_trop = sorted(p[cle] - a[cle])
        print("%s : %d attendus, %d présents, %d manquants, %d en trop" % (cle, len(a[cle]), len(p[cle]), len(manquants), len(en_trop)))
        if p[cle] and manquants:
            print("  manquants : " + ", ".join(manquants))
        if en_trop:
            print("  en trop (aucun objet de ce nom) : " + ", ".join(en_trop))
    total_a = sum(len(v) for v in a.values())
    total_p = sum(len(a[k] & p[k]) for k in a)
    print("sprites : %d / %d" % (total_p, total_a))


if __name__ == "__main__":
    main()


# ---------------------------------------------------------------- les planches (Direction artistique, 2026-09-06, 20 h 50)
# Un dossier par membre (assets/membres/<segment>/), par trait du visage (assets/visage/<trait>/), par objet
# (assets/objets/<id>/) : chaque PNG une case de 64 ou une planche de cases. On lit la taille dans l'en-tête PNG
# (sans Pillow) et l'on signale ce qui n'est pas un multiple de la case.
import struct

MEMBRES = ["torse", "tete", "bras_haut", "bras_bas", "main", "jambe_haut", "jambe_bas", "pied"]
TRAITS = ["tete", "oreilles", "cheveux", "yeux", "nez", "bouche", "barbe", "sourcils", "machoire", "menton", "pommettes", "implantation", "paupieres", "marque"]


def taille_png(chemin):
    with open(chemin, "rb") as f:
        en_tete = f.read(24)
    if len(en_tete) < 24 or en_tete[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", en_tete[16:24])


def planches():
    styles = json.load(open(os.path.join(DATA, "styles.json"), encoding="utf-8"))
    case = int(styles.get("planches", {}).get("case", 64))
    racine_assets = os.path.join(RACINE, "godot", "assets")
    dossiers = [("membres", m) for m in MEMBRES] + [("visage", t) for t in TRAITS]
    for d in sorted(glob.glob(os.path.join(ASSETS, "*", ""))):
        dossiers.append(("objets", os.path.basename(os.path.dirname(d))))
    fautes = 0
    presents = 0
    for famille, nom in dossiers:
        dossier = os.path.join(racine_assets, famille, nom)
        if not os.path.isdir(dossier):
            continue
        cases = 0
        for png in sorted(glob.glob(os.path.join(dossier, "*.png"))):
            t = taille_png(png)
            if t is None or t[0] % case != 0 or t[1] % case != 0 or t[0] == 0:
                print("  planche %s/%s : %s fait %s, pas un multiple de %d" % (famille, nom, os.path.basename(png), t, case))
                fautes += 1
                continue
            cases += (t[0] // case) * (t[1] // case)
        if cases:
            presents += 1
            print("  planche %s/%s : %d variante(s)" % (famille, nom, cases))
    print("planches : %d dossier(s) garni(s), %d fichier(s) hors format" % (presents, fautes))


if __name__ == "__main__":
    planches()
