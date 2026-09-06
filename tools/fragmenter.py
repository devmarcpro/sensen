# -*- coding: utf-8 -*-
"""fragmenter.py — découpe un fichier god en bibliothèques STATIQUES
(docs/08 - Technique/Modules de la simulation et le C++.md, décidé le 2026-09-05).

Deux cibles : `simulation` (`systems/combat/simulation.gd` → `systems/simulation/sim_*.gd`, classes `Sim…`, paramètre
`sim`) et `ecrans` (`scenes/demo/ecrans.gd` → `scenes/demo/ecrans/ecrans_*.gd`, classes `Ecrans…`, paramètre `ec`).

Chaque module reçoit des PLAGES de fonctions (de la première à la dernière, dans l'ordre du fichier). L'outil :
  - déplace la plage (avec ses commentaires de tête) ; les `var`, `const` et `class` internes de la plage restent au cœur ;
  - rend chaque fonction `static` avec l'objet en premier paramètre ;
  - qualifie chaque membre (`sim.grille`, `Simulation.slot_autosave`, les méthodes de nœud implicites comme `tr`)
    et chaque appel (`f(sim, …)` dans le module, `SimX.f(sim, …)` vers un autre module, `sim.f(…)` vers le cœur) ;
  - réécrit le cœur (`SimX.f(self, …)`) ; une fonction déplacée passée sans parenthèses (un Callable pour `connect`)
    devient une lambda de même signature ; ajoute un DÉLÉGUÉ d'une ligne pour tout ce que les autres fichiers
    appellent encore sur l'objet ;
  - signale ce qu'il ne sait pas trancher (une locale qui masque un membre, un paramètre déjà nommé comme l'objet).

    python tools/fragmenter.py --cible simulation            # rapport seul
    python tools/fragmenter.py --cible ecrans --ecrire       # écrit les fichiers
Se relance depuis l'original : `git checkout` du fichier god, `rm` des modules.
"""
import io
import os
import re
import sys
import glob

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

