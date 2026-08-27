---
aliases: ["Niveau de danger", "Corruption", "Couche danger"]
tags: [monde, difficulté, décidé]
domaine: monde
statut: décidé
etape: 8
---

Le danger est une propriété du lieu, jamais du joueur. Le monde ne scale pas.

**Niveau de danger :** déterminé par la couche « danger/corruption » (voir [[Génération par couches de bruit]]), indépendamment de la distance au point d'origine — pas de progression de difficulté façon « plus loin du spawn = plus dur » à la Diablo, et **jamais de scaling sur le niveau du joueur**.

**Ce que la corruption effective pilote ([[Dérive de la corruption]]) :** niveau des créatures qui spawnent, densité des foyers, qualité/rareté du loot (richesse ∝ danger), probabilité de raids ([[Raids et menaces]]), teinte visuelle du biome (feedback).

**La richesse suit toujours le danger** (loot ∝ corruption locale), jamais l'inverse.

**En donjon :** la corruption effective d'un étage est `corruption_locale + etage × 8` (plafonnée à 100) — descendre est toujours un choix qui paie, quel que soit le danger ambiant de la région (voir [[Génération de donjon]]).

**Affichage :** la heat-map de la carte du monde ([[Début de partie]]) est **vague par défaut** — 3 niveaux lisibles (paisible / dangereuse / mortelle) ; la **valeur précise** de corruption se débloque par rang dans la guilde Exploration.

**Extension future non spécifiée — le « Dark Continent » :** voir [[Ouvert — Dark Continent]].

> [!success] Codé le 2026-08-28
> Le danger d'une cellule = la couche `danger` échantillonnée à son centre (le delta hebdomadaire de [[Dérive de la corruption]] attend 8.3b), affiché en **trois niveaux** (`planete.danger.seuils` : 0,45 et 0,75) sur la carte — jamais la valeur précise.

## Liens
- **Dépend de** : [[Génération par couches de bruit]], [[Catalogue des couches de bruit]]
- **Alimente** : [[Dérive de la corruption]], [[Loot — affixes, gemmes et rareté]], [[Raids et menaces]], [[Génération de donjon]], [[Début de partie]]
- **Voir aussi** : [[Minerais par profondeur]], [[Créatures]], [[Ouvert — Dark Continent]], [[Ouvert — Créatures fantastiques]] *(abandonné)*
