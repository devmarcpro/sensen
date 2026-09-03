---
aliases: ["H.3", "Annexe H.3", "Conditions de reproduction", "COND", "Coûts de reproduction"]
tags: [société, élevage, données, décidé]
domaine: société
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Les conditions **ne touchent ni au génome ni à l'hérédité** : ce sont des prédicats sur le contexte. Un seul évaluateur — et surtout, il renvoie **pourquoi** ça échoue.

Ce qu'il faut réunir pour qu'un couple se reproduise, et ce que ça coûte.

## Les quinze conditions

```js
const COND = {
  habitat:    (c,a,b,x) => x.habitat===c.v ? null : 'il faut un '+c.v,
  temperature:(c,a,b,x) => x.temp>=c.min && x.temp<=c.max ? null
                 : 'eau à '+Math.round(x.temp)+'°, il en faut entre '+c.min+' et '+c.max,
  humidite:   (c,a,b,x) => …,   salinite: (c,a,b,x) => …,
  lumiere:    (c,a,b,x) => …,   courant:  (c,a,b,x) => …,
  saison:     (c,a,b,x) => c.v.includes(x.saison) ? null : 'pas la saison',
  heure:      (c,a,b,x) => …,
  sexe:       (c,a,b)   => a.sexe!==b.sexe ? null : 'il faut un mâle et une femelle',
  apres:      (c,a,b)   => (a.evt===c.k && b.evt===c.k) ? null : 'seulement après la '+c.k,
  age:        (c,a,b)   => Math.min(a.age,b.age)>=c.min ? null : 'trop jeunes',
  stat:       (c,a,b)   => Math.min(a[c.k],b[c.k])>=c.min ? null : c.k+' insuffisante',
  ressource:  (c,a,b,x) => (S.mat[c.k]||0)>=c.n ? null : 'il faut '+c.n+' '+matName(c.k),
  place:      (c,a,b,x) => x.libre>0 ? null : 'plus de place',
  voisinage:  (c,a,b,x) => x.autour[c.k]>=c.n ? null : 'il faut '+c.n+' '+c.k+' à portée',
};

function peutSeReproduire(a, b, x) {
  const R = espece(a.k).repro, raisons = [];
  if (a.k !== b.k) raisons.push('espèces différentes');
  R.conditions.forEach(c => { const m = COND[c.c](c,a,b,x); if(m) raisons.push(m); });
  return { ok: !raisons.length, raisons };
}
```

**Toutes lisent des systèmes déjà en place** : `temperature` lit la température ressentie de [[Météo]] · `saison` lit le calendrier ([[Décision — Saisons activées à l'étape 10]]) · `heure` lit [[Cycle jour-nuit et sommeil]] · `ressource` lit l'inventaire · `place` et `habitat` lisent le mobilier ([[Meubles]]) · `stat` et `age` lisent le bloc `corps` de [[Blocs de l'être]].

## La règle d'interface, non négociable

> **L'interface doit afficher la raison, jamais un bouton grisé muet.**
> « Eau à 14°, il en faut entre 18 et 26 » vaut **la moitié de la qualité perçue du système**.

C'est la même exigence que la lisibilité du combat ([[Combat tactique sur grille]] : *la lisibilité EST le game feel*) et que l'infobulle exhaustive des modules ([[Vocabulaire des modules — six axes]] : *aucune information cachée, aucun « environ »*). L'écran d'élevage rejoint la liste de [[Écrans d'interface]].

## Les six coûts

Appliqués à la naissance ou à la récolte :

| Coût | Effet |
|---|---|
| `tue_parent` | le parent meurt en donnant naissance |
| `tue_a_la_recolte` | récolter le produit tue l'être (ver à soie, huître) |
| `consomme_ressource` | la reproduction consomme des matériaux |
| `portee_unique_annuelle` | une seule portée par an in-game (120 jours, [[Âge des PNJ]]) |
| `fenetre_courte` | fenêtre de quelques jours seulement (crabes après la mue) |
| `evasion` | risque de fuite — les évadés forment des populations sauvages |

**C'est le coût qui crée l'arbitrage**, pas la rareté : un ver à soie filé est un ver à soie mort ([[Catalogue des groupes d'élevage]], famille *coût par croisement*).

> [!success] Constaté le 2026-09-03 — les drapeaux ci-dessus sont codés sous `repro.conditions` et `repro.couts`
> Une espèce porte `repro` : `moteur`, une liste de `conditions` (`{c: "habitat"}`, `{c: "temperature", min, max}`, `{c: "sexe"}`, `{c: "place"}`…), une `portee` et des `couts`. `consomme_ressource` est un coût dans `couts` ; `fenetre_courte`, `tue_a_la_recolte` et `tue_parent` n'existent pas tels quels — aucune espèce du catalogue n'en avait besoin. Ils s'ajouteraient comme conditions ou coûts, pas comme drapeaux.

## Liens
- **Dépend de** : [[Loci — les dix types]], [[Blocs de l'être]], [[Élevage — intention et familles]]
- **Alimente** : [[Catalogue des groupes d'élevage]], [[Vivarium — capture et élevage]], [[Écrans d'interface]]
- **Voir aussi** : [[Météo]], [[Décision — Saisons activées à l'étape 10]], [[Cycle jour-nuit et sommeil]], [[Meubles]], [[Règle d'anneau]], [[Tests de conformité — élevage]]
