---
aliases: ["3.4", "3.4 Villages PNJ", "Repeuplement", "Décimation"]
tags: [monde, société, simulation, décidé]
domaine: monde
statut: décidé
etape: 9
---

Comment un village vit, se repeuple, et ce qui arrive quand on le vide entièrement.

**Repeuplement (cadence hebdomadaire, même horloge que [[Claims et persistance]]/[[Économie — sources et puits]]/[[Dérive de la corruption]]) :**
- Chaque village a une **capacité** dérivée du nombre de pièces habitables détectées (même algorithme que l'habitat du joueur, [[Habitat des PNJ]]/[[Détection de pièces]], appliqué aux bâtiments du village).
- Chaque semaine, un village sous sa capacité a une chance de gagner un nouveau résident (immigration/nouvelle génération abstraite — pas de simulation de naissance individuelle), qui reprend un poste vacant (`jobs_compatible`, [[Population et exploitation]]).
- La vitesse de repeuplement est **modulée par la corruption locale** ([[Dérive de la corruption]]) : un village dans une zone pacifiée par le joueur repeuple vite ; un village menacé stagne ou décline — la même pression civilisatrice qui éloigne le danger nourrit aussi la vie.

**Décimation totale (conséquence assumée) :** un village peut être **entièrement vidé** si le joueur (ou un raid, un monstre) tue ses habitants plus vite qu'ils ne repeuplent. Un village à 0 population devient un **POI abandonné** : bâtiments et meubles intacts et persistants (aucune régénération ne les efface — c'est un site claim-like), mais sans résidents ni services. Un village vidé peut être **réoccupé** par le joueur lui-même (assigner ses propres PNJ recrutés dans les logements déjà debout — réutilisation directe du bâti existant, sans reconstruire) ou repeupler naturellement à très long terme si la zone se pacifie.

**Décisions :**
- **Capacités par taille (pièces habitables générées) :** hameau 4-8, village 8-20, ville 20-60, capitale 60+. Vitesse de repeuplement : formule [[Conquête de village]] (`0.15 × sous-capacité × pacification`).

*Le moteur démographique interne (naissances, lignées) est complémentaire de l'immigration — voir [[Âge des PNJ]].*

> [!success] Codé le 2026-08-28 — étape 9.A, le hameau (`Surface._poser_village`, `data/village_buildings/`)
> Cellule à POI **village (4 %)** : un **hameau** — une place centrale, **3 à 5 bâtiments préfab** (grilles de caractères comme les salles de donjon : maison, échoppe, grange) posés autour de la place et reliés par des **chemins** en `sol` de la palette du biome, murs en `mur` de la palette (`village_palette`), portes, meubles (lits, tables, étal). Population : 1 résident par lit + un **marchand** dans l'échoppe + un **garde** sur la place (presets de [[Profils de PNJ]]), nommés par la culture du village (tirée par la race dominante — humain — parmi les 7 cultures), le village lui-même nommé (`ville_a + ville_b`). Les PNJ sont instanciés à la **première visite** de la cellule puis persistent (endormis hors fenêtre). Routes par A*, tailles ville/capitale, repeuplement et décimation attendent 9.B-10.

> [!success] Constaté le 2026-09-03 — `jobs_compatible` n'existe pas : un PNJ a **une** `fonction`
> Le code ne tient pas de liste de métiers compatibles par créature : une fiche porte une `fonction` (commerçant, forgeron, garde…) et le repeuplement tire des fiches entières, pas des métiers. Si la compatibilité de métiers redevient nécessaire, elle sera un champ neuf, pas celui-ci.

## Liens
- **Dépend de** : [[Détection de pièces]], [[Dérive de la corruption]], [[Habitat des PNJ]]
- **Alimente** : [[Conquête de village]], [[Population et exploitation]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Âge des PNJ]], [[Claims et persistance]], [[Créatures]], [[Simulation du monde — performance]]

> [!success] Mesuré le 2026-09-04 — un hameau sur la durée (`sonde_village`)
> Monde 9, le hameau voisin du camp : quatre habitants pour quatre lits, **corruption 79 %**. La moitié tuée : chance de repeuplement `0,15 × (1 − 2/4) × (1 − 0,79)` = **1,5 % par semaine** — la première arrivée tombe à la **vingt-neuvième semaine**, aucune naissance (personne n'y est marié). Décimé : abandonné dès la semaine suivante, et toujours vide douze semaines plus tard. C'est la note à la lettre : « un village menacé stagne ou décline » ; la pacification par le joueur est ce qui le ferait repeupler — les chiffres sont dans [[À juger — parcours de jeu]].
> Sur cinquante-deux semaines : le hameau revient à quatre sur quatre (arrivées à la vingt-neuvième puis plus tard) ; ses habitants ont de 24 à 39 ans pour 72 à 90 d'espérance — personne ne meurt de vieillesse dans l'année, le moteur démographique ne se voit qu'à l'échelle de décennies.

