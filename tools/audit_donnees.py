# -*- coding: utf-8 -*-
"""Audit des donnees : ce qui est reference mais introuvable, et ce qui existe sans source.
    python tools/audit_donnees.py
Complementaire de check_vault.py (le coffre) et de la validation au boot (les schemas) : celle-ci
verifie les liens ENTRE catalogues, que GameData ne connait pas — une famille de materiaux sans
recette qui la produit, une depouille qui ne correspond a aucun objet, un habitat sans meuble.
Sortie non nulle si un probleme est trouve."""
import sys
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

for k in sorted(probs):
    print("\n== %s (%d)" % (k, len(probs[k])))
    for v in probs[k][:12]:
        print("   ", v)
if not probs:
    print("audit des donnees : rien a signaler")
sys.exit(1 if probs else 0)
