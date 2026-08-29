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

> [!success] Codé le 2026-08-28 — étape 10.3
> `defense_totale = Σ gardes × (1 + niveau mêlée/5) × (1 + 0,25 × pièces équipées) + 5 × tourelles + murs construits/10 (plafond 10)`, × `defense_mult` de la gouvernance (anarchie 0,5, dictature militaire 1,5). Les gardes sont les résidents assignés à la fonction *garde* ; les tourelles un meuble `tourelle` (**pas encore de recette** — à ajouter avec les modules) ; les murs comptés dans la fenêtre chargée. Dette : 2 semaines → tourelles hors service ; 4 → les gardes ne comptent plus. **Joueur présent** (au camp) : `n = force/2` assaillants (bandits, un chef) apparaissent au **bord de la cellule du camp**, camp `raid`, profil `assaillant` (avancer vers le cœur = l'entrée du camp, creuser un mur qui bloque, attaquer ce qui se présente) ; le raid se résout quand ils sont tous morts ou après 6 000 ticks : victoire si au moins la moitié est tombée, sinon pertes proportionnelles aux survivants ; les survivants restent hostiles sur place. Un raid **réveille le dormeur** (le saut de nuit s'interrompt). **Absent** : un seul jet `force vs défense`.

> [!success] Codé le 2026-08-28 — la tourelle a une recette
> `meuble_tourelle` à l'établi : 4 planches + 2 lingots de métal ; se pose comme un meuble, compte 5 de défense (hors service à 2 semaines de dette). Portée et dégâts en combat réel : voir le callout suivant, du même jour — la tourelle tire.

> [!success] Codé le 2026-08-28 — la tourelle tire
> Pendant un **raid réel**, chaque tourelle du territoire (fenêtre chargée, hors service à 2 semaines de dette) tire toutes les `cadence_ticks` (20) sur l'assaillant le plus proche à portée (6 tuiles, ligne de vue) : `1d6` de dégâts perforants (`combat_rules.royaume.defense.tourelle_tir`), source « tourelle » — le journal le dit. Décision : pas de munitions, pas d'usure ; la tourelle ne tire que sur le camp `raid`. Véhicules : la note demande la sculpture (pixels-marqueurs) — hors de portée d'un incrément, en attente.

## Liens
- **Dépend de** : [[Population et exploitation]], [[Expansion territoriale]], [[Abstraction hors-site]], [[Construction cadrée]]
- **Alimente** : [[Raids et menaces]], [[Gouvernance, lois et diplomatie]], [[Schéma royaume]], [[Entretien et taxes]]
- **Voir aussi** : [[IA des créatures]], [[Double niveau combat et général]], [[Dérive de la corruption]], [[Sorts cataclysmiques]], [[Destruction du terrain]], [[LOD de simulation]]
