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
4. **Périmètres de récolte** — le cœur de l'idée. → **codé le jour même, en v1** : un périmètre est **une cellule revendiquée entière, filtrée par un type de récolte** (bois = les arbres, minerai = les filons, plantes = les plantes sauvages) — pas encore une zone dessinée à la main ; c'est le choix conservateur, l'outil de dessin (rectangle, pinceau) est la suite et reste au designer. Le périmètre se **scanne** quand sa cellule est dans la fenêtre : combien de tuiles portent la ressource, et quelle matière domine (le pin, le cuivre…) ; ça donne sa **richesse** et sa **réserve** (`unites_par_tuile` par tuile). Un résident assigné dessus (l'écran Assigner le propose, avec la fonction du type) produit chaque semaine `par_tuile_semaine` × min(richesse, `tuiles_max_par_resident`) × compétence × humeur unités de la matière dominante, prises sur la réserve ; sur une cellule *Ressources naturelles*, la réserve repousse de `repousse_hebdo` par semaine. Touche **P** sur une cellule de l'écran Gestion : bois → minerai → plantes → aucun. Tout dans `combat_rules.royaume.perimetres`, tests dans `test_perimetres`. Le cœur de l'idée : un périmètre = des tuiles d'une cellule revendiquée + un type de récolte (bois, pierre, minerai, plantes, pêche, champ) ; on y assigne des résidents ; la production hebdomadaire se calcule **depuis ce qu'il y a sur les tuiles** (arbres, filons, plantes, fertilité) × la compétence et l'humeur du PNJ ; et, quand le joueur est là, le résident **travaille dedans** (son poste est une tuile du périmètre, la routine l'y mène).

## Ce qui est au designer

Les chiffres (prix d'un engagement, rythme des migrants, rendement par tuile), la forme de l'outil de dessin des périmètres (rectangle, pinceau, par tuile), et si un résident sans logement finit par partir. Tout est en données ; tout se règle sans code.

## Liens
- **Dépend de** : [[Population et exploitation]], [[Rôles de cases]], [[Apprivoisement et recrutement]], [[Compagnons]], [[Habitat des PNJ]]
- **Alimente** : [[Royaume du joueur]], [[Abstraction hors-site]], [[Écrans d'interface]]
- **Voir aussi** : [[Expansion territoriale]], [[Agriculture et élevage]], [[LOD de simulation]]
