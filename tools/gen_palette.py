# -*- coding: utf-8 -*-
"""Transcrit la palette des matériaux (docs: Palette de couleurs des matériaux, F.1.1) en JSON.

    python tools/gen_palette.py

Un matériau = un hex unique ; le loader vérifie les doublons. La teinte d'une pièce
d'équipement (paperdoll) vient de là : « la construction est la forme, le matériau la teinte ».
"""
import io, json, os, re, unicodedata

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
NOTE = os.path.join(RACINE, "docs", "09 - Contenu", "Palette de couleurs des matériaux.md")
SORTIE = os.path.join(RACINE, "godot", "data", "palette_materiaux.json")


def slug(n):
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


s = io.open(NOTE, encoding="utf-8").read()
pal = {}
for nom, hexa in re.findall(r"([A-ZÉÈ][\wéèêàâîôûç' \-]*?) (#[0-9A-F]{6})", s):
    pal[slug(nom)] = {"nom": nom.strip(), "hex": hexa}
hexes = [v["hex"] for v in pal.values()]
assert len(hexes) == len(set(hexes)), "doublon de couleur dans la palette"
d = {"_doc": "Palette des matériaux (docs: Palette de couleurs des matériaux, F.1.1) — transcrite par tools/gen_palette.py. Un hex unique par matériau ; la teinte d'une pièce d'équipement vient d'ici."}
d.update(pal)
with io.open(SORTIE, "w", encoding="utf-8", newline="\n") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("%d matériaux -> %s" % (len(pal), SORTIE))
