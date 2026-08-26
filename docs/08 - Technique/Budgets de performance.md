---
aliases: ["E.14", "Annexe E.14", "Budgets de performance", "Cibles de performance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

Les cibles chiffrées de performance.

Chunks visibles : rayon de 8 chunks (~128 blocs) par défaut. Meshing : **< 4 ms par chunk** (thread séparé, jamais sur le thread principal). Entités actives simultanées par zone : **~64**. Tick complet : **< 8 ms** (marge sur les 100 ms du tick). Mémoire d'un chunk plein non subdivisé : **8 Ko** (16³ × 2 o).

Si le meshing GDScript est trop lent : passer cette partie (et elle seule) en GDExtension/Rust — **décision au profilage, pas avant**.

La stratégie d'optimisation complète, système par système, est consolidée en **Annexe G** ([[Optimisation — principes]] et suivantes), **qui fait autorité en cas de divergence**.

**Critères de validation par étape :** [[Ordre de vérification]].

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Boucle de tick]]
- **Alimente** : [[Optimisation — principes]], [[Voxels — mémoire et meshing]], [[Entités et pathfinding — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Éclairage]], [[Génération procédurale — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Risques majeurs]]
