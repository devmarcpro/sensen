---
aliases: ["E.9", "Annexe E.9", "Éditeur de sculpture", "Périmètres de sculpture"]
tags: [objets, craft, technique, décidé]
domaine: objets
statut: décidé
etape: 6
---

L'éditeur EST le moteur voxel du jeu, dans un mini-espace isolé — avec les périmètres chiffrés par table.

```
L'éditeur EST le moteur voxel du jeu : un mini-espace voxel isolé
(périmètre selon la table : items 16³, armes 16×16×48, meubles 32³,
blocs 16³ par définition, structures 64³, véhicules 64×64×96 — en voxels
de 1px), avec la même pose/subdivision/ghost preview que le monde.
Les matériaux sont débités de l'inventaire en temps réel (rendus si
effacés). Validation → génère : VoxModel (mesh + composition par matériau),
stat_weights (comptage de voxels), entrée d'objet (B.3) sauvegardée dans
le profil du joueur, partageable en coop (copie du modèle vers le
catalogue du groupe, sur action explicite du créateur).
```

**Écran dédié ([[Écrans d'interface]]) :** *Fenêtre de sculpture*.

**Sauvegarde ([[Sauvegarde]]) :** les modèles sculptés vivent dans `players/*.json`.

**Blocs fonctionnels des véhicules ([[Véhicules]]) :** pendant la sculpture d'un véhicule, le joueur place des blocs spéciaux visibles (siège de pilote, gouvernail, mât+voile, roues, coffres) — la validation vérifie les requis de la fonctionnalité choisie, seule « contrainte de forme » du jeu.

**Budget de subdivision ([[Voxels — mémoire et meshing]]) :** 512 blocs subdivisés par chunk — garde-fou qui évite qu'une méga-sculpture 1px fasse exploser mémoire et meshing.

## Liens
- **Dépend de** : [[Tables de sculpture]], [[Voxels — mémoire et meshing]], [[Stats d'un objet crafté]]
- **Alimente** : [[Schéma objet et recette]], [[Véhicules]], [[Sauvegarde]]
- **Voir aussi** : [[Écrans d'interface]], [[Multijoueur]], [[Construction cadrée]]
