---
aliases: ["E.1", "Annexe E.1", "Boucle de tick", "Coûts d'action"]
tags: [combat, temps, technique, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le cœur du jeu, chiffré : cadence, coûts d'action, ordre déterministe d'un tick, et conversion en temps calendaire.

```
HORS COMBAT (exploration) : 10 ticks/seconde, l'horloge avance seule.
EN COMBAT (action-time) : 0 tick tant qu'aucune action ; une action pousse
N ticks (son coût) dans la file, exécutés immédiatement. Réfléchir est gratuit.
Chaque entité a un COMPTEUR : elle agit quand compteur <= horloge,
puis compteur += coût. Le choix d'arme est un choix de TEMPO.

Coûts d'action par défaut :
  se déplacer d'une tuile : 3 ticks (× modificateur de dénivelé, 3.6 ;
    modulé par vitesse/poids porté)
  attaque : 10 / vitesse_arme ticks · attaque lourde : ×2
  changer d'arme : 4 · utiliser un objet : 5 · prendre la garde : 2
  attendre : 5 (rend 20 d'endurance)
COOP : mêmes ticks à l'action — le temps avance dès qu'un joueur en
  consomme. Horloge constante = option de partie uniquement.

Ordre d'un tick (déterministe, host-autoritaire) :
  1. Entités : IA décide → actions résolues (combat E.3, déplacement)
  2. Systèmes du monde : croissance cultures, régén mana/santé, faim,
     timers (régénération cases sauvages, boutiques)
  3. EventBus : dispatch des événements émis pendant 1-2
  4. Réseau : diff d'état → clients
Le temps calendaire (jour/nuit, semaine in-game) est un compteur de ticks :
  1 jour in-game = 24 000 ticks (40 min temps réel). 1 semaine = 7 jours.
```

**Budget de performance ([[Budgets de performance]]) :** tick complet < 8 ms (marge sur les 100 ms du tick).

> [!success] Décidé le 2026-08-27 — la vitesse de déplacement n'est pas une stat, c'est une compétence
> Tranché par le designer : « améliorable ou altérable comme tout, pas de vitesse fixe ». Le déplacement d'une tuile coûte
> `ticks = 3 × modificateur_de_dénivelé / skill_factor(N_athlétisme) × facteur_esquive (en combat, [[Décision — Esquive active]]) × facteur_poids ([[Armures et poids porté]]) × facteur_friction ([[Application des stats de matériau]])`, arrondi, **minimum 2**.
> **Athlétisme** ([[Compétences — liste]] : course/saut/nage) est la compétence de la course. La différence entre un loup et un humain est un **modificateur de race** : la fiche déclare des niveaux de départ (`competences` — un loup part avec un Athlétisme élevé), rien n'est figé. Hâte, Ralentissement, équipement +Athlétisme passent par les mécanismes existants. Poids porté et friction n'existent pas encore dans le prototype (facteur 1). La règle « 3 ticks × modificateur de dénivelé, modulé par vitesse/poids porté » ci-dessus est ainsi chiffrée.

> [!warning] Réglage du 2026-08-27
> **Changer d'arme : 3 ticks** (au lieu de 4), pour que le swap paie dans certains cas seulement — mesure et raisons dans [[Jauge de chaîne Wu Xing]]. Valeur de playtest, `combat_rules.json`.

> [!success] Décidé et codé le 2026-08-30 — **résolution simultanée** : plus de tours, plus d'ordre de passage
> **Instruction du designer** : « supprimer complètement les tours et l'ordre de passage ; plusieurs PNJ peuvent effectuer des actions en même temps, le joueur et un ennemi peuvent attaquer exactement au même tick ». Jusqu'ici, à un même tick, `pas()` résolvait **une** action engagée par appel, dans l'ordre d'itération des êtres — si la première tuait l'auteur de la seconde, la seconde ne partait jamais : un ordre de passage caché. Désormais `pas()` prend **toutes les actions engagées dues à ce tick** (mêmes compteurs, même horloge) comme **un seul lot** : elles sont détachées d'un coup, puis résolues l'une après l'autre **comme si elles partaient au même instant** — un auteur tué dans le lot frappe quand même, une cible tuée dans le lot est quand même frappée (`Simulation.lot_simultane`). Les **décisions** (choisir sa prochaine action) restent une par appel : elles ne sont pas des coups, l'ordre n'y change rien de visible. Conséquence voulue : deux adversaires qui frappent au même tick peuvent **mourir ensemble**. La timeline graphique est **retirée** (elle affichait un ordre qui n'existe plus) ; les états se lisent au-dessus des êtres ([[Écrans d'interface]]).

