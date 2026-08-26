---
aliases: ["Décision — Minimap en 2D", "Proposition — Minimap en 2D", "Minimap 2D"]
tags: [ouvert, proposition, héritage-voxel, monde, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Minimap et brouillard de guerre]] « coupe au niveau Y du joueur » et stocke le fog par bande verticale — cela suppose un monde volumétrique. En tactique, la surface est une grille unique + hauteur ; seuls les donjons ont des étages.

## La proposition

**Surface — une seule carte.** Plus de coupe Y : la minimap affiche la grille, teintée par **matériau dominant du chunk + ombrage dérivé de la hauteur** (un léger relief lisible, cohérent avec [[Direction artistique]] : la hauteur est une information tactique). Brouillard : `explored[cx, cz]` — **1 bit par chunk 32×32**, un set par joueur, sauvegardé dans le profil (inchangé).

**Donjon — un fog par étage.** `explored[dungeon_id, floor, chunk]` : la minimap affiche l'étage courant, changer d'étage change la carte — c'est la seule survivance légitime du découpage vertical, et elle est déjà naturelle puisque chaque étage est une grille séparée ([[Décision — Structure de données de la grille]]).

**Inchangé :** « exploré » = traversé par le cône de vision ([[IA des créatures]]) ; mise à jour incrémentale sur `chunk_explored` ([[EventBus]]) ; PNJ/monstres détectés en surcouche d'icônes, état live sans mémoire dédiée.

## Les derniers points, fixés

- **Ombrage de hauteur : calculé au chargement du chunk**, stocké avec la teinte dominante (une valeur par chunk, recalculée à la mutation). La minimap n'a pas besoin d'un shader dédié — c'est une texture mise à jour incrémentalement ([[Décision — Structure de données de la grille]]).
- **Affichage : 3 niveaux de zoom** (×1 proche ≈ 32 chunks visibles, ×2, ×4), coin haut-droit, taille fixe 256×256 px, masquable. Le zoom ×4 rejoint visuellement l'échelle de la carte du monde ([[Carte du monde]]) — la transition entre les deux est lisible.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Minimap et brouillard de guerre]], [[Grille continue]]
- **Alimente** : [[Écrans d'interface]], [[Sauvegarde]]
- **Voir aussi** : [[Décision — Structure de données de la grille]], [[Carte du monde]], [[EventBus]]
