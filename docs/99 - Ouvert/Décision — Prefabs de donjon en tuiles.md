---
aliases: ["Décision — Prefabs de donjon en tuiles", "Proposition — Prefabs de donjon en tuiles", "Prefabs en tuiles"]
tags: [ouvert, proposition, héritage-voxel, monde, décidé]
domaine: monde
statut: décidé
etape: 2
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Génération de donjon]] dimensionne les salles en cubes (« petite 8³ … immense 32×32×16 ») et les escaliers en « offset vertical −16, aligné chunk » ; [[Salles et connecteurs]] référence des `vox_model` avec positions 3D. Les donjons tactiques sont des **grilles séparées en étages discrets** ([[Grille continue]]).

## La proposition

**Tailles en tuiles par étage — transposition directe :**

```
petite 8×8 · moyenne 16×16 · grande 24×24 · immense 32×32
```

Le sol reste **jamais forcément plat** : chaque tuile du prefab porte sa hauteur 0-20 relative (estrades, fosses, gradins — [[Hauteur de terrain ±10]]), ce qui préserve tout l'intérêt tactique des salles.

**Format des prefabs :** un **plan 2D par étage** — image indexée (PNG) ou grille JSON, 1 case = 1 tuile :
- une couche **matériau** en couleurs stand-in (#00FF00… remappées au thème, mécanisme inchangé — [[Squelette modulaire et points d'attache]]) ;
- une couche **hauteur** (valeurs relatives 0-20) ;
- des **tuiles-marqueurs typées** pour les points d'attache : `porte_nord/sud/est/ouest`, `cage_escalier` — plus de positions 3D.

**Escaliers :** un connecteur escalier lie `(étage n, tuile a) → (étage n+1, tuile b)`. Plus d'« offset vertical −16 » : le lien inter-étages est une donnée du graphe, pas une translation de volume. La génération étage par étage de [[Génération de donjon]] (déjà indépendante par étage) est inchangée.

**Schéma B.10 :** `vox_model` → `plan` ; `vertical_offset` supprimé, remplacé par le lien inter-étages ; `connectors[].position` devient une coordonnée de tuile 2D. `special_tags`, `floor_theme`, `size_category` inchangés.

## Ce que ça préserve

L'algorithme par graphe intégral (attache → connecteur → salle → collision AABB en 2D → connexité par construction → boss au plus profond), la formule de profondeur, le thème/palette, la génération paresseuse par étage.

## Ce qui reste à trancher

Rejoint [[Ouvert — Taille des salles de donjon]] : taille de la bibliothèque de prefabs au lancement, et le format retenu (PNG indexé vs JSON — le PNG s'édite dans n'importe quel éditeur pixel art, cohérent avec la production des sprites).

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Génération de donjon]], [[Salles et connecteurs]], [[Grille continue]]
- **Alimente** : [[Donjons — structure et intégration]], [[Ouvert — Taille des salles de donjon]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[Hauteur de terrain ±10]]
