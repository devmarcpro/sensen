---
aliases: ["14.5", "14.5 Défense", "Défense", "Seuil de royaume", "Postes de travail"]
tags: [société, endgame, décidé]
domaine: société
statut: décidé
etape: 10
---

Défendre son territoire avec des gardes, des tourelles et des murs — et le seuil à partir duquel le monde vous traite en royaume.

- Le joueur défend son territoire avec des **gardes** (PNJ assignés), des **tourelles** et des **murs**.
- **Attaques réelles** : le territoire peut subir des raids (monstres, royaumes hostiles).
  - **Joueur présent sur place** : l'attaque se joue en tactique, sur la grille du monde.
  - **Joueur absent** : l'attaque est **simulée** via le système d'abstraction hors-site ([[Abstraction hors-site]]) — le résultat (dégâts, pertes, victoire des défenses) est calculé et rapporté au joueur.

**Décisions :**
- **Seuil de royaume reconnu : 8+ cellules claim ET 5+ PNJ résidents** — à ce moment, une entrée [[Schéma royaume]] est créée pour le joueur (gouvernance à choisir, [[Gouvernance, lois et diplomatie]]), la diplomatie et les raids de royaumes deviennent possibles. Avant ce seuil : simple "campement" aux yeux du monde (raids de monstres/bandits seulement).
- **Accords diplomatiques : résolu ([[Gouvernance, lois et diplomatie]])** — 4 types selon gouvernance.
- **Déclencheurs et échelle des raids : résolu ([[Raids et menaces]]/[[Dérive de la corruption]])** — jet hebdomadaire, probabilité f(corruption effective, valeur du territoire, réputations négatives — roi capturé compris), force ∝ valeur du territoire, **jamais scalée sur le joueur**.
- **Résolution en absence : résolu ([[Abstraction hors-site]])** — `defense_totale = Σ gardes(niveau_combat × équipement) + tourelles + bonus murs` vs `force_raid`, en un jet ; défaite = pertes proportionnelles, **jamais de wipe**.
- **Postes de travail → [[Fonctions]] :** le catalogue est désormais celui des fonctions (troisième axe de [[Les trois axes — race, classe, fonction]]) ; `vendeur` devient **commerçant**, `forgeron` devient **artisan**. Chaque fonction mappe une compétence (rendement [[Abstraction hors-site]]) — extensible en données.

**Profil d'IA dédié ([[IA des créatures]]) :** `assaillant` — progresser vers le cœur du claim, détruire les obstacles (murs), attaquer les défenseurs.

**Dégâts persistants sur claim ([[Sorts cataclysmiques]]) :** sur les cases claim, les dégâts **persistent** — ce qui rend une attaque de royaume réellement traumatisante.

**Défenses faibles en anarchie ([[Gouvernance, lois et diplomatie]]) :** pas de garde organisée, défenses de zone faibles par défaut ; dictature militaire = défenses renforcées par défaut.

**Malus de dette ([[Entretien et taxes]]) :** 2 semaines impayées → tourelles hors service ; 4+ semaines → les gardes cessent de patrouiller.

**Alliance défensive ([[Gouvernance, lois et diplomatie]]) :** renforts PNJ lors des raids subis.

## Liens
- **Dépend de** : [[Population et exploitation]], [[Expansion territoriale]], [[Abstraction hors-site]], [[Construction cadrée]]
- **Alimente** : [[Raids et menaces]], [[Gouvernance, lois et diplomatie]], [[Schéma royaume]], [[Entretien et taxes]]
- **Voir aussi** : [[IA des créatures]], [[Double niveau combat et général]], [[Dérive de la corruption]], [[Sorts cataclysmiques]], [[Destruction du terrain]], [[LOD de simulation]]
