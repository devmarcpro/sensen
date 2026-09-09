---
aliases: ["Émergence — les champs partagés", "Émergence", "Thermodynamique", "Gravité"]
tags: [vision, monde, décidé, à-juger]
domaine: vision
statut: décidé
etape: 12
---

Ce que le jeu doit avoir pour que les systèmes se répondent au lieu de se juxtaposer — et la règle qui les tient.

## La règle : un champ partagé, pas un système de plus

Un jeu est émergent quand **deux systèmes qui ne se connaissent pas se rencontrent dans une même donnée**. Un feu qui
brûle de l'herbe est un système ; un feu qui chauffe une armure de fer, fait fondre la neige, réveille un gaz et fait
paniquer un troupeau est un **champ** que cinq systèmes lisent. La différence n'est pas la richesse du feu : c'est que
la chaleur existe **en dehors** de lui.

D'où la règle qui commande tout ce qui suit : **un champ nouveau doit REMPLACER les règles ad hoc qui l'imitaient**,
jamais s'ajouter à côté. Sinon on obtient six vérités qui se contredisent, et la simulation devient un empilement.

> [!important] Décidé le 2026-09-08, 6 h — la thermodynamique et la gravité (designer : « il faudrait qu'on ait une vraie thermodynamique, une vraie gravité »)
> **Pourquoi maintenant, et pourquoi ces deux-là** : le coffre les promet déjà, et les données existent.
> - [[Mine sous une cellule]] dit en toutes lettres : « on n'y risque que **l'effondrement**, l'endurance et la faim. C'est ce qui la sépare le plus nettement du gouffre. » Aujourd'hui on n'y risque **rien** : la seule chose qui distingue une mine d'un gouffre n'est pas codée.
> - Les treize stats d'un matériau ([[Matériaux — 13 stats]]) portent déjà `isolation`, `flammabilite` et `densite` — la résistance, le seuil d'inflammation et la masse thermique. Le fer : isolation 5, densité 8. Ces trois nombres n'attendent qu'un champ de chaleur pour vouloir dire quelque chose.
> - Et c'est **le seul endroit** où porter du calcul dans le noyau C++ s'impose sans discussion : un champ diffusé sur la fenêtre est une boucle pure sur un tableau contigu — exactement la forme de `propager_lumiere`, qui existe et y tourne déjà.
>
> **La chaleur** : un `PackedFloat32Array` sur la fenêtre, **jamais sauvegardé**, reconstruit de ses sources au chargement comme la carte de lumière. Sources : le feu, la lave, le soleil, un corps vivant, une forge allumée. Puits : l'eau, la neige, la nuit, le vent. La diffusion pondérée par `isolation` (ce qui retient) et `densite` (ce qui met du temps à changer).
> **Ce que le champ REMPLACE**, et c'est la condition : le feu qui propage par flammabilité, la lave qui brûle et fige l'eau, le gaz inflammable qui s'allume, la neige et le gel, la température ressentie de la météo — cinq règles ad hoc qui deviennent **cinq lectures du même champ**. Une tuile s'enflamme quand sa chaleur dépasse le seuil de sa matière ; la neige fond au-dessus de zéro ; l'eau gèle en dessous ; la lave chauffe au lieu d'enflammer par une règle à part.
> **Ce que ça donne tout de suite** : une armure de fer devient un four près d'une coulée, une pièce fermée garde sa chaleur, un feu de camp réchauffe qui dort à côté, et un mineur qui perce une poche de magma sent la galerie devenir invivable avant d'y mourir.
>
> **La gravité** : pas de physique continue — la grille est un champ de hauteurs, pas un voxel. Le bon modèle est celui de Dwarf Fortress, **le support** : une tuile pleine sans voisine pleine ni sol dessous s'effondre ; l'effondrement blesse, bouche la galerie, et se propage à ce qu'elle portait. Creuser une galerie trop large sous la roche devient dangereux, **étayer devient un geste**, et le puits de mine cesse d'être un ascenseur gratuit.
>
> **Trois pièges, écrits avant de coder** :
> - **Le déterminisme** : toute la suite compare des résultats exacts. Un champ diffusé doit avoir un ordre de parcours fixe, sinon les tests deviennent du sable.
> - **L'incrémental dès le premier jour** : le balayage du 2026-09-08 a trouvé qu'*une seule tuile changée refait toute la carte de lumière de la fenêtre* — chaque porte de ville la déclenche. La chaleur tique en continu là où la lumière ne bouge qu'au changement : bâtie sur le même patron, elle hériterait du défaut au carré.
> - **L'ordre** : ça ne passe pas devant la sauvegarde qui perd une mine au rechargement, ni devant le menu de triche resté sur `V` dans la version publiée. Un mineur qui meurt d'un effondrement magnifique dans une mine qui redevient un donjon à salles au rechargement, c'est pire que pas d'effondrement du tout. **La sauvegarde d'abord, puis la chaleur, puis le support.**

> [!important] Décidé le 2026-09-08, 6 h 15 — les six autres champs qui manquent à l'émergence (designer : « quoi d'autre pour que le jeu soit vraiment émergent »)
> Le même critère à chaque fois : **est-ce un champ que plusieurs systèmes liraient, ou un système de plus ?** Rangés par ce qu'ils feraient émerger, pas par facilité.
>
> **1. Le bruit et l'odeur — le champ qui manque le plus.** Le jeu a la lumière (0-15, propagée) et bientôt la chaleur ; il n'a **rien pour ce qui s'entend et ce qui se sent**. Aujourd'hui la Discrétion est un simple facteur sur la portée de détection : se cacher est un nombre, pas un lieu. Un champ de bruit propagé (une porte qui claque, un combat, une forge, un éboulement) et un champ d'odeur qui traîne (le sang, la viande, le feu, le joueur lui-même) feraient émerger : la meute qui suit une piste au lieu de voir à travers les murs, l'embuscade qui se prépare en silence, la ville qu'on réveille, le prédateur qu'attire une carcasse laissée là, le mineur qu'on entend creuser à l'étage au-dessus. **C'est ce qui manque le plus à un jeu qui a déjà une Discrétion, des meutes et des odeurs de cuisine.**
>
> **2. L'eau qui pèse et qui use.** L'automate d'eau déplace des niveaux ; il ignore la **pression** (une nappe percée devrait noyer une galerie, pas la mouiller), le **poids** (l'eau devrait charger un plancher et le rompre — c'est la gravité qui le dira) et l'**érosion** (un courant devrait creuser). Le premier point est déjà à moitié là depuis les poches d'eau du 2026-09-07 : la brèche devient une source, et c'est tout.
>
> **3. Le champ de danger que les êtres lisent.** Les créatures décident sur des considérations pondérées (attaquer, fuir, errer) mais **le terrain ne leur dit rien** : elles ne voient ni le feu, ni le gaz, ni la lave, ni le vide. Un champ de danger par tuile, alimenté par les automates et lu par le chemin, ferait qu'une bête contourne un incendie, qu'un PNJ fuie une galerie qui s'effondre, qu'un garde n'entre pas dans un nuage. **Sans lui, tout ce qu'on ajoute au terrain est invisible à l'IA** — et c'est déjà le cas des gaz posés hier.
>
> **4. La réputation comme champ, pas comme compteur.** Elle existe (par village, par royaume, globale) mais elle ne **circule** pas : ce qu'on fait dans une ville ne se sait pas dans la ville voisine, sauf par le deuil ajouté le 2026-09-07. Une rumeur qui se propage de ville en ville, à la vitesse des caravanes et des voyageurs, ferait émerger la réputation régionale, le bandit connu, le héros attendu — et donnerait un rôle aux routes commerciales autrement que comme décor.
>
> **5. Le temps long : l'usure, la ruine, la repousse.** Rien ne vieillit. Un bâtiment abandonné reste neuf, une route non empruntée ne disparaît pas, une forêt coupée ne repousse pas (sauf sur une cellule Ressources), un cadavre ne se décompose pas. Un champ d'**entretien** par tuile bâtie — qui baisse sans présence et fait crouler ce qu'on délaisse — ferait émerger les ruines, la reconquête par la nature, et donnerait un sens à revenir.
>
> **6. Le besoin, au-delà de la faim.** Un PNJ a faim et une humeur. Il n'a ni **soif**, ni **sommeil** contraignant, ni **chaleur** à chercher (elle arrive avec le champ), ni **peur** persistante. Quatre besoins qui se disputent le même agenda font des comportements qu'on n'a pas écrits ; un seul besoin fait une routine.
>
> **Ce que je NE ferais pas**, et pourquoi : pas de physique continue (la grille est un champ de hauteurs, pas un voxel — et le pivot l'a tranché) ; pas de chimie générale (combiner deux matières pour en faire une troisième relève des recettes, pas d'un champ) ; pas d'économie à agents (les prix suivent le stock depuis le 2026-09-07, et une bourse à agents coûterait cent fois ce qu'elle rendrait à l'écran). **Et, depuis le 2026-09-08, deux refus de plus** : pas de **planificateur d'actions (GOAP)** — l'IA de Sensen est déjà une utility AI pondérée (`data/ai_profiles/`), et un planificateur serait un système entier à côté d'elle, pour des séquences dont un jeu à tuiles vues de dessus n'a pas besoin ; ce qui lui manque, ce sont **les jauges** et **le champ de danger**, tous deux déjà décidés. Et pas de **simulateur de figures historiques** (un mode « Legends ») — c'est le *journal* d'un champ, pas un champ ; il aurait un producteur unique et un écran unique, et ne partagerait aucune donnée avec le combat, l'IA, l'économie ou le terrain. La **rumeur** qui circule est le champ. Voir [[Émergence — le monde vivant]].
>
> **Confirmé par le designer le 2026-09-08, 7 h** : il a renvoyé la liste des six mot pour mot, dans son ordre à lui — **bruit et odeur d'abord** (« et c'est le plus criant »), puis le champ de danger, la rumeur, le temps long, les besoins, et **l'eau qui pèse en dernier**. C'est le classement qui fait foi ; la numérotation ci-dessus reste celle de la rédaction.
>
> **À juger, et ce n'est pas à moi** : l'ordre de ces six-là, et surtout s'il faut les faire **avant** de finir le jeu (pause, écran de mort, touches reconfigurables, sauvegarde fiable). Un monde profond dans un jeu qu'on ne peut pas mettre en pause reste une démo.

