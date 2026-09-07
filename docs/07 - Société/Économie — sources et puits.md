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

> [!success] Mis à jour le 2026-08-30 — les entraîneurs PNJ sont codés (le « non codés » ci-dessus est périmé)
> Le puits existe depuis le 2026-08-28 ([[Potentiel]], callout « l'entraîneur ») : PNJ tagués `entraineur` (maîtres de guilde, gardes de village), *Entraîner* au dialogue, `coût = 20 or × niveau actuel`, +10 de potentiel plafonné ; l'or va à la bourse finie du PNJ. Testé (`test_entraineur_et_commandes`). Balayage du coffre : la phrase du callout précédent était restée en retard d'une note.

> [!important] Décidé le 2026-09-07, 21 h 15 — les denrées pourrissent, et le prix se remet à bouger (designer : « ok go je te laisse faire »)
> J'avais dit au designer que « le prix ne suit pas la récolte ». **C'était faux et je le corrige** : `_semaine_economie` calcule bien le prix de chaque catégorie sur le rapport du stock au besoin, et un marchand l'applique (`facteur_economie`). Le défaut est ailleurs, et il est plus vicieux : la **nourriture ne se consomme qu'à raison d'un repas par résident et par semaine**, et rien ne l'use au-delà — douze mille sept cent quarante-quatre baies mesurées après un an de jeu. Le rapport sature à 1, et le prix de la nourriture reste **collé au plancher** dans toute ville qui récolte. Le mécanisme existait ; c'est le stock infini qui l'avait figé.
> **La règle** : chaque semaine, une part des denrées du stock se perd (`villes.economie.peremption`). Elle dépend de ce qu'est la denrée, pas d'une horloge par objet — on reste dans l'abstraction hors-site :
> - `taux_defaut` (30 %) pour un aliment cru — la baie, le lait, la viande crue ;
> - `taux_par_tag` : un **plat** tient mieux (15 %), une **conserve** presque indéfiniment (3 %), une **céréale** et une **racine** se gardent au grenier (8 %) ;
> - la perte est plafonnée par `garde_minimale` : une ville ne perd jamais tout, il reste toujours de quoi manger la semaine suivante.
> **Ce que ça débloque, et c'est le fil qui traverse tout ce qui précède** : la salaison et le fumage servent enfin à quelque chose (c'est *pour ça* qu'on les fait) ; une ville-grenier qui produit trop voit son prix descendre puis remonter quand la récolte pourrit, au lieu de rester au plancher ; une ville de montagne qui ne récolte rien paie sa nourriture au prix fort ; et la question de l'accumulation sans fin, posée au designer dans [[À juger — parcours de jeu]] depuis le 2026-09-06, reçoit une réponse.
> **Ce que ça ne fait pas** : le sac du joueur ne pourrit pas (seul le butin tombé à la mort périme, et c'est une autre règle) — un aliment porté se garde. Le faire pourrir dans le sac est une décision de confort qui demande une horloge par objet, et je la laisse au designer.

## Liens
- **Dépend de** : [[Récolte]], [[Commerce et boutiques]], [[Prix suggéré]]
- **Alimente** : [[Barèmes économiques]], [[Entretien et taxes]], [[Boutique passive]], [[Quêtes et guildes]]
- **Voir aussi** : [[Compagnons]], [[Mort et pénalité]], [[Potentiel]], [[Dérive de la corruption]], [[Écrans d'interface]], [[Royaume du joueur]]
