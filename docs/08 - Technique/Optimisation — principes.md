---
aliases: ["G.1", "Annexe G.1", "Annexe G", "Optimisation", "Principes transversaux"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : candidats GDExtension et files de travail révisés pour la grille 2D (plus de meshing). Les principes transversaux sont inchangés.

Les cinq principes transversaux d'optimisation — ceux qu'on ne peut pas rattraper après coup.

*Consolidation des décisions de performance. Règle d'or : mesurer avant d'optimiser (profiler Godot), mais ARCHITECTURER pour l'optimisation dès le jour 1 — les points ci-dessous sont ceux qu'on ne peut pas rattraper après coup. [[Budgets de performance]] reste valide ; G détaille le "comment".*

**L'annexe G fait autorité sur les questions de performance** (en cas de divergence avec [[Budgets de performance]]).

```
- GDScript TYPÉ partout (annotations de types : gain réel d'interpréteur,
  gratuit). Chemins chauds identifiés au profilage → GDExtension/Rust,
  jamais préventivement. Candidats probables : bruit de génération, A*,
  compositing de billboards, éclairage 2D.
- AUCUNE allocation dans les boucles par tick : pools d'objets
  (entités, projectiles, particules), tableaux préalloués réutilisés,
  PackedByteArray/PackedInt32Array pour les données de grille (jamais des
  Array de Variant).
- TIME-SLICING : chaque système lourd a un budget par tick et une file
  de travail reportable (éclairage, nav-grille, pathfinding,
  liquides, détection de pièces). Rien ne "finit coûte que coûte" dans
  la même frame.
- Threads : génération, éclairage et sauvegarde HORS thread
  principal (WorkerThreadPool Godot). Le thread principal ne fait que :
  tick de gameplay, upload des rendus prêts, rendu, UI.
- Tout est SEEDÉ et déterministe → jamais besoin de stocker ce qui est
  regénérable (principe déjà acté E.10, il vaut pour tout).
```

**Les huit sections de l'annexe G :** [[Optimisation — principes]] (G.1) · [[Voxels — mémoire et meshing]] (G.2) · [[Éclairage]] (G.3) · [[Génération procédurale — performance]] (G.4) · [[Entités et pathfinding — performance]] (G.5) · [[Simulation du monde — performance]] (G.6) · [[Réseau et sauvegarde — performance]] (G.7) · [[Ordre de vérification]] (G.8) · [[Stratification verticale]] et [[Minerais par profondeur]] (G.9).

## Liens
- **Dépend de** : [[Budgets de performance]], [[Décisions d'architecture]]
- **Alimente** : [[Voxels — mémoire et meshing]], [[Éclairage]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Sauvegarde]], [[Simulation à ticks]], [[Arborescence du projet]], [[Risques majeurs]]
