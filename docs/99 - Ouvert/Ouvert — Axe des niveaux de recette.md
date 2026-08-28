---
aliases: ["Ouvert — Axe des niveaux de recette", "Niveaux de recette"]
tags: [ouvert, craft, décidé-par-défaut]
domaine: objets
statut: décidé-par-défaut
etape: 6
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** sur quel axe unique portent les 5 niveaux d'une recette de composant ?

**Les options envisagées :**
- **efficacité matière** (moins de matériaux consommés par craft)
- **vitesse et lots** (craft plus rapide, ou plusieurs unités par opération)
- **stabilité du jet** (variance réduite sur le tirage de qualité)

**Contrainte non négociable :** le niveau de recette **ne multiplie jamais la qualité** — sinon farmer des parchemins court-circuite la progression de compétence.

**Ce qui en dépend :** [[Craft compositionnel]] (les doublons de parchemins ne doivent jamais être du loot mort), la valeur relative de l'enseignement par un artisan à haute relation ([[L'information comme récompense]]), l'équilibrage de [[Qualité d'artisanat]].

**Implémentable sans :** oui — la mécanique des 5 niveaux et du coût croissant (N doublons pour passer au niveau N, 10 au total) est posée ; seul le bonus reste à trancher.

## Le défaut : la stabilité du jet

**Niveau de recette N (1-5) → resserre le tirage de qualité du composant** ([[Qualité d'artisanat]]) :

```
random(0.85, 1.15)  →  random(0.85 + 0.03×(N−1), 1.15 − 0.03×(N−1))
N1 : 0.85–1.15  ·  N3 : 0.91–1.09  ·  N5 : 0.97–1.03
```

**Pourquoi celui-là :** c'est le seul des trois axes qui **ne multiplie jamais la qualité** (la contrainte non négociable) — la moyenne reste identique, seule la variance baisse. Un artisan qui maîtrise sa recette rate moins, il ne fait pas mieux. Les deux autres axes (efficacité matière, vitesse/lots) restent disponibles comme bonus secondaires si le playtest les réclame.

> [!success] Codé le 2026-08-28 — la stabilité du jet, telle quelle
> `e.niveaux_recettes` (recette → N, 1 par défaut) et `e.doublons_recettes` : **relire un plan déjà connu** compte un doublon ; quand les doublons atteignent **N**, la recette passe au niveau **N + 1** (max 5 — soit 1 + 2 + 3 + 4 = 10 doublons pour le niveau 5, la note dit 10 au total) et le compteur repart. Le journal dit le niveau atteint, ou « encore k doublons ». **Effet** : `Regles.qualite_craft(niveau, rng, resserrement)` — l'aléa `[0,85 ; 1,15]` devient `[0,85 + 0,03 × (N−1) ; 1,15 − 0,03 × (N−1)]` (`combat_rules.craft.qualite.resserrement_par_niveau`), appliqué aux composants, à l'assemblage des objets et aux plats. **La qualité n'est jamais multipliée** : seule la variance se resserre — un artisan de haut niveau de recette produit du régulier, pas du meilleur.

## Liens
- **Dépend de** : [[Craft compositionnel]], [[Composant et recette d'obtention]]
- **Alimente** : [[Qualité d'artisanat]]
- **Voir aussi** : [[Décisions fondatrices]], [[L'information comme récompense]]
