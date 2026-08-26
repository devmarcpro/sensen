---
aliases: ["F.1 Terres", "Terres", "Sols", "Catalogue terres"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les 6 terres et sols — la catégorie où la fertilité compte.

**Terres & sols (6) — outil : pelle, compétence Terrassement**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| Terre | 3 | 8 | 1 | 5 | 5 | 35 | 20 | 10 | 0 | 45 | 0 | 15 | 60 |
| Terre fertile | 3 | 8 | 3 | 10 | 5 | 35 | 22 | 10 | 0 | 75 | 0 | 15 | 60 |
| Tourbe | 4 | 7 | 2 | 8 | 55 | 45 | 18 | 25 | 0 | 60 | 0 | 20 | 55 |
| Sable | 2 | 9 | 1 | 3 | 0 | 25 | 5 | 8 | 0 | 5 | 0 | 5 | 70 |
| Argile | 4 | 10 | 2 | 8 | 0 | 40 | 30 | 5 | 0 | 20 | 0 | 35 | 50 |
| Gravier | 4 | 11 | 1 | 3 | 0 | 20 | 8 | 4 | 0 | 5 | 0 | 5 | 75 |

**Rendement agricole ([[Application des stats de matériau]]) :** `rendement_final = rendement_biome × (0.5 + fertilite_sol / 100)` — la **Terre fertile** (Fer 75) est le sol de référence des champs ([[Agriculture et élevage]]).

**Transformations ([[Stations de transformation]]) :** sable → verre (Forge), argile → brique (Forge).

**Matériau de surface d'un biome ([[Biomes — schéma]]) :** champs `surface_material` / `subsurface_material` (ex. `terre_fertile` / `terre` pour la forêt de mana).

**Strate de surface ([[Stratification verticale]]) :** terre/grès de 0 à −12.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Agriculture et élevage]], [[Stations de transformation]], [[Biomes — schéma]]
- **Voir aussi** : [[Application des stats de matériau]], [[Palette de couleurs des matériaux]], [[Stratification verticale]], [[Catalogue matériaux — Synthétiques]]
