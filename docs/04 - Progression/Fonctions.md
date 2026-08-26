---
aliases: ["Fonctions", "Fonction", "Postes de travail", "Métiers", "Commerçant", "Artisan"]
tags: [progression, société, contenu, décidé]
domaine: progression
statut: décidé
etape: 9
---

> [!success] Décidé le 2026-08-26
> La fonction est le troisième axe de [[Les trois axes — race, classe, fonction]]. Elle **absorbe** les 11 postes de travail, le champ `agenda.métier` ([[Blocs de l'être]]) et `leadership_role` ([[Schéma créature]]) — un seul catalogue au lieu de trois champs.

**Ce que l'être fait de ses journées.** Pas ce qu'il sait faire (c'est la classe), pas ce qu'il est (c'est la race).

## Le catalogue

**Production et récolte** — pilotent le rendement hors-site ([[Abstraction hors-site]] : `rendement_job = f(compétence, richesse de la zone)`) :

| Fonction | Ce qu'elle fait |
|---|---|
| **artisan** | **craft, et vend ce qu'il craft.** Ce qu'il produit dépend de sa **classe** — un artisan *Forgeron* fait du métal, un artisan *Mage* des parchemins |
| **commerçant** | **achète et revend.** Ne produit rien : sa marge vient de l'écart entre deux marchés ([[Prix suggéré]], douanes de [[Lois et infractions]]) |
| mineur · bûcheron · herboriste | récolte par catégorie ([[Récolte]]) |
| fermier · éleveur | [[Agriculture et élevage]], [[Élevage — intention et familles]] |
| cuisinier | [[Cuisine et alchimie]] |
| couturier | tissage, [[Composants]] |
| transporteur | déplace des biens entre claims et cellules |

**Ordre et pouvoir**

| Fonction | Ce qu'elle fait |
|---|---|
| **garde** | patrouille, intercepte, applique les lois ([[Lois et infractions]]) |
| **aventurier** | ne réside nulle part — parcourt le monde, entre en donjon, prend des quêtes. **La fonction du joueur par défaut** |
| **dirigeant** | remplace `leadership_role` : roi, maître de guilde, prêtre. Porte la succession ([[Familles et succession]]) et le titre ([[Génération de noms]]) |
| **oisif** | enfant, retraité, captif — présent, sans production |

## Les trois règles

1. **La fonction dit ce qu'on produit ; la classe dit comment.** *Artisan · Forgeron* et *artisan · Couturier* ont la même routine et ne sortent pas les mêmes objets.
2. **La fonction change librement**, par assignation ([[Population et exploitation]]) ou par choix. Ce n'est ni une identité ni un acquis.
3. **Ne pas la confondre avec le `role`** ([[Rôles de l'être]] : sauvage → apprivoisé → résident → garde → bétail), qui dit la place vis-à-vis du joueur. Un forgeron peut être `résident` ou `sauvage` sans changer de fonction.

> ⚠️ **Collision de vocabulaire à surveiller :** *garde* est à la fois une fonction et un `role`. Ce n'est pas une erreur — un PNJ peut avoir le role `garde` (affecté à la défense du territoire) **et** la fonction `garde` (c'est son métier). Les deux champs restent distincts.

## Ce que ça remplace

Les **11 postes de travail figés** de [[Défense et raids]] deviennent ce catalogue, avec deux changements : `vendeur` devient **commerçant**, et `forgeron` devient **artisan** (le métal vient désormais de la classe). Tout le reste — mapping vers une compétence, rendement, assignation — est inchangé.

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Blocs de l'être]]
- **Alimente** : [[Population et exploitation]], [[Abstraction hors-site]], [[Talents de classe]], [[Schéma créature]]
- **Voir aussi** : [[Rôles de l'être]], [[Défense et raids]], [[IA des créatures]], [[Familles et succession]], [[Habitat des PNJ]]
