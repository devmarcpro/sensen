---
aliases: ["Vers la production", "Roadmap de pré-production", "Ce qui manque"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 0
---

**Le design est complet et décidé.** Il ne reste ni question bloquante ni valeur à inventer : tout ce qui était ouvert porte une décision ou un défaut chiffré. Ce qui suit est l'état de production — ce qui est fait, et ce qui reste à *produire* (assets, code).

> [!failure] Bloquant trouvé le 2026-08-26
> **Le catalogue [[Modules]] n'est pas transcrivible en l'état** : 0/61 entrées portent un `cout_ticks`, et onze emploient des tours ou des mécaniques supprimées. Voir [[Décision — Transcription du catalogue de modules]]. C'est le premier travail avant l'étape 0, puisque le prototype de combat en dépend.

## 1. ✅ Validé — les 8 décisions post-pivot (2026-08-26, sur délégation)

- [x] [[Décision — Structure de données de la grille]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Pièces en 2D]] · [[Décision — Altitude sur 21 niveaux]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Minimap en 2D]]

## 2. Le document du prototype de combat (étape 0)

[[Ordre de construction]] : *« Prototype de combat isolé (**document séparé**) — le combat est-il bon ? Rien ne démarre avant un oui. »*
- [x] **Les sept trous du combat sont tranchés** (2026-08-26) : [[Décision — Multi-ennemis et jauge]], [[Décision — Vocabulaire d'attaque des créatures]], [[Décision — Fuite et désengagement]], [[Décision — Chaîne côté ennemis]], [[Décision — Boucliers]], [[Décision — Projectiles]], [[Décision — Esquive active]].
- [x] **Le document est rédigé** : [[Prototype de combat — spécification]] — périmètre, contenu exact, 12 jalons d'implémentation, critère de « oui » mesurable et qualitatif.

## 3. ✅ Défauts fixés pour toutes les questions de playtest

Chacune porte désormais une **valeur chiffrée implémentable** — le code ne se pose aucune question, le playtest ajuste ([[Carte — Ouvert]]) :
- [x] [[Ouvert — Axe des niveaux de recette]] (stabilité du jet) · [[Ouvert — Compensation de l'arme mixte]] (choix du segment) · [[Ouvert — Répartitions Arcane Espace Corruption]] (vecteurs A.4.6) · [[Ouvert — Fourchettes des gemmes]] (A.12 + 36 gabarits) · [[Ouvert — Saisons]] (non incluses)
- [x] [[Ouvert — Taille des salles de donjon]] (24 prefabs) · [[Ouvert — Réapparition d'un donjon]] (règle des foyers) · [[Ouvert — Tiers de monstres rares]] (un tier) · [[Ouvert — Interprétation dureté et qualité]] (clos)

## 4. Contenu à produire (données — nécessaire par étape, pas au jour 1)

- [x] **5 modules du domaine Métal** — au catalogue [[Modules]] (2026-08-26).
- [x] **Catalogue des actions de créatures** : 24 actions + 2 règles, affectations pour les 19 races animales ([[Actions des créatures]], 2026-08-26).
- [x] **Onyx** ajouté au catalogue des gemmes et à la palette (2026-08-26).
- [x] **Recettes de composants** : matrice complète bases/exotiques/sources ([[Recettes de composants]], 2026-08-26).
- [x] **Affinités de cuisine** : table complète, le Feu vient de la cuisson et le Métal du sel ([[Décision — Affinités de cuisine]], 2026-08-26).
- [x] **Surcharges Wu Xing** : les 154 matériaux passés en revue, table complète ([[Décision — Surcharges Wu Xing des matériaux]], 2026-08-26).
- [x] **Pools de noms** : les 9 cultures restantes écrites ([[Pools de noms des cultures]], 2026-08-26).
- [ ] Traductions en/ja/zh — les clés `tr()` existent dès le jour 1, les textes peuvent suivre ([[Localisation]]).

## 4 bis. Annexe H — élevage, génétique et collection *(intégrée le 2026-08-26)*

- [x] **15 notes** : mécanismes ([[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]]), contenu ([[Catalogue des groupes d'élevage]], vivarium ×3), moteur ([[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]]), et le socle des êtres ([[Blocs de l'être]], [[Apparence — données et équipement]], [[Rôles de l'être]]).
- [x] **Catalogue `species/`** squeletté avec son template ([[Décision — Pipeline de contenu]]).
- [x] **Saisons activées** à l'étape 10 — [[Décision — Saisons activées à l'étape 10]] renverse [[Ouvert — Saisons]].
- [ ] **Assets d'élevage** (étape 10) : silhouettes 13×13 des 32 espèces d'insectes, 20 motifs procéduraux, écran de registre.
- [ ] Fiches `species/` des 6 groupes recommandés au lancement (un par famille).

## 4 ter. Les trois axes et les talents *(décidé le 2026-08-26)*

- [x] [[Les trois axes — race, classe, fonction]], [[Talents de race]], [[Talents de classe]], [[Fonctions]], [[Ouvert — Changer de personnage]] + 5ᵉ contrainte permanente.
- [x] **19 classes nommées et dotées d'un talent** ([[Classes]], [[Talents de classe]]) — 8 visibles en français évocateur, 11 cachées dont 2 technologiques.
- [x] **Bestiaire restructuré** : [[Créatures]] = 19 races animales, [[Profils de PNJ]] = combinaisons tirées.
- [ ] **Modules signature** de chaque classe cachée (au-delà du talent) — contenu, étape 4+.
- [ ] **Fiches de races cachées** : Vampire, Spectre, Lycanthrope (`data/races/`) — étape 4+.
- [ ] **Pools de classes par fonction** pour la génération de PNJ ([[Talents de classe]] : classes cachées ≈ 2 %) — étape 9.

## 5. Assets à produire (aucun n'existe)

- [ ] **Étape 0-1 :** une silhouette paperdoll + quelques pièces d'équipement visibles ; les teintes des cinq éléments (jauge, effets — [[Direction artistique]]) ; l'UI de lisibilité (timeline, prévisualisations, journal — c'est LE game feel).
- [ ] **Étape 1 :** bibliothèque du **rig humanoïde 14 segments** ([[Squelette modulaire et points d'attache]]) ≈ **92 sprites** (12 têtes ×3 vues, torses, bras haut/bas, mains, jambes haut/bas, pieds) + **40 sprites d'armure** (5 constructions × 8 segments) = **≈ 130 sprites pour tous les humains du jeu**. Puis quadrupède/volant/amorphe.
- [ ] **Étape 1 :** la table `data/rigs/humanoide.json` — ordre de calque et décalages d'ancrage pour 5 orientations (3 obtenues par miroir).
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
