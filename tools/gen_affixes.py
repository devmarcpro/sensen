# -*- coding: utf-8 -*-
"""Écrit les 36 gabarits d'affixes (docs: Loot — affixes, gemmes et rareté ; Ouvert — Fourchettes
des gemmes : 6 gabarits × 6 familles).

    python tools/gen_affixes.py

Un affixe est un GÉNÉRATEUR : des fourchettes tirées à la génération de l'objet, jamais un effet
fixe. `parametres` = {nom: [min, max]} ou {nom: "element"} (tirage parmi les cinq) ;
`effet.type` est ce que le résolveur exécute ; `meilleur` dit dans quel sens un tirage est bon
(le budget de rareté pioche dans le meilleur tiers). `slots_valides` : armes et/ou armures.
Un gabarit `inerte` est chargé et tiré mais son prédicat attend un système absent (cycle
jour-nuit, corruption, densité de mana, poids porté) — signalé ici, pas caché.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "affixes"))
A = {}


def affixe(id_, famille, slots, parametres, effet, meilleur, inerte=False, tags=()):
    A[id_] = {"name_key": "affixe.%s.nom" % id_, "famille": famille, "slots_valides": list(slots),
              "parametres": parametres, "effet": effet, "meilleur": meilleur, "inerte": inerte, "tags": list(tags)}


ARMES = ["main_principale"]
ARMURES = ["casque", "cuirasse", "brassards", "jambieres", "bottes"]
BIJOUX = ["anneau", "amulette"]

# RYTHMIQUES — compteurs par objet
affixe("cadence_element", "rythmique", ARMES, {"n": [2, 4], "element": "element"}, {"type": "cadence_element"}, {"n": "bas"})
affixe("cadence_des", "rythmique", ARMES, {"n": [3, 5], "des": [1, 3]}, {"type": "cadence_des"}, {"n": "bas", "des": "haut"})
affixe("cadence_percant", "rythmique", ARMES, {"n": [4, 7], "pct": [50, 100]}, {"type": "cadence_percant"}, {"n": "bas", "pct": "haut"})
affixe("cadence_saignee", "rythmique", ARMES, {"n": [3, 6]}, {"type": "cadence_statut", "statut": "saignement", "duree_ticks": 30}, {"n": "bas"})
affixe("cadence_parade", "rythmique", ARMURES, {"n": [2, 4], "endurance": [4, 10]}, {"type": "cadence_garde_endurance"}, {"n": "bas", "endurance": "haut"})
affixe("cadence_riposte", "rythmique", ARMURES, {"n": [3, 5], "des": [1, 2]}, {"type": "cadence_riposte_des"}, {"n": "bas", "des": "haut"})
# CONDITIONNELS — lus sur des seuils physiques
affixe("cond_pv_bas", "conditionnel", ARMES, {"pct_pv": [30, 60], "des": [1, 3]}, {"type": "cond_pv"}, {"pct_pv": "haut", "des": "haut"})
affixe("cond_element_cible", "conditionnel", ARMES, {"element": "element", "pct": [15, 35]}, {"type": "cond_element_cible"}, {"pct": "haut"})
affixe("cond_profondeur", "conditionnel", ARMES + ARMURES, {"etage": [2, 4], "des": [1, 2]}, {"type": "cond_profondeur"}, {"etage": "bas", "des": "haut"})
affixe("cond_nuit", "conditionnel", ARMES + ARMURES, {"pct": [10, 20]}, {"type": "cond_nuit_vitesse"}, {"pct": "haut"}, inerte=True)
affixe("cond_corruption", "conditionnel", ARMES, {"seuil": [40, 70], "pct": [15, 30]}, {"type": "cond_corruption"}, {"seuil": "bas", "pct": "haut"}, inerte=True)
affixe("cond_mana", "conditionnel", ARMES + BIJOUX, {"pct": [15, 30]}, {"type": "cond_densite_mana_cout"}, {"pct": "haut"}, inerte=True)
# WU XING — l'identité élémentaire
affixe("wuxing_cycle", "wuxing", ARMES, {}, {"type": "wuxing_avance"}, {})
affixe("wuxing_ajout", "wuxing", ARMES + ARMURES, {"element": "element", "pct": [20, 40]}, {"type": "wuxing_ajout"}, {"pct": "haut"})
affixe("wuxing_segment", "wuxing", ARMES + BIJOUX, {}, {"type": "wuxing_segment"}, {}, tags=["rare"])
affixe("wuxing_combo", "wuxing", ARMES, {}, {"type": "wuxing_combo_des"}, {}, tags=["tres_rare"])
affixe("wuxing_purete", "wuxing", ARMES, {"pct": [10, 25]}, {"type": "wuxing_purification"}, {"pct": "haut"})
affixe("wuxing_domination", "wuxing", ARMURES, {"pct": [5, 15]}, {"type": "wuxing_defense"}, {"pct": "haut"})
# DÉCLENCHEURS
affixe("decl_zone_etourdit", "declencheur", ARMES, {"zone": ["tete"], "duree_ticks": [6, 12]}, {"type": "decl_zone_statut", "statut": "etourdi"}, {"duree_ticks": "haut"})
affixe("decl_zone_saigne", "declencheur", ARMES, {"zone": ["torse", "jambes"], "duree_ticks": [20, 40]}, {"type": "decl_zone_statut", "statut": "saignement"}, {"duree_ticks": "haut"})
affixe("decl_parade", "declencheur", ARMURES, {"endurance": [3, 8]}, {"type": "decl_parade_endurance"}, {"endurance": "haut"})
affixe("decl_mise_a_mort", "declencheur", ARMES, {"pct": [8, 15], "ticks": [30, 60]}, {"type": "decl_mise_a_mort_hate"}, {"pct": "haut", "ticks": "haut"})
affixe("decl_touche_etourdit", "declencheur", ARMURES, {"duree_ticks": [4, 8], "chance": [10, 25]}, {"type": "decl_touche_statut", "statut": "etourdi"}, {"duree_ticks": "haut", "chance": "haut"})
affixe("decl_touche_saigne", "declencheur", ARMURES, {"duree_ticks": [20, 40], "chance": [15, 35]}, {"type": "decl_touche_statut", "statut": "saignement"}, {"duree_ticks": "haut", "chance": "haut"})
# MÉCANIQUES
affixe("meca_vol_de_vie", "mecanique", ARMES, {"pct": [3, 8]}, {"type": "meca_vol_de_vie"}, {"pct": "haut"})
affixe("meca_allonge", "mecanique", ARMES, {"n": [1, 2]}, {"type": "meca_allonge"}, {"n": "haut"})
affixe("meca_garde", "mecanique", ARMURES, {"pct": [20, 40]}, {"type": "meca_garde_endurance"}, {"pct": "haut"})
affixe("meca_capacite", "mecanique", ARMURES + BIJOUX, {"kg": [10, 30]}, {"type": "meca_capacite"}, {"kg": "haut"}, inerte=True)
affixe("meca_endurance_max", "mecanique", ARMURES + BIJOUX, {"n": [5, 15]}, {"type": "meca_endurance_max"}, {"n": "haut"})
affixe("meca_armure", "mecanique", ARMURES, {"n": [1, 3]}, {"type": "meca_armure"}, {"n": "haut"})
# BIJOUX (effets passifs des pools de « Effets d'équipement types », sous forme d'affixes)
affixe("passif_stat", "passif", BIJOUX, {"stat": ["force", "dexterite", "endurance", "volonte", "perception", "charisme"], "n": [1, 3]}, {"type": "passif_stat"}, {"n": "haut"})
affixe("passif_competence", "passif", BIJOUX + ARMURES, {"competence": ["meditation", "esquive", "discretion", "athletisme", "lecture", "leadership"], "n": [2, 6]}, {"type": "passif_competence"}, {"n": "haut"})
affixe("passif_surchauffe", "passif", BIJOUX, {"mult": [60, 90]}, {"type": "passif_mecanique", "mecanique": "surchauffe_mult"}, {"mult": "bas"})
affixe("passif_regen", "passif", BIJOUX, {"pct": [50, 100]}, {"type": "passif_mecanique", "mecanique": "regen_sante"}, {"pct": "haut"}, inerte=True)
affixe("passif_vitesse", "passif", ["bottes"] + BIJOUX, {"pct": [5, 15]}, {"type": "passif_mecanique", "mecanique": "vitesse_deplacement"}, {"pct": "haut"})
affixe("passif_tag", "passif", BIJOUX, {"tag": ["vision_nocturne", "pas_silencieux", "immunite_poison", "detection_tresors"]}, {"type": "passif_tag"}, {})

os.makedirs(ROOT, exist_ok=True)
for id_, d in A.items():
    with io.open(os.path.join(ROOT, id_ + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")
print("%d affixes" % len(A))