> [!decision] Décidé le 2026-09-08, 6 h 30 — les 236 modules meurent, la grammaire reste, et les champs passent devant (designer : « on va supprimer tous les modules de capacités, bien déterminer et coder tous les noyaux de systèmes émergents et ensuite refaire les modules »)
> **Le diagnostic est juste, et le balayage l'avait chiffré sans que j'en tire la conclusion** : 23 sorts sur 86 ne produisent rien d'observable, 41 modules portent une `classe_signature` que personne ne lit, un sort au contact ne coûte ni tick ni mana. Ce n'est pas de la malchance — c'est ce qui arrive quand **236 contenus possèdent chacun leur propre règle**. Un noyau le montre à nu : `effets: ["degats", "tempo"]` et `effet: {tempo: 9}`, c'est-à-dire des **noms d'effets résolus par des branches de code**. Avec les champs, un noyau de feu dira `{chaleur: 400}` et le reste suivra seul : l'herbe s'enflamme, la neige fond, le grisou explose, la bête panique — sans qu'aucune de ces quatre lignes soit écrite.
>
> **Ce qui meurt** : les **236 contenus** de `data/modules/**` et les branches d'effet écrites en dur dans `simulation.gd`, plus les listes de modules des 19 fiches de classe.
> **Ce qui survit** : la **grammaire** — portée + forme + noyau + modificateur —, la grille de composition, les coûts (ticks, mana, vigueur, sang-froid), les emplacements, l'aperçu du sort, les parchemins et les grimoires. C'est le vocabulaire que l'interface, le butin et les classes parlent déjà ; ce qu'on jette, ce sont les mots, pas la langue.
>
> **L'ordre, et pourquoi il compte** : **les champs d'abord, la suppression ensuite.** 13 fichiers de tests sur 215 tests enregistrés dépendent des modules — supprimer d'abord, c'est faire la partie la plus risquée du chantier (toucher le cœur de la simulation) **avec le filet baissé**. On code donc la chaleur et le support pendant que la suite est verte, on les prouve, et l'on ne supprime qu'au moment de réécrire.
> **Le risque assumé de cet ordre** : concevoir les champs en regardant ce que les modules font aujourd'hui. La parade est la règle du haut de cette note — **un champ remplace, il ne s'ajoute pas** : si la chaleur n'absorbe pas le feu, la lave, le gaz, la neige et la météo, elle est ratée, quoi qu'en disent les modules.
>
> **Ce que la suppression n'excuse pas** : la sauvegarde ment toujours (recharger dans une mine régénère un donjon à salles, un donjon de corruption vaincu revient, sauvegarder en combat dissout le combat). Six défauts vérifiés à la main, qui restent en tête de file après les champs.


