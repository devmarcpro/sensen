# -*- coding: utf-8 -*-
"""La liste des objets du jeu pour les sprites (designer 2026-09-05 : « je vais générer les sprites des items,
donne-moi la liste des armes avec leurs composants, pareil pour les outils, l'équipement et autres items »).

Lit les données (godot/data) et les traductions françaises, et écrit :
  - docs/09 - Contenu/Objets — liste pour les sprites.md   (la note du coffre, régénérable)
  - <sortie json> (option --json chemin) : les mêmes listes, pour une page.

    python -X utf8 tools/liste_objets.py [--json fichier.json]

Rien n'est écrit à la main : ce qui manque ici manque dans les données.
"""
import csv, glob, io, json, os, sys, collections

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "godot", "data")
NOTE = os.path.join(RACINE, "docs", "09 - Contenu", "Objets — liste pour les sprites.md")

# ---------------------------------------------------------------- lecture

def lire(chemin):
    return json.load(io.open(chemin, encoding="utf-8"), object_pairs_hook=collections.OrderedDict)


def catalogue(dossier):
    res = collections.OrderedDict()
    for f in sorted(glob.glob(os.path.join(DATA, dossier, "**", "*.json"), recursive=True)):
        if os.path.basename(f).startswith("_"):
            continue
        res[os.path.basename(f)[:-5]] = lire(f)
    return res


TR = {}
with io.open(os.path.join(RACINE, "godot", "locale", "fr.csv"), encoding="utf-8", newline="") as fh:
    for ligne in csv.reader(fh):
        if len(ligne) >= 2:
            TR[ligne[0]] = ligne[1]


def tr(cle, defaut=None):
    return TR.get(cle, defaut if defaut is not None else cle)


def nom_item(iid, d):
    return tr(d.get("name_key", "item.%s.name" % iid), iid)


items = catalogue("items")
composants = catalogue("components")
recettes_comp = catalogue("component_recipes")
fonctionnalites = catalogue("functionalities")
competences = catalogue("competences")
familles = lire(os.path.join(DATA, "material_families.json"))
categories = lire(os.path.join(DATA, "material_categories.json"))
materiaux = catalogue("materials")
meubles_def = catalogue("meubles")
stations_def = catalogue("stations")
loot = lire(os.path.join(DATA, "loot_rules.json"))
apparences = loot.get("identification", {}).get("apparences", [])

# familles de matériaux par composant (recettes)
familles_par_comp = collections.defaultdict(list)
for rid, r in recettes_comp.items():
    c = r.get("component", "")
    if c and not c.startswith("<"):
        familles_par_comp[c].append(r.get("material_family", "?"))


def nom_famille(fid):
    return tr("famille." + fid, fid)


def nom_comp(cid):
    return tr(composants.get(cid, {}).get("name_key", "component.%s.name" % cid), cid)


def nom_fonct(fid):
    return tr(fonctionnalites.get(fid, {}).get("name_key", "functionality.%s.name" % fid), fid)


def nom_competence(cid):
    return tr(competences.get(cid, {}).get("name_key", "competence.%s.name" % cid), cid)


def nom_slot(s):
    return tr("slot." + s, s)


def nom_zone(z):
    return tr("zone." + z, z)


def nom_construction(c):
    return tr("construction.%s.nom" % c, c)


def nom_categorie(c):
    return tr("categorie." + c, c)


def nom_stat(s):
    return tr("stat." + s, s)


def nom_tag(t):
    return tr("tag." + t, t)


def nom_element(e):
    return tr("element." + e, e)


def composants_de(d):
    """[(slot, composant id, nom, familles de matériaux)]"""
    res = []
    for slot, cid in d.get("slots", {}).items():
        fams = familles_par_comp.get(cid, [])
        res.append((slot, cid, nom_comp(cid), [nom_famille(f) for f in fams]))
    return res


def texte_composants(d):
    parts = []
    for slot, cid, nom, fams in composants_de(d):
        parts.append("%s : **%s** (%s)" % (slot, nom, ", ".join(fams) if fams else "—"))
    return " · ".join(parts) if parts else "—"


def est_proto(d):
    return "prototype" in d.get("tags", [])


