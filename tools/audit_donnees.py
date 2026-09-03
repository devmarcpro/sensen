# -*- coding: utf-8 -*-
"""Audit des donnees : ce qui est reference mais introuvable, et ce qui existe sans source.
    python tools/audit_donnees.py
Complementaire de check_vault.py (le coffre) et de la validation au boot (les schemas) : celle-ci
verifie les liens ENTRE catalogues, que GameData ne connait pas — une famille de materiaux sans
recette qui la produit, une depouille qui ne correspond a aucun objet, un habitat sans meuble.
Sortie non nulle si un probleme est trouve."""
import sys
import re
import io, json, glob, os, collections

R = "C:/Sensen/godot/data/"
def cat(nom):
    d = {}
    for f in glob.glob(R + nom + "/**/*.json", recursive=True):
        b = os.path.basename(f)
        if b.startswith("_"): continue
        d[b[:-5]] = json.load(io.open(f, encoding="utf-8"))
    return d
def conf(nom): return json.load(io.open(R + nom + ".json", encoding="utf-8"))

items, recipes, comps, comp_recipes = cat("items"), cat("recipes"), cat("components"), cat("component_recipes")
materials, creatures, plants, species = cat("materials"), cat("creatures"), cat("plants"), cat("species")
meubles, stations, statuses = cat("meubles"), cat("stations"), cat("status_effects")
familles = conf("material_families")
probs = collections.defaultdict(list)

# 1. sorties de recettes : l'objet existe ?
for rid, r in recipes.items():
    it = str(r.get("output", {}).get("item", ""))
    if it and it not in items:
        probs["recette → objet de sortie inconnu"].append("%s → %s" % (rid, it))
    mat = str(r.get("output", {}).get("material", ""))
    if mat and mat not in materials:
        probs["recette → matériau de sortie inconnu"].append("%s → %s" % (rid, mat))
    for e in r.get("inputs", []):
        if e.get("item") and str(e["item"]) not in items:
            probs["recette → ingrédient inconnu"].append("%s → %s" % (rid, e["item"]))
        if e.get("material") and str(e["material"]) not in materials:
            probs["recette → matériau d'entrée inconnu"].append("%s → %s" % (rid, e["material"]))
    if str(r.get("station", "")) and str(r["station"]) not in stations:
        probs["recette → station inconnue"].append("%s → %s" % (rid, r["station"]))

# 2. objets meubles : le meuble existe ?
for iid, it in items.items():
    if it.get("meuble") and str(it["meuble"]) not in meubles:
        probs["objet → meuble inconnu"].append("%s → %s" % (iid, it["meuble"]))
    pseudo = ("huile_feu",)   # des drapeaux lus directement par la simulation, pas des status_effects
    if it.get("statut") and str(it["statut"]) not in statuses and not str(it["statut"]).startswith("purge:") and str(it["statut"]) not in pseudo:
        probs["objet → statut inconnu"].append("%s → %s" % (iid, it["statut"]))

# 3. dépouilles et parties de bête : l'objet existe ?
for cid, c in creatures.items():
    for d in c.get("depouille", []):
        if str(d) not in items:
            probs["créature → dépouille inconnue"].append("%s → %s" % (cid, d))

# 4. plantes : un consommable du même id ?
for pid in plants:
    if pid not in items:
        probs["plante sans consommable"].append(pid)

# 5. familles de matériaux : une source ?
def sources_materiau():
    src = set()
    for r in recipes.values():
        o = r.get("output", {})
        if o.get("material"): src.add(str(o["material"]))
        if o.get("forme") and not o.get("item"):   # garde le matériau de l'entrée
            for e in r.get("inputs", []):
                if e.get("material"): src.add(str(e["material"]))
                if e.get("category"):
                    for m, md in materials.items():
                        if str(md.get("category", "")) == str(e["category"]): src.add(m)
    for m, md in materials.items():   # ce que le monde pose
        wg = md.get("world_gen", {})
        if wg and str(wg.get("mode", "")) in ("biome", "filon", "strate", "surface"): src.add(m)
    for b in cat("biomes").values():
        src.add(str(b.get("surface_material", "")))
        src.add(str(b.get("subsurface_material", "")))
    for pool in conf("minerais_par_etage").get("tiers", {}).values():
        src.update(str(x) for x in pool)
    for c in creatures.values():
        for d in c.get("depouille", []): src.add(str(d))
    return src
