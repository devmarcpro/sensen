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

> [!check] Rendu le 2026-09-03 — **vingt-huit espèces paisibles, et de quoi les dépecer**
> Le monde comptait vingt-huit bêtes dont **dix-neuf hostiles** : traverser une plaine, statistiquement, c'était ne croiser que ce qui voulait vous mordre. Ce qui manquait n'était pas de la mécanique — les profils `proie`, `fuyard` et `bete_sauvage` existaient et fonctionnaient — c'était du **peuplement**. On ajoute donc vingt-huit espèces qui ne cherchent pas la bagarre : dix mammifères (lièvre, écureuil, blaireau, castor, loutre, marmotte, bison, cheval sauvage, phoque, taupe, hérisson, mouflon), six oiseaux (héron, canard, corbeau, hibou, pie, perdrix) et dix insectes ou menu peuple (papillon, libellule, sauterelle, fourmi, coccinelle, luciole, escargot, ver de terre, bousier, grillon). Les insectes ont deux ou trois points de vie : on les tue d'un geste, et c'est **voulu** — ils sont là pour que le monde soit vivant, pas pour poser un problème, ce que la décision du designer sur les répercussions rend possible.
>
> **Le trou qu'on ne voyait pas en lisant les fiches.** Cerf, loup, renard, sanglier, aigle, rat géant, scorpion, chauve-souris — huit espèces qu'on croise tout le temps — n'avaient **aucun `drops_chasse`**. On tuait un cerf et on repartait avec un steak : ni cuir, ni bois, ni os. La compétence Chasseur existait sans avoir sur quoi mordre. Douze bêtes communes ont désormais une dépouille, et trois **parties** manquaient au catalogue pour cela : la **plume**, la **corne** et la **carapace**, que les matières animales réclamaient depuis qu'elles existent.
>
> **Ce que mesure la sonde** (`res://scenes/tests/sonde_faune.tscn`) : d'abord que chaque bête s'instancie — une action inconnue ou un squelette absent s'y voit, pas en jeu ; ensuite la part de paisible dans le **tirage pondéré** de chaque biome, jour et nuit, qui est ce qu'un joueur rencontre vraiment et non ce que la liste des fiches laisse croire. Elle échoue si un biome descend sous 15 % de paisible, sauf les deux corrompus où c'est le propos.

> [!success] Tranché le 2026-09-03 — **du roam et de l'aggro** (designer)
> « Retravaille les IA PNJ hostile comme pacifique, rajoute du roam de l'aggro etc. »
> **L'architecture n'est pas en cause.** Quatorze profils, chacun fait de considérations pondérées — `attaquer`, `fuir`, `errer`, `retour`, `attendre` — et le meilleur score l'emporte. C'est la bonne forme. Ce qui manque, ce sont trois comportements que ces considérations ne savent pas exprimer :
>
> **1. Le roam n'a pas de destination.** `_ia_errer` tire une case adjacente au hasard à chaque tick, bornée à douze tuiles de l'ancre. Un être ne se promène donc pas : il **tremble sur place**. Sur cent ticks, une marche au hasard s'éloigne en moyenne de dix tuiles de son point de départ — autant dire qu'un garde reste dans sa salle et qu'un cerf ne traverse jamais une clairière. Un donjon est une collection d'êtres plantés qui attendent qu'on entre.
> **Ce qu'on met à la place** : un **but**. L'être choisit une destination dans son rayon de roam, y va par le chemin, s'arrête un moment en arrivant, puis en choisit une autre. Le mouvement devient lisible — on voit quelqu'un *aller quelque part*.
>
> **2. L'aggro n'existe pas comme notion.** Un être attaque ce qui est à portée. Il ne se souvient pas de qui l'a frappé : tirer une flèche depuis l'ombre ne désigne pas le tireur. Il ne transmet rien : `cri_de_ralliement` et `hurlement` existent comme **actions** et ne réveillent personne. Et il ne désengage jamais vraiment — seuls une distance à l'ancre et un compteur de ticks sans vue le ramènent.
> **Ce qu'on met à la place** : une **table d'aggro** par être — qui m'a fait quoi, et combien. Frapper en monte, soigner l'ennemi en monte, le temps la fait redescendre. La cible est celle qui pèse le plus, pas la plus proche.
>
> **3. Le pacifique ne fait rien de pacifique.** `proie` et `fuyard` fuient le joueur, et c'est tout leur répertoire. Rien ne broute, ne dort, ne va boire. Les vingt-huit espèces paisibles ajoutées le 2026-09-03 sont vivantes au sens statistique et immobiles au sens visuel.
>
> **Les trois hypothèses que je pose, faute d'arbitrage — chacune est un chiffre ou une ligne :**
> - **l'aggro se transmet** aux alliés proches, dans un rayon, et à poids réduit. Une meute qui réagit ensemble est ce qui rend un loup effrayant ; sinon on les tue un par un pendant que les autres regardent. C'est aussi ce qui donne enfin un effet au cri de ralliement ;
> - **on désengage** : l'aggro décroît à chaque tick, et quand elle tombe sous un seuil l'être rentre. Poursuivre indéfiniment transforme chaque rencontre en course à travers l'étage ;
> - **le roam est une marche vers un but tiré au hasard**, pas une patrouille sur un chemin fixe. Les donjons sont générés et personne n'y a tracé de rondes ; une patrouille demanderait des points de passage écrits à la main dans chaque salle.

