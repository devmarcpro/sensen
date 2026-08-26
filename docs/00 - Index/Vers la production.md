---
aliases: ["Vers la production", "Roadmap de pré-production", "Ce qui manque"]
tags: [index, production, à-trancher]
domaine: index
statut: à-trancher
etape: 0
---

Ce qui reste à modifier dans le design, et ce qui manque pour lancer la production. État au 2026-08-26 — à cocher au fil de l'eau.

## 1. ✅ Validé — les 8 décisions post-pivot (2026-08-26, sur délégation)

- [x] [[Décision — Structure de données de la grille]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Pièces en 2D]] · [[Décision — Altitude sur 21 niveaux]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Minimap en 2D]]

## 2. Le document du prototype de combat (étape 0)

[[Ordre de construction]] : *« Prototype de combat isolé (**document séparé**) — le combat est-il bon ? Rien ne démarre avant un oui. »*
- [x] **Les sept trous du combat sont tranchés** (2026-08-26) : [[Décision — Multi-ennemis et jauge]], [[Décision — Vocabulaire d'attaque des créatures]], [[Décision — Fuite et désengagement]], [[Décision — Chaîne côté ennemis]], [[Décision — Boucliers]], [[Décision — Projectiles]], [[Décision — Esquive active]].
- [x] **Le document est rédigé** : [[Prototype de combat — spécification]] — périmètre, contenu exact, 12 jalons d'implémentation, critère de « oui » mesurable et qualitatif.

## 3. À trancher au playtest (implémentable sans — ne bloque pas)

- [ ] [[Ouvert — Axe des niveaux de recette]] · [[Ouvert — Répartitions Arcane Espace Corruption]] · [[Ouvert — Fourchettes des gemmes]] · [[Ouvert — Compensation de l'arme mixte]] · [[Ouvert — Saisons]]
- [ ] Questions de contenu différables : [[Ouvert — Taille des salles de donjon]], [[Ouvert — Réapparition d'un donjon]], [[Ouvert — Tiers de monstres rares]], [[Ouvert — Interprétation dureté et qualité]] (à formaliser).

## 4. Contenu à produire (données — nécessaire par étape, pas au jour 1)

- [x] **5 modules du domaine Métal** — au catalogue [[Modules]] (2026-08-26).
- [x] **Catalogue des actions de créatures** : 24 actions + 2 règles, affectations pour les 34 créatures ([[Actions des créatures]], 2026-08-26).
- [x] **Onyx** ajouté au catalogue des gemmes et à la palette (2026-08-26).
- [x] **Recettes de composants** : matrice complète bases/exotiques/sources ([[Recettes de composants]], 2026-08-26).
- [x] **Affinités de cuisine** : table complète, le Feu vient de la cuisson et le Métal du sel ([[Décision — Affinités de cuisine]], 2026-08-26).
- [x] **Surcharges Wu Xing** : les 154 matériaux passés en revue, table complète ([[Décision — Surcharges Wu Xing des matériaux]], 2026-08-26).
- [x] **Pools de noms** : les 9 cultures restantes écrites ([[Pools de noms des cultures]], 2026-08-26).
- [ ] Traductions en/ja/zh — les clés `tr()` existent dès le jour 1, les textes peuvent suivre ([[Localisation]]).

## 5. Assets à produire (aucun n'existe)

- [ ] **Étape 0-1 :** une silhouette paperdoll + quelques pièces d'équipement visibles ; les teintes des cinq éléments (jauge, effets — [[Direction artistique]]) ; l'UI de lisibilité (timeline, prévisualisations, journal — c'est LE game feel).
- [ ] **Étape 1 :** bibliothèques de parties ([[Squelette modulaire et points d'attache]]) : humanoïde 12 têtes / 8 torses / 8 bras / 8 jambes, puis quadrupède/volant/amorphe.
- [ ] **Étape 2 :** premiers prefabs de donjon (2-3 salles + connecteurs suffisent pour valider le pipeline).
- [ ] Police UI à couverture CJK (type Noto Sans CJK) testée dans les 4 langues ([[Localisation]]).

## 6. Chantier technique (le squelette existe, le code non)

- [x] **Pipeline de contenu décidé et squeletté** ([[Décision — Pipeline de contenu]]) : `godot/data/` contient les 24 catalogues avec leurs `_template.json` et son README — ajouter du contenu = ajouter un fichier JSON.

- [ ] Projet Godot 4.x : squelette en place (`godot/`, arborescence D.1 — [[Arborescence du projet]]). À l'ouverture du chantier : autoloads GameData/EventBus/TickManager en premier ([[Décisions d'architecture]], [[Simulation à ticks]]), validation de schémas au boot, `tr()` dès le premier écran.
- [ ] Les quatre [[Contraintes permanentes]] s'appliquent dès la première ligne — en particulier serveur autoritaire en solo et zéro `_process(delta)` dans la logique.
- [ ] Critère de perf avant chaque étape ([[Ordre de vérification]]).

## 7. Gouvernance du design

- [x] Le coffre `docs/` est la **source de vérité** ; `archive/SENSEN_GDD.md` est figé (il contient encore le texte voxel — c'est voulu, c'est une archive).
- [ ] À chaque décision prise (propositions, playtest) : mettre à jour la note concernée, retirer la mention « proposé », passer le `statut` à `décidé`.

## Le chemin critique, en une ligne

**~~Valider P2 + P7~~ ✅ → ~~écrire le document du prototype de combat (et trancher les 7 trous)~~ ✅ → ~~produire les 5 modules Métal + le catalogue d'actions de créatures~~ ✅ → **la silhouette paperdoll → coder l'étape 0**** ([[Prototype de combat — spécification]], jalon 1). Tout le reste peut suivre la cadence des 11 étapes.

## Liens
- **Dépend de** : [[Ordre de construction]], [[Héritage voxel — audit]], [[Trous connus du combat]]
- **Alimente** : [[Ordre de vérification]], [[Carte — Ouvert]]
- **Voir aussi** : [[Contraintes permanentes]], [[Décisions fondatrices]], [[Arborescence du projet]]
