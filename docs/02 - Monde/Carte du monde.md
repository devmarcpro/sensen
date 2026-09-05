---
aliases: ["3.1", "3.1 Carte du monde", "Carte du monde", "Couche roguelite"]
tags: [monde, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

La couche stratégique : une vue abstraite de la même grille, servant de voyage rapide et de tableau de bord des points d'intérêt.

- **Monde fini, structuré comme une planète** : continents, îles et océan ([[Décision — Monde fini, continents et océan]]) — 1024×1024 cellules, ~35 % de terres émergées, 5 à 7 continents. La carte du monde a donc des **bords**, et l'océan y est un obstacle réel plutôt qu'un décor.
- Généré procéduralement et déterministiquement à la graine.
- Déplacement case par case sur la carte du monde (façon roguelike).
- **Biomes :** nombreux et nuancés (**20+**), émergeant des combinaisons variées des couches de bruit ([[Génération par couches de bruit]]) plutôt qu'un petit nombre de catégories larges façon Minecraft.
- **Points d'intérêt :** donjons/ruines à explorer, camps de monstres/repaires, ressources rares à récolter, sanctuaires/autels magiques, villages/villes PNJ (voir [[Villages PNJ — repeuplement et décimation]]).
- **Trésors et artefacts :** catégorie d'objets à part — voir [[Trésors et artefacts]].
- **Niveau de danger :** voir [[Niveau de danger]].
- **Dérive de la corruption (monde vivant)** : voir [[Dérive de la corruption]].
- **Articulation avec le monde continu :** la carte du monde est une vue abstraite de la même grille, utilisée comme **raccourci de voyage rapide**. Le joueur peut aussi **tout traverser à pied en continu**, sans jamais passer par la carte, puisque la grille est sans coupure.

**Décisions :**
- **Biomes :** la liste de référence est **[[Biomes de départ]]** (12 au lancement, extensible vers 20+ par simple ajout de données [[Biomes — schéma]] — les conditions de couches y sont définies par biome).
- **Points d'intérêt : hybride résolu ([[Unification macro-micro]])** — assemblés procéduralement à partir de **salles/bâtiments préfabriqués faits main** (palettes remapables, [[Direction artistique]]) ; densités chiffrées en [[Unification macro-micro]] (village 4 %, donjon 6 %, camp 8 %, sanctuaire 3 %, filon majeur 6 % par cellule).

**Voyage en véhicule :** voyager avec un véhicule accélère le voyage rapide (coût de temps in-game réduit : ×0.6 terrestre sur route, ×0.5 naval sur mer) et augmente le cargo transportable — voir [[Véhicules]].

**Voyage maritime :** le voyage rapide en mer ne s'ouvre que sur les **routes maritimes déjà parcourues une fois** — même principe que le reste de la carte, qui n'est jamais qu'un raccourci par-dessus un monde réellement traversable. Atteindre un continent la première fois est donc toujours une navigation, jamais un clic.

> [!success] Codé le 2026-08-28 — étape 8.3a, `scenes/demo/carte.gd` (touche **M**)
> Une case par cellule, **33×33 cellules** autour du joueur (flèches pour défiler), le **biome échantillonné au centre** de la cellule (`couleur` du biome), la **heat-map de danger en trois niveaux** (paisible / dangereuse / mortelle, seuils `planete.danger`, teinte orange puis rouge), les **icônes des POI** (donjon : carré cerclé d'or ; filon majeur : point clair), le camp et la cellule courante cerclés. Les cellules jamais explorées sont assombries. **Voyage rapide** : cliquer une cellule **de terre déjà explorée** (au moins un chunk vu) — le joueur y arrive au centre marchable, le temps in-game avance de `planete.voyage.ticks_par_cellule` × distance (décision : 384 ticks par cellule, soit 128 tuiles à 3 ticks ; le ×0,6 des routes attend les routes) ; la mer reste un obstacle. La carte est un résumé, jamais une source de vérité : elle relit la surface.

> [!success] Codé le 2026-08-28 — les routes sur la carte et le voyage
> Traits ocre entre cellules reliées ; **voyage rapide ×0,6** quand départ et arrivée sont sur une route (sans véhicule — le facteur des véhicules attend).

> [!success] Ajusté le 2026-08-30 — 192 ticks par cellule
> Avec le retour aux cellules de 64 × 64 ([[Claims et persistance]]), `voyage.ticks_par_cellule` passe de 384 à **192** : toujours 3 ticks par tuile, la règle n'a pas changé, la cellule si.

> [!success] Décidé et codé le 2026-09-01 — la carte devient une vraie carte (designer, point 59)
> Quatre changements demandés, tous en données ou en dessin, aucun asset. **Chaque cellule est peinte en 5 × 5 sous-points** (`carte.sous_points`) : la surface est échantillonnée cinq fois par côté au lieu d'une, si bien qu'une **côte, une lisière ou un flanc de montagne se lisent dans la case elle-même** au lieu d'un aplat de biome. **L'avatar du joueur** est dessiné sur sa cellule — le même paperdoll que dans le jeu, en miniature, pas un point. La carte se **fait glisser** (bouton du milieu ou clic droit maintenu), les flèches faisant toujours défiler. **Le zoom a été annulé le 2026-09-01** sur décision du designer, en même temps que le rendu pixelisé : la carte garde une échelle fixe.
>
> Enfin, **voyager coûte le temps d'une vraie marche** : le forfait `ticks_par_cellule` disparaît au profit du produit *distance en tuiles × coût d'un pas*, où le coût d'un pas est celui du jeu — la vitesse du personnage, sa charge et le terrain compris. Traverser trois cellules de montagne chargé coûte donc bien plus que trois cellules de plaine à vide, et la route garde sa remise.

> [!success] Codé le 2026-09-01 — le donjon dit sa difficulté (designer, point 61)
> Un donjon né de la corruption ne se laissait juger qu'à la couleur de sa case. Il s'annonce désormais **deux fois**. **Au survol de la carte** : son nom de thème, son élément, son **niveau**, son nombre d'**étages** et le taux de **corruption** de la cellule. **À l'entrée** : la même ligne au journal, puis un rappel permanent dans l'en-tête tant qu'on y est — « corrompu, niveau 12 (74 %) ». Le joueur peut donc décider **avant** d'entrer, et sait **pendant** où il a mis les pieds.

> [!bug] Corrigé le 2026-09-01 — la carte refusait tout voyage (designer)
> « impossible de se déplacer avec la carte du monde contrairement à ce que je voulais ». Deux verrous. **Le premier** : `voyager` exigeait `cellule_exploree(cell)` — or on n'explore une cellule qu'en y allant, donc tout clic hors des cases déjà foulées répondait « voyage impossible ». Marcher vers l'inconnu est le geste normal d'une carte : la condition tombe, seule la terre ferme du monde reste exigée (l'océan se refuse toujours). **Le second** : le glissement était **du code mort** — la première branche de `_entree` traitait *tous* les `InputEventMouseMotion` et rendait la main, si bien que la branche `if ev is InputEventMouseMotion and _glisse` placée après n'était jamais atteinte. Le survol et le glissement sont désormais traités dans la même branche.


> [!success] Tranché le 2026-09-02 — le monde se lit en **continents** et en **régions** (designer)
> « Le monde est découpé en continents et les continents sont découpés en régions. » J'avais proposé que la région soit le territoire d'un royaume, puisque `royaume_de(cell)` pave déjà la carte ; le designer a tranché contre, et il a raison : **« les territoires sont voués à changer »**. Une région dont les frontières bougent au gré des conquêtes ne peut porter ni un nom stable, ni un donjon permanent, ni un souvenir de ce qu'on y a accompli. La découpe est donc **géographique et immuable**, indépendante de qui règne.
> **Le continent** est une masse de terre : les plaques tectoniques continentales qui se touchent n'en forment qu'un seul, réunies une fois pour toutes. **La région** est une subdivision d'un continent — un pavage de Voronoï sur un réseau de germes jitterés, lu à la demande comme la tectonique l'est déjà : aucune passe globale, aucune couture, même graine même découpe. Chaque région et chaque continent porte un nom généré, et la carte du monde les nomme sur la cellule survolée.

> [!success] Codé le 2026-09-02 — une partie ne commence pas n'importe où (designer)
> « J'aimerais garantir que le joueur spawn sur un continent avec sur sa masse terrestre au moins un gouffre, 2 villes de 2 royaumes différents. » Une graine qui pose le camp sur un îlot désert donne une partie sans rien à faire — et on ne s'en aperçoit qu'après avoir joué une heure. Le monde **cherche** donc une case qui tienne ces promesses, au lieu de se contenter d'une case de terre ferme. Sauf si le joueur a choisi la sienne sur la carte : c'est son droit de commencer au bout du monde.
> **Deux raccourcis assumés**, pour que le calcul tienne en une fraction de seconde : on ne parcourt pas la masse de terre entière mais un **voisinage** — un gouffre à l'autre bout d'un continent n'est de toute façon pas « sous la main » — et on n'inspecte pas chaque cellule : les gouffres se déduisent des germes de région, les villes des capitales des royaumes du secteur.
> Vérifié sur six graines : **six fois tenu**, après avoir porté le rayon de recherche à 140 cellules pour l'une d'elles.
> **Une erreur de méthode corrigée au passage** : `sonde_monde` ne passait la graine qu'aux jets de dés, pas au **monde**. Toutes les mesures de monde de la journée — régions, gouffres, densité — décrivaient donc un seul et même monde, présenté à tort comme un cas général.

> [!success] Corrigé le 2026-09-04 — la teinte des donjons de corruption sur la carte
> Vu sur une capture de la carte, dans la console : « Invalid color code: [0.9, 0.25, 0.15] », trois fois par image. La carte lisait `wuxing.teintes` comme des codes HTML alors que ce sont des triplets RVB (tout le reste du jeu les lit ainsi) : les donjons nés de la corruption se dessinaient d'une couleur de repli, pas de celle de leur élément. Corrigé dans `carte.gd`.

> [!success] Codé le 2026-09-05, 20 h — se déplacer case par case sur la carte (designer, point 98)
> « Actuellement on ne peut pas se déplacer dessus ; je voudrais pouvoir me déplacer comme un vieux RPG style Dragon Quest / Final Fantasy, juste se déplacer de case en case. » Sur la carte (M), **les flèches font marcher le joueur d'une cellule** : chaque pas est un `voyager` vers la voisine, au coût de la marche (la route le divise, comme avant), la carte reste ouverte et se recentre sur lui, l'avatar suit ; arrivé sur la cellule d'un donjon, on y entre et la carte se ferme. **Maj + flèches** font défiler la carte (l'ancien rôle des flèches), le clic marche jusqu'à une cellule lointaine ou revendique une voisine comme avant, Échap ferme. Le titre de la carte le dit. Rien de nouveau dans la simulation : un pas est un voyage d'une cellule.

## Liens
- **Dépend de** : [[Décision — Monde fini, continents et océan]], [[Grille continue]], [[Unification macro-micro]], [[Génération par couches de bruit]]
- **Alimente** : [[Début de partie]], [[Boucle de jeu]], [[Donjons — structure et intégration]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Niveau de danger]], [[Dérive de la corruption]], [[Trésors et artefacts]], [[Biomes de départ]], [[Véhicules]]
