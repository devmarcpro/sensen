# -*- coding: utf-8 -*-
"""FAIRE ENTRER LES SPRITES QUE LE DESIGNER DEPOSE A LA RACINE (designer 2026-09-10 : « il fallait que tu organises
les fichiers toi-meme quand je fais ca »).

    python tools/entrer_sprites.py [--remplacer] [--source <dossier>]

LE DESIGNER DEPOSE, L OUTIL RANGE. Il pose ses PNG a la racine du depot — `tete poisson.png`, `yeux poisson.png`,
`casque plaque.png` — et cet outil les met a leur place, leur donne leur valeur de locus, leur clef de traduction et
leur calque de points. Sa racine est son depot d arrivee : **on COPIE, on ne deplace jamais**, et elle est de toute
facon ignoree par git (`/*.png`).

CE QUI FAIT TOUT LE TRAVAIL, ET C EST LE DESIGNER QUI LE DONNE SANS LE SAVOIR : **chaque element est dessine A SA
PLACE SUR SA TETE.** Il ne dessine pas ses yeux au centre d une case vide, il les dessine la ou ils vont. On n a
donc rien a deviner : on LIT la position de chaque element dans son propre fichier, et on l ecrit comme ancre de la
tete du meme jeu. La bouche du poisson tombe exactement ou il l a mise.

DEUX TRAITEMENTS, SELON QU UN ELEMENT SE REPETE OU NON :
  · un element REPETE (les yeux, les oreilles — deux ancres) est dessine par PAIRE : on le coupe, on garde celui de
    gauche, on le translate au centre de sa case et on l y marque. Le jeu le pose sur chaque ancre et RETOURNE celui
    de droite ;
  · un element UNIQUE (le nez, la bouche, la coiffe) ne bouge pas d un pixel, et son point va la ou le dessin est
    deja. Un nez de poisson fait de DEUX narines reste un seul nez : deux trous d un meme dessin ne sont pas deux
    nez, et son point tombe entre eux.
Dans les deux cas, sur une tete non marquee, le rendu est identique a ce qu il etait — c est ce qui rend l entree
sans risque.

CE QU IL NE SAIT PAS PLACER, IL LE DIT ET N Y TOUCHE PAS. Une planche d equipement est indexee par CONSTRUCTION
(matelasse, cuir, mailles, ecailles, plaque, tissu, rituel) : `casque.png` tout court ne dit pas laquelle, et
choisir a la place du designer mettrait un heaume d acier sur la ligne du matelasse sans que personne ne s en
apercoive. Il faut `casque plaque.png`. **Un outil qui devine est un outil qui ment un jour.**

TOUT SE DEDUIT DES DONNEES : les traits du visage viennent des locus de `apparence.json`, les segments de
`assets/membres/`, les slots et les constructions de `assets/equipement/` et de `styles.json`. Ajouter un locus ou
un slot suffit a le rendre acceptable ici, sans toucher a cet outil.
"""
import argparse
import collections
import io
import json
import os
import re
import shutil
import sys
import unicodedata

from PIL import Image

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ASSETS = os.path.join(RACINE, "godot", "assets")
DONNEES = os.path.join(RACINE, "godot", "data")
LOCALES = [("fr", os.path.join(RACINE, "godot", "locale", "fr.csv")),
           ("en", os.path.join(RACINE, "godot", "locale", "en.csv"))]

# CEUX DONT LA TETE PORTE DEUX ANCRES : ils se dessinent par paire et se coupent. Les autres sont uniques.
REPETES = {"yeux", "oreilles", "sourcils", "pommettes"}


def lire(nom):
    return json.load(io.open(os.path.join(DONNEES, nom), encoding="utf-8"),
                     object_pairs_hook=collections.OrderedDict)


def ecrire(nom, d):
    io.open(os.path.join(DONNEES, nom), "w", encoding="utf-8", newline="").write(
        json.dumps(d, ensure_ascii=False, indent=2) + "\n")


def slug(n):
    n = unicodedata.normalize("NFKD", n).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "_", n).strip("_")


