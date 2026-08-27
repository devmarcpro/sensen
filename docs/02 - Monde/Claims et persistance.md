---
aliases: ["3.3", "3.3 Persistance et claims", "Claims", "Persistance"]
tags: [monde, territoire, décidé]
domaine: monde
statut: décidé
etape: 7
---

Ce qui persiste et ce qui se régénère dans le monde : la règle qui fait qu'on peut défigurer la nature mais pas sa base.

- **Cases "claim"** (revendiquées par le joueur) : constructions persistantes indéfiniment.
- **Cases sauvages** (non revendiquées) : régénérées après 1 semaine de temps in-game.
- **Villages et villes** (PNJ) : permanents, non affectés par la régénération.

**Cellules donjon exclues du zonage :** tant qu'un donjon occupe une cellule ([[Donjons — structure et intégration]]), celle-ci n'est ni claimable ni zonable — elle le redevient après le délai de disparition post-nettoyage ([[Donjons — structure et intégration]]/[[Génération de donjon]]).

**Rôles des cases claim :** voir [[Rôles de cases]].

**Cadence hebdomadaire :** la régénération partage la même horloge in-game que la [[Dérive de la corruption]], le repeuplement des villages ([[Villages PNJ — repeuplement et décimation]]) et les prélèvements économiques ([[Économie — sources et puits]]).

> [!success] Décidé et codé le 2026-08-28 — le camp de base de l'étape 7 (`systems/worldgen/camp.gd`, `Simulation.charger_camp`)
> Le camp est **la cellule de départ du monde**, générée par la surface (8.1, `systems/worldgen/surface.gd` : biome, sol, arbres, rochers, filons, accidents de relief) et complétée par `data/camp.json`, **revendiquée d'office et gratuitement** — la note ne chiffre aucun coût de claim ; le premier claim est celui du camp, les suivants attendent [[Expansion territoriale]]. Tout ce qui y est posé **persiste** : la cellule est mise de côté telle quelle (grille, meubles, coffres, êtres) quand on part en expédition et revient dans cet état (`camp_sauve`), comme un étage de donjon. Elle porte l'**entrée du donjon** (une tuile `entree_donjon` : E dessus lance une expédition ; la sortie de l'étage 1 **ramène au camp** au lieu d'enchaîner une expédition), des **arbres** et des **rochers de surface** à récolter (hache, pioche), un **coffre de départ** (hache, pioche, lit de paille). La cellule du camp est **entièrement découverte** (pas de brouillard sur son propre claim ; les êtres restent soumis à la vue). Signal `cell_claimed` non émis (une seule cellule, pas encore de carte). Rôle de la cellule : `base` (les rôles de [[Rôles de cases]] attendent une deuxième cellule).

## Liens
- **Dépend de** : [[Grille continue]], [[Simulation à ticks]]
- **Alimente** : [[Rôles de cases]], [[Royaume du joueur]], [[Destruction du terrain]], [[Récolte]]
- **Voir aussi** : [[Dérive de la corruption]], [[Donjons — structure et intégration]], [[Simulation du monde — performance]], [[Sauvegarde]]
