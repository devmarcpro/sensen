---
aliases: ["14.3", "14.3 Halls de guilde", "Halls de guilde", "Hall de guilde"]
tags: [société, endgame, décidé]
domaine: société
statut: décidé
etape: 10
---

Le contenu de guilde vient au joueur.

- Le joueur peut **construire les halls des guildes dans lesquelles il a un rang élevé** sur son propre territoire ([[Quêtes et guildes]]).
- Bénéfice : prendre les quêtes de ces guildes **sans se déplacer** — le contenu de guilde vient au joueur.

**Coût d'entretien ([[Barèmes économiques]]) :** un hall de guilde compte comme structure spéciale — 25 or/semaine.

**Unicité par ville PNJ ([[Génération des royaumes PNJ]]) :** chaque ville tire aléatoirement ses halls parmi les 12, avec **maximum un exemplaire de chaque type par ville** — aucune ville n'a tout, ce qui rend l'information « quelle ville a quel hall » précieuse ([[L'information comme récompense]]).

**Tables de sculpture ([[Tables de sculpture]]) :** l'accès aux tables des locaux de guilde (rang 3) précède l'obtention de la station personnelle (rang 4) — un hall sur son territoire donne cet accès sans déplacement.

> [!success] Précisé le 2026-08-28
> Les tables de sculpture sont abandonnées ([[Tables de sculpture]]) : les rangs 3 et 4 ne débloquent plus d'accès à ces tables ; leurs autres récompenses restent.

> [!success] Codé le 2026-08-28
> **Sur son territoire** : le meuble *Hall de guilde* (objet `meuble_hall_de_guilde`, recette à l'établi : 6 planches) se pose si le joueur est au moins **Adepte (rang 3)** dans une guilde ; il prend la guilde du rang le plus haut, fait apparaître un maître de guilde à côté (les quêtes de cette guilde sans se déplacer) et compte comme **structure spéciale (25 or/semaine)**. Démonter le hall renvoie le maître. Gabarits par guilde : guerriers (`chasse_prime`, `donjon`), chasseurs (`chasse_bete`, `traque`), prospecteurs (`purge`) ; les autres guildes attendent leurs patterns (transport, construction…).

## Liens
- **Dépend de** : [[Quêtes et guildes]], [[Expansion territoriale]], [[Construction cadrée]]
- **Alimente** : [[Entretien et taxes]]
- **Voir aussi** : [[Tables de sculpture]], [[Génération des royaumes PNJ]], [[L'information comme récompense]], [[Barèmes économiques]], [[Royaume du joueur]]
