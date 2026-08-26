---
aliases: ["12.5", "12.5 Noms de PNJ et de villes", "Noms culturels", "Génération culturelle des noms"]
tags: [êtres, société, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Un générateur préfixe + suffixe piloté par culture — aucun nom écrit à la main, une variété énorme depuis quelques dizaines d'entrées par pool.

**Principe : générateur par préfixe + suffixe, piloté par culture.** Chaque nom (prénom, nom de famille, nom de ville) est formé en tirant une **partie A** et une **partie B** dans les pools d'une **culture** (schéma [[Culture de nommage — schéma]]) et en les concaténant — aucun nom écrit à la main, une variété énorme depuis quelques dizaines d'entrées par pool.

- **Chaque PNJ a un prénom ET un nom de famille**, générés à l'instanciation ([[Schéma créature]]). Le nom de famille est **hérité** : un PNJ fondateur (sans parent) tire un nom de famille dans le pool de sa culture, ses enfants ([[Âge des PNJ]], liens `family`) le portent automatiquement.
- **Titre pour les PNJ importants** : tout PNJ à `leadership_role` ([[Familles et succession]]) reçoit en plus un **titre** tiré du pool de sa culture, adapté à son type de rôle (Roi/Reine pour une monarchie, Premier Ministre pour une république, Grand Maître pour une guilde...) — affiché avant son nom (ex. "Roi Aldric Sombreval").
- **Culture ≠ race — deux axes indépendants** : une race peut porter plusieurs cultures possibles selon le royaume où elle est née (un royaume **humain** peut avoir une culture à sonorité chinoise, nordique, latine... — cf. exemple [[Culture de nommage — schéma]]). Chaque culture déclare des **affinités de tirage par race** (`race_affinity`) : les 3 races piochent parmi les 7 cultures, toutes inspirées du monde réel — l'Humain a le spectre le plus large, le Nain penche vers le nordique, l'Elfe vers le celte.
- **Villes et villages** héritent de la culture de leur royaume ([[Génération des royaumes PNJ]]) — noms cohérents à l'échelle d'un même royaume.
- **Ordre des noms** configurable par culture (`name_order`: `prenom_nom` ou `nom_prenom`) — certaines cultures nomment famille avant prénom.

**Décisions :**
- **Cultures de lancement : 7** (liste [[Cultures de nommage]]) — assez pour une vraie variété sans exploser le volume de contenu à la main.
- Détail technique complet (algorithme, formats) : **[[Génération de noms]]**.

**Hors localisation ([[Localisation]]) :** les noms propres saisis par le joueur (modèles sculptés, PNJ renommés) et les ids internes.

**Contenu à produire :** [[Ouvert — Pools de noms des cultures]].

## Liens
- **Dépend de** : [[Culture de nommage — schéma]], [[Schéma créature]], [[Races]]
- **Alimente** : [[Génération de noms]], [[Génération des royaumes PNJ]], [[Cultures de nommage]]
- **Voir aussi** : [[Familles et succession]], [[Âge des PNJ]], [[Localisation]], [[Dialogue PNJ]], [[Ouvert — Pools de noms des cultures]]