src = sources_materiau()
for fid, f in familles.items():
    if fid == "_doc": continue
    m = str(f.get("material", ""))
    if m and m not in materials:
        probs["famille → matériau inconnu"].append("%s → %s" % (fid, m))
    elif m and m not in src:
        probs["famille de composant sans source"].append("%s (%s)" % (fid, m))

# 6. recettes de composants : la famille existe ?
for cid, cr in comp_recipes.items():
    fam = str(cr.get("material_family", ""))
    if fam and fam not in familles:
        probs["recette de composant → famille inconnue"].append("%s → %s" % (cid, fam))
    if cr.get("component") and str(cr["component"]) not in comps:
        probs["recette de composant → composant inconnu"].append("%s → %s" % (cid, cr["component"]))

# 7. espèces : habitat = un meuble contenant ?
types_meubles = {str(m.get("type_meuble", "")) for m in meubles.values() if m.get("capacite_slots")}
for sid, sp in species.items():
    if str(sp.get("habitat", "")) not in types_meubles:
        probs["espèce → habitat sans meuble"].append("%s → %s" % (sid, sp.get("habitat")))


# 8. classes et races : competences, talents, objets, modules
classes, races, talents, competences = cat("classes"), cat("races"), cat("talents"), cat("competences")
modules, creature_actions, ai_profiles = cat("modules"), cat("creature_actions"), cat("ai_profiles")
biomes, rigs, functionalities = cat("biomes"), cat("rigs"), cat("functionalities")
for cid, c in classes.items():
    for k in c.get("competences", {}):
        if str(k) not in competences: probs["classe -> competence inconnue"].append("%s -> %s" % (cid, k))
    if c.get("talent") and str(c["talent"]) not in talents: probs["classe -> talent inconnu"].append("%s -> %s" % (cid, c["talent"]))
    for it in c.get("equipement", []) + c.get("ratelier", []):
        if str(it) not in items: probs["classe -> objet inconnu"].append("%s -> %s" % (cid, it))
for rid, r in races.items():
    if r.get("talent") and str(r["talent"]) not in talents: probs["race -> talent inconnu"].append("%s -> %s" % (rid, r["talent"]))

# 9. creatures : actions, profil d'IA, rig, objets
for cid, c in creatures.items():
    for a in c.get("actions", []):
        if str(a) not in creature_actions: probs["creature -> action inconnue"].append("%s -> %s" % (cid, a))
    if c.get("ai_profile") and str(c["ai_profile"]) not in ai_profiles: probs["creature -> profil d'IA inconnu"].append("%s -> %s" % (cid, c["ai_profile"]))
    if c.get("skeleton_template") and str(c["skeleton_template"]) not in rigs: probs["creature -> rig inconnu"].append("%s -> %s" % (cid, c["skeleton_template"]))
    for it in c.get("equipement", []) + c.get("ratelier", []):
        if str(it) not in items: probs["creature -> objet inconnu"].append("%s -> %s" % (cid, it))

# 10. biomes : la faune existe au bestiaire
for bid, b in biomes.items():
    for f in b.get("faune", []) + b.get("faune_nuit", []):
        i = str(f.get("id", f) if isinstance(f, dict) else f)
        if i not in creatures: probs["biome -> creature inconnue"].append("%s -> %s" % (bid, i))

# 11. objets : fonctionnalite, module, competence
for iid, it in items.items():
    if it.get("functionality") and str(it["functionality"]) not in functionalities: probs["objet -> fonctionnalite inconnue"].append("%s -> %s" % (iid, it["functionality"]))
    if it.get("module") and str(it["module"]) not in modules: probs["objet -> module inconnu"].append("%s -> %s" % (iid, it["module"]))
    if it.get("competence") and str(it["competence"]) not in competences: probs["objet -> competence inconnue"].append("%s -> %s" % (iid, it["competence"]))

# 12. statuts poses par les modules et les affixes (le champ est un dict {id, duree_ticks})
for mid, m in modules.items():
    st = (m.get("effet") or {}).get("statut")
    sid = str(st.get("id", "")) if isinstance(st, dict) else (str(st) if st else "")
    if sid and sid not in statuses: probs["module -> statut inconnu"].append("%s -> %s" % (mid, sid))
