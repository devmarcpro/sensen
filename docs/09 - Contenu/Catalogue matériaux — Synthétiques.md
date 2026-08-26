---
aliases: ["F.1 Synthétiques", "Synthétiques", "Catalogue synthétiques"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les 4 matériaux fabriqués en station — pas de récolte possible.

**Synthétiques (4) — fabriqués en station (pas de récolte)**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri | Station |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|---|
| Verre | 8 | 8 | 6 | 20 | 0 | 10 | 15 | 4 | 0 | 0 | 95 | 1 | 25 | Forge (sable) |
| Brique | 18 | 12 | 4 | 5 | 0 | 35 | 10 | 2 | 0 | 0 | 0 | 3 | 50 | Forge (argile) |
| Chaume tressé | 3 | 2 | 2 | 5 | 90 | 65 | 3 | 88 | 0 | 0 | 0 | 55 | 60 | Atelier tissage (paille) |
| Papier | 1 | 1 | 3 | 25 | 95 | 25 | 3 | 90 | 0 | 0 | 15 | 20 | 45 | Scierie (bois) |

**Transparence ([[Application des stats de matériau]]) :** `transparence >= 50` → le bloc laisse passer lumière et regard (fenêtres, serres) — le **Verre** (95) est le matériau canonique. Impact rendu : passe séparée ([[Éclairage]]).

**Fragilité en tempête ([[Météo]]) :** le **Chaume tressé** (Dur 3) fait partie des blocs très fragiles arrachés par la tempête, avec la paille.

**Palette de village ([[Biomes — schéma]]) :** `village_palette` — ex. `{"mur": "chene", "toit": "chaume_tresse", "sol": "calcaire"}`.

**Recettes exotiques ([[Craft compositionnel]]) :** *lame de verre* fait partie des recettes exotiques à apprendre.

**Palier industriel ([[Palier industriel]]) :** verre trempé, brique réfractaire, béton, caoutchouc — recettes industrielles trouvées/achetées, aux vecteurs Wu Xing plats.

**Recette de base ([[Stations de transformation]]) :** Forge — sable → verre, argile → brique. Scierie — bois → papier. Atelier de tissage — paille → chaume.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]], [[Stations de transformation]]
- **Alimente** : [[Palier industriel]], [[Craft compositionnel]], [[Construction cadrée]]
- **Voir aussi** : [[Application des stats de matériau]], [[Météo]], [[Biomes — schéma]], [[Palette de couleurs des matériaux]], [[Décision — Structure de données de la grille]], [[Catalogue matériaux — Terres]]
