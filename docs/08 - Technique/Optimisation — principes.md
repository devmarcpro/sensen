---
aliases: ["G.1", "Annexe G.1", "Annexe G", "Optimisation", "Principes transversaux"]
tags: [technique, performance, décidé, héritage-voxel]
domaine: technique
statut: décidé
etape: 0
---

> [!warning] Héritage voxel
> Les principes transversaux (GDScript typé, zéro allocation, time-slicing, threads, tout seedé) restent valables tels quels. Héritage : les « candidats probables » meshing/éclairage 3D, et « PackedByteArray pour les données voxel » — à relire pour la grille 2D.
> — Classement complet : [[Héritage voxel — audit]].

Les cinq principes transversaux d'optimisation — ceux qu'on ne peut pas rattraper après coup.

*Consolidation des décisions de performance. Règle d'or : mesurer avant d'optimiser (profiler Godot), mais ARCHITECTURER pour l'optimisation dès le jour 1 — les points ci-dessous sont ceux qu'on ne peut pas rattraper après coup. [[Budgets de performance]] reste valide ; G détaille le "comment".*

**L'annexe G fait autorité sur les questions de performance** (en cas de divergence avec [[Budgets de performance]]).

```
- GDScript TYPÉ partout (annotations de types : gain réel d'interpréteur,
  gratuit). Chemins chauds identifiés au profilage → GDExtension/Rust,
  jamais préventivement. Candidats probables : meshing, éclairage,
  bruit de génération, A*.
- AUCUNE allocation dans les boucles par tick : pools d'objets
  (entités, projectiles, particules), tableaux préalloués réutilisés,
  PackedByteArray/PackedInt32Array pour les données voxel (jamais des
  Array de Variant).
- TIME-SLICING : chaque système lourd a un budget par tick et une file
  de travail reportable (meshing, éclairage, nav-grille, pathfinding,
  liquides, détection de pièces). Rien ne "finit coûte que coûte" dans
  la même frame.
- Threads : génération, meshing, éclairage et sauvegarde HORS thread
  principal (WorkerThreadPool Godot). Le thread principal ne fait que :
  tick de gameplay, upload de meshes prêts, rendu, UI.
- Tout est SEEDÉ et déterministe → jamais besoin de stocker ce qui est
  regénérable (principe déjà acté E.10, il vaut pour tout).
```

**Les huit sections de l'annexe G :** [[Optimisation — principes]] (G.1) · [[Voxels — mémoire et meshing]] (G.2) · [[Éclairage]] (G.3) · [[Génération procédurale — performance]] (G.4) · [[Entités et pathfinding — performance]] (G.5) · [[Simulation du monde — performance]] (G.6) · [[Réseau et sauvegarde — performance]] (G.7) · [[Ordre de vérification]] (G.8) · [[Stratification verticale]] et [[Minerais par profondeur]] (G.9).

## Liens
- **Dépend de** : [[Budgets de performance]], [[Décisions d'architecture]]
- **Alimente** : [[Voxels — mémoire et meshing]], [[Éclairage]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Sauvegarde]], [[Simulation à ticks]], [[Arborescence du projet]], [[Risques majeurs]]
