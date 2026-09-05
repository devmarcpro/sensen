# -*- coding: utf-8 -*-
"""fragmenter_tests.py — découpe `scenes/tests/test_combat.gd` (9 800 lignes, 191 tests) en douze fichiers de
domaine sous `scenes/tests/suite/`, sans toucher au corps d'un seul test.

  - `tests_base.gd` (`TestsBase`, RefCounted) porte les aides communes (`verifier` renvoie au lanceur, `nouvelle_sim`,
    `joueur_de`, `_capacite_test`, `_planete_test`, `_consommer_xp`, `_cellule_eau`, `add_child`) ;
  - chaque `tests_<domaine>.gd` étend `TestsBase` et reçoit ses `func test_…` tels quels ;
  - `test_combat.gd` reste le LANCEUR : la liste `_lancer("…")` écrite à la main, le filtre `--seul`, le compte des échecs,
    et cherche chaque test dans ses modules.

    python tools/fragmenter_tests.py            # rapport seul
    python tools/fragmenter_tests.py --ecrire   # écrit les fichiers (à relancer depuis l'original : git checkout)
"""
import io
import os
import re
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RACINE, 'godot', 'scenes', 'tests', 'test_combat.gd')
DEST = os.path.join(RACINE, 'godot', 'scenes', 'tests', 'suite')

AIDES = ['nouvelle_sim', 'joueur_de', '_capacite_test', '_planete_test', '_consommer_xp', '_cellule_eau']

# (fichier, description, premier test, dernier test) dans l'ordre de la liste _lancer
GROUPES = [
    ('tests_noyau.gd', "le noyau : grille, dés, règles, simulation, horloges, Wu Xing, capacités, statuts, liaisons, niveaux, paperdoll", 'test_grille', 'test_paperdoll_et_tutoriels'),
    ('tests_matieres.gd', "les matières et le craft : matériaux, récolte, fabrication, assemblage", 'test_materiaux', 'test_desequiper_jeter'),
    ('tests_monde.gd', "le monde : surface, sauvegarde, carte et voyage, corruption, cycle et météo", 'test_surface', 'test_cycle_et_meteo'),
    ('tests_villages.gd', "les villages et les royaumes : village vivant, réputation, guildes, compagnons, territoire, raids, conquête", 'test_village', 'test_conquete_et_succession'),
    ('tests_elevage.gd', "l'alchimie, les villes et halls, l'élevage : saisons, familles, loci, harmonie, registre, entraîneur, guildes, anneau-mesure, chatoyant", 'test_alchimie', 'test_chatoyant'),
    ('tests_talents.gd', "les routes, l'habitat, les talents et les formes : lumière, industriel, bétail, classes cachées, vampire, spectre, lycanthrope, incarnation, cataclysme", 'test_routes', 'test_vecteur_lieu'),
    ('tests_equipement_et_terrain.gd', "l'équipement, les recettes, les plantes, le bestiaire, les statuts et potions, la nage, la neige, l'eau, le feu, la lave, le courant", 'test_effets_equipement', 'test_courant'),
    ('tests_ia_et_donnees.gd', "l'IA, les espèces, les données, la discrétion, la triche, les statues, les routes entre royaumes, les tooltips, les meubles, la transmutation, les glyphes, l'alternance, la meute", 'test_ia_portails', 'test_etats_tuiles_par_grille'),
    ('tests_grilles_de_sorts.gd', "l'index du monde, la sauvegarde du terrain, les uniques, les bombes, la grille de composition, les trames, les crans, les étapes, la projection", 'test_index_monde', 'test_lod_projection'),
    ('tests_base_et_compagnons.gd', "la faune, la base (engager, périmètres, faim, dette), les compagnons en donjon, les classes des PNJ, la composition des capacités, les zones au sol", 'test_faune_rarefaction', 'test_conditions_et_modificateurs'),
    ('tests_donjon_et_progression.gd', "le camp, la géographie, le donjon, les portes, les chaînes, le loot, la chasse, les serments, les budgets, la sauvegarde partout, le boss, la progression, l'expédition, les arènes", 'test_camp', 'test_arenes_autonomes'),
    ('tests_pnj_et_villes.gd', "le brouillard, les bêtes et leur horloge, la routine civile, les boutiques, le recrutement, le calendrier, les territoires, les villes, les champs, l'anneau moyen, l'économie, les transports, les PNJ distincts, les royaumes-pays, les étages", 'test_brouillard', 'test_batiment_etages'),
]

DEF = re.compile(r'^(static )?func ([A-Za-z_]\w*)\(')


def lire(p):
    return io.open(p, encoding='utf-8').read()


def ecrire(p, s):
    d = os.path.dirname(p)
    if not os.path.isdir(d):
        os.makedirs(d)
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)


