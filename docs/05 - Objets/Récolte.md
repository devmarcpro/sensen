---
aliases: ["A.2", "Annexe A.2", "Récolte", "4.2 récolte", "Filons de surface"]
tags: [objets, matériaux, formule, décidé]
domaine: objets
statut: décidé
etape: 6
---

Chercher des ressources, c'est explorer, pas creuser : des filons de surface, un outil adapté, et une règle d'irrécoltabilité qui sert de verrou de progression.

**Récolte des ressources (façon Elin, pas de minage exploratoire)** : les minerais, pierres et argiles apparaissent en **filons de surface** — des nœuds visibles sur la grille, récoltables à l'outil approprié, qui se régénèrent avec les cases sauvages ([[Claims et persistance]]). Le bois s'abat, les plantes se cueillent, les créatures se dépècent. Chercher des ressources, c'est **explorer**, pas creuser.

**Trois facteurs :**
- Chaque catégorie de matériau est associée à un outil dédié (hache → bois, pioche → minerai/roche, etc. — [[Catégories de matériaux]]).
- La **vitesse** et la **quantité** récoltées dépendent de trois facteurs combinés :
  1. Le niveau du joueur dans la compétence de récolte associée au matériau visé (ex : Minage pour minerai/roche).
  2. La dureté du matériau récolté.
  3. La dureté des matériaux composant l'outil utilisé.
- **Important :** les matériaux bruts n'ont pas de "qualité" — seulement leurs stats fixes. La récolte n'améliore jamais la qualité d'un matériau, seulement la vitesse/quantité obtenue.

**Formules (A.2) :**

```
temps_recolte (secondes) =
  durete_materiau / (durete_outil * qualite_outil * skill_factor(N_recolte))

quantite_recoltee = 1 + floor(N_recolte / 10)    (chance de +1 par palier de 10 niveaux)
XP gagnée par bloc récolté = durete_materiau
```

- Un matériau est **irrécoltable** si `durete_outil * qualite_outil < durete_materiau * 0.5` (outil trop faible : aucun progrès, feedback visuel "l'outil rebondit").
- Récolte à mains nues : dureté d'outil implicite = 1, qualité = 1.

**Verrou de progression ([[Stratification verticale]]) :** combinée à la stratification par dureté, la règle d'irrécoltabilité fait que creuser profond exige de meilleurs outils, de meilleurs matériaux (trouvés en profondeur) ou des PNJ mineurs de haut niveau.

**Rôle de case dédié ([[Rôles de cases]]) :** « Ressources naturelles » — la case garde la régénération hebdomadaire malgré le claim, réserve d'exploitation renouvelable.

> [!success] Codé le 2026-08-28 — la récolte en donjon (filons muraux), `combat_rules.recolte`
> Les formules de la note telles quelles, en ticks : `ticks = ⌈durete_materiau / (durete_outil × qualite_outil × skill_factor(N)) × 10⌉` (10 ticks par seconde d'exploration), `quantite = 1 + ⌊N/10⌋`, XP = dureté du matériau versée à la compétence de la catégorie (Minage pour un filon). **Décisions** : `skill_factor(N)` = celui de [[Progression par l'usage]] (1 + 0,02 N) ; **l'outil** = l'objet en main principale dont la fonctionnalité est l'outil de la catégorie (`pioche` pour métaux, roches, minéraux, gemmes, fossiles), dureté = sa `durete_base`, qualité = sa `qualite` ; sans outil adapté, on peut toujours **creuser** un mur (décision du 2026-08-27, 10 ticks) mais le matériau s'effrite — rien n'est récolté ; avec un outil trop faible (`durete × qualite < durete_materiau × 0,5`), « l'outil rebondit » et rien ne se passe. Le matériau récolté est un objet `materiau_brut` empilable dans le sac (un par matériau, `quantite`). Première pioche : `proto_pioche` (tête de fer, dureté 25) dans le loot des coffres de donjon — la voie pierre/os de l'Établi arrive avec les stations.

> [!success] Précisé le 2026-08-28 — les plantes sauvages
> Contenu de tuile `plante` (franchissable, destructible, tag `vegetation`) portant un matériau végétal (lin, chanvre, coton, paille) : se récolte à la **faucille** (`proto_faucille`, dans le coffre de départ et le loot) par un clic adjacent, selon la même formule (Herboristerie). Les biomes déclarent leurs `plantes` comme leur `vegetation`.

> [!success] Corrigé le 2026-08-29 — trois outils de récolte que rien ne portait
> Même contrôle que pour les stats fantômes, appliqué aux `harvest.tool_category` des matériaux : **dix-sept matériaux** exigeaient un outil qu'**aucune fonctionnalité** ne fournissait — `pelle` (glace, neige, argile, gravier, sable, terre, terre fertile, tourbe), `seau` (eau, eau salée, boue, sève, huile, goudron, lave) et `dague` (os, os massif). Creuser ces tuiles marchait, mais ne **récoltait rien** : ni matériau, ni XP, jamais. Deux fonctionnalités de plus (`pelle`, `seau`), leurs objets (`proto_pelle`, `proto_seau`, `craft_pelle` assemblé comme la pioche) et une recette de menuiserie pour le seau ; la **dague** reçoit `outil: "dague"` — on récolte les os à la lame, pas au pic. Le **talus** accepte désormais la pelle autant que la pioche, comme le disait déjà [[Destruction du terrain]] (`outil_elever` devient `outils_elever`, une liste). `tools/audit_donnees.py` vérifie que toute catégorie d'outil citée par un matériau est portée par au moins une fonctionnalité.

> [!success] Décidé et codé le 2026-08-30 — « aucun chiffre fixe » : la récolte est un jet porté par la compétence
> Philosophie posée par le designer pour les charges de modules, étendue à tout ce que le joueur **gagne** : plus de « 1 unité, +1 par 20 niveaux ». Une tuile récoltée donne **`recolte.des` (1d2) × skill_factor(compétence de récolte)** ; une plante sauvage cueillie **`cueillette.des` (1d2) × skill_factor(Collecte)** ; une parcelle mûre garde sa formule (base × rendement du biome × fertilité) mais la multiplie par **un jet 2d6/7** (moyenne 1, jamais deux récoltes identiques) et par skill_factor(Agriculture). Les quêtes suivent : `gold_per_target_level` et `guild_xp` des gabarits sont des **notations de dés** (`2d10+5`, `2d6+3`), jetées à la génération — deux gardes n'offrent pas la même prime. **Décision** : l'aléa est **toujours multiplié par la compétence**, jamais additionné — un maître ne tire pas de meilleurs dés, il tire plus de chaque dé ; et le plancher est toujours 1, une récolte ne rend jamais rien.

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]], [[Progression par l'usage]], [[Qualité d'artisanat]]
- **Alimente** : [[Stratification verticale]], [[Rôles de cases]], [[Population et exploitation]]
- **Voir aussi** : [[Claims et persistance]], [[Minerais par profondeur]], [[Fabrication d'outils]], [[Compétences — liste]], [[Décisions fondatrices]]
