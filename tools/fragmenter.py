# -*- coding: utf-8 -*-
"""fragmenter.py — découpe `simulation.gd` en bibliothèques STATIQUES `Sim…`
(docs/08 - Technique/Modules de la simulation et le C++.md, décidé le 2026-09-05).

Chaque module reçoit des PLAGES de fonctions (de la première à la dernière, dans l'ordre du fichier).
L'outil :
  - déplace la plage (avec ses commentaires de tête) dans `godot/systems/simulation/sim_<x>.gd` ;
  - rend chaque fonction `static` avec `sim: Simulation` en premier paramètre ;
  - qualifie chaque membre de la simulation (`sim.grille`, `Simulation.slot_autosave`) et chaque appel
    (`f(sim, …)` dans le module, `SimX.f(sim, …)` vers un autre module, `sim.f(…)` vers le cœur) ;
  - réécrit le cœur (`SimX.f(self, …)`) et ajoute un DÉLÉGUÉ d'une ligne pour tout ce que les autres
    fichiers appellent encore sur la simulation ;
  - signale ce qu'il ne sait pas trancher (une fonction passée comme Callable sans parenthèses, une locale qui
    masque un membre, un paramètre déjà nommé `sim`).

    python tools/fragmenter.py            # rapport seul
    python tools/fragmenter.py --ecrire   # écrit les fichiers
"""
import io
import os
import re
import sys
import glob

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RACINE, 'godot', 'systems', 'combat', 'simulation.gd')
DEST = os.path.join(RACINE, 'godot', 'systems', 'simulation')
CLASSE_SIM = 'Simulation'

# (classe, fichier, description, plages [(première fonction, dernière fonction)])
PLAN = [
    ('SimLieux', 'sim_lieux.gd', "l'arène, le camp, les donjons, les gouffres, les étages de donjon (charger, descendre, remonter, sortir)",
     [('charger_arene', '_reprendre'), ('_descendre', '_boss_vaincu')]),
    ('SimTerrain', 'sim_terrain.gd', "le terrain vivant : eau, courants, lave, feu, foudre, pluie, vent, terrassement, cueillette, creusage ; le cycle jour-nuit et la météo",
     [('_memoriser_terrain', '_retirer_materiau'), ('dans_l_eau', '_tiquer_souffle'), ('_cycle', '_tiquer_meteo')]),
    ('SimCamp', 'sim_camp.gd', "le camp : poser, murs, démonter, coffres, ranger, prendre, dormir, voyager ; les parcelles et la boutique passive ; le tick d'un territoire",
     [('_tuile_libre_pour_poser', 'voyager'), ('_pm', '_rapport_absence')]),
    ('SimPnj', 'sim_pnj.gd', "les PNJ : dialogue, commerce, traits, histoires et souhaits, cadeaux, opinions ; compagnons et recrutement ; échanges, ordres, apprivoisement, résurrection, âge ; quêtes et guildes ; relations et réputation",
     [('replique', '_vendre'), ('places_escorte', '_recruter'), ('echanger', 'categorie_age'), ('quetes_offertes', '_rendre_quete'), ('ennemis', '_rumeur')]),
    ('SimTerritoire', 'sim_territoire.gd', "le territoire : claims, rôles, résidents, assignations, pièces et strates, recettes uniques ; abris, humeurs, nourriture, production ; le contexte d'un territoire (Villes B0) ; l'économie des villes (B3) et la semaine du territoire",
     [('_ry', 'a_unique_ax'), ('_abri_a', 'production_de'), ('_dans_territoire', '_semaine_joueur'), ('categorie_economique', '_puissance_de')]),
    ('SimVilles', 'sim_villes.gd', "les villes : le jour du calendrier (marché, fêtes), les transports (B4), les étages des bâtiments (99), le peuplement d'une agglomération, ses champs et ses bêtes",
     [('jour_courant', '_garnir_marche'), ('_transports', '_acheter_monture'), ('batiment_a_escalier', '_sortir_interieur'), ('_peupler_fenetre', '_creer_perimetres_ville')]),
    ('SimPerimetres', 'sim_perimetres.gd', "les périmètres de récolte : dessiner, scanner, postes, stockages, maisons, la base, engager, migrants",
     [('perimetres', '_semaine_migrants')]),
    ('SimRoyaumes', 'sim_royaumes.gd', "les royaumes : état, règne et ère, événements, guerres (D) ; conquête, familles, titres, succession, la semaine des royaumes PNJ ; lois, douanes, accords ; gouvernance, défense et raids",
     [('royaume_par_id', 'en_guerre'), ('village_a', '_ia_assaut')]),
    ('SimElevage', 'sim_elevage.gd', "l'entraîneur, les commandes de collectionneurs ; l'élevage : génomes, hérédité, capture, spécimens, variétés, paliers, la semaine",
     [('ame_dans_sac', '_semaine_elevage')]),
    ('SimObjets', 'sim_objets.gd', "les êtres et les objets : ajouter un être, réapprovisionner, le loot composé, l'apparence et l'habillage ; donner, nommer, identifier, équiper, jeter, périmer, contenants, ramasser, respawn, sertir, lire, drop",
     [('ajouter', '_habiller_pnj'), ('donner', '_drop')]),
    ('SimSauvegarde', 'sim_sauvegarde.gd', "la sauvegarde : emplacements, résumé, sauvegarder, charger, l'étage mis de côté",
     [('slot', 'charger_sauvegarde'), ('_sauver_etage', '_sauver_etage')]),
    ('SimFabrication', 'sim_fabrication.gd', "le craft compositionnel et la fabrication aux stations",
     [('_faconner', '_fabriquer')]),
    ('SimTalents', 'sim_talents.gd', "le vecteur du lieu, les armes fantômes, les formes et les rituels, les vampires, les affûts, les masques, les glyphes, les portails, la saisie ; les grilles de composition et les talents",
     [('vecteur_lieu', '_ia_se_debattre'), ('niveau_arme', '_apprendre_talent')]),
]