for aid, a in cat("affixes").items():
    st = (a.get("effet") or {}).get("statut")
    sid = str(st.get("id", "")) if isinstance(st, dict) else (str(st) if st else "")
    if sid and sid not in statuses: probs["affixe -> statut inconnu"].append("%s -> %s" % (aid, sid))

# 13. modules : une liaison ou un declencheur sans `effet` est ignore en silence par l'assembleur
for mid, m in modules.items():
    if str(m.get("module_type", "")) in ("liaison", "declencheur") and not m.get("effet"):
        probs["module -> liaison/declencheur sans effet"].append(mid)

# 14. les six stats : tout nom cite ailleurs est un point donne dans le vide
STATS = ("force", "dexterite", "endurance", "volonte", "perception", "charisme")
def _stats_de(d):
    for cle in ("bonus_stats", "potentiel", "stats"):
        v = d.get(cle)
        if isinstance(v, dict):
            for k in v.keys():
                yield cle, str(k)
for cid, c in list(classes.items()) + list(races.items()):
    for cle, nom in _stats_de(c):
        if cle == "bonus_stats" and nom not in STATS:
            probs["classe/race -> stat inconnue"].append("%s -> %s" % (cid, nom))
for iid, it in items.items():
    for cle, nom in _stats_de(it):
        if cle == "potentiel" and nom not in STATS:
            probs["objet -> stat inconnue"].append("%s -> %s" % (iid, nom))
for pid, pl in plants.items():
    for cle, nom in _stats_de(pl):
        if cle == "potentiel" and nom not in STATS:
            probs["plante -> stat inconnue"].append("%s -> %s" % (pid, nom))
for sid, st in statuses.items():
    for m in st.get("modifiers", []):
        cible = str(m.get("cible", ""))
        if cible.startswith("stat:") and cible[5:] not in STATS:
            probs["statut -> stat inconnue"].append("%s -> %s" % (sid, cible))

# 16. outils de recolte : toute categorie citee par un materiau doit etre portee par une fonctionnalite
fonctionnalites = cat("functionalities")
outils = set(str(f.get("outil", "")) for f in fonctionnalites.values() if f.get("outil"))
for mid, m in materials.items():
    tc = (m.get("harvest") or {}).get("tool_category") or ""
    if tc and str(tc) not in outils:
        probs["materiau -> outil qu'aucune fonctionnalite ne porte"].append("%s -> %s" % (mid, tc))

# 17. filtres de categorie (loot, boutiques, marchands) : un filtre qui ne matche RIEN est une categorie morte
shop_types = cat("shop_types")
def _matche(it, f):
    if f.get("types_any") and str(it.get("type", "")) not in f["types_any"]:
        return False
    tags = it.get("tags", [])
    if f.get("tags_any") and not any(t in tags for t in f["tags_any"]):
        return False
    if any(t not in tags for t in f.get("tags_all", [])):
        return False
    if any(t in tags for t in f.get("tags_none", [])):
        return False
    if str(it.get("id", "")) in f.get("exclut", []):
        return False
    if f.get("categories_materiau"):
        m = materials.get(str(it.get("materiau", "")), {})
        if str(m.get("category", "")) not in f["categories_materiau"]:
            return False
    return True
def _verifier_filtre(ou, f):
    if not any(_matche(it, f) for it in items.values()):
        probs["filtre de categorie qui ne matche aucun objet"].append("%s -> %s" % (ou, json.dumps(f, ensure_ascii=False)))
for nom, c in conf("loot_rules")["contenants"]["categories"].items():
    _verifier_filtre("loot/" + nom, c["filtre"])
for sid, sh in shop_types.items():
    for k, bloc in enumerate(sh.get("selection", [])):
        _verifier_filtre("boutique %s [%d]" % (sid, k), bloc["filtre"])
for cid, c in creatures.items():
    for k, bloc in enumerate(c.get("stock_marchand", [])):
        _verifier_filtre("marchand %s [%d]" % (cid, k), bloc["filtre"])

