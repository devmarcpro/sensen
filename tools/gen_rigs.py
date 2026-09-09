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

`lacet_actif` : tous les rigs sauf l'amorphe tournent pour de bon depuis le 2026-09-09. Les rigs animaux étaient
écrits comme des dessins de PROFIL — leur axe long était l'axe `x` de l'écran — et le lacet les aurait couchés dans
la profondeur à toutes les orientations, y compris celle où ils étaient justes. Réécrits en espace du corps, leur axe
long est l'axe de PROFONDEUR : à lacet nul le museau vient vers la caméra (une vue de face, gratuite), à 90 degrés le
corps se remet à l'horizontale et l'on retrouve exactement le profil d'avant. L'amorphe garde `false` : une masse
n'a pas d'orientation, et la faire tourner ne ferait que l'amincir.

`epaisseur` : un segment est un cylindre à section elliptique, pas un ruban — `largeur` d'un côté à l'autre,
`epaisseur` de l'avant à l'arrière. Un torse vu de profil fait son épaisseur ; omise, elle vaut
`largeur × styles.sprites.epaisseur_defaut`.

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


def seg(parent, ancrage, longueur, largeur, angle=90, ancrages=None, zone=None, profondeur=0.0, epaisseur=None):
    # `epaisseur` : la mesure DE L'AVANT À L'ARRIÈRE. Un segment est un cylindre à section elliptique, pas un
    # ruban — un torse vu de profil fait son épaisseur, pas une fraction arbitraire de sa largeur. Omise, elle
    # vaut `largeur × styles.sprites.epaisseur_defaut`.
    d = {"parent": parent, "ancrage": ancrage, "longueur": longueur, "largeur": largeur,
         "angle": angle, "ancrages": ancrages or {}, "zone": zone}
    if profondeur:
        d["profondeur"] = profondeur
    if epaisseur is not None:
        d["epaisseur"] = epaisseur
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
        "bassin": seg(None, None, 5, 8, -90, {"taille": [5, 0, 0], "hanche_G": [0, -2.5, -1], "hanche_D": [0, 2.5, -1]}, "torse", epaisseur=6),
        "torse": seg("bassin", "taille", 9, 9, -90, {"cou": [9, 0, -1], "epaule_G": [7, -5, -1.5], "epaule_D": [7, 5, -1.5], "dos": [3, 0, 2]}, "torse", epaisseur=6),
        "tete": seg("torse", "cou", 8, 8, -90, {}, "tete", epaisseur=8),   # une tête est aussi profonde que large
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
    "lacet_actif": True,
    "segments": {
        # LE CORPS EST COUCHE LE LONG DE L'AXE DE PROFONDEUR (2026-09-09) : `angle` -90 met l'axe de largeur a
        # l'horizontale, `profondeur` 90 couche le corps. A lacet nul, le museau vient vers la camera — une vue de
        # face, qu'on n'avait pas ; a 90 degres, le corps se remet a l'horizontale et l'on retrouve le profil d'avant.
        "torse": seg(None, None, 20, 8, -90, {"cou": [20, 0, 3], "epaule_AV_G": [17, 3, 0], "epaule_AV_D": [17, -3, 0],
                                              "epaule_AR_G": [3, 3, 0], "epaule_AR_D": [3, -3, 0], "dos": [10, 0, 4]},
                     "torse", 90, epaisseur=9),
        "tete": seg("torse", "cou", 7, 6, -90, {}, "tete", 70, epaisseur=6),
        "patte_AV_G": seg("torse", "epaule_AV_G", 6, 2.5, 95, {"pied": [6, 0, 0]}, "jambes", epaisseur=2.5),
        "patte_AV_D": seg("torse", "epaule_AV_D", 6, 2.5, 85, {"pied": [6, 0, 0]}, "jambes", epaisseur=2.5),
        "patte_AR_G": seg("torse", "epaule_AR_G", 6, 2.5, 95, {"pied": [6, 0, 0]}, "jambes", epaisseur=2.5),
        "patte_AR_D": seg("torse", "epaule_AR_D", 6, 2.5, 85, {"pied": [6, 0, 0]}, "jambes", epaisseur=2.5),
        "pied_AV_G": seg("patte_AV_G", "pied", 4, 2.5, 90, {}, "pieds", 35, epaisseur=2.5),
        "pied_AV_D": seg("patte_AV_D", "pied", 4, 2.5, 90, {}, "pieds", 35, epaisseur=2.5),
        "pied_AR_G": seg("patte_AR_G", "pied", 4, 2.5, 90, {}, "pieds", 35, epaisseur=2.5),
        "pied_AR_D": seg("patte_AR_D", "pied", 4, 2.5, 90, {}, "pieds", 35, epaisseur=2.5),
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
    "lacet_actif": True,
    "segments": {
        # Le corps couche vers la camera (2026-09-09) ; les ailes, elles, s'ouvrent dans le PLAN FRONTAL — a lacet
        # nul on voit l'oiseau de face, ailes deployees ; a 90 degres elles se raccourcissent d'elles-memes, ce qui
        # est exactement ce qu'on voit d'un oiseau de profil.
        "torse": seg(None, None, 10, 6, -90, {"cou": [10, 0, 1], "aile_G": [5, 3, 0], "aile_D": [5, -3, 0]},
                     "torse", 90, epaisseur=6),
        "tete": seg("torse", "cou", 4, 4, -90, {}, "tete", 70, epaisseur=4),
        "aile_G": seg("torse", "aile_G", 14, 5, 200, {}, "bras", epaisseur=1.5),
        "aile_D": seg("torse", "aile_D", 14, 5, -20, {}, "bras", epaisseur=1.5),
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
    "lacet_actif": True,
    "segments": {
        # Le corps couche vers la camera ; les huit pattes s'ouvrent dans le plan frontal, quatre a gauche et quatre
        # a droite. Leur ecart LE LONG du corps (3, 6, 9, 11) est desormais un ecart EN PROFONDEUR : les pattes avant
        # sont les plus proches de nous et se dessinent donc en dernier, sans qu'on l'ecrive nulle part.
        "torse": seg(None, None, 12, 9, -90, {"cou": [12, 0, 1],
                                              "p1G": [3, 4, 0], "p2G": [6, 4, 0], "p3G": [9, 4, 0], "p4G": [11, 4, 0],
                                              "p1D": [3, -4, 0], "p2D": [6, -4, 0], "p3D": [9, -4, 0], "p4D": [11, -4, 0]},
                     "torse", 90, epaisseur=7),
        "tete": seg("torse", "cou", 5, 4, -90, {}, "tete", 70, epaisseur=4),
        "patte_1G": seg("torse", "p1G", 7, 1.8, 100, {}, "jambes", epaisseur=1.8),
        "patte_2G": seg("torse", "p2G", 7, 1.8, 120, {}, "jambes", epaisseur=1.8),
        "patte_3G": seg("torse", "p3G", 7, 1.8, 140, {}, "jambes", epaisseur=1.8),
        "patte_4G": seg("torse", "p4G", 7, 1.8, 160, {}, "jambes", epaisseur=1.8),
        "patte_1D": seg("torse", "p1D", 7, 1.8, 80, {}, "jambes", epaisseur=1.8),
        "patte_2D": seg("torse", "p2D", 7, 1.8, 60, {}, "jambes", epaisseur=1.8),
        "patte_3D": seg("torse", "p3D", 7, 1.8, 40, {}, "jambes", epaisseur=1.8),
        "patte_4D": seg("torse", "p4D", 7, 1.8, 20, {}, "jambes", epaisseur=1.8),
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
    "lacet_actif": True,
    "segments": {
        # Le corps vient vers la camera ; la queue ondule dans le plan HORIZONTAL (x, z) et non plus dans celui de
        # l'ecran : `angle` 0 pose la direction dans ce plan, `profondeur` la fait tourner. Un serpent love se voit
        # donc en plongee, comme le reste du monde, au lieu d'onduler verticalement comme un ressort.
        "torse": seg(None, None, 10, 6, -90, {"cou": [10, 0, 1], "q1": [0, 0, 0]}, "torse", 90, epaisseur=6),
        "tete": seg("torse", "cou", 6, 5, -90, {}, "tete", 70, epaisseur=5),
        "c1": seg("torse", "q1", 8, 5, 0, {"q2": [8, 0, 0]}, "torse", -120, epaisseur=5),
        "c2": seg("c1", "q2", 7, 4, 0, {"q3": [7, 0, 0]}, "torse", -60, epaisseur=4),
        "c3": seg("c2", "q3", 6, 3, 0, {}, "torse", -120, epaisseur=3),
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
