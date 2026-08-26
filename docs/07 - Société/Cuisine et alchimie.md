---
aliases: ["7.7", "7.7 Cuisine, alchimie et nourriture", "Cuisine", "Alchimie", "Viandes paramétriques"]
tags: [société, craft, décidé]
domaine: société
statut: décidé
etape: 10
---

Cuisiner pour la croissance long terme, distiller pour la puissance court terme — et une chasse qui devient un objectif en soi.

**Cuisine (station Cuisine, compétence Cuisine) :**
- Les recettes combinent des ingrédients (viandes, légumes, plantes, œufs...) en **plats**. Un plat porte : une valeur de **nutrition** (remplit la faim, [[Faim]]) et des **bonus de potentiel** ([[Potentiel]]) vers les stats liées à ses ingrédients.
- **La nutrition est le multiplicateur** (façon Elin) : `potentiel_gagné = Σ bonus des ingrédients × nutrition/100 × qualité du plat` — un plat raffiné vaut mieux que ses ingrédients crus, cuisiner a un vrai rendement.
- La qualité du plat suit la formule de qualité standard ([[Qualité d'artisanat]]) sur la compétence Cuisine.
- **Harmonie Wu Xing ([[Wu Xing hors combat]]/[[Domination et multiplicateurs]])** : chaque ingrédient porte une affinité élémentaire ; un plat couvrant les cinq éléments gagne **×1.2** en nutrition et potentiel — l'équilibre daoïste de l'assiette, mécanisé.

**Viandes (paramétriques par créature) :** chaque créature droppe **sa propre viande**, dont les bonus de potentiel dérivent des **stats de la créature source** (une viande d'ours brun donne du potentiel de Force/Endurance, une viande d'aigle de la Perception — formule [[Nourriture, potentiel et potions]]). Pas de contenu à la main : la viande est générée depuis la fiche de la créature ([[Schéma créature]]).

**Alchimie (station Alambic, compétence Alchimie) :**
- Les **potions** donnent des **bonus temporaires** (buffs à durée : stats, résistances, régénérations, effets spéciaux — via le système de statuts [[Statuts]] et de modificateurs [[Résolveur de modificateurs]]).
- Ingrédients : **parties de créatures** (yeux, peaux, griffes, dents, os... — droppées par les mobs, matériaux paramétriques [[Catalogue matériaux — Paramétriques]]) et **plantes** ([[Plantes]]) ; les propriétés de la partie/plante orientent l'effet de la potion (un œil → potions de Perception/vision, une griffe → potions de Force...).
- Qualité de la potion ([[Qualité d'artisanat]], compétence Alchimie) = durée et intensité du buff.

**Boucle complète :** chasser (parties + viandes spécifiques) + cultiver (plantes, [[Agriculture et élevage]]) → cuisiner (croissance long terme via potentiel) + distiller (puissance court terme via buffs) → progresser → chasser plus grand. La chasse d'une créature précise pour sa viande/ses parties devient un objectif en soi.

**Contenu à produire :** [[Ouvert — Affinités élémentaires de cuisine]].

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Stations de transformation]], [[Potentiel]], [[Faim]]
- **Alimente** : [[Nourriture, potentiel et potions]], [[Potions]], [[Nourriture]], [[Statuts]]
- **Voir aussi** : [[Wu Xing hors combat]], [[Schéma créature]], [[Catalogue matériaux — Paramétriques]], [[Plantes]], [[Agriculture et élevage]], [[Résolveur de modificateurs]], [[Ouvert — Affinités élémentaires de cuisine]]
