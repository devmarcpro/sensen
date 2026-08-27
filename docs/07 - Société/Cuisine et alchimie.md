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

**Contenu à produire :** [[Décision — Affinités de cuisine]].

> [!success] Codé le 2026-08-28 — l'alchimie (reliquat de l'étape 10)
> **Parties de créatures** : toute bête tuée laisse, avec sa dépouille, **une partie** tirée parmi œil, peau, griffe, dent, os (`combat_rules.alchimie.parties`, chacune orientée vers une stat : œil → Perception, griffe → Force, dent → Dextérité, peau → Endurance, os → Volonté). Ce sont des consommables empilables (`items/oeil.json`…) — pas encore des matériaux paramétriques (la valeur de la stat de la créature source n'est pas portée : simplification). **Distiller** à l'Alambic (compétence Alchimie) : une partie + une culture (toute plante cultivée, entrée `tag: culture` des recettes) → une **potion** de la stat correspondante ; qualité d'artisanat (A.3) sur Alchimie : **durée = 3 000 ticks × qualité**, **intensité** : qualité ≥ 1,3 → potion *forte* (+6 au lieu de +3). Les statuts portent désormais des modificateurs `stat:<nom>` (add) pris en compte par `Etres.recalculer` à l'application et à l'expiration.

> [!success] Codé le 2026-08-28 — viandes et parties paramétriques
> À la mort d'une créature, sa **viande** porte un `potentiel` dérivé de sa fiche (+1 sur sa stat la plus haute) et une `puissance = stat / 10` ; sa **partie** porte la puissance de la stat qu'elle oriente (griffe → Force du loup / 10…). Les piles ne fusionnent qu'à puissance et potentiel égaux (une griffe d'ours et une griffe de renard restent deux piles). **Plats** : `potentiel = potentiel de la recette + Σ potentiel des ingrédients` (la nutrition × qualité reste le multiplicateur à l'ingestion). **Potions** : la puissance de la partie multiplie l'ajout du statut (`+3 × puissance`, `+6 × puissance` pour une forte) — `Etres.recalculer` lit la puissance portée par le statut actif. L'harmonie Wu Xing des plats (×1,2 à cinq éléments) n'est pas codée.

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Stations de transformation]], [[Potentiel]], [[Faim]]
- **Alimente** : [[Nourriture, potentiel et potions]], [[Potions]], [[Nourriture]], [[Statuts]]
- **Voir aussi** : [[Wu Xing hors combat]], [[Schéma créature]], [[Catalogue matériaux — Paramétriques]], [[Plantes]], [[Agriculture et élevage]], [[Résolveur de modificateurs]], [[Décision — Affinités de cuisine]]