# 15. quetes : pattern connu du progresseur, tags du selecteur reellement passes par le code, guilde qui existe
QUEST_PATTERNS = ("tuer", "donjon", "livrer", "construire", "fabriquer", "vendre", "explorer")
TAGS_CONSTRUIRE = ("meuble", "station", "mur")
KINDS_FABRIQUER = ("composant", "objet", "potion", "plat", "materiau")
quests, guilds = cat("quest_templates"), cat("guilds")
tags_creatures = set()
for c in creatures.values():
    tags_creatures.update(str(t) for t in c.get("tags", []))
tags_creatures.add("hostile")   # pose par le camp, pas par la fiche
for qid, q in quests.items():
    pat = str(q.get("pattern", ""))
    if pat not in QUEST_PATTERNS:
        probs["quete -> pattern inconnu"].append("%s -> %s" % (qid, pat))
    if q.get("guild") and str(q["guild"]) not in guilds:
        probs["quete -> guilde inconnue"].append("%s -> %s" % (qid, q["guild"]))
    sel = q.get("target_selector", {})
    for t in sel.get("tags_any", []):
        t = str(t)
        if pat == "construire" and t not in TAGS_CONSTRUIRE:
            probs["quete construire -> tag jamais passe"].append("%s -> %s" % (qid, t))
        if pat == "tuer" and t not in tags_creatures:
            probs["quete tuer -> tag qu'aucune creature ne porte"].append("%s -> %s" % (qid, t))
    for t in sel.get("kinds_any", []):
        if pat == "fabriquer" and str(t) not in KINDS_FABRIQUER:
            probs["quete fabriquer -> kind jamais passe"].append("%s -> %s" % (qid, t))
    if sel.get("items_any"):
        probs["quete -> items_any (liste d'ids : utiliser un filtre)"].append(qid)
    if pat == "livrer" and "filtre" in sel:
        _verifier_filtre("quete %s" % qid, sel["filtre"])

# 18. sorties derivees (`depuis_entree`) : le champ cite doit exister sur au moins un objet, et pointer un objet reel
for iid, it in items.items():
    d = it.get("distillat")
    if d and str(d) not in items:
        probs["objet -> distillat inconnu"].append("%s -> %s" % (iid, d))
for rid, r in recipes.items():
    out = r.get("output", {})
    if "depuis_entree" not in out:
        continue
    champ, tag = str(out.get("champ", "")), str(out["depuis_entree"])
    porteurs = [i for i, it in items.items() if it.get(champ) and tag in it.get("tags", [])]
    if not porteurs:
        probs["recette derivee sans ingredient qui porte le champ"].append("%s -> %s/%s" % (rid, tag, champ))

# 19. objets qui portent leur cout (meubles, stations) : station et competence reelles, entrees connues
competences_all = cat("competences")
for iid, it in items.items():
    rc = it.get("recipe", {})
    if not rc.get("inputs"):
        continue
    if str(rc.get("station", "")) not in stations:
        probs["objet.recipe -> station inconnue"].append("%s -> %s" % (iid, rc.get("station")))
    if str(rc.get("craft_skill", "")) not in competences_all:
        probs["objet.recipe -> competence inconnue"].append("%s -> %s" % (iid, rc.get("craft_skill")))
    for e in rc["inputs"]:
        if e.get("item") and str(e["item"]) not in items:
            probs["objet.recipe -> ingredient inconnu"].append("%s -> %s" % (iid, e["item"]))
        if e.get("material") and str(e["material"]) not in materials:
            probs["objet.recipe -> materiau inconnu"].append("%s -> %s" % (iid, e["material"]))

# 20. tags cites par le code (`"x" in e.tags`) : chacun doit exister quelque part en donnees
import re as _re
_src = ""
for _f in glob.glob("C:/Sensen/godot/**/*.gd", recursive=True):
    if "tests" in _f: continue
    _src += io.open(_f, encoding="utf-8").read() + "\n"
_tags_data = set()
for _f in glob.glob(R + "**/*.json", recursive=True):
    try: _d = json.load(io.open(_f, encoding="utf-8"))
    except Exception: continue
    _pile = [_d]
    while _pile:
        _x = _pile.pop()
        if isinstance(_x, dict):
            for _t in _x.get("tags", []) if isinstance(_x.get("tags"), list) else []:
                _tags_data.add(str(_t))
            _pile.extend(_x.values())
        elif isinstance(_x, list):
            _pile.extend(_x)