def nom_sprite(iid, d=None):
    """Ce qu'il faut dessiner (Direction artistique, 2026-09-05, 9 h) : un objet assemblé n'a pas de sprite propre, son
    icône est composée des sprites de ses composants (composants/<id>.png, ou <id>_<variante>.png) ; un objet de fortune
    (proto_) garde son pictogramme ; le reste est un fichier <id>.png."""
    if d is not None and d.get("slots"):
        v = d.get("variante_visuelle", "")
        return " + ".join("composants/%s.png" % cid for cid in d["slots"].values()) + ((" · variante %s" % v) if v else "")
    if iid.startswith("proto_"):
        return "— (pictogramme)"
    if iid.startswith("craft_"):
        return iid[len("craft_"):] + ".png"
    return iid + ".png"


# ---------------------------------------------------------------- sections

def section_armes():
    lignes = []
    armes = [(i, d) for i, d in items.items() if d.get("type") == "arme"]
    voies = collections.OrderedDict()
    for i, d in sorted(armes, key=lambda x: nom_item(*x)):
        f = fonctionnalites.get(d.get("functionality", ""), {})
        comp = f.get("combat_skill", "")
        stat = competences.get(comp, {}).get("stat", "?")
        voies.setdefault(stat, []).append((i, d, f, comp))
    ordre = ["force", "dexterite", "endurance", "volonte", "perception", "charisme"]
    rows = []
    for stat in ordre + [s for s in voies if s not in ordre]:
        for i, d, f, comp in voies.get(stat, []):
            rows.append(collections.OrderedDict([
                ("id", i), ("nom", nom_item(i, d)), ("voie", nom_stat(stat)), ("competence", nom_competence(comp)),
                ("mains", d.get("hands", f.get("hands", 1))), ("emplacement", nom_slot(d.get("equip_slot", ""))),
                ("degats", f.get("degats_des", "—")), ("type_degats", f.get("type_degats", "—")),
                ("portee", "%s–%s" % (f.get("portee_min", 1), f.get("portee", 1))),
                ("zone", f.get("attaque_zone", "")),
                ("composants", composants_de(d)), ("proto", est_proto(d)),
                ("materiau", d.get("materiau", "")), ("sprite", nom_sprite(i, d)),
            ]))
    return rows


def section_simple(type_, avec_fonct=True):
    rows = []
    for i, d in sorted(((i, d) for i, d in items.items() if d.get("type") == type_), key=lambda x: nom_item(*x)):
        f = fonctionnalites.get(d.get("functionality", ""), {}) if avec_fonct else {}
        rows.append(collections.OrderedDict([
            ("id", i), ("nom", nom_item(i, d)), ("fonction", nom_fonct(d["functionality"]) if d.get("functionality") else ""),
            ("mains", d.get("hands", 0)), ("emplacement", nom_slot(d.get("equip_slot", "")) if d.get("equip_slot") else "—"),
            ("zone", nom_zone(d["zone"]) if d.get("zone") else ""), ("construction", nom_construction(d["construction"]) if d.get("construction") else ""),
            ("composants", composants_de(d)), ("proto", est_proto(d)), ("materiau", d.get("materiau", "")),
            ("tags", [t for t in d.get("tags", []) if t not in (type_, "assemble", "prototype")]),
            ("quantite", d.get("quantite", 1)), ("luminosite", d.get("luminosite", 0)),
            ("materiaux_recette", [(e.get("category", ""), e.get("forme", ""), e.get("amount", 0)) for e in d.get("recipe", {}).get("inputs", [])]),
            ("element", d.get("element") or ""), ("meuble", d.get("meuble", "")), ("station", d.get("station", "")), ("sprite", nom_sprite(i, d)),
        ]))
    return rows


def section_composants():
    rows = []
    for cid, c in sorted(composants.items(), key=lambda x: nom_comp(x[0])):
        rows.append(collections.OrderedDict([
            ("id", cid), ("nom", nom_comp(cid)), ("slot", c.get("slot_type", "")),
            ("familles", [nom_famille(f) for f in familles_par_comp.get(cid, [])]),
            ("stations", sorted(set(r.get("station", "") for r in recettes_comp.values() if r.get("component") == cid))),
            ("utilise_par", [nom_fonct(u) if u in fonctionnalites else tr("item.craft_%s.name" % u, u) for u in c.get("used_by", [])]),
            ("sprite", "composants/%s.png" % cid),
        ]))
    return rows


