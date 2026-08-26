---
aliases: ["G.9 minerais", "ore_bands.json", "Minerais par profondeur", "Bandes de minerai"]
tags: [monde, génération, données, décidé, héritage-voxel]
domaine: monde
statut: décidé
etape: 8
---

> [!warning] Héritage voxel
> Les bandes en Y supposent qu'on creuse : héritage voxel. À remapper sur la **profondeur d'étage de donjon** ([[Génération de donjon]] : la corruption effective croît déjà avec l'étage) et la composition des **filons de surface** ([[Récolte]]) — ou à supprimer. La logique « risque/dureté/valeur montent ensemble » reste le principe à préserver.
> — Classement : [[Héritage voxel — audit]] · **Proposition de remplacement à valider : [[Proposition — Minerais et strates après le pivot]]**.

Les filons sont filtrés par bande de profondeur : plus c'est profond, meilleur c'est. Trois pressions (risque, dureté de la roche, valeur du minerai) montent ensemble sur la même verticale.

```
MINERAIS PAR PROFONDEUR — les filons (couche ressources, B.8) sont
filtrés par bande de profondeur : plus c'est profond, meilleur c'est
(data/ore_bands.json, cf. valeurs F.1) :
  0 → -55    : cuivre, étain, zinc, lignite, sel gemme, argile réfract.,
               ocre, tourbe compactée, turquoise, ambre (côtes/forêts)
  -30 → -120 : fer, nickel, manganèse, houille, pyrite, malachite,
               soufre, mica, salpêtre, quartz, bitume, fluorine,
               phosphorite, calcite    (l'ère du fer)
  -80 → -220 : or, argent, cobalt, antimoine, anthracite, graphite,
               cinabre, améthyste, topaze, grenat, lapis-lazuli,
               géodes                  (richesse + acier)
  -160 → -320: platine, titane, chrome, bismuth, opale, jade, rubis,
               saphir, émeraude, kimberlite (roche-hôte du diamant)
  -280 → fond: tungstène, diamant (dans la kimberlite) + filons GÉANTS
FOSSILES : os/ammonites/coquillages dans les roches sédimentaires
  (calcaire, schiste, grès) toutes profondeurs ; bois pétrifié dans
  le tuf ; météorite ferreuse : poches ultra-rares à toute profondeur
  + sites d'impact de surface (POI rare).
Le guano se trouve dans les cavernes peu profondes (engrais, 7.4).
La kimberlite est le SIGNAL du diamant (le prospecteur avisé la
reconnaît — et la guilde des Prospecteurs vend cette information).
Les bandes se CHEVAUCHENT (transitions douces) ; densité et taille des
filons augmentent avec la profondeur DANS chaque bande (un filon de
fer à -100 est plus gros qu'à -40). La couche danger/corruption (3.0)
s'intensifie aussi avec la profondeur (spawns souterrains plus durs) :
le risque, la dureté de la roche et la valeur du minerai montent
ensemble — trois pressions alignées sur la même verticale.
```

**Rappel :** le minage exploratoire souterrain a été écarté ([[Décisions fondatrices]]) — les ressources minérales se récoltent en **filons de surface** ([[Récolte]]). Ces bandes de profondeur restent la logique de placement du champ de bruit et valent pour les cavernes, les donjons et les filons profonds atteignables.

## Liens
- **Dépend de** : [[Stratification verticale]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Récolte]], [[Quêtes et guildes]], [[Catalogue matériaux — Minéraux]], [[Catalogue matériaux — Gemmes]], [[Catalogue matériaux — Fossiles]]
- **Voir aussi** : [[Niveau de danger]], [[Génération par couches de bruit]]
