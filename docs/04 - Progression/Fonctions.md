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
| **artisan** | **craft, et vend ce qu'il craft.** Ce qu'il produit dépend de sa **classe** — un artisan *La Braise* fait du métal, un artisan *Le Souffle* des parchemins |
| **commerçant** | **achète et revend.** Ne produit rien : sa marge vient de l'écart entre deux marchés ([[Prix suggéré]], douanes de [[Lois et infractions]]) |
| mineur · bûcheron · herboriste | récolte par catégorie ([[Récolte]]) |
| fermier · éleveur | [[Agriculture et élevage]], [[Élevage — intention et familles]] |
| cuisinier | [[Cuisine et alchimie]] — tire *Le Creuset* ou *La Paume* |
| couturier | tissage, [[Composants]] |
| transporteur | déplace des biens entre claims et cellules |

**Ordre et pouvoir**

| Fonction | Ce qu'elle fait |
|---|---|
| **garde** | patrouille, intercepte, applique les lois ([[Lois et infractions]]) — tire *Le Sabre* ou *La Trace* |
| **aventurier** | ne réside nulle part — parcourt le monde, entre en donjon, prend des quêtes. **La fonction du joueur par défaut**, et la seule où toutes les classes sont possibles |
| **dirigeant** | remplace `leadership_role` : roi, maître de guilde, prêtre. Porte la succession ([[Familles et succession]]) et le titre ([[Génération de noms]]). Un prêtre tire *La Paume* |
| **oisif** | enfant, retraité, captif — présent, sans production |

## Le champ `classes_possibles`

La classe d'un PNJ est tirée dans un **pool restreint par sa fonction** ([[Talents de classe]]). Le voici, fixé :

| Fonction | `classes_possibles` |
|---|---|
| aventurier · oisif | **les 8 visibles** (la seule fonction sans restriction) |
| artisan | La Braise · Le Creuset · La Paume · Le Souffle |
| commerçant | La Balance · Le Vent · Le Creuset |
| garde | Le Sabre · La Trace |
| dirigeant | La Balance · Le Sabre · Le Souffle · La Paume |
| mineur · bûcheron | La Braise · La Trace · Le Vent |
| herboriste | Le Creuset · La Paume · La Trace |
| fermier · éleveur | La Trace · Le Vent · La Braise |
| cuisinier | Le Creuset · La Paume |
| couturier | La Braise · Le Vent |
| transporteur | Le Vent · La Balance |

**Les classes cachées ignorent ce pool** : elles sont tirées à ≈ 2 % **avant** lui, sur n'importe quelle fonction. C'est ce qui rend possible le nain commerçant *L'Ombre* ou le mineur *Le Rieur* — et c'est ce qui rend les classes cachées trouvables ([[Exemples — dix PNJ générés]]).

**Pondération des fonctions** dans une population générique : fermier 12 · artisan 14 · garde 12 · aventurier 10 · commerçant 9 · mineur 7 · éleveur 6 · bûcheron 5 · herboriste 5 · cuisinier 5 · couturier 4 · transporteur 4 · oisif 4 · dirigeant 3.

## Les trois règles

1. **La fonction dit ce qu'on produit ; la classe dit comment.** *artisan · La Braise* sort du métal, *artisan · Le Souffle* des parchemins — même routine, autres objets.
2. **La fonction change librement**, par assignation ([[Population et exploitation]]) ou par choix. Ce n'est ni une identité ni un acquis.
3. **Ne pas la confondre avec le `role`** ([[Rôles de l'être]] : sauvage → apprivoisé → résident → garde → bétail), qui dit la place vis-à-vis du joueur. Un forgeron peut être `résident` ou `sauvage` sans changer de fonction.

> ⚠️ **Collision de vocabulaire à surveiller :** *garde* est à la fois une fonction et un `role`. Ce n'est pas une erreur — un PNJ peut avoir le role `garde` (affecté à la défense du territoire) **et** la fonction `garde` (c'est son métier). Les deux champs restent distincts.

## Ce que ça remplace

Les **11 postes de travail figés** de [[Défense et raids]] deviennent ce catalogue, avec deux changements : `vendeur` devient **commerçant**, et `forgeron` devient **artisan** (le métal vient désormais de la classe). Tout le reste — mapping vers une compétence, rendement, assignation — est inchangé.

> [!success] Codé à l'étape 9 (2026-08-28) — trace ajoutée le 2026-09-04
> `data/functions/` (le portefeuille des fonctions) et le champ `fonction` des créatures civiles ; les routines par fonction sont dans les profils d'IA (`_cible_routine`).

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Blocs de l'être]]
- **Alimente** : [[Population et exploitation]], [[Abstraction hors-site]], [[Talents de classe]], [[Schéma créature]]
- **Voir aussi** : [[Rôles de l'être]], [[Défense et raids]], [[IA des créatures]], [[Familles et succession]], [[Habitat des PNJ]]