def section_gemmes():
    rows = []
    for i, d in sorted(((i, d) for i, d in items.items() if d.get("type") == "gemme"), key=lambda x: nom_item(*x)):
        effets = []
        for t in d.get("tailles", []):
            typ = t.get("type", "")
            if typ == "competence":
                effets.append(nom_competence(t.get("competence", "")))
            elif typ == "stat":
                effets.append(nom_stat(t.get("stat", "")))
            elif typ == "degats_element":
                effets.append("dégâts " + nom_element(t.get("element", "")))
            else:
                effets.append(typ)
        rows.append(collections.OrderedDict([
            ("id", i), ("nom", nom_item(i, d)), ("materiau", tr("material.%s.name" % d.get("materiau", ""), d.get("materiau", ""))),
            ("element", nom_element(d["element"]) if d.get("element") else "—"), ("effets", effets), ("sprite", nom_sprite(i, d)),
        ]))
    return rows


def section_consommables():
    groupes = collections.OrderedDict([
        ("potion", "Potions (fioles)"), ("plat", "Plats cuisinés"), ("viande", "Viandes"), ("culture", "Cultures (récoltes des champs)"),
        ("herbe", "Herbes, champignons et buissons (cueillette)"), ("partie", "Parties de créatures"), ("autre", "Autres"),
    ])
    rows = collections.OrderedDict((g, []) for g in groupes)
    for i, d in sorted(((i, d) for i, d in items.items() if d.get("type") == "consommable"), key=lambda x: nom_item(*x)):
        tags = d.get("tags", [])
        g = "autre"
        for cle in ["potion", "plat", "viande", "culture", "herbe", "partie"]:
            if cle in tags or (cle == "herbe" and ("champignon" in tags or "buisson" in tags)):
                g = cle
                break
        rows[g].append(collections.OrderedDict([
            ("id", i), ("nom", nom_item(i, d)),
            ("tags", [nom_tag(t) for t in tags if t not in ("consommable", "empilable")]),
            ("distillat", tr("item.%s.name" % d["distillat"], d["distillat"]) if d.get("distillat") else ""),
            ("wuxing", ", ".join("%s %d %%" % (nom_element(e), round(v * 100)) for e, v in d.get("wuxing", {}).items())),
            ("cru", d.get("cru", False)), ("sprite", nom_sprite(i, d)),
        ]))
    return groupes, rows


def section_materiaux():
    formes = sorted(k[len("forme."):] for k in TR if k.startswith("forme."))
    cats = collections.OrderedDict()
    for mid, m in materiaux.items():
        cats.setdefault(m.get("category", "?"), []).append(tr(m.get("name_key", "material.%s.name" % mid), mid))
    return formes, cats


# ---------------------------------------------------------------- écriture

def md_composants(comps):
    if not comps:
        return "—"
    return "<br>".join("`%s` → **%s** — %s" % (slot, nom, ", ".join(fams) if fams else "—") for slot, cid, nom, fams in comps)


