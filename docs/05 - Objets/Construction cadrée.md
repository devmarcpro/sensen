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

> [!success] Codé le 2026-08-28 — poser à la tuile sur le camp
> Intentions `poser` (un meuble ou une station portative du sac devient un contenu de tuile adjacente : `meuble`, `station_fixe`), `poser_mur` (**1 unité de pierre taillée, de planche ou de brique** → un mur construit, destructible, portant son matériau — décision : la note dit « coût en ressources et en temps » sans chiffre), `poser_porte` (1 planche → une porte, franchissable, qui coupe la vue), `demonter` (un meuble ou une station revient au sac ; un mur construit se démonte sans rendre son matériau, comme creuser). **Pas d'orientation** : tout se pose à la tuile, un mur est un bloc plein (décision). Les tuiles construites portent le tag `construit`. Coût en temps : `camp.poser_ticks` (10). Le modelage du terrain (élever/abaisser) attend la surface.

> [!success] Complété le 2026-08-29 — le modelage du terrain, et le signal réel
> Le callout ci-dessus disait « le modelage du terrain (élever/abaisser) attend la surface » : il est codé depuis (intention `terrasser`, ±1 de hauteur, pioche en main pour élever, bornes `terrasser.h_min`/`h_max`, terrain mémorisé et régénéré hors claim — voir *Destruction du terrain*). **Le signal** : la note prévoyait `block_placed` / `block_destroyed` ; l'implémentation n'en a qu'un, **`tile_changed(pos)`**, émis par toute mutation de tuile (contenu, hauteur, meuble, eau, feu) — le client redessine, et les quêtes de construction progressent par appel direct (`_progresser_quetes`) plutôt que par abonnement. Décision : un seul signal de mutation plutôt que deux signaux typés, tant qu'aucun système n'a besoin de distinguer *poser* de *détruire*.

## Liens
- **Dépend de** : [[Décisions fondatrices]], [[Claims et persistance]], [[Hauteur de terrain ±10]]
- **Alimente** : [[Détection de pièces]], [[Habitat des PNJ]], [[Expansion territoriale]], [[Destruction du terrain]]
- **Voir aussi** : [[Tables de sculpture]], [[Meubles]], [[Stations de transformation]], [[Quêtes et guildes]], [[EventBus]], [[Défense et raids]]
