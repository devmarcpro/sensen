---
aliases: ["E.14", "Annexe E.14", "Budgets de performance", "Cibles de performance"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les chiffres voxel (meshing < 4 ms/chunk, 8 Ko/chunk 16³) sont retirés — archivés dans le GDD source. Les budgets de rendu tuiles + billboards proposés : [[Décision — Budgets et critères de performance tactiques]].

Les cibles chiffrées de performance.

**Budgets confirmés (indépendants du pivot) :**
- **Tick complet : < 8 ms** (marge sur les 100 ms du tick).
- **Entités actives simultanées par zone : ~64.**
- Rayon de chargement : **8 chunks** autour du joueur par défaut.

**Budgets du rendu tactique ([[Décision — Budgets et critères de performance tactiques]]) :** 60 fps à rayon 8 chunks de tuiles ; mutation de tuile < 1 ms de re-render local, jamais de frame > 16 ms ; 200 billboards paperdoll animés sans chute de frame ; chunk généré < 2 ms en thread ; étage de donjon < 100 ms ; mémoire chunk 32×32 ≈ 7 Ko.

Si un chemin chaud GDScript est trop lent : passer cette partie (et elle seule) en GDExtension/Rust — **décision au profilage, pas avant** ([[Optimisation — principes]]).

La stratégie d'optimisation complète, système par système, est consolidée en **Annexe G** ([[Optimisation — principes]] et suivantes), **qui fait autorité en cas de divergence**.

**Critères de validation par étape :** [[Ordre de vérification]].

> [!success] Codé le 2026-08-31 — le tick sous les 8 ms, mesuré
> `test_budgets` mesure le pas de simulation (< 8 ms), la génération d'étage, d'objet à affixes et le recalcul de stats. Les budgets de rendu se lisent avec `capture.tscn --disable-vsync` (moyenne et pire image imprimées).

> [!important] 2026-09-05, 21 h — « le jeu lag énormément en ville » (designer), mesuré et allégé
> Le designer propose de réécrire du code en C++ ; sa règle du dépôt dit « pas de GDExtension » ([[Contraintes permanentes]], `AGENT.md`) — c'est à lui de la lever, et avant cela il fallait savoir CE QUI coûte. Mesure : `capture.tscn -- --ville --frames 400` imprime la moyenne et le pire d'une image, et `main.chrono` (le client chronomètre chaque étape de l'image : le pas de simulation, les nœuds, le texte, la minimap, chaque dessin). Dans une cité de 247 habitants (graine 21) : **25,1 ms par image, pire 83 ms** — dont 3,9 ms à redessiner **tous** les paperdolls à chaque image, 3,2 ms de HUD redessiné à chaque image pour deux cents êtres, 4 ms de texte et de minimap vingt fois par seconde, et presque rien de simulation (le pas du monde : 0,01 ms). Après : le paperdoll ne se redessine que si sa signature change (orientation, action, équipement, apparence — relue une image sur quatre, en quinconce), le HUD ne dessine que les êtres à l'écran et une image sur deux, le texte et la minimap sept fois par seconde → **16,6 ms par image, pire 18 ms** sur la même cité. Le reste est le rendu de Godot lui-même (deux cent trente paperdolls dessinés en commandes de canvas, le terrain en polygones) : c'est le plancher en GDScript, et le vrai gain suivant est de dessiner le terrain par cellule (un nœud par cellule, redessiné seulement quand elle change) et les êtres lointains en un seul pictogramme. Consigné dans [[À juger — parcours de jeu]].
> Le second problème vu par le designer, « les PNJ se sentent obligés de bouger constamment » : deux causes — une partie commençait le Nouvel An (toute la ville convergeait vers la place, et deux cents habitants visaient des coins pris : ils piétinaient) ; une partie commence désormais le 3 du Rat (`calendrier.jour_depart`), et un PNJ à un pas de sa cible prise s'y tient (`_actions_candidates`, `_ia_pas_routine`).

> [!note] 2026-09-06, 0 h 30 — l'échelle de la simulation, mesurée (`sonde_echelle.tscn`)
> 197 êtres chargés : 1,2 ms par tick du monde ; 2 000 êtres (résidents clonés) : 4,8 ms, sous le budget d'une image (12 ms), après que la faim, la météo et la vision ont cessé de balayer toutes les entités pour trouver le joueur (`Simulation.joueurs()`). Le poste restant : la recherche de la prochaine entité due, un balayage par pas. Détail et suite dans [[Modules de la simulation et le C++]].

> [!decision] 2026-09-06, 1 h 45 — le terrain par morceaux (suite du lag en ville)
> La couche `Terrain` redessinait **toute** la zone autour du joueur (41 × 41 tuiles) dès qu'il s'éloignait du centre de la passe ou qu'il **découvrait une tuile** — en ville, chaque pas découvre : c'était la saccade en marchant. Désormais le terrain est un ensemble de **morceaux de 8 × 8 tuiles** (`TerrainMorceau`, un nœud chacun, `z_index` = colonne + ligne du morceau, ce qui garde l'ordre de profondeur isométrique : deux morceaux de même z ne se recouvrent jamais). Un morceau ne se redessine que si une de ses tuiles change (`tile_changed`, avec ses voisines de bord) ou se découvre (les tuiles du champ de vue du joueur, quand le compte de découvertes bouge) ; les morceaux naissent et meurent avec la distance au joueur (`RAYON_VUE`), une nouvelle grille les refait tous. Les végétaux (billboards) suivent leur morceau. Mesure attendue : `draw.terrain` en pic passe de la zone entière à un ou deux morceaux.
>
> **Mesuré à 2 h 30** (capture `--ville --frames 400`, même cité de 202 habitants, machine chargée) : moyenne **16,6 → 12,3 à 14,9 ms** par image, pire **18 → 18 à 25** (la première image, qui dessine les 36 morceaux d'un coup) ; les morceaux ne se redessinent plus ensuite (`n.terrain` 36 sur 395 images, la simulation dit au client quelles tuiles viennent d'être découvertes : `Grille.decouvertes_recentes`) ; le paperdoll passe de 450 ms cumulées (267 dessins) à 47 à 86 ms (92 à 224 dessins) grâce aux pictogrammes. Les morceaux de 16 × 16 essayés d'abord coûtaient 12 ms chacun à redessiner et cachaient moins bien hors écran : 8 × 8 est le bon grain. Un piège vu à la capture d'un hameau : le z des morceaux est relatif au nœud Terrain (0 à 46) — à z -10, les morceaux du bas passaient au-dessus du brouillard (-2) et des voiles ; le Terrain est à -60 depuis 3 h 50. Ce qui reste dans l'image (une dizaine de ms) est le rendu Godot lui-même des tuiles retenues et des êtres : la prochaine marche sera les sprites.

> [!decision] 2026-09-06, 2 h — les êtres lointains en pictogramme
> Un paperdoll complet coûte près de 2 ms à dessiner (segments, tenus, occulteurs) et un PNJ qui marche change d'orientation à chaque pas : en ville, deux cents habitants en mouvement, c'est un redessin permanent même avec la signature. Au-delà de `combat_rules.tempo.pictogramme_au_dela` tuiles du joueur (12 ; 0 pour désactiver), le paperdoll dessine un **pictogramme** — un corps et une tête à sa couleur de peau, un liseré rouge s'il est hostile — qui ne dépend ni de l'orientation ni de l'équipement : il ne se redessine qu'en franchissant le seuil. De près, rien ne change. Le seuil est un choix de regard autant que de budget : [[À juger — parcours de jeu]].

> [!note] 2026-09-06, 3 h 30 — la semaine d une ville chargée
> Sonde des villes (monde 9, 189 résidents, cinq cellules) : le passage de semaine coûtait 560 ms, dont 200 en humeurs et 44 en maisons — la détection de pièces inondait mille tuiles par porte côté rue, et chaque lit cherchait sa pièce dans chaque pièce. Après ([[Détection de pièces]], l extérieur d abord ; une table tuile → pièce par cellule) : 98 ms en humeurs, 33 en maisons. Le reste de la semaine est la production, les royaumes PNJ et les pas simulés en accéléré.

> [!decision] 2026-09-06, 8 h — le LOD de simulation des PNJ (designer : « aucune raison d'autant lagger en ville puisque là j'avais que 2 PNJ à l'écran… tout est simulé comme si c'était à l'écran »)
> Dans la fenêtre chargée, tous les êtres décidaient pareil : utilité, cible, chemin A* ou pas glouton, une décision par pas. Désormais un **civil loin de tout joueur** (`planete.routine.lod.rayon_plein`, 28 tuiles : hors de l'écran) et hors combat est un **figurant** : `_ia_lointain` lit sa cible de routine et fait un **bond** de `pas_par_decision` tuiles vers elle en ligne droite (la case libre la plus proche s'il y a un mur : il traverse — personne ne le voit), paie le temps de marche (`deplacement.cout_base` par tuile), et, arrivé, se tient là `attente_ticks` avant de redécider. Ni chemin, ni vision, ni portes, ni journal. Quand le joueur s'approche, il redevient un être entier à sa prochaine décision. Les hostiles, les bêtes, les véhicules et tout être en combat gardent la simulation complète. Le journal n'écrit plus les pas du joueur non plus (« n'affiche pas les déplacements dans le journal »).
>
> **Codé à 8 h 45** (`test_lod_pnj` : loin, un villageois bondit de six tuiles vers son poste sans chemin et s'y tient deux cents ticks ; près, un pas d'une tuile). Un figurant a une routine (des horaires dans son profil) : les bêtes, les itinérants, les véhicules restent entiers. Sonde d'échelle : 197 êtres 1,2 → 0,74 ms par tick ; 2 000 êtres 4,8 → 2,8 à 3,7 ms. Ce qu'un joueur verra : rien, sauf un habitant qui apparaît à l'écran là où sa journée l'a mené.

> [!success] 2026-09-06, 10 h — « réécriture en C++ et optimisation » (designer) : le noyau C++ et la file des compteurs, mesurés
> Décidé et décrit dans [[Modules de la simulation et le C++]] (section 3). Sonde d'échelle (monde 9, Mokroslav, l'éditeur du designer ouvert à côté — « machine chargée »), ms par tick du monde, avant → après :
>
> | êtres | avant | après | ce qui reste |
> |---|---|---|---|
> | 197 | 1,68 | **0,52** | régénération 0,13, raid et météo 0,14 |
> | 501 | 2,25 | **0,72** | décisions 0,16, fin de pas 0,11 |
> | 1 002 | 2,11 | ≈ 1,1 | |
> | 2 000 | 4,60 | **1,82** | fin de pas 0,47, monde 0,38, décisions 0,37 |
>
> Le gros du gain n'est pas le C++ : `_prochaine("monde")` balayait toutes les entités à chaque pas (2,93 ms des 4,6 à 2 000 êtres — `pas.prochaine` au chrono depuis) ; la file triée validée en tête le ramène à 0,08. Une première version qui rebâtissait « la liste des dus » à chaque tick ne gagnait presque rien : à 2 000 êtres il n'y a que cinq pas par tick, et une reconstruction O(n) en GDScript coûte autant que cinq balayages — d'où la file persistante. Le noyau C++, lui, rend le chemin, la ligne et le champ de vue **deux à trois cents fois** moins chers (`test_noyau_cpp` : arène 1 746 → 6 ms pour 150 chemins ; fenêtre 192 × 192 à 800 nœuds 8 006 → 23 ms) : ce n'est pas ce qui pesait sur le tick d'une ville (les chemins de routine sont en cache, les figurants n'en font pas), c'est ce qui permettra d'en demander plus — un budget de nœuds plus large, un A* sous plus de vingt tuiles, la vision de plus d'êtres — sans revenir sur le budget. Les chiffres du rendu (le regroupement des triangles du terrain et du brouillard) suivent ci-dessous.

> [!note] 2026-09-06, 10 h 30 — le rendu en ville : les triangles regroupés, et ce que la mesure a appris
> Un morceau de terrain dessinait chaque triangle par une commande de canvas (`draw_primitive`) : quatre cents commandes par morceau, quatorze mille retenues par image. Désormais `_poly` accumule dans un **lot** (`LotTriangles`) pendant qu'un morceau ou le brouillard se dessine, et tout part en **une** commande (`RenderingServer.canvas_item_add_triangle_array`) ; une commande qu'on ne regroupe pas (sprite, caisse, traverse de porte) vide le lot avant elle, l'ordre de dessin ne change pas — regardé sur deux captures de villes : murs, portes, plantes, voiles du brouillard, rien ne diffère à l'œil. `capture.tscn` mesure désormais le rendu lui-même (`viewport_set_measure_render_time` : CPU et GPU du viewport, appels de dessin) et accepte `--sans-lots` pour comparer. Intel UHD 620, Firefox et Steam ouverts à côté, **`--disable-vsync` AVANT le `--`** (après, c'est un argument utilisateur que Godot ignore : la première série mesurait 33 ms d'images calées sur le vsync — le piège de la matinée), et **`--graine 21`** (sans graine, chaque prise tombe dans une autre ville — la première série comparait des cités de 163 à 283 habitants) :
>
> | cité « Ouarbah », 247 habitants, 7 cellules (deux prises chacune) | image (moyenne) | pire image | rendu CPU | rendu GPU | appels de dessin |
> |---|---|---|---|---|---|
> | triangle par triangle | 18,3 et 24,7 ms | 34 et 56 ms | 2,1 et 2,8 ms | 2,0 et 2,4 ms | 495 |
> | en lots | **16,9 et 17,0 ms** | **27 et 39 ms** | **1,1 ms** | **1,7 ms** | 529 |
>
> **12 h 50 — la semaine d'une ville, suite** (sonde des villes, monde 9, cinq cellules, 204 êtres) : `t.humeurs` 98 → 7,5 ms et `t.maisons` 33 → 14 ms, les pièces inondées par le noyau C++ (`regions_cellule`, [[Détection de pièces]]) ; et le vrai poids de la semaine, que personne n'avait chronométré : `pas.regen` **530 ms** — la régénération de mana jouait une tranche de dix ticks par tranche écoulée depuis la dernière action, huit cents jets par dormeur au réveil ([[Mana]], `tranches_exactes`) → 0,9 ms. La semaine passe de 350-850 ms à **175-250 ms**, le tick de croisière de 0,54 à 0,39 ms.
>
> Le lot divise par deux le temps de rendu CPU et gagne une à deux millisecondes d'image ; mais le rendu de Godot n'est **pas** ce qui remplit l'image : trois millisecondes sur dix-sept. Le GDScript du client en prend six (nœuds 1,5 à 2, HUD 0,7, texte et minimap 0,5, paperdolls et terrain au redessin), et le reste est le moteur lui-même — trois cents nœuds d'êtres et de végétaux à faire vivre et trier chaque image. Le C++ ne changerait rien à ça ; ce qui le changerait, c'est **moins de nœuds** : les êtres lointains sans nœud du tout (dessinés d'un trait sur une couche, comme le terrain), les végétaux fondus dans leur morceau. C'est la prochaine marche du rendu, et elle est en GDScript.

> [!success] 2026-09-06, 14 h 40 — le passage d'une cellule sans à-coup, et le brouillard d'une ville allégé
> **Le recentrage.** Quand le joueur franchit une cellule, la fenêtre glisse d'une cellule ; le client refaisait tout : les 36 morceaux de terrain, des centaines de végétaux, deux cents paperdolls réinstanciés et redessinés — trois à quatre cents millisecondes de gel, masquées par un voile noir (`_ouvrir_chargement`). Désormais `_apres_recentrage` garde tout et **re-clé** : les morceaux (leur clé et leur profondeur suivent la nouvelle origine), les végétaux (par position monde, profondeur refaite), les paperdolls (rien à faire). Ce qui le permet : `_ecran` soustrait `origine_dessin`, l'origine du dernier VRAI changement de grille, et plus l'origine courante — un glissement ne déplace donc aucun dessin retenu ; au-delà de seize cellules du point de départ on rebase par le chemin complet (les pixels restent loin de 1e6). Mesuré (capture `--ville --graine 21 --traverser-en-jeu 40`) : le recentrage coûte **0,8 ms**, et la traversée dessine 35 morceaux et 235 paperdolls de moins ; le voile noir ne s'ouvre plus. `--recentrage-complet` garde l'ancien chemin pour comparer.
> **Le brouillard en ville.** Chaque pas redessine le brouillard, et une ville a des centaines de murs mémorisés hors de vue, chacun dessiné comme un bloc complet (matériaux, bandes, voisins : 73 µs) : 55 ms par pas. Une **silhouette** (`_dessine_silhouette` : trois faces plates, sombres, opaques) fait le même travail à l'œil pour le quart du prix — le brouillard passe à 33 ms par pas, et ce qui reste est la boucle GDScript sur 1 681 tuiles ; la marche suivante est de la bâtir dans le noyau (les voiles, les toits et les ombres en un tableau de triangles chacun), puis les morceaux de terrain eux-mêmes (10 ms le morceau de ville).

> [!success] 2026-09-06, 22 h — le brouillard et les toits par le noyau (file 114) : mesure en ville
> `capture --ville --graine 21 --heure 10 --traverser 24`, 55 images, chrono client cumulé : `draw.brouillard` 27,7 ms → 2,7 ms (dont 1,75 ms de tableaux par le noyau), `draw.toits` 12,6 ms → 0,75 ms ; l'image moyenne 20,1 → 18,1 ms, process 23,3 → 19,3 ms. `test_noyau_passes` sur trois cas : 10 106 triangles, GDScript 94 ms, C++ 3,8 ms. Ce qui pèse encore par image, en ville : `noeuds` (la mise à jour des paperdolls, 173 ms sur 55 images, ~3 ms par image), `draw.hud` (65 ms), `ui.texte` (24 ms), `lumiere` (12 ms) — la prochaine marche de 114 est là, avant les morceaux de terrain.
> **22 h 20, la visibilité des êtres par le noyau** (`SensenGrille.visibles`, un appel par image pour tous) : `noeuds` 173 → 135 ms sur 55 images (~2,5 ms par image), `draw.hud` 65 → 19 ms. Ce qui reste dans `noeuds` est la mise à jour des nœuds eux-mêmes (position, lumière, profondeur, signature) — du GDScript par être, sans boucle pure à déplacer.
> **22 h 50, les morceaux de terrain par le noyau** (`SensenGrille.morceau`, les coupures pour les commandes hors triangles) : `draw.terrain` 42 ms pour 36 morceaux redessinés (1,2 ms par morceau, dont 0,27 ms de tableaux par le noyau ; c'était ~10 ms par morceau), soit le passage d'une cellule qui refait ses neuf morceaux en ~11 ms au lieu de ~90. Dans le même test, 25 morceaux : GDScript 78 ms, C++ 5 ms.

> [!success] Mesuré et corrigé le 2026-09-07, 9 h — la saccade des premières secondes : les planches se chargeaient en plein dessin
> Le lag en ville ne venait pas d'où je le croyais. Deux enseignements de mesure avant tout remède :
> - **Sans `--disable-vsync` (AVANT le `--`), la moyenne d'image ne veut rien dire** : elle mesure le plafond du moniteur (23 ms). Une capture de ville prise sans lui disait « 24,8 ms » alors que le coût réel était tout autre.
> - **Le chrono du client est CUMULÉ sur toute la capture**, pas par image : `lumiere 121 ms` sur 115 images fait 1 ms par image, pas 121. Le lire comme un temps d'image mène droit à optimiser ce qui ne coûte rien.
> Ce que la mesure a fini par montrer : `draw.paperdoll` variait de **116 à 897 ms** d'une capture à l'autre, à scénario identique. Ce n'était pas du bruit — c'était le **chargement paresseux des planches** : le premier dessin d'un membre ou d'un trait de visage ouvre le dossier, lit ses PNG et les découpe en cases (`Planches.charger`). Fait en pleine partie, la première fois qu'un villageois montre son visage, c'est une saccade ; et selon que la capture tombait avant ou après, la mesure changeait du simple au décuple.
> `Planches.prechauffer()` assemble les trois racines (`membres`, `visage`, `objets`) et crée leurs textures dans le `_ready` du client : **236 ms une fois au lancement** — du temps mort qu'on avait déjà — au lieu de millisecondes semées au hasard pendant le jeu. Un paperdoll redessiné passe de 0,4-3,7 ms à **0,12 ms**.
> Où en est le budget d'image dans une cité de 247 habitants (graine 21, midi, sans vsync) : **15,2 ms de moyenne au zoom de jeu (2,0)**, 17,2 à 1,0, 23,2 à 0,45 — la pire image reste à 28 ms. Le budget (16 ms) tient en moyenne au zoom où l'on joue, pas aux zooms de survol, et la pire image le dépasse encore : ce qui reste à regarder, c'est le recalcul de la carte de lumière et les morceaux de terrain qu'un changement de tuile fait redessiner.

> [!success] Outillé le 2026-09-07, 10 h — le chrono du client garde le PIRE de chaque étape, et ce qu'il a montré
> Un cumul divisé par le nombre d'images noie les saccades : une étape qui coûte cent millisecondes **une fois** disparaît dans la moyenne. `_top_client` garde désormais `max.<étape>` à côté du cumul, et la capture les imprime. Ce que cela a montré tout de suite, dans une cité de 247 habitants :
> - **`max.lumiere` de 10 à 263 ms selon les exécutions**, pour le même scénario. Ce n'était pas la lumière : c'était la **première texture créée du processus**, qui paie l'initialisation du pipeline de rendu (180 à 230 ms). Selon l'ordre des choses, elle tombait sur les planches ou sur la carte de lumière. `Planches.prechauffer()` crée maintenant une texture de quatre pixels avant tout le reste, pour que ce réveil ait lieu quand il n'y a rien à l'écran.
> - **`max.ui.minimap` ≈ 50 ms** au premier tracé, puis ~2 ms toutes les 0,15 s : la minimap redessine ses 4 096 tuiles dès que le compte des tuiles découvertes change, et téléverse sa texture à chaque rafraîchissement. C'est le prix d'une minimap qui suit le brouillard ; à revoir si le budget se resserre (ne redessiner que les tuiles nouvellement découvertes).
> - **Une fois les initialisations passées, l'image tient** : 14,4 à 15,2 ms de moyenne au zoom de jeu, pire image 22 à 28 ms selon les exécutions.
> La leçon de méthode : **une mesure qui varie du simple au décuple d'une exécution à l'autre n'est pas du bruit** — c'est un coût de première fois qu'on n'a pas vu. Chercher ce qui se fait une seule fois avant de chercher ce qui se fait à chaque image.

> [!success] Mesuré le 2026-09-07, 17 h 45 — la minimap par le noyau (designer : « réécriture C++ et optimisation », redit)
> `capture --ville --graine 21 --heure 10 --traverser 24` (sans vsync, 55 images, une traversée de cellule qui découvre des tuiles) : **`max.ui.minimap` 50 ms → 4,1 ms**, cumul `ui.minimap` 21,6 ms sur 55 images. Dans `test_noyau_passes`, la même cellule : GDScript 51,0 ms, C++ 1,90 ms, octets identiques. Ce qui reste des 4 ms est la surcouche des icônes (une boucle sur les vivants, la copie de l'image et son téléversement, sept fois par seconde) — pas une boucle sur les tuiles. Le détail dans [[Modules de la simulation et le C++]] (callout du 2026-09-07, 17 h).

> [!important] Mesuré le 2026-09-08 — le lag en ville, chiffré : et **les deux passes chaudes sont DÉJÀ en C++** (designer : « énorme lag en ville », puis « tu peux pas réécrire certaines fonctions en C++ ? »)
> **La mesure** (capture d'une ville de 107 habitants, 85 images, sur l'Intel UHD 620 du designer) : **24,1 ms en moyenne, 46,2 ms au pire** — 41 images/s en moyenne, 21 au pire. Le détail retourne l'intuition :
> - **GPU : 5,9 ms.** **Rendu CPU de Godot : 3,3 ms.** Le matériel n'est pas le mur.
> - **1 261 appels de dessin par image.**
> - Le plus gros poste instrumenté est `draw.terrain` : **216 ms pour 196 redessins de morceaux** en 85 images.
>
> **Et voici la réponse à « pourquoi pas le C++ » : les deux passes chaudes y sont déjà.**
> - Les **morceaux de terrain** passent par `SensenGrille.morceau` — la part **C++ coûte 0,23 ms** par morceau (`morceau.tableaux`), la **soumission au canevas 0,87 ms** (`draw.terrain`). **Le C++ est déjà la partie bon marché.**
> - Le **brouillard** passe par `SensenGrille.brouillard` — sa part C++ culmine à 7,3 ms sur l'image d'un pas, la soumission à **12,7 ms**. Même verdict.
> Ce qui reste coûteux est ce que **Godot doit soumettre** : ce n'est pas du calcul, c'est du dessin, et aucun portage ne le contourne.
>
> **Les vrais leviers, dans l'ordre du gain :**
> 1. **Le joueur ne VOIT que 5 tuiles** (`perception × detection_par_perception` = 5 × 1,0) alors qu'on en **DESSINE 20** autour de lui. Toute la ville est donc du **mémorisé**, dessiné en silhouettes plates — et le brouillard en compte des centaines par passe, refaites à chaque pas. **Élargir la vue réduit mécaniquement ce qu'il y a à dessiner** : c'est le plus gros gain disponible, et il explique aussi le « les textures ne sont pas toujours affichées ». *C'est une décision de game design : le champ de vue du joueur et la portée de détection d'une IA partagent le même nombre, et ce ne sont pas la même chose.*
> 2. **Ne pas refaire ce qui n'a pas changé** — la leçon du jour, appliquée deux fois : la **carte de lumière** se refaisait entièrement à chaque tick de monde (cent recalculs → zéro sur cent ticks immobiles), et les **occulteurs d'un paperdoll** gardaient les blocs de l'ancienne tuile parce que la position n'était pas dans la signature de redessin — d'où les « blocs fantômes qui suivent le joueur ».
> 3. **Moins de triangles** : fusionner les silhouettes mémorisées adjacentes. Là, oui, le C++ servirait — mais après les deux premiers.
>
> **Une leçon de méthode qui n'est pas technique** : quatre processus Godot **orphelins** ont été trouvés dans la journée — des runs headless dont la tâche se termine côté harnais mais dont le processus survit, jusqu'à **823 secondes de CPU**. Ils tournaient pendant que le designer jouait. Vérifier les processus **avant** de lancer une suite fait partie de la mesure.

> [!success] Corrigé le 2026-09-08 — la chasse au lag en ville, et **un A/B rigoureux qui nuance mon hypothèse**
> **Ce que le joueur VOIT a désormais ses propres nombres.** Il empruntait `engagement.detection_par_perception` — la portée à laquelle une **IA repère une cible** —, si bien qu'en plein jour, ciel clair, il ne voyait que **cinq tuiles** quand le client en dessine vingt autour de lui. Toute la ville était donc du **mémorisé**, redessiné en silhouettes plates à chaque pas. `vision.joueur_base` (18) + `joueur_par_perception`, avec `joueur_min` comme plancher ; la nuit et la météo continuent de multiplier, une lumière en main rattrape.
>
> **L'A/B, à graine fixe, même ville** (KomPtah, 247 habitants, 85 images) :
>
> | | moyenne | **pire image** | appels de dessin |
> |---|---|---|---|
> | vue à **5** tuiles | 22,1 ms | **46,1 ms** | 1 236 |
> | vue à **23** tuiles | 24,2 ms | **36,6 ms** | 1 242 |
>
> **La moyenne monte de 9 %, la pire image baisse de 21 %**, et le temps de script total passe de 166 à 47 ms. C'est la **pire image** qui compte ici : ce que le designer décrit comme « lag quand le joueur se déplace » est un **à-coup**, celui du brouillard entièrement reconstruit à chaque pas. Voir loin réduit ce qu'il y a à reconstruire.
> **Honnêteté sur la méthode** : la première mesure, sans graine fixe, tombait sur une autre ville et disait le contraire (29,6 ms contre 24,1). Elle ne prouvait rien. **Deux captures ne se comparent que sur la même graine** — et il a fallu que la mesure me contredise pour que je le voie.
>
> **Les deux à-coups traités le même jour** : la **carte de lumière** refaite entièrement à chaque tick de monde (cent recalculs → zéro sur cent ticks immobiles, prouvé par `test_lumiere_incrementale`), et les **occulteurs d'un paperdoll** qui gardaient les blocs de l'ancienne tuile — la position n'était pas dans la signature de redessin, d'où les « blocs fantômes qui suivent le joueur et disparaissent à l'arrivée ».
>
> **Ce qui reste, dans l'ordre du gain** : **fusionner les silhouettes mémorisées adjacentes** (là, le C++ servirait vraiment — c'est le seul endroit de la chasse où il servirait), et **réduire les ~1 240 appels de dessin par image**.

> [!failure] **CORRECTION du 2026-09-08, 18 h — la conclusion ci-dessous était FAUSSE, et la mesure qui l'aurait montrée tenait en une capture**
> J'ai écrit « ce n'était pas un défaut de dessin, c'était un réglage ». C'était un **défaut de dessin** : le shader de grain n'atteignait pas le décor du tout. Le matériau était posé sur le nœud `terrain`, mais tout est dessiné par ses enfants `TerrainMorceau`, et un enfant de canevas sans matériau **n'hérite pas** de celui de son parent (`use_parent_material` manquait). Et par-dessus, `origine_dessin` restait à (0, 0) : les UV portaient des coordonnées monde qui noyaient le style de la matière.
> **Ce que j'ai mal fait, précisément** : j'ai vérifié que les UV étaient posées (elles l'étaient), j'ai vu que le grain était faible (il l'était), et j'ai conclu. Je n'ai jamais vérifié que le shader **tournait sur ces pixels**. Un test d'une ligne — peindre en magenta tout ce qui passe par le shader — l'aurait dit d'un coup d'œil ; c'est celui qui a fini par trancher, six heures plus tard. **Une cause plausible n'est pas une cause démontrée.**
> Le réglage du grain (0,26 / 0,15) reste, mais il n'explique rien : il n'était simplement jamais appliqué.

> [!success] Corrigé le 2026-09-08 — « les textures ne sont pas affichées sur les blocs et les sols » : ce n'était pas un défaut de dessin, c'était un réglage
> **Le sol reçoit bien ses UV** — le dessus d'une tuile, ses deux flancs, et même **un motif par matière** encodé dans la partie haute de `UV.x`. Le shader de grain tournait. La règle qu'il énonce (« sans UV, la matière est plate : ni soleil ni grain ») ne concernait pas le sol.
> **Le problème était l'intensité** : `force_grain: 0.12` et `force_douce: 0.07`, soit une variation d'environ **±12 %** de la couleur. Sur une palette sombre — ±0,03 sur un vert olive — c'est **invisible**. Posé à **0,26 / 0,15** : la matière se voit sans que le décor grouille ; un essai à 0,38 / 0,22 s'est révélé trop marqué sur les toits.
> **C'est de la direction artistique et une ligne de données** : le chiffre revient au designer, les deux captures de comparaison lui ont été envoyées.

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Boucle de tick]]
- **Alimente** : [[Optimisation — principes]], [[Entités et pathfinding — performance]], [[Ordre de vérification]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Décision — Structure de données de la grille]], [[Éclairage]], [[Génération procédurale — performance]], [[Simulation du monde — performance]], [[Réseau et sauvegarde — performance]], [[Risques majeurs]]
