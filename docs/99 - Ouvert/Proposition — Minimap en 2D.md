---
aliases: ["Proposition — Minimap en 2D", "Minimap 2D"]
tags: [ouvert, proposition, héritage-voxel, monde, à-trancher]
domaine: monde
statut: à-trancher
etape: 8
---

> [!todo] Proposition à valider
> Rédigée le 2026-08-26 pour remplacer l'héritage voxel. **Rien ici n'est une décision du GDD.**

**Le problème :** [[Minimap et brouillard de guerre]] « coupe au niveau Y du joueur » et stocke le fog par bande verticale — cela suppose un monde volumétrique. En tactique, la surface est une grille unique + hauteur ; seuls les donjons ont des étages.

## La proposition

**Surface — une seule carte.** Plus de coupe Y : la minimap affiche la grille, teintée par **matériau dominant du chunk + ombrage dérivé de la hauteur** (un léger relief lisible, cohérent avec [[Direction artistique]] : la hauteur est une information tactique). Brouillard : `explored[cx, cz]` — **1 bit par chunk 32×32**, un set par joueur, sauvegardé dans le profil (inchangé).

**Donjon — un fog par étage.** `explored[dungeon_id, floor, chunk]` : la minimap affiche l'étage courant, changer d'étage change la carte — c'est la seule survivance légitime du découpage vertical, et elle est déjà naturelle puisque chaque étage est une grille séparée ([[Proposition — Structure de données de la grille]]).

**Inchangé :** « exploré » = traversé par le cône de vision ([[IA des créatures]]) ; mise à jour incrémentale sur `chunk_explored` ([[EventBus]]) ; PNJ/monstres détectés en surcouche d'icônes, état live sans mémoire dédiée.

## Ce qui reste à trancher

Si l'ombrage de hauteur se calcule au chargement du chunk ou en shader ; la taille d'affichage et le zoom.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Minimap et brouillard de guerre]], [[Grille continue]]
- **Alimente** : [[Écrans d'interface]], [[Sauvegarde]]
- **Voir aussi** : [[Proposition — Structure de données de la grille]], [[Carte du monde]], [[EventBus]]
