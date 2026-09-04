---
aliases: ["Gestion de base", "Périmètres de récolte", "Base façon Dwarf Fortress"]
tags: [société, territoire, décidé]
domaine: société
statut: décidé
etape: 10
---

L'idée du designer du 2026-09-04, ce que le coffre en avait déjà, ce qui manque, et l'ordre dans lequel on le construit.

> [!quote] Le designer, 2026-09-04, 8 h 40
> « J'ai eu une idée, peut-être que c'est déjà présent dans la documentation : **gestion de base en mode Dwarf Fortress**. Le joueur définit des **périmètres par type de récolte**, le joueur **assigne des PNJ de sa base** sur les périmètres de récolte, **efficacité de la récolte selon les stats du PNJ et les stats des tuiles** du périmètre. Donc avant de mettre tout ça en place il va falloir **avancer sur tout le système de recrutement des PNJ / gestion de base / gestion des compagnons**, etc. »

> [!quote] Le designer, 2026-09-04, 10 h 25 — après la v1
> « Les **périmètres sont dessinés par le joueur**, pareil pour le **résidentiel**, et les **maisons seront construites automatiquement** si des PNJ sont assignés, qu'il y a les matériaux nécessaires, et tout cela selon les paramètres décidés. »
> Ce que ça change : la v1 « un périmètre = la cellule entière filtrée par type » n'est qu'un repli — le périmètre devient **un ensemble de tuiles que le joueur dessine** (étape 4 bis) ; il existe un **périmètre résidentiel**, dessiné de même (étape 5) ; et un résident assigné au résidentiel **se fait bâtir une maison** dedans, automatiquement, quand le stock du territoire a les matériaux, aux dimensions et au prix que les données décident (étape 5). Tout est en données ; les paramètres sont au designer.

> [!quote] Le designer, 2026-09-04, 10 h 35
> « Du coup, pour chaque poste, il faut assigner un **stockage**. »
> Ce que je lis : un poste de récolte (un périmètre de production, ou une fonction) doit désigner **où va ce qu'il produit** — un périmètre de type *stockage*, dessiné comme les autres, avec une capacité qui dépend de ses tuiles ; sans stockage assigné, le poste ne produit pas (rien ne tombe dans un stock abstrait). C'est l'étape 6, après le dessin et les maisons.

## Ce que le coffre en avait déjà

- **La vision, oui.** [[Boucle de jeu]] : *claim → recrutement / assignation de PNJ → exploitation automatisée*. [[Population et exploitation]] dit « assigner les PNJ à des tâches précises (poste de travail, **zone à exploiter**) » et [[Rôles de cases]] promet, pour le rôle *Ressources naturelles*, une réserve « récoltable en boucle, notamment par les PNJ assignés ». Le mot *zone* est là depuis le début ; il n'a jamais été spécifié.
- **Ce qui est codé** (étapes 9.D et 10.1, 2026-08-28) : le recrutement **par la relation** (`_recruter`, sept fiches recrutables, seuil 60-70, places d'escorte), l'apprivoisement des bêtes (V), l'assignation d'un compagnon ou d'un PNJ d'un village conquis à une **fonction** par le dialogue (`_assigner` : poste = la tuile où il est, logement = un lit libre, humeur), la **production hebdomadaire par formules** (`production_de` : rendement de base × niveau de la compétence × humeur × productivité du territoire), l'entretien, la dette, l'écran Gestion (Tab → Territoire).
- **Ce qui manque, et que l'idée demande :**
  1. **Un vrai recrutement pour la base.** Aujourd'hui on ne recrute qu'un *compagnon* (qui suit, et prend une place d'escorte), qu'on assigne ensuite s'il se trouve sur une cellule revendiquée. Rien ne permet d'**engager quelqu'un pour qu'il aille s'installer à la base**, et personne n'y vient de lui-même.
  2. **Des périmètres.** La production ne regarde pas les tuiles : un bûcheron produit du bois qu'il y ait ou non un arbre. Le périmètre — un ensemble de tuiles d'une cellule revendiquée, typé par ce qu'on y récolte — n'existe pas.
  3. **L'efficacité par les tuiles.** Les stats du PNJ comptent (compétence, humeur) ; les stats des tuiles (ce qui pousse, ce qui affleure, la fertilité) ne comptent que pour les parcelles agricoles.
  4. **La gestion des compagnons** est riche (postures, ordres, échange, résurrection, suiveur territorial) ; ce qui lui manque est une **vue de base** où l'on voit tout son monde et où l'on décide.

## L'ordre, celui du designer

1. **Recrutement** — *engager* un PNJ pour la base (il part s'y installer, sans prendre de place d'escorte), et des **migrants** qui viennent d'eux-mêmes quand la base a de la place et une réputation. → codé le jour même, voir [[Population et exploitation]].
2. **Gestion de base** — l'écran Gestion devient un vrai tableau des résidents : fonction, poste, logement, humeur, et les actions *réassigner* / *renvoyer* sans aller parler à chacun. → codé le jour même : chaque résident dit s'il est logé et où est son poste ; **Entrée** ouvre le choix de fonction, **Suppr** le renvoie (un engagé ou un migrant redevient villageois, un ancien compagnon redevient compagnon).
3. **Compagnons** — la même vue pour l'escorte : qui suit, qui attend à la base, et le passage de l'un à l'autre. → codé le jour même : les compagnons sont listés sous les résidents avec leur ordre, **Entrée** bascule *suis-moi* / *attends ici*.
4. **Périmètres de récolte** — le cœur de l'idée. → **codé le jour même, en v1** : un périmètre est **une cellule revendiquée entière, filtrée par un type de récolte** (bois = les arbres, minerai = les filons, plantes = les plantes sauvages) — pas encore une zone dessinée à la main ; c'est le choix conservateur, l'outil de dessin (rectangle, pinceau) est la suite et reste au designer. Le périmètre se **scanne** quand sa cellule est dans la fenêtre : combien de tuiles portent la ressource, et quelle matière domine (le pin, le cuivre…) ; ça donne sa **richesse** et sa **réserve** (`unites_par_tuile` par tuile). Un résident assigné dessus (l'écran Assigner le propose, avec la fonction du type) produit chaque semaine `par_tuile_semaine` × min(richesse, `tuiles_max_par_resident`) × compétence × humeur unités de la matière dominante, prises sur la réserve ; sur une cellule *Ressources naturelles*, la réserve repousse de `repousse_hebdo` par semaine. Touche **P** sur une cellule de l'écran Gestion : bois → minerai → plantes → aucun. Et le résident **travaille dedans** : son poste devient une tuile au bord de la ressource (`_poste_de_perimetre`), la routine du niveau 1 l'y mène le jour, la projection du LOD 2 l'y remet au retour. Tout dans `combat_rules.royaume.perimetres`, tests dans `test_perimetres`. Le cœur de l'idée : un périmètre = des tuiles d'une cellule revendiquée + un type de récolte (bois, pierre, minerai, plantes, pêche, champ) ; on y assigne des résidents ; la production hebdomadaire se calcule **depuis ce qu'il y a sur les tuiles** (arbres, filons, plantes, fertilité) × la compétence et l'humeur du PNJ ; et, quand le joueur est là, le résident **travaille dedans** (son poste est une tuile du périmètre, la routine l'y mène).