CIBLES = {
    'simulation': {
        'src': os.path.join('godot', 'systems', 'combat', 'simulation.gd'),
        'dest': os.path.join('godot', 'systems', 'simulation'),
        'classe': 'Simulation',
        'param': 'sim',
        'implicites': ['tr', 'tr_n'],
        'doc_module': "Bibliothèque STATIQUE de la simulation (Modules de la simulation et le C++, 2026-09-05) : l'état vit dans\n## `Simulation`, reçue en premier paramètre ; ici, seulement des règles. Déplacé depuis `simulation.gd` par\n## `tools/fragmenter.py`, sans changement de comportement.",
        'titre_delegues': "délégués vers les bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)",
        'doc_delegues': "## Ce que le client, les tests et les sondes appellent sur la simulation garde sa signature ; les règles vivent dans\n## les modules `godot/systems/simulation/`. Écrits par `tools/fragmenter.py`.",
        'titre_etat': "l'état des bibliothèques Sim… (Modules de la simulation et le C++, 2026-09-05)",
        'plan': [
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
        ],
    },
    'ecrans': {
        'src': os.path.join('godot', 'scenes', 'demo', 'ecrans.gd'),
        'dest': os.path.join('godot', 'scenes', 'demo', 'ecrans'),
        'classe': 'Ecrans',
        'param': 'ec',
        'implicites': ['tr', 'tr_n', 'add_child', 'remove_child', 'get_viewport', 'get_tree', 'get_node', 'get_node_or_null',
                       'is_inside_tree', 'set_process', 'call_deferred', 'get_window', 'move_child', 'get_children', 'find_child',
                       'get_parent', 'is_node_ready', 'get_index', 'has_node', 'set_process_input', 'get_child', 'get_child_count'],
        'doc_module': "Bibliothèque STATIQUE des écrans (Modules de la simulation et le C++, 2026-09-06) : l'état et les nœuds vivent dans\n## `Ecrans`, reçu en premier paramètre ; ici, seulement la construction et la logique d'un écran. Déplacé depuis\n## `ecrans.gd` par `tools/fragmenter.py --cible ecrans`, sans changement de comportement.",
        'titre_delegues': "délégués vers les bibliothèques Ecrans… (2026-09-06)",
        'doc_delegues': "## Ce que la scène, les sondes et les autres écrans appellent sur `Ecrans` garde sa signature ; la construction des\n## écrans vit dans `scenes/demo/ecrans/`. Écrits par `tools/fragmenter.py --cible ecrans`.",
        'titre_etat': "l'état et les classes internes des écrans déplacés (2026-09-06)",
        'plan': [
            ('EcransListe', 'ecrans_liste.gd', "la liste et le détail communs : rafraîchir, les boutons, le glisser-déposer, la sélection, le détail, l'action principale",
             [('rafraichir', '_action_principale')]),
            ('EcransDialogue', 'ecrans_dialogue.gd', "le dialogue et le commerce : les répliques, l'histoire, la fiche du PNJ, les quêtes, l'échange",
             [('ouvrir_dialogue', '_construire_commerce')]),
            ('EcransGestion', 'ecrans_gestion.gd', "la gestion du territoire : le rapport, les lois, le registre, l'entraîneur, les quêtes, les capacités et le composeur, le titre",
             [('_construire_gestion', '_construire_titre')]),
            ('EcransCreation', 'ecrans_creation.gd', "la création de personnage (fiche, apparence, pantin, kit), le monde, les options, charger, le menu, la triche, le contexte, les périmètres, assigner, l'échange",
             [('_fiche_apercu', '_construire_echange')]),
            ('EcransInventaire', 'ecrans_inventaire.gd', "l'inventaire : le menu d'un objet, jeter, lire, sertir, manger, poser, le texte d'un objet",
             [('_construire_inventaire', 'texte_objet')]),
            ('EcransAtelier', 'ecrans_atelier.gd', "l'atelier : les recettes, leur texte, les piles, les filtres, l'obtention des composants",
             [('_construire_atelier', '_obtention_famille')]),
            ('EcransFeuille', 'ecrans_feuille.gd', "la feuille de personnage et l'aperçu : surligner un membre, replacer l'aperçu et la liste",
             [('_construire_feuille', '_replacer_liste')]),
        ],
    },
}

MOTS_CLES = {"if", "elif", "else", "for", "while", "match", "break", "continue", "pass", "return", "class", "class_name",
             "extends", "is", "in", "as", "self", "signal", "func", "static", "const", "enum", "var", "breakpoint", "preload",
             "await", "yield", "assert", "void", "and", "or", "not", "true", "false", "null", "super", "PI", "TAU", "INF", "NAN"}

TOK = re.compile(r'''(?P<com>\#[^\n]*)|(?P<str3>"""(?:\\.|[^\\])*?""")|(?P<str>"(?:\\.|[^"\\])*")|(?P<chr>'(?:\\.|[^'\\])*')|(?P<id>[A-Za-z_][A-Za-z0-9_]*)|(?P<other>.)''', re.S)   # une chaîne peut contenir un retour à la ligne (ecrans.gd)
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
        self.ligne = ligne
        self.statique = statique
        self.nom = nom
        self.params = params
        self.ret = (ret or 'void').strip()
        self.debut = ligne
        self.fin = ligne
        self.module = None


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
    vars_inst, vars_stat, consts, classes = set(), set(), set(), set()
    for l in lignes:
        m = re.match(r'^(?:@onready |@export(?:\([^)]*\))? )?(static )?var ([A-Za-z_]\w*)', l)
        if m:
            (vars_stat if m.group(1) else vars_inst).add(m.group(2))
        m = re.match(r'^const ([A-Za-z_]\w*)', l)
        if m:
            consts.add(m.group(1))
        m = re.match(r'^class ([A-Za-z_]\w*)', l)
        if m:
            classes.add(m.group(1))
        m = re.match(r'^signal ([A-Za-z_]\w*)', l)
        if m:
            vars_inst.add(m.group(1))
    return vars_inst, vars_stat, consts, classes