# ---------------------------------------------------------------- ce que le depot sait accueillir, lu des donnees
STYLES = lire("styles.json")["planches"]
CASE = int(STYLES["case"])
RAYON = CASE / float(STYLES["visage_boite"])
COULEURS = STYLES["marqueurs"]["couleurs"]
TAILLE_MARQUEUR = int(STYLES["marqueurs"].get("taille", 2))
CONSTRUCTIONS = list(STYLES.get("constructions", []))
APPARENCE = lire("apparence.json")

TRAITS = [str(l["id"]) for l in APPARENCE["loci"]
          if os.path.isdir(os.path.join(ASSETS, "visage", str(l["id"])))]
SEGMENTS = sorted(d for d in os.listdir(os.path.join(ASSETS, "membres"))
                  if os.path.isdir(os.path.join(ASSETS, "membres", d)))
SLOTS = sorted(d for d in os.listdir(os.path.join(ASSETS, "equipement"))
               if os.path.isdir(os.path.join(ASSETS, "equipement", d)))


def amas(im):
    """LES AMAS DE PIXELS OPAQUES, par voisinage a huit directions, rendus par leur centre.

    LE SEUIL DE FUSION EST SERRE (deux pixels) ET IL DOIT L ETRE. Une pupille et son reflet se touchent ; deux yeux,
    jamais. A un sixieme de case, les deux yeux du jeu « etoile », distants de neuf pixels, fusionnaient en un seul —
    et la planche devenait un oeil unique au milieu du front, sans erreur et sans message."""
    px = im.load()
    vus, res = set(), []
    for y in range(CASE):
        for x in range(CASE):
            if px[x, y][3] < 8 or (x, y) in vus:
                continue
            file, pts = [(x, y)], []
            vus.add((x, y))
            while file:
                a, b = file.pop()
                pts.append((a, b))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        v = (a + dx, b + dy)
                        if 0 <= v[0] < CASE and 0 <= v[1] < CASE and v not in vus and px[v[0], v[1]][3] >= 8:
                            vus.add(v)
                            file.append(v)
            res.append(pts)
    change = True
    while change and len(res) > 1:
        change = False
        for i in range(len(res)):
            for j in range(i + 1, len(res)):
                if min(abs(a[0] - b[0]) + abs(a[1] - b[1]) for a in res[i] for b in res[j]) <= 2:
                    res[i] += res[j]
                    del res[j]
                    change = True
                    break
            if change:
                break
    res.sort(key=lambda p: sum(q[0] for q in p) / len(p))
    return [(sum(q[0] for q in p) / len(p) + 0.5, sum(q[1] for q in p) / len(p) + 0.5, p) for p in res]


def poser_marqueur(im, x, y, hexa):
    rgb = (int(hexa[1:3], 16), int(hexa[3:5], 16), int(hexa[5:7], 16), 255)
    x0, y0 = int(round(x - TAILLE_MARQUEUR / 2.0)), int(round(y - TAILLE_MARQUEUR / 2.0))
    for dy in range(TAILLE_MARQUEUR):
        for dx in range(TAILLE_MARQUEUR):
            if 0 <= x0 + dx < CASE and 0 <= y0 + dy < CASE:
                im.putpixel((x0 + dx, y0 + dy), rgb)


def verifier(chemin):
    """CE QU UNE PLANCHE DOIT ETRE, AVANT D ENTRER : la bonne taille, et EN NUANCES DE GRIS. Un sprite peint ne se
    laisse pas teindre — c est tout le sujet du 2026-09-10 — et une couleur franche dans un dessin peut en plus se
    faire prendre pour un marqueur. On refuse plutot que de convertir : convertir un dessin sans le dire, c est
    decider a la place de celui qui l a fait."""
    im = Image.open(chemin).convert("RGBA")
    if im.size[0] % CASE or im.size[1] % CASE or im.size[0] == 0:
        return None, "%d x %d n est pas un multiple de %d" % (im.size[0], im.size[1], CASE)
    colores = sum(1 for q in im.getdata() if q[3] >= 8 and not (q[0] == q[1] == q[2]))
    if colores:
        return None, "%d pixel(s) en couleur — une planche se dessine en nuances de gris, le jeu la teinte" % colores
    return im, ""


def locus_de(trait):
    for l in APPARENCE["loci"]:
        if str(l["id"]) == trait:
            return l
    return None


