---
aliases: ["H.1", "Annexe H.1", "Règle d'anneau", "Anneau", "Hérédité qualitative"]
tags: [société, élevage, formule, décidé]
domaine: société
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Le mécanisme central de l'hérédité, et celui qui donne son plaisir au système.

Une valeur lointaine ne s'obtient jamais d'un coup : **elle se marche.**

## La règle

Chaque caractère qualitatif vit sur un **anneau ordonné** — les couleurs par nuances voisines, les motifs par familles graphiques. La descendance hérite de la valeur de l'un des parents, **ou de l'une de ses voisines immédiates**.

```
34 %  la valeur du parent A
34 %  la valeur du parent B
16 %  une voisine de A   (8 % de chaque côté)
16 %  une voisine de B
```

**C'est la même logique que le cycle d'engendrement du Wu Xing** ([[Wu Xing — cycles et vecteurs]] : les éléments sont un anneau, on avance de proche en proche) — et elle récompense exactement ce qu'on veut récompenser : la **sélection dirigée**.

## Ce que ça mesure

Sur un anneau de 16 couleurs, départ à 0 :

| Cible | En visant | Au hasard |
|---|---|---|
| 2 crans | 14 couvées | — |
| 4 crans | 28 couvées | — |
| 6 crans | 45 couvées | — |
| **8 crans** (l'opposé) | **57 couvées** | **833 couvées** |

> **Le facteur quinze entre le joueur qui sélectionne et celui qui laisse faire est la mesure que le système fonctionne.**

C'est le critère de validation du mécanisme : si ce facteur s'écrase, les probabilités sont à revoir — pas le système.

## Implémentation

Fonction unique, appliquée à tout locus de type `anneau` ([[Loci — les dix types]]) :

```js
anneau: (a, b, L) => {
  const r = Math.random();
  if (r < .34) return a;
  if (r < .68) return b;
  const s = Math.random() < .5 ? a : b;
  return ring(s + (Math.random() < .5 ? 1 : -1), L.n);
}
```

`L.n` est la taille de l'anneau, déclarée par l'espèce. **Aucune connaissance de l'espèce dans la fonction.**

## Point de tuning

Avec trois loci qui bougent à chaque couvée, **216 issues possibles** ([[Vivarium — loci et variétés]]). Si le résultat paraît aléatoire au lieu de dirigé, passer de **34/34/16/16** à **40/40/20** — à trancher au playtest, pas en simulation ([[Ouvert — Équilibrage du contraste]]).

## Liens
- **Dépend de** : [[Loci — les dix types]], [[Élevage — intention et familles]]
- **Alimente** : [[Vivarium — loci et variétés]], [[Vivarium — capture et élevage]], [[Apparence — données et équipement]]
- **Voir aussi** : [[Wu Xing — cycles et vecteurs]], [[Conditions de reproduction]], [[Ouvert — Équilibrage du contraste]], [[Tests de conformité — élevage]]