_cites = set(_re.findall(r'"([a-z_]+)" in \w+(?:\.\w+)?\.get\("tags"', _src)) | set(_re.findall(r'"([a-z_]+)" in \w+\.tags', _src))
_poses = set(_re.findall(r'tags\.append\("([a-z_]+)"\)', _src))   # poses a l'execution (releve, quetes…)
for _t in sorted(_cites - _tags_data - _poses):
    probs["tag cite par le code, porte par aucune donnee"].append(_t)

# 21. les cinq elements : un nom d'element mal ecrit fait planter la table Wu Xing a l'execution
ELEMENTS = tuple(conf("wuxing")["elements"])
def _elements_de(d, chemin, ou):
    if isinstance(d, dict):
        for k, v in d.items():
            if k in ("elements", "wuxing", "vecteur") and isinstance(v, dict):
                for nom in v.keys():
                    if str(nom) not in ELEMENTS:
                        probs["element inconnu (les cinq du Wu Xing)"].append("%s -> %s" % (ou, nom))
            else:
                _elements_de(v, chemin + "/" + str(k), ou)
    elif isinstance(d, list):
        for x in d:
            _elements_de(x, chemin, ou)
for _nom_cat in ("modules", "creatures", "items", "materials", "affixes", "status_effects", "creature_actions", "biomes"):
    for _id, _d in cat(_nom_cat).items():
        _elements_de(_d, "", "%s/%s" % (_nom_cat, _id))

# 22. noyaux inertes : un effet declare sans la donnee qui le sert ne fait RIEN quand le sort part
BESOIN_EFFET = {"statut": "statut", "deplacement": "deplacement", "terrain": "terrain",
                "invocation": "invocation", "tempo": "tempo"}
modules_cat = cat("modules")
inertes = []
for mid, m in modules_cat.items():
    if str(m.get("module_type", "")) != "noyau":
        continue
    ef = m.get("effet") or {}
    for e in [str(x) for x in m.get("effets", [])]:
        if e in BESOIN_EFFET and not ef.get(BESOIN_EFFET[e]):
            inertes.append("%s -> %s" % (mid, e))
        elif e in ("degats", "soin") and not m.get("power_base"):
            inertes.append("%s -> %s (pas de power_base)" % (mid, e))
# Chantier connu (voir Structure competences-modules-slots, callout du 2026-08-29) : 50 slots inertes
# au moment du constat. L'audit ne bloque pas sur l'existant, mais refuse que le chiffre AUGMENTE.
# 23. les autres types de modules : une condition sans predicat, une liaison ou un declencheur sans
# effet, un modificateur dont l'effet n'est lu par personne — meme controle que pour les noyaux.
# La liste est tenue a la main en miroir de Simulation._evaluer_conditions : un predicat absent d'ici
# est un module qui ne se declenche JAMAIS (la capacite ne part pas du tout).
# Miroir de Capacites.tuiles_de_forme : une geometrie absente d'ici tombe dans le defaut « visee au point ».
GEOMETRIES_GEREES = ("point", "soi", "ligne", "cone", "croix", "diagonale", "carre", "anneau", "couronne", "tuile", "vague",
    "mur", "sillage", "chemin", "colonne", "horizon", "nuee", "arc", "damier")
PREDICATS_GERES = ("hauteur_relative", "dos_ou_flanc", "ligne_de_vue_degagee", "cible_isolee",
    "cible_adjacente_a_allie", "pv_cible_sous", "pv_porteur_sous", "vecteur_de_lieu", "porteur_en_posture",
    "jauge_chaine_pleine", "segment_chaine_present", "element_cible", "porteur_immobile_depuis",
    "corruption_au_dessus", "phase_du_jour", "meteo_parmi", "porteur_dissimule", "cible_immobilisee", "cible_alignee", "cible_marquee")
CLES_MOD = ("des", "portee", "portee_mult", "portee_fixe", "portee_min", "taille", "ignore_armure", "vampirique", "erosion",
            "durees_mult", "projection", "attraction", "segments", "purification", "silencieux", "sans_trace",
            "detonation", "emprise", "tracant", "prisme", "element_vers", "geometrie_map",
            "canalisation", "enchainement", "fragmentation", "ligature", "remanence", "ricochet")