> [!check] Rendu le 2026-09-03 — **le roam mène quelque part, l'aggro désigne qui a frappé**
> Mesuré par `res://scenes/tests/sonde_ia.tscn` :
> - **roam** : huit êtres, cent tours d'errance — **10,3 tuiles** d'éloignement moyen de leur point de départ, 14 pour le plus loin. L'ancienne marche au hasard, bornée à douze tuiles, tremblait sur place ;
> - **aggro** : un loup frappé de loin par le joueur **le vise, lui**, alors qu'un autre ennemi se tient à une tuile ;
> - **alerte** : un loup voisin monte à 10 d'aggro sur le joueur **sans avoir été touché**. Un seul rebond, pas de proche en proche : un étage entier ne se lève pas d'un coup ;
> - **oubli** : 60 d'aggro, puis 0 après deux mille tours. C'est ce qui permet de désengager.
>
> > [!warning] La distinction qui m'a coûté deux tests avant que je la comprenne
> > **L'aggro dit qui on VEUT ; la perception dit si on peut y faire quelque chose.** Ma première version prenait pour cible celui qui pesait le plus dans la table, sans vérifier qu'on le voyait — et un être gardait donc pour cible un joueur passé en Discrétion parce qu'il l'avait aperçu une seconde plus tôt. **Toute la furtivité tombait avec.** L'aggro décide LEQUEL des ennemis visibles on vise — l'archer qui vous a blessé plutôt que le colosse planté devant vous — et non pas de voir à travers les murs.
> > C'est la suite de tests qui l'a dit, avec deux échecs nets (« discret : le loup ne le voit pas, pas de cible » et « semé en Discrétion »). Sans eux, j'aurais livré une aggro qui annule une mécanique entière sans que rien ne le signale.
>
> > [!bug] Et une faute que la documentation a rattrapée
> > En ajoutant les réglages d'aggro, j'ai **remplacé** le bloc `ia` des règles au lieu de l'étendre : `ticks_entre_decisions`, `soin_seuil`, `reculer_distance` et `guet_distance` ont disparu — de quoi faire qu'un soigneur ne soigne plus, qu'un tireur ne recule plus et qu'un embusqueur ne guette plus, en silence. Ce qui m'a sauvé, c'est que le `_doc` du bloc **racontait que ça s'était déjà produit** le 2026-08-31, une clé dupliquée ayant écrasé ces trois mêmes réglages. Restauré, comparé valeur par valeur, et le `_doc` dit maintenant que ce bloc **se fusionne, il ne se réécrit pas**.

> [!check] Rendu le 2026-09-03 — **le versant pacifique : brouter, boire, dormir**
> Une bête paisible ne se promène plus au hasard : quand elle choisit un but de roam, elle **préfère une case près d'une plante ou d'une eau**, et se rabat sur un but quelconque si rien ne se broute dans son rayon. C'est assez pour que le monde ait l'air habité par des bêtes qui *font* quelque chose — sans inventer un système de faim et de soif pour la faune, que personne n'a demandé et qui doublerait la complexité pour un gain visuel identique.
> Elle **dort** aussi : une nouvelle considération `heure_de_repos` la fait se reposer hors de son heure. Les **nocturnes** font l'inverse — c'est le même drapeau, lu à l'envers. Marqués : hibou, luciole, grillon, chauve-souris, essaim de chauves-souris.
>
> > [!warning] Une considération que personne ne pondère n'existe pas
> > Le moteur la calcule et l'ignore : elle ne pèse dans aucun score. J'ai donc dû donner du poids à `heure_de_repos` dans `proie` (1,4), `fuyard` (1,2) et `bete_sauvage` (0,9) — sans quoi j'aurais écrit du **code mort en croyant avoir livré un comportement**, et rien ne me l'aurait dit. C'est le revers de l'architecture par considérations pondérées : ajouter une entrée au dictionnaire des candidates ne suffit jamais, il faut aussi qu'un profil la regarde.
> > Au passage, l'envie d'errer des profils paisibles passe de 0,6 à **0,9** : maintenant qu'errer mène quelque part, ça vaut la peine d'y aller. Rien ne change pour un garde ou un assaillant, qui ne pondèrent pas ces considérations.