MOTS_CLES = {"if", "elif", "else", "for", "while", "match", "break", "continue", "pass", "return", "class", "class_name",
             "extends", "is", "in", "as", "self", "signal", "func", "static", "const", "enum", "var", "breakpoint", "preload",
             "await", "yield", "assert", "void", "and", "or", "not", "true", "false", "null", "super", "PI", "TAU", "INF", "NAN"}

TOK = re.compile(r'''(?P<com>\#[^\n]*)|(?P<str3>"""(?:\\.|[^\\])*?""")|(?P<str>"(?:\\.|[^"\\\n])*")|(?P<chr>'(?:\\.|[^'\\\n])*')|(?P<id>[A-Za-z_][A-Za-z0-9_]*)|(?P<other>.)''', re.S)
DEF = re.compile(r'^(static )?func ([A-Za-z_]\w*)\((.*)\)(?: -> ([^:]+))?:\s*$')


def lire(p):
    return io.open(p, encoding='utf-8').read()


def ecrire(p, s):
    d = os.path.dirname(p)
    if not os.path.isdir(d):
        os.makedirs(d)
    io.open(p, 'w', encoding='utf-8', newline='\n').write(s)


def separer_params(params):
    """Les paramètres d'une signature, séparés aux virgules de profondeur 0."""
    res, prof, cur = [], 0, ''
    for c in params:
        if c in '([{':
            prof += 1
        elif c in ')]}':
            prof -= 1
        if c == ',' and prof == 0:
            res.append(cur.strip())
            cur = ''
        else:
            cur += c
    if cur.strip():
        res.append(cur.strip())
    return res


def nom_param(p):
    return re.split(r'[:=]', p, 1)[0].strip()


def parens_apres(texte, i):
    """Le contenu entre la parenthèse ouvrante à `texte[i]` et sa fermante."""
    assert texte[i] == '('
    prof, j = 0, i
    while j < len(texte):
        if texte[j] == '(':
            prof += 1
        elif texte[j] == ')':
            prof -= 1
            if prof == 0:
                return texte[i + 1:j]
        j += 1
    return texte[i + 1:]


def locales_de(texte):
    """Tout ce qu'une fonction déclare localement : paramètres, lambdas, var, for, match."""
    loc = set()
    for m in re.finditer(r'\bfunc\b\s*\w*\s*\(', texte):
        for p in separer_params(parens_apres(texte, m.end() - 1)):
            n = nom_param(p)
            if n:
                loc.add(n)
    for m in re.finditer(r'\bvar\s+([A-Za-z_]\w*)', texte):
        loc.add(m.group(1))
    for m in re.finditer(r'\bfor\s+([A-Za-z_]\w*)', texte):
        loc.add(m.group(1))
    return loc


