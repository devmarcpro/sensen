---
aliases: ["E.30", "Annexe E.30", "Minimap", "Brouillard de guerre"]
tags: [monde, interface, technique, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] Héritage voxel
> La « coupe au niveau Y » et le bitmask par bande verticale supposent un monde volumétrique : en surface, le monde tactique est une grille unique + hauteur — une seule carte suffit. Le découpage vertical ne garde de sens que **par étage de donjon**. À re-spécifier.
> — Classement complet : [[Héritage voxel — audit]].

Une minimap qui coupe au niveau Y du joueur, et un brouillard de guerre stocké à la résolution chunk.

```
AFFICHAGE — toujours visible à l'écran (coin, façon roguelike). Coupe
  AU NIVEAU Y DU JOUEUR : le monde étant réellement 3D (grottes,
  donjons multi-étages 3.5/E.29, tours), la minimap montre le plan de
  la bande verticale où se trouve le joueur (± 1 chunk, ex. pour voir
  un escalier proche), jamais une projection aplatie de toute la
  colonne. Changer d'étage change ce qui s'affiche.

BROUILLARD DE GUERRE — seules les zones explorées sont visibles, le
  reste est noir. "Exploré" = traversé par le cône de détection/
  vision du joueur (E.16) au passage.

STOCKAGE (perf, cohérent avec G) — résolution CHUNK (16×16), par
  bande verticale (chunk_y, 16 blocs), PAS par bloc individuel :
    explored[chunk_x, chunk_z, chunk_y] : 1 bit
  Bitmask compact, un set par joueur, sauvegardé dans le profil
  (E.10) — persiste entre sessions. Un donjon (E.29) a ses propres
  coordonnées chunk (même monde, volume dense) : chaque étage a donc
  naturellement son propre bitmask d'exploration, sans système
  séparé.

RENDU — échantillonnage des chunks explorés dans un rayon autour du
  joueur à la bande Y courante ; teinte simplifiée par matériau
  dominant de surface du chunk (pas de rendu plein, juste une
  couleur) ; PNJ/monstres détectés affichés en surcouche (icônes),
  pas de mémoire dédiée (état live, pas de fog par entité).
  Coût : mise à jour incrémentale sur `chunk_explored` (nouvel
  événement EventBus, E.12) — jamais de recalcul de zone.
```

## Liens
- **Dépend de** : [[Grille continue]], [[IA des créatures]], [[Sauvegarde]]
- **Alimente** : [[Écrans d'interface]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Carte du monde]], [[EventBus]], [[Ordre de construction]]