def ecrire_note(armes, outils, boucliers, armures, bijoux, gemmes, munitions, comps, livres, groupes_c, cons, formes, cats_mat, meubles, stations):
    L = []
    w = L.append
    w("---")
    w('aliases: ["Liste des objets", "Sprites des objets"]')
    w("tags: [contenu, art, généré]")
    w("domaine: contenu")
    w("statut: décidé")
    w("etape: 1")
    w("---")
    w("")
    w("> [!important] Demande du designer (2026-09-05) : « je vais générer les sprites des items, donne-moi la liste des armes avec leurs composants, pareil pour les outils, l'équipement et autres items »")
    w("> Cette note est **générée** par `tools/liste_objets.py` depuis `godot/data` et `locale/fr.csv` : rien n'y est écrit à la main, la relancer la remet à jour. Elle compte ce que le jeu sait fabriquer, ramasser ou poser, avec ce qui fait la silhouette d'un objet : son **type**, son **emplacement**, ses **composants** et les **familles de matériaux** que chaque composant accepte.")
    w(">")
    w("> **Où vont les sprites.** `godot/assets/objets/` ([[Direction artistique]], 2026-09-05). **On ne dessine pas les armes, on dessine les composants** : un objet assemblé (arme, outil, bouclier, armure, bijou, munition) n'a pas de sprite propre — son icône est composée des sprites de ses composants, `composants/<id>.png` (ou `composants/<id>_<variante>.png` quand l'objet porte `variante_visuelle` : épée droite, sabre courbe, rapière fine), chacun teinté par sa matière ; la colonne « sprite » de chaque table dit lesquels. Les objets qui ne s'assemblent pas (consommables, gemmes, livres, meubles, stations) sont un fichier `<id>.png` ; les matières, un fichier par forme dans `matieres/`. Gris neutre, carré, fond transparent ; le jeu prend un sprite dès qu'il existe et garde son pictogramme par code sinon ; `tools/verif_sprites.py` dit ce qui manque.")
    w(">")
    w("> **Ce qui fait un objet, pour le dessin.** Un objet assemblé est une *base* (épée, cuirasse, pioche) dont chaque *composant* est taillé dans un *matériau* — c'est le matériau qui donne la couleur ([[Palette de couleurs des matériaux]]) et la qualité qui donne l'état. Dessiner les composants, c'est donc dessiner toutes les armes à la fois : l'épée à lame d'os et poignée d'ivoire que le joueur a fabriquée ressemble à ce qu'elle est. Les objets `proto_*` sont les pièces de fortune du prototype (une matière fixe, pas de composants) : mêmes silhouettes que leurs bases assemblées. Le jeu dessine aujourd'hui des pictogrammes par code (`Pictos.dessiner_objet`, une case de 10 × 10 unités, avec des alias : sabre et rapière → épée, stylet → dague, hallebarde → lance, baguette → bâton magique…) — les sprites peuvent suivre ces regroupements ou distinguer chaque objet. Conventions : [[Direction artistique]] (lisibilité avant réalisme, teintes des cinq éléments) et le gabarit d'encrage `gabarit-encrage-sprites.pdf` dans ce dossier.")
    w("")
    w("## 1. Les armes (%d, dont %d de fortune)" % (len(armes), sum(1 for a in armes if a["proto"])))
    w("")
    w("Par voie (la stat de la compétence de l'arme). Dés, type de dégâts et portée viennent de la fonctionnalité ; les composants et leurs matériaux des recettes de composants.")
    w("")
    w("| Arme | id · sprite | Voie · compétence | Mains | Dés · type · portée | Composants (slot → composant — matériaux) |")
    w("|---|---|---|---|---|---|")
    for a in armes:
        w("| **%s**%s | `%s`<br>`%s` | %s · %s | %d | %s · %s · %s%s | %s |" % (
            a["nom"], " *(fortune, %s)*" % a["materiau"] if a["proto"] else "", a["id"], a["sprite"], a["voie"], a["competence"], a["mains"],
            a["degats"], a["type_degats"], a["portee"], (" · zone %s" % a["zone"]) if a["zone"] else "", md_composants(a["composants"])))
    w("")
    w("## 2. Les outils (%d) et les boucliers (%d)" % (len(outils), len(boucliers)))
    w("")
    w("| Outil | id · sprite | Fonction | Mains · emplacement | Composants |")
    w("|---|---|---|---|---|")
    for o in outils + boucliers:
        extra = (" · %s, %s" % (o["zone"], o["construction"])) if o["construction"] else ""
        lum = (" · lumière %d" % o["luminosite"]) if o["luminosite"] else ""
        w("| **%s**%s | `%s`<br>`%s` | %s%s%s | %d · %s | %s |" % (o["nom"], " *(fortune, %s)*" % o["materiau"] if o["proto"] else "", o["id"], o["sprite"], o["fonction"] or "—", extra, lum, o["mains"], o["emplacement"], md_composants(o["composants"])))
    w("")
    w("## 3. Armures et vêtements (%d)" % len(armures))
    w("")
    w("L'emplacement dit où la pièce se porte, la zone ce qu'elle couvre, la construction sa matière dominante (plaque, tissu, matelassé, rituel, cuir, mailles). Les vêtements ont une *étoffe* là où les armures ont une *plaque*.")
    w("")
    w("| Pièce | id · sprite | Emplacement · zone | Construction | Composants |")
    w("|---|---|---|---|---|")
    for a in armures:
        w("| **%s**%s | `%s`<br>`%s` | %s · %s | %s | %s |" % (a["nom"], " *(fortune, %s)*" % a["materiau"] if a["proto"] else "", a["id"], a["sprite"], a["emplacement"], a["zone"], a["construction"] or "—", md_composants(a["composants"]) if a["composants"] else ("—" if not a["tags"] else ", ".join(a["tags"]))))
    w("")
    w("## 4. Bijoux (%d) et gemmes (%d)" % (len(bijoux), len(gemmes)))
    w("")
    w("| Bijou | id · sprite | Emplacement | Composants |")
    w("|---|---|---|---|")
    for b in bijoux:
        w("| **%s**%s | `%s`<br>`%s` | %s | %s |" % (b["nom"], " *(fortune, %s)*" % b["materiau"] if b["proto"] else "", b["id"], b["sprite"], b["emplacement"], md_composants(b["composants"])))
    w("")
    w("Une gemme se sertit dans la sertissure d'un bijou ; sa couleur est celle de son élément quand elle en a un.")
    w("")
    w("| Gemme | id · sprite | Matériau | Élément | Ce qu'elle porte |")
    w("|---|---|---|---|---|")
    for g in gemmes:
        w("| **%s** | `%s`<br>`%s` | %s | %s | %s |" % (g["nom"], g["id"], g["sprite"], g["materiau"], g["element"], ", ".join(g["effets"])))
    w("")
    w("## 5. Munitions (%d)" % len(munitions))
    w("")
    w("| Munition | id | Par pile | Composants |")
    w("|---|---|---|---|")
    for m in munitions:
        w("| **%s**%s | `%s` | %d | %s |" % (m["nom"], " *(fortune)*" if m["proto"] else "", m["id"], m["quantite"], md_composants(m["composants"]) if m["composants"] else (m["element"] or "—")))
    w("")
    w("## 6. Les composants (%d)" % len(comps))
    w("")
    w("Chaque composant est une pièce à part entière (elle se fabrique, se ramasse, se stocke) : un sprite par composant, teinté par sa matière.")
    w("")
    w("| Composant | id · sprite | Slot | Familles de matériaux | Station | Sert à |")
    w("|---|---|---|---|---|---|")
    for c in comps:
        w("| **%s** | `%s`<br>`%s` | %s | %s | %s | %s |" % (c["nom"], c["id"], c["sprite"], c["slot"], ", ".join(c["familles"]) or "—", ", ".join(s for s in c["stations"] if s) or "—", ", ".join(c["utilise_par"]) or "—"))
    w("")
    w("## 7. Livres et parchemins (%d)" % len(livres))
    w("")
    w("| Objet | id | Type | Tags |")
    w("|---|---|---|---|")
    for l in livres:
        w("| **%s** | `%s` | %s | %s |" % (l["nom"], l["id"], l["type"], ", ".join(l["tags"]) or "—"))
    w("")
    n_c = sum(len(v) for v in cons.values())
    w("## 8. Consommables (%d)" % n_c)
    w("")
    w("Une potion non identifiée se montre comme une **fiole** d'une des %d apparences : %s. Identifiée, elle prend le nom de son distillat. Les ingrédients (herbes, champignons, cultures, parties de bêtes) sont ce qu'on cueille, récolte ou dépèce." % (len(apparences), ", ".join(tr("apparence." + a, a) for a in apparences)))
    w("")
    for g, titre in groupes_c.items():
        if not cons[g]:
            continue
        w("### %s (%d)" % (titre, len(cons[g])))
        w("")
        w("| Objet | id | Tags | Élément(s) | Distillat |")
        w("|---|---|---|---|---|")
        for c in cons[g]:
            w("| **%s** | `%s` | %s | %s | %s |" % (c["nom"], c["id"], ", ".join(c["tags"]) or "—", c["wuxing"] or "—", c["distillat"] or "—"))
        w("")
    w("## 9. Les matériaux : %d matières, %d formes" % (sum(len(v) for v in cats_mat.values()), len(formes)))
    w("")
    w("Une matière brute ou transformée est un objet empilable : un sprite par **forme** (teinté par la matière) suffit — `assets/objets/matieres/<forme>.png`. Formes : %s." % ", ".join("`%s`" % f for f in formes))
    w("")
    w("| Catégorie | Matières |")
    w("|---|---|")
    for cat, noms in cats_mat.items():
        w("| **%s** (%d) | %s |" % (nom_categorie(cat), len(noms), ", ".join(sorted(noms))))
    w("")
    w("## 10. Meubles (%d) et stations portatives (%d)" % (len(meubles), len(stations)))
    w("")
    w("Un meuble se pose sur une tuile (il a une emprise et parfois une lumière) ; une station portative se porte dans le sac et se pose pour fabriquer. Les matières de recette disent de quoi ils ont l'air.")
    w("")
    w("| Meuble | id | Recette (matières) | Lumière · bloque le passage |")
    w("|---|---|---|---|")
    for m in meubles:
        fiche = meubles_def.get(m["meuble"], {})
        w("| **%s** | `%s` | %s | %s · %s |" % (m["nom"], m["id"], ", ".join("%d %s (%s)" % (n, nom_categorie(c), tr("forme." + f, f).replace("{materiau}", "").strip(" ()") or f) for c, f, n in m["materiaux_recette"]) or "—",
            fiche.get("luminosite", 0) or "—", "oui" if fiche.get("bloque_passage") else "non"))
    w("")
    w("| Station | id | Recette (matières) | Compétence |")
    w("|---|---|---|---|")
    for s in stations:
        fiche = stations_def.get(s["station"], {})
        w("| **%s** | `%s` | %s | %s |" % (s["nom"], s["id"], ", ".join("%d %s (%s)" % (n, nom_categorie(c), tr("forme." + f, f).replace("{materiau}", "").strip(" ()") or f) for c, f, n in s["materiaux_recette"]) or "—", nom_competence(fiche.get("craft_skill", "")) if fiche.get("craft_skill") else "—"))
    w("")
    w("## Liens")
    w("- [[Composants]] · [[Recettes de composants]] · [[Palette de couleurs des matériaux]] · [[Direction artistique]] · [[Potions]] · [[Nourriture]] · [[Meubles]] · [[Effets d'équipement types]]")
    w("")
    io.open(NOTE, "w", encoding="utf-8", newline="\n").write("\n".join(L))


