# -*- coding: utf-8 -*-
"""Les sous-dossiers de planches et leurs spritesheets de substitution (Direction artistique, designer 2026-09-06, 21 h 10 :
« fais les sous-dossiers et des spritesheets de substitution »).

    python -X utf8 tools/gen_planches_substitution.py

Crée `godot/assets/membres/<segment>/`, `godot/assets/visage/<trait>/` et, dans chacun, `00_substitution.png` : une
planche de cases de 64 × 64 (une colonne), une case par variante — la carrure pour un membre, chaque valeur du locus
pour un trait du visage (l'ordre de apparence.json). Les cases reprennent, en blanc-gris (le jeu les teinte), ce que le
paperdoll dessinait par code : un membre est une pilule de la longueur de la case, un trait est à sa place dans une boîte
de tête de 2,6 rayons. Ce sont des gabarits à remplacer, pas des dessins : le designer garde le nom `00_substitution.png`
ou le supprime quand ses propres cases arrivent (ses fichiers, numérotés, passent après lui dans l'ordre des noms — ou
avant, s'il le supprime).

Sans Pillow : un petit rastériseur (cercles, ellipses, segments épais, polygones) sur-échantillonné 4 × 4, et le PNG écrit
à la main (zlib). Rien de ce fichier n'est lu par le jeu : `Planches` lit les dossiers.
"""
import json, math, os, struct, zlib

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(RACINE, "godot", "data")
ASSETS = os.path.join(RACINE, "godot", "assets")
SS = 4   # sur-échantillonnage par côté


def lire_json(nom):
    return json.load(open(os.path.join(DATA, nom), encoding="utf-8"))


# ---------------------------------------------------------------- un rastériseur minuscule

class Toile:
    """Une case de `c` px, RGBA ; chaque forme est une fonction (x, y) -> couvert, évaluée SS × SS fois par pixel."""

    def __init__(self, c):
        self.c = c
        self.cov = [[0.0] * c for _ in range(c)]   # couverture 0..1 (alpha)
        self.val = [[1.0] * c for _ in range(c)]   # gris 0..1
        self.marques = {}   # (x, y) -> (r, g, b) : les marqueurs de couleur, poses par-dessus tout a la fin

    def forme(self, dedans, gris=1.0):
        c, n = self.c, SS
        for y in range(c):
            for x in range(c):
                k = 0
                for sy in range(n):
                    for sx in range(n):
                        if dedans(x + (sx + 0.5) / n, y + (sy + 0.5) / n):
                            k += 1
                if k:
                    a = k / float(n * n)
                    a0 = self.cov[y][x]
                    # la nouvelle forme passe par-dessus : gris mêlé selon sa couverture
                    self.val[y][x] = (self.val[y][x] * (1 - a) * a0 + gris * a) / max(1e-6, (1 - a) * a0 + a) if a0 > 0 else gris
                    self.cov[y][x] = a + a0 * (1 - a)

    def cercle(self, cx, cy, r, gris=1.0):
        self.forme(lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r, gris)

    def ellipse(self, cx, cy, rx, ry, gris=1.0):
        self.forme(lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0, gris)

    def anneau(self, cx, cy, r, ep, gris=1.0):
        self.forme(lambda x, y: (r - ep) ** 2 <= (x - cx) ** 2 + (y - cy) ** 2 <= (r + ep) ** 2, gris)

    def arc(self, cx, cy, r, ep, a0, a1, gris=1.0):
        def dedans(x, y):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if not ((r - ep) ** 2 <= d2 <= (r + ep) ** 2):
                return False
            a = math.atan2(y - cy, x - cx)
            while a < a0:
                a += 2 * math.pi
            return a <= a1
        self.forme(dedans, gris)

    def segment(self, x0, y0, x1, y1, ep, gris=1.0):
        dx, dy = x1 - x0, y1 - y0
        l2 = dx * dx + dy * dy

        def dedans(x, y):
            if l2 == 0:
                return (x - x0) ** 2 + (y - y0) ** 2 <= ep * ep
            t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / l2))
            px, py = x0 + t * dx, y0 + t * dy
            return (x - px) ** 2 + (y - py) ** 2 <= ep * ep
        self.forme(dedans, gris)

    def polygone(self, pts, gris=1.0):
        def dedans(x, y):
            ok = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi:
                    ok = not ok
                j = i
            return ok
        self.forme(dedans, gris)

    def pilule(self, cx, cy, w, h, gris=1.0):
        """Un rectangle aux bouts ronds, vertical, centré."""
        r = w / 2.0
        self.forme(lambda x, y: (abs(x - cx) <= r and cy - h / 2.0 + r <= y <= cy + h / 2.0 - r)
                   or (x - cx) ** 2 + (y - (cy - h / 2.0 + r)) ** 2 <= r * r
                   or (x - cx) ** 2 + (y - (cy + h / 2.0 - r)) ** 2 <= r * r, gris)

    def marqueur(self, x, y, hexa):
        """UN PIXEL DE COULEUR FRANCHE (designer 2026-09-09) : il dit ou va un element du visage. Le jeu le lit puis
        l EFFACE — il ne se voit jamais. Il se pose APRES le dessin, exactement sur son pixel, sans anticrenelage :
        une couleur moyennee avec du gris ne serait plus reconnaissable."""
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < self.c and 0 <= yi < self.c:
            self.marques[(xi, yi)] = (int(hexa[1:3], 16), int(hexa[3:5], 16), int(hexa[5:7], 16))

    def rgba(self):
        """LE DESSIN SEUL, sans un pixel de couleur : les points vivent dans leur propre fichier (designer
        2026-09-09, « le sprite et un autre fichier correspondant qui est juste les points »)."""
        out = []
        for y in range(self.c):
            row = []
            for x in range(self.c):
                v = int(round(255 * self.val[y][x]))
                a = int(round(255 * min(1.0, self.cov[y][x])))
                row += [v, v, v, a]
            out.append(row)
        return out

    def points(self):
        """LE CALQUE DES POINTS : transparent partout, sauf les quelques pixels de couleur. Rend None s il n y en a
        aucun — inutile d ecrire un fichier vide a cote de chaque dessin."""
        if not self.marques:
            return None
        out = []
        for y in range(self.c):
            row = []
            for x in range(self.c):
                if (x, y) in self.marques:
                    r, g, b = self.marques[(x, y)]
                    row += [r, g, b, 255]
                else:
                    row += [0, 0, 0, 0]
            out.append(row)
        return out