class Fonction:
    def __init__(self, ligne, statique, nom, params, ret):
        self.ligne = ligne          # index de la ligne `func`
        self.statique = statique
        self.nom = nom
        self.params = params
        self.ret = (ret or 'void').strip()
        self.debut = ligne          # début du bloc (commentaires de tête)
        self.fin = ligne            # fin exclusive du bloc (début du bloc suivant)
        self.module = None          # classe du module, ou None pour le cœur


def analyser(lignes):
    fonctions = []
    for i, l in enumerate(lignes):
        m = DEF.match(l)
        if m:
            fonctions.append(Fonction(i, bool(m.group(1)), m.group(2), m.group(3), m.group(4)))
        elif l.startswith('func ') or l.startswith('static func '):
            raise SystemExit("signature non reconnue, ligne %d : %s" % (i + 1, l.strip()))
    for f in fonctions:
        d = f.ligne
        while d > 0 and (lignes[d - 1].startswith('#') or lignes[d - 1].startswith('@')):
            d -= 1
        f.debut = d
    for k, f in enumerate(fonctions):
        f.fin = fonctions[k + 1].debut if k + 1 < len(fonctions) else len(lignes)
    return fonctions


def membres_de(lignes):
    vars_inst, vars_stat, consts = set(), set(), set()
    for l in lignes:
        m = re.match(r'^(static )?var ([A-Za-z_]\w*)', l)
        if m:
            (vars_stat if m.group(1) else vars_inst).add(m.group(2))
        m = re.match(r'^const ([A-Za-z_]\w*)', l)
        if m:
            consts.add(m.group(1))
    return vars_inst, vars_stat, consts


class Reecriture:
    def __init__(self, fonctions, vars_inst, vars_stat, consts):
        self.par_nom = {f.nom: f for f in fonctions}
        self.vars_inst, self.vars_stat, self.consts = vars_inst, vars_stat, consts
        self.rapport = []

    def reecrire(self, texte, module, nom_fonction, locales):
        """`module` = classe du module où ce texte va (None pour le cœur)."""
        toks = list(TOK.finditer(texte))
        out = []
        i = 0

        def prochain_utile(k):
            while k < len(toks):
                t = toks[k]
                if t.lastgroup == 'other' and t.group().isspace():
                    k += 1
                    continue
                return k, t
            return k, None

        def precedent_est(chaine):
            for s in reversed(out):
                if s.isspace():
                    continue
                return s == chaine
            return False

        while i < len(toks):
            t = toks[i]
            g = t.lastgroup
            s = t.group()
            if g != 'id':
                out.append(s)
                i += 1
                continue
            # un identifiant
            apres_point = precedent_est('.')
            apres_func = False
            for prev in reversed(out):
                if prev.isspace():
                    continue
                apres_func = (prev == 'func')
                break
            if apres_point or apres_func or s in MOTS_CLES and s != 'self':
                out.append(s)
                i += 1
                continue
            if s == 'self':
                out.append('sim' if module else 'self')
                i += 1
                continue
            if module and s in ('tr', 'tr_n') and s not in locales:
                out.append('sim.' + s)   # les méthodes d'Object (traduction) n'existent pas en statique
                i += 1
                continue
            if s in locales:
                if s in self.vars_inst or s in self.vars_stat or s in self.consts or s in self.par_nom:
                    self.rapport.append("%s : la locale `%s` masque un membre" % (nom_fonction, s))
                out.append(s)
                i += 1
                continue
            if module and s in self.vars_inst:
                out.append('sim.' + s)
                i += 1
                continue
            if module and (s in self.vars_stat or s in self.consts):
                out.append(CLASSE_SIM + '.' + s)
                i += 1
                continue
            if s in self.par_nom:
                f = self.par_nom[s]
                k, suivant = prochain_utile(i + 1)
                appel = suivant is not None and suivant.group() == '('
                if f.statique:
                    # une statique du cœur : depuis un module, qualifiée par la classe
                    out.append((CLASSE_SIM + '.' + s) if module else s)
                    i += 1
                    continue
                if not appel:
                    if f.module == module:
                        out.append(s)   # un Callable de la même classe
                    elif f.module is None:
                        out.append('sim.' + s)   # un Callable lié à la simulation (`connect`)
                    else:
                        self.rapport.append("%s : `%s` référencé sans appel (Callable) vers %s" % (nom_fonction, s, f.module))
                        out.append(s)
                    i += 1
                    continue
                # un appel : qui le reçoit ?
                k2, apres_paren = prochain_utile(k + 1)
                vide = apres_paren is not None and apres_paren.group() == ')'
                # `var x := f(...)` vers une autre classe : le type ne s'infère pas pendant l'analyse croisée, on l'écrit
                if f.module != module and f.ret != 'void':
                    utiles = [j for j in range(len(out)) if not out[j].isspace()]
                    if len(utiles) >= 4 and out[utiles[-1]] == '=' and out[utiles[-2]] == ':' and out[utiles[-4]] == 'var' and re.match(r'^[A-Za-z_]\w*$', out[utiles[-3]]):
                        out[utiles[-3]] = out[utiles[-3]] + ': ' + f.ret
                        out[utiles[-2]] = ''   # `var x: T = …` : le `:=` n'a plus lieu d'être
                if f.module == module:
                    if module is None:
                        out.append(s + '(')
                    else:
                        out.append(s + '(sim' + ('' if vide else ', '))
                elif f.module is None:
                    out.append('sim.' + s + '(')
                else:
                    premier = 'self' if module is None else 'sim'
                    out.append(f.module + '.' + s + '(' + premier + ('' if vide else ', '))
                # on a consommé jusqu'à la parenthèse ouvrante incluse
                i = k + 1
                continue
            out.append(s)
            i += 1
        return ''.join(out)


