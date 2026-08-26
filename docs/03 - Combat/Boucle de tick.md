---
aliases: ["E.1", "Annexe E.1", "Boucle de tick", "Coûts d'action"]
tags: [combat, temps, technique, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le cœur du jeu, chiffré : cadence, coûts d'action, ordre déterministe d'un tick, et conversion en temps calendaire.

```
HORS COMBAT (exploration) : 10 ticks/seconde, l'horloge avance seule.
EN COMBAT (action-time) : 0 tick tant qu'aucune action ; une action pousse
N ticks (son coût) dans la file, exécutés immédiatement. Réfléchir est gratuit.
Chaque entité a un COMPTEUR : elle agit quand compteur <= horloge,
puis compteur += coût. Le choix d'arme est un choix de TEMPO.

Coûts d'action par défaut :
  se déplacer d'une tuile : 3 ticks (× modificateur de dénivelé, 3.6 ;
    modulé par vitesse/poids porté)
  attaque : 10 / vitesse_arme ticks · attaque lourde : ×2
  changer d'arme : 4 · utiliser un objet : 5 · prendre la garde : 2
  attendre : 5 (rend 20 d'endurance)
COOP : mêmes ticks à l'action — le temps avance dès qu'un joueur en
  consomme. Horloge constante = option de partie uniquement.

Ordre d'un tick (déterministe, host-autoritaire) :
  1. Entités : IA décide → actions résolues (combat E.3, déplacement)
  2. Systèmes du monde : croissance cultures, régén mana/santé, faim,
     timers (régénération cases sauvages, boutiques)
  3. EventBus : dispatch des événements émis pendant 1-2
  4. Réseau : diff d'état → clients
Le temps calendaire (jour/nuit, semaine in-game) est un compteur de ticks :
  1 jour in-game = 24 000 ticks (40 min temps réel). 1 semaine = 7 jours.
```

**Budget de performance ([[Budgets de performance]]) :** tick complet < 8 ms (marge sur les 100 ms du tick).

## Liens
- **Dépend de** : [[Action-time à ticks]], [[Simulation à ticks]]
- **Alimente** : [[Pipeline de résolution du combat]], [[Endurance]], [[Mana]], [[Faim]], [[Cycle jour-nuit et sommeil]], [[Dérive de la corruption]]
- **Voir aussi** : [[Hauteur de terrain ±10]], [[EventBus]], [[Réseau]], [[Budgets de performance]], [[Temporalités parallèles]]
