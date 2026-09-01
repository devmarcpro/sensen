#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère le gabarit d'encrage papier des sprites — un PDF A4 à imprimer.

Les cases ne sont pas des carrés arbitraires : chacune porte le squelette réel
d'un segment, lu dans `godot/data/rigs/*.json`. Proportions, longueurs et
positions d'articulation viennent des données — jamais recopiées ici.

    python tools/gen_gabarit_sprites.py [chemin/sortie.pdf]

Sortie par défaut : docs/09 - Contenu/gabarit-encrage-sprites.pdf
"""

import io
import json
import os
import sys

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RIGS = os.path.join(RACINE, "godot", "data", "rigs")
SORTIE = os.path.join(RACINE, "docs", "09 - Contenu", "gabarit-encrage-sprites.pdf")

# ---------------------------------------------------------------- géométrie

MM = 72.0 / 25.4                      # millimètre → point PDF
A4 = (210.0 * MM, 297.0 * MM)
MARGE = 13.0 * MM
ECHELLE = 5.4 * MM                    # millimètres par unité de rig
RESPIR = 9.0 * MM                     # marge de débordement autour de la boîte
GOUT = 4.0 * MM                       # gouttière entre cases
HAUT_ENTETE = 22.0 * MM
HAUT_PIED = 9.0 * MM

# Couleurs réservées d'ancrage (`Squelette modulaire et points d'attache`).
# Imprimées en clair : le trait de l'artiste passe par-dessus, l'import les relit.
ANCRE_RVB = {
    "cou": (1.00, 1.00, 0.00), "epaule": (0.00, 1.00, 0.50),
    "coude": (0.00, 0.88, 0.50), "poignet": (0.00, 0.75, 0.50),
    "prise": (1.00, 0.00, 0.75), "hanche": (0.00, 0.75, 1.00),
    "genou": (0.00, 0.63, 1.00), "cheville": (0.00, 0.50, 1.00),
    "dos": (1.00, 0.50, 0.00), "aile": (0.50, 0.00, 1.00),
    "queue": (1.00, 0.00, 0.00), "monture": (0.00, 1.00, 0.75),
}


def couleur_ancre(nom):
    base = nom.split("_")[0].rstrip("GD0123456789")
    for cle, rvb in ANCRE_RVB.items():
        if base.startswith(cle) or nom.startswith(cle):
            return rvb
    return (0.45, 0.45, 0.45)


# ---------------------------------------------------------------- écriture PDF

class Pdf:
    """Écrivain PDF minimal : lignes, rectangles, cercles, texte. Aucune dépendance."""

    def __init__(self):
        self.objets = [None]          # 1-indexé
        self.pages = []
        self.flux = []

    def _ajouter(self, corps):
        self.objets.append(corps)
        return len(self.objets) - 1

    def page(self, contenu):
        self.flux.append(contenu)

    def ecrire(self, chemin):
        polices = {
            "F1": b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>",
            "F2": b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>",
            "F3": b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>",
        }
        ref_polices = {n: self._ajouter(c) for n, c in polices.items()}
        res = "<< /Font << " + " ".join(
            "/%s %d 0 R" % (n, r) for n, r in sorted(ref_polices.items())) + " >> >>"
        id_res = self._ajouter(res.encode("latin-1"))

        id_pages = self._ajouter(b"PLACEHOLDER")
        ids_page = []
        for contenu in self.flux:
            data = contenu.encode("latin-1")
            id_flux = self._ajouter(
                b"<< /Length %d >>\nstream\n" % len(data) + data + b"\nendstream")
            corps = ("<< /Type /Page /Parent %d 0 R /MediaBox [0 0 %.2f %.2f] "
                     "/Resources %d 0 R /Contents %d 0 R >>"
                     % (id_pages, A4[0], A4[1], id_res, id_flux))
            ids_page.append(self._ajouter(corps.encode("latin-1")))

        self.objets[id_pages] = ("<< /Type /Pages /Count %d /Kids [%s] >>" % (
            len(ids_page), " ".join("%d 0 R" % i for i in ids_page))).encode("latin-1")
        id_cat = self._ajouter(("<< /Type /Catalog /Pages %d 0 R >>" % id_pages).encode("latin-1"))

        out = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
        decalages = [0]
        for i in range(1, len(self.objets)):
            decalages.append(len(out))
            out += b"%d 0 obj\n" % i + self.objets[i] + b"\nendobj\n"
        pos_xref = len(out)
        out += b"xref\n0 %d\n" % len(self.objets)
        out += b"0000000000 65535 f \n"
        for d in decalages[1:]:
            out += b"%010d 00000 n \n" % d
        out += (b"trailer\n<< /Size %d /Root %d 0 R >>\nstartxref\n%d\n%%%%EOF\n"
                % (len(self.objets), id_cat, pos_xref))
        with open(chemin, "wb") as f:
            f.write(bytes(out))


# ---------------------------------------------------------------- primitives

def esc(s):
    s = s.replace("\\", r"\\").replace("(", r"\(").replace(")", r"\)")
    return s.encode("cp1252", "replace").decode("latin-1")


class Toile:
    def __init__(self):
        self.o = []

    def trait(self, g):
        self.o.append("%.3f %.3f %.3f RG" % g)

    def remplir(self, g):
        self.o.append("%.3f %.3f %.3f rg" % g)

    def epaisseur(self, w):
        self.o.append("%.2f w" % w)

    def pointille(self, motif=None):
        self.o.append("[%s] 0 d" % ("" if not motif else " ".join("%.1f" % v for v in motif)))

    def ligne(self, x1, y1, x2, y2):
        self.o.append("%.2f %.2f m %.2f %.2f l S" % (x1, y1, x2, y2))

    def rect(self, x, y, w, h, plein=False):
        self.o.append("%.2f %.2f %.2f %.2f re %s" % (x, y, w, h, "f" if plein else "S"))

    def cercle(self, cx, cy, r, plein=False):
        k = r * 0.5523
        self.o.append(
            "%.2f %.2f m %.2f %.2f %.2f %.2f %.2f %.2f c "
            "%.2f %.2f %.2f %.2f %.2f %.2f c %.2f %.2f %.2f %.2f %.2f %.2f c "
            "%.2f %.2f %.2f %.2f %.2f %.2f c %s"
            % (cx + r, cy, cx + r, cy + k, cx + k, cy + r, cx, cy + r,
               cx - k, cy + r, cx - r, cy + k, cx - r, cy,
               cx - r, cy - k, cx - k, cy - r, cx, cy - r,
               cx + k, cy - r, cx + r, cy - k, cx + r, cy,
               "f" if plein else "S"))

    def texte(self, x, y, s, police="F1", taille=8, g=(0, 0, 0)):
        self.o.append("BT %.3f %.3f %.3f rg /%s %.1f Tf %.2f %.2f Td (%s) Tj ET"
                      % (g[0], g[1], g[2], police, taille, x, y, esc(s)))

    def texte_centre(self, cx, y, s, police="F1", taille=8, g=(0, 0, 0)):
        # Helvetica : largeur moyenne ~0.52 em, suffisant pour centrer un label court.
        self.texte(cx - 0.26 * taille * len(s), y, s, police, taille, g)

    def rendu(self):
        return "\n".join(self.o)


# ---------------------------------------------------------------- habillage de page

def reperes(t, titre, sous_titre, page_id):
    """Croix de calage aux quatre coins + carré d'orientation + en-tête."""
    t.trait((0, 0, 0))
    t.epaisseur(0.6)
    t.pointille()
    b = 8.0 * MM
    r = 3.5 * MM
    for x, y in ((b, b), (A4[0] - b, b), (b, A4[1] - b), (A4[0] - b, A4[1] - b)):
        t.ligne(x - r, y, x + r, y)
        t.ligne(x, y - r, x, y + r)
        t.cercle(x, y, r * 0.45)
    # Carré plein en haut à gauche : donne le sens de la feuille au redressement.
    t.remplir((0, 0, 0))
    t.rect(b - 1.6 * MM, A4[1] - b - 1.6 * MM + 6 * MM, 3.2 * MM, 3.2 * MM, plein=True)

    t.texte(MARGE, A4[1] - MARGE - 3 * MM, titre, "F2", 13)
    t.texte(MARGE, A4[1] - MARGE - 9.5 * MM, sous_titre, "F3", 8.5, (0.35, 0.35, 0.35))
    t.trait((0.75, 0.75, 0.75))
    t.epaisseur(0.5)
    t.ligne(MARGE, A4[1] - MARGE - 13 * MM, A4[0] - MARGE, A4[1] - MARGE - 13 * MM)
    t.texte(MARGE, 6.0 * MM, "Sensen — gabarit d'encrage    " + page_id,
            "F1", 7, (0.55, 0.55, 0.55))
    t.texte(A4[0] - MARGE - 46 * MM, 6.0 * MM,
            "encre noire · scan 600 dpi · niveaux de gris", "F1", 7, (0.55, 0.55, 0.55))


