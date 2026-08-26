---
aliases: ["Carte des dépendances", "Dépendances"]
tags: [index, carte]
domaine: index
statut: décidé
etape: 0
---

Les grands systèmes du jeu et ce qui repose sur quoi — pour savoir ce qu'on casse en touchant à quelque chose.

## Les cinq socles

Cinq notes portent presque tout le reste. Y toucher se répercute partout.

| Socle | Ce qui en dépend directement |
|---|---|
| **[[Décisions fondatrices]]** | tout — c'est la note racine |
| **[[Data-driven design]]** | tous les schémas (Annexe B), [[Décisions d'architecture]], [[EventBus]], [[Localisation]] |
| **[[Simulation à ticks]]** | [[Boucle de tick]], [[Action-time à ticks]], [[Mana]], [[Faim]], [[IA des créatures]], [[Eau et liquides]], [[Simulation du monde — performance]] |
| **[[Wu Xing — cycles et vecteurs]]** | [[Jauge de chaîne Wu Xing]], [[Domination et multiplicateurs]], [[Craft compositionnel]], [[Armure par zone et constructions]], [[Cuisine et alchimie]], [[Modules]], [[Palier industriel]] |
| **[[Matériaux — 13 stats]]** | [[Application des stats de matériau]] → [[Stats d'armes]], [[Armure par zone et constructions]], [[Mana]], [[Météo]], [[Éclairage]], [[Agriculture et élevage]], [[Véhicules]], [[Eau et liquides]] |

## Les chaînes principales

**Chaîne du combat**
[[Simulation à ticks]] → [[Boucle de tick]] → [[Action-time à ticks]] → [[Combat tactique sur grille]] → { [[Zones de coup par dénivelé]] (← [[Hauteur de terrain ±10]]), [[Garde en posture]] ↔ [[Endurance]], [[Attaque lourde et télégraphe]] } → [[Pipeline de résolution du combat]] → [[XP de combat]]

**Chaîne Wu Xing**
[[Wu Xing — cycles et vecteurs]] → [[Domination et multiplicateurs]] → [[Jauge de chaîne Wu Xing]] → [[Cinq accès au cycle]] → { [[Armes fantomatiques]], [[Modificateurs d'affinité]] ← [[Loot — affixes, gemmes et rareté]] }
Et transversalement : [[Wu Xing hors combat]] → { [[Cuisine et alchimie]], [[Mana]] (coût par lieu), [[Craft compositionnel]] }

**Chaîne de progression**
[[Progression par l'usage]] → [[Potentiel]] → [[Double niveau combat et général]] → { [[Gabarit de quête]], [[Défense et raids]], [[Population et exploitation]] }
Alimentée par : [[XP de combat]], [[Récolte]], [[Qualité d'artisanat]], [[Lecture des livres]], [[Mana]]
Régulée par : [[Cuisine et alchimie]] → [[Nourriture, potentiel et potions]]

**Chaîne des objets**
[[Matériaux — 13 stats]] → [[Schéma matériau]] → [[Catégories de matériaux]] → [[Récolte]]
puis [[Craft compositionnel]] → [[Composants]] + [[Composant et recette d'obtention]] → [[Stats et qualité de l'assemblage]] → { [[Stats d'armes]], [[Armure par zone et constructions]] }
en parallèle : [[Loot — affixes, gemmes et rareté]] (loot-only) et [[Tables de sculpture]] (optionnel)

**Chaîne du monde**
[[Génération par couches de bruit]] + [[Catalogue des couches de bruit]] → [[Unification macro-micro]] → { [[Terrain spectaculaire]], [[Biomes — schéma]], [[Stratification verticale]] → [[Minerais par profondeur]] }
[[Grille continue]] → [[Hauteur de terrain ±10]] → { combat, [[Eau et liquides]], [[Destruction du terrain]] }
[[Niveau de danger]] → [[Dérive de la corruption]] → { [[Loot — affixes, gemmes et rareté]], [[Raids et menaces]], [[Villages PNJ — repeuplement et décimation]], [[Génération de donjon]] }

**Chaîne des êtres**
[[Schéma unifié créature-PNJ]] → [[Schéma créature]] → { [[IA des créatures]] → [[LOD de simulation]] → [[Abstraction hors-site]], [[Apprivoisement et recrutement]] → [[Compagnons]], [[Âge des PNJ]] → [[Familles et succession]] }

**Chaîne du royaume**
[[Claims et persistance]] → [[Rôles de cases]] → [[Expansion territoriale]] → [[Population et exploitation]] → [[Défense et raids]] → [[Raids et menaces]]
Économie : [[Prix suggéré]] → [[Commerce et boutiques]] → [[Boutique passive]] → [[Économie — sources et puits]] → [[Barèmes économiques]] → [[Entretien et taxes]]
Politique : [[Schéma royaume]] → [[Gouvernance, lois et diplomatie]] → [[Lois et infractions]] ; [[Génération des royaumes PNJ]] → [[Noms culturels]] → [[Génération de noms]]

## Les points de convergence

Quelques notes sont alimentées par un nombre inhabituel de systèmes — ce sont les carrefours à surveiller.

- **[[Application des stats de matériau]]** — les 13 stats irriguent mana, armure, météo, éclairage, agriculture, véhicules, chute, arcs, déplacement.
- **[[EventBus]]** — le point de découplage universel : *aucun système n'appelle directement un autre système de gameplay*.
- **[[Résolveur de modificateurs]]** — équipement, statuts, race, buffs, humeur passent tous par `Stats.get`.
- **[[Abstraction hors-site]]** — agriculture, boutiques, raids, jobs, nuit sautée s'y résolvent tous par formules.
- **[[Détection de pièces]]** — habitat du joueur, capacité des villages, contrats de construction, graphe de POI.
- **[[Jet de compétence universel]]** — lecture, dressage, négociation, discrétion, conquête, détection d'infraction.

## Ce qui ne dépend de rien d'autre

[[Pas de durabilité]], [[Explosions]], [[Public visé]], [[Ouvert — Audio et musique]].

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Ordre de construction]]
- **Voir aussi** : [[Sensen — Index général]], [[Contraintes permanentes]], toutes les cartes de domaine
