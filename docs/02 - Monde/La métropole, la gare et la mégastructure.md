---
aliases: ["La métropole", "Métropole", "La gare", "Mégastructure", "Blame", "Le hub", "Le donjon central", "Bourse"]
tags: [monde, société, vision, à décider, designer]
domaine: monde
statut: à décider
etape: 12
---

Sept idées du designer, le 2026-09-12, prises dans ses notes. Cette note les garde **entières**, avec ce qui existe déjà pour les porter, ce qui les met en danger, et **la question qui les commande toutes**.

Rien de tout cela n'est décidé. C'est une exploration, écrite avant tout code.

> [!quote] Les notes, mot pour mot
> « Métropole gigantesque à plusieurs étages avec bourse, hub style mmo avec pleins d'aventuriers où tout peut s'acheter et tout peut se vendre — en gros c'est cyberpunk — pour y accéder trouver une gare et ride très loin — un des seuls endroits hand crafted donc dans toutes les parties — le joueur — un donjon gigantesque au milieu de la map — tout le monde est un donjon/ville/ruine infini en xyz style blamz — en combat les tuiles prennent des teintes de damier »

## Ce que je lis d'abord, et c'est le cœur de la note

**Trois des sept idées sont le même objet vu de trois côtés.** La métropole à étages, le donjon gigantesque au milieu de la carte et la mégastructure infinie en xyz ne se contredisent pas : *ce sont trois descriptions d'une ville qui descend sans fin*. Yharnam posée sur Blame!. Une agglomération dont les quartiers sont des étages, dont les étages du bas ne sont plus habités, et dont personne ne connaît le fond.

Si c'est bien cela, le projet gagne d'un coup ce qui lui manquait depuis le 2026-09-10 : **le lieu que la génération procédurale ne peut pas produire**. [[Le monde — Bloodborne et Caves of Qud]] l'écrit noir sur blanc — *« on n'obtiendra jamais Yharnam en engendrant des villages, et il ne faut pas essayer »*. Une métropole faite à la main, la même dans toutes les parties, **est la réponse à une tension qui était déjà nommée dans le coffre**. C'est le meilleur argument de tout le lot.

Si ce sont trois objets distincts, il faut le dire — parce qu'alors le jeu a **trois** destinations majeures (la métropole, le donjon central, le Dark Continent) et qu'aucune n'a de raison de l'emporter sur les autres.

## Ce qui existe déjà, et qu'il ne faut pas réinventer

C'est presque tout le mécanisme, et c'est ce qui rend ces lignes abordables :

