# -*- coding: utf-8 -*-
"""Écrit les trois arènes du prototype (docs: Prototype de combat — spécification).

    python tools/gen_arenas.py

Les reliefs sont posés à la main (formes déclarées ici, déterministes) — ce script
est la « main » qui les pose ; les JSON produits sont versionnés et font foi.
Hauteurs 0-20, référence 10 (docs: Hauteur de terrain ±10).
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "prototype_arenas"))
N = 32


def grille(h=10):
    return [[h] * N for _ in range(N)]


def rect(g, x0, y0, x1, y1, h):
    for y in range(max(0, y0), min(N, y1 + 1)):
        for x in range(max(0, x0), min(N, x1 + 1)):
            g[y][x] = h


def ecrire(nom, heights, contents, player, enemies):
    d = {
        "name_key": "arena.%s.name" % nom,
        "size": [N, N],
        "heights": heights,
        "ground": [],
        "contents": contents,
        "spawns": {"player": player, "enemies": enemies},
    }
    p = os.path.join(ROOT, nom + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("ecrit", p)


# ---------------------------------------------------------------- 1. Plaine au talus
# Dénivelés doux : un talus nord (h 12) avec sa rampe (h 11), une butte NE (h 13),
# deux creux (h 9). Aucune falaise : tout est franchissable, l'initiation.
g = grille(10)
rect(g, 0, 0, 31, 9, 12)          # talus nord
rect(g, 0, 10, 31, 11, 11)        # rampe du talus
rect(g, 22, 2, 28, 6, 13)         # butte NE (Δ+1 depuis le talus)
rect(g, 4, 18, 9, 22, 9)          # creux SO
rect(g, 20, 20, 25, 24, 9)        # creux SE
rect(g, 12, 14, 16, 16, 11)       # petit tertre au centre
ecrire("plaine_au_talus", g, [],
       {"creature": "aventurier", "pos": [16, 28]},
       [{"creature": "loup", "pos": [14, 5]},
        {"creature": "loup", "pos": [18, 5]},
        {"creature": "loup", "pos": [16, 3]}])

# ---------------------------------------------------------------- 2. Gorge
# Un canyon N-S (h 7) entre deux rives (h 10) — Δ3 : falaise, lignes de vue coupées,
# chutes possibles. Entrées en rampe au nord et au sud. Plateau ouest (h 13).
g = grille(10)
rect(g, 13, 0, 18, 31, 7)         # fond de gorge
rect(g, 13, 27, 18, 28, 8)        # rampe sud : 10 → 9 → 8 → 7
rect(g, 13, 29, 18, 30, 9)
rect(g, 13, 31, 18, 31, 10)
rect(g, 13, 3, 18, 4, 8)          # rampe nord
rect(g, 13, 1, 18, 2, 9)
rect(g, 13, 0, 18, 0, 10)
rect(g, 0, 8, 7, 20, 13)          # plateau ouest (Δ+3 depuis la rive : falaise)
rect(g, 8, 8, 8, 20, 12)          # rampe du plateau : 10 → 11 → 12 → 13
rect(g, 9, 8, 9, 20, 11)
rect(g, 19, 12, 20, 14, 9)        # éboulis côté est : on peut descendre par là (Δ−1/−2)
rect(g, 19, 15, 20, 16, 8)
ecrire("gorge", g, [],
       {"creature": "aventurier", "pos": [16, 30]},
       [{"creature": "sanglier", "pos": [15, 9]},
        {"creature": "bandit", "pos": [10, 12]},
        {"creature": "bandit", "pos": [21, 10]}])

# ---------------------------------------------------------------- 3. Ruine à estrades
# Combat vertical dense : deux estrades emboîtées (h 13 puis h 16), un escalier au sud,
# des murs ruinés (contenu « mur ») qui coupent la vue et les passages.
g = grille(10)
rect(g, 9, 9, 22, 22, 13)         # estrade basse
rect(g, 13, 23, 18, 23, 12)       # escalier sud : 10 → 11 → 12 → 13
rect(g, 13, 24, 18, 24, 11)
rect(g, 12, 12, 19, 19, 16)       # estrade haute
rect(g, 14, 20, 17, 20, 15)       # marches vers l'estrade haute (Δ+2 puis +1)
rect(g, 14, 21, 17, 21, 14)
rect(g, 2, 2, 6, 6, 12)           # ruine NO surélevée
rect(g, 25, 25, 29, 29, 8)        # fosse SE
murs = []
for x in range(9, 23):            # murs ruinés sur le bord nord de l'estrade basse (brèches)
    if x not in (11, 15, 16, 20):
        murs.append({"pos": [x, 9], "type": "mur"})
for y in range(9, 23):            # bord ouest
    if y not in (12, 13, 18, 19):
        murs.append({"pos": [9, y], "type": "mur"})
for x in range(26, 31):           # un pan de mur isolé au sud-est
    murs.append({"pos": [x, 22], "type": "mur"})
ecrire("ruine_a_estrades", g, murs,
       {"creature": "aventurier", "pos": [16, 29]},
       [{"creature": "chef_de_bande", "pos": [16, 15]},
        {"creature": "bandit", "pos": [11, 20]},
        {"creature": "bandit", "pos": [20, 11]},
        {"creature": "aigle", "pos": [26, 6]},
        {"creature": "scorpion", "pos": [5, 24]}])
