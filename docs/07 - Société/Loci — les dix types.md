---
aliases: ["H.2", "Annexe H.2", "Loci", "Les dix types de loci", "Génome"]
tags: [société, élevage, données, décidé]
domaine: société
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Le génome n'est pas un objet figé : c'est un **dictionnaire dont la forme est déclarée par l'espèce**. Dix types de loci suffisent à tout le catalogue.

Comment un caractère se transmet — dix mécaniques, une fonction chacune, écrites une seule fois.

## Les dix types

| Type | Hérédité | Exemples |
|---|---|---|
| `anneau` | [[Règle d'anneau]] | couleur, motif, couleur du motif |
| `nombre` | moyenne des parents → dérive gaussienne | taille, endurance, finesse du fil |
| `recessif` | deux allèles, un seul visible | écailles, spirale senestre |
| `lie_au_sexe` | porté par un chromosome | pelage écaille-de-tortue |
| `sequence` | mélange position par position | chant, rythme de clignotement |
| `carte` | déformation de la carte d'un parent | taches d'une carpe koï |
| `acquis` | **non hérité**, fixé après la naissance | caste, mélanisme, école de dressage |
| `age` | s'exprime avec le temps | ramure, dossière, mue |
| `colonie` | porté par le groupe, pas l'individu | ruche, fourmilière, meute |
| `automate` | généré par une règle, jamais tiré | motif de coquillage |

## Les fonctions d'hérédité

Une seule par type, écrite une fois — **aucune ne connaît d'espèce** :

```js
const HERITE = {
  anneau:   (a,b,L) => { const r=Math.random();
    if(r<.34) return a; if(r<.68) return b;
    const s = Math.random()<.5 ? a : b;
    return ring(s + (Math.random()<.5 ? 1 : -1), L.n); },
  nombre:   (a,b,L) => clamp(L.min, L.max, (a+b)/2 * (1 + gauss()*L.var)),
  recessif: (a,b)   => [pick(a), pick(b)],
  sequence: (a,b)   => a.map((v,i) => Math.random()<.5 ? v : b[i]),
  carte:    (a,b,L) => deformer(Math.random()<.5 ? a : b, L.mut),
  acquis:   ()      => null,
};
```

*(`lie_au_sexe`, `age`, `colonie` et `automate` ne se résolvent pas à la conception : le premier lit le sexe de l'enfant, les deux suivants s'expriment plus tard — [[Simulation du monde — performance]], passage hebdomadaire — et le dernier est calculé, jamais tiré.)*

## Pas de plafond

Conformément au principe du GDD sur les compétences ([[Progression par l'usage]] : *sans plafond*), **les loci `nombre` n'ont pas de maximum**. Seule une dérive par génération, à rendement décroissant.

> Un mouton parti à 8 de Force peut atteindre **300 en cent générations sélectionnées**. C'est long, c'est du travail, et **rien ne l'interdit.**

C'est exactement ce qui rend possible le mouton ultime de [[Blocs de l'être]] — la puissance n'est pas accordée, elle est atteinte.

## La règle d'or

> **Aucun `if (espèce === 'x')` dans le code.**
> Si une espèce réclame une exception, c'est qu'il manque **un type de locus, une condition ou un crochet** — et c'est le registre qu'il faut étendre, pas le cas particulier.

C'est la déclinaison exacte de [[Data-driven design]] au vivant, et c'est vérifié par [[Tests de conformité — élevage]].

## Liens
- **Dépend de** : [[Élevage — intention et familles]], [[Data-driven design]], [[Blocs de l'être]]
- **Alimente** : [[Règle d'anneau]], [[Conditions de reproduction]], [[Apparence — données et équipement]], [[Catalogue des groupes d'élevage]]
- **Voir aussi** : [[Progression par l'usage]], [[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]], [[Décision — Pipeline de contenu]]
