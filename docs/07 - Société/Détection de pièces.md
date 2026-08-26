---
aliases: ["E.5", "Annexe E.5", "Détection de pièces", "Détection de pièce", "Flood fill"]
tags: [société, technique, décidé]
domaine: société
statut: décidé
etape: 7
---

> [!note] Adapté au pivot tactique
> L'algorithme 3D d'origine est conservé en fin de note comme référence historique. [[Construction cadrée]] déclare la détection « triviale en 2D » — c'est cette version qui fait foi. Critères chiffrés (surface minimale) : [[Proposition — Pièces en 2D]].

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

---

### Texte voxel d'origine (référence historique, E.5)

```
Déclenchée à la pose/destruction d'un bloc ou d'une porte sur un claim
(événement EventBus, throttlé). Flood fill 3D depuis chaque porte du claim :
- volume clos si le fill ne s'échappe pas (limite 4 096 blocs sinon "trop
  grand/ouvert") ; plafond couvert = toit ; volume intérieur >= 2×2×2 ;
  >= 1 entité meuble dans le volume.
Résultat : liste de pièces {volume, meubles, porte(s)} stockée par claim ;
l'assignation PNJ↔pièce se fait dans l'UI de gestion du claim.
Bétail : flood fill vertical simple (un toit au-dessus de la position).
```

## Liens
- **Dépend de** : [[Construction cadrée]], [[EventBus]], [[Claims et persistance]]
- **Alimente** : [[Habitat des PNJ]], [[Villages PNJ — repeuplement et décimation]], [[Quêtes et guildes]], [[LOD de simulation]]
- **Voir aussi** : [[Proposition — Pièces en 2D]], [[Conquête de village]], [[Simulation du monde — performance]], [[Meubles]], [[Arborescence du projet]], [[Écrans d'interface]]
