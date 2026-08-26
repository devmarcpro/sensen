---
aliases: ["E.7", "Annexe E.7", "Raids", "Raids et menaces", "Menaces"]
tags: [société, technique, décidé]
domaine: société
statut: décidé
etape: 10
---

La fréquence et l'échelle des raids — jamais scalées sur le niveau du joueur, toujours sur le monde.

```
Fréquence des raids sur un royaume de joueur : jet hebdomadaire in-game,
probabilité = f(corruption locale EFFECTIVE (E.20), valeur du territoire, réputations
négatives — un roi capturé (14.2) augmente drastiquement la proba côté
royaume lésé). Force du raid ~ valeur du territoire * (0.8-1.2), jamais
scalée sur le niveau du joueur (cohérent avec 3.1 : le monde ne scale pas).
Joueur présent : spawn réel d'une escouade à la bordure de cellule, IA
d'assaut vers le cœur du claim. Absent : résolution E.6.
```

**Raid de reconquête ([[Conquête de village]]) :** le royaume d'origine d'un village annexé, s'il reste hostile et puissant, peut lancer un raid de reconquête via ce même pipeline — cible = le village annexé.

**Accord de non-agression ([[Gouvernance, lois et diplomatie]]) :** aucun raid entre les deux royaumes — accessible à tous sauf l'anarchie, qui ne peut rien garantir.

**Raid pendant une nuit sautée ([[Cycle jour-nuit et sommeil]]) :** les raids peuvent frapper pendant la nuit sautée et **réveillent le dormeur** (résolution réelle).

**Événement en zone logique ([[LOD de simulation]]) :** joueur assez proche → chargement forcé + matérialisation du combat ; sinon → résolution par formule.

**Signal :** `raid_resolved` sur l'EventBus, écouté par le journal et la réputation ([[EventBus]]).

**Coût ([[Simulation du monde — performance]]) :** passages hebdomadaires sur listes filtrées — déjà bon marché par conception.

## Liens
- **Dépend de** : [[Défense et raids]], [[Dérive de la corruption]], [[Abstraction hors-site]], [[IA des créatures]]
- **Alimente** : [[Conquête de village]], [[Gouvernance, lois et diplomatie]]
- **Voir aussi** : [[Niveau de danger]], [[Population et exploitation]], [[LOD de simulation]], [[Cycle jour-nuit et sommeil]], [[EventBus]], [[Simulation du monde — performance]]
