# -*- coding: utf-8 -*-
"""La documentation promet-elle des choses que le code n'a pas ?

`check_vault.py` verifie que les LIENS entre notes tiennent. Personne ne verifiait que les
IDENTIFIANTS cites dans les notes existent vraiment : une note peut nommer `combat_rules.machin`,
une fonction `_faire_le_truc()` ou un fichier `data/trucs/` disparus depuis six semaines, et rien ne
le dit. C'est la rouille la plus sournoise d'un coffre qui fait autorite : le jour ou on relit la
note pour retrouver comment marche un systeme, elle ment.

On ne verifie que ce qui est VERIFIABLE sans ambiguite :
  - les chemins `data/...` et `res://...` cites entre accents graves ;
  - les cles de configuration de la forme `fichier.cle` quand `fichier` est un catalogue connu ;
  - les noms de fonction de la forme `nom_de_fonction()` en snake_case.

Le reste — les tournures en prose, les noms de concepts — est laisse tranquille : un outil qui crie
au loup sur du francais serait ignore en une semaine, et un outil ignore ne sert a rien.

    python tools/verif_doc_code.py
"""
import io
import os
import re
import sys
import glob

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(RACINE, "docs")
GODOT = os.path.join(RACINE, "godot")

# Les identifiants qu'on sait verifier, et rien d'autre.
RE_CHEMIN = re.compile(r"`(res://[^`]+|data/[a-z0-9_/.\-]+)`")
RE_FONCTION = re.compile(r"`([a-z_][a-z0-9_]{3,})\(\)`")
RE_CONFIG = re.compile(r"`([a-z_]+)\.([a-z_][a-z0-9_.]*)`")
# `combat_rules.json` nomme un FICHIER, pas une cle : le premier jet du verificateur signalait
# dix-neuf faux positifs de cette forme, et un outil qui crie au loup est un outil qu'on desactive.
EXT_FICHIER = {"json", "md", "gd", "tscn", "csv", "png", "py"}

# Ce qui ressemble a une fonction mais n'en est pas : on ne va pas se battre avec le francais.
IGNORE_FONCTIONS = {"etc", "cf", "ex"}


def lire(chemin):
    return io.open(chemin, encoding="utf-8").read()


def source_godot():
    """Tout le code et le nom de tous les fichiers de donnees, en un seul bloc de texte."""
    morceaux = []
    fichiers = set()
    for base, _, noms in os.walk(GODOT):
        if ".godot" in base:
            continue
        for n in noms:
            fichiers.add(n)
            if n.endswith((".gd", ".json", ".tscn")):
                try:
                    morceaux.append(lire(os.path.join(base, n)))
                except (OSError, UnicodeDecodeError):
                    pass
    return "\n".join(morceaux), fichiers


def main():
    if not os.path.isdir(DOCS):
        print("pas de dossier docs/")
        return 0
    code, fichiers = source_godot()
    catalogues = {
        os.path.basename(p)[:-5]
        for p in glob.glob(os.path.join(GODOT, "data", "*.json"))
    }
    problemes = {}
    n_notes = 0
    for chemin in glob.glob(os.path.join(DOCS, "**", "*.md"), recursive=True):
        n_notes += 1
        note = os.path.relpath(chemin, DOCS)
        texte = lire(chemin)
        for m in RE_CHEMIN.finditer(texte):
            ref = m.group(1)
            rel = ref.replace("res://", "").split("#")[0].rstrip("/")
            if not rel:
                continue
            cible = os.path.join(GODOT, rel)
            if os.path.exists(cible) or os.path.basename(rel) in fichiers:
                continue
            if os.path.isdir(os.path.join(GODOT, rel.rstrip("/"))):
                continue
            problemes.setdefault("chemin cite qui n'existe pas", []).append("%s : %s" % (note, ref))
        for m in RE_FONCTION.finditer(texte):
            nom = m.group(1)
            if nom in IGNORE_FONCTIONS:
                continue
            if ("func %s(" % nom) in code or ("%s(" % nom) in code:
                continue
            problemes.setdefault("fonction citee qui n'existe pas", []).append("%s : %s()" % (note, nom))
        for m in RE_CONFIG.finditer(texte):
            fichier, cle = m.group(1), m.group(2)
            if fichier not in catalogues:
                continue   # on ne juge que ce qui nomme un catalogue connu
            if cle in EXT_FICHIER:
                continue
            racine = cle.split(".")[0]
            if ('"%s"' % racine) in code:
                continue
            problemes.setdefault("cle de configuration citee qui n'existe pas", []).append(
                "%s : %s.%s" % (note, fichier, cle))
    total = sum(len(v) for v in problemes.values())
    for titre in sorted(problemes):
        print("\n== %s (%d)" % (titre, len(problemes[titre])))
        for ligne in sorted(set(problemes[titre]))[:20]:
            print("   ", ligne)
    if not problemes:
        print("%d notes : chaque chemin, fonction et cle citee existe dans le code" % n_notes)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
