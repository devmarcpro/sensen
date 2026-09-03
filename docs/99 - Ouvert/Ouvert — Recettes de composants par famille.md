---
aliases: ["Ouvert — Recettes de composants par famille", "Recettes de composants"]
tags: [ouvert, craft, décidé]
domaine: contenu
statut: décidé
etape: 6
---

> [!success] Résolu le 2026-08-26 — la matrice complète composant × famille (bases + exotiques + sources) est produite : [[Recettes de composants]].

**Contenu à produire ([[Décisions fondatrices]]) :** *recettes d'obtention par composant × famille ([[Composant et recette d'obtention]]) et leurs **sources exotiques**.*

**L'ampleur du travail :** 14 composants standard ([[Composants]]) × N familles de matériaux acceptées chacune = la matrice complète des recettes d'obtention. Chaque entrée porte : `component`, `material_family`, `station`, `unlocked_by_default`, et si exotique : `unlock_sources`.

**Ce qui est déjà écrit comme exemples :** `tete_pioche_metal` (famille lingot_metal, enclume, connue d'office) et `tete_pioche_obsidienne` (famille obsidienne, tailleur de pierre, débloquée par `loot_donjon` ou `guilde_forgerons_rang_3`).

**Les recettes de base connues d'office ([[Craft compositionnel]]) :** manche en bois, tête en lingot métallique...

**Les recettes exotiques à apprendre :** manche en os, en or, lame d'obsidienne, de verre... — via loot de donjon (parchemins), marchands spécialisés, enseignement de guilde par rang.

**Les trois sources de déblocage ([[L'information comme récompense]]) :** loot, achat, et **enseignement par un artisan à haute relation** (palier 75-89) — cette dernière étant le moyen **volontaire** de cibler une recette précise.

**Ce qui en dépend :** toute la boucle de collection parallèle aux modules ([[Craft compositionnel]]), et l'équilibrage par la connaissance qui est le gate principal du craft. S'y ajoutent les recettes du [[Palier industriel]] (*ce sont des entrées de plus en B.13*).

**Question liée :** [[Ouvert — Axe des niveaux de recette]].

> [!success] Constaté le 2026-09-03 — pas de tête de pioche par matière : `tete_pioche_obsidienne` et `tete_pioche_metal` sont codés sous **`tete_outil`**
> Un composant est **à matériau libre** (Craft compositionnel) : la tête d'un outil est `tete_outil`, la matière vient de la recette de composant (`component_recipes/`), pas du nom. `guilde_artisans_rang_3` n'est pas non plus un identifiant : les débloquages se déclarent dans `unlock_sources` d'une recette.

## Liens
- **Dépend de** : [[Composant et recette d'obtention]], [[Composants]], [[Craft compositionnel]]
- **Alimente** : [[Palier industriel]], [[Loot — affixes, gemmes et rareté]], [[Quêtes et guildes]]
- **Voir aussi** : [[Catégories de matériaux]], [[L'information comme récompense]], [[Ouvert — Axe des niveaux de recette]], [[Décisions fondatrices]]
