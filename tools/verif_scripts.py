#!/usr/bin/env python3
"""Vérifie que TOUS les scripts du jeu se compilent — pas seulement ceux que la suite charge.

La suite de tests ne charge jamais `scenes/demo/*.gd` : une erreur de syntaxe dans l'écran principal
passait donc au vert et partait en release (le 2026-09-02, la v0.3.0-alpha ne se lançait pas).
Ici, on ouvre chaque scène d'écran dans Godot et on refuse toute « Parse Error » ou « SCRIPT ERROR ».
"""
import os, subprocess, sys

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
GODOT = os.environ.get("GODOT", r"C:/Users/ciryl/Documents/Godot_v4.6.3-stable_win64.exe")
SCENES = ["res://scenes/demo/main.tscn"]

echecs = []
for scene in SCENES:
    p = subprocess.run([GODOT, "--headless", "--path", os.path.join(RACINE, "godot"),
                        "--quit-after", "2", scene],
                       capture_output=True, text=True, errors="replace", timeout=180)
    sortie = (p.stdout or "") + (p.stderr or "")
    for ligne in sortie.splitlines():
        if "Parse Error" in ligne or "Compilation failed" in ligne or "SCRIPT ERROR" in ligne:
            echecs.append("%s : %s" % (scene, ligne.strip()))

if echecs:
    print("SCRIPTS QUI NE COMPILENT PAS : %d" % len(echecs))
    for e in echecs[:20]:
        print("   ", e)
    sys.exit(1)
print("scripts des ecrans : tout compile")
