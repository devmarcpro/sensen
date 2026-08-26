---
aliases: ["C.3", "Annexe C.3", "Classes", "Classes de départ"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

Les 6 classes de départ : un kit **et un talent** qui définit une façon de jouer ([[Talents de classe]]).

| Classe | Kit (stats + équipement + compétences de départ) | Talent |
|---|---|---|
| Guerrier | +2 For/+1 End ; épée fer, bouclier bois ; niv. 5 en Épée, Bouclier | **Râtelier vivant** |
| Mage | +2 Vol/+1 Per ; bâton, 1 grimoire simple ; niv. 5 en Magie, Méditation, 3 modules de base | **Communion des cinq** |
| Forgeron | +2 Dex/+1 For ; outils complets qualité Correct ; niv. 5 en Forge et 1 métier au choix | **Main du métal** |
| Chasseur | +2 Dex/+1 Per ; arc, 20 flèches ; niv. 5 en Arc, Dressage | **Meute** |
| Marchand | +2 Cha/+1 Per ; 500 or, étal portatif ; niv. 5 en Négociation, Lecture | **Œil du prix** |
| Vagabond | +1 partout ; rien ; +15 points de création en plus | **Sans maître** (aucun, mais peut en apprendre un) |

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

**Ce qui a changé (2026-08-26) :** la classe ne détermine plus *uniquement* le kit de départ — elle porte un **talent permanent** ([[Talents de classe]]). Ce qui reste vrai : **aucun plafond, aucune pénalité** liés à la classe. Le talent est *un plancher, pas une cage* — tous les slots restent libres, le build émerge par-dessus.

**Classes cachées** ([[Talents de classe]]) : Éliotrope, Nécromancien, Berserker. Elles ne sont pas au menu — elles s'apprennent d'un PNJ qui les porte (relation ≥ 75, comme les recettes exotiques).

**L'ancienne classe *Artisan* devient *Forgeron*** : « artisan » est désormais une **fonction** ([[Fonctions]] : craft et vend ce qu'il craft), pas une classe.

**Équipement initial ([[Début de partie]]) :** kit de la classe, rien d'autre.

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Début de partie]], [[Stats de personnage]]
- **Voir aussi** : [[Races]], [[Compétences — liste]], [[Qualité d'artisanat]], [[Commerce et boutiques]], [[Grimoires et manuels]]
