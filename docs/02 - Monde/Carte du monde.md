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

## Liens
- **Dépend de** : [[Décision — Monde fini, continents et océan]], [[Grille continue]], [[Unification macro-micro]], [[Génération par couches de bruit]]
- **Alimente** : [[Début de partie]], [[Boucle de jeu]], [[Donjons — structure et intégration]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Niveau de danger]], [[Dérive de la corruption]], [[Trésors et artefacts]], [[Biomes de départ]], [[Véhicules]]