def cle_locale(valeur, faits):
    """LA CLEF DE TRADUCTION D UNE VALEUR NEUVE. On ecrit le slug tel quel dans les deux langues : c est un mot que
    le designer relira et corrigera d un coup d oeil, la ou une clef ABSENTE ne se voit qu a l ecran, en jeu, sous
    la forme d une valeur brute au milieu de la creation de personnage."""
    for _lg, chemin in LOCALES:
        s = io.open(chemin, encoding="utf-8").read()
        cle = "ui.apparence.val." + valeur
        if (cle + ",") in s:
            continue
        lignes = s.split("\n")
        dernier = max(i for i, l in enumerate(lignes) if l.startswith("ui.apparence.val."))
        lignes.insert(dernier + 1, '%s,"%s"' % (cle, valeur))
        io.open(chemin, "w", encoding="utf-8", newline="").write("\n".join(lignes))
        faits.append("locale %s : %s" % (os.path.basename(chemin), cle))


# ---------------------------------------------------------------- lire un nom de fichier
def analyser(nom):
    """« tete poisson.png », « poisson tete.png », « casque plaque.png », « torse.png » — l ordre des deux mots est
    libre parce que le designer ecrit dans les deux sens (« insectoide tete » et « tete etoile » coexistent a la
    racine). Rend (genre, cible, valeur) ou (None, raison, None)."""
    mots = [slug(m) for m in re.split(r"[ _\-]+", nom[:-4].strip()) if m]
    if not mots:
        return None, "nom vide", None
    if len(mots) == 1:
        m = mots[0]
        if m in SEGMENTS:
            return "membre", m, ""
        if m in SLOTS:
            return None, "un equipement doit dire sa CONSTRUCTION (%s) : « %s <construction>.png »" % (
                ", ".join(CONSTRUCTIONS), m), None
        return None, "« %s » n est ni un segment ni un slot connu" % m, None
    # deux mots ou plus : le premier reconnu decide, le reste est la valeur
    for i, m in enumerate(mots):
        reste = "_".join(mots[:i] + mots[i + 1:])
        if m in TRAITS:
            return "visage", m, reste
        if m in SLOTS:
            if reste not in CONSTRUCTIONS:
                return None, "« %s » n est pas une construction (%s)" % (reste, ", ".join(CONSTRUCTIONS)), None
            return "equipement", m, reste
        if m in SEGMENTS:
            return "membre", m, reste
    return None, "aucun mot reconnu dans « %s » (traits : %s ; slots : %s ; segments : %s)" % (
        nom, ", ".join(TRAITS), ", ".join(SLOTS), ", ".join(SEGMENTS)), None


