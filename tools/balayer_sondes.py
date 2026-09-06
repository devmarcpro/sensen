# -*- coding: utf-8 -*-
"""balayer_sondes.py — joue toutes les sondes `scenes/tests/sonde_*.tscn` l'une après l'autre (headless) et résume :
code de sortie, SCRIPT ERROR, et la ligne « SONDE … : n souci(s) / rien à signaler » de chacune. Une heure environ.
Les sorties complètes vont dans `<dossier>/sonde_<nom>.txt` (par défaut `build/sondes/`).

    python tools/balayer_sondes.py [--dossier CHEMIN] [--seulement fragment]
"""
import glob
import io
import os
import re
import subprocess
import sys
import time

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe")


def main():
    dossier = os.path.join(RACINE, "build", "sondes")
    fragment = ""
    args = sys.argv[1:]
    for i, a in enumerate(args):
        if a == "--dossier" and i + 1 < len(args):
            dossier = args[i + 1]
        elif a == "--seulement" and i + 1 < len(args):
            fragment = args[i + 1]
    if not os.path.isdir(dossier):
        os.makedirs(dossier)
    scenes = sorted(glob.glob(os.path.join(RACINE, "godot", "scenes", "tests", "sonde_*.tscn")))
    total_erreurs = 0
    total_soucis = 0
    for scene in scenes:
        nom = os.path.splitext(os.path.basename(scene))[0]
        if fragment and fragment not in nom:
            continue
        t0 = time.time()
        sortie = os.path.join(dossier, nom + ".txt")
        with io.open(sortie, "w", encoding="utf-8", errors="replace") as f:
            try:
                p = subprocess.run([GODOT, "--headless", "--path", os.path.join(RACINE, "godot"), "res://scenes/tests/%s.tscn" % nom],
                                   stdout=f, stderr=subprocess.STDOUT, timeout=900)
                code = p.returncode
            except subprocess.TimeoutExpired:
                code = "délai"
        texte = io.open(sortie, encoding="utf-8", errors="replace").read()
        erreurs = texte.count("SCRIPT ERROR")
        m = re.findall(r"SONDE[^\n:]*: ([^\n]*)", texte)
        bilan = m[-1].strip() if m else "(pas de bilan)"
        soucis = re.search(r"(\d+) souci", bilan)
        n_soucis = int(soucis.group(1)) if soucis else 0
        total_erreurs += erreurs
        total_soucis += n_soucis
        print("%-26s %5.0f s  sortie %-5s  SCRIPT ERROR %-2d  %s" % (nom, time.time() - t0, code, erreurs, bilan))
        sys.stdout.flush()
    print("BALAYAGE : %d SCRIPT ERROR, %d souci(s) — sorties dans %s" % (total_erreurs, total_soucis, dossier))


if __name__ == "__main__":
    main()
