---
aliases: ["Carte — Ouvert", "Carte Ouvert", "Questions ouvertes"]
tags: [index, carte]
domaine: index
statut: décidé
etape: 0
---

**Il ne reste aucune question bloquante.** Tout ce qui était ouvert a reçu soit une décision, soit un **défaut chiffré implémentable** — le code n'a rien à inventer. Cette carte liste ce qui reste révisable, et à quel titre. 44 notes.

## Décisions prises (le code s'appuie dessus)

**Post-pivot voxel — 8 décisions** ([[Héritage voxel — audit]])
[[Décision — Altitude sur 21 niveaux]] · [[Décision — Structure de données de la grille]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Pièces en 2D]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Minimap en 2D]]

**Combat — les 7 trous + l'esquive** ([[Trous connus du combat]])
[[Décision — Multi-ennemis et jauge]] · [[Décision — Vocabulaire d'attaque des créatures]] · [[Décision — Fuite et désengagement]] · [[Décision — Chaîne côté ennemis]] · [[Décision — Boucliers]] · [[Décision — Projectiles]] · [[Décision — Esquive active]]
→ et la spécification exécutable de l'étape 0 : **[[Prototype de combat — spécification]]**

**Architecture et contenu**
[[Décision — Pipeline de contenu]] · [[Décision — Surcharges Wu Xing des matériaux]] · [[Décision — Affinités de cuisine]] · **[[Décision — Saisons activées à l'étape 10]]** *(renverse [[Ouvert — Saisons]] — l'Annexe H rend les saisons load-bearing)*
Catalogues produits : [[Actions des créatures]] · [[Recettes de composants]] · [[Pools de noms des cultures]] · modules Métal et Onyx ([[Modules]], [[Catalogue matériaux — Gemmes]])

## Défauts fixés — révisables au playtest, jamais bloquants

Chacun porte une valeur chiffrée que le code applique telle quelle ; les réviser est du **tuning**, pas de la conception.

- [[Ouvert — Axe des niveaux de recette]] — stabilité du jet (variance resserrée, moyenne inchangée)
- [[Ouvert — Compensation de l'arme mixte]] — choix du segment + amortissement, test à ±15 %
- [[Ouvert — Répartitions Arcane Espace Corruption]] — vecteurs de A.4.6 retenus tels quels
- [[Ouvert — Fourchettes des gemmes]] — fourchettes de A.12 + 36 gabarits d'affixes
- [[Ouvert — Tiers de monstres rares]] — un seul tier (2 %, ×2.5, or)
- [[Ouvert — Réapparition d'un donjon]] — repeuplement par la règle des foyers, nouvelle seed
- [[Ouvert — Taille des salles de donjon]] — 24 prefabs, PNG à deux couches
- [[Ouvert — Saisons]] — non incluses ; la question ne peut se trancher qu'après la boucle agricole (étape 10)
- [[Ouvert — Interprétation dureté et qualité]] — **clos** (ambiguïté levée dans [[Qualité d'artisanat]])

## Extension culturelle — ouvert, non bloquant

- [[Ouvert — Feng shui, orientation du bâti et axe Yin-Yang]] — le Wu Xing mord sur six domaines et pas sur le bâti. Feng shui (décision spatiale) et Yin-Yang comme axe orthogonal (décision temporelle) ; bagua, qi et cultivation écartés. Aucune donnée nouvelle requise.

## Feature future — contrainte d'architecture immédiate

- [[Ouvert — Changer de personnage]] — incarner un compagnon, jouer une bête qu'on a élevée. La [[Contraintes permanentes|5ᵉ contrainte]] existe pour que ce soit trivial le jour venu.

## Ouvert par l'Annexe H — non bloquant

- [[Ouvert — Oiseaux chanteurs]] — le plus riche du catalogue, mais il faut une interface pour lire des chants. *À faire bien ou pas du tout.*
- [[Ouvert — Hybrides]] — ferait décoller la collection ; demande une table de paires compatibles.
- [[Ouvert — Cinquième locus visuel]] — le surmotif : ×20 de variétés, mais le registre n'est plus représentable en 2D.
- [[Ouvert — Équilibrage du contraste]] — 34/34/16/16 ou 40/40/20 ? Question **perceptuelle**, aucune simulation n'y répond.

## Ouvert par nature — hors périmètre du code

- [[Ouvert — Lore]] — noms propres, textes d'ambiance, mythologie : s'écrit au fil du contenu, le système l'absorbe sans code ([[Dialogue PNJ]]).
- [[Ouvert — Audio et musique]] — hors périmètre du document.
- [[Ouvert — Créatures fantastiques]] — extension de contenu pour les zones à haute corruption, *prévu sans changement de système*.
- [[Ouvert — Dark Continent]] — endgame retenu, non spécifié : *coûte du contenu, presque aucun système*.

## Liens
- **Voir aussi** : [[Sensen — Index général]], [[Vers la production]], [[Décisions fondatrices]], [[Héritage voxel — audit]]
- [[Décision — Grille de composition des sorts]] — l'idée du 2026-09-03 : composer un sort en emboîtant des formes dans une grille, pour interdire des combinaisons sans écrire d'interdit. Rien n'est engagé.
- [[Décision — Gestion de base, périmètres de récolte]] — l'idée du 2026-09-04 : une base façon Dwarf Fortress, des périmètres par type de récolte, des résidents assignés dessus, l'efficacité par les stats du PNJ et des tuiles ; d'abord le recrutement (codé), la vue de base, les compagnons.
