---
aliases: ["A.9.1", "Annexe A.9.1", "Nourriture et potentiel", "Viande paramétrique", "Potions formule"]
tags: [société, craft, formule, décidé]
domaine: société
statut: décidé
etape: 10
---

Les formules de la cuisine et de l'alchimie : plat, viande paramétrique, cru, potion.

```
PLAT : potentiel_gagné(stat) = Σ bonus_ingredients(stat)
         * (nutrition_totale / 100) * qualite_plat (A.3)
  répartis à la consommation ; nutrition remplit la faim (A.9).
VIANDE (paramétrique) : bonus_potentiel(stat) =
         stat_source_creature / 10  (arrondi, max 8 par stat)
  ex. ours brun For 14 → viande : +1.4 → +1 potentiel Force par unité
  cuisinée dans un plat (multiplié par nutrition/qualité).
CRU : manger cru = 50 % de la nutrition, aucun bonus de potentiel,
  risque d'infection (F.5) — cuisiner est toujours mieux.
POTION : intensité = effet_base * qualite_potion (A.3, Alchimie)
         durée = durée_base * (0.5 + qualite_potion / 2)
  1 potion active max par famille d'effet (pas d'empilement de
  potions de Force) ; les potions passent par les statuts (F.4)
  et le résolveur de modificateurs (E.4) — zéro système nouveau.
```

**Bonus Wu Xing ([[Cuisine et alchimie]]) :** un plat couvrant les cinq éléments gagne ×1.2 en nutrition **et** potentiel.

**Statut Infection ([[Statuts]]) :** Endurance −2/jour jusqu'à soin — maladie longue. Viande crue = 20 % de risque d'infection ([[Nourriture]]).

> [!success] Précisé le 2026-08-28
> La formule du plat est codée à l'étape 7 avec des bonus **fixes** en données (`potentiel` du consommable) : `potentiel_gagné = Σ bonus × nutrition/100 × qualité(A.3 Cuisine)`, cap 200. Les viandes paramétriques, le ×1,2 des cinq éléments et les potions attendent l'étape 10.

> [!success] Corrigé le 2026-08-30 — l'huile d'arme ne brûlait qu'avec une arme de Feu
> Le bonus de l'huile (`degats_element_bonus`) était lu **par l'élément dominant de l'arme** : une huile de Feu sur une dague de fer (Métal) n'ajoutait jamais son `1d4`. Le test qui devait le garantir comparait quarante coups « avec » à quarante coups « sans » — deux distributions identiques, donc un tirage à pile ou face qu'il avait gagné jusqu'ici ; un décalage du générateur l'a fait perdre, et le bug est apparu. Les dés de l'huile s'ajoutent désormais **quel que soit l'élément de l'arme** — c'est une couche sur la lame, pas une affinité. Le bonus des plats (`degats_element`) reste lié à l'élément de l'arme : un plat aligne, une huile enduit.

## Liens
- **Dépend de** : [[Cuisine et alchimie]], [[Qualité d'artisanat]], [[Potentiel]], [[Faim]]
- **Alimente** : [[Potions]], [[Nourriture]], [[Statuts]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Schéma créature]], [[Catalogue matériaux — Paramétriques]], [[Wu Xing hors combat]]
