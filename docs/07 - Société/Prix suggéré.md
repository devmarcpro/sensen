---
aliases: ["A.8", "Annexe A.8", "Prix suggéré", "Prix"]
tags: [société, économie, formule, décidé]
domaine: société
statut: décidé
etape: 9
---

La formule de prix du jeu, et la tolérance des PNJ au sur-prix.

```
prix_suggere = valeur_base_objet * qualite * facteur_rarete * facteur_reputation
valeur_base_objet = somme(valeur_base des matériaux * quantités) * 1.5 (marge d'artisanat)
facteur_reputation = 1 + (reputation_locale / 200)     (borné à [0.5, 2.0])
```

Les PNJ acceptent d'acheter en boutique passive si `prix_affiché <= prix_suggere * random(0.9, 1.3)` — vendre trop cher ralentit les ventes sans les bloquer totalement.

**`facteur_rarete`, chiffré le 2026-08-26** (il était cité dans la formule et défini nulle part) :

| Rareté | Facteur | + par affixe | + par sertissure occupée |
|---|---|---|---|
| commun | **1.0** | — | — |
| inhabituel | **1.4** | +0.35 | +0.50 |
| rare | **2.2** | +0.35 | +0.50 |
| exceptionnel | **4.0** | +0.35 | +0.50 |
| artefact | **10.0** | — | *(ni sertissable ni infusable)* |

Les bonus s'ajoutent au facteur avant multiplication. Une arme exceptionnelle à 3 affixes et 2 gemmes vaut donc `4.0 + 1.05 + 1.0 = 6.05 ×` la valeur de ses matériaux — et reste **incomparable** à un craft, puisque l'atelier ne produit pas d'affixes ([[Loot — affixes, gemmes et rareté]]).

**Stat de matériau consommée :** `valeur_base` ([[Matériaux — 13 stats]]).

**Modulation par la réputation ([[Réputation et relations]]) :** ≤ −50 hostile · −49..−20 prix **+25 %** · +20..+49 prix **−10 %**.

**Douanes ([[Lois et infractions]]) :** `prix_final = prix_suggere × (1 - tariffs[categorie])` ; `tariff >= 1.0` → vente/import refusés.

**Qualité de loot en profondeur ([[Génération de donjon]]) :** la corruption effective d'étage module la qualité/rareté du loot via cette formule et [[Qualité d'artisanat]].

**Valeur des trophées ([[Créatures]]) :** la statue 1:1 a une valeur de vente ∝ niveau de la créature.

> [!success] Constaté codé le 2026-08-31 — la note vivait sans callout
> `Simulation.prix_suggere()` implémente la formule telle quelle (Σ valeur_base des matériaux × 1,5 de marge × qualité × facteur de rareté × réputation bornée [0,5 ; 2,0] avec les paliers +25 % / −10 %), et **toute la table** vit dans `combat_rules.commerce` : facteurs 1,0 / 1,4 / 2,2 / 4,0 / 10,0, +0,35 par affixe, +0,50 par sertissure, rachat marchand à 50 % (`achat_ratio`), tolérance de troc ±15 %. Les douanes s'appliquent à l'achat (`tarif_de`, refus à ≥ 1,0). L'écran de commerce montre le détail du calcul.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Qualité d'artisanat]], [[Réputation et relations]]
- **Alimente** : [[Commerce et boutiques]], [[Boutique passive]], [[Barèmes économiques]], [[Lois et infractions]]
- **Voir aussi** : [[Loot — affixes, gemmes et rareté]], [[Stats de personnage]], [[Génération de donjon]], [[Créatures]]