# ---------------------------------------------------------------- une case

def boite_segment(seg):
    """Boîte englobante en unités de rig, ancrages compris. x = longueur, y = largeur."""
    lo, la = float(seg["longueur"]), float(seg["largeur"])
    xs, ys = [0.0, lo], [-la / 2.0, la / 2.0]
    for pos in (seg.get("ancrages") or {}).values():
        xs.append(float(pos[0]))
        ys.append(float(pos[1]))
    return min(xs), max(xs), min(ys), max(ys)


def case(t, x, y, w, h, item):
    """Dessine une case : cadre de découpe, boîte du segment, articulations, légende."""
    nom, seg, note = item["nom"], item["seg"], item.get("note", "")

    # Cadre de découpe.
    t.pointille()
    t.trait((0.0, 0.0, 0.0))
    t.epaisseur(0.7)
    t.rect(x, y, w, h)
    # Onglet d'angle : repère de rotation par case, lu au découpage automatique.
    t.epaisseur(0.7)
    t.ligne(x, y + h - 4 * MM, x + 4 * MM, y + h)

    x0, x1, y0, y1 = boite_segment(seg)
    bw = (y1 - y0) * ECHELLE
    bh = (x1 - x0) * ECHELLE
    cx = x + w / 2.0
    # La boîte s'appuie sur le bas de la case, au-dessus du bandeau de légende.
    by = y + HAUT_PIED + (h - HAUT_PIED - bh) / 2.0

    def pt(ax, ay):
        return (cx + (float(ay) - (y0 + y1) / 2.0) * ECHELLE,
                by + (float(ax) - x0) * ECHELLE)

    # Boîte englobante du segment — la silhouette doit tenir autour, pas dedans.
    t.pointille([2.2, 2.2])
    t.trait((0.72, 0.72, 0.72))
    t.epaisseur(0.5)
    t.rect(cx - bw / 2.0, by, bw, bh)

    # Axe du segment : de l'ancrage parent (0,0) à la pointe (longueur,0).
    t.pointille([1.0, 2.0])
    t.trait((0.82, 0.82, 0.82))
    ax0, ay0 = pt(0.0, 0.0)
    ax1, ay1 = pt(float(seg["longueur"]), 0.0)
    t.ligne(ax0, ay0, ax1, ay1)
    t.pointille()

    # Articulations : l'ancrage parent en bas, les ancrages portés à leur place.
    ancres = []
    if seg.get("parent"):
        ancres.append((seg.get("ancrage") or "parent", (0.0, 0.0), True))
    for a, pos in sorted((seg.get("ancrages") or {}).items()):
        ancres.append((a, (float(pos[0]), float(pos[1])), False))

    for a, (px, py), entrant in ancres:
        gx, gy = pt(px, py)
        g = couleur_ancre(a)
        t.trait(g)
        t.epaisseur(0.9)
        t.cercle(gx, gy, 1.7 * MM)
        t.epaisseur(0.6)
        t.ligne(gx - 2.6 * MM, gy, gx + 2.6 * MM, gy)
        t.ligne(gx, gy - 2.6 * MM, gx, gy + 2.6 * MM)
        if entrant:                              # flèche : d'où vient le parent
            t.ligne(gx, gy - 2.6 * MM, gx - 1.0 * MM, gy - 1.4 * MM)
            t.ligne(gx, gy - 2.6 * MM, gx + 1.0 * MM, gy - 1.4 * MM)
        t.texte(gx + 3.0 * MM, gy - 1.0 * MM, a, "F1", 5.6, tuple(v * 0.75 for v in g))

    # Bandeau de légende.
    t.trait((0.85, 0.85, 0.85))
    t.epaisseur(0.4)
    t.ligne(x + 2 * MM, y + HAUT_PIED - 1.5 * MM, x + w - 2 * MM, y + HAUT_PIED - 1.5 * MM)
    def tenir(s, taille):
        """Tronque une legende a la largeur de la case — sinon elle deborde du cadre."""
        maxi = max(4, int((w - 5 * MM) / (0.52 * taille)))
        return s if len(s) <= maxi else s[:maxi - 1] + "…"

    t.texte(x + 2.5 * MM, y + 4.2 * MM, tenir(nom, 7.5), "F2", 7.5)
    detail = "%g x %g u" % (float(seg["longueur"]), float(seg["largeur"]))
    if note:
        detail += "  ·  " + note
    t.texte(x + 2.5 * MM, y + 1.4 * MM, tenir(detail, 5.8), "F1", 5.8, (0.45, 0.45, 0.45))


