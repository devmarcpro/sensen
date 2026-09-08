# -*- coding: utf-8 -*-
"""Écrit les six rigs de squelette (docs: Squelette modulaire et points d'attache).

    python tools/gen_rigs.py

LA PROFONDEUR (designer 2026-09-08 : « rajouter la profondeur, comme ça on pourrait avoir les personnages dans les
8 angles et faire des poses plus complexes »). Un segment n'est plus un angle d'écran : c'est une ORIENTATION DANS
L'ESPACE du corps, que le paperdoll tourne du lacet du corps puis projette par l'isométrie.

Le repère du corps, lacet nul — le personnage nous fait face :
  · `x` la droite de l'écran (l'axe gauche-droite du corps),
  · `y` le BAS de l'écran (le corps est debout : cet axe ne tourne pas),
  · `z` la profondeur, VERS LE FOND.
`angle` reste l'angle dans le plan (x, y), en degrés, exactement comme avant : 0 vers la droite, −90 vers le haut,
+90 vers le bas. `profondeur` (degrés, 0 par défaut) fait SORTIR le segment de ce plan, vers l'AVANT quand elle est
positive. Un ancrage porte trois nombres : le long du parent, en travers, et en profondeur le long de sa normale
(pour un segment vertical, la normale pointe vers l'ARRIÈRE — d'où les valeurs négatives des épaules et des hanches,
qui sont devant le plan du torse).

CE QUE ÇA SUPPRIME : les ordres de calque et les décalages d'ancrage écrits à la main pour CHACUN des huit facings
de CHACUN des six rigs — de la profondeur simulée, que la vraie calcule. Il ne reste qu'un `ordre` par rig, qui ne
sert qu'à DÉPARTAGER deux segments à la même profondeur (un serpent à plat, une méduse), et huit `orientations` qui
ne disent plus que le lacet du corps et la vue de la tête.

Les rigs animaux séparaient leurs membres gauche/droite par un décalage EN TRAVERS (donc vertical à l'écran) :
c'était de la profondeur déguisée. Elle est passée en profondeur vraie, à la même valeur apparente — et c'est elle
qui trie désormais les pattes proches devant les pattes lointaines.

`lacet_actif` : les rigs ANIMAUX sont encore écrits dans le plan de l'écran (un quadrupède est dessiné de profil,
pas de face), donc leur faire subir un lacet les réduirait à un moignon. Ils gardent `false` jusqu'à leur réécriture
en espace du corps ; l'humanoïde, lui, est debout et tourne pour de bon.

Unités : pixels d'écran à l'échelle de la tuile. Les sprites viennent remplacer les rectangles ; le rig, lui, est
la donnée — pas le dessin.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "rigs"))

# Les huit orientations : le lacet du corps en degrés (0 = face à la caméra, +90 = vers la droite de l'écran)
# et la vue de la tête, qui choisit les planches du visage.
ORIENTATIONS = {
    "S":  {"lacet": 0,    "vue_tete": "face"},
    "SE": {"lacet": 45,   "vue_tete": "face"},
    "E":  {"lacet": 90,   "vue_tete": "profil"},
    "NE": {"lacet": 135,  "vue_tete": "dos"},
    "N":  {"lacet": 180,  "vue_tete": "dos"},
    "NW": {"lacet": -135, "vue_tete": "dos"},
    "W":  {"lacet": -90,  "vue_tete": "profil"},
    "SW": {"lacet": -45,  "vue_tete": "face"},
}


def seg(parent, ancrage, longueur, largeur, angle=90, ancrages=None, zone=None, profondeur=0.0):
    d = {"parent": parent, "ancrage": ancrage, "longueur": longueur, "largeur": largeur,
         "angle": angle, "ancrages": ancrages or {}, "zone": zone}
    if profondeur:
        d["profondeur"] = profondeur
    return d


def ecrire(nom, d):
    d["orientations"] = ORIENTATIONS
    p = os.path.join(ROOT, nom + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("ecrit", p)


# ---------------------------------------------------------------- humanoïde : 15 segments, le bassin à la racine
# Le bassin est la racine depuis le 2026-09-08 (designer : « sépare torse en bassin et torse »). Les épaules et les
# hanches sont DEVANT le plan du torse (profondeur négative) : c'est ce qui met les bras et les jambes au-dessus du
# tronc de face, et ce qui envoie le membre du fond DERRIÈRE lui dès que le corps tourne — sans un seul ordre écrit.
H = {
    "name_key": "rig.humanoide.name",
    "racine": "bassin",
    "hauteur_pieds": 13,
    "lacet_actif": True,
    "segments": {
        "bassin": seg(None, None, 5, 8, -90, {"taille": [5, 0, 0], "hanche_G": [0, -2.5, -1], "hanche_D": [0, 2.5, -1]}, "torse"),
        "torse": seg("bassin", "taille", 9, 9, -90, {"cou": [9, 0, -1], "epaule_G": [7, -5, -1.5], "epaule_D": [7, 5, -1.5], "dos": [3, 0, 2]}, "torse"),
        "tete": seg("torse", "cou", 8, 8, -90, {}, "tete"),
        "bras_haut_G": seg("torse", "epaule_G", 8, 3, 100, {"coude": [8, 0, 0]}, "bras", 8),
        "bras_haut_D": seg("torse", "epaule_D", 8, 3, 80, {"coude": [8, 0, 0]}, "bras", 8),
        "bras_bas_G": seg("bras_haut_G", "coude", 7, 3, 95, {"poignet": [7, 0, 0]}, "bras", 6),
        "bras_bas_D": seg("bras_haut_D", "coude", 7, 3, 85, {"poignet": [7, 0, 0]}, "bras", 6),
        "main_G": seg("bras_bas_G", "poignet", 3, 3, 90, {"prise": [2, 0, 0]}, "bras"),
        "main_D": seg("bras_bas_D", "poignet", 3, 3, 90, {"prise": [2, 0, 0]}, "bras"),
        "jambe_haut_G": seg("bassin", "hanche_G", 7, 4, 95, {"genou": [7, 0, 0]}, "jambes"),
        "jambe_haut_D": seg("bassin", "hanche_D", 7, 4, 85, {"genou": [7, 0, 0]}, "jambes"),
        "jambe_bas_G": seg("jambe_haut_G", "genou", 6, 3.5, 90, {"cheville": [6, 0, -1]}, "jambes"),
        "jambe_bas_D": seg("jambe_haut_D", "genou", 6, 3.5, 90, {"cheville": [6, 0, -1]}, "jambes"),
        # Les pieds pointent VERS L'AVANT (designer 2026-09-08 : « pieds de face, pas qu'ils pointent les 2 dans le
        # même sens ») : un écart de part et d'autre dans le plan, et 40° de profondeur qui les sort vers nous.
        "pied_G": seg("jambe_bas_G", "cheville", 4, 3, 115, {}, "pieds", 40),
        "pied_D": seg("jambe_bas_D", "cheville", 4, 3, 65, {}, "pieds", 40),
    },
    # `ordre` ne DÉPARTAGE que les segments à la même profondeur : la profondeur décide, lui n'arbitre que les ex æquo.
    "ordre": ["bras_haut_G", "bras_bas_G", "main_G", "jambe_haut_G", "jambe_bas_G", "pied_G",
              "jambe_haut_D", "jambe_bas_D", "pied_D", "bassin", "torse", "tete", "bras_haut_D", "bras_bas_D", "main_D"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse", "bassin"], "brassards": ["bras_haut_G", "bras_haut_D", "bras_bas_G", "bras_bas_D", "main_G", "main_D"],
                       "jambieres": ["jambe_haut_G", "jambe_haut_D", "jambe_bas_G", "jambe_bas_D"], "bottes": ["pied_G", "pied_D"]},
    "prise_arme": "main_D", "prise_bouclier": "main_G",
    "_doc_pieds": ("Les pieds pointent VERS L'AVANT et s'écartent (designer 2026-09-08 : « quand le personnage est de "
                   "face arrange les pieds pour qu'ils soient de face, pas qu'ils pointent les 2 dans le même sens »). "
                   "Ils étaient tous deux à 0°, donc tous deux vers la droite de l'écran. 115° et 65° les écartent en V dans "
                   "le plan, et 40° de profondeur les sortent vers le spectateur — depuis la profondeur (2026-09-08, soir), "
                   "c'est le lacet du corps qui les fait tourner, plus un miroir d'angle."),
}
ecrire("humanoide", H)

# ---------------------------------------------------------------- quadrupède : torse horizontal, tête, 4 pattes en 2 segments
Q = {
    "name_key": "rig.quadrupede.name",
    "racine": "torse",
    "hauteur_pieds": 10,
    "lacet_actif": False,   # écrit dans le plan de l'écran (de profil) : à réécrire en espace du corps
    "segments": {
        "torse": seg(None, None, 20, 8, 0, {"cou": [20, -3, 0], "epaule_AV_G": [17, 0, -4], "epaule_AV_D": [17, 0, 4],
                                            "epaule_AR_G": [3, 0, -4], "epaule_AR_D": [3, 0, 4], "dos": [10, -4, 0]}, "torse"),
        "tete": seg("torse", "cou", 7, 6, -20, {}, "tete"),
        "patte_AV_G": seg("torse", "epaule_AV_G", 6, 2.5, 95, {"pied": [6, 0, 0]}, "jambes"),
        "patte_AV_D": seg("torse", "epaule_AV_D", 6, 2.5, 85, {"pied": [6, 0, 0]}, "jambes"),
        "patte_AR_G": seg("torse", "epaule_AR_G", 6, 2.5, 95, {"pied": [6, 0, 0]}, "jambes"),
        "patte_AR_D": seg("torse", "epaule_AR_D", 6, 2.5, 85, {"pied": [6, 0, 0]}, "jambes"),
        "pied_AV_G": seg("patte_AV_G", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AV_D": seg("patte_AV_D", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AR_G": seg("patte_AR_G", "pied", 4, 2.5, 90, {}, "pieds"),
        "pied_AR_D": seg("patte_AR_D", "pied", 4, 2.5, 90, {}, "pieds"),
    },
    "ordre": ["patte_AR_D", "pied_AR_D", "patte_AV_D", "pied_AV_D", "torse", "patte_AR_G", "pied_AR_G", "patte_AV_G", "pied_AV_G", "tete"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"], "selle": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("quadrupede", Q)

# ---------------------------------------------------------------- volant : corps, tête, deux ailes
V = {
    "name_key": "rig.volant.name",
    "racine": "torse",
    "hauteur_pieds": 18,
    "lacet_actif": False,
    "segments": {
        "torse": seg(None, None, 10, 6, 0, {"cou": [10, -1, 0], "aile_G": [5, 0, -4], "aile_D": [5, 0, 4]}, "torse"),
        "tete": seg("torse", "cou", 4, 4, -10, {}, "tete"),
        "aile_G": seg("torse", "aile_G", 14, 5, 150, {}, "bras"),
        "aile_D": seg("torse", "aile_D", 14, 5, -150, {}, "bras"),
    },
    "ordre": ["aile_D", "torse", "tete", "aile_G"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("volant", V)

# ---------------------------------------------------------------- arachnide : un corps, huit pattes
A = {
    "name_key": "rig.arachnide.name",
    "racine": "torse",
    "hauteur_pieds": 6,
    "lacet_actif": False,
    "segments": {
        "torse": seg(None, None, 12, 9, 0, {"cou": [12, -1, 0],
                                            "p1G": [3, 0, -6], "p2G": [6, 0, -6], "p3G": [9, 0, -6], "p4G": [11, 0, -6],
                                            "p1D": [3, 0, 6], "p2D": [6, 0, 6], "p3D": [9, 0, 6], "p4D": [11, 0, 6]}, "torse"),
        "tete": seg("torse", "cou", 5, 4, -15, {}, "tete"),
        "patte_1G": seg("torse", "p1G", 7, 1.8, 60, {}, "jambes"),
        "patte_2G": seg("torse", "p2G", 7, 1.8, 82, {}, "jambes"),
        "patte_3G": seg("torse", "p3G", 7, 1.8, 104, {}, "jambes"),
        "patte_4G": seg("torse", "p4G", 7, 1.8, 126, {}, "jambes"),
        "patte_1D": seg("torse", "p1D", 7, 1.8, -60, {}, "jambes"),
        "patte_2D": seg("torse", "p2D", 7, 1.8, -82, {}, "jambes"),
        "patte_3D": seg("torse", "p3D", 7, 1.8, -104, {}, "jambes"),
        "patte_4D": seg("torse", "p4D", 7, 1.8, -126, {}, "jambes"),
    },
    "ordre": ["patte_1D", "patte_2D", "patte_3D", "patte_4D", "torse", "patte_1G", "patte_2G", "patte_3G", "patte_4G", "tete"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("arachnide", A)

# ---------------------------------------------------------------- serpentin : un corps et une queue qui ondule
S = {
    "name_key": "rig.serpentin.name",
    "racine": "torse",
    "hauteur_pieds": 2,
    "lacet_actif": False,
    "segments": {
        "torse": seg(None, None, 10, 6, 0, {"cou": [10, -1, 0], "q1": [0, 0, 0]}, "torse"),
        "tete": seg("torse", "cou", 6, 5, -10, {}, "tete"),
        "c1": seg("torse", "q1", 8, 5, 150, {"q2": [8, 0, 0]}, "torse"),
        "c2": seg("c1", "q2", 7, 4, -52, {"q3": [7, 0, 0]}, "torse"),
        "c3": seg("c2", "q3", 6, 3, 52, {}, "torse"),
    },
    "ordre": ["c3", "c2", "c1", "torse", "tete"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("serpentin", S)

# ---------------------------------------------------------------- amorphe : une seule masse
M = {
    "name_key": "rig.amorphe.name",
    "racine": "torse",
    "hauteur_pieds": 2,
    "lacet_actif": False,
    "segments": {"torse": seg(None, None, 12, 12, -90, {}, "torse")},
    "ordre": ["torse"],
    "slots_segments": {},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("amorphe", M)

# ---------------------------------------------------------------- le gabarit : c'est LUI que GameData valide
# Le validateur des donnees compare chaque fiche au gabarit du dossier. Il etait reste a `facings` : les six rigs
# refaits en profondeur etaient tous refuses (2026-09-08). Un gabarit ecrit a la main a cote d'un generateur est une
# bombe a retardement — il est genere ici, avec le reste.
GABARIT = {
    "_doc": ("Rig d'un template de squelette (docs: Squelette modulaire et points d'attache). Généré par "
             "tools/gen_rigs.py. Un segment = {parent, ancrage (sur le parent), longueur, largeur, angle de repos dans "
             "le plan du corps (90 = vers le bas de l'écran), profondeur (degrés hors de ce plan, positif = vers "
             "l'avant), ancrages portés [le_long, en_travers, en_profondeur], zone de coup}. `orientations` : le "
             "lacet du corps et la vue de la tête pour chacune des huit directions ; `ordre` ne sert qu'à "
             "départager deux segments à la même profondeur, c'est la profondeur qui décide du dessin. "
             "`lacet_actif` : faux pour un rig encore écrit dans le plan de l'écran (les animaux). "
             "slots_segments : quel slot d'armure peint quels segments."),
    "name_key": "rig.<id>.name",
    "racine": "torse",
    "hauteur_pieds": 13,
    "lacet_actif": True,
    "segments": {
        "torse": seg(None, None, 14, 9, -90, {"cou": [14, 0, 0], "epaule_G": [12, -5, -1.5], "epaule_D": [12, 5, -1.5]}, "torse"),
        "tete": seg("torse", "cou", 8, 8, -90, {}, "tete"),
    },
    "ordre": ["torse", "tete"],
    "slots_segments": {"casque": ["tete"], "cuirasse": ["torse"]},
    "prise_arme": None, "prise_bouclier": None,
}
ecrire("_template", GABARIT)
