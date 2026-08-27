# -*- coding: utf-8 -*-
"""Écrit les rigs des quatre templates de squelette (docs: Squelette modulaire et points d'attache).

    python tools/gen_rigs.py

Un rig = des segments (chacun accroché à un ancrage de son parent, avec une longueur, une
largeur et un angle de repos) + les ancrages portés par chaque segment + les facings
(ordre de calque et décalages d'ancrage ; W/NW/SW par miroir). Unités : pixels d'écran à
l'échelle de la tuile 40×20. Les sprites viendront remplacer les rectangles : le rig, lui,
ne changera pas — c'est la donnée, pas le dessin.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "rigs"))


def seg(parent, ancrage, longueur, largeur, angle=90, ancrages=None, zone=None):
    return {"parent": parent, "ancrage": ancrage, "longueur": longueur, "largeur": largeur,
            "angle": angle, "ancrages": ancrages or {}, "zone": zone}


def ecrire(nom, d):
    p = os.path.join(ROOT, nom + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("ecrit", p)


# ---------------------------------------------------------------- humanoïde : 14 segments
# Le torse est la racine (origine : les hanches). L'angle 90 pointe vers le bas de l'écran,
# −90 vers le haut. Les ancrages sont exprimés le long du segment (0 = attache, longueur = bout).
H = {
    "name_key": "rig.humanoide.name",
    "racine": "torse",
    "hauteur_pieds": 13,
    "segments": {
        "torse": seg(None, None, 14, 9, -90, {"cou": [14, 0], "epaule_G": [12, -5], "epaule_D": [12, 5],
                                              "hanche_G": [0, -2.5], "hanche_D": [0, 2.5], "dos": [8, 0]}, "torse"),
        "tete": seg("torse", "cou", 8, 8, -90, {}, "tete"),
        "bras_haut_G": seg("torse", "epaule_G", 8, 3, 100, {"coude": [8, 0]}, "bras"),
        "bras_haut_D": seg("torse", "epaule_D", 8, 3, 80, {"coude": [8, 0]}, "bras"),
        "bras_bas_G": seg("bras_haut_G", "coude", 7, 3, 95, {"poignet": [7, 0]}, "bras"),
        "bras_bas_D": seg("bras_haut_D", "coude", 7, 3, 85, {"poignet": [7, 0]}, "bras"),
        "main_G": seg("bras_bas_G", "poignet", 3, 3, 90, {"prise": [2, 0]}, "bras"),
        "main_D": seg("bras_bas_D", "poignet", 3, 3, 90, {"prise": [2, 0]}, "bras"),
        "jambe_haut_G": seg("torse", "hanche_G", 7, 4, 95, {"genou": [7, 0]}, "jambes"),
        "jambe_haut_D": seg("torse", "hanche_D", 7, 4, 85, {"genou": [7, 0]}, "jambes"),
        "jambe_bas_G": seg("jambe_haut_G", "genou", 6, 3.5, 90, {"cheville": [6, 0]}, "jambes"),
        "jambe_bas_D": seg("jambe_haut_D", "genou", 6, 3.5, 90, {"cheville": [6, 0]}, "jambes"),
        "pied_G": seg("jambe_bas_G", "cheville", 4, 3, 0, {}, "pieds"),
        "pied_D": seg("jambe_bas_D", "cheville", 4, 3, 0, {}, "pieds"),
    },
    # Ordre de calque : du fond vers l'avant. Offsets : décalage des ancrages du torse par facing.
    "facings": {
        "S": {"ordre": ["bras_haut_G", "bras_bas_G", "main_G", "jambe_haut_G", "jambe_bas_G", "pied_G",
                         "jambe_haut_D", "jambe_bas_D", "pied_D", "torse", "tete", "bras_haut_D", "bras_bas_D", "main_D"],
              "offsets": {}, "vue_tete": "face"},
        "SE": {"ordre": ["bras_haut_G", "bras_bas_G", "main_G", "jambe_haut_G", "jambe_bas_G", "pied_G", "torse",
                          "jambe_haut_D", "jambe_bas_D", "pied_D", "tete", "bras_haut_D", "bras_bas_D", "main_D"],
               "offsets": {"epaule_G": [0, 2], "epaule_D": [0, -1], "hanche_G": [0, 1], "hanche_D": [0, -0.5]}, "vue_tete": "face"},
        "E": {"ordre": ["bras_haut_G", "bras_bas_G", "main_G", "jambe_haut_G", "jambe_bas_G", "pied_G", "torse",
                         "jambe_haut_D", "jambe_bas_D", "pied_D", "tete", "bras_haut_D", "bras_bas_D", "main_D"],
              "offsets": {"epaule_G": [0, 4], "epaule_D": [0, -3], "hanche_G": [0, 2], "hanche_D": [0, -1.5]}, "vue_tete": "profil"},
        "NE": {"ordre": ["bras_haut_D", "bras_bas_D", "main_D", "tete", "jambe_haut_D", "jambe_bas_D", "pied_D", "torse",
                          "jambe_haut_G", "jambe_bas_G", "pied_G", "bras_haut_G", "bras_bas_G", "main_G"],
               "offsets": {"epaule_G": [0, 2], "epaule_D": [0, -1], "hanche_G": [0, 1], "hanche_D": [0, -0.5]}, "vue_tete": "dos"},
        "N": {"ordre": ["bras_haut_D", "bras_bas_D", "main_D", "bras_haut_G", "bras_bas_G", "main_G", "tete",
                         "jambe_haut_D", "jambe_bas_D", "pied_D", "jambe_haut_G", "jambe_bas_G", "pied_G", "torse"],
              "offsets": {}, "vue_tete": "dos"},
        "SW": {"miroir": "SE"}, "W": {"miroir": "E"}, "NW": {"miroir": "NE"},
    },
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"], "brassards": ["bras_haut_G", "bras_haut_D", "bras_bas_G", "bras_bas_D", "main_G", "main_D"],
                       "jambieres": ["jambe_haut_G", "jambe_haut_D", "jambe_bas_G", "jambe_bas_D"], "bottes": ["pied_G", "pied_D"]},
    "prise_arme": "main_D", "prise_bouclier": "main_G",
}
ecrire("humanoide", H)

# ---------------------------------------------------------------- quadrupède : torse horizontal, tête, 4 pattes en 2 segments
Q = {
    "name_key": "rig.quadrupede.name",
    "racine": "torse",
    "hauteur_pieds": 10,
    "segments": {
        "torse": seg(None, None, 20, 8, 0, {"cou": [20, -3], "epaule_AV_G": [17, 2], "epaule_AV_D": [17, -2],
                                            "epaule_AR_G": [3, 2], "epaule_AR_D": [3, -2], "dos": [10, -4]}, "torse"),
        "tete": seg("torse", "cou", 7, 6, -20, {}, "tete"),
        "patte_AV_G": seg("torse", "epaule_AV_G", 6, 2.5, 95, {"pied": [6, 0]}, "jambes"),
        "patte_AV_D": seg("torse", "epaule_AV_D", 6, 2.5, 85, {"pied": [6, 0]}, "jambes"),
        "patte_AR_G": seg("torse", "epaule_AR_G", 6, 2.5, 95, {"pied": [6, 0]}, "jambes"),
        "patte_AR_D": seg("torse", "epaule_AR_D", 6, 2.5, 85, {"pied": [6, 0]}, "jambes"),
        "pied_AV_G": seg("patte_AV_G", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AV_D": seg("patte_AV_D", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AR_G": seg("patte_AR_G", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AR_D": seg("patte_AR_D", "pied", 4, 2.5, 90, {}, "pieds"),
    },
    "facings": {
        "S": {"ordre": ["patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G", "tete"], "offsets": {}, "vue_tete": "face"},
        "SE": {"ordre": ["patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G", "tete"], "offsets": {}, "vue_tete": "face"},
        "E": {"ordre": ["patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "tete", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G"], "offsets": {}, "vue_tete": "profil"},
        "NE": {"ordre": ["tete", "patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G"], "offsets": {}, "vue_tete": "dos"},
        "N": {"ordre": ["tete", "patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G"], "offsets": {}, "vue_tete": "dos"},
        "SW": {"miroir": "SE"}, "W": {"miroir": "E"}, "NW": {"miroir": "NE"},
    },
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"], "selle": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("quadrupede", Q)

# ---------------------------------------------------------------- volant : corps, tête, deux ailes
V = {
    "name_key": "rig.volant.name",
    "racine": "torse",
    "hauteur_pieds": 18,
    "segments": {
        "torse": seg(None, None, 10, 6, 0, {"cou": [10, -1], "aile_G": [5, 2], "aile_D": [5, -2]}, "torse"),
        "tete": seg("torse", "cou", 4, 4, -10, {}, "tete"),
        "aile_G": seg("torse", "aile_G", 14, 5, 150, {}, "bras"),
        "aile_D": seg("torse", "aile_D", 14, 5, -150, {}, "bras"),
    },
    "facings": {
        "S": {"ordre": ["aile_D", "torse", "tete", "aile_G"], "offsets": {}, "vue_tete": "face"},
        "SE": {"ordre": ["aile_D", "torse", "tete", "aile_G"], "offsets": {}, "vue_tete": "face"},
        "E": {"ordre": ["aile_D", "torse", "tete", "aile_G"], "offsets": {}, "vue_tete": "profil"},
        "NE": {"ordre": ["tete", "aile_D", "torse", "aile_G"], "offsets": {}, "vue_tete": "dos"},
        "N": {"ordre": ["tete", "aile_D", "torse", "aile_G"], "offsets": {}, "vue_tete": "dos"},
        "SW": {"miroir": "SE"}, "W": {"miroir": "E"}, "NW": {"miroir": "NE"},
    },
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("volant", V)

# ---------------------------------------------------------------- amorphe : un corps entier
A = {
    "name_key": "rig.amorphe.name",
    "racine": "torse",
    "hauteur_pieds": 2,
    "segments": {"torse": seg(None, None, 12, 12, -90, {}, "torse")},
    "facings": {f: {"ordre": ["torse"], "offsets": {}, "vue_tete": "face"} for f in ["S", "SE", "E", "NE", "N"]} | {"SW": {"miroir": "SE"}, "W": {"miroir": "E"}, "NW": {"miroir": "NE"}},
    "slots_segments": {},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("amorphe", A)
