---
aliases: ["G.9", "Annexe G.9", "Stratification verticale", "strata.json"]
tags: [monde, génération, données, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] Héritage voxel
> Système écrit pour le minage voxel : les strates ne sont plus creusables nulle part ([[Décisions fondatrices]] — minage exploratoire écarté, pas de volume souterrain). Survit éventuellement comme logique de matériaux **par étage de donjon** et de composition des **filons de surface** — à re-décider.
> — Classement complet : [[Héritage voxel — audit]].

Plus on descend, plus la roche est dure : un verrou de progression naturel, piloté par une simple liste de strates en données.

```
data/strata.json : liste ordonnée { "material", "y_max", "transition" }
  — évaluée par colonne pendant la génération (G.4), bruit de
  transition (±12 blocs) pour des frontières organiques, surchargée
  par les biomes (un volcan fait remonter le basalte) et percée par
  les cavernes/filons. Coût : nul (une lookup par bloc généré).
Défaut : terre/grès 0→-12, calcaire -12→-55, ardoise -55→-80,
  pierre -80→-160, basalte -160→-260, granit -260→-380,
  granit noir -380→fond. Poches locales (bruit dédié) : ±1 strate.
```

**Variantes latérales :**

```
Les ROCHES suivent aussi des variantes latérales (diorite/andésite/
gneiss remplacent localement granit/basalte par bruit ; quartzite près
des filons de quartz ; tuf/ponce près des zones volcaniques 3.0) —
la géologie varie horizontalement ET verticalement.
```

**Verrou de progression ([[Unification macro-micro]]) :** combiné à la règle d'irrécoltabilité de [[Récolte]] (outil trop faible = rebond), creuser profond exige de meilleurs outils, de meilleurs matériaux (trouvés... en profondeur : boucle de progression) ou des PNJ mineurs de haut niveau.

*Les paliers serrés de dureté des roches sont **VOULUS** (stratification G.9) — ne pas les écarter (voir [[Application des stats de matériau]]).*

## Liens
- **Dépend de** : [[Unification macro-micro]], [[Terrain spectaculaire]], [[Catalogue matériaux — Roches]]
- **Alimente** : [[Minerais par profondeur]], [[Récolte]]
- **Voir aussi** : [[Application des stats de matériau]], [[Génération procédurale — performance]]