> [!success] Décidé et codé le 2026-08-30 — **en donjon, le temps n'avance qu'à l'action**
> **Instruction du designer** : « être dans un donjon devrait être considéré comme en combat constamment, donc les ticks devraient passer uniquement quand un joueur effectue des actions ». Jusqu'ici l'horloge du monde tournait en temps réel (10 ticks/s) dans les étages, hors engagement : un joueur qui réfléchissait devant une salle laissait les bandits venir à lui. Désormais, quand un étage est chargé, l'horloge « monde » passe en mode **ACTION** (`combat_rules.donjon.temps_a_l_action`) : elle ne saute qu'au compteur du prochain être à agir, et s'arrête sur le joueur tant qu'il n'a pas donné d'intention — exactement comme une horloge de combat. Réfléchir est gratuit, partout dans le donjon. Le client fait avancer cette horloge pas à pas comme celles des combats (`DELAI_PAS`), le HUD affiche « DONJON — le temps n'avance qu'à l'action ». Les horloges de combat proprement dites restent créées à l'engagement (fin de combat, XP, chaîne : rien ne change) ; à la surface (camp, monde), le temps réel demeure. Faim, météo, territoire : toujours tiqués sur l'avancée de l'horloge monde, donc à l'action en donjon. Question laissée à [[À juger — parcours de jeu]] : faut-il aussi fusionner les horloges de combat dans celle du donjon (un seul temps par étage) ?

> [!success] Corrigé le 2026-08-31 — le donjon ne gèle plus entre deux actions du joueur
> **Retour du designer** : « le jeu lague énormément en donjon, ça galère à calculer tous les PNJ ? ». Ce n'était pas le calcul : le client faisait avancer l'horloge du monde en mode action **au même rythme de lisibilité que les combats** (un pas toutes les 0,12 s) — or chaque « attend » de chaque PNJ de l'étage consomme un pas : 30 PNJ ≈ 4 secondes de gel réel après chaque action du joueur, d'autant plus long que l'étage est peuplé. Désormais l'horloge du monde se vide **chaque image** (jusqu'à ce qu'elle bute sur le joueur, garde-fou de 128 pas) ; les horloges de combat gardent leur cadence de 0,12 s, qui est un choix de lisibilité des coups. Le coût CPU réel d'un pas de simulation est mesuré par `test_budgets` (< 8 ms). La question C++/GDExtension ([[Vers la production]] 5) reste ouverte mais rien ne la justifie à ces mesures.

> [!note] Réglages — `combat_rules.ticks_par_seconde_exploration` (10) : la vitesse de l'horloge du monde en exploration, hors combat. Pointeur ajouté le 2026-09-04.

## Liens
- **Dépend de** : [[Action-time à ticks]], [[Simulation à ticks]]
- **Alimente** : [[Pipeline de résolution du combat]], [[Endurance]], [[Mana]], [[Faim]], [[Cycle jour-nuit et sommeil]], [[Dérive de la corruption]]
- **Voir aussi** : [[Hauteur de terrain ±10]], [[EventBus]], [[Réseau]], [[Budgets de performance]], [[Temporalités parallèles]]

> [!bug] 2026-09-04, 21 h 15 — une bête qui ouvre un combat par sa propre action restait sur le tampon du monde
> Vu par `capture --creature rat_geant --dump` : le rat mord le joueur (ce qui crée le combat et fait passer le rat sur l'horloge du combat), puis `_lancer_action_creature` écrivait `compteur = tick + coût` avec le tick **du monde** reçu en argument : « agit à t=8007 » dans un combat à t=15. Le rat ne rejouait jamais, le joueur restait seul « en combat » avec une bête figée tant qu'il ne s'éloignait pas de douze tuiles. Les attaques d'arme lisaient déjà `horloge_de(e).ticks` après l'engagement ; les actions de créature font pareil. Test `test_bete_engage_sur_son_horloge`. Le drapeau `--dump` de la capture reste : à chaque prise, les combats et les êtres à huit tuiles du joueur sur la sortie standard.