def taille_case(seg):
    """La case d'un segment : sa boîte plus la respiration de débordement."""
    x0, x1, y0, y1 = boite_segment(seg)
    return (max((y1 - y0) * ECHELLE + 2 * RESPIR, 34 * MM),
            max((x1 - x0) * ECHELLE + 2 * RESPIR + HAUT_PIED, 38 * MM))


def grille(pdf, titre, sous_titre, items, page_id, mini=(0.0, 0.0)):
    """Pagine en rangées : chaque case garde sa vraie taille, la rangée prend la plus haute.

    Une case uniforme gâcherait la moitié de la feuille — un pied fait 4 unités, un
    torse 14. Le rangement par étagères garde les proportions vraies ET la feuille pleine.
    """
    utile_w = A4[0] - 2 * MARGE
    utile_h = A4[1] - 2 * MARGE - HAUT_ENTETE - 4 * MM

    mesures = []
    for it in items:
        w, h = taille_case(it["seg"])
        mesures.append((it, max(w, mini[0]), max(h, mini[1])))

    rangees, courante, larg = [], [], 0.0
    for m in mesures:
        ajout = m[1] if not courante else GOUT + m[1]
        if courante and larg + ajout > utile_w:
            rangees.append(courante)
            courante, larg = [m], m[1]
        else:
            courante.append(m)
            larg += ajout
    if courante:
        rangees.append(courante)

    pages, lot, haut = [], [], 0.0
    for r in rangees:
        hr = max(m[2] for m in r)
        ajout = hr if not lot else GOUT + hr
        if lot and haut + ajout > utile_h:
            pages.append(lot)
            lot, haut = [r], hr
        else:
            lot.append(r)
            haut += ajout
    if lot:
        pages.append(lot)

    for n, lot in enumerate(pages, 1):
        t = Toile()
        suffixe = page_id if len(pages) == 1 else "%s (%d/%d)" % (page_id, n, len(pages))
        reperes(t, titre, sous_titre, suffixe)
        y = A4[1] - MARGE - HAUT_ENTETE
        for r in lot:
            hr = max(m[2] for m in r)
            y -= hr
            x = MARGE
            for it, w, h in r:
                case(t, x, y + (hr - h), w, h, it)
                x += w + GOUT
            y -= GOUT
        pdf.page(t.rendu())