def main():
    ecrire_fichiers = '--ecrire' in sys.argv
    lignes = lire(SRC).split('\n')
    fonctions = []   # (nom, debut, fin, statique)
    for i, l in enumerate(lignes):
        m = DEF.match(l)
        if m:
            d = i
            while d > 0 and (lignes[d - 1].startswith('#') or lignes[d - 1].startswith('@')):
                d -= 1
            fonctions.append([m.group(2), d, None, bool(m.group(1))])
    for k in range(len(fonctions)):
        fonctions[k][2] = fonctions[k + 1][1] if k + 1 < len(fonctions) else len(lignes)
    par_nom = {f[0]: f for f in fonctions}
    ordre_lancer = re.findall(r'_lancer\("([a-z_0-9]+)"\)', '\n'.join(lignes))
    assert len(ordre_lancer) == len(set(ordre_lancer))
    tests_definis = [f[0] for f in fonctions if f[0].startswith('test_')]
    manquants = [t for t in tests_definis if t not in ordre_lancer]
    assert not manquants, manquants
    attribution = {}
    for fichier, doc, premier, dernier in GROUPES:
        a, b = ordre_lancer.index(premier), ordre_lancer.index(dernier)
        assert a <= b
        for t in ordre_lancer[a:b + 1]:
            assert t not in attribution, t
            attribution[t] = fichier
    non_attribues = [t for t in ordre_lancer if t not in attribution]
    assert not non_attribues, non_attribues

    # la base : les aides
    corps_aides = []
    for nom in AIDES:
        f = par_nom[nom]
        corps_aides.append('\n'.join(lignes[f[1]:f[2]]))
    base = ('class_name TestsBase\nextends RefCounted\n'
            '## La base des fichiers de la suite (découpée le 2026-09-06 : `test_combat.gd` reste le lanceur, chaque\n'
            '## `suite/tests_<domaine>.gd` étend cette classe). Les aides communes vivent ici ; `verifier` compte au lanceur.\n\n'
            'static var lanceur: Node = null   # test_combat.gd, qui compte les échecs et lit `--seul`\n\n\n'
            'func verifier(cond: bool, nom: String) -> void:\n\tlanceur.verifier(cond, nom)\n\n\n'
            '## Un test qui instancie une scène (le tutoriel) la pose sous le lanceur, un nœud de l\'arbre.\n'
            'func add_child(n: Node) -> void:\n\tlanceur.add_child(n)\n\n\n'
            + '\n'.join(corps_aides).rstrip('\n') + '\n')
    sorties = {os.path.join(DEST, 'tests_base.gd'): re.sub(r'\n{4,}', '\n\n\n', base)}

    # les modules
    for fichier, doc, premier, dernier in GROUPES:
        noms = [t for t in ordre_lancer if attribution[t] == fichier]
        corps = []
        for t in noms:
            f = par_nom[t]
            corps.append('\n'.join(lignes[f[1]:f[2]]))
        entete = ('extends TestsBase\n## %s.\n## Un fichier de la suite (découpée le 2026-09-06 par `tools/fragmenter_tests.py`) : les tests sont ceux de\n'
                  '## `test_combat.gd`, tels quels ; le lanceur les appelle par leur nom, dans l\'ordre de sa liste.\n\n\n') % (doc[0].upper() + doc[1:])
        sorties[os.path.join(DEST, fichier)] = re.sub(r'\n{4,}', '\n\n\n', entete + '\n'.join(corps).rstrip('\n') + '\n')

    # le lanceur : tout sauf les tests et les aides déplacées
    a_retirer = set(tests_definis) | set(AIDES)
    garde = []
    pos = 0
    for f in fonctions:
        if f[0] in a_retirer:
            if f[1] > pos:
                garde.append('\n'.join(lignes[pos:f[1]]))
            pos = f[2]
    if pos < len(lignes):
        garde.append('\n'.join(lignes[pos:]))
    lanceur = '\n'.join(garde)
    lanceur = re.sub(r'\n{4,}', '\n\n\n', lanceur)
    a = """func _lancer(nom: String) -> void:
	_lances.append(nom)
	if not _filtre.is_empty() and not nom.contains(_filtre):
		return
	call(nom)
"""
    b = """## Les fichiers de la suite (découpée le 2026-09-06 : `tools/fragmenter_tests.py`), chacun un domaine ; les tests y sont tels quels.
const MODULES: Array = [
%s]
var _modules: Array = []


func _lancer(nom: String) -> void:
	_lances.append(nom)
	if not _filtre.is_empty() and not nom.contains(_filtre):
		return
	for m in _modules:
		if m.has_method(nom):
			m.call(nom)
			return
	verifier(false, "test introuvable dans la suite : %%s" %% nom)
""" % ''.join('\tpreload("res://scenes/tests/suite/%s"),\n' % g[0] for g in GROUPES)
    assert lanceur.count(a) == 1
    lanceur = lanceur.replace(a, b)
    a = """	for m in get_method_list():
		var nom := str(m.name)
		if nom.begins_with("test_") and not (nom in _lances):
			verifier(false, "test défini mais jamais lancé : %s" % nom)
"""
    b = """	for mod in _modules:
		for m in mod.get_method_list():
			var nom := str(m.name)
			if nom.begins_with("test_") and not (nom in _lances):
				verifier(false, "test défini mais jamais lancé : %s" % nom)
"""
    assert lanceur.count(a) == 1
    lanceur = lanceur.replace(a, b)
    a = """	Simulation.slot_autosave = "test_auto\""""
    assert lanceur.count(a) == 1
    lanceur = lanceur.replace(a, """	TestsBase.lanceur = self
	for scr in MODULES:
		_modules.append(scr.new())
""" + a)
    sorties[SRC] = lanceur

    print("lanceur : %d lignes" % lanceur.count('\n'))
    for p, s in sorties.items():
        if p != SRC:
            print("  %-36s %5d lignes" % (os.path.basename(p), s.count('\n')))
    if ecrire_fichiers:
        for p, s in sorties.items():
            ecrire(p, s)
        print("écrit.")
    else:
        print("(rapport seul : --ecrire pour écrire)")


if __name__ == '__main__':
    main()
