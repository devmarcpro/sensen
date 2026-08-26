# -*- coding: utf-8 -*-
"""Transcrit les statuts du prototype en JSON (docs: Statuts, Statuts de contrôle et anti-stunlock).

    python tools/gen_status_effects.py

« Tour » de l'ancien texte = une période de 10 ticks (décision du 2026-08-26). Un statut est
un dictionnaire de tags et de modificateurs — les systèmes lisent les tags, jamais l'id.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data", "status_effects"))
S = {}


def statut(id_, duree, des=None, element=None, periode=10, modifiers=(), tags=(), controle=False, cumule=False):
    S[id_] = {
        "name_key": "status.%s.name" % id_,
        "degats_des": des, "element": element, "periode_ticks": periode, "duree_ticks": duree,
        "controle": controle, "cumule": cumule,
        "modifiers": list(modifiers), "tags": list(tags),
    }


statut("brulure", 30, "1d4", "feu", tags=["dot", "feu", "negatif"])
statut("poison", 50, "1d3", None, tags=["dot", "poison", "negatif"], cumule=True)
statut("saignement", 40, "1d4", None, tags=["dot", "saignement", "negatif"])
statut("infection", 200, None, None, tags=["maladie", "negatif"])
statut("ralentissement", 30, modifiers=[{"cible": "cout_ticks", "mult": 1.3}], tags=["negatif"])
statut("hate", 30, modifiers=[{"cible": "cout_ticks", "mult": 0.8}], tags=["positif"])
statut("hate_meute", 30, modifiers=[{"cible": "cout_ticks", "mult": 0.9}], tags=["positif", "meute"])
statut("ralliement", 40, modifiers=[{"cible": "degats", "mult": 1.15}], tags=["positif"])
statut("etourdi", 10, modifiers=[{"cible": "compteur", "add": 10}], tags=["controle", "interrompt", "negatif"], controle=True)
statut("enracinement", 10, modifiers=[{"cible": "deplacement", "bloque": True}], tags=["controle", "negatif"], controle=True)
statut("retarde", 10, modifiers=[], tags=["controle", "negatif"], controle=True)
statut("egide", 50, modifiers=[{"cible": "armure", "add": 6}], tags=["positif", "defense"])
statut("garde_annulee", 15, modifiers=[{"cible": "garde", "bloque": True}], tags=["negatif"])
statut("terreur", 20, modifiers=[{"cible": "fuite", "bloque": False}], tags=["controle", "negatif"], controle=True)

for id_, d in S.items():
    p = os.path.join(ROOT, id_ + ".json")
    with io.open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")
print("%d statuts ecrits" % len(S))
