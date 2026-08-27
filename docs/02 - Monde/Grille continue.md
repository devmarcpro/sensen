---
aliases: ["3.2", "3.2 Structure du monde", "Grille continue", "Tuile chunk cellule"]
tags: [monde, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

Une seule grille finie et continue, sans écran de chargement, à quatre échelles emboîtées.

Une seule **grille de tuiles**, sans écran de chargement ni transition de zone — mais **bornée** ([[Décision — Monde fini, continents et océan]]). Quatre échelles s'emboîtent :

**tuile** → **chunk** (32×32 tuiles, unité de génération et de streaming) → **cellule** (128×128 tuiles, unité de la carte du monde, du claim et du zonage) → **secteur** (64×64 cellules, unité de génération politique).

**Le monde entier fait 16×16 secteurs**, soit 1024×1024 cellules ou 131 072 tuiles de côté. Toutes les coordonnées sont donc bornées : un identifiant de cellule tient dans un `u32`, et la sauvegarde a une taille maximale connue.

Chaque tuile porte : une **hauteur entière** (0-20, voir [[Hauteur de terrain ±10]]), un **matériau de sol**, un **contenu** éventuel (mur, arbre, filon, meuble, empreinte de bâtiment) et un **occupant** éventuel (créature). Structure plate, lisible, sérialisable.

- **Fini ne veut pas dire découpé.** Le monde est borné, mais il reste **une seule grille sans couture** : on traverse un continent entier à pied sans un seul chargement. La limite du monde n'est pas un mur, c'est un océan profond ([[Décision — Monde fini, continents et océan]]).
- **Continuité réelle** : on marche d'une cellule à l'autre sans rupture ; les chunks se génèrent devant et se déchargent derrière. La carte du monde reste un **résumé** du même champ de bruit ([[Unification macro-micro]]) — le voyage rapide est un raccourci par-dessus un monde qui existe vraiment.
- **Pas de volume souterrain.** Le souterrain n'existe plus comme espace continu : il devient les **donjons**, grilles séparées en étages discrets reliés par des escaliers ([[Donjons — structure et intégration]]). Les ressources minérales se récoltent en **filons de surface** (façon Elin), pas en creusant des tunnels — le minage exploratoire est explicitement écarté.
- **Gain technique** : plus de meshing volumétrique, plus de LOD 3D, plus de streaming en volume, plus de propagation de lumière en 3D. Le rendu est : tuiles instanciées teintées par matériau + billboards triés en profondeur.

*Note d'architecture : les chunks sont indexés en 3D `(x, y, z)` dès le premier jour — voir [[Décisions d'architecture]] et [[Décision — Structure de données de la grille]].*

> [!success] Décidé le 2026-08-27 — la cellule fait 64×64 (instruction du designer)
> « Je veux que les cellules soient de 64×64. » La cellule passe de 128×128 à **64×64 tuiles** ; un chunk de 32×32 = un quart de cellule. Le monde (16×16 secteurs de 64×64 cellules) fait donc 65 536 tuiles de côté. Les mentions de 128 dans [[Décision — Monde fini, continents et océan]] et [[Unification macro-micro]] sont remplacées par ce callout. Un étage de donjon = une cellule ([[Génération de donjon]]).

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Unification macro-micro]]
- **Alimente** : [[Décision — Monde fini, continents et océan]], [[Hauteur de terrain ±10]], [[Carte du monde]], [[Claims et persistance]], [[Donjons — structure et intégration]], [[Combat tactique sur grille]]
- **Voir aussi** : [[Décisions d'architecture]], [[Décision — Structure de données de la grille]], [[Sauvegarde]], [[Risques majeurs]]
