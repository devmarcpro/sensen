---
aliases: ["E.18", "Annexe E.18", "LOD de simulation", "E.18.2", "Trois niveaux de simulation", "Niveau logique"]
tags: [êtres, technique, décidé]
domaine: êtres
statut: décidé
etape: 9
---

Trois niveaux de simulation des PNJ selon leur distance au joueur, avec des transitions invisibles. C'est ce qui fait que les villages paraissent vivants.

Pattern Dwarf Fortress/RimWorld : le niveau de simulation d'un PNJ dépend de sa distance au joueur, avec des transitions invisibles.

```
NIVEAU 1 — PLEIN (chunks chargés autour du joueur) :
  IA utility complète (E.16), pathfinding réel, physique, rendu.

NIVEAU 2 — LOGIQUE (zone claim/ville CONNEXE à celle du joueur, mais
  hors chargement — ex. l'autre bout de sa base ou du village visité) :
  Le PNJ vit sur le GRAPHE DES POINTS D'INTÉRÊT de la zone :
    nœuds = lits (pièces E.5), postes de travail (jobs 14.2), étals,
    tavernes, portes... ; arêtes = distances précalculées sur la
    nav-grille (E.16), invalidées par modifications de blocs.
  État du PNJ = {POI courant OU transit(POI_a → POI_b, progression),
    agenda} — tout avance par COÛTS DE TICKS identiques au niveau 1 :
    durée de trajet = distance_graphe * coût_tick/bloc, les actions de
    routine (travailler, manger, dormir) durent leur temps réel.
  Les actions se résolvent par formules (le fermier produit, le client
  achète — mêmes formules que E.6/E.8) : timings honnêtes, coût quasi
  nul (une entrée d'agenda + un timer par PNJ ; ~100 PNJ logiques ≈
  le coût de 3 PNJ pleins).

NIVEAU 3 — ABSTRAIT (aucun joueur dans la zone) : E.6, résolution à
  gros grain par période, pas de PNJ individuels actifs.

TRANSITIONS :
  2 → 1 (le joueur approche) : matérialisation par interpolation — un
    PNJ "en transit à 60 %" est spawné à 60 % du chemin sur le graphe.
    Jamais de téléportation visible : la ville semble avoir vécu.
  1 → 2 (le joueur s'éloigne) : l'état plein est projeté sur le graphe
    (POI le plus proche, action en cours convertie en agenda).
  2 ↔ 3 : sérialisation/désérialisation vers l'état abstrait (E.6).
ÉVÉNEMENTS EN ZONE LOGIQUE (ex. raid sur un quartier hors écran) :
  joueur assez proche → chargement forcé + matérialisation du combat ;
  sinon → résolution par formule (E.6/E.7) pour ce sous-événement.

Le niveau 2 sert AUSSI les villages PNJ traversés par le joueur : même
mécanisme, zéro système supplémentaire — les villages paraissent vivants.
```

**Meubles comme nœuds du graphe ([[Meubles]]) :** lits, étals, garde-mangers, tables — *requis pour l'habitat et les POI du graphe E.18*.

> [!success] Partiellement codé — trace ajoutée le 2026-09-04
> Le LOD 1 existe : la fenêtre 3×3 de cellules autour du joueur est simulée (`Monde`, `_verifier_fenetre`), le reste du monde avance par semaines abstraites (`_tiquer_monde`, `_semaine_territoire`). Le **LOD 2** décrit ici — un graphe de POI où les PNJ voyagent hors fenêtre — **n'est pas codé** ; les villages hors fenêtre sont figés.


> [!success] Codé le 2026-09-04 — le niveau 2 par **projection au réveil**
> Le designer a demandé de finaliser les systèmes plutôt que les sous-classes ; le niveau logique était le plus gros « non codé » du coffre. Ce qui est codé n'est pas le graphe de POI qu'on tique : c'est **son résultat observable, calculé au moment où il compte**. Un PNJ mis de côté hors fenêtre porte `dormant_depuis` (le tick du monde) ; quand sa cellule rentre dans la fenêtre — retour d'expédition, marche, chargement —, `Simulation._projeter_routine` le remet **là où sa routine l'aurait mené** : à son poste, sa place ou son lit selon l'heure (`ai_profiles.horaires`, la même table que le niveau 1), ou **en chemin** entre l'ancien et le nouveau but si l'heure vient de tourner — au pas près, sur le chemin réel de la grille (`Grille.chemin`, `Regles.ticks_deplacement`). Jamais de téléportation visible : la cellule était hors fenêtre, donc hors vue.
> **Pourquoi pas un graphe qui tique.** Le résultat est le même — la position d'un PNJ de routine ne dépend que de l'heure et du chemin entre ses deux buts — et le coût pendant l'absence est **nul** au lieu d'un timer par PNJ. Le jour où un PNJ dormi devra *produire* ou *acheter*, c'est le passage hebdomadaire (`_tiquer_monde`, niveau 3) qui le fait déjà par formules, comme la note le veut. Une absence plus courte que `planete.routine.projection_min_ticks` ne projette rien.
> **Ce qui reste non codé** : les arêtes précalculées du graphe (inutiles tant qu'on projette), et les **événements en zone logique** — un raid sur un quartier hors écran se résout aujourd'hui par le passage hebdomadaire des royaumes, pas par une matérialisation forcée.

## Liens
- **Dépend de** : [[IA des créatures]], [[Détection de pièces]], [[Boucle de tick]]
- **Alimente** : [[Abstraction hors-site]], [[Villages PNJ — repeuplement et décimation]], [[Raids et menaces]]
- **Voir aussi** : [[Population et exploitation]], [[Boutique passive]], [[Meubles]], [[Entités et pathfinding — performance]], [[Météo]], [[Génération des royaumes PNJ]]
