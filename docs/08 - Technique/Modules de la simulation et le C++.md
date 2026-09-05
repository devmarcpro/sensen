---
aliases: ["Modules de la simulation", "Fragmentation de la simulation", "Le C++ dans Sensen"]
tags: [technique, architecture, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

# Modules de la simulation et le C++

> [!decision] Décidé le 2026-09-05, 21 h 15 — le designer a tranché en me laissant trancher
> « Je te laisse faire, je te fais confiance, fais au mieux » ; et la raison de fond : « je veux pouvoir simuler le plus de systèmes possible sur énormément de PNJ et de terrain, c'est aussi pour ça que je pense à la réécriture C++ ». Trois décisions, dans l'ordre où elles se font.

## 1. Fragmenter `simulation.gd` en bibliothèques statiques

`simulation.gd` compte 14 078 lignes et 558 fonctions ; ses sections datées ne suivent plus ses fonctions (la section « territoire » contient l'eau, la météo et les vampires). GDScript n'a ni classes partielles ni traits ; deux voies restaient :

- des **objets systèmes** (`RefCounted` tenant une référence à la simulation) : chaque module tient `sim`, la simulation tient ses modules — un **cycle de références** que Godot ne ramasse jamais, et la suite crée des centaines de simulations ;
- des **bibliothèques statiques** : chaque module est une classe de `static func` qui reçoit la simulation en **premier paramètre** (`SimVilles._peupler_fenetre(sim)`), l'état reste dans `Simulation`, le module ne tient rien. Pas de cycle, un appel aussi rapide qu'une méthode, et une fonction pure sur un état : exactement la forme qu'une bibliothèque C++ prendrait plus tard.

C'est la seconde. Règles :

- **L'état vit dans `Simulation`** (ses `var`), **les règles vivent dans les modules** (`godot/systems/simulation/sim_*.gd`, classes `Sim…`). Un module n'a aucune variable de classe.
- **L'API publique ne bouge pas** : tout ce que le client, les tests et les sondes appellent sur la simulation garde sa signature, par un **délégué d'une ligne** en fin de `simulation.gd` (`func perimetres() -> Array: return SimPerimetres.perimetres(self)`). À l'intérieur, la simulation appelle les modules directement.
- **Le découpage se fait par domaine, pas par date** : `SimLieux` (arène, camp, donjons, gouffres, étages de donjon), `SimTerrain` (eau, lave, feu, foudre, pluie, terrassement, cycle et météo), `SimCamp` (poser, coffres, dormir, voyager, parcelles, boutique passive), `SimPnj` (dialogue, commerce, traits, compagnons, quêtes, relations, réputation), `SimTerritoire` (claims, rôles, résidents, semaine, économie, contexte de territoire), `SimVilles` (calendrier du jour, transports, étages de bâtiments, peuplement d'une agglomération), `SimPerimetres` (périmètres de récolte, stockages, maisons, migrants), `SimRoyaumes` (états, ères, événements, conquête, lois, douanes, raids, gouvernance), `SimElevage` (entraîneur, capture, hérédité, couvées), `SimObjets` (ajouter un être, loot composé, apparence, inventaire, identification, contenants), `SimSauvegarde`, `SimFabrication` (craft, stations), `SimTalents` (grilles, talents, formes, armes fantômes, portails, affûts). Le cœur du combat reste dans `simulation.gd` : avancement, intentions, actions, statuts, actions de créatures, capacités, engagement, IA, serments — environ 4 600 lignes.
- **Le déplacement est outillé** (`tools/fragmenter.py`) : il déplace des plages de fonctions, qualifie chaque membre (`sim.grille`, `Simulation.slot_autosave`), ajoute `sim` aux appels, écrit les délégués, et signale ce qu'il ne sait pas décider (une fonction passée comme `Callable` sans parenthèses, une locale qui masque un membre). La suite complète juge le résultat : **aucun changement de comportement**.

> [!success] Codé le 2026-09-05, 23 h 55 — la fragmentation tient (suite complète verte, 1 915 vérifications, poussée en a97051e)
> `tools/fragmenter.py --ecrire` a produit les treize modules de `godot/systems/simulation/` : `simulation.gd` passe de 14 078 à 4 600 lignes de cœur (157 fonctions : avancement, intentions, actions, statuts, actions de créatures, capacités, engagement, IA, serments) plus 232 délégués d'une ligne ; les modules font de 290 (SimSauvegarde) à 1 071 lignes (SimObjets). L'outil se relance depuis l'original (`git checkout simulation.gd`, `rm` des modules) — il n'est pas incrémental. Ce qu'il a fallu lui apprendre : un commentaire qui finit par un point n'est pas un accès membre ; `tr()` n'existe pas en statique ; pendant l'analyse croisée de deux classes qui se citent, `var x := sim.f()` ne s'infère pas, il écrit le type ; `var x: T := v` est interdit ; `godot --check-only` ne charge pas les autoloads, seul `verif_scripts.py` juge. Aucun changement de comportement mesuré : le garde-fou É2 (génération d'un étage) donne 167 ms après contre 185 avant.

## 2. L'échelle : des anneaux de simulation avant tout langage

« Énormément de PNJ et de terrain » n'est pas d'abord une question de langage : une ville de 250 habitants coûte 3 ms par tick en GDScript, 2 500 habitants coûteraient 30 ms — et du C++ dix fois plus rapide ne tiendrait toujours pas 25 000. Ce qui tient, c'est de **ne pas simuler tout au même grain** :

- **l'anneau proche** (la fenêtre chargée : ~9 cellules) : le tick complet, chemins, vision, combat ;
- **l'anneau moyen** (les agglomérations du royaume, non chargées) : un tick grossier à l'heure, sans chemins ni vision — les routines se résolvent par téléportation entre postes, les stocks et les humeurs bougent ;
- **l'anneau lointain** (tous les territoires et royaumes connus) : la **semaine** qui existe déjà (`_semaine_villes`, `_semaine_royaumes_pays`).

Avant de coder l'anneau moyen : une **sonde d'échelle** (`sonde_echelle.tscn`) qui charge 500, 1 000 et 2 000 PNJ sur une grande fenêtre et donne le coût par système (`Simulation.chrono`). Elle dit où le temps part, et donc ce qu'un noyau C++ gagnerait vraiment.

> [!success] Mesuré le 2026-09-06, 0 h 30 — la sonde d'échelle existe (`sonde_echelle.tscn`), et sa première leçon n'est pas le C++
> Monde 9, la ville « Mokroslav » (188 habitants, cinq cellules, fenêtre 192 × 192), 200 ticks mesurés après une chauffe, puis ses résidents clonés (même métier, même lit, même poste, même assignation) jusqu'au compte :
>
> | êtres | avant (ms par tick) | après | par être |
> |---|---|---|---|
> | 197 | 1,83 | 1,20 | 6 µs |
> | 501 | 3,43 | 2,58 | 5 µs |
> | 1 002 | 5,74 | 3,39 | 3 µs |
> | 2 000 | 13,36 | 4,84 | 2 µs |
>
> « Avant », à 2 000 êtres, la **faim** et la **météo** coûtaient 8,6 ms des 13,4 : deux règles qui ne s'appliquent qu'au joueur balayaient les deux mille entités à chaque tick pour le trouver. `Simulation.joueurs()` garde la liste des êtres contrôlés par le joueur (validée à chaque appel : même compte d'entités, chacun encore là et encore « joueur », marquée sale par « incarner ») ; la faim, la météo et la vision la lisent. Ce qui reste à 2 000 êtres, c'est `pas` (3,8 ms) : `_prochaine()` cherche l'entité au plus petit compteur par un balayage complet à **chaque** pas, et deux cents êtres agissent par tick — un tas par compteur (avec le rang dans `ordre` pour départager, entrées périmées ignorées) le ramènerait au logarithme, mais chaque écriture de `compteur` devrait le prévenir, et il y en a partout : c'est un chantier à part, pas une retouche. Le chemin (`ia.chemin_routine`) n'apparaît même plus dans les dix premiers postes : **`AStarGrid2D` n'a rien à gagner ici** — et il ne rendrait pas les coûts d'arête asymétriques (la pente) ni l'`ignorer` des occupants. Le budget d'une image est de 12 ms : 2 000 êtres chargés tiennent déjà à 4,8 ms par tick. La prochaine marche est l'anneau moyen, pas le langage.

> [!decision] Décidé le 2026-09-06, 1 h — l'anneau moyen, première version : **la semaine des villes endormies**
> Jusqu'ici une ville sortie de la fenêtre se figeait : ses gens dormaient dans `Monde.dormants`, sa semaine ne tournait pas (`_semaine_villes` ne prenait que les territoires chargés), personne n'y vieillissait. L'anneau moyen v1 fait tourner **la même semaine, sans grille** :
> - `residents()` compte aussi les résidents endormis des cellules du territoire hors fenêtre — pour une ville comme pour le camp du joueur (« un camp et une ville sont identiques ») : la base continue de produire quand on s'en éloigne ;
> - la semaine de toutes les villes connues tourne (production des postes et des fonctions, repas, économie, prix, taxe au royaume, dette, transition de gouvernance, accords), les parties qui lisent la grille se retirent d'elles-mêmes (les maisons ne se bâtissent que dans la fenêtre, le garde-manger n'est lu que chargé) ;
> - **les champs hors fenêtre** ne poussent pas à l'heure : une parcelle rend `anneau_moyen.rendement_par_parcelle` toutes les `anneau_moyen.semaines_par_recolte` ; **le bétail** endormi produit comme le chargé ; **l'âge** avance aussi pour les endormis (et la mort de vieillesse les prend) ;
> - **l'humeur** d'un résident logé hors fenêtre reçoit `anneau_moyen.humeur_logement` à la place du bonus des meubles qu'on ne voit pas (sinon, tout le monde était « sans logement » loin des yeux).
> Pas de tick à l'heure hors fenêtre dans cette version : la boutique et les parcelles rattrapent leurs heures au retour (`heures_max_rattrapage`), ce qui existait déjà. Test `test_anneau_moyen` : partir, la ville compte encore ses gens, une semaine passe, son rapport tombe, ses stocks et son trésor bougent, on revient, ils sont là.

> [!success] Codé le 2026-09-06, 1 h 20 — l'anneau moyen v1 tient (`test_anneau_moyen`)
> Monde 9, la ville « Hangan » (126 résidents) : on y va, on repart au camp, elle sort de la fenêtre ; ses 126 résidents comptent toujours ; une semaine passe : son rapport tombe, un endormi a vieilli (29,000 → 29,019 ans), les logés hors fenêtre ont le bonus de logement, ses stocks (143) et son trésor (696) bougent, ses prix sont recalculés ; on y retourne : 126 réveillés et chargés. Bloc `anneau_moyen` de `villes.json` (schéma à jour). La suite complète juge le reste.

## 3. Le C++ : un noyau pur, mesuré, jamais une réécriture

La règle « pas de GDExtension » (`AGENT.md`) devient : **une GDExtension seulement pour le noyau pur de calcul, après mesure, décidée ici**. Ce noyau, ce sont des fonctions sans règles de jeu : le chemin, la ligne et le champ de vue, les inondations et les composantes de la grille, plus tard le tick de routine de l'anneau moyen. L'état, les règles et les données restent en GDScript et en JSON : un module `Sim…` est déjà une bibliothèque de fonctions pures sur un état, il se porte tel quel.

Ordre : d'abord `AStarGrid2D`, l'A* en C++ **du moteur** (obstacles, poids par case), qui remplace `Grille.chemin` sans extension ; puis la sonde d'échelle ; puis, si la vision ou la génération restent chaudes, l'extension `sensen_grille` avec son outillage (Build Tools, SCons, godot-cpp — rien de tout ça n'est encore sur la machine). Le rendu, lui, se règle en commandes de dessin (terrain par cellule, êtres lointains en pictogramme, sprites) : [[Budgets de performance]].

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Budgets de performance]], [[Simulation à ticks]]
- **Alimente** : [[Arborescence du projet]], [[Entités et pathfinding — performance]], [[Simulation du monde — performance]]
- **Voir aussi** : [[Un monde réel — villes, PNJ, royaumes et calendrier]], [[À juger — parcours de jeu]]
