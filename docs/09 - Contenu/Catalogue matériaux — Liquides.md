---
aliases: ["F.1 Liquides", "Liquides", "Catalogue liquides"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 8
---

Les 7 liquides — dont la viscosité dérive de la friction.

**Liquides (18) — outil : seau, compétence Collecte**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri | Fus | Por | Abs |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|--|
| Eau | 0 | 10 | 1 | 13 | 0 | 20 | 80 | 0 | 0 | 30 | 85 | 0 | 10 | 0 | 0 | 12 |
| Eau salée | 0 | 10 | 1 | 7 | 0 | 20 | 90 | 0 | 0 | 0 | 80 | 0 | 10 | -2 | 0 | 12 |
| Lave | 0 | 25 | 7 | 17 | 0 | 0 | 30 | 0 | 90 | 0 | 15 | 0 | 20 | 900 | 0 | 30 |
| Huile | 0 | 8 | 3 | 3 | 95 | 30 | 5 | 0 | 0 | 0 | 55 | 0 | 5 | -6 | 0 | 22 |
| Goudron | 1 | 11 | 3 | 2 | 90 | 35 | 5 | 0 | 0 | 0 | 0 | 10 | 5 | 60 | 0 | 48 |
| Boue | 1 | 12 | 1 | 4 | 0 | 30 | 40 | 0 | 0 | 40 | 5 | 10 | 15 | 0 | 0 | 55 |
| Sève | 1 | 9 | 4 | 17 | 65 | 30 | 10 | 0 | 0 | 10 | 40 | 20 | 3 | 0 | 0 | 25 |
| Alcool | 0 | 3 | 10 | 38 | 90 | 15 | 4 | 90 | 0 | 0 | 80 | 2 | 10 | -114 | 0 | 16 |
| Encre | 0 | 4 | 8 | 47 | 15 | 16 | 18 | 80 | 0 | 0 | 4 | 2 | 15 | 0 | 0 | 18 |
| Essence de térébenthine | 0 | 3 | 9 | 34 | 95 | 14 | 5 | 92 | 0 | 0 | 60 | 2 | 10 | -55 | 0 | 18 |
| Lait | 0 | 4 | 5 | 24 | 12 | 20 | 20 | 86 | 2 | 30 | 8 | 3 | 14 | 0 | 0 | 20 |
| Lessive de cendre | 0 | 4 | 4 | 22 | 0 | 15 | 55 | 84 | 0 | 10 | 55 | 2 | 12 | 0 | 0 | 18 |
| Mercure | 0 | 14 | 26 | 60 | 0 | 8 | 85 | 2 | 6 | 0 | 0 | 2 | 8 | -39 | 0 | 10 |
| Miel | 0 | 6 | 14 | 42 | 30 | 35 | 6 | 60 | 4 | 25 | 45 | 6 | 60 | -10 | 0 | 40 |
| Sang | 0 | 4 | 8 | 55 | 10 | 18 | 40 | 82 | 0 | 20 | 20 | 3 | 20 | 0 | 0 | 20 |
| Saumure | 0 | 4 | 3 | 27 | 0 | 14 | 80 | 85 | 0 | 0 | 65 | 2 | 12 | -21 | 0 | 14 |
| Venin | 0 | 3 | 19 | 51 | 20 | 15 | 20 | 80 | 0 | 0 | 35 | 2 | 15 | 0 | 0 | 20 |
| Vinaigre | 0 | 3 | 5 | 26 | 10 | 12 | 25 | 88 | 0 | 5 | 70 | 2 | 12 | -2 | 0 | 16 |

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