for mid, m in modules_cat.items():
    t, ef = str(m.get("module_type", "")), (m.get("effet") or {})
    if t == "condition" and "predicat_structure" in ef:
        _t = str((ef.get("predicat_structure") or {}).get("type", ""))
        if _t and _t not in PREDICATS_GERES:
            probs["condition -> predicat que le code ne gere pas"].append("%s -> %s" % (mid, _t))
    if t == "condition" and "predicat_structure" not in ef:
        probs["condition sans predicat"].append(mid)
    elif t == "liaison" and not ef:
        probs["liaison sans effet"].append(mid)
    elif t == "declencheur" and "declencheur" not in ef:
        probs["declencheur sans effet"].append(mid)
    elif t == "modificateur" and ef and not (set(ef) & set(CLES_MOD)):
        probs["modificateur dont aucune cle n'est lue par l'assembleur"].append("%s -> %s" % (mid, list(ef)))
    elif t == "portee" and str(m.get("origine", "")) not in ("cible", "lanceur"):
        probs["portee sans origine (cible | lanceur)"].append(mid)
    elif t == "forme" and str(m.get("geometrie", "")) not in GEOMETRIES_GEREES:
        probs["forme -> geometrie que le code ne gere pas"].append("%s -> %s" % (mid, m.get("geometrie")))
    elif t == "forme" and (m.get("geometrie") is None or m.get("portee_defaut") is None):
        probs["forme incomplete"].append(mid)

BUDGET_INERTES = 0   # chantier clos le 2026-08-29 : plus aucun noyau inerte, et l'audit le tient   # 50 au constat du 2026-08-29, descendu lot par lot   # 50 au constat du 2026-08-29, descendu lot par lot   # 50 au constat du 2026-08-29, descendu lot par lot   # 50 au constat du 2026-08-29, descendu lot par lot   # 50 au constat du 2026-08-29, descendu lot par lot
print("noyaux inertes (chantier en cours) : %d / %d slots — budget %d" % (len(inertes), sum(len(m.get("effets", [])) for m in modules_cat.values() if str(m.get("module_type", "")) == "noyau"), BUDGET_INERTES))
if len(inertes) > BUDGET_INERTES:
    probs["noyaux inertes : le chantier RECULE (budget %d)" % BUDGET_INERTES] = inertes

# 24. modules inatteignables : depuis que les modules sont des CHARGES (Grimoires et manuels), un module
# qu'aucun livre, aucune classe et aucune creature ne donne est un sort que le joueur ne lancera jamais.
livres = conf("loot_rules")["livres"]
def _dominante(el):
    return max(el.items(), key=lambda kv: kv[1])[0] if el else ""
_atteignables = set()
for _dom, _el in livres["domaines_grimoire"].items():
    for _mid, _m in modules_cat.items():
        _t = str(_m.get("module_type", ""))
        if _t == "noyau":
            _d = _dominante(_m.get("elements") or {})
            _arcane = (not _d) and int(_m.get("cout_endurance", 0)) <= 0
            if (_d == _el and int(_m.get("cout_mana", 0)) > 0) or (_el == "neutre" and _arcane):
                _atteignables.add(_mid)
        elif _t in ("forme", "modificateur") and _el == "neutre":
            _atteignables.add(_mid)
for _dom in livres["domaines_manuel"]:
    for _mid, _m in modules_cat.items():
        _t = str(_m.get("module_type", ""))
        if _dom == "frappes" and _t == "noyau" and int(_m.get("cout_endurance", 0)) > 0: _atteignables.add(_mid)
        if _dom == "postures" and _t == "condition": _atteignables.add(_mid)
        if _dom == "techniques" and _t in ("declencheur", "liaison"): _atteignables.add(_mid)
        # La portee est un type de module depuis le 2026-09-01 : un manuel de maitrise l'enseigne aussi.
        if _dom == "maitrise" and _t in ("modificateur", "forme", "portee"): _atteignables.add(_mid)
for _f in glob.glob(R + "classes/*.json") + glob.glob(R + "creatures/*.json"):
    _d2 = json.load(io.open(_f, encoding="utf-8"))
    for _m2 in _d2.get("modules_connus", []) or []:
        _atteignables.add(str(_m2))
    for _c2 in _d2.get("capacites", []) or []:
        for _m3 in (_c2.get("modules", []) if isinstance(_c2, dict) else []):
            _atteignables.add(str(_m3))
