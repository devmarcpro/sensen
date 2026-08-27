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

## Liens
- **Dépend de** : [[Décision — Monde fini, continents et océan]], [[Grille continue]], [[Unification macro-micro]], [[Génération par couches de bruit]]
- **Alimente** : [[Début de partie]], [[Boucle de jeu]], [[Donjons — structure et intégration]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Niveau de danger]], [[Dérive de la corruption]], [[Trésors et artefacts]], [[Biomes de départ]], [[Véhicules]]
