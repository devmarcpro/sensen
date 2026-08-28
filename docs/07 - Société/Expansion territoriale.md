---
aliases: ["14.1", "14.1 Expansion territoriale", "Expansion territoriale", "Expansion"]
tags: [société, endgame, décidé]
domaine: société
statut: décidé
etape: 10
---

Deux voies d'expansion : coloniser le vide, ou annexer le peuplé.

- Le joueur **claim de plus en plus de cases** autour de sa base (extension du système de claims, [[Claims et persistance]]), OU **conquiert des villages PNJ existants** sans les détruire (voir [[Conquête de village]]) — deux voies d'expansion, colonisation du vide et annexion du peuplé.
- Chaque case revendiquée reçoit un **rôle configurable à tout moment** (zonage — voir [[Rôles de cases]]) : base, habitation, champs, ressources naturelles — l'aménagement du territoire est une couche de gestion à part entière.
- Il y **construit des bâtiments** (construction libre + modèles de structures sculptés, [[Construction cadrée]] et [[Tables de sculpture]]).

**Seuil de royaume reconnu ([[Défense et raids]]) :** 8+ cellules claim ET 5+ PNJ résidents.

**Territoire des royaumes PNJ ([[Schéma royaume]]) :** `territory_cells` est dérivé dynamiquement des claims/conquêtes, pas saisi à la main.

> [!success] Décidé et codé le 2026-08-28 — étape 10.1, revendiquer une cellule (`Monde.claims`, `Simulation.revendiquer`)
> **Geste** : depuis la carte du monde (Tab → Carte du monde ; anciennement M), clic sur une cellule **contiguë** au territoire, **explorée**, de terre, **sans donjon actif ni village PNJ** — la note ne chiffrait ni coût ni geste. **Coût (décision)** : `50 or × nombre de cellules déjà possédées` (le camp est gratuit) — un puits d'or qui croît avec le territoire ; la somme est nulle : la cellule cesse d'être sauvage. Le territoire ne franchit pas l'eau (contiguïté sur la terre). Signal `cell_claimed` émis. `territory_cells` est dérivé de `Monde.claims`.

## Liens
- **Dépend de** : [[Claims et persistance]], [[Rôles de cases]], [[Conquête de village]], [[Construction cadrée]]
- **Alimente** : [[Population et exploitation]], [[Gouvernance, lois et diplomatie]], [[Défense et raids]], [[Entretien et taxes]]
- **Voir aussi** : [[Royaume du joueur]], [[Tables de sculpture]], [[Schéma royaume]]
