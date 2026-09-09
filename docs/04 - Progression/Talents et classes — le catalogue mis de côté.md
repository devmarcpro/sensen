---
aliases: ["Talents mis de côté", "Classes mises de côté", "Le catalogue parqué"]
tags: [progression, contenu, gelé]
domaine: progression
statut: gelé
etape: 4
---

Le catalogue complet des **26 talents** et des **19 classes**, retiré du jeu le 2026-09-09 et conservé ici mot pour mot. C'est la note qui remplace les fichiers, pas un résumé.

> [!important] Demandé par le designer le 2026-09-09 : **« retire tout les talents, laisse juste un place holder, idem pour les classes, mets juste tout dans une note pour que ce soit pas perdu »**
> **Ce qui a été retiré** : les 26 fiches de `data/talents/` et les 19 fiches de `data/classes/`. Il reste **une** de chaque — `placeholder` —, et tout ce qui nommait une classe ou un talent pointe désormais sur elle : les races, les fonctions de village (`classes_possibles`), les classes mères, les fiches d'exemple.
> **Ce qui a été GARDÉ, et c'est délibéré** : les **blocs de règles** de `combat_rules.talents` et les **branches de code** qui les lisent. Un talent est deux choses — une *fiche au catalogue* (ce que le joueur obtient) et un *mécanisme* (ce qu'il fait). La fiche est partie ; le mécanisme dort, sans porteur, et se rebranche d'une ligne le jour où le designer redéfinit un talent qui l'utilise. *Effacer les deux aurait été jeter le travail au lieu de le ranger* — et c'est justement ce que cette note refuse.
> **Conséquence à connaître** : le jeu n'a plus qu'un kit de départ et qu'une hotbar (ceux du `placeholder`), et aucun être ne porte plus de talent. Rien n'est cassé, tout est *nu*.

## Ce qu'un talent et une classe portaient

