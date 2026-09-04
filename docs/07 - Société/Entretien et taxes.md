---
aliases: ["14.6", "14.6 Entretien et taxes", "Entretien", "Dette", "Trésor du royaume"]
tags: [société, économie, endgame, décidé]
domaine: société
statut: décidé
etape: 10
---

Les puits d'or qui contrebalancent la richesse territoriale — avec des malus progressifs, jamais de spirale de destruction.

- Le royaume coûte un **entretien hebdomadaire** (population assignée + structures spéciales) et des **taxes de guilde**, prélevés automatiquement sur le trésor du royaume (alimenté par les boutiques passives, [[Boutique passive]]) — ce sont les puits d'or qui contrebalancent la richesse générée par l'exploitation territoriale ([[Population et exploitation]]).
- **Non-paiement (trésor insuffisant)** : malus progressifs, jamais de spirale de destruction automatique — humeur des PNJ en baisse, gardes moins efficaces, tourelles hors service jusqu'à régularisation. Un rapport hebdomadaire (même mécanisme que le journal [[Abstraction hors-site]]) informe le joueur avant que ça devienne critique.

**Décisions :**
- **Paliers de dette :** 1 semaine impayée : humeur générale **−5** · 2 semaines : productivité **−25 %**, tourelles hors service · 4+ semaines : les gardes cessent de patrouiller, **1 PNJ peut quitter le territoire par semaine** (le moins fidèle en relation). **Tout se rétablit dès régularisation.**
- **Réserve : oui** — dépôts libres et illimités dans le trésor ([[Économie — sources et puits]]), qui absorbe automatiquement les mauvaises semaines.

**Barèmes chiffrés ([[Barèmes économiques]]) :** `entretien = Σ(10 or / PNJ assigné) + Σ(25 or / structure spéciale : station, tourelle, hall de guilde)` ; `taxe de guilde = 0.05 × gains_de_quetes_de_la_semaine × rang_guilde_du_joueur`.

**Écran dédié ([[Écrans d'interface]]) :** gestion de claim — solde, prévisionnel hebdomadaire (revenus boutiques vs entretien), dépôts/retraits.

> [!success] Codé le 2026-08-28 — étape 10.1
> `entretien = Σ 10 or par PNJ assigné + Σ 25 or par structure spéciale (station fixe)` prélevé chaque semaine sur le **trésor** ; sinon `dette += manquant` avec les paliers de la note : 1 semaine → humeur −5 ; 2 → productivité −25 % ; 4+ → les gardes cessent, un PNJ (le moins fidèle) peut partir par semaine ; tout se rétablit dès régularisation. Taxe de guilde `0,05 × gains de quêtes de la semaine × (1 + 0,1 × rang)` prélevée sur l'or du joueur. **Rapport hebdomadaire** au journal (production, entretien, dette). Trésor : dépôts et retraits libres dans l'écran de gestion.

## Liens
- **Dépend de** : [[Économie — sources et puits]], [[Barèmes économiques]], [[Boutique passive]], [[Population et exploitation]]
- **Alimente** : [[Défense et raids]], [[Habitat des PNJ]]
- **Voir aussi** : [[Abstraction hors-site]], [[Halls de guilde]], [[Stations de transformation]], [[Quêtes et guildes]], [[Écrans d'interface]], [[Schéma royaume]]

> [!important] 2026-09-04, 16 h 45 — la grande base sur cinquante-deux semaines : deux écarts avec la note
> `sonde_grande_base --semaines 52` : la base se vide en trente-deux semaines (attendu, point 1 d'[[À juger — parcours de jeu]]), mais **l'humeur descendait à −43** et **les partants restaient debout dans le résidentiel** (vingt et un « civils » plantés là à la fin). Deux écarts de code avec la note : (1) l'humeur n'était plus recalculée tant que la dette durait, si bien que le « −5 » du palier s'empilait chaque semaine — la note dit une **humeur générale −5**, un état ; l'humeur est désormais recalculée chaque semaine (logement, faim) puis le malus de dette s'applique une fois : en dette, un résident sans toit ni repas reste à 30, pas à moins l'infini. (2) Le palier « 1 PNJ peut **quitter le territoire** » ne faisait que retirer l'assignation : le partant quitte la fenêtre pour de bon (il n'est plus dans la simulation ; son lit se libère), et le journal le dit.