def ecrire_png(chemin, cases):
    c = len(cases[0])
    h = c * len(cases)
    raw = b"".join(b"\x00" + bytes(row) for case in cases for row in case)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", c, h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    open(chemin, "wb").write(png)


# ---------------------------------------------------------------- les membres : une pilule de la longueur de la case

## POSER LES CASES SANS DECALER LES INDEX (2026-09-09). `Planches` concatene les PNG d un dossier DANS L ORDRE DES
## NOMS : l index d une variante est sa place dans cette concatenation. Une planche `00_substitution.png` posee dans
## un dossier qui a deja ses cases individuelles se range entre `00_x.png` et `01_y.png` et decale TOUT ce qui suit —
## chaque visage sauvegarde change de tete, sans erreur et sans message. Le generateur regarde donc d abord :
##   · dossier VIDE (ou n ayant que l ancienne planche) : on repose la planche entiere, comme avant ;
##   · dossier DEJA GARNI de cases individuelles : on n ecrit QUE les valeurs manquantes, une par fichier, numerotees
##     a leur place — c est la convention du designer, et elle garde les index exacts.
## Rend le nombre de fichiers ecrits.
def poser(dossier, valeurs, cases, calques=None):
    existants = []
    if os.path.isdir(dossier):
        # UN CALQUE DE POINTS N EST PAS UNE CASE : il ne compte pas comme « le dossier est deja garni », et sa
        # presence ne doit pas faire croire qu une valeur a deja son dessin.
        existants = [f for f in os.listdir(dossier)
                     if f.endswith(".png") and not f.endswith(".points.png") and f != "00_substitution.png"]
    if not existants:
        ecrire_png(os.path.join(dossier, "00_substitution.png"), cases)
        if calques and any(c is not None for c in calques):
            vide = [[0, 0, 0, 0] * len(cases[0]) // 4 for _ in cases[0]]
            ecrire_png(os.path.join(dossier, "00_substitution.points.png"),
                       [c if c is not None else vide for c in calques])
        return 1
    n = 0
    for i, v in enumerate(valeurs):
        nom = "%02d_%s.png" % (i, v)
        if any(f.endswith("_%s.png" % v) for f in existants):
            continue
        ecrire_png(os.path.join(dossier, nom), [cases[i]])
        if calques and calques[i] is not None:
            ecrire_png(os.path.join(dossier, "%02d_%s.points.png" % (i, v)), [calques[i]])
        n += 1
    return n


def planches_membres(c, rig, facteurs):
    carrures = lire_json("apparence.json")["loci"]
    ordre_carrure = next(l["valeurs"] for l in carrures if l["id"] == "carrure")
    segments = {}
    for nom, s in rig["segments"].items():
        base = nom
        for suf in ("_G", "_D"):
            if base.endswith(suf):
                base = base[: -len(suf)]
        if base == "tete":
            continue   # la tête est un trait du visage (visage/tete)
        segments.setdefault(base, (float(s["longueur"]), float(s["largeur"])))
    for base, (lo, la) in segments.items():
        cases = []
        for carrure in ordre_carrure:
            f = float(facteurs["carrure"].get(carrure, 1.0))
            t = Toile(c)
            w = min(c - 2.0, c * (la * f) / lo)   # la case fait la longueur du segment
            t.pilule(c / 2.0, c / 2.0, max(4.0, w), c - 1.0, 0.92)
            t.pilule(c / 2.0, c / 2.0, max(2.0, w - 4.0), c - 5.0, 1.0)   # un liseré : la pilule se lit une fois teintée
            cases.append(t.rgba())
        # UN MEMBRE N EST PAS UN VISAGE : son dossier ne porte qu UN dessin (l index y est la carrure, et
        # `posmod` la ramene a la seule case presente). On n y pose donc la planche des cinq carrures QUE si le
        # dossier est vide — y ajouter des cases decalerait ce que le designer a mis.
        dossier_m = os.path.join(ASSETS, "membres", base)
        if os.path.isdir(dossier_m) and [f for f in os.listdir(dossier_m) if f.endswith(".png") and not f.endswith(".points.png")]:
            print("  membres/%-11s deja garni : on ne touche a rien" % base)
            continue
        ecrire_png(os.path.join(dossier_m, "00_substitution.png"), cases)
        print("  membres/%-11s %d variante(s) (carrure), pilule %.0f × %d" % (base, len(cases), la, lo))


# ---------------------------------------------------------------- le visage : la boîte de tête, le trait à sa place

def planches_visage(c, app, facteurs):
    boite = float(lire_json("styles.json").get("planches", {}).get("visage_boite", 2.6))
    r = c / boite          # le rayon de la tête, en pixels de case
    cx = cy = c / 2.0      # le centre de la tête
    haut = lambda k: cy - r * k   # k rayons vers le haut
    droite = lambda k: cx + r * k

    # LES ELEMENTS DESSINES COMME UNE PIECE (designer 2026-09-09). Une piece est UN oeil, UNE oreille, UN nez :
    # dessinee au centre de sa case, avec son marqueur au centre, elle est ensuite posee par le jeu sur CHAQUE ancre
    # que la tete declare. Un seul dessin sert donc aux deux yeux, et une tete peut les ecarter comme elle veut.
    # Les grands traits (cheveux, barbe, machoire) restent des visages entiers : ils s etendent sur tout le crane et
    # n ont pas d ancre unique.
    PIECES = ("yeux", "oreilles", "nez", "bouche", "sourcils", "pommettes")
    # LES ANCRES PROPRES A UNE FORME DE TETE, en rayons depuis le centre de la case (x vers la droite, y vers le
    # bas). Elles REMPLACENT les ancres par defaut pour cette forme-la : c est ici qu une tete a museau descend sa
    # bouche au bout du museau et qu une tete difforme desaligne ses yeux — le jeu, lui, ne connait aucun de ces mots.
    FORMES = {
        "museau":     {"yeux": [(-0.36, -0.24), (0.36, -0.24)], "nez": [(0.0, 0.40)], "bouche": [(0.0, 0.82)]},
        "plaque":     {"yeux": [(-0.55, -0.05), (0.55, -0.05)], "bouche": [(0.0, 0.60)]},
        "ecailleuse": {"yeux": [(-0.62, -0.28), (0.62, -0.28)], "bouche": [(0.0, 0.55)], "oreilles": [(-1.02, 0.15), (1.02, 0.15)]},
        "difforme":   {"yeux": [(-0.52, -0.34), (0.28, -0.02)], "nez": [(0.10, 0.10)], "bouche": [(0.14, 0.58)], "oreilles": [(-0.95, -0.18), (0.88, 0.28)]},
        "cornue":     {"yeux": [(-0.44, -0.28), (0.44, -0.28)], "bouche": [(0.0, 0.55)]},
    }

    def marquer_tete(t, valeur):
        """Les marqueurs d une case de TETE : la ou vont les autres elements, sur CETTE forme-la."""
        table = lire_json("styles.json").get("planches", {})
        couleurs = table.get("marqueurs", {})
        ancres = table.get("ancres", {})
        propre = FORMES.get(valeur, {})
        for element, hexa in couleurs.items():
            if element.startswith("_"):
                continue
            points = propre.get(element, ancres.get(element, []))
            for a in points:
                t.marqueur(cx + float(a[0]) * r, cy + float(a[1]) * r, str(hexa))

    def case(trait, valeur, piece=False):
        t = Toile(c)
        ecart = 0.0 if piece else 0.42 * r
        if trait == "tete":
            f = float(facteurs["tete"].get(valeur, 1.0))
            if valeur == "ronde":
                t.cercle(cx, cy, r)
            elif valeur == "ovale":
                t.ellipse(cx, cy, r * 0.9, r * f)
            elif valeur == "carree":
                t.pilule(cx, cy, r * 1.9, r * 2.0 * f)
            elif valeur == "allongee":
                t.ellipse(cx, cy, r * 0.82, r * f)
            elif valeur == "en_coeur":
                t.cercle(cx, cy - r * 0.1, r)
                t.polygone([(droite(-0.75), cy + r * 0.35), (droite(0.75), cy + r * 0.35), (cx, cy + r * 1.1)])
            # LES CINQ FORMES DES RACES DU 2026-09-09. Sans branche a elles, elles sortaient VIDES — une case
            # blanche que le jeu dessinait consciencieusement. Chacune est aussi la demonstration des marqueurs :
            # le museau porte sa bouche au bout, les plaques ecartent les yeux, le difforme les desaligne.
            elif valeur == "museau":
                t.cercle(cx, cy - r * 0.15, r * 0.92)
                t.polygone([(droite(-0.42), cy + r * 0.05), (droite(0.42), cy + r * 0.05), (droite(0.26), cy + r * 1.0), (droite(-0.26), cy + r * 1.0)])
                t.cercle(cx, cy + r * 0.95, r * 0.28)
            elif valeur == "plaque":
                t.pilule(cx, cy, r * 1.8, r * 1.95)
                t.segment(droite(-0.8), haut(0.35), droite(0.8), haut(0.35), r * 0.06, 0.55)
                t.segment(droite(-0.8), cy + r * 0.3, droite(0.8), cy + r * 0.3, r * 0.06, 0.55)
            elif valeur == "ecailleuse":
                t.ellipse(cx, cy, r * 1.02, r * 0.94)
                for k_e in range(3):
                    t.arc(cx, cy + r * (0.15 * k_e - 0.1), r * (0.35 + 0.22 * k_e), r * 0.045, math.pi * 1.15, math.pi * 1.85, 0.6)
            elif valeur == "difforme":
                t.cercle(cx - r * 0.08, cy - r * 0.05, r * 0.95)
                t.cercle(cx + r * 0.42, cy + r * 0.28, r * 0.48)
                t.cercle(cx - r * 0.35, cy - r * 0.5, r * 0.3)
            elif valeur == "cornue":
                t.cercle(cx, cy, r * 0.96)
                for cote_c in (-1, 1):
                    t.segment(cx + r * 0.6 * cote_c, haut(0.62), cx + r * 1.05 * cote_c, haut(1.35), r * 0.11)
        elif trait == "yeux":
            for cote in ((1,) if piece else (-1, 1)):
                ox, oy = cx + ecart * cote, (cy if piece else haut(0.15))
                if valeur == "grands":
                    t.cercle(ox, oy, r * 0.2)
                elif valeur == "en_amande":
                    t.anneau(ox, oy, r * 0.2, r * 0.05)
                elif valeur == "tombants":
                    t.segment(ox - r * 0.14, oy, ox + r * 0.14, oy + r * 0.12, r * 0.05)
                elif valeur == "fentes":
                    t.segment(ox - r * 0.16, oy, ox + r * 0.16, oy, r * 0.05)
                else:
                    t.cercle(ox, oy, r * 0.12)
        elif trait == "nez":
            hx, hy = cx, (cy - r * 0.18 if piece else haut(0.05))
            if valeur == "fin":
                t.segment(hx, hy, hx, hy + r * 0.3, r * 0.03)
            elif valeur == "busque":
                t.segment(hx, hy - r * 0.1, hx + r * 0.08, hy + r * 0.15, r * 0.05)
                t.segment(hx + r * 0.08, hy + r * 0.15, hx, hy + r * 0.4, r * 0.05)
            elif valeur == "crochu":
                t.segment(hx, hy, hx + r * 0.12, hy + r * 0.35, r * 0.045)
            elif valeur == "plat":
                t.segment(hx - r * 0.1, hy, hx + r * 0.1, hy, r * 0.045)
            else:
                t.segment(hx, hy, hx, hy + r * 0.35, r * 0.045)
        elif trait == "bouche":
            by = (cy if piece else cy + r * 0.5)
            demi = r * (0.3 if valeur == "large" else 0.18)
            if valeur == "boudeuse":
                t.arc(cx, by + r * 0.24, r * 0.3, r * 0.045, math.pi * 1.2, math.pi * 1.8)
            elif valeur == "sourire":
                t.arc(cx, by - r * 0.2, r * 0.32, r * 0.045, math.pi * 0.15, math.pi * 0.85)
            else:
                t.segment(cx - demi, by, cx + demi, by, r * 0.045)
        elif trait == "cheveux":
            if valeur == "crete":
                t.segment(cx, haut(0.9), cx, haut(1.5), r * 0.2)
            elif valeur != "chauve":
                t.arc(cx, cy, r * 0.94, r * 0.17, math.pi * 1.06, math.pi * 1.94)
                if valeur == "longs":
                    for cote in (-1, 1):
                        t.segment(cx + r * 0.85 * cote, cy, cx + r * 0.85 * cote, cy + r * 1.5, r * 0.15)
                elif valeur == "queue":
                    t.segment(cx, cy + r * 0.6, cx, cy + r * 1.8, r * 0.125)
                elif valeur == "chignon":
                    t.cercle(cx, haut(1.05), r * 0.42)
                elif valeur == "tresses":
                    for cote in (-1, 1):
                        t.segment(cx + r * 0.8 * cote, haut(0.2), cx + r * 1.1 * cote, cy + r * 1.6, r * 0.11)
        elif trait == "sourcils":
            if valeur != "aucun":
                for cote in ((1,) if piece else (-1, 1)):
                    ox, oy = cx + ecart * cote, (cy if piece else haut(0.42))
                    t.segment(ox - r * 0.16, oy, ox + r * 0.16, oy, r * (0.08 if valeur == "epais" else 0.04))
        elif trait == "barbe":
            lg = float(facteurs["barbe"].get(valeur, 0.0)) / 8.0 * r   # en unités de rig, la tête fait 8 : ramené au rayon
            if lg > 0:
                t.polygone([(droite(-0.8), cy + r * 0.1), (droite(0.8), cy + r * 0.1), (droite(0.35), cy + r + lg), (droite(-0.35), cy + r + lg)])
        elif trait == "oreilles":
            lg = float(facteurs["oreilles"].get(valeur, 0.0)) / 8.0 * r
            for cote in ((1,) if piece else (-1, 1)):
                bx = (cx if piece else cx + r * 0.9 * cote)
                if lg > 0:
                    t.polygone([(bx, cy + r * 0.2), (bx, cy - r * 0.2), (bx + lg * cote, cy - lg * 0.6)])
                else:
                    t.cercle(bx, cy, r * 0.22)
        elif trait == "machoire":
            lg = {"fine": 0.42, "carree": 0.66, "lourde": 0.80}.get(valeur, 0.55) * r
            t.segment(cx - lg, cy + r * 0.55, cx + lg, cy + r * 0.55, r * 0.035)
        elif trait == "menton":
            if valeur == "pointu":
                t.polygone([(droite(-0.2), cy + r * 0.8), (droite(0.2), cy + r * 0.8), (cx, cy + r * 1.1)])
            elif valeur == "fendu":
                t.segment(cx, cy + r * 0.78, cx, cy + r * 0.95, r * 0.04)
        elif trait == "pommettes":
            if valeur in ("hautes", "saillantes"):
                for cote in ((1,) if piece else (-1, 1)):
                    ox = (cx if piece else cx + r * 0.62 * cote)
                    oy = cy if piece else (haut(0.05) if valeur == "hautes" else cy + r * 0.02)
                    t.segment(ox, oy - r * 0.12, ox, oy + r * 0.12, r * (0.05 if valeur == "saillantes" else 0.03))
        elif trait == "implantation":
            if valeur == "en_pointe":
                t.polygone([(droite(-0.22), haut(0.72)), (droite(0.22), haut(0.72)), (cx, haut(0.42))])
            elif valeur == "degarnie":
                for cote in (-1, 1):
                    t.cercle(cx + r * 0.6 * cote, haut(0.62), r * 0.2, 0.75)
        elif trait == "paupieres":
            for cote in (-1, 1):
                ox = cx + ecart * cote
                if valeur == "lourdes":
                    t.segment(ox - r * 0.2, haut(0.30), ox + r * 0.2, haut(0.30), r * 0.055)
                elif valeur == "plissees":
                    t.arc(ox, haut(0.33), r * 0.2, r * 0.03, math.pi * 1.1, math.pi * 1.9)
        elif trait == "marque":
            if valeur == "cicatrice":
                t.segment(droite(0.5), haut(0.5), droite(0.25), cy + r * 0.45, r * 0.04)
            elif valeur == "tatouage":
                t.anneau(droite(-0.45), haut(0.05), r * 0.24, r * 0.04)
        # LE MARQUEUR DE LA CASE. Une TETE porte ceux des autres elements ; une PIECE porte le sien, au centre —
        # c est lui que le jeu fera tomber sur chaque ancre.
        if trait == "tete":
            marquer_tete(t, valeur)
        elif piece:
            hexa = lire_json("styles.json").get("planches", {}).get("marqueurs", {}).get(trait, "")
            if hexa:
                t.marqueur(cx, cy, str(hexa))
        return t

    for locus in app["loci"]:
        if locus.get("universel", False):
            continue   # la carrure et la taille ne sont pas des traits du visage
        trait = locus["id"]
        dossier = os.path.join(ASSETS, "visage", trait)
        toiles = [case(trait, v, trait in PIECES) for v in locus["valeurs"]]
        cases = [t.rgba() for t in toiles]
        calques = [t.points() for t in toiles]
        n = poser(dossier, locus["valeurs"], cases, calques)
        print("  visage/%-13s %d variante(s), %d ecrite(s) : %s" % (trait, len(cases), n, ", ".join(locus["valeurs"])))


def main():
    c = int(lire_json("styles.json").get("planches", {}).get("case", 64))
    app = lire_json("apparence.json")
    rig = lire_json(os.path.join("rigs", "humanoide.json"))
    print("planches de substitution (cases de %d) :" % c)
    planches_membres(c, rig, app["facteurs"])
    planches_visage(c, app, app["facteurs"])
    lisez = os.path.join(ASSETS, "LISEZ-MOI.md")
    if not os.path.exists(lisez):
        open(lisez, "w", encoding="utf-8").write(
            "# Les planches de sprites\n\n"
            "Un dossier = une planche (Direction artistique, 2026-09-06). Chaque PNG y est une case de 64 × 64, ou une planche de cases lues de haut en bas puis de gauche à droite ; les fichiers se lisent dans l'ordre de leurs noms (numérote-les). Le jeu assemble le dossier au premier usage.\n\n"
            "- `membres/<segment>/` : la case fait la LONGUEUR du segment, centrée sur son axe, le dessin du bas (l'articulation) vers le haut (le bout) ; la gauche est le miroir de la droite ; une case par carrure (mince, moyenne, large, trapue, athletique) ; en blanc-gris, le jeu teinte.\n"
            "- `visage/<trait>/` : la case est la TÊTE ENTIÈRE (un carré de 2,6 rayons de tête, centré), le trait à sa place ; une case par valeur du locus, dans l'ordre de `data/apparence.json` ; en blanc-gris, le jeu teinte (peau, cheveux, encre).\n"
            "- `objets/<id>/` : la case de l'icône ; la variante visuelle de l'objet choisit la case. `objets/<id>.png` (un seul fichier) reste valable.\n\n"
            "`00_substitution.png` est un gabarit généré par `tools/gen_planches_substitution.py` : remplace-le par tes cases, ou supprime-le. Un fichier dont la taille n'est pas un multiple de 64 est ignoré (`tools/verif_sprites.py` le signale).\n")


if __name__ == "__main__":
    main()
