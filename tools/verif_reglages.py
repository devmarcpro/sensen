# -*- coding: utf-8 -*-
"""Un reglage lu que rien n ecrit (Ordre de verification, callout du 2026-09-07, 16 h).

Trois defauts trouves le meme jour — le tresor des royaumes qui ne pouvait pas bouger, la diplomatie gelee sur
« cordial », les routes qui se refusaient a des hostiles qui n existaient pas — sont LE MEME defaut : une regle
qui lit un etat que rien n ecrit. Elle ne casse rien, ne leve aucune erreur, ne rougit dans aucun test : elle
retombe sur son defaut, et la branche qui en depend ne s ouvre jamais.

On releve :
  LU      tout litteral que le code lit          .get("x"  .has("x")  .erase("x")  ["x"]
  ECRIT   tout litteral que le code ecrit        "x":      d["x"] =   .x =
  DONNEES toutes les chaines des JSON de data/   les cles ET les valeurs — un identifiant est souvent une
          valeur (une liste d emplacements, un tag, un theme)
Ce qui est lu sans etre ni ecrit ni present dans les donnees retombe toujours sur son defaut : ou bien c est un
nombre de jeu qui devrait etre en donnees, ou bien c est une surcharge facultative — et celles-la se gelent une
par une dans tools/verif_reglages_baseline.txt, avec la raison.

    python tools/verif_reglages.py            # sort 1 si un reglage neuf apparait
    python tools/verif_reglages.py --geler    # regele la liste apres l avoir lue
"""
import json
import os
import re
import sys

RACINES_GD = ['godot/systems', 'godot/scenes/demo']
RACINE_DATA = 'godot/data'
GEL = 'tools/verif_reglages_baseline.txt'

RE_LU = re.compile(r'\.(?:get|has|erase)\(\s*"([a-z_][a-z0-9_]*)"')
RE_IDX = re.compile(r'\[\s*"([a-z_][a-z0-9_]*)"\s*\]')
RE_ECRIT_DICT = re.compile(r'"([a-z_][a-z0-9_]*)"\s*:')
RE_ECRIT_IDX = re.compile(r'\[\s*"([a-z_][a-z0-9_]*)"\s*\]\s*=')
RE_ECRIT_ATTR = re.compile(r'\.([a-z_][a-z0-9_]*)\s*=[^=]')


def chaines_des_donnees():
    """Les cles ET les valeurs de tous les JSON, plus les noms de dossiers et de fichiers (les catalogues)."""
    vues = set()

    def visiter(o):
        if isinstance(o, dict):
            for k, v in o.items():
                vues.add(k)
                visiter(v)
        elif isinstance(o, list):
            for v in o:
                visiter(v)
        elif isinstance(o, str):
            vues.add(o)

    for base, dossiers, fichiers in os.walk(RACINE_DATA):
        for d in dossiers:
            vues.add(d)
        for f in fichiers:
            if not f.endswith('.json'):
                continue
            vues.add(f[:-5])
            with open(os.path.join(base, f), encoding='utf-8') as fh:
                try:
                    visiter(json.load(fh))
                except ValueError as e:
                    print('json illisible : %s (%s)' % (f, e))
    return vues


def scanner_le_code():
    lu, ecrit = {}, set()
    for racine in RACINES_GD:
        for base, _, fichiers in os.walk(racine):
            for f in fichiers:
                if not f.endswith('.gd'):
                    continue
                p = os.path.join(base, f)
                with open(p, encoding='utf-8') as fh:
                    for n, ligne in enumerate(fh, 1):
                        code = ligne.split('#')[0]   # un commentaire ne lit ni n ecrit rien
                        for rx in (RE_ECRIT_DICT, RE_ECRIT_IDX, RE_ECRIT_ATTR):
                            for m in rx.finditer(code):
                                ecrit.add(m.group(1))
                        for rx in (RE_LU, RE_IDX):
                            for m in rx.finditer(code):
                                lu.setdefault(m.group(1), []).append('%s:%d' % (p.replace('\\', '/'), n))
    return lu, ecrit


def gel_connu():
    if not os.path.exists(GEL):
        return set()
    with open(GEL, encoding='utf-8') as fh:
        return set(l.split('#')[0].strip() for l in fh if l.split('#')[0].strip())


def main():
    donnees = chaines_des_donnees()
    lu, ecrit = scanner_le_code()
    candidats = sorted(k for k in lu if k not in ecrit and k not in donnees)
    gel = gel_connu()
    neufs = [k for k in candidats if k not in gel]

    if '--geler' in sys.argv:
        with open(GEL, 'w', encoding='utf-8', newline='') as fh:
            fh.write("# Les reglages lus que rien n ecrit et qu on assume : une surcharge facultative, un\n"
                     "# marqueur interne, une condition offerte mais inutilisee. Un par ligne, la raison apres #.\n")
            for k in candidats:
                fh.write('%s\n' % k)
        print('gel refait : %d reglage(s)' % len(candidats))
        return 0

    print('%d litteraux lus, %d ecrits par le code, %d chaines dans les donnees' % (len(lu), len(ecrit), len(donnees)))
    if not neufs:
        print('reglages lus que rien n ecrit : %d, tous geles' % len(candidats))
        return 0
    print('\n%d reglage(s) lu(s) que RIEN n ecrit et qui ne sont pas geles :' % len(neufs))
    for k in neufs:
        print('  %-26s %s' % (k, ', '.join(lu[k][:3])))
    print("\nOu bien c'est un nombre de jeu a poser en donnees, ou bien c'est une surcharge facultative :")
    print("dans ce cas, ajoute-le a %s avec sa raison." % GEL)
    return 1


if __name__ == '__main__':
    sys.exit(main())
