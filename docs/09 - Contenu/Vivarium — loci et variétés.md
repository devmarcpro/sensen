---
aliases: ["H.6", "Annexe H.6", "Vivarium", "Vivarium — loci et variétés", "Insectes", "154 112 variétés"]
tags: [contenu, élevage, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Le groupe des insectes est le **modèle de référence, entièrement spécifié**. Tout nouveau groupe se calque dessus.

Quatre loci, 154 112 variétés, et les unis qui émergent au lieu d'être une case du tableau.

## Les quatre loci

**espèce → couleur principale → motif → couleur du motif**

- **32 espèces**, réparties sur 8 biotopes × jour/nuit — **aucun créneau vide**.
- **16 couleurs** sur un anneau en dégradé continu ([[Règle d'anneau]]) :
  *Ivoire · Cendre · Ardoise · Encre · Grenat · Vermillon · Corail · Ambre · Or · Citron · Olive · Mousse · Jade · Turquoise · Indigo · Améthyste*
- **20 motifs**, tous **procéduraux** — des fonctions de `(x, y)`, jamais des masques plaqués, pour qu'ils **épousent la silhouette** ([[Apparence — données et équipement]]).
- **16 couleurs de motif**, puisées dans **la même palette** que la couleur principale.

## Les unis émergent

Il n'y a **pas de motif « Uni »**. Quand les deux couleurs tombent sur la même valeur, l'insecte est uni **quel que soit son motif**. C'est une propriété qui **émerge** au lieu d'être une case du tableau — et le registre ne la compte qu'une fois.

```
par espèce : 16 unis + 16 × 20 × 15 contrastés = 4 816 variétés
au total   : 32 × 4 816 = 154 112 variétés
```

Plus le drapeau **chatoyant** — **1,5 %** à la naissance, **×6** si un parent l'est.

*C'est le même principe de design que les « types d'armure » de [[Armure par zone et constructions]] : ils n'existent pas comme étiquettes, ils émergent des constructions. Une propriété qui émerge ne coûte rien à maintenir.*

## Silhouettes

Chaque espèce est dessinée sur une grille **13×13**, à arêtes nettes, avec quatre types de cases :

| Case | Rendu |
|---|---|
| `o` corps | couleur principale, motif appliqué |
| `w` aile | idem, opacité 0.82 (membrane) |
| `h` tête | toujours sombre |
| `l` patte, antenne | couleur principale assombrie |

Le motif étant une fonction de `(x, y)` :

> **La même variété ne rend pas pareil selon l'espèce.** Un jade rayé d'ambre sur un sphinx, ce sont deux grandes ailes barrées ; sur un phasme, trois traits sur une brindille.

**Couverture mesurée**, du plus discret au plus voyant : Moucheté et Pointillé 13 %, Larmes 17 %, Constellé 15 %, Ocellé 26 %, Rayé 29 %, Croisillon 33 %, Oblique 42 %, Chevron 50 %, Damier 52 %.

## Liens
- **Dépend de** : [[Règle d'anneau]], [[Loci — les dix types]], [[Apparence — données et équipement]]
- **Alimente** : [[Vivarium — capture et élevage]], [[Vivarium — registre et paliers]]
- **Voir aussi** : [[Élevage — intention et familles]], [[Catalogue des groupes d'élevage]], [[Direction artistique]], [[Palette de couleurs des matériaux]], [[Ouvert — Cinquième locus visuel]]
