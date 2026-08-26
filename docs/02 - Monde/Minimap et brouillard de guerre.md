---
aliases: ["E.30", "Annexe E.30", "Minimap", "Brouillard de guerre"]
tags: [monde, interface, technique, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> La « coupe au niveau Y » et le bitmask par bande verticale sont retirés — archivés dans le GDD source. Version 2D détaillée : [[Décision — Minimap en 2D]].

Une minimap toujours visible, un brouillard de guerre par chunk — une carte en surface, une par étage en donjon.

```
AFFICHAGE — toujours visible à l'écran (coin, façon roguelike).
  SURFACE : une seule carte — le monde tactique est une grille unique
  + hauteur ; teinte par matériau dominant du chunk + ombrage dérivé
  de la hauteur (le relief est une information tactique, 9).
  DONJON : la minimap affiche l'étage courant ; changer d'étage change
  la carte — chaque étage est une grille séparée (3.5).

BROUILLARD DE GUERRE — seules les zones explorées sont visibles, le
  reste est noir. "Exploré" = traversé par le cône de détection/
  vision du joueur (E.16) au passage.

STOCKAGE (perf, cohérent avec G) — résolution CHUNK :
    surface : explored[cx, cz]                  → 1 bit par chunk 32×32
    donjon  : explored[dungeon_id, floor, chunk] → un bitmask par étage
  Bitmask compact, un set par joueur, sauvegardé dans le profil
  (E.10) — persiste entre sessions.

RENDU — échantillonnage des chunks explorés dans un rayon autour du
  joueur ; teinte simplifiée par matériau dominant (pas de rendu
  plein, juste une couleur) ; PNJ/monstres détectés affichés en
  surcouche (icônes), pas de mémoire dédiée (état live, pas de fog
  par entité).
  Coût : mise à jour incrémentale sur `chunk_explored` (événement
  EventBus, E.12) — jamais de recalcul de zone.
```

## Liens
- **Dépend de** : [[Grille continue]], [[IA des créatures]], [[Sauvegarde]]
- **Alimente** : [[Écrans d'interface]], [[Donjons — structure et intégration]]
- **Voir aussi** : [[Décision — Minimap en 2D]], [[Carte du monde]], [[EventBus]], [[Ordre de construction]]
