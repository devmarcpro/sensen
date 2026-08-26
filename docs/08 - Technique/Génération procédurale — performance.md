---
aliases: ["G.4", "Annexe G.4", "Génération performance", "FastNoiseLite"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 8
---

Le terrain spectaculaire coûte le même prix que le terrain plat — à condition de rester à un niveau de domain warping.

```
FastNoiseLite (natif Godot, C++) pour toutes les couches — jamais de
bruit en GDScript. Le terrain spectaculaire (E.2 : ridged, domain
warping, terrasses) reste du bruit par colonne — même coût que du
terrain plat, seule la composition des couches change. Le domain
warping double les évaluations de bruit sur x/z : rester à 1 niveau
de warp (pas de warp imbriqué). Les 8 couches sont échantillonnées PAR COLONNE
(x,z) une fois, mises en cache par chunk-colonne ; le remplissage 3D
ne réévalue pas le bruit 2D. Le bruit 3D de cavernes est évalué par
pas de 4 blocs et interpolé (trilinéaire) — ×64 moins d'appels,
différence invisible. Génération complète en thread, par anneaux de
priorité autour du joueur. Les POI/villages (E.2) se génèrent à la
première visite de la cellule uniquement (hash déterministe).
```

**Génération de donjon paresseuse ([[Génération de donjon]]) :** génération en thread au premier accès à l'étage — un étage jamais atteint ne coûte rien.

**Royaumes paresseux ([[Génération des royaumes PNJ]]) :** un royaume « existe » en données dès que son secteur est interrogé, mais ses villes/PNJ ne sont instanciés qu'à l'approche du joueur. Un royaume jamais visité ne coûte rien.

**Stratification ([[Stratification verticale]]) :** évaluée par colonne pendant la génération — coût nul, une lookup par bloc généré.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Unification macro-micro]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Terrain spectaculaire]], [[Génération de donjon]], [[Génération des royaumes PNJ]], [[Stratification verticale]]
- **Voir aussi** : [[Biomes — schéma]], [[Météo]], [[Budgets de performance]], [[Ordre de vérification]]