5. **Le résidentiel et les maisons automatiques** (designer, 10 h 25) — → **codé le jour même** : le type *résidentiel* se dessine comme les autres ; au passage de semaine, chaque résident assigné dessus sans lit valide se fait bâtir une **chaumière** (`royaume.maisons.plan`, le préfab des villages) sur ses tuiles libres, si `territoire.stocks` a `royaume.maisons.cout` (12 de bois, n'importe quelle forme — la scierie est un autre chantier), murs et porte construits, lit posé, le résident y dort (`_batir_maisons`). Seulement quand la cellule est dans la fenêtre : hors fenêtre, la construction attend le retour. — un périmètre de type *résidentiel*, dessiné comme les autres ; un résident qui y est assigné et n'a pas de lit **se fait bâtir une maison** dedans, automatiquement, quand `territoire.stocks` a les matériaux (`royaume.maisons` : l'empreinte, les murs, la porte, le lit, le coût en matières, le délai), en suivant les règles de [[Détection de pièces]] et de [[Habitat des PNJ]] : la maison est une pièce valide, le résident y a son lit, son humeur suit.

**4 bis. Les périmètres dessinés** (designer, 10 h 25) — → **codé le jour même** : **P** dans le monde ouvre le choix du type (bois, minerai, plantes, résidentiel), puis deux clics dessinent un rectangle (Échap annule) ; un périmètre porte ses `tuiles` (coordonnées locales de la cellule), plusieurs par cellule, dessinés sur la carte en teinte de leur type ; la richesse et le poste ne comptent que ses tuiles. — un périmètre est un ensemble de tuiles (`tuiles`, en coordonnées locales de la cellule) que le joueur dessine sur la carte du camp : un mode *périmètre* (touche P dans le monde), deux coins pour un rectangle, le type choisi au menu ; plusieurs périmètres par cellule ; la richesse se compte sur ses tuiles seulement. La v1 « cellule entière » reste le comportement d'un périmètre sans `tuiles`.

6. **Un stockage par poste** (designer, 10 h 35) — un périmètre de type *stockage* (dessiné) a une capacité (`royaume.stockage.unites_par_tuile` × ses tuiles) ; chaque périmètre de production **désigne son stockage** (touche S sur le périmètre dans l'écran Gestion, à tour de rôle parmi les stockages) ; la production hebdomadaire va dans ce stockage — jusqu'à sa capacité, le reste est perdu et le journal le dit — et le stock du territoire (`territoire.stocks`) reste la somme de tous les stockages, ce que les maisons et les chantiers consomment. Sans stockage désigné, un poste ne produit pas.

## Ce qui est au designer

Les chiffres (prix d'un engagement, rythme des migrants, rendement par tuile), la forme de l'outil de dessin des périmètres (rectangle, pinceau, par tuile), et si un résident sans logement finit par partir. Tout est en données ; tout se règle sans code.

## Liens
- **Dépend de** : [[Population et exploitation]], [[Rôles de cases]], [[Apprivoisement et recrutement]], [[Compagnons]], [[Habitat des PNJ]]
- **Alimente** : [[Royaume du joueur]], [[Abstraction hors-site]], [[Écrans d'interface]]
- **Voir aussi** : [[Expansion territoriale]], [[Agriculture et élevage]], [[LOD de simulation]]
