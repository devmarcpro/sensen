# -*- coding: utf-8 -*-
"""Ajoute le champ structuré `effet` aux modules que le résolveur consomme (docs: Modules,
Vocabulaire des modules — six axes, décision du 2026-08-26).

    python tools/structure_modules.py

Les descriptions restent la référence lisible ; `effet` en est la transcription exécutable.
Un module sans `effet` n'est pas encore résolu par le code (le loader l'accepte, l'assembleur
le signale en debug). Relançable : idempotent.
"""
import io, json, os, glob

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "modules"))

# Modificateurs : ce qu'ils changent sur le noyau suivant (les ticks sont déjà dans surcout_ticks,
# la ressource dans surcout_ressource).
MODIFICATEURS = {
    "concentration": {"des": 1},
    "surcharge": {"des": 2},
    "focale": {"des": 1, "taille": -1},
    "corps_a_corps": {"des": 2, "portee_fixe": 1},
    "longue_vue": {"des": -1, "portee_mult": 2},
    "precipitation": {"des": -1},
    "allonge": {"portee": 2},
    "sans_angle_mort": {"portee_min": 1},
    "ampleur": {"taille": 1},
    "perforant": {"ignore_armure": True},
    "vampirique": {"vampirique": 0.5},
    "persistance": {"durees_mult": 2},
    "vivacite": {},
    "patience": {},
    "repulsion": {"projection": 1},
    "gravite": {"attraction": 1},
    "pureté": {},
    "purete": {"purification": 0.4},
    "amorce": {"segments": 1},
}

# Conditions : prédicat structuré + bonus structuré. Échec : ne part pas, rend 50 % des ticks.
CONDITIONS = {
    "surplomb": ({"type": "hauteur_relative", "signe": ">"}, {"des": 2}),
    "contrebas": ({"type": "hauteur_relative", "signe": "<"}, {"portee": 2, "ticks": -1}),
    "angle_mort": ({"type": "dos_ou_flanc"}, {"des": 3}),
    "champ_libre": ({"type": "ligne_de_vue_degagee"}, {"ticks": -2}),
    "pied_ferme": ({"type": "porteur_immobile_depuis", "ticks": 20}, {"des": 2}),
    "isolement": ({"type": "cible_isolee"}, {"des": 2}),
    "escorte": ({"type": "cible_adjacente_a_allie"}, {"des": 1, "taille": 1}),
    "achevement": ({"type": "pv_cible_sous", "pct": 30}, {"des": 3}),
    "affinite": ({"type": "element_cible", "element": "X"}, {"mult": 1.2}),
    "entravee": ({"type": "cible_immobilisee"}, {"des": 2}),
    "dernier_souffle": ({"type": "pv_porteur_sous", "pct": 40}, {"des": 3}),
    "pleine_garde": ({"type": "porteur_en_posture"}, {"ticks": -2, "des": 1}),
    "resonance": ({"type": "segment_chaine_present", "element": "X"}, {"des": 2}),
    "chaine_pleine": ({"type": "jauge_chaine_pleine"}, {"des": 3, "ticks": -3}),
}

# Noyaux dont l'effet a des paramètres au-delà de power_base/effets.
NOYAUX = {
    "estoc": {"ignore_armure_points": 4},
    "botte": {"deplacement": {"mode": "recul", "cible": "soi", "distance": "1"}},
    "charge_d_epaule": {"deplacement": {"mode": "projection", "distance": "2"}},
    "poussee": {"deplacement": {"mode": "projection", "distance": "2"}},
    "attraction": {"deplacement": {"mode": "attraction", "distance": "2"}},
    "elan": {"deplacement": {"mode": "saut", "cible": "soi", "distance": "3"}},
    "permutation": {"deplacement": {"mode": "permutation"}},
    "transfert": {"soin": {"source": "pv_porteur"}},
    "second_souffle": {"ressource": {"endurance": 30}},
    "trait_nu": {"sans_segment": True},
    "barriere": {"invocation": {"contenu": "barriere", "duree_ticks": 50}},
    "exhaussement": {"terrain": {"delta": 1}},
    "fosse": {"terrain": {"delta": -3, "chute": True}},
    "racine": {"statut": {"id": "enracinement", "duree_ticks": 10}},
}

# Liaisons et déclencheurs résolus par le prototype (décision du 2026-08-27).
LIAISONS = {
    "repetition": {"rejoue": 2, "des": -1},
    "ricochet": {"sauts": "1d3", "des": -1, "portee": 2},
    "dispersion": {"dispersion": True},
    "miroir": {"miroir": True},
    "partage": {"partage": True},
    "echo": {"echo": 0.5, "apres_ticks": 20},
    "propagation": {"propagation": True, "des": -1},
    "salve": {"salve": 3, "mult": 0.6},
    "contagion": {"contagion": True},
    "boucle": {"boucle": True, "des": -1},
}
DECLENCHEURS = {
    "a_l_impact": {"declencheur": "impact"},
    "curee": {"declencheur": "mise_a_mort"},
    "sceau": {"declencheur": "entree", "duree_ticks": 100},
    "meche": {"declencheur": "apres_ticks", "ticks": 20},
    "riposte": {"declencheur": "riposte"},
    "parade": {"declencheur": "parade"},
    "ouverture": {"declencheur": "ouverture"},
    "veille": {"declencheur": "veille", "pct": 40},
    "testament": {"declencheur": "testament"},
    "accord": {"declencheur": "accord"},
    "cadence": {"declencheur": "cadence", "n": 3},
}

n = 0
for p in sorted(glob.glob(os.path.join(ROOT, "**", "*.json"), recursive=True)):
    d = json.load(open(p, encoding="utf-8"))
    id_ = d["id"]
    effet = None
    if d["module_type"] == "modificateur" and id_ in MODIFICATEURS:
        effet = MODIFICATEURS[id_]
    elif d["module_type"] == "condition" and id_ in CONDITIONS:
        pred, bonus = CONDITIONS[id_]
        effet = {"predicat_structure": pred, "bonus_structure": bonus, "echec_ticks_rendus": 0.5}
    elif d["module_type"] == "noyau" and id_ in NOYAUX:
        effet = NOYAUX[id_]
    elif d["module_type"] == "liaison" and id_ in LIAISONS:
        effet = LIAISONS[id_]
    elif d["module_type"] == "declencheur" and id_ in DECLENCHEURS:
        effet = DECLENCHEURS[id_]
    if effet is not None:
        d["effet"] = effet
        n += 1
        with io.open(p, "w", encoding="utf-8", newline="\n") as f:
            json.dump(d, f, ensure_ascii=False, indent=2)
            f.write("\n")
print("%d modules structures" % n)
