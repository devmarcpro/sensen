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
