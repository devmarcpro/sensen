---
aliases: ["Vers la production", "Roadmap de pré-production", "Ce qui manque"]
tags: [index, production, à-trancher]
domaine: index
statut: à-trancher
etape: 0
---

Ce qui reste à modifier dans le design, et ce qui manque pour lancer la production. État au 2026-08-26 — à cocher au fil de l'eau.

## 1. À valider — les 8 propositions post-pivot

Le nettoyage de l'héritage voxel ([[Héritage voxel — audit]]) laisse 8 propositions chiffrées, intégrées dans les notes avec la mention « proposé ». **Les valider (ou les amender) est la première décision à prendre** — aucune n'est bloquante pour commencer l'étape 0, mais P2, P5 et P7 le deviennent vite :

- [ ] [[Proposition — Structure de données de la grille]] — **bloquant étape 0-1** (c'est la fondation du code)
- [ ] [[Proposition — Budgets et critères de performance tactiques]] — **bloquant étape 0** (le critère de sortie du prototype)
- [ ] [[Proposition — Sculpture en pixel art]] — bloquant étape 1 (pipeline d'assets)
- [ ] [[Proposition — Prefabs de donjon en tuiles]] — bloquant étape 2
- [ ] [[Proposition — Pièces en 2D]] — bloquant étape 7
- [ ] [[Proposition — Altitude sur 21 niveaux]] — bloquant étape 8
- [ ] [[Proposition — Minerais et strates après le pivot]] — bloquant étape 8
- [ ] [[Proposition — Minimap en 2D]] — bloquant étape 8

## 2. À écrire — le document du prototype de combat (étape 0)

[[Ordre de construction]] : *« Prototype de combat isolé (**document séparé**) — le combat est-il bon ? Rien ne démarre avant un oui. »* **Ce document n'existe pas encore.** C'est le vrai déclencheur de la production. Il doit fixer :
- le périmètre exact du prototype (quelles armes, quels modules, quelles créatures, quelle grille) ;
- le critère de « oui » — comment on jugera honnêtement que le combat est bon ;
- et trancher au passage les **sept trous connus du combat** ([[Trous connus du combat]]) : [[Ouvert — Multi-ennemis et jauge]], [[Ouvert — Vocabulaire d'attaque des créatures]], [[Ouvert — Fuite et désengagement]], [[Ouvert — Chaîne côté ennemis]], [[Ouvert — Boucliers]], [[Ouvert — Projectiles]], [[Ouvert — Esquive active]].

## 3. À trancher au playtest (implémentable sans — ne bloque pas)

- [ ] [[Ouvert — Axe des niveaux de recette]] · [[Ouvert — Répartitions Arcane Espace Corruption]] · [[Ouvert — Fourchettes des gemmes]] · [[Ouvert — Compensation de l'arme mixte]] · [[Ouvert — Saisons]]
- [ ] Questions de contenu différables : [[Ouvert — Taille des salles de donjon]], [[Ouvert — Réapparition d'un donjon]], [[Ouvert — Tiers de monstres rares]], [[Ouvert — Interprétation dureté et qualité]] (à formaliser).

## 4. Contenu à produire (données — nécessaire par étape, pas au jour 1)

- [ ] **5 modules du domaine Métal** ([[Ouvert — Modules du domaine Métal]]) — **nécessaire dès l'étape 0** si le prototype teste la rotation complète des cinq éléments.
- [ ] L'**Onyx** manque au catalogue des gemmes et à la palette (cité par la table de sertissage — [[Catalogue matériaux — Gemmes]]). Étape 3.
- [ ] Recettes de composants × familles + sources exotiques ([[Ouvert — Recettes de composants par famille]]). Étape 6.
- [ ] Affinités élémentaires des ingrédients de cuisine ([[Ouvert — Affinités élémentaires de cuisine]]). Étape 10.
- [ ] Surcharges `wuxing` des 153 matériaux ([[Ouvert — Surcharges wuxing des matériaux]]). Étape 6.
- [ ] Pools de noms des 9 cultures restantes ([[Ouvert — Pools de noms des cultures]]). Étape 9.
- [ ] Traductions en/ja/zh — les clés `tr()` existent dès le jour 1, les textes peuvent suivre ([[Localisation]]).

## 5. Assets à produire (aucun n'existe)

- [ ] **Étape 0-1 :** une silhouette paperdoll + quelques pièces d'équipement visibles ; les teintes des cinq éléments (jauge, effets — [[Direction artistique]]) ; l'UI de lisibilité (timeline, prévisualisations, journal — c'est LE game feel).
- [ ] **Étape 1 :** bibliothèques de parties ([[Squelette modulaire et points d'attache]]) : humanoïde 12 têtes / 8 torses / 8 bras / 8 jambes, puis quadrupède/volant/amorphe.
- [ ] **Étape 2 :** premiers prefabs de donjon (2-3 salles + connecteurs suffisent pour valider le pipeline).
- [ ] Police UI à couverture CJK (type Noto Sans CJK) testée dans les 4 langues ([[Localisation]]).

## 6. Chantier technique (le squelette existe, le code non)

- [ ] Projet Godot 4.x : squelette en place (`godot/`, arborescence D.1 — [[Arborescence du projet]]). À l'ouverture du chantier : autoloads GameData/EventBus/TickManager en premier ([[Décisions d'architecture]], [[Simulation à ticks]]), validation de schémas au boot, `tr()` dès le premier écran.
- [ ] Les quatre [[Contraintes permanentes]] s'appliquent dès la première ligne — en particulier serveur autoritaire en solo et zéro `_process(delta)` dans la logique.
- [ ] Critère de perf avant chaque étape ([[Ordre de vérification]]).

## 7. Gouvernance du design

- [x] Le coffre `docs/` est la **source de vérité** ; `archive/SENSEN_GDD.md` est figé (il contient encore le texte voxel — c'est voulu, c'est une archive).
- [ ] À chaque décision prise (propositions, playtest) : mettre à jour la note concernée, retirer la mention « proposé », passer le `statut` à `décidé`.

## Le chemin critique, en une ligne

**Valider P2 + P7 → écrire le document du prototype de combat (et trancher les 7 trous) → produire les 5 modules Métal + la silhouette paperdoll → coder l'étape 0.** Tout le reste peut suivre la cadence des 11 étapes.

## Liens
- **Dépend de** : [[Ordre de construction]], [[Héritage voxel — audit]], [[Trous connus du combat]]
- **Alimente** : [[Ordre de vérification]], [[Carte — Ouvert]]
- **Voir aussi** : [[Contraintes permanentes]], [[Décisions fondatrices]], [[Arborescence du projet]]
