# -*- coding: utf-8 -*-
"""Écrit la bibliothèque de prefabs de donjon (docs: Salles et connecteurs, Décision — Prefabs de
donjon en tuiles, Génération de donjon) : 12 salles + 8 connecteurs, en grilles JSON.

    python tools/gen_dungeon_prefabs.py

Un plan = des lignes de caractères, 1 caractère = 1 tuile :
  '.' sol · '#' mur · ' ' hors du prefab · 'N' 'S' 'E' 'W' porte (nord/sud/est/ouest, sur le bord)
  'X' cage d'escalier · chiffres : sol à la hauteur relative 0-9 ('.' = 0)
Les hauteurs relatives s'ajoutent à la hauteur de base de l'étage (10). Les formes sont posées
à la main ici — « terrain plat, reliefs en exception » (décision du 2026-08-27).
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data"))


def ecrire(dossier, id_, d):
    p = os.path.join(ROOT, dossier, id_ + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")


def rect(w, h, portes, inner=None):
    """Salle rectangulaire w×h murée, portes = {"N": x, "S": x, "E": y, "W": y}, inner = lignes intérieures."""
    lignes = []
    for y in range(h):
        row = []
        for x in range(w):
            bord = x == 0 or y == 0 or x == w - 1 or y == h - 1
            c = "#" if bord else "."
            if inner and not bord:
                c = inner[y - 1][x - 1]
            row.append(c)
        lignes.append(row)
    for d, k in portes.items():
        if d == "N": lignes[0][k] = "N"
        if d == "S": lignes[h - 1][k] = "S"
        if d == "W": lignes[k][0] = "W"
        if d == "E": lignes[k][w - 1] = "E"
    return ["".join(r) for r in lignes]


def connecteurs_de(plan):
    res = []
    for y, l in enumerate(plan):
        for x, c in enumerate(l):
            if c in "NSEW":
                res.append({"type": "porte", "position": [x, y], "direction": {"N": "nord", "S": "sud", "E": "est", "W": "ouest"}[c]})
            elif c == "X":
                res.append({"type": "cage_escalier", "position": [x, y], "direction": "bas"})
    return res


def salle(id_, taille, plan, themes, tags=(), flat=True):
    ecrire("dungeon_rooms", id_, {"kind": "salle", "size_category": taille, "floor_theme": list(themes), "plan": plan,
                                  "flat_floor": flat, "connectors": connecteurs_de(plan), "special_tags": list(tags),
                                  "sprite_slots": {"#00FF00": "roche"}})


def connecteur(id_, type_, plan, links=False):
    d = {"kind": "connecteur", "type": type_, "plan": plan, "links_floors": links, "connectors": connecteurs_de(plan)}
    ecrire("dungeon_connectors", id_, d)


# ---------------------------------------------------------------- 12 salles
T = ["ruine", "crypte", "mine", "repaire"]
# petites 8×8
salle("cellule", "petite", rect(8, 8, {"N": 3, "S": 4}), T, ["entree_eligible"])
salle("reduit", "petite", rect(8, 8, {"W": 3, "E": 4, "N": 4}), T)
salle("puits", "petite", rect(8, 8, {"S": 3, "E": 3}, [
    "......", "......", "..#...", "..#...", "......", "......"]), T)
# moyennes 16×16
salle("halle", "moyenne", rect(16, 16, {"N": 7, "S": 8, "E": 7, "W": 8}), T, ["entree_eligible"])
estrade = ["." * 14] * 3 + ["....11111111.."] * 2 + ["....12222221.."] * 4 + ["....11111111.."] * 2 + ["." * 14] * 3
salle("salle_des_estrades", "moyenne", rect(16, 16, {"N": 7, "S": 7, "W": 7}, estrade), T, ["boss_room_eligible", "treasure_eligible"], flat=False)
salle("salle_aux_piliers", "moyenne", rect(16, 16, {"N": 3, "S": 12, "E": 3, "W": 12},
      ["." * 14, "." * 14, "..#........#..", "." * 14, "." * 14, "." * 14, "..#........#..", "." * 14, "." * 14, "." * 14, "..#........#..", "." * 14, "." * 14, "." * 14]), T)
salle("gradins", "moyenne", rect(16, 16, {"N": 7, "S": 7}, ["33333333333333"] * 2 + ["22222222222222"] * 2 + ["11111111111111"] * 2 + ["." * 14] * 8), T, ["treasure_eligible"], flat=False)
# grandes 24×24
salle("nef", "grande", rect(24, 24, {"N": 11, "S": 12, "E": 11, "W": 12}), T, ["boss_room_eligible"])
cour = ["." * 22] * 6 + ["......####..####......"] * 1 + ["......#........#......"] * 3 + ["." * 22] * 2 + ["......#........#......"] * 3 + ["......####..####......"] * 1 + ["." * 22] * 6
salle("cour_interieure", "grande", rect(24, 24, {"N": 5, "S": 18, "W": 5, "E": 18}, cour), T, ["treasure_eligible"])
caverne = ["." * 22] * 4 + ["...111111.....222....."] * 3 + ["..11222211...22322...."] * 3 + ["...111111.....222....."] * 3 + ["." * 22] * 9
salle("caverne", "grande", rect(24, 24, {"N": 11, "E": 6, "W": 17}, caverne), ["mine", "repaire"], ["boss_room_eligible"], flat=False)
# immenses 32×32
salle("grande_salle", "immense", rect(32, 32, {"N": 15, "S": 16, "E": 15, "W": 16}), T, ["treasure_eligible"])
arene = ["." * 30] * 8 + ["........1111111111111........."] * 2 + ["........1222222222221........."] * 10 + ["........1111111111111........."] * 2 + ["." * 30] * 8
salle("arene_du_boss", "immense", rect(32, 32, {"N": 15, "S": 15}, arene), T, ["boss_room_eligible"], flat=False)

# ---------------------------------------------------------------- 8 connecteurs (un connecteur relie deux portes)
connecteur("corridor_droit_court", "corridor_droit", ["#N#", "#.#", "#.#", "#.#", "#S#"])
connecteur("corridor_droit_long", "corridor_droit", ["#N#"] + ["#.#"] * 8 + ["#S#"])
connecteur("corridor_coude", "corridor_coude", ["#N###", "#...E", "#####"])
connecteur("corridor_coude_inverse", "corridor_coude", ["###N#", "W...#", "#####"])
connecteur("corridor_T", "corridor_T", ["##N##", "W...E", "#####"])
connecteur("escalier", "escalier", ["#N#", "#X#", "###"], links=True)
connecteur("porte_simple", "porte_simple", ["#N#", "#S#"])
connecteur("rampe", "rampe", ["#N#", "#2#", "#1#", "#S#"])
print("prefabs ecrits dans", ROOT)
