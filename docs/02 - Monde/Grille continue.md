---
aliases: ["3.2", "3.2 Structure du monde", "Grille continue", "Tuile chunk cellule"]
tags: [monde, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

Une seule grille infinie de tuiles, sans écran de chargement, à trois échelles emboîtées.

Une seule **grille infinie de tuiles**, sans écran de chargement ni transition de zone. Trois échelles s'emboîtent :

**tuile** → **chunk** (32×32 tuiles, unité de génération et de streaming) → **cellule** (128×128 tuiles, unité de la carte du monde, du claim et du zonage).

Chaque tuile porte : une **hauteur entière** (0-20, voir [[Hauteur de terrain ±10]]), un **matériau de sol**, un **contenu** éventuel (mur, arbre, filon, meuble, empreinte de bâtiment) et un **occupant** éventuel (créature). Structure plate, lisible, sérialisable.

- **Continuité réelle** : on marche d'une cellule à l'autre sans rupture ; les chunks se génèrent devant et se déchargent derrière. La carte du monde reste un **résumé** du même champ de bruit ([[Unification macro-micro]]) — le voyage rapide est un raccourci par-dessus un monde qui existe vraiment.
- **Pas de volume souterrain.** Le souterrain n'existe plus comme espace continu : il devient les **donjons**, grilles séparées en étages discrets reliés par des escaliers ([[Donjons — structure et intégration]]). Les ressources minérales se récoltent en **filons de surface** (façon Elin), pas en creusant des tunnels — le minage exploratoire est explicitement écarté.
- **Gain technique** : plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume, plus de propagation de lumière en 3D. Le rendu est : tuiles instanciées teintées par matériau + billboards triés en profondeur.

*Note d'architecture : les chunks sont indexés en 3D `(x, y, z)` dès le premier jour — voir [[Décisions d'architecture]] et [[Voxels — mémoire et meshing]].*

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Unification macro-micro]]
- **Alimente** : [[Hauteur de terrain ±10]], [[Carte du monde]], [[Claims et persistance]], [[Donjons — structure et intégration]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Décisions d'architecture]], [[Voxels — mémoire et meshing]], [[Sauvegarde]], [[Risques majeurs]]
