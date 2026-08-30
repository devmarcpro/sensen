---
aliases: ["G.8", "Annexe G.8", "Ordre de vérification", "Critères de perf par étape"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les critères voxel d'origine (mutation de bloc, « façade 64 blocs 4px meshée < 4 ms ») et l'ancien ordre D.3 sont retirés — archivés dans le GDD source. Les critères ci-dessous suivent les 11 étapes tactiques ; chiffres décidés en [[Décision — Budgets et critères de performance tactiques]].

Un critère de performance à valider avant de passer à l'étape suivante. **Un critère raté = on optimise AVANT d'empiler le système suivant.**

**Le principe (conservé de G.8) :** chaque étape de [[Ordre de construction]] a son critère de perf AVANT de passer à la suivante, sur machine moyenne cible.

**Critères par étape ([[Décision — Budgets et critères de performance tactiques]]) :**

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
É11 2 joueurs LAN : mutation visible < 100 ms chez l'autre.
```

**Principe parallèle ([[Contraintes permanentes]]) :** *une brique à la fois, chacune avec un critère de sortie formulé AVANT de commencer.*

> [!success] Codé le 2026-08-31 — les critères mesurables sans écran ont un test
> `test_budgets` (suite) : É2 étage < 100 ms, É3 objet à affixes < 1 ms, É4 recalcul de stats < 0,5 ms, tick de simulation < 8 ms. Restent à l'œil ou au profil : les critères de rendu (fps, frames > 16 ms — `capture.tscn --disable-vsync` mesure déjà le coût moyen d'image) et le réseau (É11). La cellule de surface est mesurée dans `test_surface` (< 250 ms, budget de 32 ms différé).

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Budgets de performance]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Contraintes permanentes]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Réseau et sauvegarde — performance]], [[LOD de simulation]]
