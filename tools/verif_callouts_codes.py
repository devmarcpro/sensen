# -*- coding: utf-8 -*-
"""Un callout « Codé » qui ment (designer 2026-09-07, 21 h : « vérifie aussi les notes marquées Codés, je pense qu'il y a
de faux positifs ou des systèmes codés à moitié »).

Le coffre porte ~270 notes « décidé », presque toutes avec un callout `[!success] Codé le …`. Rien ne vérifiait que ce
qui y est annoncé existe VRAIMENT dans le code. Ce script relève, dans chaque callout de réussite, les identifiants
cités en `code` — fonctions (`f()`, `Classe.f`), fichiers (`data/x/y.json`, `systems/x.gd`), clés de données — et dit
lesquels sont introuvables dans le dépôt.

Ce n'est PAS `verif_doc_code.py`, qui balaie la note entière : ici on ne regarde que ce qu'un callout **affirme avoir
codé**, ce qui est bien plus fort — une citation morte y est une promesse non tenue, pas une note qui a vieilli.

    python tools/verif_callouts_codes.py            # sort 1 s'il reste des promesses non tenues hors du gel
    python tools/verif_callouts_codes.py --geler    # regèle la liste après l'avoir lue
"""
import os
import re
import sys

DOCS = 'docs'
CODE_DIRS = ['godot/systems', 'godot/scenes', 'godot/autoload', 'cpp/src', 'tools']
GEL = 'tools/verif_callouts_codes_baseline.txt'

# un callout de réussite : « > [!success] … » jusqu'à la fin du bloc de citation
RE_CALLOUT = re.compile(r'^> \[!success\][^\n]*\n(?:^>[^\n]*\n)*', re.M)
RE_CODE = re.compile(r'`([^`\n]{2,120})`')
# ce qu'on sait vérifier : une fonction, une méthode, un fichier de données, un script
RE_FONCTION = re.compile(r'^(?:[A-Z][A-Za-z0-9_]*\.)?([a-z_][a-z0-9_]*)\(\)?$')
RE_METHODE = re.compile(r'^([A-Z][A-Za-z0-9_]*)\.([a-z_][a-z0-9_]*)$')
RE_FICHIER = re.compile(r'^((?:data|systems|scenes|tools|cpp|godot)/[A-Za-z0-9_\-./]+\.(?:json|gd|py|cpp|h|gdshader))$')
RE_TEST = re.compile(r'^(test_[a-z0-9_]+)$')


def corpus():
    """Tout le code du dépôt en une chaîne, plus l'ensemble des chemins de fichiers."""
    textes = []
    chemins = set()
    for racine in CODE_DIRS + ['godot/data', 'godot/locale']:
        for base, _, fichiers in os.walk(racine):
            for f in fichiers:
                p = os.path.join(base, f).replace('\\', '/')
                chemins.add(p)
                chemins.add(p[len('godot/'):] if p.startswith('godot/') else p)
                if f.endswith(('.gd', '.py', '.cpp', '.h', '.gdshader')):
                    try:
                        with open(p, encoding='utf-8') as fh:
                            textes.append(fh.read())
                    except (OSError, UnicodeDecodeError):
                        pass
    return '\n'.join(textes), chemins


def citations(texte):
    """Les identifiants d'un callout qu'on sait vérifier, avec leur genre."""
    res = []
    for brut in RE_CODE.findall(texte):
        c = brut.strip()
        m = RE_FICHIER.match(c)
        if m:
            res.append(('fichier', m.group(1)))
            continue
        m = RE_TEST.match(c)
        if m:
            res.append(('test', m.group(1)))   # un test cité doit exister ET être lancé : c'est la preuve du callout
            continue
        m = RE_METHODE.match(c)
        if m:
            res.append(('fonction', m.group(2)))
            continue
        m = RE_FONCTION.match(c)
        if m:
            res.append(('fonction', m.group(1)))
    return res


def gel_connu():
    if not os.path.exists(GEL):
        return set()
    with open(GEL, encoding='utf-8') as fh:
        return set(l.split('#')[0].strip() for l in fh if l.split('#')[0].strip())


def main():
    code, chemins = corpus()
    manquants = {}   # citation -> [notes]
    n_callouts = 0
    n_citations = 0
    for base, _, fichiers in os.walk(DOCS):
        for f in sorted(fichiers):
            if not f.endswith('.md'):
                continue
            p = os.path.join(base, f)
            with open(p, encoding='utf-8') as fh:
                note = fh.read()
            for bloc in RE_CALLOUT.findall(note):
                n_callouts += 1
                if '~~' in bloc.split('\n', 1)[0]:
                    continue   # un titre barré annonce ce qui a été RETIRÉ depuis : ses citations n'engagent plus
                for genre, c in citations(bloc):
                    n_citations += 1
                    if genre == 'test':
                        # un test doit être écrit dans la suite ET inscrit au lanceur, sinon il n'est jamais joué
                        e = re.escape(c)
                        dans_suite = (re.search(r'\bfunc\s+%s\b' % e, code) is not None
                                      and re.search(r'_lancer\("%s"\)' % e, code) is not None)
                        scene = ('godot/scenes/tests/%s.tscn' % c) in chemins   # certains « tests » sont des scènes
                        trouve = dans_suite or scene
                    elif genre == 'fonction':
                        # Un callout cite sans distinction une fonction GDScript ou Python, une methode C++
                        # (`Classe::nom(`), une variable membre (`var nom`) et une cle de donnees (`"nom"`) :
                        # on les accepte toutes les quatre, sinon l'outil crie au loup sur `claims` ou `zones`.
                        e = re.escape(c)
                        motif = r'\b(?:func|def)\s+%s\b|::%s\s*\(|\bvar\s+%s\b|"%s"' % (e, e, e, e)
                        trouve = re.search(motif, code) is not None
                    else:
                        trouve = c in chemins or ('godot/' + c) in chemins
                    if not trouve:
                        manquants.setdefault(c, []).append(p.replace('\\', '/'))

    if '--geler' in sys.argv:
        with open(GEL, 'w', encoding='utf-8', newline='') as fh:
            fh.write("# Ce qu'un callout « Codé » cite et que le code n'a pas — assumé : renommé depuis, cité comme\n"
                     "# une intention, ou appartenant à un outil externe. Un par ligne, la raison après #.\n")
            for c in sorted(manquants):
                fh.write('%s\n' % c)
        print('gel refait : %d citation(s)' % len(manquants))
        return 0

    gel = gel_connu()
    neufs = sorted(c for c in manquants if c not in gel)
    print('%d callouts « Codé », %d citations vérifiables, %d introuvable(s) dont %d hors du gel'
          % (n_callouts, n_citations, len(manquants), len(neufs)))
    if not neufs:
        return 0
    print("\nCe qu'un callout affirme avoir codé et que le code n'a pas :")
    for c in neufs:
        notes = sorted(set(manquants[c]))
        print('  %-40s %s' % (c, ', '.join(n.split('/')[-1] for n in notes[:3])))
    print("\nOu bien la promesse n'est pas tenue, ou bien la citation a vieilli :")
    print("dans le second cas, corrige la note ; sinon, ajoute la citation à %s avec sa raison." % GEL)
    return 1


if __name__ == '__main__':
    sys.exit(main())
