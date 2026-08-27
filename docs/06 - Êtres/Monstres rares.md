---
aliases: ["12.4", "12.4 Monstres rares", "Monstres rares", "Variantes rares", "Épithètes"]
tags: [êtres, loot, décidé]
domaine: êtres
statut: décidé
etape: 3
---

Des variantes rares façon Phantasy Star Online — repérables de loin, à drop garanti, et sans une seule nouvelle brique technique.

**Variantes rares :** à la résolution d'un spawn ([[IA des créatures]]), une créature a une faible chance d'apparaître en **variante rare** — exclue pour les civils, PNJ uniques et le bétail (champ `rare_chance` de [[Schéma créature]], défaut **2 %**, 0 pour les exclusions).

- **Stats :** multipliées **×2 à ×3** (tirage par tier) par rapport à la créature de base.
- **Apparence :** teinte distincte (or/argent/prismatique selon tier) via le **paramètre de recolorisation par instance déjà en place pour toutes les créatures** ([[Entités et pathfinding — performance]]) — zéro nouveau système de rendu — plus un effet émissif (glow), repérable de loin, cohérent avec la mécanique `luminosite` ([[Application des stats de matériau]]).
- **Nom affiché :** `[Épithète] [Nom de créature]` (ex. "Loup Blanc Ancestral") — épithètes tirées d'un pool par tier (`data/rare_epithets.json`, localisé, [[Localisation]]).
- **Drop garanti :** un objet à effets ([[Effets d'équipement passifs]]) au budget renforcé (**3-4 effets** au lieu de 0-2) systématiquement à la mort.

**Décisions :**
- Réutilise entièrement les systèmes existants (recolorisation par instance, effets d'équipement) — **aucune nouvelle brique technique**.

**Questions ouvertes :** [[Ouvert — Tiers de monstres rares]] — les tiers (or/argent/prismatique) ont-ils des taux de spawn différenciés, ou un seul tier "rare" au lancement avec l'extension vers plusieurs tiers plus tard ?

**Pas de nom propre ([[Schéma créature]]) :** une variante rare garde son épithète, jamais un prénom/nom de famille culturel.

**Métadonnée de provenance ([[Loot — affixes, gemmes et rareté]]) :** tout loot rare+ porte son origine — donjon, date, **monstre rare**.

> [!success] Codé le 2026-08-27
> Tirage à l'instanciation d'un être contrôlé par l'IA (`rare_chance` de la fiche, défaut 2 % — `loot_rules.json`) : stats de base ×2.5, teinte or via la teinte d'instance du paperdoll, épithète tirée de `data/rare_epithets.json` (un seul tier, [[Ouvert — Tiers de monstres rares]]), drop garanti **exceptionnel à 3 affixes** avec provenance « monstre rare ». Le glow attend les sprites.

## Liens
- **Dépend de** : [[Schéma créature]], [[IA des créatures]], [[Effets d'équipement passifs]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Entités et pathfinding — performance]], [[Application des stats de matériau]], [[Localisation]], [[Créatures]], [[Ouvert — Tiers de monstres rares]]
