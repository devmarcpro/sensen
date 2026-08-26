---
aliases: ["G.9 minerais", "ore_bands.json", "Minerais par profondeur", "Bandes de minerai", "Tiers de minerai"]
tags: [monde, génération, données, à-trancher]
domaine: monde
statut: à-trancher
etape: 8
---

> [!note] Adapté au pivot tactique
> Les bandes en Y supposaient qu'on creuse — retirées comme clé de placement. Le remapping proposé (tiers par corruption en surface, bandes d'étage en donjon) est en [[Proposition — Minerais et strates après le pivot]] (à valider). La répartition d'origine est conservée ci-dessous comme donnée source des tiers.

Quels minerais apparaissent où : des tiers par corruption effective en surface, des bandes d'étage en donjon. Le principe préservé : *le risque, la dureté et la valeur montent ensemble*.

**Le placement proposé ([[Proposition — Minerais et strates après le pivot]]) :**
- **Filons de surface** ([[Récolte]]) : tiers 1 à 5 selon la **corruption effective** ([[Dérive de la corruption]]) et le biome — la richesse suit le danger ([[Niveau de danger]]).
- **Donjons** : bandes d'**étage** — étages 1-2 : tiers 1-2 · 3-4 : tiers 2-3 · 5-6 : tiers 3-4 · 7+ : tiers 4-5, la kimberlite comme sol des salles à diamant.

**La répartition d'origine (G.9, donnée source des tiers) :**

```
tier 1 : cuivre, étain, zinc, lignite, sel gemme, argile réfractaire,
         ocre, tourbe compactée, turquoise, ambre (côtes/forêts)
tier 2 : fer, nickel, manganèse, houille, pyrite, malachite, soufre,
         mica, salpêtre, quartz, bitume, fluorine, phosphorite,
         calcite                        (l'ère du fer)
tier 3 : or, argent, cobalt, antimoine, anthracite, graphite,
         cinabre, améthyste, topaze, grenat, lapis-lazuli, géodes
                                        (richesse + acier)
tier 4 : platine, titane, chrome, bismuth, opale, jade, rubis,
         saphir, émeraude, kimberlite   (roche-hôte du diamant)
tier 5 : tungstène, diamant (dans la kimberlite) + filons GÉANTS
FOSSILES : os/ammonites/coquillages dans les roches sédimentaires —
  étages 1-3 des donjons + affleurements de falaise en surface ;
  bois pétrifié dans le tuf ; météorite ferreuse : POI de surface
  (sites d'impact).
Le guano se trouve dans les donjons à thème « repaire » (engrais, 7.4).
La kimberlite est le SIGNAL du diamant (le prospecteur avisé la
reconnaît — et la guilde des Prospecteurs vend cette information).
Les tiers se CHEVAUCHENT (transitions douces) ; densité et taille des
filons augmentent avec la corruption/l'étage DANS chaque tier.
Le risque, la dureté de la roche et la valeur du minerai montent
ensemble — trois pressions alignées.
```

**Rappel :** le minage exploratoire souterrain a été écarté ([[Décisions fondatrices]]) — les ressources se récoltent en **filons de surface** ([[Récolte]]) et en filons muraux de donjon.

## Liens
- **Dépend de** : [[Proposition — Minerais et strates après le pivot]], [[Dérive de la corruption]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Récolte]], [[Génération de donjon]], [[Quêtes et guildes]], [[Catalogue matériaux — Minéraux]], [[Catalogue matériaux — Gemmes]], [[Catalogue matériaux — Fossiles]]
- **Voir aussi** : [[Niveau de danger]], [[Stratification verticale]], [[Génération par couches de bruit]]
