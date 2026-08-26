---
aliases: ["Décision — Saisons activées à l'étape 10", "Saisons activées", "Saisons"]
tags: [monde, société, élevage, décidé]
domaine: monde
statut: décidé
etape: 10
---

> [!warning] Cette décision en renverse une précédente
> [[Ouvert — Saisons]] fixait « **non incluses au lancement** », en notant que *la question ne peut pas se trancher avant d'avoir joué la boucle agricole*. **L'Annexe H tranche la question à sa place** : l'élevage rend les saisons load-bearing. Renversement assumé, motivé ci-dessous.

Les saisons sont **activées**, en même temps que l'élevage et l'agriculture — étape 10 de [[Ordre de construction]].

## Pourquoi le renversement

L'Annexe H ([[Élevage — intention et familles]]) fait des saisons une **dépendance dure**, pas un agrément :

- la condition `saison` est l'une des quinze de [[Conditions de reproduction]] ;
- des groupes entiers du [[Catalogue des groupes d'élevage]] en dépendent structurellement : le **rut d'automne** des cervidés, la **tonte saisonnière** des moutons, les hirondelles qui **migrent une saison sur deux**, la floraison qui nourrit les **ruches**, la marée des **coquillages** ;
- le coût `portee_unique_annuelle` n'a aucun sens sans année lisible.

Sans saisons, six des trente-cinq groupes deviennent inertes et la famille « le monde décide » perd son verbe. **Le doute de [[Ouvert — Saisons]] est levé par une exigence de contenu, pas par une préférence.**

## Ce qui est activé

```
1 an in-game = 120 jours (déjà fixé, Âge des PNJ)
             = 4 saisons de 30 jours

Printemps → Bois   ·  Été → Feu  ·  Fin d'été → Terre
Automne   → Métal  ·  Hiver → Eau
```

*(L'attribution daoïste traditionnelle — la « fin d'été » du Wu Xing est une cinquième saison courte, ici les 10 derniers jours de l'été. Cohérent avec [[Identité visuelle chinoise]] et [[Wu Xing — cycles et vecteurs]].)*

**Implémentation, telle que [[Météo]] l'avait prévue :** *multiplier le bruit temporel par une courbe annuelle* — une courbe sur `temperature`, plus un champ `saison` exposé par l'horloge du monde ([[Simulation à ticks]]). **Aucun système nouveau**, exactement ce que la note annonçait.

## Ce que ça touche, et ce que ça ne touche pas

**Touché :** [[Agriculture et élevage]] (cycles de culture — c'est le gros du travail d'équilibrage), [[Météo]] (courbe annuelle sur la température), [[Conditions de reproduction]] (condition `saison`), [[Catalogue des groupes d'élevage]].

**Non touché :** le combat, le loot, les donjons, le craft, les royaumes — aucun ne lit la saison. Le risque du renversement est **borné à la boucle agricole**, qui est précisément ce que [[Ouvert — Saisons]] voulait attendre… et qui arrive en même temps, à l'étape 10.

**Extension gratuite :** les saisons alignées sur les éléments deviennent disponibles comme modificateur de lieu ([[Wu Xing hors combat]] : *saisons alignées sur les éléments, extension future naturelle*) — à activer ou non séparément, ce n'est pas dans cette décision.

## Liens
- **Dépend de** : [[Élevage — intention et familles]], [[Météo]], [[Ouvert — Saisons]]
- **Alimente** : [[Conditions de reproduction]], [[Agriculture et élevage]], [[Catalogue des groupes d'élevage]]
- **Voir aussi** : [[Âge des PNJ]], [[Wu Xing hors combat]], [[Identité visuelle chinoise]], [[Ordre de construction]]