# ---------------------------------------------------------------- pages libres

def page_libre(pdf, titre, sous_titre, page_id, cols, lignes, etiquettes=None):
    """Cases vides — armes, ornements, calligraphie : rien à articuler."""
    t = Toile()
    reperes(t, titre, sous_titre, page_id)
    utile_w = A4[0] - 2 * MARGE
    utile_h = A4[1] - 2 * MARGE - HAUT_ENTETE - 4 * MM
    cw = (utile_w - (cols - 1) * GOUT) / cols
    ch = (utile_h - (lignes - 1) * GOUT) / lignes
    haut = A4[1] - MARGE - HAUT_ENTETE
    for i in range(cols * lignes):
        c, l = i % cols, i // cols
        x = MARGE + c * (cw + GOUT)
        y = haut - (l + 1) * ch - l * GOUT
        t.pointille()
        t.trait((0, 0, 0))
        t.epaisseur(0.7)
        t.rect(x, y, cw, ch)
        t.ligne(x, y + ch - 4 * MM, x + 4 * MM, y + ch)
        t.trait((0.88, 0.88, 0.88))
        t.epaisseur(0.4)
        t.ligne(x + cw / 2, y + HAUT_PIED, x + cw / 2, y + ch - 3 * MM)
        t.ligne(x + 3 * MM, y + HAUT_PIED + (ch - HAUT_PIED) / 2,
                x + cw - 3 * MM, y + HAUT_PIED + (ch - HAUT_PIED) / 2)
        t.trait((0.85, 0.85, 0.85))
        t.ligne(x + 2 * MM, y + HAUT_PIED - 1.5 * MM, x + cw - 2 * MM, y + HAUT_PIED - 1.5 * MM)
        lab = (etiquettes[i] if etiquettes and i < len(etiquettes) else "")
        t.texte(x + 2.5 * MM, y + 4.2 * MM, lab or "nom : ", "F2" if lab else "F1", 7.5,
                (0, 0, 0) if lab else (0.6, 0.6, 0.6))
        t.texte(x + 2.5 * MM, y + 1.4 * MM, "teinte : données  ·  encre noire seule",
                "F1", 5.8, (0.55, 0.55, 0.55))
    pdf.page(t.rendu())


