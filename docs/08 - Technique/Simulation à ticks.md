---
aliases: ["Simulation à ticks", "TickManager", "Ticks architecture"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

Une seule source d'avancement du temps de jeu : le TickManager. Jamais `_process(delta)` pour la logique.

**Simulation à ticks (décision fondamentale, voir [[Action-time à ticks]])** : un `TickManager` (dans WorldManager ou autoload dédié) est la seule source d'avancement du temps de jeu.
- En **temps réel**, il émet des ticks à fréquence fixe (ex : 10 ticks/s) ;
- en **mode tactique**, il n'émet que lorsqu'une action de joueur consomme du temps.

Tous les systèmes (combat, mana [[Mana]], faim [[Faim]], IA, croissance des cultures, timers de régénération [[Claims et persistance]]) s'abonnent aux ticks et n'utilisent **JAMAIS** `_process(delta)` pour la logique de jeu — delta reste réservé au purement visuel (animations, interpolation, particules).

**En multi, le host est l'autorité des ticks et les diffuse** ([[Réseau]]).

**Contrainte permanente ([[Contraintes permanentes]]) :** *déterminisme — génération seedée, résolution par ticks, aucun recours au delta de frame dans la logique.*

**Ordre déterministe d'un tick et coûts d'action :** [[Boucle de tick]].

**Temporalités multiples ([[Temporalités parallèles]]) :** une horloge du monde, une par combat, une par donjon — dès le départ, jamais une horloge unique globale.

**Timer wheel ([[Simulation du monde — performance]]) :** cultures, faim PNJ et timers ne tournent pas par tick — chaque instance stocke son échéance et s'enregistre dans une timer wheel globale.

> [!success] Codé depuis l'étape 0 — trace ajoutée le 2026-09-04
> `Simulation.pas()` avance l'horloge, résout ce qui est dû dans un lot simultané (`lot_simultane`), applique les intentions ; le client fait `pas("monde")` en exploration et laisse le combat en temps à l'action. Le budget « tick < 8 ms » est mesuré par `test_budgets`.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Action-time à ticks]], [[Contraintes permanentes]]
- **Alimente** : [[Boucle de tick]], [[Réseau]], [[Simulation du monde — performance]]
- **Voir aussi** : [[Temporalités parallèles]], [[Mana]], [[Faim]], [[Claims et persistance]], [[Cycle jour-nuit et sommeil]], [[IA des créatures]]
