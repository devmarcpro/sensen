---
aliases: ["5.0", "5.0 Le temps", "Action-time", "Ticks", "Action-time à ticks"]
tags: [combat, temps, décidé]
domaine: combat
statut: décidé
etape: 0
---

Il n'y a pas de tours : il y a une horloge partagée que les actions font avancer. Réfléchir est gratuit.

**Exploration en temps réel libre, combat en action-time.** Il n'y a **pas de tours** : il y a une **horloge partagée** que les actions font avancer.

```
Hors combat : déplacement libre en temps réel.
En combat   : le temps n'avance QUE lorsqu'une action est engagée.
              Réfléchir est gratuit et illimité.

Chaque entité possède un COMPTEUR : elle agit quand
compteur <= horloge, puis compteur += coût_de_son_action.
Une dague à 6 ticks joue trois fois pendant qu'un espadon à 18
joue une fois — LE CHOIX D'ARME EST UN CHOIX DE TEMPO.

Coûts de référence (E.1) :
  déplacement d'une tuile : 3 ticks (× modificateur de dénivelé)
  attaque                 : 10 / vitesse_arme
  changer d'arme          : 4 · objet : 5 · prendre la garde : 2
```

- **Le combat est in-situ** : le monde EST la grille de combat. Aucune instance, aucune arène qui se ferme. Le combat s'enclenche au contact d'un hostile et se relâche quand il n'y en a plus.
- **TEMPORALITÉS PARALLÈLES (coop)** : voir [[Temporalités parallèles]].
- **Architecture à ticks conservée** ([[Simulation à ticks]]) : toute la simulation (IA, statuts, croissance, économie, faim) est pilotée par des ticks, jamais par le delta de frame. En exploration temps réel, l'horloge avance d'elle-même ; en combat, elle avance à l'action.
- **Vote** : la mécanique de vote ne subsiste que pour le **saut de nuit** ([[Cycle jour-nuit et sommeil]]).

**Détail chiffré de la boucle :** [[Boucle de tick]].

> [!success] Codé depuis l'étape 0 (2026-08-26) — trace ajoutée le 2026-09-04
> C'est la boucle même du jeu : chaque être a un `compteur` en ticks, agit quand l'horloge l'atteint, et le coût d'une action est son délai (`Regles.ticks_attaque()`, `ticks_deplacement()`). Deux horloges coexistent, monde et combat (`horloge_de()`) — voir [[Temporalités parallèles]]. La suite le vérifie à chaque passe (« descente −1 : 2 ticks », « montée +1 : 5 ticks »).

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Simulation à ticks]]
- **Alimente** : [[Boucle de tick]], [[Combat tactique sur grille]], [[Jauge de chaîne Wu Xing]], [[Endurance]], [[Sorts cataclysmiques]]
- **Voir aussi** : [[Temporalités parallèles]], [[Hauteur de terrain ±10]], [[Stats d'armes]], [[Cycle jour-nuit et sommeil]]
