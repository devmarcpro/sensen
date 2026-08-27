# -*- coding: utf-8 -*-
"""Écrit les catalogues de la progression (docs: Compétences — liste, Double niveau combat et
général, Races, Classes, Talents de race/classe, Astrologie — cycle sexagésimal, Potentiel).

    python tools/gen_progression_data.py

- data/competences/ : une fiche par compétence (catégorie combat/général, stat associée, famille) ;
- data/races/ : Humain, Elfe, Nain (bonus de stats, potentiels de base, talent, espérance de vie) ;
- data/classes/ : les 8 classes visibles (kit, compétences de départ, potentiels, talent) ;
- data/astrologie.json : éléments et animaux du cycle sexagésimal → potentiels, trines.
"""
import io, json, os

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "godot", "data"))


def ecrire(dossier, id_, d):
    os.makedirs(os.path.join(ROOT, dossier), exist_ok=True)
    with io.open(os.path.join(ROOT, dossier, id_ + ".json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
        f.write("\n")


# ---------------------------------------------------------------- compétences
C = {}


def comp(id_, categorie, stat, famille):
    C[id_] = {"name_key": "competence.%s.name" % id_, "category": categorie, "stat": stat, "famille": famille, "tags": [categorie, famille]}


for a, st in [("epee", "force"), ("hache_d_armes", "force"), ("masse", "force"), ("lance", "force"), ("dague", "dexterite"), ("arc", "dexterite"),
              ("arbalete", "dexterite"), ("baton_magique", "volonte"), ("mains_nues", "force"), ("bouclier", "endurance"), ("dual_wielding", "dexterite"), ("deux_mains", "force")]:
    comp(a, "combat", st, "armes")
for m in ["meditation", "controle_mana", "magie_feu", "magie_eau", "magie_terre", "magie_metal", "magie_bois", "magie_arcane", "magie_espace", "magie_corruption"]:
    comp(m, "combat", "volonte", "magie")
for r, st in [("minage", "force"), ("bucheronnage", "force"), ("terrassement", "endurance"), ("herboristerie", "perception"), ("collecte", "perception")]:
    comp(r, "general", st, "recolte")
for r, st in [("forge", "force"), ("menuiserie", "dexterite"), ("taille_de_pierre", "force"), ("tissage", "dexterite"), ("alchimie", "volonte"), ("cuisine", "perception"), ("enchantement", "volonte")]:
    comp(r, "general", st, "artisanat")
for r, st in [("lecture", "perception"), ("negociation", "charisme"), ("dressage", "charisme"), ("leadership", "charisme"), ("agriculture", "endurance"), ("elevage", "charisme"), ("navigation", "perception")]:
    comp(r, "general", st, "vie")
for r, st in [("discretion", "dexterite"), ("athletisme", "endurance"), ("esquive", "dexterite"), ("encaissement", "endurance")]:
    comp(r, "combat", st, "survie")
for r in ["matelasse", "cuir", "mailles", "ecailles", "plaque"]:
    comp(r, "combat", "endurance", "construction")
for r, st in [("tranchant", "force"), ("perforant", "dexterite"), ("contondant", "force")]:
    comp(r, "combat", st, "type_degats")
for e in ["bois", "feu", "terre", "metal", "eau"]:
    comp("element_" + e, "combat", "volonte", "element")
for id_, d in C.items():
    ecrire("competences", id_, d)
ecrire("competences", "_template", {"_doc": "Compétence (docs: Compétences — liste, Double niveau combat et général). category : combat | general (agrégats) ; stat : la stat qui reçoit la moitié de l'XP (décision du 2026-08-27) ; famille : pour les potentiels de base par famille. Les modules progressent sous leur propre id, catégorie combat, stat Volonté, sans fiche.",
                                     "name_key": "competence.<id>.name", "category": "combat", "stat": "force", "famille": "armes", "tags": []})

# ---------------------------------------------------------------- races (Races, Talents de race)
FAM_MAGIE = ["magie"]
ecrire("races", "humain", {"name_key": "race.humain.name", "bonus_stats": {}, "xp_mult": 1.10, "base_potentials": {"_defaut": 90}, "talent": "polyvalent", "lifespan": 80, "tags": ["humanoide"]})
ecrire("races", "elfe", {"name_key": "race.elfe.name", "bonus_stats": {"volonte": 2, "perception": 1}, "regen_mana_mult": 1.2, "endurance_max_add": -20,
                         "base_potentials": {"_defaut": 80, "magie": 120, "meditation": 120, "controle_mana": 120, "forge": 60, "encaissement": 60}, "talent": "chair_de_mana", "lifespan": 350, "tags": ["humanoide"]})
ecrire("races", "nain", {"name_key": "race.nain.name", "bonus_stats": {"endurance": 2, "force": 1}, "recolte_mult": {"minage": 1.15, "forge": 1.15},
                         "base_potentials": {"_defaut": 80, "forge": 120, "minage": 120, "taille_de_pierre": 120, "encaissement": 120, "magie": 60, "discretion": 60}, "talent": "oeil_de_la_pierre", "tags_acquis": ["detection_filons"], "lifespan": 250, "tags": ["humanoide"]})
ecrire("races", "_template", {"_doc": "Race (docs: Races, Talents de race). bonus_stats : ajoutés à la création ; base_potentials : par compétence ou par famille (_defaut sinon) ; talent : id du talent (mécanisme d'étape ultérieure) ; lifespan : espérance de vie.",
                              "name_key": "race.<id>.name", "bonus_stats": {}, "base_potentials": {"_defaut": 80}, "talent": None, "lifespan": 80, "tags": ["humanoide"]})

# ---------------------------------------------------------------- classes (Classes)
LOURDES = {"masse": 60, "hache_d_armes": 60, "deux_mains": 60}
def classe(id_, stats, equip, ratelier, comps, pot, talent, points=0):
    ecrire("classes", id_, {"name_key": "classe.%s.name" % id_, "bonus_stats": stats, "equipement": equip, "ratelier": ratelier, "competences": comps,
                            "base_potentials": pot, "talent": talent, "points_creation_bonus": points, "tags": ["visible"]})
classe("le_sabre", {"force": 2, "endurance": 1}, ["proto_epee", "proto_bouclier"], ["proto_epee", "proto_bouclier"], {"epee": 5, "bouclier": 5},
       {"_defaut": 80, "epee": 120, "bouclier": 120, "deux_mains": 120, "encaissement": 120, "magie": 60, "alchimie": 60}, "ratelier_vivant")
classe("le_souffle", {"volonte": 2, "perception": 1}, ["proto_baton_magique"], ["proto_baton_magique"], {"magie_feu": 5, "meditation": 5},
       {"_defaut": 80, "magie": 120, "meditation": 120, "controle_mana": 120} | LOURDES, "communion_des_cinq")
classe("la_braise", {"dexterite": 2, "force": 1}, ["proto_masse"], ["proto_masse"], {"forge": 5, "menuiserie": 5},
       {"_defaut": 80, "forge": 120, "menuiserie": 120, "tissage": 120, "taille_de_pierre": 120, "cuisine": 120, "magie": 60} | LOURDES, "main_du_metal")
classe("la_trace", {"dexterite": 2, "perception": 1}, ["proto_arc", "proto_fleches"], ["proto_arc", "proto_dague"], {"arc": 5, "dressage": 5},
       {"_defaut": 80, "arc": 120, "arbalete": 120, "dressage": 120, "discretion": 120, "herboristerie": 120, "forge": 60, "encaissement": 60}, "meute")
classe("la_balance", {"charisme": 2, "perception": 1}, ["proto_dague"], ["proto_dague"], {"negociation": 5, "lecture": 5},
       {"_defaut": 80, "negociation": 120, "leadership": 120, "lecture": 120, "minage": 60} | LOURDES, "oeil_du_prix")
classe("la_paume", {"volonte": 2, "charisme": 1}, ["proto_baton_magique"], ["proto_baton_magique"], {"magie_bois": 5, "alchimie": 5},
       {"_defaut": 80, "magie_bois": 120, "meditation": 120, "alchimie": 100} | LOURDES, "souffle_rendu")
classe("le_creuset", {"perception": 2, "volonte": 1}, ["proto_dague"], ["proto_dague"], {"alchimie": 5, "herboristerie": 5},
       {"_defaut": 80, "alchimie": 120, "herboristerie": 120, "cuisine": 100} | LOURDES, "fiole_vive")
classe("le_vent", {"force": 1, "dexterite": 1, "endurance": 1, "volonte": 1, "perception": 1, "charisme": 1}, [], [], {},
       {"_defaut": 100}, None, points=15)
ecrire("classes", "_template", {"_doc": "Classe (docs: Classes, Talents de classe). Kit : bonus_stats, equipement, ratelier, competences de départ ; base_potentials par compétence ou famille ; talent : id (mécanisme d'étape ultérieure) ; points_creation_bonus.",
                                "name_key": "classe.<id>.name", "bonus_stats": {}, "equipement": [], "ratelier": [], "competences": {}, "base_potentials": {"_defaut": 80}, "talent": None, "points_creation_bonus": 0, "tags": ["visible"]})

# ---------------------------------------------------------------- astrologie
with io.open(os.path.join(ROOT, "astrologie.json"), "w", encoding="utf-8", newline="\n") as f:
    json.dump({
        "_doc": "Cycle sexagésimal (docs: Astrologie — cycle sexagésimal) : +10 de potentiel de base dans les compétences liées. Une année = un élément (cycle de 5) et un animal (cycle de 12) ; 60 combinaisons.",
        "elements": ["bois", "feu", "terre", "metal", "eau"],
        "animaux": ["rat", "boeuf", "tigre", "lapin", "dragon", "serpent", "cheval", "chevre", "singe", "coq", "chien", "cochon"],
        "bonus_potentiel": 10,
        "element_competences": {"bois": ["magie_bois", "agriculture"], "feu": ["magie_feu", "cuisine", "forge"], "terre": ["magie_terre", "minage", "terrassement"],
                                "metal": ["magie_metal", "forge", "taille_de_pierre"], "eau": ["magie_eau", "alchimie", "navigation"]},
        "animal_competences": {"rat": ["discretion", "negociation"], "boeuf": ["encaissement", "agriculture"], "tigre": ["deux_mains", "athletisme"], "lapin": ["esquive", "herboristerie"],
                               "dragon": ["controle_mana", "leadership"], "serpent": ["alchimie", "herboristerie"], "cheval": ["athletisme", "dressage"], "chevre": ["tissage", "taille_de_pierre"],
                               "singe": ["lecture", "menuiserie"], "coq": ["arc", "arbalete"], "chien": ["dressage", "encaissement"], "cochon": ["cuisine", "negociation"]},
        "trines": [["rat", "dragon", "singe"], ["boeuf", "serpent", "coq"], ["tigre", "cheval", "chien"], ["lapin", "chevre", "cochon"]],
        "relation_trine": 1.25, "relation_opposition": 0.8
    }, f, ensure_ascii=False, indent=2)
    f.write("\n")
print("competences:", len(C), "; races 3 ; classes 8 ; astrologie")
