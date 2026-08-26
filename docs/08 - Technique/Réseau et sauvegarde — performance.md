---
aliases: ["G.7", "Annexe G.7", "Réseau performance", "Sauvegarde performance", "zstd"]
tags: [technique, performance, réseau, décidé]
domaine: technique
statut: décidé
etape: 11
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : « + octrees » retiré de la compression. Le reste (deltas, batching, quantification, autosave en thread) est inchangé.

Deltas compressés, positions quantifiées, sauvegarde en thread qui ne bloque jamais.

```
Chunks vers les clients : envoyés compressés (zstd sur le
PackedByteArray), puis uniquement des DELTAS (liste de
mutations) — jamais de renvoi complet. Mutations groupées par tick
(batching) en un seul paquet fiable.
Positions d'entités : quantifiées (10 cm), envoyées seulement si
changées, interpolées côté client.
Sauvegarde : sérialisation en thread, écriture atomique (E.10) ;
l'autosave ne bloque jamais le jeu (copie-sur-écriture des
structures modifiées pendant la sérialisation).
```

**Critère de validation ([[Ordre de vérification]]) :** *2 joueurs LAN : mutation visible < 100 ms chez l'autre.*

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Réseau]], [[Sauvegarde]]
- **Alimente** : [[Multijoueur]], [[Ordre de vérification]]
- **Voir aussi** : [[Proposition — Structure de données de la grille]], [[Budgets de performance]], [[Décisions d'architecture]]
