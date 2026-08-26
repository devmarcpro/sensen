---
aliases: ["Décision — Pièces en 2D", "Proposition — Pièces en 2D", "Pièces 2D", "Critères de pièce"]
tags: [ouvert, proposition, héritage-voxel, société, décidé]
domaine: société
statut: décidé
etape: 7
---

> [!success] Décidé le 2026-08-26
> Rédigée pour remplacer l'héritage voxel, **validée sur délégation du designer** (« tout doit être rédigé et décidé avant production »). Le code s'appuie dessus ; révisable comme toute décision.

**Le problème :** [[Habitat des PNJ]] exige une pièce de « 2×2×2 blocs » et un bonus à « volume ≥ 27 blocs » ; [[Détection de pièces]] la valide par flood fill 3D. Critères volumétriques — or [[Construction cadrée]] déclare la détection « triviale en 2D » (empreinte de tuiles + hauteur de murs).

## La proposition

**Une pièce valide :**
- une région 2D de tuiles intérieures **close** (flood fill 2D depuis chaque porte, borné à **1 024 tuiles** — au-delà : « trop grand/ouvert ») ;
- délimitée par des **murs** (contenu de tuile) et **une porte** ;
- couverte par un **toit** — propriété de l'**empreinte du bâtiment** ([[Construction cadrée]] : un bâtiment est une empreinte + une hauteur de murs ; le toit est un drapeau de l'empreinte, plus rien à détecter en volume) ;
- **surface ≥ 4 tuiles** (l'équivalent 2D du 2×2×2) ;
- **≥ 1 meuble** (n'importe lequel — inchangé).

**Meilleure chambre :** +1 humeur par type de meuble distinct, max +10 (inchangé) · **+5 si surface ≥ 9 tuiles** (remplace « volume ≥ 27 blocs », qui était un 3×3×3).

**Bétail :** toute tuile sous une empreinte avec toit (remplace le « flood fill vertical simple »).

**Capacité de village ([[Villages PNJ — repeuplement et décimation]], [[Conquête de village]]) :** inchangée — Σ des pièces valides selon les critères ci-dessus.

## Ce que ça préserve

Tous les malus/bonus chiffrés de [[Habitat des PNJ]] (−15 sans logement, −5 par co-occupant, l'humeur comme levier de rendement), le throttling et le déclenchement par EventBus de [[Détection de pièces]], et les trois usages de l'algorithme (habitat, capacité de village, contrats de construction).

## Les derniers points, fixés

- **Surface minimale : 6 tuiles** (et non 4). En isométrique, une pièce de 2×2 avec un meuble et une porte est illisible ; 6 tuiles (2×3) est le plus petit espace qui se lit comme une chambre. Le strict équivalent volumétrique cède devant la lisibilité — c'est le principe de [[Direction artistique]].
- **Bonus de taille : +5 à partir de 12 tuiles** (3×4) — assez grand pour se distinguer nettement du minimum.

## Liens
- **Dépend de** : [[Héritage voxel — audit]], [[Détection de pièces]], [[Habitat des PNJ]], [[Construction cadrée]]
- **Alimente** : [[Villages PNJ — repeuplement et décimation]], [[Conquête de village]], [[Quêtes et guildes]]
- **Voir aussi** : [[Meubles]], [[LOD de simulation]]
