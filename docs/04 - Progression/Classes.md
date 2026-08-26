---
aliases: ["C.3", "Annexe C.3", "Classes", "Classes de départ"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

Les 6 kits de départ. Une classe n'est qu'un kit initial — aucune restriction durable ensuite.

| Classe | Kit (stats + équipement + compétences de départ) |
|---|---|
| Guerrier | +2 For/+1 End ; épée fer, bouclier bois ; niv. 5 en Épée, Bouclier |
| Mage | +2 Vol/+1 Per ; bâton, 1 grimoire simple ; niv. 5 en Magie, Méditation, 3 modules de base |
| Artisan | +2 Dex/+1 For ; outils complets qualité Correct ; niv. 5 en 2 métiers au choix |
| Chasseur | +2 Dex/+1 Per ; arc, 20 flèches ; niv. 5 en Arc, Dressage |
| Marchand | +2 Cha/+1 Per ; 500 or, étal portatif ; niv. 5 en Négociation, Lecture |
| Vagabond | +1 partout ; rien ; +15 points de création en plus |

**Potentiels de base ([[Potentiel]]) :** chaque race ET chaque classe définit ses potentiels de base par stat et par familles de compétences (champ `base_potentials` en données) — ex. Nain : Forge/Minage 120, Magie 60 ; Mage : domaines de magie 120, armes lourdes 60. Les valeurs vivent dans `data/races/` et `data/classes/` ([[Décision — Pipeline de contenu]]).

**Valeurs de `base_potentials` (fixées — défaut 80 partout où non listé) :**

| Race | 120 | 60 |
|---|---|---|
| Humain | *(aucun — 90 partout : le polyvalent)* | — |
| Elfe | domaines de magie, Méditation, Contrôle du Mana | Forge, Encaissement |
| Nain | Forge, Minage, Taille de pierre, Encaissement | domaines de magie, Discrétion |
| Sylvide | Herboristerie, Agriculture, domaine Vie, Alchimie | Forge, Encaissement |
| Cendreux | Forge, domaine Feu, Encaissement | domaine Eau/Glace, Discrétion |
| Échomorphe | Discrétion, Lecture, domaine Espace | *(tout le reste à 70 — le −10 % d'XP de C.2)* |

| Classe | 120 | 60 |
|---|---|---|
| Guerrier | Épée, Bouclier, Deux Mains, Encaissement | domaines de magie, Alchimie |
| Mage | domaines de magie, Méditation, Contrôle du Mana | armes lourdes (Masse, Hache, Deux Mains) |
| Artisan | Forge, Menuiserie, Tissage, Taille de pierre, Cuisine | armes lourdes, domaines de magie |
| Chasseur | Arc, Arbalète, Dressage, Discrétion, Herboristerie | Forge, Encaissement |
| Marchand | Négociation, Leadership, Lecture, Charisme | armes lourdes, Minage |
| Vagabond | *(aucun — 100 partout : la polyvalence brute)* | — |

Race et classe **s'additionnent** : le plancher final est la moyenne des deux valeurs quand elles diffèrent (un Nain Mage a 90 en Forge et 90 en magie — ni spécialiste ni nul). C'est ce qui rend les 36 combinaisons mécaniquement distinctes ([[Potentiel]]).

**Aucune restriction durable ([[Création de personnage]]) :** la classe détermine **uniquement des bonus de stats/équipement de départ** — pas de plafond ni de pénalité liés à la classe une fois en jeu, cohérent avec la progression 100 % par l'usage.

**Équipement initial ([[Début de partie]]) :** kit de la classe, rien d'autre.

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Début de partie]], [[Stats de personnage]]
- **Voir aussi** : [[Races]], [[Compétences — liste]], [[Qualité d'artisanat]], [[Commerce et boutiques]], [[Grimoires et manuels]]