> [!bug] 2026-09-04, 21 h 50 — la routine n'a jamais pesé : `civil` et `garde` n'avaient pas de poids `routine`
> Le designer : « vérifie que les IA des PNJ fonctionnent correctement, que ce soit ennemis ou alliés ». La sonde `sonde_ia_pnj.tscn` pose un villageois au camp avec un poste à cinq tuiles à l'est, une place à cinq au nord, un lit à cinq à l'ouest, et fait passer midi, 21 h et 23 h : **il ne bouge pas** (5 → 5 tuiles aux trois heures). Le callout du 2026-08-28 (étape 9.B) dit que l'action `routine` et sa considération `hors_poste` ont été « ajoutées à l'utility » — c'est vrai du moteur (`_actions_candidates` la propose, `_decider_ia` l'exécute), mais **aucun profil ne la pondérait** : `civil.json` et `garde.json` datent du 9.A et n'ont jamais été retouchés. Une candidate sans poids score zéro, et `attendre` (calme 1,0) gagnait toujours. C'est exactement la faute décrite plus haut pour `heure_de_repos` (« une considération que personne ne pondère n'existe pas ») — le même piège, un jour plus tôt, jamais vu parce que rien ne mesurait la routine dans la fenêtre : la projection du LOD 2 (`_projeter_routine`), elle, lit les horaires directement et déplace un PNJ hors fenêtre, ce qui donnait l'illusion au chargement. **Corrigé en données** : `routine: {hors_poste: 1.2}` dans `civil` et `garde` — au-dessus d'`attendre` (1,0) et de `retour` (0,6 / 0,8) quand on est hors de son poste, et rien quand on y est. Test `test_routine_civile`.

> [!bug] 2026-09-04, 22 h — le cri de ralliement et le hurlement n'étaient jamais poussés : personne ne « soutenait » par un statut
> Même sonde : un chef de bande engagé contre le joueur, un bandit à cinq tuiles — l'acolyte reste dehors, aggro 0, et le chef n'a jamais crié. `_meilleur_soutien` ne savait proposer que deux effets, **soin** et **invoquer** ; une action d'allié à effet **statut** (`cri_de_ralliement` → ralliement, `hurlement` → hâte de meute) passait `_est_soutien` et ressortait vide. Le callout de l'aggro du 2026-09-03 disait que l'alerte « donne enfin un effet au cri de ralliement » : elle donne un effet à l'*alerte* quand on frappe le chef ; le cri lui-même, l'action de la fiche, restait lettre morte — comme le hurlement des loups, que la banshee et les deux loups portent depuis leur création. **Corrigé** : `_meilleur_soutien` propose une action d'allié à statut quand l'être a une cible et qu'un allié dans l'anneau de l'action n'a pas encore le statut ; le profil `elite` pondère `soutenir` à 1,3 et `hostile` à 0,9 — sous `attaquer` au contact (1,8), au-dessus de `poursuivre` (≤ 0,9) : le chef rallie et le loup hurle *avant* de charger, puis frappent. Les trente-deux hostiles sans action d'allié n'ont jamais de candidate `soutenir` : rien ne change pour eux. Test `test_cri_de_ralliement`.
>
> Ce que la sonde dit aussi, et qui est au designer : la **banshee** n'a que ces deux actions d'allié. Seule, elle engage le joueur, le suit, et ne peut rien lui faire.

> [!bug] 2026-09-04, 22 h 15 — dix « fuyards » attaquaient le joueur à vue : l'écureuil, le lièvre, la pie, la taupe…
> Même sonde, au camp, trente-sept bêtes paisibles posées à trois tuiles d'un joueur qui ne fait qu'attendre : les vingt proies s'éloignent sans un coup ; **les onze fuyards ouvrent le combat et mordent** — le rat géant 86 dégâts en quarante rondes, le hérisson 56, la pie 55, la marmotte 51, le corbeau 46. Le profil `fuyard` pondérait `attaquer` comme un hostile (portée 1,0, agressivité 0,8 = 1,8 à portée) et ne pondérait `fuir` que par la santé : à pleine vie, une perdrix chargeait. Le callout du 2026-09-03 les range pourtant parmi les « vingt-huit espèces qui ne cherchent pas la bagarre ». **Corrigé en données**, à la manière de `bete_sauvage` : `attaquer: {acculee: 1.5}` (il mord si on le coince au contact), `fuir: {menace_en_vue: 1.0, joueur_proche: 1.0, sante_basse: 2.0}` (il fuit à vue, et plus fort blessé). Le rat géant, tagué hostile ET fuyard, mord donc quand on est sur lui et fuit sinon ; si le designer le veut agressif à vue, c'est `ai_profile: hostile` dans sa fiche — une ligne.

> [!bug] 2026-09-04, 22 h 30 — voir le joueur ouvrait un combat, même pour un cerf
> Même sonde, mesurée autrement (un combat ouvert plutôt que des dégâts) : **trente-six bêtes paisibles sur trente-sept « attaquent »** — elles n'ont mordu personne, mais `_chercher_cible` engageait un combat avec tout ennemi vu, avant même de choisir une action ; la proie fuyait ensuite, participante d'un combat dont le joueur, lui, ne sortait qu'à douze tuiles ou trente ticks sans la voir. Dans le jeu : croiser un cerf au camp met le joueur « en combat » et arrête le monde. **Corrigé** : seul un profil qui pondère `attaquer` par `cible_a_portee` (`_profil_offensif`) engage à vue ; les autres prennent la cible pour la fuir et n'ouvrent un combat qu'en frappant vraiment (acculés, par `_ia_attaquer`). Le forçage « une bête hostile qui a une cible en vue ne flâne pas » suit la même règle. `bete_sauvage` perd `cible_a_portee` : la note dit « attaque acculée ». Test `test_proie_n_engage_pas`.

> [!check] 2026-09-04, 22 h 45 — **la sonde des IA de PNJ, ennemis et alliés** (`res://scenes/tests/sonde_ia_pnj.tscn`, `--seulement hostiles,paisibles,types,compagnons,camp,donjon`)
> Le designer : « vérifie que les IA des PNJ fonctionnent correctement, que ce soit ennemis ou alliés ». La sonde joue des scènes courtes et dit ce que chaque être a **fait** ; les quatre callouts au-dessus sont ce qu'elle a trouvé (avec le bug d'horloge du même soir, [[Boucle de tick]], trouvé par la capture juste avant). Après corrections, rien à signaler :
> - **quarante hostiles** du catalogue, chacun posé à trois tuiles d'un joueur qui attend, soixante rondes : **40 engagent, 40 frappent**, 28 approchent (les douze autres frappent de là où ils sont : serres, piqués, tirs), **0 figé** sur une horloge qui n'est pas la sienne ;
> - **trente-sept paisibles** au camp, quarante rondes : **37 s'éloignent, 0 attaque** — avant, les onze fuyards mordaient et trente-six « ouvraient un combat » ;
> - **les types** : le tireur posé au contact recule à deux tuiles et tire (90 dégâts en quarante rondes) ; le soigneur remonte un bandit de 18 à 40 PV ; le chaman appelle (cinq vivants, puis sept) ; le rôdeur guette à six tuiles et frappe quand on vient ; la brute à 10 % de vie ne fuit pas (133 dégâts) ; le bandit à 10 % fuit à treize tuiles ; le rat blessé au contact fuit à seize ; le chef de bande rallie l'acolyte à deux tuiles ;
> - **les compagnons** : après douze pas du joueur, à une tuile ; « attends ici » tenu à zéro tuile pendant que l'autre suit ; « suis-moi » ramène à une ; contre un bandit **2 sur 2 entrent dans le combat du maître** et le tuent (56 dégâts) ; « évite » s'écarte à sept tuiles sans un coup ; défensif, il reste à trois tuiles du maître pour une cible à huit ; agressif, il la poursuit à onze ;
> - **au camp** : le villageois fuit le loup à vingt-quatre tuiles ; le garde engage le loup à cinq tuiles, le tue, et patrouille ensuite ; **la routine mène au poste à midi, à la place à 21 h, au lit à 23 h** (5 → 0 tuiles chaque fois) ;
> - **en donjon** : un bandit à huit tuiles vient au joueur qui attend, l'engage et frappe (142 dégâts), sur l'horloge à l'action.
>
> Ce que la sonde **ne dit pas** : si c'est bien. Ce qui reste au designer est dans [[À juger — parcours de jeu]] (la banshee sans attaque, le rat géant coincé ou à vue, le recul du tireur). Et une promesse de la note toujours **non codée** : « civil : alerter gardes » — un civil n'alerte personne à vue ; ce qui existe, c'est l'aggro qui se transmet aux alliés à huit tuiles quand il est **frappé** (`_monter_aggro`, alerte), ce qui met le garde sur le loup un coup trop tard.

## Liens
- **Dépend de** : [[Schéma créature]], [[Data-driven design]], [[Boucle de tick]], [[Hauteur de terrain ±10]]
- **Alimente** : [[LOD de simulation]], [[Compagnons]], [[Raids et menaces]], [[Lois et infractions]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Abstraction hors-site]], [[Habitat des PNJ]], [[Population et exploitation]], [[Entités et pathfinding — performance]], [[Cycle jour-nuit et sommeil]], [[Créatures]], [[Jet de compétence universel]]
