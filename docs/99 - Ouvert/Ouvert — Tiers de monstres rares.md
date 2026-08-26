---
aliases: ["Ouvert — Tiers de monstres rares", "Tiers rares"]
tags: [ouvert, êtres, décidé-par-défaut]
domaine: êtres
statut: décidé-par-défaut
etape: 3
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** les tiers de rareté (or/argent/prismatique) ont-ils des **taux de spawn différenciés**, ou un seul tier « rare » au lancement avec l'extension vers plusieurs tiers plus tard ?

**Ce qui est posé ([[Monstres rares]]) :** `rare_chance` défaut **2 %** (0 pour civils/uniques/bétail). Stats ×2 à ×3 **par tirage de tier**. Teinte or/argent/prismatique **selon tier**. Épithètes tirées d'un pool **par tier**. Drop garanti d'un objet à 3-4 effets.

**Les options :**
- **Un seul tier au lancement** : plus simple, les 2 % restent un seul jet, extension ultérieure sans refonte (les pools d'épithètes et de teintes sont déjà par tier en données).
- **Trois tiers différenciés d'emblée** : plus de granularité de récompense, mais trois pools d'épithètes à écrire et trois teintes à calibrer.

**Ce qui en dépend :** rien de structurel — [[Monstres rares]] *réutilise entièrement les systèmes existants, aucune nouvelle brique technique*. C'est une décision de contenu et d'équilibrage.

## Le défaut : un seul tier au lancement

`rare_chance` **2 %** ([[Schéma créature]]), **stats ×2.5**, teinte **or**, épithète tirée du pool unique, drop garanti **3 effets** ([[Effets d'équipement types]]).

**Pourquoi :** les données sont déjà structurées par tier (pools d'épithètes, teintes) — passer à trois tiers plus tard est un ajout de données, zéro code ([[Décision — Pipeline de contenu]]). Commencer à un tier évite d'écrire trois pools d'épithètes avant d'avoir vu un seul monstre rare en jeu.

**L'extension, si le playtest la réclame :** argent 1.4 % (×2, 3 effets) · or 0.5 % (×2.5, 3 effets) · prismatique 0.1 % (×3, 4 effets).

## Liens
- **Dépend de** : [[Monstres rares]], [[Schéma créature]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]]
- **Voir aussi** : [[Entités et pathfinding — performance]], [[Créatures]], [[Localisation]]
