---
aliases: ["Ouvert — Réapparition d'un donjon", "Nouveaux donjons"]
tags: [ouvert, monde, donjon, décidé-par-défaut]
domaine: monde
statut: décidé-par-défaut
etape: 2
---

> [!success] Défaut fixé le 2026-08-26 — implémentable tel quel
> Sur délégation du designer : **le code part de cette valeur**, aucune question à se poser. La question reste légitimement ouverte au playtest — la réviser est une décision de tuning, pas de conception.

**La question :** un nouveau donjon peut-il apparaître ailleurs dans le monde pour remplacer celui disparu — et à quelle fréquence de génération de nouveaux foyers de donjon ?

**Ce qui est posé ([[Donjons — structure et intégration]]) :** un donjon nettoyé disparaît et sa cellule redevient claimable après 1,5 jour in-game. *Pas de farm infini du même donjon.* La densité de génération initiale est de **6 % par cellule** ([[Unification macro-micro]]).

**Ce qui existe déjà et pourrait servir de réponse ([[Dérive de la corruption]]) :** un foyer vidé devient **inactif** pendant sa période de répit (4 semaines pour un mineur, 12 pour un majeur), *puis il peut se repeupler (jet hebdomadaire, proba ∝ corruption locale restante)*. Reste à décider si cette règle s'applique aux donjons comme aux camps, ou si les donjons disparaissent définitivement et sont remplacés ailleurs.

**Ce qui en dépend :** la disponibilité à long terme de la seule source d'affixes, d'artefacts, de grimoires et de parchemins exotiques ([[Loot — affixes, gemmes et rareté]] : *le donjon est la SEULE source*) — un monde infini garantit qu'il y en aura toujours plus loin, mais la région pacifiée du joueur pourrait s'assécher.

## Le défaut : les donjons se repeuplent comme les autres foyers

**La règle de [[Dérive de la corruption]] s'applique aux donjons sans exception** : un donjon nettoyé devient un foyer **inactif** pendant sa période de répit — **4 semaines** (mineur) à **12 semaines** (majeur) — puis fait un **jet hebdomadaire de repeuplement, de probabilité ∝ corruption locale restante**.

**Concrètement :** le donjon disparaît de la surface après 1,5 jour ([[Donjons — structure et intégration]]) ; si le jet réussit après le répit, **un nouveau donjon est généré dans la même cellule** avec une **nouvelle seed** (nouveau plan, nouveau thème, nouveau loot — [[Génération de donjon]]). Dans une région pacifiée, la probabilité tend vers zéro : la région se vide durablement et le joueur doit s'éloigner — exactement l'effet voulu par [[Dérive de la corruption]].

**Pourquoi :** zéro système nouveau, et ça préserve la promesse de [[Loot — affixes, gemmes et rareté]] (*le donjon est la SEULE source*) sans jamais permettre de farmer le même donjon.

## Liens
- **Dépend de** : [[Donjons — structure et intégration]], [[Dérive de la corruption]]
- **Alimente** : [[Loot — affixes, gemmes et rareté]], [[Boucle de jeu]]
- **Voir aussi** : [[Unification macro-micro]], [[Claims et persistance]], [[Génération de donjon]]
