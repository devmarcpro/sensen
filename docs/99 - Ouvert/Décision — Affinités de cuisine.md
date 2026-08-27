---
aliases: ["Décision — Affinités de cuisine", "Ouvert — Affinités élémentaires de cuisine", "Affinités de cuisine", "Affinités des ingrédients"]
tags: [contenu, wuxing, société, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 10
---

> [!success] Décidé le 2026-08-26
> Table produite sur délégation. Le design voulu : **le Feu vient de la cuisson et le Métal du sel** — l'assiette aux cinq éléments est un vrai puzzle, pas un automatisme.

Les affinités élémentaires des ingrédients de cuisine ([[Cuisine et alchimie]] : un plat couvrant les cinq éléments gagne ×1.2 en nutrition et potentiel).

## Trois règles

1. **La cuisson ajoute du Feu** (*plus la transformation est violente, plus le Feu entre* — [[Wu Xing hors combat]]) : tout plat **cuisiné** reçoit un AJOUT `feu 0.15` avant normalisation ([[Modificateurs d'affinité]] — même opération que partout). Manger cru n'en bénéficie pas (cohérent : le cru est déjà pénalisé, [[Nourriture, potentiel et potions]]).
2. **Les viandes portent le vecteur de leur créature source** (champ `elements` de [[Schéma créature]]) ; défaut si `null` : `bois 0.5 / eau 0.5` (chair et sang). Poisson : `eau 0.8 / bois 0.2`. Œuf : `bois 0.5 / eau 0.5`.
3. **La rareté est le design** : le Bois est partout (verdure), la Terre facile (racines, champignons), l'Eau accessible (fruits, poisson), le **Feu** vient de la cuisson et des piquants, le **Métal** presque uniquement du **sel** et de l'achillée. L'assiette harmonieuse = verdure + racine + fruit/poisson + sel + cuisson.

## La table (`data/plants/` champ `wuxing`, + ingrédients divers)

**Cultures ([[Plantes]]) :**

| Ingrédient | wuxing | | Ingrédient | wuxing |
|---|---|---|---|---|
| Blé | bois 0.7 / terre 0.3 | | Orge | bois 0.7 / terre 0.3 |
| Carotte | terre 0.6 / bois 0.4 | | Pomme de terre | terre 0.7 / bois 0.3 |
| Chou | bois 0.8 / eau 0.2 | | Oignon | feu 0.5 / terre 0.5 *(piquant)* |
| Citrouille | terre 0.5 / bois 0.5 | | Tomate | bois 0.5 / eau 0.5 |

**Buissons, vignes, cueillette :**

| Ingrédient | wuxing | | Ingrédient | wuxing |
|---|---|---|---|---|
| Framboise, Myrtille, Baies | bois 0.6 / eau 0.4 | | Raisin | bois 0.5 / eau 0.5 |
| Houblon | bois 0.8 / eau 0.2 | | Pomme | bois 0.6 / eau 0.4 |
| Miel | bois 0.6 / terre 0.4 | | Champignon des prés | terre 0.6 / bois 0.4 |
| Amanite | terre 0.5 / eau 0.5 | | | |

**Herbes ([[Plantes]]) :**

| Herbe | wuxing | | Herbe | wuxing |
|---|---|---|---|---|
| Camomille | bois 0.6 / eau 0.4 | | Menthe | eau 0.6 / bois 0.4 *(fraîcheur)* |
| Sauge | bois 0.5 / eau 0.5 | | Achillée | bois 0.6 / **metal 0.4** |
| Ortie | bois 0.7 / feu 0.3 *(pique)* | | Belladone | eau 0.5 / terre 0.5 |

**Divers :**

| Ingrédient | wuxing |
|---|---|
| **Sel** (sel gemme en cuisine) | **metal 0.5** / eau 0.5 *(« le métal enrichit l'eau »)* |
| Viande grillée / crue | vecteur de la créature source (règle 2) |
| Poisson | eau 0.8 / bois 0.2 |
| Pain | bois 0.6 / terre 0.25 / feu 0.15 *(blé cuit)* |

**Exemple d'assiette harmonieuse :** ragoût = viande (Bois/Eau) + pomme de terre (Terre) + oignon (Feu) + **sel (Métal)** + cuisson (+Feu) → les cinq éléments couverts, ×1.2. Sans sel, pas de Métal : le sel gemme devient un ingrédient recherché — cohérent avec son rôle de conservation ([[Catalogue matériaux — Minéraux]]).

> [!success] Codé le 2026-08-28
> Les ingrédients portent `wuxing` (cultures, baies, miel, champignon, pain ; **viandes** : vecteur `elements` de la créature source, défaut bois 0,5 / eau 0,5 ; **sel gemme** : `combat_rules.craft.harmonie.ingredients_materiaux` — metal 0,5 / eau 0,5 en cuisine, sans toucher au vecteur de combat du matériau). Les recettes de plats acceptent des **entrées optionnelles** (`optionnel: true` — toute pile taguée `ingredient` ou le sel gemme brut, consommées si présentes dans le sac, jusqu'à trois). Le vecteur du plat = Σ ingrédients + `feu 0,15` (cuisson), normalisé ; **cinq éléments > 0 → `harmonie` 1,2** sur la nutrition et le potentiel à l'ingestion (journal « assiette harmonieuse »). Décision : les entrées optionnelles sont prises d'office dans l'ordre du sac — le choix fin des ingrédients attend un écran.

## Liens
- **Dépend de** : [[Cuisine et alchimie]], [[Wu Xing hors combat]], [[Plantes]]
- **Alimente** : [[Nourriture, potentiel et potions]], [[Potentiel]], [[Nourriture]]
- **Voir aussi** : [[Décision — Surcharges Wu Xing des matériaux]], [[Modificateurs d'affinité]], [[Catalogue matériaux — Paramétriques]]
