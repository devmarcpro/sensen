---
aliases: ["F.9", "Annexe F.9", "Potions", "12 potions", "Potions de départ"]
tags: [contenu, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 10
---

Les 12 potions de départ — alchimie, station Alambic.

Potion de soin (2d6 PV, instantané) · de Force/Dextérité/Endurance/Volonté/Perception/Charisme (+3 stat, 10 min) · de résistance au feu / au froid (isolation +40, 10 min) · de vision nocturne (tag, 10 min) · de respiration aquatique (tag, 5 min) · Antipoison (purge + immunité 5 min) · Poison de lame (applique le statut Poison aux attaques, 5 min — **illégal dans la plupart des royaumes**, [[Lois et infractions]]).

**Formule ([[Nourriture, potentiel et potions]]) :**
```
POTION : intensité = effet_base * qualite_potion (A.3, Alchimie)
         durée = durée_base * (0.5 + qualite_potion / 2)
  1 potion active max par famille d'effet (pas d'empilement de
  potions de Force) ; les potions passent par les statuts (F.4)
  et le résolveur de modificateurs (E.4) — zéro système nouveau.
```

**Ingrédients ([[Cuisine et alchimie]]) :** parties de créatures ([[Catalogue matériaux — Paramétriques]]) et plantes ([[Plantes]]) — les propriétés de la partie/plante orientent l'effet (un œil → potions de Perception/vision, une griffe → potions de Force).

**Tags accordés ([[Effets d'équipement types]]) :** `vision_nocturne`, `respiration_aquatique` — les mêmes que les `grant_tag` de l'équipement.

**Isolation ([[Application des stats de matériau]]) :** +40 d'isolation contre la chaleur/le froid — `degats_subis *= (1 - isolation_armure / 125)`.

**Puissance court terme ([[Cuisine et alchimie]]) :** distiller donne la puissance court terme via buffs ; cuisiner donne la croissance long terme via potentiel.

## Liens
- **Dépend de** : [[Cuisine et alchimie]], [[Nourriture, potentiel et potions]], [[Qualité d'artisanat]]
- **Alimente** : [[Statuts]], [[Résolveur de modificateurs]]
- **Voir aussi** : [[Plantes]], [[Catalogue matériaux — Paramétriques]], [[Effets d'équipement types]], [[Lois et infractions]], [[Application des stats de matériau]], [[Stations de transformation]], [[Stats de personnage]]
