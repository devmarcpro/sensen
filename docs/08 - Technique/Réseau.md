---
aliases: ["E.11", "Annexe E.11", "Réseau", "Autorité", "Host autoritaire"]
tags: [technique, réseau, décidé]
domaine: technique
statut: décidé
etape: 11
---

Le host est autoritaire, le client envoie des intentions. La règle qui tient dès le solo.

```
Host autoritaire sur : ticks, monde voxel, entités, loot, économie.
Client envoie : intentions (inputs, "je pose bloc X ici") ; le host valide
(anti-triche minimal : portée, possession) et diffuse le résultat.
Fiable (RPC) : mutations du monde, inventaire, craft, quêtes, votes.
Non-fiable 10-20 Hz : positions/animations des entités proches.
Intérêt : un client ne reçoit que les chunks/entités dans son rayon.
Vote tactique (5.0) : RPC fiable, majorité simple, re-vote possible
après 30 s ; le passage en tactique fige les ticks pour tous.
```

**Contrainte permanente ([[Contraintes permanentes]]) :** *serveur autoritaire, même en solo* — toute la logique de jeu vit côté serveur ; le client envoie des *intentions* et affiche un *état*. En solo les deux tournent dans le même processus, **jamais dans le même code**. Et : *aucun système de gameplay ne lit l'input directement*.

**Vote restant ([[Action-time à ticks]]) :** la mécanique de vote ne subsiste que pour le **saut de nuit** ([[Cycle jour-nuit et sommeil]]).

**RNG ([[Pipeline de résolution du combat]]) :** le host tire tous les dés — RNG seedé par tick pour la reproductibilité en debug.

**Liquides ([[Eau et liquides]]) :** le host simule, les écoulements sont des mutations de blocs standard — rien de nouveau à synchroniser.

**Optimisation :** voir [[Réseau et sauvegarde — performance]].

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Contraintes permanentes]], [[Simulation à ticks]]
- **Alimente** : [[Multijoueur]], [[Sauvegarde]], [[Réseau et sauvegarde — performance]]
- **Voir aussi** : [[Boucle de tick]], [[Pipeline de résolution du combat]], [[Eau et liquides]], [[Cycle jour-nuit et sommeil]], [[Temporalités parallèles]], [[Destruction du terrain]]
