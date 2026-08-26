---
aliases: ["E.16", "Annexe E.16", "IA", "Utility AI", "Pathfinding", "Détection"]
tags: [êtres, technique, décidé, héritage-voxel]
domaine: êtres
statut: décidé
etape: 9
---

> [!warning] Héritage voxel
> Le bloc « pathfinding voxel 3D » (2 blocs d'air au-dessus, liens de saut/chute, A* volumique) est héritage : sur la grille, la traversabilité découle des règles de dénivelé de [[Hauteur de terrain ±10]] (+1/+2 franchissable à surcoût, ±3 infranchissable, chute avec dégâts). L'Utility AI, les routines, la détection et le graphe global survivent. Volants/amorphes à re-spécifier.
> — Classement complet : [[Héritage voxel — audit]].

Une Utility AI data-driven : créer ou modifier un comportement = éditer un JSON, zéro code.

**Architecture : Utility AI data-driven** (`data/ai_profiles/*.json`). Ne s'applique qu'aux PNJ en simulation PLEINE — niveau 1 du LOD ([[LOD de simulation]]) ; les PNJ hors chargement tournent en mode logique (graphe de POI) ou abstrait ([[Abstraction hors-site]]). À chaque tick de décision (1 tous les 10 ticks par entité, échelonnés entre entités), l'entité NOTE ses actions candidates et exécute la mieux notée :

```
score(action) = Σ considération_i * poids_i
Considérations : lisent les mêmes données que tout le reste (stats, tags,
faim, santé, distance de cible, job assigné, horaire, ordres reçus...).
Exemples de profils :
  hostile      : attaquer(portée, agressivité), poursuivre, fuir(santé<25%)
  bete_sauvage : fuir(joueur proche), attaquer(acculée), errer, manger
  civil        : routine horaire (voir ci-dessous), fuir(danger), alerter gardes
  garde        : patrouiller, intercepter(hostile détecté), retour au poste
  assaillant   : progresser vers cœur du claim, détruire obstacles(murs),
                 attaquer défenseurs — utilisé par les raids (E.7)
  compagnon    : voir E.17
Créer/modifier un comportement = éditer un JSON, zéro code.
```

**Routines civiles :** champ `horaires` du profil, piloté par l'horloge de ticks ([[Boucle de tick]]) : ex. 6h-20h → job (étal, champ, forge), 20h-22h → social (taverne/place), nuit → lit assigné ([[Habitat des PNJ]]). C'est ce qui fait vivre les villages, et ça réutilise l'assignation de jobs ([[Population et exploitation]]).

**Détection :** vision = cône de distance f(Perception) modulé par la lumière locale ([[Application des stats de matériau]] : `luminosite`) et la Discrétion de la cible (jet opposé [[Jet de compétence universel]] quand ça compte). L'alerte se propage aux alliés proches (événement local, pas EventBus global).

**Pathfinding voxel 3D (deux étages) :**
```
LOCAL : A* sur grille de navigation dérivée des blocs — marchable =
  bloc solide + 2 blocs d'air au-dessus ; liens de saut (1 bloc),
  de chute (<= 3 blocs), échelles/portes. La nav-grille d'un chunk est
  invalidée par `block_placed/destroyed` et reconstruite paresseusement :
  le monde destructible est géré nativement.
  Budget : file de requêtes globale, N chemins résolus/tick ; entités
  lointaines ou non-critiques : déplacement en ligne droite + esquive
  d'obstacle locale (pas de vrai A*).
GLOBAL : graphe grossier au niveau cellules/routes (E.2) pour les trajets
  longue distance (caravanes, raids inter-cellules) ; affiné en local à
  l'arrivée. Hors zone chargée : pas de pathfinding du tout — les entités
  sont dans l'abstraction (E.6), position téléportée logiquement.
Morphologies (12) : volants ignorent la contrainte de sol (A* 3D volumique
  simplifié) ; amorphes passent les ouvertures 1 bloc. Paramètres de
  navigation dans le template de squelette.
```

**Malus de vision nocturne ([[Cycle jour-nuit et sommeil]]) :** cône réduit pour tous — la nuit favorise la Discrétion (jets +4) autant qu'elle menace.

**Détection d'infraction ([[Lois et infractions]]) :** réutilise ce cône de détection — aucun témoin dans le rayon → l'infraction est ignorée mécaniquement.

**Signal :** `chunk_explored` alimente la minimap ([[Minimap et brouillard de guerre]]).

**Budget ([[Entités et pathfinding — performance]]) :** jamais plus de ~6 décisions utility/tick ; 2 requêtes A* résolues/tick max, résultats cachés et partagés.

## Liens
- **Dépend de** : [[Schéma créature]], [[Data-driven design]], [[Boucle de tick]]
- **Alimente** : [[LOD de simulation]], [[Compagnons]], [[Raids et menaces]], [[Lois et infractions]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Abstraction hors-site]], [[Habitat des PNJ]], [[Population et exploitation]], [[Entités et pathfinding — performance]], [[Cycle jour-nuit et sommeil]], [[Créatures]], [[Jet de compétence universel]]
