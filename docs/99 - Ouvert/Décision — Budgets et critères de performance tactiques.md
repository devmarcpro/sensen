---
aliases: ["Décision — Budgets et critères de performance tactiques", "Proposition — Budgets et critères de performance tactiques", "Budgets tactiques", "Critères tactiques"]
tags: [ouvert, proposition, héritage-voxel, technique, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Budgets de performance]] chiffre le meshing voxel (< 4 ms/chunk, 8 Ko/chunk) et [[Ordre de vérification]] valide des étapes voxel (« façade 64 blocs 4px meshée < 4 ms ») sur l'ancien ordre D.3. Il faut des budgets et des critères pour le rendu tuiles + billboards et les 11 étapes tactiques.

## Budgets proposés

```
Tick complet            : < 8 ms                       (conservé)
Entités actives/zone    : ~64                          (conservé)
Rendu                   : 60 fps, rayon 8 chunks de tuiles
                          (~256×256 tuiles chargées autour du joueur)
Mutation de tuile       : re-render local < 1 ms, jamais de frame > 16 ms
Billboards              : 200 sprites paperdoll animés sans chute de frame
Génération d'un chunk   : < 2 ms (en thread)
Étage de donjon         : généré < 100 ms ; transition d'étage < 250 ms
Mémoire chunk 32×32     : ~7 Ko (cf. Proposition — Structure de données)
```

## Critères de validation par étape (remplace G.8)

Un critère de perf **avant** de passer à l'étape suivante — le principe de [[Ordre de vérification]] est conservé, la liste suit désormais [[Ordre de construction]] :

```
É0  Prototype de combat : grille 32×32 + 10 entités, 60 fps,
    prévisualisations et timeline sans latence perceptible.
É1  Paperdoll : 50 créatures en billboards composés < 4 ms de rendu.
É2  Donjon : étage généré < 100 ms, transition < 250 ms.
É3  Loot : génération d'un objet à affixes < 1 ms.
É4  Progression : recalcul complet des stats d'un personnage < 0.5 ms
    (le résolveur E.4 est appelé partout).
É8  Monde : streaming en déplacement rapide, aucune frame > 16 ms ;
    voyage rapide + chargement de cellule < 1 s.
É9  100 PNJ en niveau logique ≈ coût de 3 PNJ pleins (cf. E.18).
É11 2 joueurs LAN : mutation visible < 100 ms chez l'autre. (conservé)
```

## Ce que ça préserve

La règle de [[Ordre de vérification]] (*un critère raté = on optimise avant d'empiler*), les budgets de simulation de [[Budgets de performance]], et tous les principes de [[Optimisation — principes]] — dont « GDExtension/Rust au profilage, jamais préventivement » (candidats probables révisés : bruit de génération, A*, compositing de billboards).

## Ce qui reste à calibrer

Tous les chiffres sont des ordres de grandeur à confronter à la machine cible — c'est le rôle du profilage, pas du document.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Budgets de performance]], [[Ordre de vérification]], [[Ordre de construction]]
- **Alimente** : [[Optimisation — principes]], [[Entités et pathfinding — performance]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[LOD de simulation]]
