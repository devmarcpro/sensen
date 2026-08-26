---
aliases: ["G.9", "Annexe G.9", "Stratification verticale", "strata.json", "Palette de sol des donjons"]
tags: [monde, génération, données, décidé]
domaine: monde
statut: à-trancher
etape: 2
---

> [!note] Adapté au pivot tactique
> Le système de strates minables en Y est retiré — on ne creuse plus nulle part ([[Décisions fondatrices]]). Le recyclage proposé — palette de sol par étage de donjon — est en [[Proposition — Minerais et strates après le pivot]] (à valider). La table d'origine est conservée ci-dessous comme donnée source de cette palette.

L'ancienne stratification par profondeur, recyclée en palette de sol des étages de donjon : la dureté du sol croît avec l'étage.

**Le recyclage proposé ([[Proposition — Minerais et strates après le pivot]]) :**

```
étages 1-2 : calcaire/grès · 3-4 : ardoise/pierre · 5-6 : basalte
étages 7+  : granit, puis granit noir
```

La dureté croissante du sol garde un sens tactique — sorts de terrain, [[Destruction du terrain]], [[Explosions]] — et préserve le principe d'origine : *le risque, la dureté et la valeur montent ensemble* (le risque étant désormais la corruption effective d'étage, [[Génération de donjon]]).

**La table d'origine (G.9, donnée source de la palette) :**

```
Défaut : terre/grès 0→-12, calcaire -12→-55, ardoise -55→-80,
  pierre -80→-160, basalte -160→-260, granit -260→-380,
  granit noir -380→fond. Poches locales (bruit dédié) : ±1 strate.
Variantes latérales : diorite/andésite/gneiss remplacent localement
  granit/basalte par bruit ; quartzite près des filons de quartz ;
  tuf/ponce près des zones volcaniques — la géologie varie aussi
  horizontalement.
```

Les **variantes latérales** restent applicables telles quelles aux étages de donjon (un donjon en zone volcanique tire tuf/ponce/basalte) et aux affleurements de surface par biome.

**Paliers serrés voulus ([[Application des stats de matériau]]) :** les paliers de dureté des roches ([[Catalogue matériaux — Roches]]) sont VOULUS — ne pas les écarter.

## Liens
- **Dépend de** : [[Proposition — Minerais et strates après le pivot]], [[Catalogue matériaux — Roches]]
- **Alimente** : [[Génération de donjon]], [[Destruction du terrain]]
- **Voir aussi** : [[Minerais par profondeur]], [[Application des stats de matériau]], [[Récolte]], [[Décisions fondatrices]]