def lambda_pour(f, module, param, coeur):
    """Un Callable vers une fonction déplacée : une lambda de même signature."""
    noms = [nom_param(p) for p in separer_params(f.params)]
    params_sans_defaut = ', '.join(p.split('=')[0].strip() for p in separer_params(f.params))
    premier = 'self' if coeur else param
    appel = '%s.%s(%s)' % (f.module, f.nom, ', '.join([premier] + noms))
    if f.ret != 'void':
        appel = 'return ' + appel
    return 'func(%s) -> %s: %s' % (params_sans_defaut, f.ret, appel)


class Reecriture:
    def __init__(self, cfg, fonctions, vars_inst, vars_stat, consts, classes):
        self.cfg = cfg
        self.par_nom = {f.nom: f for f in fonctions}
        self.vars_inst, self.vars_stat, self.consts, self.classes = vars_inst, vars_stat, consts, classes
        self.rapport = []

    def reecrire(self, texte, module, nom_fonction, locales):
        """`module` = classe du module où ce texte va (None pour le cœur)."""
        classe, param, implicites = self.cfg['classe'], self.cfg['param'], self.cfg['implicites']
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

        def precedent():
            for s in reversed(out):
                if s.isspace():
                    continue
                return s
            return ''

        while i < len(toks):
            t = toks[i]
            g = t.lastgroup
            s = t.group()
            if g != 'id':
                out.append(s)
                i += 1
                continue
            prev = precedent()
            if prev == '.' or prev == 'func' or (s in MOTS_CLES and s != 'self'):
                out.append(s)
                i += 1
                continue
            if s == 'self':
                out.append(param if module else 'self')
                i += 1
                continue
            if module and s in implicites and s not in locales:
                out.append(param + '.' + s)   # une méthode du nœud (tr, add_child…) n'existe pas en statique
                i += 1
                continue
            if s in locales:
                if s in self.vars_inst or s in self.vars_stat or s in self.consts or s in self.par_nom:
                    self.rapport.append("%s : la locale `%s` masque un membre" % (nom_fonction, s))
                out.append(s)
                i += 1
                continue
            if module and s in self.vars_inst:
                out.append(param + '.' + s)
                i += 1
                continue
            if module and (s in self.vars_stat or s in self.consts or s in self.classes):
                out.append(classe + '.' + s)
                i += 1
                continue
            if s in self.par_nom:
                f = self.par_nom[s]
                k, suivant = prochain_utile(i + 1)
                appel = suivant is not None and suivant.group() == '('
                if f.statique:
                    out.append((classe + '.' + s) if module else s)
                    i += 1
                    continue
                if not appel:
                    if f.module == module:
                        out.append(s)
                    elif f.module is None:
                        out.append(param + '.' + s)   # un Callable lié à l'objet (`connect`)
                    else:
                        out.append(lambda_pour(f, module, param, module is None))   # un Callable vers un module : une lambda
                    i += 1
                    continue
                k2, apres_paren = prochain_utile(k + 1)
                vide = apres_paren is not None and apres_paren.group() == ')'
                if f.module != module and f.ret != 'void':
                    utiles = [j for j in range(len(out)) if not out[j].isspace()]
                    if len(utiles) >= 4 and out[utiles[-1]] == '=' and out[utiles[-2]] == ':' and out[utiles[-4]] == 'var' and re.match(r'^[A-Za-z_]\w*$', out[utiles[-3]]):
                        out[utiles[-3]] = out[utiles[-3]] + ': ' + f.ret
                        out[utiles[-2]] = ''
                if f.module == module:
                    if module is None:
                        out.append(s + '(')
                    else:
                        out.append(s + '(' + param + ('' if vide else ', '))
                elif f.module is None:
                    out.append(param + '.' + s + '(')
                else:
                    premier = 'self' if module is None else param
                    out.append(f.module + '.' + s + '(' + premier + ('' if vide else ', '))
                i = k + 1
                continue
            out.append(s)
            i += 1
        return ''.join(out)