for _mid in sorted(set(modules_cat) - _atteignables):
    probs["module inatteignable (aucun livre, aucune classe)"].append(_mid)

# 25. « aucun chiffre fixe » (Grimoires et manuels) : les quantites de livres et de charges sont des DES
_DES = re.compile(r"^\d*d\d+([+-]\d+)?$|^\d+$")
# (les charges de module n'existent plus : apprendre est definitif, designer 2026-08-31)
# 26. toute fiche de module porte une famille (le rangement en dossiers en depend)
for _mid, _m in modules_cat.items():
    if not _m.get("famille"):
        probs["module sans famille"].append(_mid)

# 27. Un module qui impose une icone (champ `icone`) doit nommer un pictogramme que scenes/demo/pictos.gd connait.
_src_pictos = io.open(os.path.join(os.path.dirname(R.rstrip("/")), "scenes", "demo", "pictos.gd"), encoding="utf-8").read()
_bloc = _src_pictos[_src_pictos.index("const NOMS"):_src_pictos.index("]", _src_pictos.index("const NOMS"))]
PICTOS = set(re.findall(r'"([a-z_]+)"', _bloc))
for mid, m in modules_cat.items():
    if m.get("icone") and m["icone"] not in PICTOS:
        probs.setdefault("27. icone de module inconnue de pictos.gd", []).append("%s : %s" % (mid, m["icone"]))

# 28. Chaque module porte un style connu de data/styles.json (Six types de modules et assemblage, 2026-08-30).
STYLES = set(conf("styles")["styles"].keys())
for mid, m in modules_cat.items():
    st = m.get("style")
    if not st or st not in STYLES:
        probs.setdefault("28. style de module absent ou inconnu (styles.json)", []).append("%s : %s" % (mid, st))

# 29. Sous-categories de materiaux (designer 2026-09-03) : une sous-categorie qui n'existe pas dans
#     `material_categories.<cat>.sous` est une faute de frappe silencieuse — la fiche se comporterait
#     comme si elle n'en avait pas, et personne ne le verrait. On verifie aussi que la fiche suit
#     bien l'outil et la competence que sa sous-categorie declare : declarer un rangement puis y
#     contredire est pire que ne rien declarer.
_cats = conf("material_categories")
for mid, m in cat("materials").items():
    sc = m.get("sous_categorie")
    if not sc:
        continue
    _c = _cats.get(str(m.get("category", "")), {})
    _sous = _c.get("sous", {})
    if sc not in _sous:
        probs.setdefault("29. sous-categorie inconnue (material_categories.<cat>.sous)", []).append("%s : %s/%s" % (mid, m.get("category"), sc))
        continue
    _d = _sous[sc]
    _h = m.get("harvest", {}) or {}
    if _d.get("tool") and str(_h.get("tool_category", "")) != str(_d["tool"]):
        probs.setdefault("29. la fiche contredit l'outil de sa sous-categorie", []).append("%s : %s au lieu de %s" % (mid, _h.get("tool_category"), _d["tool"]))
    if _d.get("harvest_skill") and str(_h.get("skill", "")) != str(_d["harvest_skill"]):
        probs.setdefault("29. la fiche contredit la competence de sa sous-categorie", []).append("%s : %s au lieu de %s" % (mid, _h.get("skill"), _d["harvest_skill"]))

# 29b. Et la station qu'une sous-categorie nomme doit exister comme objet-station.
_stations = set()
for iid, it in cat("items").items():
    if str(it.get("type", "")) == "station":
        _stations.add(str(it.get("station", "")))
for _cn, _cd in _cats.items():
    if not isinstance(_cd, dict):
        continue
    for _sn, _sd in (_cd.get("sous", {}) or {}).items():
        if _sn.startswith("_") or not isinstance(_sd, dict):
            continue
        _st = _sd.get("station_transform")
        if _st and _st not in _stations:
            probs.setdefault("29. station de sous-categorie inexistante", []).append("%s/%s -> %s" % (_cn, _sn, _st))

for k in sorted(probs):
    print("\n== %s (%d)" % (k, len(probs[k])))
    for v in probs[k][:12]:
        print("   ", v)
if not probs:
    print("audit des donnees : rien a signaler")
sys.exit(1 if probs else 0)