def main():
    armes = section_armes()
    outils = section_simple("outil")
    boucliers = section_simple("bouclier")
    armures = section_simple("armure", avec_fonct=False)
    bijoux = section_simple("bijou", avec_fonct=False)
    gemmes = section_gemmes()
    munitions = section_simple("munition", avec_fonct=False)
    comps = section_composants()
    livres = []
    for t in ["manuel", "grimoire", "parchemin"]:
        for r in section_simple(t, avec_fonct=False):
            r["type"] = tr("type." + t, t)
            livres.append(r)
    groupes_c, cons = section_consommables()
    formes, cats_mat = section_materiaux()
    meubles = section_simple("meuble", avec_fonct=False)
    stations = section_simple("station", avec_fonct=False)
    ecrire_note(armes, outils, boucliers, armures, bijoux, gemmes, munitions, comps, livres, groupes_c, cons, formes, cats_mat, meubles, stations)
    total = len(armes) + len(outils) + len(boucliers) + len(armures) + len(bijoux) + len(gemmes) + len(munitions) + len(comps) + len(livres) + sum(len(v) for v in cons.values()) + len(meubles) + len(stations)
    print("liste des objets : %d armes, %d outils, %d boucliers, %d armures, %d bijoux, %d gemmes, %d munitions, %d composants, %d livres, %d consommables, %d meubles, %d stations, %d matières (%d formes) — %d objets, note écrite" % (
        len(armes), len(outils), len(boucliers), len(armures), len(bijoux), len(gemmes), len(munitions), len(comps), len(livres), sum(len(v) for v in cons.values()), len(meubles), len(stations), sum(len(v) for v in cats_mat.values()), len(formes), total))
    if "--json" in sys.argv:
        chemin = sys.argv[sys.argv.index("--json") + 1]
        io.open(chemin, "w", encoding="utf-8", newline="\n").write(json.dumps({
            "armes": armes, "outils": outils, "boucliers": boucliers, "armures": armures, "bijoux": bijoux, "gemmes": gemmes,
            "munitions": munitions, "composants": comps, "livres": livres, "groupes_consommables": groupes_c, "consommables": cons,
            "formes": formes, "materiaux": {nom_categorie(c): sorted(v) for c, v in cats_mat.items()}, "meubles": meubles, "stations": stations,
            "apparences": [tr("apparence." + a, a) for a in apparences],
        }, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
