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

> [!success] Codé le 2026-08-28 — étape 9.B : routines horaires, patrouilles, `errer`
> Les profils à `horaires` (civil, garde) jouent leur **routine** sur l'horloge du monde : `"6-20": "poste"` → le PNJ rejoint son poste (là où il est né : étal, forge, champ), `"20-22": "social"` → la place du village, `"22-6": "lit"` → son lit ; le garde **patrouille** pendant son poste (un point au hasard autour de son ancrage, renouvelé à l'arrivée). Action `routine` (considération `hors_poste`) et `errer` (un pas au hasard, considération `calme`) ajoutées à l'utility ; en surface seulement. Décision : le pas de routine est **glouton** (la case adjacente la plus proche de la cible, A* sous 20 tuiles) — le graphe de POI du LOD 2 attend.

> [!success] Codé le 2026-08-29 — la Discrétion entre enfin dans la détection
> `voit_ia` ne lisait que la Perception, la lumière et le tag `pas_silencieux` : la compétence **Discrétion** ne servait qu'aux infractions, et la note *Créatures* attendait « la Discrétion +4 » depuis l'étape 9. Désormais la portée de détection est **réduite par la Discrétion de la cible** : `portée × (1 − min(discretion_max_pct, (niveau + bonus de nuit) × discretion_par_niveau))` — 2 % par niveau, **plafond 60 %**, plus les **+4 niveaux équivalents la nuit** (`cycle.discretion_nuit`, déjà utilisé par les infractions). Un rôdeur de niveau 20 est vu de 40 % moins loin le jour, de 52 % moins loin la nuit. Décisions : la réduction est **déterministe**, pas un jet par tick (un jet ferait clignoter la détection d'un pas à l'autre — le jet opposé reste pour les moments qui comptent : témoin d'infraction, approche d'apprivoisement) ; elle ne s'applique **pas à un être immobile en garde** — se cacher demande de bouger comme de ne pas bouger, mais tenir sa garde n'est pas se cacher ; et la portée ne descend jamais sous **1 tuile** (adjacent, on voit toujours).

> [!success] Corrigé le 2026-08-29 — la détection n'entrait pas dans l'acquisition de cible
> Suite du callout précédent, et bug plus grave que ce qu'il corrigeait : `voit_ia` (Perception, nuit et lumière, Dissimulation de L'Ombre, pas silencieux, Discrétion) n'était appelé que par les **témoins** d'infraction, les PNJ qui fuient un spectre et le passage de garde à combat des compagnons. **`_chercher_cible`**, la fonction par laquelle une créature hostile prend le joueur pour cible, lisait la **Perception brute et la ligne de vue** — donc ni la nuit, ni une torche, ni la Discrétion, ni L'Ombre ne changeaient jamais le moment où un loup vous repère, et une cible en ligne de vue n'était jamais perdue. Les deux passent par `voit_ia`. Conséquence voulue : **semer en Discrétion** existe — une cible que l'IA ne voit plus pendant `engagement.ia_ticks_sans_vue` (100 ticks) est lâchée, qu'elle soit derrière un mur, dans le noir ou simplement discrète. Le dernier « hors du code » de [[Prototype de combat — spécification]] tombe avec l'embuscade.

> [!success] Codé le 2026-08-30 — reculer, soutenir, guetter
> Pour les [[Créatures]] nouvelles (tireur, invocateur, soigneur, embusqueur), trois considérations et deux actions de plus dans l'utility — invisibles aux profils qui ne les pondèrent pas. **`reculer`** (`cible_au_contact`) : proposé quand la cible est à `combat_rules.ia.reculer_distance` (1) ou moins et que l'être a une action de portée minimale ≥ 2 ; exécuté comme un pas de fuite. **`soutenir`** (`allie_a_soutenir`) : proposé quand `_meilleur_soutien` trouve quelque chose — l'allié le plus blessé sous `ia.soin_seuil` (0,7) à portée d'un soin, ou une invocation sous le plafond `max` de l'action quand un ennemi est pris pour cible ; les actions de soutien (cible `allie`, effets `soin` / `invoquer`) ne sont **jamais** choisies comme attaques. **`guet`** (considération d'`attendre`) : 1 quand la cible est à plus de `ia.guet_distance` (3) tuiles — l'embusqueur la laisse venir. Un profil `tank` a `seuil_fuite_sante` 0 ; un `fuyard` 0,5.

> [!success] Tranché le 2026-09-02 — **la faune paisible se tue sans conséquence** (designer)
> « La faune paisible peut être tuée sans répercussions. » Pas de perte de réputation, pas de raréfaction, pas de prédateurs affamés : un écureuil abattu est un écureuil abattu. C'est une simplification assumée, et elle a une vertu — elle évite d'ajouter un système de conséquences écologiques à un jeu qui en porte déjà beaucoup.
> **Ce que cela change pour le peuplement** : les bêtes paisibles sont là pour que le monde soit **vivant** et pour nourrir la chasse, pas pour poser un dilemme moral. Elles peuvent donc être nombreuses et fragiles sans qu'on craigne de vider le monde.

## Liens
- **Dépend de** : [[Schéma créature]], [[Data-driven design]], [[Boucle de tick]], [[Hauteur de terrain ±10]]
- **Alimente** : [[LOD de simulation]], [[Compagnons]], [[Raids et menaces]], [[Lois et infractions]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Abstraction hors-site]], [[Habitat des PNJ]], [[Population et exploitation]], [[Entités et pathfinding — performance]], [[Cycle jour-nuit et sommeil]], [[Créatures]], [[Jet de compétence universel]]
