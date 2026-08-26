---
aliases: ["Décision — Minerais et strates après le pivot", "Proposition — Minerais et strates après le pivot", "Minerais après pivot", "Strates après pivot"]
tags: [ouvert, proposition, héritage-voxel, monde, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Stratification verticale]] et [[Minerais par profondeur]] placent roches et minerais par bandes de profondeur Y — mais on ne creuse plus nulle part ([[Décisions fondatrices]] : minage exploratoire écarté). Les ressources se récoltent en **filons de surface** ([[Récolte]]) et les donjons descendent en **étages discrets**. Le principe à sauver : *le risque, la dureté et la valeur montent ensemble*.

## La proposition : remapper les deux axes

**1. Filons de surface — les bandes Y deviennent des tiers par corruption effective** ([[Dérive de la corruption]]), pondérés par biome. La richesse suit le danger, exactement comme le veut [[Niveau de danger]] :

```
tier 1 (partout)          : cuivre, étain, zinc, lignite, sel gemme,
                            argile réfractaire, ocre, tourbe compactée
tier 2 (corruption ≥ 20,  : fer, nickel, manganèse, houille, pyrite,
        ou biome montagne)  malachite, soufre, mica, salpêtre, quartz,
                            bitume, fluorine, phosphorite, calcite
tier 3 (corruption ≥ 45,  : or, argent, cobalt, antimoine, anthracite,
        montagne cristal.)  graphite, cinabre, améthyste, topaze,
                            grenat, lapis-lazuli, turquoise, ambre
tier 4 (corruption ≥ 70)  : platine, titane, chrome, bismuth, opale,
                            jade, rubis, saphir, émeraude, kimberlite
tier 5 (corruption ≥ 90)  : tungstène, diamant (signalé par la
                            kimberlite à proximité)
```

**2. Donjons — les bandes Y deviennent des bandes d'étage.** Les salles reçoivent des filons muraux (contenu de tuile récoltable) selon la profondeur d'étage — cohérent avec [[Génération de donjon]] où la corruption effective croît déjà de +8 par étage :

```
étages 1-2 : tiers 1-2 · étages 3-4 : tiers 2-3 · étages 5-6 : tiers 3-4
étages 7+  : tiers 4-5, kimberlite comme sol des salles à diamant
```

**3. Les strates G.9 deviennent la palette de sol des étages de donjon** — la dureté du sol croît avec l'étage, ce qui garde un sens tactique (sorts de terrain, [[Destruction du terrain]], [[Explosions]]) :

```
étages 1-2 : calcaire/grès · 3-4 : ardoise/pierre · 5-6 : basalte
étages 7+  : granit, puis granit noir
```

**4. Cas particuliers :** fossiles sédimentaires → étages 1-3 + affleurements de falaise en surface · météorite ferreuse → POI de surface (déjà prévu, [[Catalogue matériaux — Fossiles]]) · guano → donjons à thème « repaire », étages 1-2 (plus de cavernes).

## Ce que ça préserve

Les trois pressions alignées (risque = corruption/étage, dureté du sol, valeur du minerai), la kimberlite comme signal du diamant vendu par les Prospecteurs, et l'intégralité des données de [[Minerais par profondeur]] — seule la **clé de placement** change (Y → corruption/étage).

## Ce qui reste à trancher

Les seuils exacts des tiers ; la densité de filons muraux par salle ; si la règle d'irrécoltabilité ([[Récolte]]) suffit comme second verrou ou si certains tiers exigent un outil minimum.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Minerais par profondeur]], [[Stratification verticale]], [[Dérive de la corruption]]
- **Alimente** : [[Récolte]], [[Génération de donjon]], [[Salles et connecteurs]]
- **Voir aussi** : [[Niveau de danger]], [[Catalogue matériaux — Gemmes]], [[Quêtes et guildes]]