def main():
    ecrire_fichiers = '--ecrire' in sys.argv
    nom_cible = 'simulation'
    for k, a in enumerate(sys.argv):
        if a == '--cible' and k + 1 < len(sys.argv):
            nom_cible = sys.argv[k + 1]
    cfg = CIBLES[nom_cible]
    SRC = os.path.join(RACINE, cfg['src'])
    DEST = os.path.join(RACINE, cfg['dest'])
    classe, param = cfg['classe'], cfg['param']
    texte = lire(SRC)
    lignes = texte.split('\n')
    fonctions = analyser(lignes)
    vars_inst, vars_stat, consts, classes = membres_de(lignes)
    par_nom = {f.nom: f for f in fonctions}
    ordre = {f.nom: k for k, f in enumerate(fonctions)}
    modules = {}
    for cl, fichier, doc, plages in cfg['plan']:
        liste = []
        for premier, dernier in plages:
            assert premier in par_nom and dernier in par_nom, (premier, dernier)
            a, b = ordre[premier], ordre[dernier]
            assert a <= b, (premier, dernier)
            for f in fonctions[a:b + 1]:
                assert f.module is None, "%s déjà dans %s" % (f.nom, f.module)
                assert not f.statique, "%s est statique : elle reste dans le cœur" % f.nom
                f.module = cl
                liste.append(f)
        modules[cl] = (fichier, doc, liste)
    R = Reecriture(cfg, fonctions, vars_inst, vars_stat, consts, classes)

    # le cœur : tout ce qui n'est pas un bloc déplacé, réécrit fonction par fonction
    blocs_deplaces = sorted([(f.debut, f.fin) for f in fonctions if f.module is not None])
    morceaux = []
    pos = 0
    for d, fin in blocs_deplaces:
        if d > pos:
            morceaux.append((pos, d))
        pos = max(pos, fin)
    if pos < len(lignes):
        morceaux.append((pos, len(lignes)))
    parts = []
    for d, fin in morceaux:
        part = '\n'.join(lignes[d:fin])
        sous = re.split(r'(?m)^(?=(?:static )?func )', part)
        res = []
        for morceau in sous:
            m = DEF.match(morceau.split('\n', 1)[0])
            if m:
                res.append(R.reecrire(morceau, None, m.group(2), locales_de(morceau)))
            else:
                res.append(R.reecrire(morceau, None, '(en-tête)', set()))
        parts.append(''.join(res))
    texte_coeur = re.sub(r'\n{4,}', '\n\n\n', '\n'.join(parts))

    # les modules ; les var, const et class des plages déplacées restent au cœur
    sorties = {}
    vars_deplacees = []
    for cl, (fichier, doc, liste) in modules.items():
        corps = []
        for f in liste:
            bloc = lignes[f.debut:f.fin]
            garde = []
            k = 0
            while k < len(bloc):
                l = bloc[k]
                if re.match(r'^(static var |var |const |@onready var |@export)', l):
                    while garde and garde[-1].startswith('#') and not garde[-1].startswith('# ----'):
                        vars_deplacees.append(garde.pop())
                    vars_deplacees.append(l)
                    k += 1
                    prof = l.count('[') + l.count('{') + l.count('(') - l.count(']') - l.count('}') - l.count(')')
                    while prof > 0 and k < len(bloc):   # une valeur sur plusieurs lignes (un tableau ouvert) suit
                        vars_deplacees.append(bloc[k])
                        prof += bloc[k].count('[') + bloc[k].count('{') + bloc[k].count('(') - bloc[k].count(']') - bloc[k].count('}') - bloc[k].count(')')
                        k += 1
                    continue
                if l.startswith('class '):
                    while garde and garde[-1].startswith('#') and not garde[-1].startswith('# ----'):
                        vars_deplacees.append(garde.pop())
                    vars_deplacees.append(l)
                    k += 1
                    while k < len(bloc) and (bloc[k].startswith('\t') or bloc[k].strip() == ''):
                        vars_deplacees.append(bloc[k])
                        k += 1
                    continue
                garde.append(l)
                k += 1
            morceau = '\n'.join(garde)
            loc = locales_de(morceau)
            if param in loc:
                R.rapport.append("%s : une locale s'appelle déjà `%s`" % (f.nom, param))
            vide = f.params.strip() == ''
            sig_avant = 'func %s(%s)' % (f.nom, f.params)
            sig_apres = 'static func %s(%s: %s%s)' % (f.nom, param, classe, '' if vide else ', ' + f.params)
            assert morceau.count(sig_avant) == 1, f.nom
            morceau = morceau.replace(sig_avant, sig_apres)
            corps.append(R.reecrire(morceau, cl, f.nom, loc))
        entete = 'class_name %s\nextends RefCounted\n## %s.\n## %s\n\n\n' % (cl, doc[0].upper() + doc[1:], cfg['doc_module'])
        contenu = re.sub(r'\n{4,}', '\n\n\n', entete + '\n'.join(corps).rstrip('\n') + '\n')
        sorties[os.path.join(DEST, fichier)] = contenu

    # les autres fichiers : ce qu'ils appellent encore sur l'objet → délégués
    corpus = []
    for p in glob.glob(os.path.join(RACINE, 'godot', '**', '*.gd'), recursive=True):
        ap = os.path.abspath(p)
        if ap == os.path.abspath(SRC) or ap.startswith(os.path.abspath(DEST)):
            continue
        corpus.append(lire(p))
    corpus = '\n'.join(corpus)
    delegues = []
    for f in fonctions:
        if f.module is None:
            continue
        if re.search(r'[.\"]' + re.escape(f.nom) + r'\b', corpus):
            noms = [nom_param(p) for p in separer_params(f.params)]
            corps = '%s.%s(%s)' % (f.module, f.nom, ', '.join(['self'] + noms))
            if f.ret != 'void':
                corps = 'return ' + corps
            delegues.append((f.module, 'func %s(%s) -> %s:\n\t%s' % (f.nom, f.params, f.ret, corps)))
    if delegues:
        texte_coeur = texte_coeur.rstrip('\n') + '\n\n\n# ---------------------------------------------------------------- %s\n%s\n' % (cfg['titre_delegues'], cfg['doc_delegues'])
        derniere = None
        for module, txt in delegues:
            if module != derniere:
                texte_coeur += '\n# %s\n' % module
                derniere = module
            texte_coeur += '\n' + txt + '\n'
        texte_coeur += '\n'
    if vars_deplacees:
        section = ('# ---------------------------------------------------------------- %s\n'
                   '## Déclarés au fil des sections déplacées ; l\'état reste ici, les règles sont dans les modules.\n' % cfg['titre_etat']
                   + '\n'.join(vars_deplacees).rstrip('\n') + '\n\n\n')
        marque = '# ---------------------------------------------------------------- ' + cfg['titre_delegues']
        if marque in texte_coeur:
            i = texte_coeur.index(marque)
            texte_coeur = texte_coeur[:i] + section + texte_coeur[i:]
        else:
            texte_coeur = texte_coeur.rstrip('\n') + '\n\n\n' + section

    print("cœur : %d lignes (%d fonctions restent, %d délégués)" % (texte_coeur.count('\n'), sum(1 for f in fonctions if f.module is None), len(delegues)))
    for cl, (fichier, doc, liste) in modules.items():
        print("  %-18s %-24s %5d lignes, %3d fonctions" % (cl, fichier, sorties[os.path.join(DEST, fichier)].count('\n'), len(liste)))
    for r in R.rapport:
        if 'masque un membre' in r and nom_cible == 'simulation':
            continue
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
