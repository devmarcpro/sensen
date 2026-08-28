---
aliases: ["G.9", "Annexe G.9", "Stratification verticale", "strata.json", "Palette de sol des donjons"]
tags: [monde, génération, données, décidé]
domaine: monde
statut: décidé
etape: 2
---

> [!note] Adapté au pivot tactique
> Le système de strates minables en Y est retiré — on ne creuse plus nulle part ([[Décisions fondatrices]]). Le recyclage décidé — palette de sol par étage de donjon — est en [[Décision — Minerais et strates après le pivot]] ). La table d'origine est conservée ci-dessous comme donnée source de cette palette.

L'ancienne stratification par profondeur, recyclée en palette de sol des étages de donjon : la dureté du sol croît avec l'étage.

**Le recyclage ([[Décision — Minerais et strates après le pivot]]) :**

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

> [!success] Codé le 2026-08-28 — la palette de sol par étage
> `minerais_par_etage.palette_mur` : bandes d'étages → matériau des murs du labyrinthe (`calcaire` 1-2, `ardoise` 3-4, `basalte` 5-6, `granit` 7-9, `granit_noir` 10+). Décision : **le thème garde son `materiau_mur` aux étages 1-2** (ruine = pierre, repaire = calcaire : l'identité du lieu se voit en surface), la palette prend le relais à partir de l'étage 3 — le sol se lit alors par sa dureté, et creuser (Destruction du terrain) devient plus lent avec la profondeur puisque `_creuser` lit `grille.materiau_de`. **Poches locales** : `palette_mur.poches` — un `FastNoiseLite` dédié (graine, donjon, étage ; fréquence 0,08) ; au-dessus de 0,7 le mur prend la strate **suivante** (étage + 2), sous 0,3 la **précédente** — des taches de basalte dans l'ardoise, d'ardoise dans le basalte ; les filons priment. Décision : pas de poche en dessous de l'étage 3 (le thème y règne).

## Liens
- **Dépend de** : [[Décision — Minerais et strates après le pivot]], [[Catalogue matériaux — Roches]]
- **Alimente** : [[Génération de donjon]], [[Destruction du terrain]]
- **Voir aussi** : [[Minerais par profondeur]], [[Application des stats de matériau]], [[Récolte]], [[Décisions fondatrices]]
