---
aliases: ["F.1 Météorologiques", "Glace", "Neige", "Catalogue météorologiques"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 8
---

Les 2 matériaux qui apparaissent et disparaissent selon la météo — mais restent de vrais blocs constructibles.

**Météorologiques (2) — apparaissent/disparaissent selon la météo ([[Météo]]) ; récoltables**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri | Notes |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|---|
| Glace | 6 | 9 | 2 | 20 | 0 | 30 | 25 | 40 | 0 | 0 | 70 | 2 | 5 | transparente, très glissante, fond à la chaleur |
| Neige | 1 | 3 | 1 | 10 | 0 | 60 | 5 | 50 | 0 | 5 | 5 | 30 | 30 | isolante (igloo viable !), fond vite |

**Décision ([[Météo]]) :** *Glace et Neige ajoutés au catalogue — matériaux réels à part entière (constructibles : la glace est un vrai bloc, transparent, glissant ; fond près des sources de chaleur).*

**Gel ([[Météo]]) :** température < −5 prolongée → la surface des blocs d'eau calmes devient GLACE (bloc réel, marchable, **friction 5**, cassable → re-eau) ; appliqué paresseusement au chargement de la zone. *Les lacs gelés ouvrent des raccourcis saisonniers ; la pêche/navigation s'arrêtent.*

**Neige ([[Météo]]) :** couche de neige au sol (bloc fin 4px auto-posé sur les surfaces exposées, paresseusement au chargement — comme la régénération [[Claims et persistance]]), fond au redoux/sources de chaleur.

**Friction et déplacement ([[Application des stats de matériau]]) :** `Vitesse de déplacement au sol *= (0.85 + friction_sol × 0.003)` bornée [0.85, 1.15] — *glace 0 = glissade*. Le module **Mur de glace** ([[Modules]]) crée des blocs de glace temporaires — *matériau réel, friction 5*.

**Vecteur Wu Xing ([[Wu Xing hors combat]]) :** liquide/glace → **Eau**.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Météo]], [[Catégories de matériaux]]
- **Alimente** : [[Modules]], [[Application des stats de matériau]], [[Construction cadrée]]
- **Voir aussi** : [[Eau et liquides]], [[Catalogue matériaux — Liquides]], [[Palette de couleurs des matériaux]], [[Wu Xing hors combat]], [[Ouvert — Saisons]]
