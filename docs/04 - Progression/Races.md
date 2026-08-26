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

**Potentiels de base ([[Potentiel]]) :** chaque race ET chaque classe définit ses potentiels de base par stat et par familles de compétences (champ `base_potentials` en données) — ex. Nain : Forge/Minage 120, Magie 60 ; Mage : domaines de magie 120, armes lourdes 60. Les valeurs complètes vivent dans `data/races/` et `data/classes/` (défaut 80 partout où non spécifié).

**Cultures dédiées ([[Cultures de nommage]]) :** les races « originales » (Sylvide, Cendreux, Échomorphe) ont chacune une culture qui leur est propre (peu ou pas partagée), tandis qu'Humain/Elfe/Nain piochent parmi un plus large éventail de cultures inspirées du monde réel — Sylvestre (Sylvide), Ignée (Cendreux), Résonance (Échomorphe).

**Race dominante d'un royaume ([[Génération des royaumes PNJ]]) :** choisie selon le biome de la capitale (affinités déclarées dans les données de race — ex. nains → montagnes) ; ~90 % de la population, et l'exclusivité des rôles de gouvernance.

**Espérance de vie ([[Âge des PNJ]]) :** donnée `lifespan` par race, avec variance ±15 %.

**Réputation par race ([[Réputation et relations]]) :** chaque race a sa propre perception du joueur ; les rivalités entre races sont déclarées en données (`rivals`).

## Liens
- **Dépend de** : [[Création de personnage]]
- **Alimente** : [[Potentiel]], [[Stats de personnage]], [[Génération des royaumes PNJ]], [[Cultures de nommage]], [[Âge des PNJ]]
- **Voir aussi** : [[Classes]], [[Réputation et relations]], [[Schéma unifié créature-PNJ]], [[Faim]], [[Culture de nommage — schéma]]
