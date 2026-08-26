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

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Qualité d'artisanat]], [[Réputation et relations]]
- **Alimente** : [[Commerce et boutiques]], [[Boutique passive]], [[Barèmes économiques]], [[Lois et infractions]]
- **Voir aussi** : [[Loot — affixes, gemmes et rareté]], [[Stats de personnage]], [[Génération de donjon]], [[Créatures]]
