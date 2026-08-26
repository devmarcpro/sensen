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
| Guerrier | Épée, Bouclier, Deux Mains, Encaissement | domaines de magie, Alchimie |
| Mage | domaines de magie, Méditation, Contrôle du Mana | armes lourdes (Masse, Hache, Deux Mains) |
| Artisan | Forge, Menuiserie, Tissage, Taille de pierre, Cuisine | armes lourdes, domaines de magie |
| Chasseur | Arc, Arbalète, Dressage, Discrétion, Herboristerie | Forge, Encaissement |
| Marchand | Négociation, Leadership, Lecture, Charisme | armes lourdes, Minage |
| Vagabond | *(aucun — 100 partout : la polyvalence brute)* | — |

Race et classe **s'additionnent** : le plancher final est la moyenne des deux valeurs quand elles diffèrent (un Nain Mage a 90 en Forge et 90 en magie — ni spécialiste ni nul). C'est ce qui rend les 36 combinaisons mécaniquement distinctes ([[Potentiel]]).

**Cultures ([[Cultures de nommage]]) :** les 3 races piochent parmi les **7 cultures**, toutes inspirées du monde réel — l'Humain a le spectre le plus large, le Nain penche vers le nordique, l'Elfe vers le celte. Les affinités sont déclarées par `race_affinity` ([[Culture de nommage — schéma]]).

**Race dominante d'un royaume ([[Génération des royaumes PNJ]]) :** choisie selon le biome de la capitale (affinités déclarées dans les données de race — ex. nains → montagnes) ; ~90 % de la population, et l'exclusivité des rôles de gouvernance.

**Espérance de vie ([[Âge des PNJ]]) :** donnée `lifespan` par race, avec variance ±15 %.

**Réputation par race ([[Réputation et relations]]) :** chaque race a sa propre perception du joueur ; les rivalités entre races sont déclarées en données (`rivals`).

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Stats de personnage]], [[Génération des royaumes PNJ]], [[Cultures de nommage]], [[Âge des PNJ]]
- **Voir aussi** : [[Classes]], [[Réputation et relations]], [[Schéma unifié créature-PNJ]], [[Faim]], [[Culture de nommage — schéma]]
