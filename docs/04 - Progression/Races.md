---
aliases: ["C.2", "Annexe C.2", "Races", "Races de départ"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

Les 3 races de lancement — **classiques et lisibles**.

> [!warning] Trois races retirées le 2026-08-26
> **Sylvide**, **Cendreux** et **Échomorphe** (les races « originales ») sont supprimées, ainsi que leurs 3 cultures dédiées ([[Cultures de nommage]]). Le monde garde Humain, Elfe et Nain — de la fantasy classique assumée, pas de peuples inventés. Tout le reste du système de races est **intact** : réputation par race, race dominante d'un royaume, `race_affinity`, `lifespan` par race.

| Race | Bonus | Talent ([[Talents de race]]) |
|---|---|---|
| Humain | +10 % XP de compétences | **Polyvalent** — porte **deux** talents de classe |
| Elfe | +2 Volonté, +1 Perception, régén mana +20 % | **Chair de mana** — la surchauffe coûte de l'endurance, pas de la santé |
| Nain | +2 Endurance, +1 Force, minage/forge +15 % | **Œil de la pierre** — `detection_filons` permanent, ignore l'irrécoltabilité |

**La race porte désormais un talent** qui change la façon de jouer ([[Talents de race]]) — passif, subi, avec sa contrepartie. Les races **cachées** (Vampire, Spectre, Lycanthrope, et toute espèce du bestiaire) ne se choisissent pas : **on le devient**.

**Potentiels de base ([[Potentiel]]) :** chaque race ET chaque classe définit ses potentiels de base par stat et par familles de compétences (champ `base_potentials` en données) — ex. Nain : Forge/Minage 120, Magie 60 ; Mage : domaines de magie 120, armes lourdes 60. Les valeurs vivent dans `data/races/` et `data/classes/` ([[Décision — Pipeline de contenu]]).

**Valeurs de `base_potentials` (fixées — défaut 80 partout où non listé) :**

| Race | 120 | 60 |
|---|---|---|
| Humain | *(aucun — 90 partout : le polyvalent)* | — |
| Elfe | domaines de magie, Méditation, Contrôle du Mana | Forge, Encaissement |
| Nain | Forge, Minage, Taille de pierre, Encaissement | domaines de magie, Discrétion |

| Classe | 120 | 60 |
|---|---|---|
| Le Sabre | Épée, Bouclier, Deux Mains, Encaissement | domaines de magie, Alchimie |
| Le Souffle | domaines de magie, Méditation, Contrôle du Mana | armes lourdes (Masse, Hache, Deux Mains) |
| La Braise | Forge, Menuiserie, Tissage, Taille de pierre, Cuisine | armes lourdes, domaines de magie |
| La Trace | Arc, Arbalète, Dressage, Discrétion, Herboristerie | Forge, Encaissement |
| La Balance | Négociation, Leadership, Lecture, Charisme | armes lourdes, Minage |
| Le Vent | *(aucun — 100 partout : la polyvalence brute)* | — |

Race et classe **s'additionnent** : le plancher final est la moyenne des deux valeurs quand elles diffèrent (un Nain Mage a 90 en Forge et 90 en magie — ni spécialiste ni nul). C'est ce qui rend les 36 combinaisons mécaniquement distinctes ([[Potentiel]]).

**Cultures ([[Cultures de nommage]]) :** les 3 races piochent parmi les **7 cultures**, toutes inspirées du monde réel — l'Humain a le spectre le plus large, le Nain penche vers le nordique, l'Elfe vers le celte. Les affinités sont déclarées par `race_affinity` ([[Culture de nommage — schéma]]).

**Race dominante d'un royaume ([[Génération des royaumes PNJ]]) :** choisie selon le biome de la capitale (affinités déclarées dans les données de race — ex. nains → montagnes) ; ~90 % de la population, et l'exclusivité des rôles de gouvernance.

**Espérance de vie ([[Âge des PNJ]]) :** donnée `lifespan` par race, avec variance ±15 %. **Valeurs fixées le 2026-08-26** (elles manquaient) :

| Race | `lifespan` | Maturité (`lifespan × 0.22`) | Grisonnement |
|---|---|---|---|
| Humain | **80 ans** | 17 ans | ~38 ans |
| Nain | **250 ans** | 55 ans | ~110 ans |
| Elfe | **350 ans** | 77 ans | ~210 ans |

La **maturité** (22 % de l'espérance) est le plancher d'âge de toute fonction productive et la condition `age` de la reproduction ([[Conditions de reproduction]]) ; en dessous, la fonction est `oisif` (enfant) et les stats sont multipliées par un facteur de croissance.

**Réputation par race ([[Réputation et relations]]) :** chaque race a sa propre perception du joueur ; les rivalités entre races sont déclarées en données (`rivals`).

> [!success] Codé — trace ajoutée le 2026-09-04
> `data/races/` : bonus de départ, talent de race (`talents.chair_de_mana`, `deux_queues`…), niveaux de départ par compétence ; les trois races cachées (vampire, spectre, lycanthrope) sont codées avec l'incarnation.

> [!important] Demandé par le designer le 2026-09-09 : **« les races: humain, insectoide, homme bête, robot, nautiques (hommes poissons), mutant, daemon »**
> **Cinq manquaient au catalogue**, et elles y sont : **homme-bête**, **robot**, **nautique**, **mutant**, **daemon** — chacune avec ses bonus de stats, ses potentiels, son espérance de vie et son visage. Dix-neuf traits de visage neufs (têtes, oreilles, yeux, bouches) ont été **ajoutés en fin** de leurs loci, parce que l'index d'une valeur est celui de sa case de planche : l'insérer au milieu changerait le visage de tous les personnages déjà sauvegardés.
> **Aucune ne porte de talent**, et c'est volontaire : le designer a fait retirer talents et classes le même jour ([[Talents et classes — le catalogue mis de côté]]). Les cinq talents qui étaient dessinés pour elles — le flair de l'homme-bête, le châssis du robot, les branchies du nautique, la chair instable du mutant, le sang de soufre du daemon — sont conservés dans cette note-là, avec le système existant auquel chacun devait s'accrocher.
> **UNE QUESTION RESTE OUVERTE, et elle n'est pas à moi** : la liste ne dit pas si elle **remplace** ou si elle **ajoute**. **Elfe**, **Nain**, **Vampire** et **Spectre** sont donc toujours au catalogue. Effacer quatre races — leurs cultures de nommage, leurs apparences, ce qui les cite dans les royaumes — n'est pas réversible, et cela se demande.
> **Le lycanthrope reste distinct de l'homme-bête** : l'un est un homme qu'une malédiction change (une race *cachée*, qu'on devient), l'autre est un **peuple** qu'on choisit à la création.

> [!bug] Un défaut trouvé en donnant un visage à ces cinq races (2026-09-09)
> Ajouter dix-neuf valeurs de locus demandait des dessins. Relancer `tools/gen_planches_substitution.py` a reposé un `00_substitution.png` dans **chaque** dossier — y compris ceux où le designer avait déjà mis ses propres cases. Or `Planches` concatène les PNG d'un dossier **dans l'ordre des noms**, et l'index d'une variante est sa place dans cette concaténation : « 00_substitution.png » se range entre « 00_ronde.png » et « 01_ovale.png », et sa planche de onze cases **décalait de onze rangs tout ce qui suit**. *Chaque visage sauvegardé aurait changé de tête, sans erreur et sans message.*
> Le générateur **regarde désormais ce que le dossier contient** : garni de cases individuelles, il n'écrit qu'**une case par valeur manquante**, numérotée à sa place (`06_museau.png`) ; vide, il repose la planche entière comme avant. Un dossier de **membre** n'est jamais touché s'il porte déjà un dessin — l'index y est la carrure, et `posmod` la ramène à la seule case présente.

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Stats de personnage]], [[Génération des royaumes PNJ]], [[Cultures de nommage]], [[Âge des PNJ]]
- **Voir aussi** : [[Classes]], [[Réputation et relations]], [[Schéma unifié créature-PNJ]], [[Faim]], [[Culture de nommage — schéma]]
