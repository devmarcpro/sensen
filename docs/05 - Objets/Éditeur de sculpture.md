---
aliases: ["E.9", "Annexe E.9", "Éditeur de sculpture", "Périmètres de sculpture"]
tags: [objets, craft, technique, décidé]
domaine: objets
statut: décidé
etape: 6
---

> [!note] Adapté au pivot tactique
> Réécrit pour le **pixel art paramétrique** ([[Construction cadrée]], [[Tables de sculpture]]). L'éditeur voxel d'origine est archivé (GDD source, historique git). Périmètres et pipeline 2D chiffrés : [[Décision — Sculpture en pixel art]].

L'éditeur de sculpture : un canevas de pixels où le joueur pose ses vrais matériaux — le principe d'E.9 transposé en 2D.

```
L'éditeur est un canevas de PIXELS isolé (périmètre selon la table —
valeurs proposées en [[Décision — Sculpture en pixel art]] : items
16×16, armes 16×48, meubles 32×32, blocs 16×16, structures 64×64,
véhicules 96×64), avec pose/gomme/ghost preview.
1 pixel = 1 unité de matériau, débitée de l'inventaire en temps réel
(rendue si effacée) ; le pixel s'affiche à la couleur réelle du
matériau (palette F.1.1) — pas de remapping pendant la sculpture.
Validation → génère : sprite (vue isométrique de référence) +
composition par matériau, stat_weights (comptage de pixels, A.4),
entrée d'objet (B.3) sauvegardée dans le profil du joueur,
partageable en coop (copie du modèle vers le catalogue du groupe,
sur action explicite du créateur).
```

**Écran dédié ([[Écrans d'interface]]) :** *Fenêtre de sculpture*.

**Sauvegarde ([[Sauvegarde]]) :** les modèles sculptés vivent dans `players/*.json` — inchangé.

**Blocs fonctionnels des véhicules ([[Véhicules]]) :** des **pixels-marqueurs typés** visibles (siège de pilote, gouvernail, mât+voile, roues, coffres) — mêmes couleurs réservées que les points d'attache ([[Squelette modulaire et points d'attache]]). La validation vérifie les requis de la fonctionnalité choisie, seule « contrainte de forme » du jeu.

## Liens
- **Dépend de** : [[Tables de sculpture]], [[Stats d'un objet crafté]], [[Décision — Sculpture en pixel art]]
- **Alimente** : [[Schéma objet et recette]], [[Véhicules]], [[Sauvegarde]]
- **Voir aussi** : [[Écrans d'interface]], [[Multijoueur]], [[Construction cadrée]], [[Palette de couleurs des matériaux]]
