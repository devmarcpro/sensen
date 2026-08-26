---
aliases: ["F.1 Liquides", "Liquides", "Catalogue liquides"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 8
---

Les 7 liquides — dont la viscosité dérive de la friction.

**Liquides (7) — outil : seau, compétence Collecte**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| Eau | 0 | 10 | 1 | 15 | 0 | 20 | 80 | — | 0 | 30 | 85 | 0 | 10 |
| Eau salée | 0 | 10 | 1 | 12 | 0 | 20 | 90 | — | 0 | 0 | 80 | 0 | 10 |
| Lave | 0 | 25 | 8 | 20 | 0 | 0 | 30 | — | 90 | 0 | 15 | 0 | 20 |
| Huile | 0 | 8 | 6 | 5 | 95 | 30 | 5 | — | 0 | 0 | 55 | 0 | 5 |
| Goudron | 1 | 11 | 5 | 3 | 90 | 35 | 5 | — | 0 | 0 | 0 | 10 | 5 |
| Boue | 1 | 12 | 1 | 8 | 0 | 30 | 40 | — | 0 | 40 | 5 | 10 | 15 |
| Sève | 1 | 9 | 5 | 20 | 65 | 30 | 10 | — | 0 | 10 | 40 | 20 | 3 |

**Viscosité ([[Eau et liquides]]) :** portée d'étalement 7 tuiles pour l'eau, 3 pour les liquides visqueux (lave, boue, goudron, huile) — champ `viscosite` **dérivé de la friction**. Mise à jour tous les 5 ticks (eau) / 15 ticks (visqueux).

**Conductivité et foudre ([[Eau et liquides]]) :** la foudre frappant l'eau se propage à toutes les entités dans le volume d'eau connexe (rayon 5) — l'**eau salée** (CÉl 90) étend le rayon à 8.

**Lave ([[Eau et liquides]]) :** enflamme les blocs `flammabilite > 0` adjacents ; dégâts de contact 3d6 feu/tour ; lave + eau → obsidienne ou pierre. Luminosité 90 → source de chaleur locale ([[Météo]]).

**Transformations ([[Stations de transformation]]) :** Alambic — liquides → extraits/potions ([[Cuisine et alchimie]]).

**Évaporation en canicule ([[Météo]]) :** l'eau peu profonde s'évapore (niveaux d'écoulement uniquement, **jamais les sources**).

**Gel ([[Météo]]) :** température < −5 prolongée → la surface des blocs d'eau calmes devient **Glace** ([[Catalogue matériaux — Météorologiques]]).

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Eau et liquides]], [[Stations de transformation]], [[Cuisine et alchimie]]
- **Voir aussi** : [[Météo]], [[Catalogue matériaux — Météorologiques]], [[Application des stats de matériau]], [[Palette de couleurs des matériaux]], [[Véhicules]]