**Un talent** : `name_key`, `desc_key`, son porteur (`race` **ou** `classe`, jamais les deux), `cache` (un talent caché ne s'affiche pas à la création) et ses `tags`. Ses **nombres** vivaient à part, dans `combat_rules.talents.<id>` — reproduits ci-dessous avec chaque talent qui en avait.

**Une classe** : le **kit de départ** (`equipement`, `ratelier`, `equipement_slots`), les `competences` de départ, les `bonus_stats`, les `base_potentials` (par compétence ou par famille, `_defaut` sinon), le `talent` de classe, les `capacites` (chacune une liste de **modules** composés) et la `hotbar` qui les range, la `signature`, la `classe_mere` et `points_creation_bonus`.

## Les 26 talents

### Affût — classe **l_engrenage**

*Une tourelle portative qui tire avec l'élément de ton arme et mange ton carquois.*

```json
{
  "name_key": "talent.affut.name",
  "desc_key": "talent.affut.desc",
  "classe": "l_engrenage",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.affut` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "portee": 6,
  "cadence_ticks": 400,
  "degats": "1d6",
  "type": "perforant"
}
```

### Brèche — classe **le_passeur**

*Deux portails appairés, repositionnables ; mana max −30 %.*

```json
{
  "name_key": "talent.breche.name",
  "desc_key": "talent.breche.desc",
  "classe": "le_passeur",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.breche` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "portails_max": 2,
  "mana_max_mult": 0.7,
  "ia_portee": 8,
  "ia_gain_min": 6
}
```

### Carapace — race **insectoide**

*Une chitine qui protège partout : +3 d'armure sur toutes les zones, mais −15 d'endurance maximale.*

```json
{
  "name_key": "talent.carapace.name",
  "desc_key": "talent.carapace.desc",
  "classe": null,
  "race": "insectoide",
  "cache": false,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.carapace` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "_doc": "CARAPACE (talent de race insectoide, 2026-09-09) : une chitine qui protege partout, tout le temps, et qui pese. `armure` s ajoute a l armure de zone quelle que soit la piece portee — c est la difference avec une cuirasse, qui ne couvre que le torse. `vigueur_max` est ce qu elle coute : une carapace n est pas gratuite, et un insectoide s essouffle plus vite qu un homme.",
  "armure": 3.0,
  "vigueur_max": -15
}
```

### Chaîne d'amorces — classe **la_meche**

*Une explosion amorce les bombes dans son rayon — les tiennes aussi.*

```json
{
  "name_key": "talent.chaine_d_amorces.name",
  "desc_key": "talent.chaine_d_amorces.desc",
  "classe": "la_meche",
  "race": null,
  "cache": true,
  "tags": []
}
```

### Chair de mana — race **elfe**

*La surchauffe coûte de la vigueur ; mana ×1,2 ; vigueur max −20.*

```json
{
  "name_key": "talent.chair_de_mana.name",
  "desc_key": "talent.chair_de_mana.desc",
  "classe": null,
  "race": "elfe",
  "cache": false,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.chair_de_mana` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "mana_regen_mult": 1.2,
  "vigueur_max": -20
}
```

### Communion des cinq — classe **le_souffle**

*L'élément de son arme tourne seul dans le cycle à chaque coup, contre un peu de mana.*

```json
{
  "name_key": "talent.communion_des_cinq.name",
  "desc_key": "talent.communion_des_cinq.desc",
  "classe": "le_souffle",
  "race": null,
  "cache": false,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.communion_des_cinq` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "mana": 2
}
```

### Deux queues — classe **le_rieur**

*Critiques 19-20, échecs 1-2, une relance par combat.*

```json
{
  "name_key": "talent.deux_queues.name",
  "desc_key": "talent.deux_queues.desc",
  "classe": "le_rieur",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.deux_queues` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "crit_bonus": 1,
  "fumble_bonus": 1
}
```

### Dissimulation — classe **l_ombre**

*Dissimulé après chaque mise à mort (vu seulement adjacent) ; −25 % de face.*

```json
{
  "name_key": "talent.dissimulation.name",
  "desc_key": "talent.dissimulation.desc",
  "classe": "l_ombre",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.dissimulation` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "face_mult": 0.75,
  "vu_a": 1
}
```

### Fiole vive — classe **le_creuset**

*Ses potions se partagent avec les alliés adjacents, et l'alambic en tire deux.*

```json
{
  "name_key": "talent.fiole_vive.name",
  "desc_key": "talent.fiole_vive.desc",
  "classe": "le_creuset",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Graveur — classe **le_sceau**

*Glyphes permanents déclenchés à distance ; 2× mana, immobile pendant la gravure.*

```json
{
  "name_key": "talent.graveur.name",
  "desc_key": "talent.graveur.desc",
  "classe": "le_sceau",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.graveur` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "mana_mult": 2,
  "gravure_ticks": 600,
  "portee_declenchement": 8
}
```

### Jauge de sang — classe **l_ecarlate**

*Les dégâts subis remplissent la jauge (jusqu'à ×1,8) ; tout soin la vide.*

```json
{
  "name_key": "talent.jauge_de_sang.name",
  "desc_key": "talent.jauge_de_sang.desc",
  "classe": "l_ecarlate",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.jauge_de_sang` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "max": 100,
  "mult_max": 1.8
}
```

### Lune — race **lycanthrope**

*Forme bestiale à volonté : stats ×1,5, griffes et crocs, ni arme, ni capacité, ni parole ; forcée une nuit sur trente.*

```json
{
  "name_key": "talent.lune.name",
  "desc_key": "talent.lune.desc",
  "classe": null,
  "race": "lycanthrope",
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.lune` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "stats_mult": 1.5,
  "actions": [
    "griffure",
    "morsure_puissante"
  ],
  "ticks_transformation": 400,
  "nuit_forcee_toutes_les": 30
}
```

### Main du métal — classe **la_braise**

*Reforger un objet looté sans perdre ses affixes.*

```json
{
  "name_key": "talent.main_du_metal.name",
  "desc_key": "talent.main_du_metal.desc",
  "classe": "la_braise",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Maître du tempo — classe **le_sablier**

*Voler du tempo à un ennemi : il est retardé, tu avances — contre de la santé.*

```json
{
  "name_key": "talent.maitre_du_tempo.name",
  "desc_key": "talent.maitre_du_tempo.desc",
  "classe": "le_sablier",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.maitre_du_tempo` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "tempo_vole": 8,
  "sante": 5,
  "portee": 3
}
```

### Masques — classe **le_masque**

*Deux masques à la fois, changés à 0 tick ; jamais de garde.*

```json
{
  "name_key": "talent.masques.name",
  "desc_key": "talent.masques.desc",
  "classe": "le_masque",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.masques` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "max": 2
}
```

### Meute — classe **la_trace**

*Les coups de ses compagnons posent des segments sur sa jauge de chaîne.*

```json
{
  "name_key": "talent.meute.name",
  "desc_key": "talent.meute.desc",
  "classe": "la_trace",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Œil de la pierre — race **nain**

*Rien n'est irrécoltable (÷ 3 au-dessus du seuil) ; vision −20 % ; sent les filons.*

```json
{
  "name_key": "talent.oeil_de_la_pierre.name",
  "desc_key": "talent.oeil_de_la_pierre.desc",
  "classe": null,
  "race": "nain",
  "cache": false,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.oeil_de_la_pierre` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "recolte_div": 3.0,
  "vision_mult": 0.8
}
```

### Œil du prix — classe **la_balance**

*Voit la bourse réelle des marchands ; +1 place d'escorte.*

```json
{
  "name_key": "talent.oeil_du_prix.name",
  "desc_key": "talent.oeil_du_prix.desc",
  "classe": "la_balance",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Polyvalent — race **humain**

*Porte deux talents de classe : le sien et un appris.*

```json
{
  "name_key": "talent.polyvalent.name",
  "desc_key": "talent.polyvalent.desc",
  "classe": null,
  "race": "humain",
  "cache": false,
  "tags": []
}
```

### Râtelier vivant — classe **le_sabre**

*Une fois par chaîne, changer d'arme coûte 0 tick.*

```json
{
  "name_key": "talent.ratelier_vivant.name",
  "desc_key": "talent.ratelier_vivant.desc",
  "classe": "le_sabre",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Releveur — classe **le_fossoyeur**

*Relève les cadavres en invocations de 60 ticks ; chaque relève coûte de la réputation partout.*

```json
{
  "name_key": "talent.releveur.name",
  "desc_key": "talent.releveur.desc",
  "classe": "le_fossoyeur",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.releveur` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "duree_ticks": 6000,
  "portee": 2,
  "reputation": -10
}
```

### Saisie — classe **le_porteur**

*Saisir un être adjacent et le lancer ; ni attaque ni garde tant qu'il est porté.*

```json
{
  "name_key": "talent.saisie.name",
  "desc_key": "talent.saisie.desc",
  "classe": "le_porteur",
  "race": null,
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.saisie` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "distance_lancer": 3,
  "degats_lancer": "1d6"
}
```

### Sans chair — race **spectre**

*Dégâts physiques ×0,3, traverse un mur ; ni armure, ni soins de bouche ; les civils fuient.*

```json
{
  "name_key": "talent.sans_chair.name",
  "desc_key": "talent.sans_chair.desc",
  "classe": null,
  "race": "spectre",
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.sans_chair` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "corruption_seuil": 70,
  "physique_mult": 0.3,
  "capacite_poids": 5,
  "terreur_ticks": 2000,
  "slots_refuses": [
    "casque",
    "cuirasse",
    "jambieres"
  ]
}
```

### Sans maître — classe **le_vent**

*Commence sans talent ; apprend celui d'un PNJ (relation ≥ 75) et peut en changer.*

```json
{
  "name_key": "talent.sans_maitre.name",
  "desc_key": "talent.sans_maitre.desc",
  "classe": "le_vent",
  "race": null,
  "cache": false,
  "tags": []
}
```

### Soif de sang — race **vampire**

*+3 à toutes les stats la nuit, brûle au jour ; une morsure remplit la jauge ; plus de plats.*

```json
{
  "name_key": "talent.soif_de_sang.name",
  "desc_key": "talent.soif_de_sang.desc",
  "classe": null,
  "race": "vampire",
  "cache": true,
  "tags": []
}
```

Ses nombres, dans `combat_rules.talents.soif_de_sang` — **gardés en place**, le mécanisme dort mais n'est pas perdu :

```json
{
  "degats_morsure": "1d6",
  "refresh_ticks": 20000
}
```

### Souffle rendu — classe **la_paume**

*Ses soins posent un segment de l'élément de la cible ; ses coups d'arme n'en posent aucun.*

```json
{
  "name_key": "talent.souffle_rendu.name",
  "desc_key": "talent.souffle_rendu.desc",
  "classe": "la_paume",
  "race": null,
  "cache": false,
  "tags": []
}
```

## Les 19 classes

Rangées par **classe mère** — les six axes de `classes_meres.json`, chacun avec sa stat maîtresse :

- **Guerrier** (stat `force`) : `l_ecarlate`, `le_porteur`, `le_sabre`, `la_braise`
- **Rôdeur** (stat `dexterite`) : `l_ombre`, `la_meche`, `le_masque`
- **Mage** (stat `volonte`) : `la_paume`, `le_fossoyeur`, `le_passeur`, `le_sablier`, `le_souffle`
- **Sentinelle** (stat `endurance`) : `le_vent`, `le_sceau`
- **Érudit** (stat `perception`) : `l_engrenage`, `la_trace`, `le_creuset`
- **Meneur** (stat `charisme`) : `la_balance`, `le_rieur`

### L'Écarlate

```json
{
  "name_key": "classe.l_ecarlate.name",
  "bonus_stats": {
    "force": 2,
    "endurance": 1
  },
  "equipement": [
    "craft_epee",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_dague",
    "craft_lance"
  ],
  "competences": {
    "epee": 4,
    "encaissement": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "jauge_de_sang",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "l_ecarlate_saignement",
      "name_key": "module.saignement.name",
      "modules": [
        "point",
        "contact",
        "saignement"
      ]
    },
    {
      "id": "l_ecarlate_estoc",
      "name_key": "module.estoc.name",
      "modules": [
        "point",
        "contact",
        "estoc"
      ]
    },
    {
      "id": "l_ecarlate_frappe",
      "name_key": "module.frappe.name",
      "modules": [
        "point",
        "contact",
        "frappe"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "saignement",
  "classe_mere": "guerrier",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### L'Engrenage

```json
{
  "name_key": "classe.l_engrenage.name",
  "bonus_stats": {
    "dexterite": 2,
    "perception": 1
  },
  "equipement": [
    "craft_arc",
    "craft_casque",
    "torche",
    "craft_fleches"
  ],
  "ratelier": [
    "craft_dague",
    "craft_masse"
  ],
  "competences": {
    "arbalete": 4,
    "forge": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "affut",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "l_engrenage_tourelle",
      "name_key": "module.tourelle.name",
      "modules": [
        "point",
        "jet_long",
        "tourelle"
      ]
    },
    {
      "id": "l_engrenage_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_long",
        "eclat"
      ]
    },
    {
      "id": "l_engrenage_epine",
      "name_key": "module.epine.name",
      "modules": [
        "point",
        "jet_long",
        "epine"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "tourelle",
  "classe_mere": "erudit",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### L'Ombre

```json
{
  "name_key": "classe.l_ombre.name",
  "bonus_stats": {
    "dexterite": 2,
    "perception": 1
  },
  "equipement": [
    "craft_dague",
    "craft_jambieres",
    "torche"
  ],
  "ratelier": [
    "craft_arc",
    "craft_epee"
  ],
  "competences": {
    "discretion": 6,
    "dague": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "dissimulation",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "l_ombre_voile",
      "name_key": "module.voile.name",
      "modules": [
        "point",
        "contact",
        "voile"
      ]
    },
    {
      "id": "l_ombre_estoc",
      "name_key": "module.estoc.name",
      "modules": [
        "point",
        "contact",
        "estoc"
      ]
    },
    {
      "id": "l_ombre_projection",
      "name_key": "module.projection.name",
      "modules": [
        "point",
        "contact",
        "projection"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "voile",
  "classe_mere": "rodeur",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### La Balance

```json
{
  "name_key": "classe.la_balance.name",
  "bonus_stats": {
    "charisme": 2,
    "perception": 1
  },
  "equipement": [
    "craft_luth",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_dague"
  ],
  "competences": {
    "negociation": 5,
    "lecture": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "negociation": 120,
    "leadership": 120,
    "lecture": 120,
    "minage": 60,
    "masse": 60,
    "hache_d_armes": 60,
    "deux_mains": 60
  },
  "talent": "oeil_du_prix",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "la_balance_estimation",
      "name_key": "module.estimation.name",
      "modules": [
        "point",
        "jet_court",
        "estimation"
      ]
    },
    {
      "id": "la_balance_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    },
    {
      "id": "la_balance_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_court",
        "eclat"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "estimation",
  "classe_mere": "meneur",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### La Braise

```json
{
  "name_key": "classe.la_braise.name",
  "bonus_stats": {
    "dexterite": 2,
    "force": 1
  },
  "equipement": [
    "craft_masse",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_hache",
    "craft_pioche"
  ],
  "competences": {
    "forge": 5,
    "menuiserie": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "forge": 120,
    "menuiserie": 120,
    "tissage": 120,
    "taille_de_pierre": 120,
    "cuisine": 120,
    "magie": 60,
    "masse": 60,
    "hache_d_armes": 60,
    "deux_mains": 60
  },
  "talent": "main_du_metal",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "la_braise_trempe",
      "name_key": "module.trempe.name",
      "modules": [
        "point",
        "hast",
        "trempe"
      ]
    },
    {
      "id": "la_braise_fonte",
      "name_key": "module.fonte.name",
      "modules": [
        "point",
        "hast",
        "fonte"
      ]
    },
    {
      "id": "la_braise_ronce",
      "name_key": "module.ronce.name",
      "modules": [
        "point",
        "hast",
        "ronce"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "trempe",
  "classe_mere": "guerrier",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### La Mèche

```json
{
  "name_key": "classe.la_meche.name",
  "bonus_stats": {
    "dexterite": 2,
    "perception": 1
  },
  "equipement": [
    "craft_dague",
    "craft_casque",
    "torche"
  ],
  "ratelier": [
    "craft_arc",
    "craft_pelle"
  ],
  "competences": {
    "forge": 3,
    "terrassement": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "forge": 110,
    "terrassement": 120,
    "athletisme": 100
  },
  "talent": "chaine_d_amorces",
  "points_creation_bonus": 0,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "la_meche_bombe",
      "name_key": "module.bombe.name",
      "modules": [
        "point",
        "jet_long",
        "bombe"
      ]
    },
    {
      "id": "la_meche_foudroiement",
      "name_key": "module.foudroiement.name",
      "modules": [
        "point",
        "jet_long",
        "foudroiement"
      ]
    },
    {
      "id": "la_meche_fonte",
      "name_key": "module.fonte.name",
      "modules": [
        "point",
        "jet_long",
        "fonte"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "bombe",
  "classe_mere": "rodeur",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### La Paume

```json
{
  "name_key": "classe.la_paume.name",
  "bonus_stats": {
    "volonte": 2,
    "charisme": 1
  },
  "equipement": [
    "craft_baton_magique",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_faucille"
  ],
  "competences": {
    "magie_bois": 5,
    "alchimie": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "magie_bois": 120,
    "meditation": 120,
    "alchimie": 100,
    "masse": 60,
    "hache_d_armes": 60,
    "deux_mains": 60
  },
  "talent": "souffle_rendu",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "la_paume_baume",
      "name_key": "module.baume.name",
      "modules": [
        "chemin",
        "sur_soi",
        "baume"
      ]
    },
    {
      "id": "la_paume_seve",
      "name_key": "module.seve.name",
      "modules": [
        "point",
        "jet_court",
        "seve"
      ]
    },
    {
      "id": "la_paume_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "baume",
  "classe_mere": "mage",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### La Trace

```json
{
  "name_key": "classe.la_trace.name",
  "bonus_stats": {
    "dexterite": 2,
    "perception": 1
  },
  "equipement": [
    "craft_arc",
    "craft_jambieres",
    "torche",
    "craft_fleches"
  ],
  "ratelier": [
    "craft_dague",
    "craft_lance"
  ],
  "competences": {
    "arc": 5,
    "dressage": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "arc": 120,
    "arbalete": 120,
    "dressage": 120,
    "discretion": 120,
    "herboristerie": 120,
    "forge": 60,
    "encaissement": 60
  },
  "talent": "meute",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "la_trace_traque",
      "name_key": "module.traque.name",
      "modules": [
        "point",
        "jet_long",
        "traque"
      ]
    },
    {
      "id": "la_trace_gravier",
      "name_key": "module.gravier.name",
      "modules": [
        "point",
        "jet_long",
        "gravier"
      ]
    },
    {
      "id": "la_trace_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_long",
        "eclat"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "traque",
  "classe_mere": "erudit",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Creuset

```json
{
  "name_key": "classe.le_creuset.name",
  "bonus_stats": {
    "perception": 2,
    "volonte": 1
  },
  "equipement": [
    "craft_sarbacane",
    "craft_cuirasse",
    "torche",
    "craft_flechettes"
  ],
  "ratelier": [
    "craft_faucille",
    "craft_seau"
  ],
  "competences": {
    "alchimie": 5,
    "herboristerie": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "alchimie": 120,
    "herboristerie": 120,
    "cuisine": 100,
    "masse": 60,
    "hache_d_armes": 60,
    "deux_mains": 60
  },
  "talent": "fiole_vive",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "le_creuset_fiole",
      "name_key": "module.fiole.name",
      "modules": [
        "chemin",
        "sur_soi",
        "fiole"
      ]
    },
    {
      "id": "le_creuset_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    },
    {
      "id": "le_creuset_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_court",
        "eclat"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "fiole",
  "classe_mere": "erudit",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Fossoyeur

```json
{
  "name_key": "classe.le_fossoyeur.name",
  "bonus_stats": {
    "volonte": 3
  },
  "equipement": [
    "craft_baton_magique",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_pelle",
    "craft_dague"
  ],
  "competences": {
    "magie_corruption": 4,
    "encaissement": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "releveur",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_fossoyeur_releve",
      "name_key": "module.releve.name",
      "modules": [
        "point",
        "jet_court",
        "releve"
      ]
    },
    {
      "id": "le_fossoyeur_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    },
    {
      "id": "le_fossoyeur_roche",
      "name_key": "module.roche.name",
      "modules": [
        "point",
        "jet_court",
        "roche"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "releve",
  "classe_mere": "mage",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Masque

```json
{
  "name_key": "classe.le_masque.name",
  "bonus_stats": {
    "dexterite": 3
  },
  "equipement": [
    "craft_jambieres",
    "torche"
  ],
  "ratelier": [
    "craft_dague"
  ],
  "competences": {
    "mains_nues": 4,
    "athletisme": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "masques",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_masque_ecaille_elementaire",
      "name_key": "module.ecaille_elementaire.name",
      "modules": [
        "chemin",
        "sur_soi",
        "ecaille_elementaire"
      ]
    },
    {
      "id": "le_masque_brasier",
      "name_key": "module.brasier.name",
      "modules": [
        "point",
        "hast",
        "brasier"
      ]
    },
    {
      "id": "le_masque_flamme",
      "name_key": "module.flamme.name",
      "modules": [
        "point",
        "hast",
        "flamme"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "ecaille_elementaire",
  "classe_mere": "rodeur",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Passeur

```json
{
  "name_key": "classe.le_passeur.name",
  "bonus_stats": {
    "dexterite": 1,
    "volonte": 2
  },
  "equipement": [
    "craft_baton_magique",
    "craft_jambieres",
    "torche"
  ],
  "ratelier": [
    "craft_dague"
  ],
  "competences": {
    "magie_espace": 4,
    "athletisme": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "breche",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_passeur_portail",
      "name_key": "module.portail.name",
      "modules": [
        "point",
        "jet_long",
        "portail"
      ]
    },
    {
      "id": "le_passeur_flamme",
      "name_key": "module.flamme.name",
      "modules": [
        "point",
        "jet_long",
        "flamme"
      ]
    },
    {
      "id": "le_passeur_brasier",
      "name_key": "module.brasier.name",
      "modules": [
        "point",
        "jet_long",
        "brasier"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "portail",
  "classe_mere": "mage",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Porteur

```json
{
  "name_key": "classe.le_porteur.name",
  "bonus_stats": {
    "force": 3
  },
  "equipement": [
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_masse"
  ],
  "competences": {
    "mains_nues": 4,
    "athletisme": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "saisie",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_porteur_empoigne",
      "name_key": "module.empoigne.name",
      "modules": [
        "point",
        "contact",
        "empoigne"
      ]
    },
    {
      "id": "le_porteur_projection",
      "name_key": "module.projection.name",
      "modules": [
        "point",
        "contact",
        "projection"
      ]
    },
    {
      "id": "le_porteur_estoc",
      "name_key": "module.estoc.name",
      "modules": [
        "point",
        "contact",
        "estoc"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "empoigne",
  "classe_mere": "guerrier",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Rieur

```json
{
  "name_key": "classe.le_rieur.name",
  "bonus_stats": {
    "charisme": 2,
    "dexterite": 1
  },
  "equipement": [
    "craft_flute",
    "craft_casque",
    "torche"
  ],
  "ratelier": [
    "craft_epee",
    "craft_arc"
  ],
  "competences": {
    "negociation": 3,
    "dague": 3
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "deux_queues",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_rieur_pari",
      "name_key": "module.pari.name",
      "modules": [
        "point",
        "contact",
        "pari"
      ]
    },
    {
      "id": "le_rieur_botte",
      "name_key": "module.botte.name",
      "modules": [
        "point",
        "contact",
        "botte"
      ]
    },
    {
      "id": "le_rieur_charge_d_epaule",
      "name_key": "module.charge_d_epaule.name",
      "modules": [
        "point",
        "contact",
        "charge_d_epaule"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "pari",
  "classe_mere": "meneur",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Sablier

```json
{
  "name_key": "classe.le_sablier.name",
  "bonus_stats": {
    "volonte": 3
  },
  "equipement": [
    "craft_baton_magique",
    "craft_casque",
    "torche"
  ],
  "ratelier": [
    "craft_dague"
  ],
  "competences": {
    "magie_arcane": 4,
    "esquive": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "maitre_du_tempo",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_sablier_celerite",
      "name_key": "module.celerite.name",
      "modules": [
        "point",
        "jet_court",
        "celerite"
      ]
    },
    {
      "id": "le_sablier_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    },
    {
      "id": "le_sablier_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_court",
        "eclat"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "celerite",
  "classe_mere": "mage",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Sabre

```json
{
  "name_key": "classe.le_sabre.name",
  "bonus_stats": {
    "force": 2,
    "endurance": 1
  },
  "equipement": [
    "craft_epee",
    "craft_bouclier",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_lance",
    "craft_dague"
  ],
  "competences": {
    "epee": 5,
    "bouclier": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "epee": 120,
    "bouclier": 120,
    "deux_mains": 120,
    "encaissement": 120,
    "magie": 60,
    "alchimie": 60
  },
  "talent": "ratelier_vivant",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "le_sabre_frappe",
      "name_key": "module.frappe.name",
      "modules": [
        "point",
        "contact",
        "frappe"
      ]
    },
    {
      "id": "le_sabre_estoc",
      "name_key": "module.estoc.name",
      "modules": [
        "point",
        "contact",
        "estoc"
      ]
    },
    {
      "id": "le_sabre_projection",
      "name_key": "module.projection.name",
      "modules": [
        "point",
        "contact",
        "projection"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "frappe",
  "classe_mere": "guerrier",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Sceau

```json
{
  "name_key": "classe.le_sceau.name",
  "bonus_stats": {
    "endurance": 1,
    "volonte": 2
  },
  "equipement": [
    "craft_lance",
    "craft_cuirasse",
    "torche"
  ],
  "ratelier": [
    "craft_masse"
  ],
  "competences": {
    "enchantement": 4,
    "encaissement": 4
  },
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "graveur",
  "points_creation_bonus": 4,
  "tags": [
    "cache"
  ],
  "capacites": [
    {
      "id": "le_sceau_balise",
      "name_key": "module.balise.name",
      "modules": [
        "point",
        "jet_court",
        "balise"
      ]
    },
    {
      "id": "le_sceau_epine",
      "name_key": "module.epine.name",
      "modules": [
        "point",
        "jet_court",
        "epine"
      ]
    },
    {
      "id": "le_sceau_gel",
      "name_key": "module.gel.name",
      "modules": [
        "point",
        "jet_court",
        "gel"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "balise",
  "classe_mere": "sentinelle",
  "cachee": true,
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Souffle

```json
{
  "name_key": "classe.le_souffle.name",
  "bonus_stats": {
    "volonte": 2,
    "perception": 1
  },
  "equipement": [
    "craft_baton_magique",
    "craft_casque",
    "torche"
  ],
  "ratelier": [
    "craft_dague"
  ],
  "competences": {
    "magie_feu": 5,
    "meditation": 5
  },
  "base_potentials": {
    "_defaut": 80,
    "magie": 120,
    "meditation": 120,
    "controle_mana": 120,
    "masse": 60,
    "hache_d_armes": 60,
    "deux_mains": 60
  },
  "talent": "communion_des_cinq",
  "points_creation_bonus": 0,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "le_souffle_meditation",
      "name_key": "module.meditation.name",
      "modules": [
        "soi",
        "meditation"
      ]
    },
    {
      "id": "le_souffle_flamme",
      "name_key": "module.flamme.name",
      "modules": [
        "point",
        "jet_long",
        "flamme"
      ]
    },
    {
      "id": "le_souffle_eboulement",
      "name_key": "module.eboulement.name",
      "modules": [
        "point",
        "jet_long",
        "eboulement"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "meditation",
  "classe_mere": "mage",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

### Le Vent

```json
{
  "name_key": "classe.le_vent.name",
  "bonus_stats": {
    "force": 1,
    "dexterite": 1,
    "endurance": 1,
    "volonte": 1,
    "perception": 1,
    "charisme": 1
  },
  "equipement": [
    "craft_lance",
    "craft_jambieres",
    "torche"
  ],
  "ratelier": [
    "craft_arc",
    "craft_dague"
  ],
  "competences": {},
  "base_potentials": {
    "_defaut": 100
  },
  "talent": "sans_maitre",
  "points_creation_bonus": 4,
  "tags": [
    "visible"
  ],
  "capacites": [
    {
      "id": "le_vent_eclat",
      "name_key": "module.eclat.name",
      "modules": [
        "point",
        "jet_court",
        "eclat"
      ]
    },
    {
      "id": "le_vent_ronce",
      "name_key": "module.ronce.name",
      "modules": [
        "point",
        "jet_court",
        "ronce"
      ]
    },
    {
      "id": "le_vent_gravier",
      "name_key": "module.gravier.name",
      "modules": [
        "point",
        "jet_court",
        "gravier"
      ]
    }
  ],
  "hotbar": [
    {
      "type": "capacite",
      "ref": 0
    },
    {
      "type": "capacite",
      "ref": 1
    },
    {
      "type": "capacite",
      "ref": 2
    }
  ],
  "signature": "eclat",
  "classe_mere": "sentinelle",
  "equipement_slots": {
    "main_principale": "craft_epee",
    "main_secondaire": "craft_epee"
  }
}
```

## Qui nommait une classe, et qui pointe désormais sur le placeholder

Les **fonctions de village** disaient quelles classes un habitant pouvait porter (`classes_possibles`). Le tableau garde ce lien, qui est du contenu et non du code :

| fonction | classes possibles |
|---|---|
| `artisan` | `la_braise`, `le_creuset`, `la_paume`, `le_souffle` |
| `aventurier` | `la_braise`, `le_creuset`, `la_paume`, `le_souffle`, `la_balance`, `le_vent`, `le_sabre`, `la_trace` |
| `bucheron` | `la_braise`, `la_trace`, `le_vent` |
| `commandant` | `la_balance`, `le_souffle` |
| `commercant` | `la_balance`, `le_vent`, `le_creuset` |
| `couturier` | `la_braise`, `le_vent` |
| `cuisinier` | `le_creuset`, `la_paume` |
| `dirigeant` | `la_balance`, `le_sabre`, `le_souffle`, `la_paume` |
| `eleveur` | `la_trace`, `le_vent`, `la_braise` |
| `fermier` | `la_trace`, `le_vent`, `la_braise` |
| `garde` | `le_sabre`, `la_trace` |
| `herboriste` | `le_creuset`, `la_paume`, `la_trace` |
| `journalier` | `la_trace`, `la_braise` |
| `maire` | `la_balance`, `le_souffle` |
| `maitre_de_guilde` | `la_balance`, `le_sabre`, `le_souffle`, `la_paume` |
| `mineur` | `la_braise`, `la_trace`, `le_vent` |
| `oisif` | `la_braise`, `le_creuset`, `la_paume`, `le_souffle`, `la_balance`, `le_vent`, `le_sabre`, `la_trace` |
| `portefaix` | `la_braise`, `le_roc` |
| `pretre` | `la_paume` |
| `seigneur` | `la_balance`, `le_souffle` |
| `syndic` | `la_balance`, `le_souffle` |
| `transporteur` | `le_vent`, `la_balance` |

Et les **races** portaient chacune un talent :

| race | talent |
|---|---|
| `elfe` | `chair_de_mana` |
| `humain` | `polyvalent` |
| `insectoide` | `carapace` |
| `lycanthrope` | `lune` |
| `nain` | `oeil_de_la_pierre` |
| `spectre` | `sans_chair` |
| `vampire` | `soif_de_sang` |

## Les cinq talents de race qui étaient prêts et qui ne seront pas écrits

Le même jour, le designer a donné la liste des races — *« humain, insectoide, homme bête, robot, nautiques (hommes poissons), mutant, daemon »*. Cinq manquaient au catalogue, et chacune arrivait avec un talent conçu pour s'accrocher à un système **qui existe déjà**. Les races sont faites ; leurs talents ne le seront pas, mais leur dessin est ici, parce qu'il vaut mieux qu'un fichier :

- **Homme-bête — `flair`.** Il porte le tag `bete`, donc le champ d'odeur le fait **déjà** remonter une piste sans une ligne de code. Le talent n'aurait fait qu'abaisser le seuil de lisibilité de la piste (`odeur.flair.seuil` divisé par trois) : il sent ce qu'un fauve ordinaire ne sent pas encore.
- **Robot — `chassis`.** Un corps qu'on entretient au lieu de le nourrir : **il ne mange pas** (`faim_vitesse` à zéro) et **ne se répare pas tout seul** (le soin par partie multiplié par zéro — il faut le réparer). Sa coque ajoute de l'armure sur toutes les zones comme la carapace, et son bâti porte plus lourd.
- **Nautique — `branchies`.** La nage a déjà son coût et son refus de surcharge : l'homme-poisson les **ignore**. Il entre dans l'eau chargé là où un autre s'y noierait.
- **Mutant — `chair_instable`.** *« Un membre perdu ne repousse pas »* est la règle écrite le matin même avec le soin par partie. **Le mutant en aurait été l'exception** — au bout d'un long délai hors combat, une partie perdue revient. Il en faut une pour qu'une règle se remarque.
- **Daemon — `sang_de_soufre`.** Il **est une source du champ thermique** : il chauffe sa tuile comme un feu, fait fondre la neige, réchauffe une pièce et se signale à qui lit la chaleur. En échange la chaleur ne l'atteint pas, et le froid le mord deux fois plus.

## Liens

- [[Classes]] — ce que la classe est censée être
- [[Talents de race]] et [[Talents de classe]] — les deux notes de conception
- [[Races]] — les sept races, elles, sont au catalogue
- [[Les trois axes — race, classe, fonction]]
