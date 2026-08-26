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

## Les derniers points, fixés

- **Format : PNG indexé**, deux fichiers par prefab — `<id>.png` (couche matériau en couleurs stand-in + tuiles-marqueurs d'attache) et `<id>_h.png` (couche hauteur, niveaux de gris 0-20). S'édite dans n'importe quel éditeur pixel art, se diffe visuellement, se relit à chaud (F5, [[Décision — Pipeline de contenu]]).
- **Bibliothèque au lancement : 24 prefabs** — 12 salles (3 petites, 4 moyennes, 3 grandes, 2 immenses dont une éligible boss) + 8 connecteurs (droit ×2, coudé ×2, T, escalier, porte simple, rampe) + 4 entrées de surface. Assez pour que la variété tienne, grâce au remapping de palette par thème ([[Donjons — structure et intégration]] : *un petit nombre de prefabs, une grande variété visuelle*).

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Génération de donjon]], [[Salles et connecteurs]], [[Grille continue]]
- **Alimente** : [[Donjons — structure et intégration]], [[Ouvert — Taille des salles de donjon]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[Hauteur de terrain ±10]]
