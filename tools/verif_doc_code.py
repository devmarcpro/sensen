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
  - les noms de fonction de la forme `nom_de_fonction()` en snake_case ;
  - les CLES DE DONNEES citees nues entre accents graves (`cout_vigueur`, `forme_grille`) : un
    snake_case avec un tiret bas, qui doit exister comme cle JSON, identifiant de code ou nom de
    fichier. Ajoute le 2026-09-03 : six notes citaient encore `cout_endurance`, renomme la veille,
    et l'outil ne le voyait pas parce qu'il ne regardait que les cles de la forme `fichier.cle`.

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
# Une cle de donnees citee nue : snake_case, au moins un tiret bas, pas de point ni de parenthese.
RE_CLE_NUE = re.compile(r"`([a-z][a-z0-9]*(?:_[a-z0-9]+)+)`")


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
    stems = {os.path.splitext(n)[0] for n in fichiers}
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
        # Une note d'audit d'un heritage retire cite a dessein des identifiants morts : on ne la juge
        # pas. De meme, une ligne qui dit qu'un nom est ANCIEN (renomme, perime) cite l'ancien nom
        # pour dire qu'il n'existe plus — c'est le contraire d'une promesse.
        historique = ("Héritage" in os.path.basename(chemin)) or ("historique" in texte[:400])
        # Le coffre ecrit son histoire en callouts dates, et le plus recent gagne : une cle citee dans
        # un vieux callout puis declaree perimee ou renommee dans un plus recent n'est pas une promesse.
        # On releve donc d'abord, note par note, les cles que la note elle-meme dit anciennes — sur
        # une ligne qui parle de renommage, de peremption ou de remplacement — et on les exempte partout
        # dans cette note. C'est la convention du coffre, pas une tolerance de l'outil.
        MARQUEURS = ("renomm", "périmé", "perime", "ancien nom", "s'appel", "~~", "→", "->", "devien", "remplac", "retiré", "retire")
        anciennes = set()
        for ligne_brute in texte.splitlines():
            bas = ligne_brute.lower()
            if any(mq in bas for mq in MARQUEURS):
                for m2 in RE_CLE_NUE.finditer(ligne_brute):
                    anciennes.add(m2.group(1))
        for m in RE_CLE_NUE.finditer(texte):
            if historique:
                break
            cle = m.group(1)
            if cle in anciennes:
                continue
            # une cle existe si elle est ecrite entre guillemets (JSON ou chaine de code), comme
            # identifiant nu dans le code, ou comme nom de fichier de donnees
            if ('"%s"' % cle) in code or ("&\"%s\"" % cle) in code or cle in stems:
                continue
            if re.search(r"\b%s\b" % re.escape(cle), code):
                continue
            problemes.setdefault("cle de donnees citee qui n'existe pas", []).append("%s : %s" % (note, cle))
    # Le CLIQUET (2026-09-03). Le premier passage du controle des cles nues a trouve cent trois
    # identifiants cites par quarante-cinq notes et absents du code : des champs proposes par le
    # design et codes sous un autre nom, des restes du voxel, des exemples entre accents graves. On
    # ne peut pas les regler en une passe, et un outil rouge pendant une semaine est un outil qu'on
    # n'ecoute plus. Donc : la rouille CONNUE est gelee dans `verif_doc_code_baseline.txt` — c'est la
    # file de travail des passes suivantes, chacune en retire des lignes — et seule une rouille
    # NOUVELLE fait echouer. `--geler` reecrit le gel depuis l'etat courant ; on ne le fait qu'apres
    # avoir regle ce qu'on pouvait, jamais pour faire taire l'outil.
    chemin_gel = os.path.join(RACINE, "tools", "verif_doc_code_baseline.txt")
    gel = set()
    if os.path.exists(chemin_gel):
        gel = {l.strip() for l in lire(chemin_gel).splitlines() if l.strip() and not l.startswith("#")}
    if "--geler" in sys.argv:
        lignes_gel = sorted(set(problemes.get("cle de donnees citee qui n'existe pas", [])))
        io.open(chemin_gel, "w", encoding="utf-8", newline="\n").write(
            "# Rouille connue du coffre : identifiants cites par les notes et absents du code.\n"
            "# Chaque passe de reconciliation en retire ; `python tools/verif_doc_code.py --geler` regele.\n"
            + "\n".join(lignes_gel) + "\n")
        print("gel reecrit : %d lignes de rouille connue" % len(lignes_gel))
        gel = set(lignes_gel)
    connues = []
    if "cle de donnees citee qui n'existe pas" in problemes:
        restantes = []
        for ligne in problemes["cle de donnees citee qui n'existe pas"]:
            (connues if ligne in gel else restantes).append(ligne)
        if restantes:
            problemes["cle de donnees citee qui n'existe pas"] = restantes
        else:
            del problemes["cle de donnees citee qui n'existe pas"]
    total = sum(len(v) for v in problemes.values())
    for titre in sorted(problemes):
        print("\n== %s (%d)" % (titre, len(problemes[titre])))
        for ligne in sorted(set(problemes[titre]))[:500]:
            print("   ", ligne)
    regle = len(gel) - len(set(connues))
    if connues:
        print("rouille connue : %d citation(s) encore dans le gel%s" % (len(set(connues)), (" — %d reglee(s) depuis le gel, relancer --geler" % regle) if regle > 0 else ""))
    if not problemes:
        print("%d notes : chaque chemin, fonction et cle citee existe dans le code (hors rouille connue)" % n_notes)
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
