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

## 2. L'échelle : des anneaux de simulation avant tout langage

« Énormément de PNJ et de terrain » n'est pas d'abord une question de langage : une ville de 250 habitants coûte 3 ms par tick en GDScript, 2 500 habitants coûteraient 30 ms — et du C++ dix fois plus rapide ne tiendrait toujours pas 25 000. Ce qui tient, c'est de **ne pas simuler tout au même grain** :

- **l'anneau proche** (la fenêtre chargée : ~9 cellules) : le tick complet, chemins, vision, combat ;
- **l'anneau moyen** (les agglomérations du royaume, non chargées) : un tick grossier à l'heure, sans chemins ni vision — les routines se résolvent par téléportation entre postes, les stocks et les humeurs bougent ;
- **l'anneau lointain** (tous les territoires et royaumes connus) : la **semaine** qui existe déjà (`_semaine_villes`, `_semaine_royaumes_pays`).

Avant de coder l'anneau moyen : une **sonde d'échelle** (`sonde_echelle.tscn`) qui charge 500, 1 000 et 2 000 PNJ sur une grande fenêtre et donne le coût par système (`Simulation.chrono`). Elle dit où le temps part, et donc ce qu'un noyau C++ gagnerait vraiment.

## 3. Le C++ : un noyau pur, mesuré, jamais une réécriture

La règle « pas de GDExtension » (`AGENT.md`) devient : **une GDExtension seulement pour le noyau pur de calcul, après mesure, décidée ici**. Ce noyau, ce sont des fonctions sans règles de jeu : le chemin, la ligne et le champ de vue, les inondations et les composantes de la grille, plus tard le tick de routine de l'anneau moyen. L'état, les règles et les données restent en GDScript et en JSON : un module `Sim…` est déjà une bibliothèque de fonctions pures sur un état, il se porte tel quel.

Ordre : d'abord `AStarGrid2D`, l'A* en C++ **du moteur** (obstacles, poids par case), qui remplace `Grille.chemin` sans extension ; puis la sonde d'échelle ; puis, si la vision ou la génération restent chaudes, l'extension `sensen_grille` avec son outillage (Build Tools, SCons, godot-cpp — rien de tout ça n'est encore sur la machine). Le rendu, lui, se règle en commandes de dessin (terrain par cellule, êtres lointains en pictogramme, sprites) : [[Budgets de performance]].

## Liens
- **Dépend de** : [[Décisions d'architecture]], [[Budgets de performance]], [[Simulation à ticks]]
- **Alimente** : [[Arborescence du projet]], [[Entités et pathfinding — performance]], [[Simulation du monde — performance]]
- **Voir aussi** : [[Un monde réel — villes, PNJ, royaumes et calendrier]], [[À juger — parcours de jeu]]
