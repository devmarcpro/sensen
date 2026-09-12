# -*- coding: utf-8 -*-
"""LES SIGNAUX DE L EVENTBUS ONT-ILS UN EMETTEUR ET UN AUDITEUR ? (ordre de travail 40/43, palier 10)

    python tools/verif_signaux.py [--gel]

POURQUOI UN OUTIL ET PAS UN NETTOYAGE. La file demandait de « supprimer les signaux sans auditeur ». C est le mauvais
geste : **un signal emis sans auditeur n est pas un defaut, c est un point d extension.** Le jeu s en sert comme
d une facade — `item_sold` attend les quetes, `dungeon_cleared` attend le jalon, `raid_resolved` attend le journal du
territoire. Les supprimer retirerait l API au moment ou elle va servir.

CE QUI EST UN DEFAUT, C EST QU ON NE LE SACHE PAS. Un signal MORT DES DEUX COTES est du bruit pur (`locale_changed`
l etait, retire le 2026-09-12). Un signal ECOUTE MAIS JAMAIS EMIS est pire : c est une fonctionnalite qui ne se
declenchera jamais, et rien ne le dit. Cet outil gele donc l etat connu, avec une raison par signal, et signale le
suivant le jour ou il apparait — comme `verif_reglages.py` et `verif_doc_code.py` le font pour les reglages et les
citations. *Un manque ecrit vaut mieux qu un manque tu.*

CE QU IL NE PEUT PAS VOIR, ET IL LE DIT : un auditeur DYNAMIQUE (`Callable` monte a l execution, connexion via une
variable) est invisible a une lecture de texte. Deux des douze en ont un, par les bulles d onboarding — d ou le gel
plutot qu un echec, et d ou la colonne « raison ».
"""
import argparse
import glob
import io
import os
import re
import sys

RACINE = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BUS = os.path.join(RACINE, "godot", "autoload", "event_bus.gd")
GEL = os.path.join(RACINE, "tools", "verif_signaux_baseline.txt")

# CE QU ON SAIT DE CHAQUE SIGNAL SANS AUDITEUR, ET POURQUOI IL RESTE. Un signal absent de cette table et sans
# auditeur fait echouer l outil : c est le treizieme, celui qu on veut voir arriver.
RAISONS = {
    "skill_xp_gained": "facade : le client l affichera par competence quand la feuille montrera les gains",
    "skill_level_up": "facade : le palier 9 l affichera en grand (le jeu montre ce qu il sait)",
    "item_sold": "facade : les quetes de marchand et le journal du commerce l attendent",
    "dungeon_cleared": "traite au palier 4 par l autre bout (le jalon de sortie) — le signal reste l API",
    "quest_completed": "facade : il n y a pas encore de systeme de quetes",
    "creature_recruited": "auditeur DYNAMIQUE par les bulles d onboarding — invisible a une lecture de texte",
    "cell_claimed": "auditeur DYNAMIQUE par les bulles d onboarding — invisible a une lecture de texte",
    "cell_role_changed": "facade : l ecran de gestion lit l etat, il n a pas besoin du signal",
    "raid_resolved": "facade : le journal du territoire l attend",
    "leadership_changed": "facade : les familles et la succession l attendent",
    "village_conquered": "facade : la conquete est lue par l etat, le signal reste l API",
    "explosion": "facade : le client secoue l ecran a partir des degats, pas du signal",
}


def signaux():
    res = []
    for l in io.open(BUS, encoding="utf-8"):
        m = re.match(r"^signal\s+(\w+)", l)
        if m:
            res.append(m.group(1))
    return res


def source():
    t = []
    for motif in ("godot/**/*.gd", "godot/**/*.tscn"):
        for f in glob.glob(os.path.join(RACINE, motif), recursive=True):
            if os.path.basename(f) == "event_bus.gd":
                continue
            t.append(io.open(f, encoding="utf-8", errors="replace").read())
    return "\n".join(t)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--gel", action="store_true", help="reecrire le gel a l etat courant")
    args = ap.parse_args()

    src = source()
    morts, sans_auditeur, sans_emetteur, inconnus = [], [], [], []
    sig = signaux()
    for s in sig:
        # UN EMETTEUR se reconnait a trois formes : `EventBus.emettre(&"s"` (la voie du depot), `EventBus.s.emit(`
        # et l ancien `emit_signal("s"`. Un AUDITEUR, a `EventBus.s.connect(` ou `connect("s"`.
        emis = ('&"%s"' % s) in src or (".%s.emit" % s) in src or ('emit_signal("%s"' % s) in src
        ecoute = (".%s.connect" % s) in src or ('connect("%s"' % s) in src
        if not emis and not ecoute:
            morts.append(s)
        elif ecoute and not emis:
            sans_emetteur.append(s)
        elif emis and not ecoute:
            sans_auditeur.append(s)
            if s not in RAISONS:
                inconnus.append(s)

    print("%d signaux declares dans event_bus.gd" % len(sig))
    print("  emis ET ecoutes            : %d" % (len(sig) - len(morts) - len(sans_auditeur) - len(sans_emetteur)))
    print("  emis, jamais ecoutes       : %d (facades ou auditeurs dynamiques)" % len(sans_auditeur))
    for s in sans_auditeur:
        print("      %-22s %s" % (s, RAISONS.get(s, "!! SANS RAISON ECRITE")))
    if morts:
        print("  MORTS DES DEUX COTES       : %s" % ", ".join(morts))
    if sans_emetteur:
        print("  ECOUTES, JAMAIS EMIS       : %s" % ", ".join(sans_emetteur))

    gel = ""
    if os.path.exists(GEL):
        gel = io.open(GEL, encoding="utf-8").read()
    courant = "morts=%s\nsans_auditeur=%s\nsans_emetteur=%s\n" % (
        ",".join(sorted(morts)), ",".join(sorted(sans_auditeur)), ",".join(sorted(sans_emetteur)))
    if args.gel:
        io.open(GEL, "w", encoding="utf-8", newline="").write(courant)
        print("gel reecrit")
        return 0

    faute = 0
    # UN SIGNAL ECOUTE MAIS JAMAIS EMIS est le pire des trois : une fonctionnalite qui ne se declenchera jamais, et
    # rien ne le dit. Il fait echouer, toujours.
    if sans_emetteur:
        print("ECHEC : %d signal(aux) ont un auditeur et aucun emetteur — la fonctionnalite ne partira jamais." % len(sans_emetteur))
        faute = 1
    if morts:
        print("ECHEC : %d signal(aux) mort(s) des deux cotes — a supprimer d event_bus.gd." % len(morts))
        faute = 1
    if inconnus:
        print("ECHEC : %d signal(aux) sans auditeur ET sans raison ecrite dans RAISONS : %s" % (len(inconnus), ", ".join(inconnus)))
        print("        Ajoute la raison dans tools/verif_signaux.py, ou donne-lui un auditeur.")
        faute = 1
    if gel and gel != courant and not faute:
        print("L etat a change depuis le gel (sans faute) — relance avec --gel si c est voulu :")
        for a, b in zip(gel.split("\n"), courant.split("\n")):
            if a != b:
                print("    gel : %s\n    ici : %s" % (a, b))
    if not faute:
        print("signaux : rien a signaler")
    return faute


if __name__ == "__main__":
    sys.exit(main())
