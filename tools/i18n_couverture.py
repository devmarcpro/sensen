# -*- coding: utf-8 -*-
"""Couverture de traduction (docs: Localisation) : ce qui manque dans chaque locale par rapport au francais.
    python tools/i18n_couverture.py            # le rapport
    python tools/i18n_couverture.py --manquantes ui    # la liste des cles manquantes d'un prefixe
Le francais fait foi : c'est la langue d'ecriture des notes. Sortie non nulle si une locale
declaree dans project.godot manque plus de cles que le seuil tolere (voir SEUIL).
"""
import io, os, sys, collections

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "locale"))
SEUIL = 1.0   # part maximale de cles manquantes toleree (1.0 = aucun echec : la traduction est un chantier ouvert)

def cles(chemin):
    d = {}
    for i, ligne in enumerate(io.open(chemin, encoding="utf-8")):
        ligne = ligne.rstrip("\n")
        if i == 0 or not ligne or ligne.startswith("#"):
            continue
        k, _, v = ligne.partition(",")
        if k:
            d[k] = v
    return d

fr = cles(os.path.join(RACINE, "fr.csv"))
autres = sorted(f for f in os.listdir(RACINE) if f.endswith(".csv") and f != "fr.csv")
echec = False
for f in autres:
    loc = cles(os.path.join(RACINE, f))
    manquantes = [k for k in fr if k not in loc]
    en_trop = [k for k in loc if k not in fr]
    part = len(manquantes) / max(1, len(fr))
    print("%-8s %5d / %5d traduites (%3.0f %%)%s" % (f[:-4], len(fr) - len(manquantes), len(fr), 100 * (1 - part),
                                                     "  ; %d cles orphelines" % len(en_trop) if en_trop else ""))
    par_prefixe = collections.Counter(k.split(".")[0] for k in manquantes)
    for prefixe, n in par_prefixe.most_common(8):
        print("      %-16s %d" % (prefixe, n))
    if len(sys.argv) > 2 and sys.argv[1] == "--manquantes":
        for k in sorted(k for k in manquantes if k.startswith(sys.argv[2])):
            print("      %s,%s" % (k, fr[k]))
    if part > SEUIL:
        echec = True
# Les clés littérales tr("...") du code GDScript doivent exister dans fr.csv (une clé absente s'affiche brute à l'écran).
import re, glob
GODOT = os.path.normpath(os.path.join(RACINE, ".."))
motif = re.compile(r'tr\("([a-z0-9_.]+)"\)')
cles_code = {}
for f in glob.glob(os.path.join(GODOT, "scenes", "**", "*.gd"), recursive=True) + glob.glob(os.path.join(GODOT, "systems", "**", "*.gd"), recursive=True):
    for k in motif.findall(io.open(f, encoding="utf-8").read()):
        cles_code.setdefault(k, os.path.relpath(f, GODOT))
absentes = sorted((k, f) for k, f in cles_code.items() if k not in fr)
for k, f in absentes:
    print("cle de code absente de fr.csv : %s (%s)" % (k, f))
print("cles litterales du code : %d, absentes de fr.csv : %d" % (len(cles_code), len(absentes)))
if absentes:
    echec = True
sys.exit(1 if echec else 0)

# Un gabarit d'affixe sans {base} efface le nom de l'objet : « de portage (+40) » au lieu de
# « Anneau de portage (+40) ». Trouve le 2026-09-02 sur une collecte de 97 objets.
_sans_base = []
for _f in ("fr", "en"):
    for _l in io.open(os.path.join(RACINE, "%s.csv" % _f), encoding="utf-8"):
        if _l.startswith("affixe.") and ".nom," in _l and "{base}" not in _l:
            _sans_base.append("%s : %s" % (_f, _l.split(",")[0]))
if _sans_base:
    print("GABARITS D'AFFIXE SANS {base} (le nom de l'objet disparait) : %d" % len(_sans_base))
    for _x in _sans_base:
        print("   ", _x)
    sys.exit(1)
