---
aliases: ["E.5", "Annexe E.5", "Détection de pièces", "Détection de pièce", "Flood fill"]
tags: [société, technique, décidé]
domaine: société
statut: décidé
etape: 7
---

> [!note] Adapté au pivot tactique
> Algorithme réécrit en 2D — [[Construction cadrée]] la déclare « triviale en 2D ». Le flood fill 3D d'origine est archivé (GDD source, historique git). Critères chiffrés : [[Décision — Pièces en 2D]].

L'algorithme qui pilote le logement des PNJ, la capacité des villages et les contrats de construction — trivial en 2D depuis le pivot.

```
Déclenchée à la pose/destruction d'une tuile ou d'une porte sur un claim
(événement EventBus, throttlé). Flood fill 2D depuis chaque porte du claim :
- région de tuiles intérieures close si le fill ne s'échappe pas à travers
  les murs (contenu de tuile) ; borné (au-delà : "trop grand/ouvert") ;
- toit = propriété de l'empreinte du bâtiment (4.1 : un bâtiment est une
  empreinte de tuiles + une hauteur de murs — rien à détecter en volume) ;
- surface minimale en tuiles (Proposition — Pièces en 2D) ;
- >= 1 entité meuble dans la région.
Résultat : liste de pièces {surface, meubles, porte(s)} stockée par claim ;
l'assignation PNJ↔pièce se fait dans l'UI de gestion du claim.
Bétail : toute tuile sous une empreinte avec toit.
```

**Throttling ([[Simulation du monde — performance]]) :** 1 revalidation/s max par claim, flood fill borné, en thread — inchangé.

**Trois usages :**
1. Logement des PNJ du joueur ([[Habitat des PNJ]]) ;
2. Capacité d'un village PNJ ([[Villages PNJ — repeuplement et décimation]], [[Conquête de village]]) ;
3. Validation des contrats de construction de la guilde développement de ville ([[Quêtes et guildes]]).

**Nœuds du graphe de POI ([[LOD de simulation]]) :** les lits des pièces détectées sont des nœuds du graphe de niveau 2.

> [!success] Codé le 2026-08-28 — `Simulation.pieces_de_cellule(cell)`
> Flood fill 2D depuis chaque **porte** d'une cellule revendiquée (dans la fenêtre chargée) : la région est close si elle ne s'échappe pas (bornée à 1 024 tuiles, murs = tag `mur`, portes = tag `porte`, l'eau et les solides bloquent) ; **surface ≥ 6**, **≥ 1 meuble**. **Toit** : décision — les empreintes de bâtiment n'existent pas encore en code, une région close par des murs est réputée couverte. Résultat `{tuiles, meubles (types), portes}` par cellule, recalculé au passage de semaine (pas de throttling par événement : le passage hebdomadaire suffit tant que le logement n'est lu qu'à la semaine). La capacité de village reste « un lit par PNJ initial ».

## Liens
- **Dépend de** : [[Construction cadrée]], [[EventBus]], [[Claims et persistance]]
- **Alimente** : [[Habitat des PNJ]], [[Villages PNJ — repeuplement et décimation]], [[Quêtes et guildes]], [[LOD de simulation]]
- **Voir aussi** : [[Décision — Pièces en 2D]], [[Conquête de village]], [[Simulation du monde — performance]], [[Meubles]], [[Arborescence du projet]], [[Écrans d'interface]]
