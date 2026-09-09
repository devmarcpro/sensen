# -*- coding: utf-8 -*-
"""lancer_tests.py — joue la suite `scenes/tests/test_combat.tscn` (headless) et REFUSE une erreur de script.

POURQUOI CET OUTIL EXISTE (2026-09-09). La suite compte ses `verifier` et conclut « TESTS : tout passe ». Mais une
**erreur de script** — un acces invalide, un appel a une methode disparue — ne fait pas echouer un test : elle
INTERROMPT la fonction, et tout ce qu'elle devait verifier apres n'est jamais joue. La suite dit alors « tout passe »
en ayant silencieusement saute la moitie d'un test. C'est ainsi que `test_gaz_dans_le_sol` lisait `cfg.gaz` sur un
dictionnaire qui n'a pas cette cle : le test mourait a sa ligne 2093, et la suite restait verte.

Les SONDES avaient deja ce garde-fou (`balayer_sondes.py` compte les SCRIPT ERROR) ; la SUITE, non — l'inverse de ce
qu'on attendrait. Cet outil le rend a la suite : il refuse toute *SCRIPT ERROR*, *Parse Error* ou *Compilation
failed*, exige la ligne de bilan, et rend un code de sortie non nul des qu'il manque quelque chose.

    python tools/lancer_tests.py [--seul fragment] [--sortie CHEMIN] [--quand-meme]

`GODOT` dans l'environnement designe l'executable ; sinon celui du poste.
"""
import io
import os
import re
import subprocess
import sys
import time

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", r"C:\Users\ciryl\AppData\Local\Programs\Godot\godot.cmd")
MOTIFS = ("SCRIPT ERROR", "Parse Error", "Compilation failed")


def main():
    args = sys.argv[1:]
    fragment = ""
    # UN FICHIER PAR RUN, ET UN SEUL GODOT (2026-09-09, appris a mes depens). La sortie s appelait `build/tests.txt`
    # pour tout le monde : deux lancements simultanes ecrivaient DANS LE MEME FICHIER, et j y ai lu des echecs qui
    # venaient d un autre run. Un outil de verification qui melange deux resultats est pire qu absent — il fait
    # chercher un defaut qui n existe pas. Le nom porte donc le PID, et le dernier resultat est aussi recopie dans
    # `build/tests.txt` pour rester facile a trouver.
    sortie = os.path.join(RACINE, "build", "tests_%d.txt" % os.getpid())
    for i, a in enumerate(args):
        if a == "--seul" and i + 1 < len(args):
            fragment = args[i + 1]
        elif a == "--sortie" and i + 1 < len(args):
            sortie = args[i + 1]
    dossier = os.path.dirname(os.path.abspath(sortie))
    if not os.path.isdir(dossier):
        os.makedirs(dossier)

    # Le projet n autorise qu UNE instance de Godot a la fois (deux se marchent sur le cache d import et sur les
    # `user://`). L outil le fait respecter au lieu de l esperer.
    if "--quand-meme" not in args:
        try:
            liste = subprocess.run(["tasklist"], capture_output=True, text=True, timeout=30).stdout.lower()
            if "godot" in liste:
                print("REFUS : un Godot tourne deja. Le projet n en veut qu un a la fois — attends-le, ou passe")
                print("        --quand-meme si tu sais ce que tu fais.")
                return 3
        except Exception:
            pass   # pas de tasklist : on ne bloque pas pour autant

    cmd = [GODOT, "--headless", "--path", os.path.join(RACINE, "godot"), "res://scenes/tests/test_combat.tscn"]
    if fragment:
        cmd += ["--", "--seul", fragment]
    # UNE ERREUR D'ANALYSE NE COUTE PAS UNE HEURE (2026-09-09). Un script de la suite qui ne compile pas laisse Godot
    # tourner sans jamais rien jouer : le premier essai de cet outil a attendu son delai entier pour rien. On surveille
    # donc la sortie pendant qu'elle s'ecrit, et l'on coupe des que le moteur dit qu'il n'a pas pu charger la scene.
    FATAL = ("Failed to load script", "Compilation failed", "Parse Error")
    t0 = time.time()
    code = None
    with io.open(sortie, "w", encoding="utf-8", errors="replace") as f:
        p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
        tue = ""
        while True:
            code = p.poll()
            if code is not None:
                break
            if time.time() - t0 > 3600:
                p.kill()
                print("LA SUITE : delai depasse (une heure) — sortie dans %s" % sortie)
                return 2
            time.sleep(2.0)
            vu = io.open(sortie, encoding="utf-8", errors="replace").read()
            for m in FATAL:
                if m in vu:
                    tue = m
                    break
            if tue:
                p.kill()
                code = p.wait()
                break
        if tue:
            print("LA SUITE : coupee au bout de %.0f s — le moteur n'a pas pu charger la suite (%s)." % (time.time() - t0, tue))
    texte = io.open(sortie, encoding="utf-8", errors="replace").read()

    # 1. Les echecs que la suite compte elle-meme.
    for ligne in texte.splitlines():
        if u"ÉCHEC" in ligne or "ECHEC" in ligne or ligne.startswith("TESTS :"):
            print(ligne.rstrip())
    bilan = re.findall(r"^TESTS : .*$", texte, re.M)
    ok_bilan = bool(bilan) and "tout passe" in bilan[-1]

    # 2. Les erreurs de script, qui n'echouent nulle part et emportent la fin d'un test.
    erreurs = []
    lignes = texte.splitlines()
    for i, ligne in enumerate(lignes):
        if any(m in ligne for m in MOTIFS):
            ou = ""
            for j in range(i, min(i + 3, len(lignes))):
                m = re.search(r"at: (\S+) \((res://[^)]+)\)", lignes[j])
                if m:
                    ou = " — %s dans %s" % (m.group(1), m.group(2))
                    break
            erreurs.append(ligne.strip() + ou)
    for e in erreurs:
        print("  ERREUR DE SCRIPT : %s" % e)

    try:
        io.open(os.path.join(RACINE, "build", "tests.txt"), "w", encoding="utf-8", errors="replace").write(texte)
    except Exception:
        pass
    print("LA SUITE : %.0f s, code %s, %d erreur(s) de script — sortie dans %s" % (time.time() - t0, code, len(erreurs), sortie))
    if not bilan:
        print("LA SUITE : pas de ligne de bilan — la suite n'est pas allee au bout.")
    if erreurs or not ok_bilan or code != 0:
        return 1
    print("LA SUITE : tout passe, sans une seule erreur de script.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
