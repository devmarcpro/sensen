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

## Liens
- **Dépend de** : [[Détection de pièces]], [[Dérive de la corruption]], [[Habitat des PNJ]]
- **Alimente** : [[Conquête de village]], [[Population et exploitation]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Âge des PNJ]], [[Claims et persistance]], [[Créatures]], [[Simulation du monde — performance]]
