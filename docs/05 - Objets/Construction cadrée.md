---
aliases: ["4.1", "4.1 Construction cadrée", "Construction cadrée", "Construction"]
tags: [objets, construction, décidé]
domaine: objets
statut: décidé
etape: 7
---

La construction libre à la Minecraft est écartée. Ce qui subsiste est fonctionnel et lisible : des empreintes de bâtiments et du modelage de terrain.

La construction libre à la Minecraft est **écartée** : elle n'a pas de sens sur une grille et n'est pas le cœur du jeu. Ce qui subsiste est fonctionnel et lisible :

- **Empreintes de bâtiments** : un bâtiment est une empreinte de tuiles + une hauteur de murs, posée depuis un catalogue ou dessinée tuile par tuile sur ses cases claim ([[Claims et persistance]]). La **détection de pièces** ([[Détection de pièces]], qui pilote le logement des PNJ) devient triviale en 2D.
- **Modelage du terrain** : élever ou abaisser une tuile (talus, tranchée, terrasse), avec un coût en ressources et en temps. C'est le successeur du minage — on façonne le sol, on ne creuse pas de galeries.
- **Aménagement** : murs, portes, sols, meubles ([[Meubles]]), stations d'artisanat, pièges, palissades — tout se pose à la tuile.
- **Destruction** : voir [[Destruction du terrain]]. Elle vaut pour les bâtiments PNJ comme pour les siens.
- **Ce qui disparaît** : la subdivision de blocs à résolution variable, le tunnel arbitraire, la forteresse voxel sculptée bloc à bloc.
- **Ce qui survit** : les **tables de sculpture** ([[Tables de sculpture]]) pour les **objets** — armes, meubles, véhicules — désormais en pixel art paramétrique plutôt qu'en voxel.

**Contrats de construction ([[Quêtes et guildes]]) :** la guilde développement de ville/royaume donne des contrats de construction réels, validés par la détection de pièces.

**Signal :** `block_placed/destroyed` sur l'EventBus, écouté par la détection de pièces, les quêtes bâtisseur et le réseau ([[EventBus]]).

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Claims et persistance]], [[Hauteur de terrain ±10]]
- **Alimente** : [[Détection de pièces]], [[Habitat des PNJ]], [[Expansion territoriale]], [[Destruction du terrain]]
- **Voir aussi** : [[Tables de sculpture]], [[Meubles]], [[Stations de transformation]], [[Quêtes et guildes]], [[EventBus]], [[Défense et raids]]
