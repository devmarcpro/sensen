---
aliases: ["F.1 Terres", "Terres", "Sols", "Catalogue terres"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les 6 terres et sols — la catégorie où la fertilité compte.

**Terres & sols (12) — outil : pelle, compétence Terrassement**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| Terre | 2 | 8 | 1 | 3 | 5 | 35 | 20 | 10 | 0 | 45 | 0 | 15 | 60 |
| Terre fertile | 3 | 8 | 3 | 8 | 5 | 35 | 22 | 10 | 0 | 75 | 0 | 15 | 60 |
| Tourbe | 3 | 7 | 2 | 7 | 55 | 45 | 18 | 25 | 0 | 60 | 0 | 20 | 55 |
| Sable | 1 | 9 | 1 | 2 | 0 | 25 | 5 | 8 | 0 | 5 | 0 | 5 | 70 |
| Argile | 3 | 10 | 2 | 7 | 0 | 40 | 30 | 5 | 0 | 20 | 0 | 35 | 50 |
| Gravier | 2 | 11 | 1 | 2 | 0 | 20 | 8 | 4 | 0 | 5 | 0 | 5 | 75 |
| Cendre | 1 | 2 | 2 | 17 | 10 | 35 | 4 | 45 | 0 | 40 | 0 | 5 | 40 |
| Humus | 1 | 3 | 3 | 15 | 20 | 30 | 5 | 40 | 0 | 95 | 0 | 10 | 50 |
| Latérite | 5 | 6 | 3 | 17 | 0 | 26 | 8 | 18 | 0 | 25 | 0 | 5 | 48 |
| Limon | 2 | 5 | 2 | 10 | 5 | 25 | 6 | 25 | 0 | 85 | 0 | 8 | 55 |
| Marne | 3 | 5 | 3 | 14 | 0 | 28 | 6 | 22 | 0 | 55 | 0 | 6 | 45 |
| Sable noir | 2 | 5 | 3 | 24 | 0 | 22 | 12 | 20 | 0 | 5 | 0 | 8 | 52 |

**Rendement agricole ([[Application des stats de matériau]]) :** `rendement_final = rendement_biome × (0.5 + fertilite_sol / 100)` — la **Terre fertile** (Fer 75) est le sol de référence des champs ([[Agriculture et élevage]]).

**Transformations ([[Stations de transformation]]) :** sable → verre (Forge), argile → brique (Forge).

**Matériau de surface d'un biome ([[Biomes — schéma]]) :** champs `surface_material` / `subsurface_material` (ex. `terre_fertile` / `terre` pour la forêt de mana).

**Strate de surface ([[Stratification verticale]]) :** terre/grès de 0 à −12.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Agriculture et élevage]], [[Stations de transformation]], [[Biomes — schéma]]
- **Voir aussi** : [[Application des stats de matériau]], [[Palette de couleurs des matériaux]], [[Stratification verticale]], [[Catalogue matériaux — Synthétiques]]
