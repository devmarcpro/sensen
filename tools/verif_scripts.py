#!/usr/bin/env python3
"""Vérifie que TOUS les scripts du jeu se compilent — pas seulement ceux que la suite charge.

Deux angles morts, tous deux payés :

1. **Les écrans.** La suite de tests ne charge jamais `scenes/demo/*.gd` : une erreur de syntaxe dans
   l'écran principal passait au vert et partait en release (le 2026-09-02, la v0.3.0-alpha ne se
   lançait pas). On ouvre donc chaque scène d'écran dans Godot et on refuse toute « Parse Error ».

2. **Les sondes elles-mêmes.** Une sonde dont le script ne compile pas ne *échoue* pas : Godot charge
   la scène sans script, personne n'appelle `quit()`, et le processus **tourne indéfiniment**. Ça
   ressemble à s'y méprendre à une boucle infinie du jeu — ça m'a coûté deux diagnostics erronés le
   2026-09-03, dont un annoncé au designer comme un possible blocage du moteur. Un script cassé doit
   dire « je suis cassé » en deux secondes, pas se taire pendant dix minutes.

    python tools/verif_scripts.py
"""
import glob
import os
import subprocess
import sys

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.environ.get("GODOT", r"C:/Users/ciryl/Documents/Godot_v4.6.3-stable_win64.exe")
MOTIFS = ("Parse Error", "Compilation failed", "SCRIPT ERROR")


def lancer(args, timeout):
    p = subprocess.run([GODOT, "--headless", "--path", os.path.join(RACINE, "godot")] + args,
                       capture_output=True, text=True, errors="replace", timeout=timeout)
    return (p.stdout or "") + (p.stderr or "")


echecs = []

# 1. les écrans : on ouvre vraiment la scène, deux images suffisent à charger tous ses scripts
for scene in ["res://scenes/demo/main.tscn"]:
    for ligne in lancer(["--quit-after", "2", scene], 180).splitlines():
        if any(m in ligne for m in MOTIFS):
            echecs.append("%s : %s" % (scene, ligne.strip()))

# 2. les sondes et les bancs, avec `--check-only` : Godot ANALYSE le script sans l'exécuter.
#    Le mot qui compte est « Parse error » — une faute de syntaxe. « Compilation failed » ne veut
#    rien dire ici : un script parfaitement sain le produit dès qu'il nomme un autoload, parce que
#    hors contexte l'autoload n'existe pas. Confondre les deux donnait douze faux positifs sur
#    quatorze sondes, et un outil qui crie au loup est un outil qu'on désactive.
sondes = sorted(glob.glob(os.path.join(RACINE, "godot", "scenes", "tests", "*.gd")))
for chemin in sondes:
    res = "res://scenes/tests/" + os.path.basename(chemin)
    try:
        sortie = lancer(["--check-only", "--script", res], 90)
    except subprocess.TimeoutExpired:
        echecs.append("%s : n'a pas rendu la main en 90 s" % res)
        continue
    for ligne in sortie.splitlines():
        if "parse error" in ligne.lower():
            echecs.append("%s : %s" % (res, ligne.strip()))

if echecs:
    print("SCRIPTS QUI NE COMPILENT PAS : %d" % len(echecs))
    for e in echecs[:20]:
        print("   ", e)
    sys.exit(1)
print("scripts des ecrans et des %d sondes : tout compile" % len(sondes))
