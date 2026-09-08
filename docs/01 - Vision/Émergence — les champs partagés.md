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
> **Ce que je NE ferais pas**, et pourquoi : pas de physique continue (la grille est un champ de hauteurs, pas un voxel — et le pivot l'a tranché) ; pas de chimie générale (combiner deux matières pour en faire une troisième relève des recettes, pas d'un champ) ; pas d'économie à agents (les prix suivent le stock depuis le 2026-09-07, et une bourse à agents coûterait cent fois ce qu'elle rendrait à l'écran). **Et, depuis le 2026-09-08, un quatrième refus** : pas de **simulateur de figures historiques** (un mode « Legends ») — c'est le *journal* d'un champ, pas un champ ; il aurait un producteur unique et un écran unique, et ne partagerait aucune donnée avec le combat, l'IA, l'économie ou le terrain. La **rumeur** qui circule est le champ. Voir [[Émergence — le monde vivant]].
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
> **Une promesse de cette note que le code ne tient pas encore** (relevé le 2026-09-08) : le callout du haut annonce une diffusion « pondérée par `isolation` (ce qui retient) et `densite` (ce qui met du temps à changer) ». **Le champ codé ne lit que `isolation`** (`sim_terrain.gd`, la ligne du coefficient) : l'inertie thermique de la matière dense n'existe pas. À faire avec la stat `fusion`, quand la chaleur reprendra du service — ou à retirer de la promesse.
>
> **Ce que ce champ n'absorbe PAS encore**, et il faut le dire pour ne pas mentir : la neige et le gel restent des **drapeaux de grille** (`grille.neige`, `grille.gel`) posés par la météo, pas des lectures du champ ; la température ressentie de la météo reste sa propre fonction ; le gaz inflammable garde sa règle d'allumage. Ces trois-là tomberont quand la matière saura **fondre** — c'est-à-dire avec la stat `fusion` de [[Matériaux — 13 stats]], qui n'existe pas encore.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Matériaux — 13 stats]], [[Application des stats de matériau]], [[Grille continue]]
- **Alimente** : [[Mine sous une cellule]], [[Éclairage]], [[Météo]], [[IA des créatures]], [[Modules de la simulation et le C++]]
- **Voir aussi** : [[Eau et liquides]], [[Gaz dans le sol]], [[Destruction du terrain]], [[Réputation et relations]], [[Faim]]
