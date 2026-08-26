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

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Schéma créature]], [[Races]]
- **Alimente** : [[L'information comme récompense]], [[Voie de rédemption]], [[Apprivoisement et recrutement]], [[Prix suggéré]], [[Boutique passive]]
- **Voir aussi** : [[Astrologie — cycle sexagésimal]], [[Dialogue PNJ]], [[Conquête de village]], [[Lois et infractions]], [[Schéma royaume]], [[Quêtes et guildes]], [[Habitat des PNJ]]
