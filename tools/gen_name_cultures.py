# -*- coding: utf-8 -*-
"""Transcrit les pools de noms des cultures (docs: Pools de noms des cultures, Culture de nommage — schéma)
en data/name_cultures/*.json, et leurs titres en clés de locale (`titre.<culture>.<gouvernance>.<genre>`).

    python tools/gen_name_cultures.py
"""
import io, json, os, re, unicodedata

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
NOTE = os.path.join(RACINE, "docs", "09 - Contenu", "Pools de noms des cultures.md")
SORTIE = os.path.join(RACINE, "godot", "data", "name_cultures")
LOCALE = os.path.join(RACINE, "godot", "locale", "fr.csv")
GOUV = ["monarchie", "republique", "theocratie", "ploutocratie", "dictature", "guilde"]
GOUV_CLE = {"monarchie": "monarchie_hereditaire", "republique": "republique", "theocratie": "theocratie", "ploutocratie": "ploutocratie", "dictature": "dictature", "guilde": "guilde_maitre"}


def slug(n):
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


def pool(txt):
    items = []
    for x in txt.split(","):
        x = x.strip().strip("*").strip()
        x = re.sub(r"\(.*?\)", "", x).replace("*", "").strip()
        if x == "" or x.lower() == "vide":
            items.append("")
        else:
            items.append(x)
    return items


cultures = {}
courante = None
for ligne in io.open(NOTE, encoding="utf-8"):
    m = re.match(r"^## (.+?)(?: — `name_order: (\w+)`)?\s*$", ligne)
    if m and not m.group(1).startswith("Liens"):
        nom = m.group(1)
        races = re.findall(r"\((.*?)\)", nom)
        courant = slug(nom.split("(")[0].split("/")[0])
        cultures[courant] = {"nom": nom.split("(")[0].strip(), "name_order": m.group(2) or "prenom_nom",
                             "race_affinity": {slug(r.strip()): 1.0 for r in (races[0].split(",") if races else ["Humain"])}, "pools": {}, "titres": {}}
        courante = courant
        continue
    if courante is None or not ligne.startswith("- `"):
        continue
    if "`titres`" in ligne:
        corps = ligne.split(":", 1)[1]
        for part in corps.split("·"):
            part = part.strip()
            part_ascii = unicodedata.normalize("NFKD", part).encode("ascii", "ignore").decode().lower()
            for g in GOUV:
                if part_ascii.startswith(g):
                    reste = part[len(g):].strip()
                    mf = [x.strip() for x in reste.split("⟋")]
                    cultures[courante]["titres"][GOUV_CLE[g]] = {"m": mf[0], "f": mf[1] if len(mf) > 1 and mf[1] else mf[0]}
        continue
    for cle, val in re.findall(r"`(\w+)` : ([^·\n]+)", ligne):
        cultures[courante]["pools"][cle] = pool(val)

# La Sino, écrite dans la note de schéma.
cultures["sino"] = {"nom": "Sino", "name_order": "nom_prenom", "race_affinity": {"humain": 1.0}, "pools": {
    "prenom_a": ["Li", "Wang", "Zh", "Xi", "Mei", "Jian", "Hu", "Chen"], "prenom_b_m": ["ang", "ong", "ing", "un"], "prenom_b_f": ["ei", "an", "ao", "ua"],
    "famille_a": ["Li", "Wang", "Zhang", "Chen", "Liu", "Yang", "Huang"], "famille_b": [""], "ville_a": ["Bei", "Nan", "Shang", "Hang", "Chang", "Guang"], "ville_b": ["jing", "hai", "zhou", "yang", "an", "sha"]},
    "titres": {"monarchie_hereditaire": {"m": "Empereur", "f": "Impératrice"}, "republique": {"m": "Chancelier", "f": "Chancelière"}, "theocratie": {"m": "Grand Prêtre", "f": "Grande Prêtresse"},
               "ploutocratie": {"m": "Grand Marchand", "f": "Grande Marchande"}, "dictature": {"m": "Généralissime", "f": "Généralissime"}, "guilde_maitre": {"m": "Grand Maître", "f": "Grande Maîtresse"}}}

lignes_locale = []
for cid, c in cultures.items():
    p = c["pools"]
    d = {"name_key": "culture.%s.name" % cid, "name_order": c["name_order"], "race_affinity": c["race_affinity"],
         "prenom_a": p.get("prenom_a", []), "prenom_b_m": p.get("prenom_b_m", p.get("prenom_b", [])), "prenom_b_f": p.get("prenom_b_f", p.get("prenom_b", [])),
         "famille_a": p.get("famille_a", []), "famille_b_m": p.get("famille_b_m", p.get("famille_b", [""])), "famille_b_f": p.get("famille_b_f", p.get("famille_b", [""])),
         "ville_a": p.get("ville_a", []), "ville_b": p.get("ville_b", []), "titres": {}}
    for gouv, mf in c["titres"].items():
        d["titres"][gouv] = {"m": "titre.%s.%s.m" % (cid, gouv), "f": "titre.%s.%s.f" % (cid, gouv)}
        lignes_locale.append("titre.%s.%s.m,%s" % (cid, gouv, mf["m"]))
        lignes_locale.append("titre.%s.%s.f,%s" % (cid, gouv, mf["f"]))
    lignes_locale.append("culture.%s.name,%s" % (cid, c["nom"]))
    for k in ["prenom_a", "prenom_b_m", "prenom_b_f", "famille_a", "ville_a", "ville_b"]:
        assert d[k], (cid, k)
    with io.open(os.path.join(SORTIE, cid + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")

s = io.open(LOCALE, encoding="utf-8").read()
debut, fin = "# --- cultures de nommage (tools/gen_name_cultures.py) ---\n", "# --- fin cultures ---\n"
bloc = debut + "".join(('%s\n' % l) if "," not in l.split(",", 1)[1] else ('%s,"%s"\n' % tuple(l.split(",", 1))) for l in lignes_locale) + fin
if debut in s:
    s = s[:s.index(debut)] + bloc + s[s.index(fin) + len(fin):]
else:
    s = s.rstrip("\n") + "\n" + bloc
io.open(LOCALE, "w", encoding="utf-8", newline="\n").write(s)
print("%d cultures -> %s" % (len(cultures), SORTIE))
