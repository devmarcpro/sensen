---
aliases: ["7.6", "7.6 Économie", "Économie", "Puits d'or", "Portefeuille PNJ"]
tags: [société, économie, décidé]
domaine: société
statut: décidé
etape: 10
---

Avec récolte infinie et progression sans plafond, l'inflation est structurellement garantie sans puits explicites : l'or doit pouvoir disparaître du jeu.

**Principe :** avec récolte infinie ([[Récolte]]) et progression sans plafond, l'inflation est structurellement garantie sans **puits** explicites — l'or doit pouvoir disparaître du jeu, pas seulement circuler.

**Règle unifiée — portefeuille de PNJ fini :** tout PNJ (marchand existant, client de la boutique passive [[Boutique passive]], prêtre, maître de guilde...) a un **stock d'or maximal** selon son métier/rang, qui **se recharge lentement** (cadence hebdomadaire, même horloge que la corruption [[Dérive de la corruption]] et la régénération [[Claims et persistance]]). Un marchand à sec **refuse d'acheter en or** au-delà de son stock — il propose un **troc en objets** de valeur équivalente plutôt qu'un refus sec (débouché préservé, formule [[Barèmes économiques]]). Cette règle unique couvre à la fois la vente aux marchands ([[Commerce et boutiques]]) et les ventes de la boutique passive : même mécanique, deux contextes.

**Puits d'or récurrents — entretien du royaume ([[Royaume du joueur]]) :**
- **Taxes de guilde** : prélèvement hebdomadaire automatique (% des gains de quêtes de la semaine, ou montant fixe croissant par rang) — cet or **sort du jeu**, il n'est reversé à aucun PNJ dépensable.
- **Entretien du territoire** : coût hebdomadaire proportionnel à la population de PNJ assignés et au nombre de structures spéciales (stations, tourelles, halls de guilde) — payé automatiquement depuis le trésor du royaume (alimenté par les boutiques passives, [[Boutique passive]]). Non-paiement → malus (détail [[Entretien et taxes]]), pas de spirale automatique.
- **Résurrection de compagnons** (déjà acté, [[Compagnons]]) : coût ∝ niveau, payé à un prêtre — lui-même limité par son propre portefeuille (règle ci-dessus).
- **Mort du joueur** (déjà acté, [[Mort et pénalité]]) : −10 % de l'or transporté, détruit — un puits ponctuel déjà en place.

**Boucle complète :** récolte → vente (limitée par les portefeuilles PNJ) → richesse → entretien du royaume (sort du jeu) + taxes de guilde (sort du jeu) — l'or circule et fuit, il ne s'accumule pas indéfiniment côté monde.

**Puits supplémentaire ([[Potentiel]]) :** les **entraîneurs PNJ** (20 or × niveau actuel → +10 de potentiel dans une compétence choisie) — un puits d'or supplémentaire.

**Décisions :**
- **Barèmes : résolu ([[Barèmes économiques]])** — portefeuilles par métier/rang, taxe 5 % pondérée par rang, entretien 10 or/PNJ + 25 or/structure.
- **Trésor : visible et gérable** — écran de gestion de claim ([[Écrans d'interface]]) : solde, prévisionnel hebdomadaire (revenus boutiques vs entretien), dépôts/retraits libres du joueur (constituer une réserve est permis et encouragé, cf. [[Entretien et taxes]]).

> [!success] Codé le 2026-08-28 — étape 10.2
> Puits en place : entretien du territoire, taxe de guilde `0,05 × gains de quêtes × (1 + 0,1 × (rang − 1))`, résurrection, mort. **Troc automatique** : un marchand à sec propose en échange un objet de son stock dont le prix est à ±15 % de la valeur de vente ; l'échange est fait d'office avec une ligne de journal (pas d'écran d'acceptation — à juger). Entraîneurs PNJ non codés.

## Liens
- **Dépend de** : [[Récolte]], [[Commerce et boutiques]], [[Prix suggéré]]
- **Alimente** : [[Barèmes économiques]], [[Entretien et taxes]], [[Boutique passive]], [[Quêtes et guildes]]
- **Voir aussi** : [[Compagnons]], [[Mort et pénalité]], [[Potentiel]], [[Dérive de la corruption]], [[Écrans d'interface]], [[Royaume du joueur]]