# ---------------------------------------------------------------- entrer
def entrer_visage(jeux, remplacer, faits, refus):
    """UN JEU DE VISAGE ENTIER D UN COUP : les elements d abord — ils disent ou ils vont —, la tete ensuite, qui
    recoit leurs positions comme ancres. C est pour cela qu on regroupe par VALEUR et non par fichier : une tete
    seule ne saurait rien ancrer, et un oeil seul ne saurait pas quelle tete il complete."""
    for valeur, elems in sorted(jeux.items()):
        ancres = {}
        for trait in sorted(elems.keys(), key=lambda t: (t == "tete", t)):   # la tete en dernier
            source = elems[trait]
            im, souci = verifier(source)
            if im is None:
                refus.append("%s : %s" % (os.path.basename(source), souci))
                continue
            locus = locus_de(trait)
            if valeur not in locus["valeurs"]:
                locus["valeurs"].append(valeur)   # A LA FIN : l index d une variante deja enregistree ne bouge pas
            i = locus["valeurs"].index(valeur)
            cible = os.path.join(ASSETS, "visage", trait, "%02d_%s.png" % (i, valeur))
            if os.path.exists(cible) and not remplacer:
                refus.append("%s : %s existe deja (--remplacer pour ecraser)" % (
                    os.path.basename(source), os.path.relpath(cible, RACINE).replace(os.sep, "/")))
                continue
            groupes = amas(im)
            pts_im = Image.new("RGBA", (CASE, CASE), (0, 0, 0, 0))
            if trait == "tete":
                # LA TETE PORTE LES ANCRES QU ON VIENT DE LIRE DANS SES PROPRES ELEMENTS.
                shutil.copyfile(source, cible)
                for autre, liste in ancres.items():
                    for (x, y) in liste:
                        poser_marqueur(pts_im, x, y, COULEURS[autre][0])
                detail = "ancre " + ", ".join(sorted(ancres.keys())) if ancres else "sans ancre (aucun element fourni)"
            elif trait in REPETES and len(groupes) >= 2:
                ancres[trait] = [(g[0], g[1]) for g in groupes[:2]]
                gx, gy, pts = groupes[0]
                piece = Image.new("RGBA", (CASE, CASE), (0, 0, 0, 0))
                dx, dy = int(round(CASE * 0.5 - gx)), int(round(CASE * 0.5 - gy))
                for (x, y) in pts:
                    if 0 <= x + dx < CASE and 0 <= y + dy < CASE:
                        piece.putpixel((x + dx, y + dy), im.getpixel((x, y)))
                piece.save(cible)
                poser_marqueur(pts_im, CASE * 0.5, CASE * 0.5, COULEURS[trait][0])
                detail = "paire coupee, ancres " + str([(round(a[0], 1), round(a[1], 1)) for a in ancres[trait]])
            else:
                tous = [q for g in groupes for q in g[2]]
                if not tous:
                    ancres[trait] = [(CASE * 0.5, CASE * 0.5)]
                    cx = cy = CASE * 0.5
                else:
                    cx = sum(q[0] for q in tous) / len(tous) + 0.5
                    cy = sum(q[1] for q in tous) / len(tous) + 0.5
                    ancres[trait] = [(cx, cy)]
                shutil.copyfile(source, cible)
                poser_marqueur(pts_im, cx, cy, COULEURS[trait][0])
                detail = "unique, ancre (%.1f, %.1f)" % (cx, cy)
            pts_im.save(cible[:-4] + ".points.png")
            faits.append("%-26s -> %-44s %s" % (os.path.basename(source),
                                                os.path.relpath(cible, RACINE).replace(os.sep, "/"), detail))
        # LA TETE APPREND SES NOUVELLES ANCRES MEME QUAND ELLE N ENTRE PAS. Le designer depose par morceaux : une
        # bouche aujourd hui, des oreilles demain. Si la tete de ce jeu est deja en place, elle est SAUTEE — et sans
        # cette reprise, l element neuf se poserait sur l ancre PAR DEFAUT au lieu de la sienne, c est-a-dire
        # ailleurs que la ou il a ete dessine. On relit donc son calque et on y remplace les ancres des traits qui
        # viennent d entrer, en gardant toutes les autres.
        if ancres and "tete" not in elems:
            _reprendre_ancres_tete(valeur, ancres, faits)
        cle_locale(valeur, faits)


def _reprendre_ancres_tete(valeur, ancres, faits):
    locus = locus_de("tete")
    if locus is None or valeur not in locus["valeurs"]:
        return
    tete = os.path.join(ASSETS, "visage", "tete", "%02d_%s.png" % (locus["valeurs"].index(valeur), valeur))
    if not os.path.exists(tete):
        return
    calque = tete[:-4] + ".points.png"
    im = Image.open(calque).convert("RGBA") if os.path.exists(calque) else Image.new("RGBA", (CASE, CASE), (0, 0, 0, 0))
    # on efface les marqueurs des traits repris, on ne touche pas aux autres
    a_effacer = set()
    for trait in ancres:
        for h in COULEURS.get(trait, []):
            a_effacer.add((int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)))
    for y in range(CASE):
        for x in range(CASE):
            q = im.getpixel((x, y))
            if q[3] >= 8 and q[:3] in a_effacer:
                im.putpixel((x, y), (0, 0, 0, 0))
    for trait, liste in ancres.items():
        for (x, y) in liste:
            poser_marqueur(im, x, y, COULEURS[trait][0])
    im.save(calque)
    faits.append("%-26s    ancres reprises sur %s : %s" % ("", os.path.relpath(calque, RACINE).replace(os.sep, "/"),
                                                           ", ".join(sorted(ancres.keys()))))


