---
aliases: ["C.2", "Annexe C.2", "Races", "Races de départ"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

Les 6 races de lancement : trois classiques, trois originales.

| Race | Type | Bonus |
|---|---|---|
| Humain | Classique | +10 % XP de compétences (polyvalent) |
| Elfe | Classique | +2 Volonté, +1 Perception, régén mana +20 % |
| Nain | Classique | +2 Endurance, +1 Force, minage/forge +15 % |
| Sylvide | Original — peuple des forêts de mana | Photosynthèse (faim ralentie de moitié le jour), affinité végétale |
| Cendreux | Original — né des zones volcaniques | Immunisé aux dégâts de chaleur mineurs, +15 % forge |
| Échomorphe | Original — créature du bruit, mimétique | Peut changer ses parties de corps ([[Schéma unifié créature-PNJ]]) à volonté, -10 % XP |

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

**Cultures dédiées ([[Cultures de nommage]]) :** les races « originales » (Sylvide, Cendreux, Échomorphe) ont chacune une culture qui leur est propre (peu ou pas partagée), tandis qu'Humain/Elfe/Nain piochent parmi un plus large éventail de cultures inspirées du monde réel — Sylvestre (Sylvide), Ignée (Cendreux), Résonance (Échomorphe).

**Race dominante d'un royaume ([[Génération des royaumes PNJ]]) :** choisie selon le biome de la capitale (affinités déclarées dans les données de race — ex. nains → montagnes) ; ~90 % de la population, et l'exclusivité des rôles de gouvernance.

**Espérance de vie ([[Âge des PNJ]]) :** donnée `lifespan` par race, avec variance ±15 %.

**Réputation par race ([[Réputation et relations]]) :** chaque race a sa propre perception du joueur ; les rivalités entre races sont déclarées en données (`rivals`).

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Stats de personnage]], [[Génération des royaumes PNJ]], [[Cultures de nommage]], [[Âge des PNJ]]
- **Voir aussi** : [[Classes]], [[Réputation et relations]], [[Schéma unifié créature-PNJ]], [[Faim]], [[Culture de nommage — schéma]]
