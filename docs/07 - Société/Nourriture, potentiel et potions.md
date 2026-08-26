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

## Liens
- **Dépend de** : [[Cuisine et alchimie]], [[Qualité d'artisanat]], [[Potentiel]], [[Faim]]
- **Alimente** : [[Potions]], [[Nourriture]], [[Statuts]]
- **Voir aussi** : [[Résolveur de modificateurs]], [[Schéma créature]], [[Catalogue matériaux — Paramétriques]], [[Wu Xing hors combat]]