def main():
    ecrire_fichiers = '--ecrire' in sys.argv
    texte = lire(SRC)
    lignes = texte.split('\n')
    fonctions = analyser(lignes)
    vars_inst, vars_stat, consts = membres_de(lignes)
    par_nom = {f.nom: f for f in fonctions}
    ordre = {f.nom: k for k, f in enumerate(fonctions)}
    modules = {}   # classe → (fichier, doc, [fonctions])
    for classe, fichier, doc, plages in PLAN:
        liste = []
        for premier, dernier in plages:
            assert premier in par_nom and dernier in par_nom, (premier, dernier)
            a, b = ordre[premier], ordre[dernier]
            assert a <= b, (premier, dernier)
            for f in fonctions[a:b + 1]:
                assert f.module is None, "%s déjà dans %s" % (f.nom, f.module)
                assert not f.statique, "%s est statique : elle reste dans le cœur" % f.nom
                f.module = classe
                liste.append(f)
        modules[classe] = (fichier, doc, liste)
    R = Reecriture(fonctions, vars_inst, vars_stat, consts)

    # les fonctions du cœur, réécrites une à une (les appels vers les modules)
    coeur = []
    k_ligne = 0
    for f in fonctions:
        if f.module is not None:
            continue
    # on reconstruit le cœur : tout ce qui n'est pas un bloc déplacé
    blocs_deplaces = sorted([(f.debut, f.fin) for f in fonctions if f.module is not None])
    morceaux = []
    pos = 0
    for d, fin in blocs_deplaces:
        if d > pos:
            morceaux.append((pos, d))
        pos = max(pos, fin)
    if pos < len(lignes):
        morceaux.append((pos, len(lignes)))
    texte_coeur_parts = []
    for d, fin in morceaux:
        part = '\n'.join(lignes[d:fin])
        # réécrire fonction par fonction (les locales) : on découpe aux définitions
        sous = re.split(r'(?m)^(?=(?:static )?func )', part)
        res = []
        for morceau in sous:
            m = DEF.match(morceau.split('\n', 1)[0])
            if m:
                res.append(R.reecrire(morceau, None, m.group(2), locales_de(morceau)))
            else:
                res.append(R.reecrire(morceau, None, '(en-tête)', set()))
        texte_coeur_parts.append(''.join(res))
    texte_coeur = '\n'.join(texte_coeur_parts)
    texte_coeur = re.sub(r'\n{4,}', '\n\n\n', texte_coeur)

    # les autres fichiers : ce qu'ils appellent encore sur la simulation → délégués
    autres = []
    for p in glob.glob(os.path.join(RACINE, 'godot', '**', '*.gd'), recursive=True):
        if os.path.abspath(p) == os.path.abspath(SRC) or os.path.abspath(p).startswith(os.path.abspath(DEST)):
            continue
        autres.append(lire(p))
    corpus = '\n'.join(autres)
    delegues = []
    for f in fonctions:
        if f.module is None:
            continue
        if re.search(r'[.\"]' + re.escape(f.nom) + r'\b', corpus):
            noms = [nom_param(p) for p in separer_params(f.params)]
            args = ', '.join(['self'] + noms)
            corps = '%s.%s(%s)' % (f.module, f.nom, args)
            if f.ret != 'void':
                corps = 'return ' + corps
            sig = 'func %s(%s) -> %s:' % (f.nom, f.params, f.ret)
            delegues.append((f.module, sig + '\n\t' + corps))
    if delegues:
        texte_coeur = texte_coeur.rstrip('\n') + '\n\n\n' + \
            '# ---------------------------------------------------------------- délégués vers les bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)\n' + \
            '## Ce que le client, les tests et les sondes appellent sur la simulation garde sa signature ; les règles vivent dans\n' + \
            '## les modules `godot/systems/simulation/`. Écrits par `tools/fragmenter.py`.\n'
        derniere = None
        for module, txt in delegues:
            if module != derniere:
                texte_coeur += '\n# %s\n' % module
                derniere = module
            texte_coeur += '\n' + txt + '\n'
        texte_coeur += '\n'

    # les modules
    sorties = {}
    vars_deplacees = []   # les `var` de classe déclarées au fil d'une plage déplacée : l'état reste au cœur
    for classe, (fichier, doc, liste) in modules.items():
        corps = []
        for f in liste:
            bloc = lignes[f.debut:f.fin]
            garde = []
            k = 0
            while k < len(bloc):
                l = bloc[k]
                if re.match(r'^(static var |var |const )', l):
                    while garde and garde[-1].startswith('#') and not garde[-1].startswith('# ----'):
                        vars_deplacees.append(garde.pop())   # ses commentaires de tête, contigus
                    vars_deplacees.append(l)
                    k += 1
                    continue
                garde.append(l)
                k += 1
            morceau = '\n'.join(garde)
            loc = locales_de(morceau)
            if 'sim' in loc:
                R.rapport.append("%s : une locale s'appelle déjà `sim`" % f.nom)
            # la signature : statique, sim en premier
            vide = f.params.strip() == ''
            sig_avant = 'func %s(%s)' % (f.nom, f.params)
            sig_apres = 'static func %s(sim: %s%s)' % (f.nom, CLASSE_SIM, '' if vide else ', ' + f.params)
            assert morceau.count(sig_avant) == 1, f.nom
            morceau = morceau.replace(sig_avant, sig_apres)
            corps.append(R.reecrire(morceau, classe, f.nom, loc))
        entete = ('class_name %s\nextends RefCounted\n## %s.\n'
                  '## Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l\'état vit dans\n'
                  '## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par\n'
                  '## `tools/fragmenter.py`, sans changement de comportement.\n\n\n') % (classe, doc[0].upper() + doc[1:])
        contenu = entete + '\n'.join(corps).rstrip('\n') + '\n'
        contenu = re.sub(r'\n{4,}', '\n\n\n', contenu)
        sorties[os.path.join(DEST, fichier)] = contenu

    if vars_deplacees:
        section = ('# ---------------------------------------------------------------- l\'état des bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)\n'
                   '## Ces variables étaient déclarées au fil des sections déplacées ; l\'état reste ici, les règles sont dans les modules.\n'
                   + '\n'.join(vars_deplacees) + '\n\n\n')
        marque = '# ---------------------------------------------------------------- délégués'
        if marque in texte_coeur:
            i = texte_coeur.index(marque)
            texte_coeur = texte_coeur[:i] + section + texte_coeur[i:]
        else:
            texte_coeur = texte_coeur.rstrip('\n') + '\n\n\n' + section

    # le rapport
    n_coeur = texte_coeur.count('\n')
    print("cœur : %d lignes (%d fonctions restent, %d délégués)" % (n_coeur, sum(1 for f in fonctions if f.module is None), len(delegues)))
    for classe, (fichier, doc, liste) in modules.items():
        print("  %-16s %-22s %5d lignes, %3d fonctions" % (classe, fichier, sorties[os.path.join(DEST, fichier)].count('\n'), len(liste)))
    for r in R.rapport:
        print("  À VOIR : " + r)
    if ecrire_fichiers:
        ecrire(SRC, texte_coeur)
        for p, s in sorties.items():
            ecrire(p, s)
        print("écrit.")
    else:
        print("(rapport seul : --ecrire pour écrire)")


if __name__ == '__main__':
    main()
