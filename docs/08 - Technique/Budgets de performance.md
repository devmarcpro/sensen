---
aliases: ["E.14", "Annexe E.14", "Budgets de performance", "Cibles de performance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les chiffres voxel (meshing < 4 ms/chunk, 8 Ko/chunk 16³) sont retirés — archivés dans le GDD source. Les budgets de rendu tuiles + billboards proposés : [[Décision — Budgets et critères de performance tactiques]].

Les cibles chiffrées de performance.

**Budgets confirmés (indépendants du pivot) :**
- **Tick complet : < 8 ms** (marge sur les 100 ms du tick).
- **Entités actives simultanées par zone : ~64.**
- Rayon de chargement : **8 chunks** autour du joueur par défaut.

**Budgets du rendu tactique ([[Décision — Budgets et critères de performance tactiques]]) :** 60 fps à rayon 8 chunks de tuiles ; mutation de tuile < 1 ms de re-render local, jamais de frame > 16 ms ; 200 billboards paperdoll animés sans chute de frame ; chunk généré < 2 ms en thread ; étage de donjon < 100 ms ; mémoire chunk 32×32 ≈ 7 Ko.

Si un chemin chaud GDScript est trop lent : passer cette partie (et elle seule) en GDExtension/Rust — **décision au profilage, pas avant** ([[Optimisation — principes]]).

La stratégie d'optimisation complète, système par système, est consolidée en **Annexe G** ([[Optimisation — principes]] et suivantes), **qui fait autorité en cas de divergence**.

**Critères de validation par étape :** [[Ordre de vérification]].

> [!success] Codé le 2026-08-31 — le tick sous les 8 ms, mesuré
> `test_budgets` mesure le pas de simulation (< 8 ms), la génération d'étage, d'objet à affixes et le recalcul de stats. Les budgets de rendu se lisent avec `capture.tscn --disable-vsync` (moyenne et pire image imprimées).

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Boucle de tick]]
- **Alimente** : [[Optimisation — principes]], [[Entités et pathfinding — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Décision — Structure de données de la grille]], [[Éclairage]], [[Génération procédurale — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Risques majeurs]]