def page_mode_emploi(pdf, stats):
    t = Toile()
    reperes(t, "Gabarit d'encrage — mode d'emploi",
            "Dessiner les sprites de Sensen sur papier, les scanner, les rendre au pipeline paperdoll.",
            "p. 1")
    y = A4[1] - MARGE - HAUT_ENTETE - 2 * MM

    def titre(s):
        nonlocal y
        y -= 7.5 * MM
        t.texte(MARGE, y, s, "F2", 10)
        y -= 1.5 * MM

    def para(s, indent=0.0, police="F1", g=(0.2, 0.2, 0.2)):
        nonlocal y
        y -= 4.6 * MM
        t.texte(MARGE + indent, y, s, police, 8.2, g)

    titre("1. La règle qui commande tout : dessiner en noir, jamais en couleur")
    para("La teinte n'appartient pas au sprite. Elle vient des données — matériau, espèce, génome, élément.")
    para("Le scan sert de MASQUE : alpha = 1 - luminance, le moteur teinte par-dessus. Un feutre de couleur")
    para("casse la palette et rend le sprite inutilisable. Encre noire pigmentée, 0,3 à 0,5 mm, sur blanc.")

    titre("2. Le squelette est déjà imprimé — ne le déplacez pas")
    para("Chaque case porte les articulations du segment à leur position réelle, lue dans data/rigs/*.json :")
    para("cercle + croix = un ancrage, la couleur est celle de reserved_colors (cou jaune, coude vert, ...).", 4 * MM)
    para("Le cercle fléché du bas = l'ancrage PARENT : le point par lequel le segment se raccorde.", 4 * MM)
    para("Le rectangle pointillé = la boîte du segment à l'échelle. Le trait peut la déborder (cheveux,", 4 * MM)
    para("épaulière, drapé) : c'est pour ça que la case est plus grande. Les proportions, elles, sont vraies.", 4 * MM)

    titre("3. Le miroir : un seul côté à dessiner")
    para("Les segments _D sont le miroir horizontal des _G. Le gabarit ne propose que le côté gauche.")
    para("Une pièce volontairement asymétrique (une seule épaulière, le bras au bouclier) se dessine à part.")

    titre("4. Scanner")
    para("600 dpi, NIVEAUX DE GRIS (pas noir et blanc pur : les gris donnent l'antialiasing du trait).")
    para("Scanner à plat, jamais de photo — la distorsion et l'ombre de la main coûtent plus cher à corriger.")
    para("Les quatre croix d'angle servent au redressement ; le carré plein en haut à gauche donne le sens.")
    para("L'onglet coupé en haut à gauche de chaque case donne son orientation au découpage automatique.")

    titre("5. Ce qui ne se dessine PAS sur papier")
    para("Le terrain : il n'a pas de textures, il a un shader de grain calculé qui suit le relief. Le remplacer")
    para("par des scans coûterait de la mémoire et le raccord des tuiles, pour perdre l'inclinaison iso.")
    para("Les motifs à répéter sans couture, et l'interface fonctionnelle (jauges, cadres, boutons).")

    titre("6. Ordre de travail conseillé")
    para("Commencer par la page « cases libres » — un sceau, un cartouche, une calligraphie de titre.")
    para("Une soirée, risque nul, et vous saurez tout de suite si le rendu vous plaît. Les 130 segments")
    para("du paperdoll ne se sortent qu'après : un sprite scanné se corrige au feutre, pas en changeant")
    para("un chiffre. Figer le rig en code d'abord, encrer ensuite.")

    y -= 9 * MM
    t.trait((0.8, 0.8, 0.8))
    t.epaisseur(0.5)
    t.ligne(MARGE, y, A4[0] - MARGE, y)
    y -= 5.5 * MM
    t.texte(MARGE, y, "Contenu de ce gabarit", "F2", 9)
    for s in stats:
        y -= 4.4 * MM
        t.texte(MARGE + 4 * MM, y, s, "F1", 8, (0.25, 0.25, 0.25))

    y -= 8 * MM
    t.texte(MARGE, y, "Légende des ancrages (couleurs réservées)", "F2", 9)
    y -= 6 * MM
    x = MARGE
    for nom in ("cou", "epaule", "coude", "poignet", "prise", "hanche", "genou", "cheville", "dos", "aile"):
        g = ANCRE_RVB[nom]
        t.trait(g)
        t.epaisseur(0.9)
        t.cercle(x + 2 * MM, y + 1 * MM, 1.5 * MM)
        t.texte(x + 5 * MM, y, nom, "F1", 7, (0.3, 0.3, 0.3))
        x += 18.5 * MM
        if x > A4[0] - MARGE - 18 * MM:
            x = MARGE
            y -= 6 * MM

    pdf.page(t.rendu())


