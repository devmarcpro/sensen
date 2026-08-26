---
aliases: ["3.1", "3.1 Carte du monde", "Carte du monde", "Couche roguelite"]
tags: [monde, structure, décidé]
domaine: monde
statut: décidé
etape: 8
---

La couche stratégique : une vue abstraite de la même grille, servant de voyage rapide et de tableau de bord des points d'intérêt.

- Monde infini, généré procéduralement.
- Déplacement case par case sur la carte du monde (façon roguelike).
- **Biomes :** nombreux et nuancés (**20+**), émergeant des combinaisons variées des couches de bruit ([[Génération par couches de bruit]]) plutôt qu'un petit nombre de catégories larges façon Minecraft.
- **Points d'intérêt :** donjons/ruines à explorer, camps de monstres/repaires, ressources rares à récolter, sanctuaires/autels magiques, villages/villes PNJ (voir [[Villages PNJ — repeuplement et décimation]]).
- **Trésors et artefacts :** catégorie d'objets à part — voir [[Trésors et artefacts]].
- **Niveau de danger :** voir [[Niveau de danger]].
- **Dérive de la corruption (monde vivant)** : voir [[Dérive de la corruption]].
- **Articulation avec le monde continu :** la carte du monde est une vue abstraite de la même grille, utilisée comme **raccourci de voyage rapide**. Le joueur peut aussi **tout traverser à pied en continu**, sans jamais passer par la carte, puisque la grille est sans coupure.

**Décisions :**
- **Biomes :** la liste de référence est **[[Biomes de départ]]** (12 au lancement, extensible vers 20+ par simple ajout de données [[Biomes — schéma]] — les conditions de couches y sont définies par biome).
- **Points d'intérêt : hybride résolu ([[Unification macro-micro]])** — assemblés procéduralement à partir de **salles/bâtiments préfabriqués .vox faits main** (palettes remapables, [[Direction artistique]]) ; densités chiffrées en [[Unification macro-micro]] (village 4 %, donjon 6 %, camp 8 %, sanctuaire 3 %, filon majeur 6 % par cellule).

**Voyage en véhicule :** voyager avec un véhicule accélère le voyage rapide (coût de temps in-game réduit : ×0.6 terrestre sur route, ×0.5 naval sur mer) et augmente le cargo transportable — voir [[Véhicules]].

## Liens
- **Dépend de** : [[Grille continue]], [[Unification macro-micro]], [[Génération par couches de bruit]]
- **Alimente** : [[Début de partie]], [[Boucle de jeu]], [[Donjons — structure et intégration]], [[Minimap et brouillard de guerre]]
- **Voir aussi** : [[Niveau de danger]], [[Dérive de la corruption]], [[Trésors et artefacts]], [[Biomes de départ]], [[Véhicules]]
