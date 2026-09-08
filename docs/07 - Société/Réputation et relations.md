---
aliases: ["7.2", "7.2 Réputation et relations PNJ", "Réputation", "Relations"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 9
---

Quatre niveaux de réputation en parallèle, et une échelle de conséquences par palier.

- **Pas de mariage prévu pour l'instant** (peut-être reconsidéré plus tard).
- **Système à quatre niveaux, en parallèle :**
  - **Réputation globale** : perception générale du joueur, toutes factions confondues.
  - **Réputation par royaume** : chaque royaume/faction a sa propre opinion du joueur.
  - **Relation par PNJ individuel** : chaque PNJ a sa propre relation avec le joueur.
  - **Réputation par race** : chaque race a sa propre perception du joueur.
- **Facteurs d'évolution (mélange de tous) :** actions positives/négatives envers les PNJ (aide, cadeaux, méfaits), quêtes accomplies, combat/protection (défendre un PNJ ou un village).

**Décisions :**
- **Interactions entre niveaux : oui, légères** — les rivalités entre races/royaumes sont déclarées en données (`rivals` dans races/[[Schéma royaume]]) : un gain de réputation envers X applique **−25 % de ce gain** envers ses rivaux déclarés. Pas de cascade au-delà d'un degré.
- **Conséquences par palier (échelle −100..+100) :** ≤ −50 : hostile à vue (gardes/civils fuient ou attaquent) · −49..−20 : prix +25 %, quêtes refusées · −19..+19 : neutre · +20..+49 : prix −10 % · ≥ +50 : quêtes spéciales, confidences/rumeurs ([[Dialogue PNJ]]), facilités de recrutement.
- **Recrutement : la relation individuelle est le critère** ([[Schéma créature]]) ; les réputations race/royaume agissent en **modificateur de vitesse** du gain de relation (×0.5 à ×1.5 selon le palier), jamais en seuil direct. Les **compatibilités astrologiques** ([[Astrologie — cycle sexagésimal]]) s'y ajoutent comme second modificateur de vitesse.

**L'information est la récompense principale de la relation :** voir [[L'information comme récompense]].

**Voie de rédemption :** voir [[Voie de rédemption]].

**Ce que la réputation n'est pas ([[Quêtes et guildes]]) :** la réputation de guilde n'existe pas — c'est un système **rang + XP de guilde**, une progression, pas une opinion.

**Impacts majeurs :** conquête de village ([[Conquête de village]] — libération vs agression), capture d'un roi ([[Population et exploitation]]), infractions ([[Lois et infractions]]), rétrogradation d'un PNJ en bétail ([[Habitat des PNJ]] : relation −30).

**Modulation des prix :** [[Prix suggéré]] (`facteur_reputation`).

> [!success] Codé le 2026-08-28 — étape 9.C, `combat_rules.reputation`
> Les paliers de l'échelle −100..+100 tels quels : **≤ −50 hostile à vue** (`Simulation.ennemis` : un civil dont la relation avec le joueur est ≤ −50 le traite en ennemi), −49..−20 prix +25 % et **quêtes refusées**, +20..+49 prix −10 %, **≥ +50 confidences** (rumeurs qui révèlent un POI, [[L'information comme récompense]]). Trois niveaux codés : **relation par PNJ**, **réputation par village** (le royaume attend l'étape 10 : le village en tient lieu), **réputation globale** ; la race est lue mais sans rivalités encore. **Gains chiffrés (décision, la note ne l'était pas)** : frapper un civil −30 (lui) / −10 (son village) / −3 (globale) ; le tuer −50 / −20 / −5 ; quête accomplie +10 / +5 / +1 ; parler +1/jour. La relation d'un PNJ **module la vitesse** des gains (×0,5 sous −20, ×1,5 au-dessus de +50 — la note le prévoit pour race/royaume, appliqué au village).


> [!important] Noté le 2026-09-08 — la réputation par **factions**, une faction par espèce (designer : « réputation par factions, une faction par espèce, il y a aussi la réputation par ville, par royaume, etc. »)
> **Ce qui existe** : la réputation est déjà à **trois étages** — par PNJ, par **village**, par **royaume**, plus une réputation globale, avec une vitesse par palier, l'hostilité à vue sous un seuil, des paliers d'information, et une dérive de rédemption hebdomadaire vers zéro.
> **Ce qui manque** : l'étage des **factions**, et l'idée que **chaque espèce en est une**. Aujourd'hui un loup abattu n'engage rien : il n'y a pas de « les loups » à qui ça pourrait déplaire. Avec une faction par espèce, chasser les cerfs jusqu'au dernier fâche quelque chose, et une meute peut se souvenir.
> **Ce que ça donne, et pourquoi c'est plus qu'un compteur de plus** : c'est le **lecteur naturel** de deux choses déjà décidées — la **rumeur** qui circule (elle transporte le fait, la faction décide qui s'en offusque) et les **tags idéologiques** validés le même jour sur un avis extérieur (une faction porte des **valeurs**, une action porte des **tags**, la réputation s'ajuste seule). Les trois ne font qu'un seul système, et il vaut mieux les écrire ensemble.
> **Ce qu'il faudra trancher** : une faction par espèce **et** des factions qui n'en sont pas (une guilde, un culte, une bande de brigands) — le même objet, ou deux ? Et une espèce est-elle une faction **par elle-même**, ou une faction qui se trouve n'avoir qu'une espèce ?
> **Où ça se range** : avec la rumeur et les tags, au palier 7 de l'[[Ordre de travail]] — ce sont les mêmes lignes.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Schéma créature]], [[Races]]
- **Alimente** : [[L'information comme récompense]], [[Voie de rédemption]], [[Apprivoisement et recrutement]], [[Prix suggéré]], [[Boutique passive]]
- **Voir aussi** : [[Astrologie — cycle sexagésimal]], [[Dialogue PNJ]], [[Conquête de village]], [[Lois et infractions]], [[Schéma royaume]], [[Quêtes et guildes]], [[Habitat des PNJ]]