# ---------------------------------------------------------------- assemblage

def charger(nom):
    with io.open(os.path.join(RIGS, nom + ".json"), encoding="utf-8") as f:
        return json.load(f)


def uniques(rig_nom):
    """Les segments d'un rig, cote droit retire (miroir) — l'ordre du fichier est conserve."""
    rig = charger(rig_nom)
    segs = rig["segments"]
    out = []
    for nom, seg in segs.items():
        jumeau_G = None
        if nom.endswith("_D"):
            jumeau_G = nom[:-2] + "_G"
        elif nom.endswith("D"):
            jumeau_G = nom[:-1] + "G"
        if jumeau_G and jumeau_G in segs:
            continue                       # le cote droit vient du miroir
        base, note = nom, ""
        if nom.endswith("_G") and nom[:-2] + "_D" in segs:
            base, note = nom[:-2], "miroir -> _D"
        elif nom.endswith("G") and nom[:-1] + "D" in segs:
            base, note = nom[:-1], "miroir -> ...D"
        out.append({"nom": base, "seg": seg, "note": note})
    return out


def main():
    sortie = sys.argv[1] if len(sys.argv) > 1 else SORTIE
    pdf = Pdf()

    humain = uniques("humanoide")
    quad = uniques("quadrupede")
    autres = []
    for r in ("volant", "serpentin", "arachnide", "amorphe"):
        for it in uniques(r):
            it = dict(it)
            it["nom"] = "%s · %s" % (r, it["nom"])
            it["note"] = (it["note"] + "  " if it["note"] else "") + "rig %s" % r
            autres.append(it)

    # Les 5 constructions d'armure repeignent les mêmes segments (la forme est la
    # construction, la teinte est le matériau) : on redonne les segments couverts.
    couverts = [it for it in humain if it["nom"] in
                ("tete", "torse", "bras_haut", "bras_bas", "main",
                 "jambe_haut", "jambe_bas", "pied")]
    constructions = ("Matelassé", "Cuir", "Mailles", "Écailles", "Plaque")

    stats = [
        "p. 2  — humanoïde : %d segments uniques (les _D viennent du miroir)" % len(humain),
        "p. 3  — têtes : 3 vues (face, profil, dos), la seule exception du rig",
        "p. 4+ — armure : %d segments x %d constructions = %d sprites, toute l'armure du jeu"
        % (len(couverts), len(constructions), len(couverts) * len(constructions)),
        "puis  — quadrupède, volant, serpentin, arachnide, amorphe",
        "fin   — cases libres : armes, sceaux, cartouches, calligraphie d'interface",
    ]
    page_mode_emploi(pdf, stats)

    grille(pdf, "Humanoïde — bibliothèque de base",
           "14 segments, 8 à dessiner : les _D sont le miroir des _G. Une passe pour TOUS les humains du jeu.",
           humain, "p. 2 · rig humanoïde")

    tete = charger("humanoide")["segments"]["tete"]
    vues = [{"nom": "tête — %s" % v, "seg": tete,
             "note": "vue %s" % v} for v in ("face", "profil", "dos")] * 2
    grille(pdf, "Humanoïde — têtes, les trois vues",
           "Un visage ne se relit pas par superposition : 3 vues par tête, sélectionnées par le facing. Seul segment concerné.",
           vues, "p. 3 · têtes", mini=(56 * MM, 62 * MM))

    for c in constructions:
        grille(pdf, "Armure — construction : %s" % c,
               "La construction donne la forme, le matériau donne la teinte. Encre noire : les centaines de "
               "variantes viennent du remapping de palette.",
               [dict(it, note=("%s · " % c) + (it["note"] or "")) for it in couverts],
               "armure · %s" % c)

    grille(pdf, "Quadrupède — bibliothèque de base",
           "Un torse portant 4 chaînes epaule -> pied. Les côtés D et les pattes AR viennent du miroir et de la répétition.",
           quad, "rig quadrupède")

    grille(pdf, "Volant, serpentin, arachnide, amorphe",
           "Les quatre autres templates de squelette. Mêmes règles : encre noire, articulations imprimées, miroir pour le côté droit.",
           autres, "autres rigs")

    page_libre(pdf, "Cases libres — armes et objets tenus",
               "Une arme = un sprite, accroché à l'ancrage « prise » (rose). Dessiner la poignée sur le repère central.",
               "cases libres · armes", 3, 3)
    page_libre(pdf, "Cases libres — sceaux, cartouches, calligraphie",
               "Le meilleur rapport identité/effort : l'ornement d'encre. Commencer ici avant les 130 segments.",
               "cases libres · ornements", 2, 3)

    d = os.path.dirname(sortie)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    pdf.ecrire(sortie)
    print("Gabarit écrit : %s (%d pages)" % (sortie, len(pdf.flux)))


if __name__ == "__main__":
    main()
