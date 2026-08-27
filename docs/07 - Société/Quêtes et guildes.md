---
aliases: ["7.3", "7.3 Quêtes et guildes", "Guildes", "Quêtes", "Rangs de guilde"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 9
---

Douze guildes, des quêtes entièrement procédurales, et une progression de rang qui récompense en accès autant qu'en or.

**Génération des quêtes :** entièrement **procédurales**, générées à partir de gabarits (façon tableau de quêtes/bounty board) — cohérent avec l'infinité du monde et l'approche data-driven ([[Data-driven design]]). Pas de questlines écrites à la main pour l'instant. Schéma : [[Gabarit de quête]].

**Types de guildes envisagés :**
- Guerriers/combat
- Magie
- Artisanat/commerce
- Exploration/aventuriers
- Assassins/voleurs
- Transporteurs (logistique)
- Développement de ville/royaume
- Gladiateurs (tournois, arène — lié au PvP en duel, [[Multijoueur]])
- Navigateurs (exploration maritime, commerce à distance)
- Bâtisseurs (contrats de construction — lié aux tables de sculpture, [[Tables de sculpture]])
- Prospecteurs (repérage de gisements rares — lié aux couches de bruit de ressources, [[Génération par couches de bruit]])
- Chasseurs de trésor

**Progression de rang :** monter en rang dans une guilde donne accès à un **mélange** de :
- Meilleures récompenses (or, objets)
- Compétences/modules exclusifs à la guilde
- Accès à des zones/PNJ/services réservés
- **Tables de sculpture** ([[Tables de sculpture]]) : accès aux tables des locaux de guilde à un rang intermédiaire, puis station personnelle à un rang supérieur — chaque table est liée à une guilde spécifique.

**Décisions :**
- **Gabarits par guilde : oui, résolu ([[Gabarit de quête]])** — chaque gabarit porte un champ `guild` ; chaque guilde a ses patterns propres (combat = éliminer, transport = livrer, bâtisseurs = construire, prospecteurs = localiser...).
- **Réputation de guilde : ce n'est PAS une réputation ([[Réputation et relations]])** — c'est le système **rang + XP de guilde**, une progression, pas une opinion. Structure de rangs figée : **5 rangs** (Novice, Compagnon, Adepte, Expert, Maître), montée par XP de quêtes de guilde.
- **Multi-guildes : toutes cumulables** au lancement (les taxes hebdomadaires par guilde, [[Barèmes économiques]], sont le coût naturel du cumul).
- **Guilde développement de ville/royaume :** ses quêtes sont des **contrats de construction réels** (bâtir/réparer des structures sur des sites concrets, validées par la détection de pièces [[Détection de pièces]]) et des financements (apporter N matériaux à un projet communal contre or + XP de guilde).

*(L'apprivoisement est intégralement spécifié en [[Apprivoisement et recrutement]] — approcher, tenter, entretenir.)*

**Source de recettes exotiques ([[Craft compositionnel]]) :** enseignement de guilde (secrets d'artisans par rang) — l'une des trois sources, avec le loot et l'achat.

**Récompense d'information ([[Début de partie]]) :** la valeur précise de corruption se débloque par rang dans la guilde Exploration.

**Halls de guilde sur son territoire :** voir [[Halls de guilde]].

**Unicité par ville ([[Génération des royaumes PNJ]]) :** maximum un exemplaire de chaque type de hall de guilde par ville — trouver « la ville qui a un hall des Enchanteurs » est une vraie information.

**Succession du maître de guilde ([[Familles et succession]]) :** l'officier de plus haut rang après le maître devient le nouveau maître ; délai de transition 2 semaines.

> [!success] Précisé le 2026-08-28
> Sculpture abandonnée ([[Tables de sculpture]]) : les paliers de guilde qui y donnaient accès sont à réaffecter (recettes exotiques, station personnelle) — à préciser à l'étape 9.

## Liens
- **Dépend de** : [[Data-driven design]], [[Gabarit de quête]], [[Double niveau combat et général]]
- **Alimente** : [[Tables de sculpture]], [[Halls de guilde]], [[Craft compositionnel]], [[Barèmes économiques]], [[Économie — sources et puits]]
- **Voir aussi** : [[Réputation et relations]], [[Génération des royaumes PNJ]], [[Familles et succession]], [[Donjons — structure et intégration]], [[Multijoueur]], [[Minerais par profondeur]], [[Culture de nommage — schéma]]