- **La gare, le rail et le train sont CODÉS** depuis le 2026-09-05 ([[Villes — population, quartiers et économie]], B4) : le rail suit les routes du royaume, la tuile `quai` est la gare, le train est un **être** qui passe à 8 h, 14 h et 20 h, on monte, on paie `prix_par_cellule` × distance, on voyage plus vite que la marche. *Il n'y a rien à construire pour « trouver une gare ».*
- **Les étages sont la structure la plus ancienne du jeu** : un donjon empile des grilles bornées indexées `(x, y, z)` ([[Donjons — structure et intégration]], [[Grille continue]]), chaque étage avec son propre graphe de salles. Les **bâtiments à étages** existent en ville depuis le 2026-09-06. Une ville à étages n'est pas une structure neuve : c'est un donjon **habité**.
- **La ville est un territoire**, le même que le camp du joueur (2026-09-05) : quartiers typés sur plusieurs cellules, rues, résidents assignés, stocks, trésor, économie hebdomadaire, marchands itinérants, calèches.
- **Le prix sait déjà se calculer** — `valeur_base × qualité × rareté × réputation` ([[Commerce et boutiques]], [[Prix suggéré]]) — et la bourse *locale* est déjà une idée du designer, du 2026-09-10 : *« et si tous les prix étaient style bourse ? »* ([[Le corps comme système — organes, blessures et réserves]], § 2). **Il manque un seul terme : ce que ce lieu-ci en pense aujourd'hui.**
- **La bourse d'un marchand est finie** et ce qui dépasse son `or_max` **sort du jeu** : le puits existe.
- **Les PNJ se génèrent** par fonction, classe et culture ; un « aventurier » n'est pas une créature à écrire, c'est une fonction de plus.
- **Le damier est déjà une géométrie de sort** (`capacites.gd`, « une case sur deux, un terrain qu'on peut encore traverser »). Ce n'est pas un détail : voir la ligne 7.

---

## 1. La métropole gigantesque à plusieurs étages

**Ce que ça coûte : moins qu'il n'y paraît.** Les étages existent, les quartiers existent, les bâtiments à étages existent. Une métropole est une ville dont les **quartiers sont empilés** au lieu d'être posés côte à côte — le même `(x, y, z)` que le donjon, avec des habitants dedans.

**Ce que ça débloque, et qui est déjà une question en attente** : la question 13 de [[Décisions en attente]] — *« que voit-on du niveau du dessous depuis un étage ? »* — n'est plus une question de confort, elle devient **le blocage principal**. Une ville à étages où l'on ne voit pas la rue qu'on surplombe est aveugle ; une ville où l'on voit tout est illisible. La troisième voie écrite dans cette question (ne montrer le dessous **que par une ouverture** — une cage d'escalier, un trou, un balcon) est exactement ce qu'une métropole verticale demande, et c'est elle qui donne le vertige.

**Le danger** : une ville verticale multiplie le coût de génération par le nombre d'étages, et l'étage de donjon tient aujourd'hui dans un budget de 100 ms **par étage**. Une métropole de vingt niveaux n'est pas vingt fois un village : elle se génère **paresseusement, un étage à la fois**, comme un donjon — et elle ne se met en mémoire qu'à l'étage où l'on est.

## 2. Faite à la main, donc la même dans toutes les parties

**C'est l'idée la plus forte, et la plus étrangère au projet.** Tout Sensen dérive d'une graine ; ici, pour la première fois, un lieu ne dérive de rien. C'est un renversement, pas un ajout — et il faut donc savoir ce que « hand crafted » veut dire, parce que les deux lectures n'ont pas le même prix :

- **Le plan est écrit, la vie est engendrée** *(recommandé)* : le tracé, les niveaux, les portes, les noms des quartiers et des lieux-dits sont fixes et identiques dans toutes les parties ; **qui y habite, ce qui s'y vend, ce qui y a pourri** sont engendrés par la graine, comme partout ailleurs. Le joueur reconnaît le lieu, les joueurs parlent du même endroit — et le contenu reste vivant. Coût : une bibliothèque de salles assemblées selon un plan écrit, ce que la génération de donjon sait déjà faire, plus **le plan lui-même**, qui est du travail de designer.
- **Tout est dessiné, tuile par tuile** : des semaines de travail à la main, sur un projet qui n'a **aucun asset** et qui dessine tout par code. À dire clairement avant de commencer.

**Ce que la version recommandée donne gratuitement** : la **connaissance comme progression**, qui est ce que [[Le monde — Bloodborne et Caves of Qud]] retient de Bloodborne. Savoir qu'un raccourci existe derrière la troisième grille du niveau −4 est un savoir qui **traverse les parties** — le seul du jeu.

## 3. Pour y accéder : trouver une gare, et rouler très loin

**La gare existe, le train existe, le prix par cellule existe.** Deux règles s'y opposent, et ce sont deux décisions, pas deux chantiers :

- **Le train ne relie que les villes d'un même royaume.** La métropole n'appartient probablement à aucun royaume (une ville sans roi, ou un royaume à elle seule). Il faut une **ligne longue** qui ne suit pas les routes du royaume : un rail qui part d'une gare quelconque et s'en va.
- **Le voyage rapide ne s'ouvre que sur ce qu'on a déjà parcouru** ([[Carte du monde]]). Or « trouver une gare et rouler très loin » veut dire *partir sans savoir où l'on va*. La métropole est donc l'**exception assumée** : on ne voyage pas vite vers elle, **on la subit** — un trajet long, payé, qui ne s'annule pas.

**Et il y a une réponse à une question qui traîne depuis le 2026-09-05**, écrite dans [[À juger — parcours de jeu]] : *« le train n'est pas simulé entre deux gares… un train qui roule sous les yeux du joueur serait une autre affaire ; dis si tu la veux. »* **« Ride très loin » est cette réponse.** Le seul trajet du jeu qui mérite d'être vécu est celui-là — et il est bon marché à construire : un wagon est une **grille bornée** qui se déplace, c'est-à-dire exactement ce qu'est un étage de donjon. On y monte, on y rencontre des gens, on y dort, on y est attaqué, et le paysage défile à la fenêtre. *L'entrée vaut le lieu.*

## 4. La bourse, et « tout peut s'acheter, tout peut se vendre »

**C'est la ligne la plus dangereuse du lot, et elle a son antidote dans le coffre.**

Le danger est nommé mot pour mot dans [[Décision — Monde fini, continents et océan]] : *« l'infini avait un coût caché : rien n'y est rare »*. C'est pour ça que le monde a cessé d'être infini. **Un lieu où tout s'achète refait l'infini au milieu du fini** : plus aucune trouvaille n'est une trouvaille, plus aucun voyage n'a de motif, et le loot du donjon devient une monnaie.

**L'antidote est celui que le designer a lui-même proposé le 2026-09-10** : une bourse n'est pas un catalogue, **c'est un écart de prix**. Le prix porte un terme de lieu déduit des stocks — ce que la métropole a en trop est bon marché, ce qui lui manque est cher, et cela **bouge** avec ce que le monde fait (une guerre, une route coupée, un donjon vidé, une caravane perdue). Alors :

- « tout peut se vendre » cesse d'être une facilité et devient **le seul endroit qui achète ce que personne d'autre ne veut** — ce qui est déjà une raison de faire le voyage ;
- « tout peut s'acheter » devient un **arbitrage** : on achète ici pour vendre là-bas, et la métropole fabrique des itinéraires au lieu d'en supprimer ;
- les **marchands itinérants** et les caravanes, déjà codés, deviennent le transport du prix : ce sont eux qui propagent l'écart.

**Deux garde-fous à écrire avant, pas après** : la bourse de la métropole est **finie**, comme celle de tout marchand (sinon c'est un robinet d'or infini, et l'économie entière se vide dedans) ; et le marché **revend ce qu'on lui apporte, il n'engendre rien** — un artefact ne se tire aujourd'hui qu'à la mort d'un boss de donjon ([[Trésors et artefacts]]), il n'est ni craftable ni sculptable ; le jour où l'étal en propose un, descendre perd sa seule raison d'être.

## 5. Un hub façon MMO, plein d'aventuriers

**Le coût est faible** : les PNJ se génèrent, ils portent une classe, ils ont des routines, et l'[[Abstraction hors-site]] sait déjà faire vivre ce que le joueur ne regarde pas. Des aventuriers qui **partent en donjon et n'en reviennent pas toujours** sont la façon la moins chère de rendre un lieu vivant — et le meilleur usage possible de la simulation hors-site.

**Mais il y a une contrepartie, et elle touche le différenciateur déclaré du projet.** Depuis le 2026-09-10, la phrase que ni Qud ni Bloodborne ne peuvent dire est : *« on peut distancer sa propre réputation »*. Un lieu unique où tout le monde se retrouve **peut tuer cette phrase** : si toutes les nouvelles convergent en un point, on ne distance plus rien.

**Deux sorties, et il faut en choisir une :**
- **La métropole est là où la rumeur arrive en PREMIER** — toutes les routes y mènent. Alors on ne peut pas s'y cacher, et c'est **la scène** de la réputation plutôt que sa mort : le lieu où ce qu'on a fait ailleurs vous rattrape *(recommandé — la mécanique y gagne un théâtre)*.
- **La métropole est là où la rumeur arrive en DERNIER** — trop de monde, trop de bruit, personne ne sait qui tu es. Alors c'est le refuge de celui qui a tout brûlé derrière lui, ce qui est une autre bonne histoire, mais qui prive la ville de sa mémoire.

## 6. Un donjon gigantesque au milieu de la carte

**Trois remarques, dont une qui est un conflit dur :**

1. **Le milieu de la carte est le point de départ du joueur.** `cellule_depart` pointe la première forêt tempérée **au centre du monde** — (513, 257) — depuis le 2026-09-01, et pour une raison écrite : *« le début de partie doit être hospitalier »*. Le donjon central et le camp de départ ne peuvent pas occuper la même case. Soit le départ se déplace vers une périphérie (et le début de partie change de nature), soit « au milieu » veut dire *au milieu, et on vient de loin*.
2. **Cela ne casse aucune règle de difficulté** : le danger est une propriété du lieu, jamais de la distance ni du niveau du joueur ([[Niveau de danger]]). Un donjon central très dangereux est parfaitement légal — il est dur parce qu'il est profond (`corruption + étage × 8`), pas parce qu'il est loin.
3. **Mais il entre en concurrence avec le Dark Continent** ([[Ouvert — Dark Continent]]), qui est la destination de fin de partie déjà écrite, et dont la barrière est l'océan. Deux « grands ailleurs » se volent leur effet, **sauf si l'un est vertical et l'autre horizontal** : le donjon central se *descend*, le Dark Continent se *traverse*. Dit comme ça, ils ne se gênent pas — ils demandent deux préparations différentes.

## 7. Tout le monde en donjon / ville / ruine infini en xyz, façon Blame!

**Prise au pied de la lettre, cette ligne défait la décision fondatrice du 2026-08-26.** Il faut en mesurer le coût avant d'en discuter, comme on l'a fait pour l'identité chinoise :

> Ce qu'un monde-mégastructure retire : la **tectonique** (24 plaques, continents, îles, points chauds), les **biomes**, la **météo** (température, vent, gel), l'**agriculture et l'élevage** (51 plantes, 14 bêtes, les rotations), les **royaumes** avec leurs frontières terrestres, les **bateaux** et l'océan comme porte, les **saisons**, le **cycle jour-nuit** vu du ciel — et tout le programme du « monde réel » du 2026-09-05. C'est la moitié du jeu, et elle est codée.

**Et le motif de la décision de 2026-08-26 tient toujours** : l'infini rend tout gratuit, donc rien rare.

**Mais il y a une lecture qui ne coûte rien et qui donne l'image entière** : *la mégastructure n'est pas le monde, elle est la métropole*. **Infinie en z, bornée en xy.** Une ville qui descend sans fond, dont les niveaux du bas sont des ruines, dont les ruines du bas sont un donjon — c'est le Blame! qu'on veut, et c'est **la ligne 1, la ligne 2 et la ligne 6 réunies**, posées dans une planète qui ne bouge pas. Rien à jeter.

**Un détail technique à régler si le fond n'existe pas** : la corruption d'étage est `corruption_locale + étage × 8`, **plafonnée à 100**. Passé l'étage 12, un donjon cesse de devenir plus dangereux. Un puits sans fond demande une autre courbe — sans quoi le niveau −400 vaut le niveau −12, et « infini » veut dire « répétitif ».

## 8. En combat, les tuiles prennent des teintes de damier

**Elle répond à un manque réel** : rien au sol ne dit qu'on vient d'entrer en combat. L'entrée en combat change tout — l'horloge, les coûts, la portée — et ne se voit aujourd'hui que dans les panneaux.

**Un piège, et il est précis** : `damier` **est déjà le nom d'une géométrie de sort** — « un carré une case sur deux, un terrain qu'on peut encore traverser ». Un damier de fond sous des damiers de sorts se battra à l'écran, et sur la même grille. Le sol porte déjà beaucoup : la teinte de biome, la teinte de corruption, le jaune des coûts de déplacement, le rouge du télégraphe, le bleu de la prévisualisation.

**La forme qui survit à tout ça** : que le damier soit une affaire de **valeur**, pas de couleur — une alternance de luminosité très faible (quelques pour cent), sous toutes les couches colorées, qui se lit comme une texture et jamais comme une information. Il dit *« le temps a changé de nature »*, il ne dit rien d'autre. Et il se règle d'un nombre en données, donc il se juge à l'œil — ce qui est au designer ([[À juger — parcours de jeu]]).

---

## La question qui les commande toutes

> **La métropole est-elle un LIEU du monde, ou son CENTRE ?**

Tout le reste en découle, et les deux réponses font deux jeux différents :

- **Un lieu** — une destination parmi d'autres, extraordinaire, qu'on atteint après un long trajet et dont on revient. Le monde-planète reste le jeu ; la métropole en est le sommet.
- **Le centre** — le hub où l'on revient toujours, où tout s'achète, où tout le monde est. Alors la planète devient la **banlieue** de la métropole : les villages, les royaumes, l'agriculture et les six mois de simulation sociale deviennent le décor de trajets entre deux passages en ville. *C'est ce que fait un hub de MMO, et c'est très efficace — mais ça retourne le jeu.*

Mon avis, et il n'engage que moi : **un lieu**. Le projet a passé six mois à rendre le monde digne d'être habité ; un hub central le déshabiterait. La métropole est plus forte comme *l'endroit où l'on va* que comme *l'endroit d'où l'on part*.

## Deux questions plus petites, mais qui bloquent l'écriture

- **Le registre technologique** — c'est la question 34 de [[Décisions en attente]], et « en gros c'est cyberpunk » y répond **à moitié**. Reste : le cyberpunk est-il **partout** (et alors les monarchies héréditaires et les théocraties du générateur de royaumes deviennent incohérentes), ou **localisé dans la métropole** — un vestige d'une civilisation plus haute, au milieu d'un monde qui a régressé ? *La seconde est la réponse conservatrice, elle ne coûte rien à ce qui existe, et c'est exactement comme Bloodborne et Qud traitent leur propre technologie.*
- **Une ligne est restée en suspens dans les notes** : « **Le joueur** », seul, sans suite. Elle attendait quelque chose. Dis-moi ce qu'elle voulait dire — je la garde telle quelle plutôt que de deviner.

## Liens
- **Dépend de** : [[Le monde — Bloodborne et Caves of Qud]], [[Décision — Monde fini, continents et océan]], [[Villes — population, quartiers et économie]], [[Donjons — structure et intégration]]
- **Alimente** : [[Décisions en attente]], [[Ordre de travail]], [[Carte du monde]], [[Commerce et boutiques]]
- **Voir aussi** : [[Niveau de danger]], [[Ouvert — Dark Continent]], [[Grille continue]], [[Abstraction hors-site]], [[Rumeur et factions]], [[Le corps comme système — organes, blessures et réserves]], [[À juger — parcours de jeu]]