> [!success] Codé le 2026-09-08 — le champ de chaleur, et les deux règles qu'il remplace — `data/thermique.json`, `SimTerrain._tiquer_chaleur`
> **Le premier champ partagé, et il obéit à la règle du haut de cette note : il REMPLACE.** La chaleur est un `PackedFloat32Array` en **degrés** sur la couche 0 de la fenêtre, **jamais sauvegardé** — il se reconstruit de ses sources comme la carte de lumière, et il se vide quand la fenêtre glisse (ses index sont ceux de la grille d'avant).
>
> **Ce qui a disparu du code**, et c'est le point :
> - **Le jet de propagation du feu.** `_tiquer_feux` tirait un dé par voisine, `flammabilite/100 × propagation × vent`. Supprimé, avec sa clé `feu.propagation` dans `combat_rules.json`. Le feu ne fait plus que **chauffer sa tuile** (1 100 °C, la température réelle du cœur d'une flamme de bois).
> - **L'ignition directe par la lave.** `_tiquer_lave` appelait `_enflammer` sur chaque voisine sèche. Supprimé. La coulée **chauffe** (1150 °C).
> Une tuile s'enflamme désormais quand **sa propre chaleur atteint le seuil de sa matière**, interpolé sur sa flammabilité entre 110 °C (flammabilité 100) et 400 °C (flammabilité 0). Un pin (70) prend à **197 °C**, une culture (60) à 226, une plante sauvage (50) à 255 ; un meuble (40) demande 284 °C et une matière peu inflammable (20) 342 — ceux-là veulent de la lave ou un brasier, pas un feu de camp. **Une seule règle d'ignition là où il y en avait deux**, et elle sort des stats du matériau.
>
> **L'incrémental, dès le premier jour** — c'était le deuxième piège écrit plus haut. `chaleur_active` ne contient que les tuiles qui s'écartent de l'ambiante de plus de 1,5 °C, exactement comme `eau_active` ; le pas ne balaie que celles-là et leurs voisines, jamais la fenêtre. Quand rien ne brûle, **le pas coûte le parcours de deux dictionnaires vides et rend la main** : le champ EST l'ambiante. Un garde-fou (`actives_max`) arrête l'expansion si le front dépasse 4 096 tuiles.
>
> **Le déterminisme** — le premier piège. Les index à traiter sont **triés** avant diffusion, et le pas est en **double tampon** (on lit l'ancien, on écrit le neuf) : deux exécutions donnent le même champ au flottant près. Plus aucun `RandomNumberGenerator` dans la propagation du feu — le test qui forçait `propagation = 1,5` pour être déterministe n'a plus rien à forcer, il regarde la physique. **Le calage s'est fait SUR LA MESURE, pas sur un modèle** : le premier jeu de nombres a échoué d'un degré (le voisin montait à 214 °C pour un seuil à 215). Le modèle Python que j'avais écrit avant de coder était 30 % trop chaud. Le test dit maintenant à quelle température le voisin a pris.
>
> **Ce que le champ apporte en plus, sans une ligne de règle** : une pièce fermée garde sa chaleur (l'**isolation** du matériau freine l'échange — une paroi isolante retient, un métal donne), un corps souffre de l'air lui-même au-delà de 70 °C ou sous −12 °C (le feu et la lave gardent leur brûlure **au contact** : pas de double comptage), et le vent n'est pas perdu — il **attise la source** au lieu de doubler un tirage.
>
> **La promesse est tenue depuis le 2026-09-08 au soir — sur une question du designer** (« est-ce qu'on a l'inertie ? c'est prévu ? »). Elle ne l'était pas : le callout annonçait une diffusion pondérée par `isolation` **et** `densite`, et le champ ne lisait que la première. Pire, je l'avais relevé le matin même sans le mettre en file — une promesse non tenue **et** non listée finit oubliée.
> **Ce qui est codé** : le facteur d'inertie vaut `2 × inertie_ref / (inertie_ref + densite)`, donc **1 pile à la densité de référence** — le calage du matin reste intact — et la matière se différencie autour : balsa ×1,78, pin ×1,33, fer ×1,00, granit ×0,67, plomb ×0,62. Une matière dense met du temps à changer de température, une matière légère suit tout de suite. **Ce que ça donne** : un mur de pierre se réchauffe lentement et garde sa chaleur longtemps, une cloison de bois léger suit la pièce — la cave reste fraîche l'été, la forge devient invivable. Le test du feu reste vert, le voisin s'enflammant à 221 °C.
> **Ce qui manquait encore à la matière** : `fusion`, sans quoi la chaleur ne savait que **brûler**. **Écrite le 2026-09-09** — 247 points de fusion en degrés réels, et `SimTerrain._fondre` qui les lit : le gypse rend du plâtre, le calcaire de la chaux, la malachite son cuivre. Voir [[Matériaux — 13 stats]].
>
> **Ce que ce champ n'absorbe PAS encore**, et il faut le dire pour ne pas mentir : la neige et le gel restent des **drapeaux de grille** (`grille.neige`, `grille.gel`) posés par la météo, pas des lectures du champ ; la température ressentie de la météo reste sa propre fonction ; le gaz inflammable garde sa règle d'allumage. **La stat `fusion` existe depuis le 2026-09-09 et le champ sait fondre** — mais ces trois-là ne tomberont que le jour où la neige et le gel seront des **tuiles** plutôt que deux booléens de fenêtre. La matière était le premier verrou ; ce n'était pas le seul.


> [!decision] Décidé le 2026-09-08, 13 h — un module de sort est une **modulation d'une règle du monde**, jamais un effet à lui (designer : « les modules de sort vont être totalement refaits de 0, ce serait des modulations des règles du monde. Donc oui on a besoin de l'inertie — par exemple un sort qui jette un rocher droit devant »)
> **C'est la phrase qui manquait à tout ce qui précède.** La décision du matin disait *ce qui meurt* (les 236 contenus) et *ce qui survit* (la grammaire). Celle-ci dit **ce que devient un module** : il ne produit plus d'effet, il **tourne un bouton d'une règle qui existe déjà**. Un noyau de feu ne « fait pas 3d6 de feu » — il **verse des degrés** dans le champ de chaleur, et l'herbe s'enflamme, la neige fond, le grisou explose, la bête panique, sans qu'aucune de ces lignes soit écrite. Un noyau de projection ne « pousse pas de 3 cases » — il **lance un corps à une vitesse**, et le monde décide du reste.
>
> **Ce que ça retourne dans l'ordre du chantier, et c'est important** : la réécriture des contenus ne peut pas précéder les règles qu'ils modulent. **On ne module que ce qui existe.** Chaque champ manquant est donc un module qu'on ne pourra pas écrire — ce qui confirme l'ordre du designer (« les champs d'abord »), mais en durcit la raison : ce n'est plus seulement une question de filet de tests, c'est que **le vocabulaire des sorts est fait de règles du monde**.
>
> **L'inertie devient obligatoire, et ce n'est pas celle qu'on venait de coder.** L'inertie *thermique* (la masse qui met du temps à changer de température) a été codée le jour même. Celle qu'appelle « un sort qui jette un rocher droit devant » est **l'inertie mécanique** : un corps en mouvement a une **masse** et une **quantité de mouvement**, et il la transmet.
> **Ce qui existe aujourd'hui, et qui ne suffit pas** : un projectile est une **ligne de Bresenham résolue d'un coup** ([[Décision — Projectiles]], 2026-08-26) — la trajectoire est tracée, la cible est touchée, fin. Rien ne **voyage**, rien n'a de masse, rien ne continue.
> **Ce qu'il faut** : un corps lancé qui traverse les tuiles au fil des ticks, avec `masse × vitesse` comme seule donnée partagée. Ce que plusieurs systèmes en liraient : les **dégâts** (un rocher lent qui pèse fait autre chose qu'une flèche rapide qui ne pèse rien), le **recul** (le léger part, le lourd encaisse), la **destruction du terrain** (un rocher casse un mur, une flèche s'y plante), le **champ de bruit** (un impact s'entend), le **support** (ce qui vole retombe), et la **grammaire des sorts** (« lancer » devient un noyau, plus un effet). Et la donnée d'entrée existe déjà : `Regles` calcule le **poids** d'un objet à partir de la `densite` de sa matière et de son volume.
>
> **Trois sources, une seule règle** (précisé par le designer le 2026-09-08 : « l'inertie c'est aussi pouvoir monter à l'étage et faire tomber un rocher de l'étage sur un ennemi en dessous pour l'écraser, écraser quelqu'un avec un camion »). Ce n'est pas trois mécaniques, c'est **la même donnée avec trois origines** : `masse × vitesse`, qu'elle vienne d'un **bras** (le rocher lancé), de la **hauteur** (le rocher lâché d'un étage) ou d'un **moteur** (la calèche, le train). Une masse en mouvement transmet son énergie à ce qu'elle touche — un point.
>
> **Ce qui existe déjà, et c'est plus qu'on ne croit** :
> - **La chute blesse** — `Simulation` applique `Grille.degats_chute`, et le **sol qui reçoit amortit** selon son `elasticite` (tomber sur de la tourbe n'est pas tomber sur du granit).
> - **Les couches Z, les escaliers et les étages** sont codés depuis le 2026-09-06.
> - **Les véhicules existent** : `creatures/vehicule/caleche.json` et `train.json`, avec leur propre IA d'itinéraire.
> - **Le poids d'un objet** est déjà calculé par `Regles` depuis la `densite` de sa matière et son volume.
>
> **Ce qui manque exactement, et c'est peu de choses pour beaucoup d'effet** :
> - **`degats_chute` ne connaît que la HAUTEUR** : `(niveaux − franchise) × dégâts_par_niveau`. Un caillou et un bloc de granit font le même mal. **La masse n'entre nulle part.**
> - **Une chute ne blesse QUE celui qui tombe.** Rien ne regarde ce qu'il y a **en dessous** : lâcher un rocher d'un étage sur un ennemi ne lui fait rien du tout, et c'est précisément l'exemple du designer.
> - **Un véhicule ne heurte personne** : son IA suit un itinéraire, aucune règle ne dit ce qui arrive à qui se trouve sur son passage.
>
> **Ce que la règle unique absorberait** (et c'est la condition, comme toujours) : les dégâts de chute deviennent *la masse qui rencontre le sol*, le projectile cesse d'être une ligne résolue d'un coup, l'éboulement du champ de support devient *une masse qui tombe* au lieu d'une règle à part, et le véhicule reçoit sa collision **sans qu'on l'écrive**. Quatre règles, une donnée.
>
> **Ce qui n'est PAS à moi et doit être tranché avant de coder** :
> - **Le grain de la vitesse.** Une grille à ticks n'a pas de vélocité continue : un corps avance de N tuiles par tick, ou d'une tuile toutes les N ticks. Combien de crans veut-on entre « la flèche » et « le rocher » ?
> - **Jusqu'où va le recul.** Un corps poussé pousse-t-il à son tour ce qu'il heurte (chaîne de collisions), ou s'arrête-t-il au premier obstacle ?
> - **Est-ce que le joueur lui-même est un corps ?** Une charge a-t-elle un élan qui l'emporte au-delà de sa cible, un personnage lourd met-il un tick de plus à changer de direction ? C'est la question que j'avais posée et qui reste ouverte : **l'inertie du déplacement** est un autre chantier que celle des projectiles, et beaucoup plus intrusif.


> [!success] Codé le 2026-09-08 — le champ de danger, et les deux sources que l'IA ne voyait pas — `thermique.json → danger`, `SimTerrain._tiquer_danger`
> **Le troisième champ partagé**, après la lumière et la chaleur. Et le plus petit des trois, parce que la structure existait déjà — mal.
>
> **Ce qui existait** : `grille.dangers`, un dictionnaire **binaire** (idx → true), posé par **trois choses seulement** — le feu, la lave, le glyphe d'un Graveur. Lu par le chemin (le noyau C++ refuse toute tuile non nulle) et par deux endroits de l'IA.
> **Ce qu'il ratait, et c'était l'essentiel** : **les nuages de gaz n'y étaient pas.** Une poche percée pose des zones dans `sim.zones` et n'appelait **jamais** `poser_danger` — l'IA marchait dans le poison, dans le grisou, dans le nuage qui asphyxie. Le balayage du 2026-09-08 l'avait dit en une phrase (« c'est déjà vrai des gaz posés hier ») ; c'était exact. Et **la chaleur** non plus : une tuile à 300 °C, brûlante sans flamme, était invisible.
>
> **Ce que le champ fait** : il **gradue** — 1 à 100 au lieu d'un booléen — et il **absorbe** les deux sources manquantes. Le grade se **déduit des données**, sans rien inventer : un gaz qui blesse ou explose vaut 100, un gaz qui pose un statut vaut 60, un gaz qui ne fait qu'étouffer les feux vaut 30 ; la chaleur s'interpole entre le seuil où elle brûle (70 °C) et celui qui vaut le maximum.
> **Et voici le point de la règle** : le code de décision de l'IA **n'a pas changé d'une ligne**. « On ne reste pas dans le danger » couvre désormais le gaz et la chaleur **sans une branche de plus**. Un champ remplace ; il ne s'ajoute pas.
>
> **Rétrocompatible par construction** : le noyau C++ refuse toute valeur non nulle du miroir `danger_a`, donc graduer ne change rien pour le chemin ; et `poser_danger(i)` sans intensité vaut 100, donc les trois appelants d'avant gardent exactement leur sens.
> **Une précaution structurelle** : le champ ne retire **que ses propres tuiles**. Le feu, la lave et les glyphes gardent la leur — sinon dissiper un nuage effacerait le danger d'un feu posé au même endroit. `test_champ_de_danger` le vérifie explicitement, en plus des trois autres points.
>
> **Ce qu'il reste à ce champ** : l'IA se contente encore de **refuser** une tuile dangereuse ; elle ne **pèse** pas encore le grade pour choisir entre deux chemins imparfaits. C'est ce que la graduation rend possible, et ce n'est pas fait.

> [!success] Codé le 2026-09-09 — **le danger se pèse** (ce qui restait de l'ordre de travail 24) — `combat_rules.deplacement`, `grille.gd`, `sensen_grille.cpp`
> Le champ graduait depuis la veille ; **personne ne lisait le grade.** Les deux chercheurs de chemin — le GDScript et sa transcription C++ — refusaient toute valeur non nulle, si bien qu'une tuile graduée **1 barrait exactement comme la lave**. La graduation était donc, pour le chemin, une écriture sans lecture : le travail de la veille avait produit un nombre juste et un comportement inchangé. *C'est le genre de défaut qu'aucun test ne signale, parce que rien n'est faux — c'est seulement inutile.*
>
> **Deux nombres en données, et la raison de chacun.**
> · `danger_refus` (100) — à ce grade et au-delà, la tuile reste **infranchissable**. Sans ce seuil, un coût, si grand soit-il, finit toujours par être payé : un être enfermé derrière un mur de flammes traverserait le feu plutôt que d'attendre. **Ce qui tue à coup sûr ne se négocie pas.**
> · `danger_cout_par_grade` (100 ticks) — ce qu'un point de grade ajoute au pas.
>
> **Les deux nombres sont calibrés sur ce que le champ émet vraiment**, et c'est en allant le lire que le premier réglage est tombé. J'avais posé le seuil à 50 : or un **gaz à statut vaut 60** — il serait resté refusé tout comme avant, et le grade aurait été lu sans rien changer pour lui. À 100, seuls sont refusés le feu, la lave, un glyphe armé et un gaz qui blesse ou explose ; le reste se pèse. Un pas coûte 300 ticks, donc un gaz inerte (30) demande **dix pas de détour**, un gaz à statut (60) **vingt**, un sol à 350 °C (79) **vingt-six** — et chacun se traverse quand même s'il n'y a pas d'autre chemin. La tuile d'**arrivée** garde son passe-droit : on vise volontairement une tuile dangereuse, c'est ainsi qu'on entre dans un feu pour l'éteindre ou qu'on frappe ce qui s'y tient.
>
> **Un défaut découvert en chemin, et il n'existait qu'à cause de ce changement.** Le garde-fou des miroirs — celui qui recompile `danger_a` quand un dictionnaire a été écrit sans passer par les méthodes — écrivait **1** dans chaque case, pas le grade. Tant que le chemin ne faisait que refuser, `1` et `47` disaient la même chose et l'aplatissement était invisible ; du jour où le grade se paie, ce rattrapage rendait **un feu à 100 presque gratuit**. Un raccourci qui dormait sans nuire est devenu faux le jour où la donnée a commencé à compter.
>
> **Ce qu'un test d'égalité GDScript/C++ ne prouve pas.** Si les deux implémentations refusaient tout, elles seraient parfaitement d'accord — et le test passerait. `test_danger_pese` demande donc un **comportement**, sur un terrain plat bâti pour la question : une barrière de danger en travers du passage, de grade 20 partout sauf une rangée à 1. Le chemin la franchit, et **il la franchit par la rangée à 1** — le détour ne lui coûte aucun pas, les diagonales avançant aussi en x. La même barrière à 100 : plus de chemin du tout. À 20 partout : il paie et traverse. Et à chaque fois le noyau C++ rend la même chose, tuile pour tuile.
>
> **Et un second défaut, du même genre, dans la règle qui fait fuir.** « On ne reste pas dans le feu » exigeait, pour le pas de sortie, une tuile **sans aucun danger**. Cela ne coûtait rien tant que le danger était binaire — hors du feu, c'était forcément zéro. Depuis qu'il se gradue, un être au milieu d'un **large nuage** n'a plus une seule sortie propre à portée : il ne trouvait aucune case et **restait à mourir sur place**. Il va maintenant vers la tuile **la moins dangereuse** de ses huit voisines, ce qui est le même pas qu'avant dès qu'il y a du sol sain à côté, et un pas vers l'air libre quand il n'y en a pas. *Graduer une donnée ne casse pas ses lecteurs ; cela révèle ceux qui la lisaient comme un oui-ou-non.*
>
> **Ce qui reste** : `atteignables` — la portée de déplacement — ignore toujours le danger, comme avant ce changement. C'est cohérent (elle mesure ce qu'on peut atteindre, pas la route qu'on choisit), mais un jour il faudra dire si une zone n'est atteignable qu'*au prix* du danger.

> [!success] Codé le 2026-09-09 — **le champ de support** : une galerie trop large s'effondre (ordre de travail 25) — `support.json`, `SimTerrain._tiquer_support`, `portance`
> **Le quatrième champ partagé**, et celui qui fait exister la mine. [[Mine sous une cellule]] disait « on n'y risque que **l'effondrement**, l'endurance et la faim — c'est ce qui la sépare le plus nettement du gouffre » ; on n'y risquait **rien**.
>
> **Le modèle est celui que cette note avait tranché**, celui de Dwarf Fortress, adapté à une grille par étage : une tuile **ouverte** est couverte d'un plafond que la roche alentour tient. `portee_base + portee_par_portance × portance` donne la distance maximale entre une tuile ouverte et son soutien le plus proche ; au-delà, le plafond tombe. **Aucune portée n'est écrite matière par matière** — le granit (85) tient six tuiles, la terre (10) une et demie, le sable (2) rien. Une galerie de granit s'ouvre donc sur douze tuiles de large ; la même dans la terre s'effondre à trois. *C'est la stat qui fait le comportement, et c'est tout l'intérêt d'une stat.*
>
> **`portance` était la deuxième des cinq colonnes manquantes**, et elle est écrite : 247 valeurs, 0 à 100. Contrairement à `fusion`, ce n'est pas une grandeur du monde réel avec son unité — la résistance en flexion se mesure en mégapascals et un joueur n'en a que faire. C'est donc la seconde moitié de la règle du 2026-09-02 qui s'applique : **respecter l'ordre du monde réel, pas ses unités**. Deux familles où `durete` aurait trompé, et c'est ce qui justifie une stat séparée : les **gemmes** sont dures et **cassantes** (un diamant raye tout et se fend d'un coup de marteau) ; le **plomb** et l'**or** sont des métaux **mous** — le plomb porte moins qu'un chêne.
>
> **Étayer est devenu un geste, sans une ligne d'interface neuve.** L'`etai` est un **meuble** : il passe par le chemin qui existe déjà — un objet dans le sac, `_poser`, `poser_meuble` —, il se fabrique à l'établi avec deux planches, il **ne bloque pas le passage** (on marche entre ses montants) et il **porte**. C'est la définition la plus courte possible du geste que la note demandait.
>
> **Le patron est celui de la CHALEUR, pas celui de la lumière** — la note l'exigeait en toutes lettres. Le champ ne balaie jamais la fenêtre : un coup de pioche inscrit les tuiles à portée dans une file, et le pas ne regarde que celles-là. Un éboulement inscrit ses voisines à son tour, puisque ce qui vient de se boucher **soutient** désormais.
>
> **Deux décisions de conception qui ne se voient qu'en écrivant le code** :
> · **L'éboulement pose un mur DESTRUCTIBLE**, du matériau de l'étage. Une galerie bouchée se rouvre à la pioche — un éboulement coûte du temps et du sang, il ne supprime pas un chemin pour toujours.
> · **Un occupant ne peut pas se retrouver dans la pierre.** On le blesse, puis on le pousse vers une tuile ouverte voisine. S'il n'y en a aucune, **la tuile reste ouverte et le plafond grogne** : il tombera au pas suivant. C'est plus juste qu'un mur posé sur quelqu'un, et ça laisse une seconde à celui qui court.
>
> **La preuve est un contrôle négatif** (`test_support`), comme pour la fusion : voir une galerie s'effondrer ne prouverait rien — une règle « toute galerie de rayon 3 tombe » le ferait aussi. Le test creuse **deux fois la même galerie**, au même endroit, à la même taille, et ne change **que la matière de l'étage** : le granit tient, la terre tombe. Puis un étai au milieu, et elle tient.
>
> **LES DEUX MANQUES ONT ÉTÉ COMBLÉS LE JOUR MÊME** (designer : « fais le nécessaire alors »), et le second était dans le modèle d'origine.
>
> **1. Le champ ne joue plus « en mine ».** Le verrou est remplacé par une **question physique** : *y a-t-il seulement quelque chose au-dessus ?* Sous terre — une mine, un donjon creusé — toute tuile ouverte a de la pierre au-dessus d'elle. À la couche d'un étage, la tuile où l'on marche **est** un plancher. **À ciel ouvert, il n'y a rien à faire tomber** : ce n'est pas une limite du champ, c'est le ciel. Un interrupteur est devenu une propriété du lieu.
>
> **2. La troisième dimension, et la propagation.** Un plancher d'étage tient de deux façons, et il suffit d'une : **par en dessous** (du plein juste sous lui) ou **par le côté** (un mur de sa propre couche, à portée de la matière — la même règle que le plafond de roche). Sinon il tombe : la tuile devient de l'air, ce qui s'y tenait **chute d'un niveau** avec les dégâts de chute qui existaient déjà, et le plancher du dessus est remis en question.
>
> **Il a fallu une règle de plus, et c'est elle qui rend la propagation vraie** : le **mur** d'étage. Un plancher tenu par des murs qui ne reposent sur rien serait une maison suspendue en l'air. Et cette règle **ne peut pas être locale** — c'est le piège de ce genre de champ : un mur tenu par son voisin, lui-même tenu par le premier, se porterait mutuellement à jamais. Ce qui compte est donc le **groupe** : un ensemble de tuiles pleines d'une même couche tient si **l'une d'elles au moins** repose sur du plein juste dessous. C'est un ancrage, pas un voisinage. Le parcours est borné par `composante_max` — une falaise n'a pas à être parcourue pour qu'on sache qu'elle tient, et sans cette borne un champ incrémental redeviendrait un balayage.
>
> **Résultat, que personne n'a écrit** : abattre les murs du rez-de-chaussée fait tomber l'étage — **et celui du dessus avec**. `test_support_etages` bâtit une maison de deux niveaux, vérifie d'abord qu'elle **tient** (le contrôle négatif est la même géométrie), puis abat le bas et compte : les deux planchers cèdent, et il ne reste pas un mur du second en l'air.
>
> **Un défaut trouvé en sortant de la mine, et il n'existait que là.** « Ce qui soutient » se lisait *bloque le passage* — les deux se confondent sous terre, mais à la couche d'un étage ils divergent gravement : l'**air** hors des bâtiments (`vide`) bloque le passage — on n'y marche pas — sans rien porter du tout. Un plancher se serait cru tenu par le vide. Ce qui porte, c'est ce qui est **plein**.
> **Et un piège de test dont la leçon vaut d'être gardée** : la première version a rougi pour une raison juste mais étrangère à ce qu'elle mesurait — le terrain du camp avait posé un arbre sous le plancher, qui le portait par en dessous. La maison abattue restait debout **à bon droit**. Quand une géométrie est le sujet du test, elle se pose entièrement à la main.
>
> **CE QUI A ÉTÉ CREUSÉ, PAS CE QUI A ÉTÉ BÂTI — et c'est un test qui me l'a appris.** En sortant de la mine, la règle de portée s'est mise à juger les salles que le **générateur** avait taillées : un coup de pioche dans une ruine faisait tomber le plafond d'un hall large de dix tuiles, creusé bien avant qu'on arrive. `test_recolte` a rougi, et il avait raison — le champ était en train de condamner tout le contenu existant du jeu.
> La règle qui manquait tient en une phrase : **une voûte qui tient depuis des siècles a été bâtie pour tenir ; la galerie que tu ouvres est ton affaire.** Le champ ne juge donc que les tuiles marquées `modifies` — « changée depuis la construction du lieu » —, ce que le jeu tenait déjà et persiste déjà. Le danger reste exactement là où la note le voulait : *creuser une galerie trop large devient dangereux*.
> *La leçon d'outillage est ailleurs, et elle est plus dure* : j'ai d'abord lu cet échec dans un `build/tests.txt` que **trois exécutions de Godot se partageaient**, faute d'avoir respecté la règle du projet — une instance à la fois. J'ai douté d'un résultat vrai. `lancer_tests.py` écrit maintenant un fichier par exécution et **refuse de démarrer si un Godot tourne déjà**. Un outil de vérification qui mélange deux résultats est pire qu'absent : il fait chercher un défaut qui n'existe pas.
>
> **Ce qui reste** : la démolition par les PNJ et les royaumes ne nourrit pas encore le champ — seuls le coup de pioche et l'explosion le font.

> [!success] Codé le 2026-09-09 — **le champ sonore**, celui qui manquait le plus (ordre de travail 26) — `sonore.json`, `SimTerrain.sonner`, `absorption`
> **Le premier des six dans le classement du designer**, et le dernier à avoir été débloqué : il attendait un **nom**. `bruit` était pris par le bruit de Perlin dans toute la génération ; le designer a tranché `sonore` le 2026-09-09. Le mot était libre — deux occurrences dans tout le code, et ce sont deux commentaires sur « l'onde sonore » du barde, donc une future *source* du champ, pas une collision. `son` a été écarté sur mesure : libre comme identifiant, mais présent **367 fois en prose**, puisque c'est le possessif français. *Un mot qu'on ne peut pas chercher est un mot pris.*
>
> **LE SON CONTOURNE, ET C'EST TOUT LE MODÈLE.** Il ne se propage pas en ligne droite comme la vue : il suit le **plus court chemin sonore** depuis sa source. Un cri passe donc par la porte ouverte plutôt qu'à travers le mur, deux pièces mitoyennes s'entendent mal, et un couloir en L porte la voix. C'est ce qui sépare ce champ de la ligne de vue — et c'est exactement ce que la note demandait : **« se cacher devient un lieu, pas un nombre »**.
> Entrer dans une tuile coûte `pas_cout` de volume, plus l'`absorption` de la matière quand la tuile est pleine. **Aucune matière n'est nommée dans le code** : c'est la stat qui décide.
>
> **`absorption` est la troisième des cinq colonnes** — 247 valeurs de 0 à 100, dans l'ordre du monde réel. Et **c'est la stat qui diverge le plus des deux autres**, ce qui la justifie mieux que n'importe quel argument : le **liège** est mou, ne porte rien, et étouffe mieux que le granit ; l'**acier** est dur, porte tout, et transmet le son comme un fil ; la **neige** (95) rend un monde silencieux, ce que chacun a entendu une fois. Le **plomb** est la grande exception métallique — c'est l'écran acoustique du monde réel. `durete` et `portance` n'auraient jamais dit cela.
>
> **Ce que l'IA en fait, et le code de décision n'a pas gonflé** : un être sans cible visible qui entend quelque chose chez lui **remonte la pente du champ** vers le plus fort. Il n'a pas besoin de savoir ce qu'il a entendu ni d'où ça vient — le champ le sait pour lui, et le son a contourné les murs tout seul. C'est « la meute qui suit une piste au lieu de voir à travers les murs », en une branche avant l'errance.
> **La Discrétion cesse d'être un simple facteur sur une portée** : elle retranche au volume qu'on **émet**. Un rôdeur discret creuse moins fort.
>
> **Les sources sont celles qui existaient déjà** — un champ remplace, il ne s'ajoute pas : le coup de **pioche**, l'**éboulement** (la plus forte du jeu, et elle vient du champ de support codé le matin même). Le coup, la mort et la porte ont leur volume en données et attendent d'être branchés.
>
> **Le contrôle négatif est particulièrement net ici** (`test_sonore`) : on écoute **à la même distance de la même source**, des deux côtés d'un couloir de même géométrie, et l'on ne change **que la matière du mur**. Derrière deux tuiles de granit : rien. Derrière deux tuiles de verre : on entend. Puis on perce le granit, et le son passe par l'ouverture — il contourne.
> *Une leçon de test au passage* : avec un mur d'**une** tuile, le granit laissait passer exactement 5,0, c'est-à-dire **pile** le seuil d'audibilité. La physique était juste, le test tenait en équilibre sur un fil — et un fil se rompt au premier réglage. Un mur se teste épais.
>
> **Ce qui reste** : le combat, la mort et les portes ne sonnent pas encore (leur volume est écrit, pas branché) ; le champ ne connaît pas les couches Z ; et l'**odeur**, l'autre moitié du point 1, n'existe pas.

> [!success] Codé le 2026-09-09 — **le champ d'odeur**, l'autre moitié du point 1 — `odeur.json`, `SimTerrain.tracer`
> **Il est l'exact contraire du champ sonore, et c'est ce qui le rend utile.** Le son est instantané et s'efface vite : il dit **où quelqu'un est**, maintenant. L'odeur est lente et elle traîne : elle dit **où quelqu'un est passé**, et depuis combien de temps. L'un sert à surprendre, l'autre à pister. Mesuré : `fondu` 0,03 contre 0,50 — une odeur survit douze pas de champ là où un bruit s'était éteint.
>
> **LA PISTE N'A BESOIN D'AUCUN HORODATAGE**, et c'est le point de conception qui fait tout marcher. Un être dépose une trace là où il passe, et le champ s'efface un peu à chaque pas : une piste laissée au fil du temps **décroît donc vers l'ancien**. Le dernier pas est le plus fort ; **remonter la pente mène au dépôt le plus frais**, c'est-à-dire là où l'être vient d'aller. La meute suit la piste jusqu'à celui qui l'a laissée, et rien ne mémorise l'heure.
> La diffusion est **faible à dessein** : une piste est une ligne, pas un nuage. Ce qui s'étale, c'est une **dépouille**, qui sent tant qu'elle est là — son odeur est réémise, elle ne s'éteint pas d'un coup. C'est « le prédateur qu'attire une carcasse laissée là ».
> Et la **Discrétion** cesse une deuxième fois d'être un facteur sur une portée : un rôdeur discret laisse une piste **plus pâle** (18 contre 30), que la meute perd plus tôt.
>
> **LES ORGANES DE SENS SONT LE LECTEUR DE CES CHAMPS** *(designer, le même jour : « tout ce qui est nez yeux oreilles etc font partie des organes »).* Et cela tombe juste, parce que les trois champs qu'ils interrogent existent depuis ce jour-là : la **vue** lit la lumière, l'**ouïe** le champ sonore, l'**odorat** le champ d'odeur. Perdre l'organe, c'est perdre l'accès au champ.
> Chaque espèce a les siens, et ce sont **ceux du monde réel** : le serpent n'a **aucune oreille externe** et sent par son **organe de Jacobson** ; l'araignée a **huit yeux** et perçoit par ses **soies sensorielles** ; l'oiseau a des **narines** et des **conduits auditifs**, pas de pavillons.
> **La règle de prudence est explicite** : un sens n'est perdu que si le plan DÉCLARE des organes pour lui ET qu'ils sont TOUS tombés. Un œil crevé ne rend pas aveugle ; une gelée qui ne déclare aucun œil perçoit comme avant ; et le serpent, qui n'a pas d'oreille, n'est pas sourd pour autant — *la règle ne punit pas une anatomie d'être ce qu'elle est.*
>
> **Ce qui reste** : le combat, la mort et les portes ne sonnent pas encore ; les deux champs ignorent les couches Z ; et l'odeur **ne distingue pas ce qui sent** — un loup suit la piste d'un loup aussi bien que celle du joueur.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Matériaux — 13 stats]], [[Application des stats de matériau]], [[Grille continue]]
- **Alimente** : [[Mine sous une cellule]], [[Éclairage]], [[Météo]], [[IA des créatures]], [[Modules de la simulation et le C++]]
- **Voir aussi** : [[Eau et liquides]], [[Gaz dans le sol]], [[Destruction du terrain]], [[Réputation et relations]], [[Faim]]
