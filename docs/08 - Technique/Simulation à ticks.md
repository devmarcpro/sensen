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


> [!success] Fait le 2026-09-08 — **un tick est devenu une milliseconde** (designer : « je pense que ça serait mieux de faire en sorte que 1 tick soit équivalent à 10 millisecondes non ? », puis « et si une tick une milliseconde ? », puis « on fait ça »)
> Le monde tournait à **10 ticks/s** : un tick valait 100 ms, et le temps à l'action ne savait pas exprimer une différence de vitesse plus fine que 10 % — une frappe coûtait 5 ticks, deux combattants dont l'un est 10 % plus rapide se départageaient sur **0,5 tick**, arrondi à 0 ou à 1. À **1000 ticks/s**, la frappe vaut 500 ticks et les 10 % se disent exactement. Et une durée en donnée **se lit en temps réel** : `duree_ticks: 300`, c'est 300 ms.
> **Ce qui a décidé, et c'était mesurable** : je croyais qu'une horloge 100 fois plus fine coûterait 100 fois plus de pas. Faux — `Horloge.accumuler` **saute** (un seul `avancer(n)` par image), et ce qui l'écoute fait agir *ce qui est dû* puis compare des **périodes**. Le coût est par image et par entité due, jamais par tick.
> **Le travail n'était pas le ×100, c'était la classification.** Un balayage sur les noms trouve 942 champs qui parlent de temps ; trois pièges rendent le balayage inutilisable :
> - des **multiplicateurs portent le mot « ticks »** — `lourde_mult_ticks`, `extraction_ticks`, et surtout `echec_ticks_rendus` (0,5), lu comme `1 − x` : une **fraction**. Et `progression.ticks_plancher_module` (0,5 = « jamais sous 50 % de sa base »), **dans lequel je suis tombé au premier passage** : toutes les capacités ont coûté cinquante fois leur base jusqu'à ce que la suite le crie ;
> - des **coûts en ticks ne portent pas le mot** — `actions.attaque_base`, `changer_arme`, `deplacement.cout_base`, `montee_1` — et juste à côté, dans le même bloc, `chute_delta` est une **hauteur** et `creuser.xp` de l'**XP** ;
> - trois **débits par tick** demandaient une **division** : vérifié que les trois passent par des flottants avec un seul arrondi, donc 0,02 et 0,01 se comportent.
> **Et un tick écrit en dur, comme annoncé** : le sommeil avançait le monde par tranches de **100**, plafonnées à **200** — 20 000 ticks au total, quand une nuit en fait 800 000. Le dormeur se réveillait douze minutes plus tard. Les deux nombres sont en données.
> **Le garde-fou du script** : il **échoue** s'il rencontre un champ temporel qu'aucune de ses trois listes ne nomme, et il ne **commence à écrire qu'après** avoir tout classé — le premier jet écrivait au fil de l'eau, s'arrêtait sur les refus et laissait la donnée à moitié migrée. Il a fallu restaurer depuis git pour s'en apercevoir.
> **Les sauvegardes** portent une `version` : une partie d'avant est multipliée au chargement, sinon son calendrier reculerait de plusieurs jours.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Action-time à ticks]], [[Contraintes permanentes]]
- **Alimente** : [[Boucle de tick]], [[Réseau]], [[Simulation du monde — performance]]
- **Voir aussi** : [[Temporalités parallèles]], [[Mana]], [[Faim]], [[Claims et persistance]], [[Cycle jour-nuit et sommeil]], [[IA des créatures]]