def entrer_equipement(fichiers, remplacer, faits, refus):
    """UNE PLANCHE D EQUIPEMENT EST INDEXEE PAR CONSTRUCTION, et un dossier ne peut pas melanger la planche de
    substitution (sept cases d un coup) avec des fichiers individuels : `Planches` les concatene dans l ordre des
    NOMS, et `00_substitution.png` decalerait tout ce qui le suit. On la retire donc, et le generateur reecrira les
    constructions manquantes une par une."""
    for (slot, construction, source) in fichiers:
        im, souci = verifier(source)
        if im is None:
            refus.append("%s : %s" % (os.path.basename(source), souci))
            continue
        dossier = os.path.join(ASSETS, "equipement", slot)
        i = CONSTRUCTIONS.index(construction)
        cible = os.path.join(dossier, "%02d_%s.png" % (i, construction))
        if os.path.exists(cible) and not remplacer:
            refus.append("%s : %s existe deja (--remplacer)" % (os.path.basename(source),
                         os.path.relpath(cible, RACINE).replace(os.sep, "/")))
            continue
        subst = os.path.join(dossier, "00_substitution.png")
        if os.path.exists(subst):
            os.remove(subst)
            for suf in (".import",):
                if os.path.exists(subst + suf):
                    os.remove(subst + suf)
            faits.append("equipement/%s : la planche de substitution retiree (elle decalait les index)" % slot)
        shutil.copyfile(source, cible)
        faits.append("%-26s -> %-44s construction %s (index %d)" % (
            os.path.basename(source), os.path.relpath(cible, RACINE).replace(os.sep, "/"), construction, i))


def entrer_membre(fichiers, remplacer, faits, refus):
    """UN MEMBRE N A QU UN DESSIN (l index de son dossier est la CARRURE, et `posmod` la ramene a la seule case
    presente) : on remplace donc le fichier existant plutot que d en ajouter un a cote."""
    for (segment, _valeur, source) in fichiers:
        im, souci = verifier(source)
        if im is None:
            refus.append("%s : %s" % (os.path.basename(source), souci))
            continue
        dossier = os.path.join(ASSETS, "membres", segment)
        existants = sorted(f for f in os.listdir(dossier) if f.endswith(".png") and not f.endswith(".points.png"))
        cible = os.path.join(dossier, existants[0] if existants else "00_%s.png" % segment)
        if existants and not remplacer:
            refus.append("%s : %s existe deja (--remplacer)" % (os.path.basename(source),
                         os.path.relpath(cible, RACINE).replace(os.sep, "/")))
            continue
        shutil.copyfile(source, cible)
        faits.append("%-26s -> %-44s (le calque de points est conserve)" % (
            os.path.basename(source), os.path.relpath(cible, RACINE).replace(os.sep, "/")))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--remplacer", action="store_true", help="ecraser une case qui existe deja")
    ap.add_argument("--source", default=RACINE, help="ou chercher les PNG (defaut : la racine du depot)")
    args = ap.parse_args()

    fichiers = sorted(f for f in os.listdir(args.source)
                      if f.lower().endswith(".png") and os.path.isfile(os.path.join(args.source, f)))
    if not fichiers:
        print("aucun PNG dans %s" % args.source)
        return 0
    jeux, equip, membres, refus, faits = collections.defaultdict(dict), [], [], [], []
    for f in fichiers:
        genre, cible, valeur = analyser(f)
        chemin = os.path.join(args.source, f)
        if genre is None:
            refus.append("%s : %s" % (f, cible))
        elif genre == "visage":
            jeux[valeur][cible] = chemin
        elif genre == "equipement":
            equip.append((cible, valeur, chemin))
        elif genre == "membre":
            membres.append((cible, valeur, chemin))

    entrer_visage(jeux, args.remplacer, faits, refus)
    entrer_equipement(equip, args.remplacer, faits, refus)
    entrer_membre(membres, args.remplacer, faits, refus)
    if jeux:
        ecrire("apparence.json", APPARENCE)

    print("ENTREE DES SPRITES — %d fichier(s) lus dans %s" % (len(fichiers), args.source))
    for l in faits:
        print("  · " + l)
    if refus:
        print("  laisses de cote (%d) :" % len(refus))
        for l in refus:
            print("    ! " + l)
    if faits:
        print("  À FAIRE ENSUITE : `godot --headless --path godot --import`, puis la galerie et la suite.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
