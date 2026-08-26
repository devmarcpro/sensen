# -*- coding: utf-8 -*-
"""Transcrit le catalogue des 24 actions de créatures en JSON (docs: Actions des créatures).

    python tools/gen_creature_actions.py

Schéma : les six axes de « Vocabulaire des modules — six axes » (Décision — Vocabulaire
d'attaque des créatures). Une ligne de la table = un fichier. Valeurs de premier
équilibrage : on ajuste ici ET dans la note, jamais dans le code.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "creature_actions"))

# id, elements, forme, portee, taille, cible, ticks, endurance, dés, type, conditions, effets, tags
A = []


def action(id_, elem, forme, portee, taille, ticks, endurance, des, type_, effets=(), conditions=(), cible="ennemi", tags=(), ldv=True):
    A.append({
        "name_key": "creature_action.%s.name" % id_,
        "elements": ({elem: 1.0} if elem else {}),
        "forme": forme, "portee": list(portee), "taille": taille, "cible": cible,
        "ligne_de_vue": ldv, "cout_ticks": ticks, "cout_endurance": endurance,
        "degats_des": des, "type_degats": type_,
        "conditions": list(conditions),
        "effets": list(effets),
        "tags": list(tags), "_id": id_,
    })


D = {"type": "degats"}
# Morsures et griffes
action("morsure", "bois", "cible_unique", (1, 1), 1, 8, 6, "1d6", "perforant", [D], tags=["morsure"])
action("morsure_puissante", "bois", "cible_unique", (1, 1), 1, 12, 10, "2d6", "perforant",
       [D, {"type": "statut", "id": "saignement", "duree_ticks": 30}], tags=["morsure"])
action("morsure_venimeuse", "bois", "cible_unique", (1, 1), 1, 10, 6, "1d4", "perforant",
       [D, {"type": "statut", "id": "poison", "duree_ticks": 50}], tags=["morsure", "poison"])
action("griffure", "bois", "cible_unique", (1, 1), 1, 6, 5, "1d4", "tranchant", [D], tags=["griffe"])
action("coup_de_patte", "terre", "cible_unique", (1, 1), 1, 12, 10, "2d6", "contondant",
       [D, {"type": "deplacement", "mode": "projection", "distance": "1"}], tags=["coup"])
# Charges et coups (télégraphés)
action("charge", "terre", "ligne", (1, 3), 3, 14, 12, "2d6", "contondant",
       [D, {"type": "deplacement", "mode": "projection", "distance": "1d3"},
        {"type": "deplacement", "mode": "au_contact", "cible": "soi"}], tags=["charge", "telegraphe"])
action("coup_de_defenses", "metal", "cible_unique", (1, 1), 1, 10, 8, "1d8", "perforant", [D], tags=["coup"])
action("coup_de_tete", "terre", "cible_unique", (1, 1), 1, 12, 10, "1d8", "contondant",
       [D, {"type": "deplacement", "mode": "projection", "distance": "1"}],
       conditions=[{"type": "hauteur_relative", "valeur": "plus_haut", "bonus": {"des": 1}}], tags=["coup"])
action("masse_ecrasante", "terre", "cible_unique", (1, 1), 1, 16, 14, "2d8", "contondant", [D], tags=["coup"])
action("ruade", "terre", "cible_unique", (1, 1), 1, 10, 8, "1d6", "contondant",
       [D, {"type": "deplacement", "mode": "projection", "distance": "1"}, {"type": "fuite"}], tags=["coup"])
# Meute et essaim
action("harcelement_meute", "bois", "cible_unique", (1, 1), 1, 8, 6, "1d4", "perforant", [D],
       conditions=[{"type": "cible_adjacente_a_allie", "bonus": {"des": 1}}], tags=["morsure", "meute"])
action("hurlement", "bois", "anneau", (0, 0), 3, 12, 4, None, None,
       [{"type": "statut", "id": "hate_meute", "duree_ticks": 30}], cible="allie", tags=["meute", "telegraphe"], ldv=False)
action("dard_essaim", "bois", "anneau", (0, 0), 1, 8, 4, "1d4", "perforant",
       [D, {"type": "statut", "id": "poison", "duree_ticks": 20}], cible="toute_entite", tags=["poison"], ldv=False)
action("nuee", "eau", "soi", (0, 0), 1, 10, 0, "1", "perforant",
       [D, {"type": "statut", "id": "infection", "chance": 0.1}], cible="toute_entite", tags=["aura", "continu"], ldv=False)
# Embuscade et venin
action("pique_venimeuse", "eau", "cible_unique", (1, 1), 1, 10, 6, "1d4", "perforant",
       [D, {"type": "statut", "id": "poison", "duree_ticks": 50}], tags=["poison"])
action("pinces", "metal", "cible_unique", (1, 1), 1, 8, 6, "1d4", "tranchant", [D, D], tags=["coup"])
action("machoire_verrouillee", "eau", "cible_unique", (1, 1), 1, 16, 14, "2d8", "perforant",
       [D, {"type": "statut", "id": "enracinement", "duree_ticks": 10}], tags=["morsure", "telegraphe"])
action("embuscade", None, "soi", (0, 0), 0, 0, 0, None, None,
       [{"type": "bonus_premiere_attaque", "des": 2}], cible="soi", tags=["passive"], ldv=False)
action("bond", "bois", "cible_unique", (1, 3), 1, 12, 10, "1d6", "tranchant",
       [{"type": "deplacement", "mode": "saut", "cible": "soi", "distance": "3", "ignore_obstacles": 1}, D], tags=["saut", "telegraphe"])
# Volants
action("pique_plongeant", "bois", "ligne", (1, 4), 4, 14, 12, "2d6", "tranchant",
       [D], tags=["vol", "ignore_denivele", "telegraphe"])
action("serres", "metal", "cible_unique", (1, 1), 1, 8, 6, "1d6", "tranchant", [D], tags=["griffe"])
action("becquetage", "metal", "cible_unique", (1, 1), 1, 6, 5, "1d4", "perforant", [D], tags=["coup"])
# Élites
action("cri_de_ralliement", "feu", "anneau", (0, 0), 4, 12, 6, None, None,
       [{"type": "statut", "id": "ralliement", "duree_ticks": 40}], cible="allie", tags=["elite", "telegraphe"], ldv=False)
action("enchainement", None, "cible_unique", (1, 1), 1, 14, 12, None, None,
       [{"type": "attaque_arme"}, {"type": "attaque_arme"}], tags=["elite", "telegraphe"])

for a in A:
    id_ = a.pop("_id")
    p = os.path.join(ROOT, id_ + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(a, f, ensure_ascii=False, indent=2)
        f.write("\n")
print("%d actions ecrites dans %s" % (len(A), ROOT))
