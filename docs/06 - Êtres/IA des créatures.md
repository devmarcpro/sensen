---
aliases: ["E.16", "Annexe E.16", "IA", "Utility AI", "Pathfinding", "Détection"]
tags: [êtres, technique, décidé]
domaine: êtres
statut: décidé
etape: 9
---

> [!note] Adapté au pivot tactique
> Pathfinding réécrit pour la grille : la traversabilité découle des règles de dénivelé de [[Hauteur de terrain ±10]]. La version « voxel 3D » d'origine est archivée (GDD source, historique git).

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

**Détection :** vision = cône de distance f(Perception) modulé par la lumière locale ([[Application des stats de matériau]] : `luminosite`) et la Discrétion de la cible (jet opposé [[Jet de compétence universel]] quand ça compte). L'alerte se propage aux alliés proches (événement local, pas EventBus global). La ligne de vue est bloquée par le dénivelé ([[Hauteur de terrain ±10]]).

**Pathfinding sur la grille (deux étages) :**

```
LOCAL : A* sur la grille de tuiles — la traversabilité et les coûts
  découlent des règles de dénivelé (3.6) :
    Δ0 : 3 ticks · +1 : 5 · +2 : 8 · Δ ≥ +3 : infranchissable
    −1/−2 : 2 ticks · chute ≥ 3 acceptée par l'IA si les dégâts
    (hauteur−2)×5 restent supportables (paramètre du profil) ;
    échelles/cordes/portes = liens spéciaux du graphe.
  Une tuile est bloquée par son contenu (mur, meuble) ou son occupant.
  La nav-grille d'un chunk est invalidée par tile_placed/destroyed et
  reconstruite paresseusement : le monde destructible est géré
  nativement.
  Budget : file de requêtes globale, N chemins résolus/tick ; entités
  lointaines ou non-critiques : déplacement en ligne droite + esquive
  d'obstacle locale (pas de vrai A*).
GLOBAL : graphe grossier au niveau cellules/routes (E.2) pour les trajets
  longue distance (caravanes, raids inter-cellules) ; affiné en local à
  l'arrivée. Hors zone chargée : pas de pathfinding du tout — les entités
  sont dans l'abstraction (E.6), position téléportée logiquement.
Morphologies (12) : les volants ignorent les contraintes de dénivelé
  (survol des Δ ≥ 3 et des tuiles d'eau) ; les amorphes passent les
  ouvertures d'une tuile. Paramètres de navigation dans le template
  de squelette.
```

**Malus de vision nocturne ([[Cycle jour-nuit et sommeil]]) :** cône réduit pour tous — la nuit favorise la Discrétion (jets +4) autant qu'elle menace.

**Détection d'infraction ([[Lois et infractions]]) :** réutilise ce cône de détection — aucun témoin dans le rayon → l'infraction est ignorée mécaniquement.

**Signal :** `chunk_explored` alimente la minimap ([[Minimap et brouillard de guerre]]).

**Budget ([[Entités et pathfinding — performance]]) :** jamais plus de ~6 décisions utility/tick ; 2 requêtes A* résolues/tick max, résultats cachés et partagés.

> [!success] Décidé le 2026-08-26 — l'utility du prototype
> Le prototype implémente le noyau : profils dans `data/ai_profiles/` (`hostile`, `bete_sauvage`, `compagnon`), `score = Σ considération × poids` sur des considérations normalisées 0-1 (`cible_a_portee`, `cible_visible`, `distance_cible`, `sante_basse`, `loin_de_l_ancre`, `cible_perdue`, `endurance_basse`, `acculee`, `joueur_proche`, `calme`), une action infaisable est simplement absente des candidates. Actions : `attaquer` (l'action ou l'arme faisable aux dégâts moyens les plus hauts), `poursuivre`, `fuir`, `retour` (à l'ancrage), `attendre`. **Détection** = `Perception` tuiles (facteur `detection_par_perception` de `combat_rules.json`) **avec ligne de vue** ; le cône, la lumière et la Discrétion viennent plus tard. Une décision à chaque fois que l'entité est due (l'échelonnement « 1 tous les 10 ticks » viendra avec le LOD).

> [!success] Codé le 2026-08-28 — profils `civil` et `garde`
> `civil` : attend (calme), fuit dès qu'une menace est en vue (`fuir` pondéré par la santé et la proximité), ne poursuit ni n'attaque ; `garde` : attaque et poursuit les hostiles, retourne à son poste. **Camps** : `joueur`, `civil` et `hostile` — un civil et le joueur ne sont pas ennemis (`Simulation.ennemis(a, b)` : deux camps différents sont ennemis sauf joueur/civil ; la réputation qui retourne un village attend 9.C). Les `horaires` des fonctions (6-20 h poste, 20-22 h social, nuit lit) sont en données mais pas encore joués (9.B).

## Liens
- **Dépend de** : [[Schéma créature]], [[Data-driven design]], [[Boucle de tick]], [[Hauteur de terrain ±10]]
- **Alimente** : [[LOD de simulation]], [[Compagnons]], [[Raids et menaces]], [[Lois et infractions]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Abstraction hors-site]], [[Habitat des PNJ]], [[Population et exploitation]], [[Entités et pathfinding — performance]], [[Cycle jour-nuit et sommeil]], [[Créatures]], [[Jet de compétence universel]]
