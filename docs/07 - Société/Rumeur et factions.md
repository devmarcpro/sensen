---
aliases: ["Rumeur", "Factions", "Tags idéologiques", "Réputation par faction"]
tags: [société, émergence, codé]
domaine: société
statut: codé
etape: 7
---

Un acte laisse un **fait tagué** ; le fait **met du temps** à parcourir la carte ; la réputation d'une faction envers quelqu'un est la **somme de ce que ses valeurs pensent des faits qu'elle connaît**.

> [!success] Codé le 2026-09-09 — **la rumeur qui circule et les factions qui l'écoutent** (ordre de travail 29 et 29 bis ; designer 2026-09-08 : « réputation par factions, une faction par espèce »)
> **LES DEUX LIGNES SONT UN SEUL SYSTÈME**, et la file le disait : *elle transporte le fait, la faction décide qui s'en offusque*. Écrire l'une sans l'autre, c'est un champ qui ne mène nulle part, ou des valeurs que rien n'alimente.
>
> **RIEN NE SE PROPAGE, ET C'EST CE QUI REND LE SYSTÈME GRATUIT.** Un observateur à `d` cellules du fait le sait à partir de `fait.tick + d × ticks_par_cellule` : on le **déduit**, exactement comme le stade d'une dépouille se déduit de l'heure de la mort. Aucune boucle ne colporte, aucun état ne s'accumule, et **la réputation n'est jamais comptée deux fois** — elle est une *fonction* des faits connus, pas un compteur qu'on incrémente. Elle s'efface donc **toute seule** quand les faits vieillissent, ce qui est exactement ce qu'on attend d'une rancune. *La seule chose qui s'oublie par décision est le plafond de la liste : au-delà de `faits_max`, le plus ancien tombe.*
>
> **L'ACTE NE JUGE PAS.** Il pose des tags — `sang_verse`, `nature_detruite`, `industrie`, `vol`, `cruaute`, `entraide`… — et ce sont les **valeurs** d'une faction qui décident. Un arbre abattu fâche les Gardiens des bois et laisse les gens d'armes de marbre ; un meurtre dans la rue fait l'inverse. **Un acte de plus est une ligne de donnée, pas une règle.**
>
> **UNE ESPÈCE EST UNE FACTION, sans un fichier de plus.** Tout acte contre une bête porte le tag `espece:<id>`, et la faction implicite de cette espèce ne value **que ce tag-là**. *Chasser les cerfs jusqu'au dernier fâche donc les cerfs* — et personne d'autre, sauf ceux dont les valeurs disent que le sang versé compte. C'était le manque nommé par la file : « aujourd'hui, chasser les cerfs jusqu'au dernier ne fâche personne ».
>
> **CE QUI LE REND VISIBLE** : `SimPnj.relation_de` ajoute l'opinion des factions du PNJ à ce qu'il sait de lui-même. Un garde qui n'a **jamais vu** le joueur le regarde de travers si la nouvelle du meurtre est arrivée jusqu'à son village — et un bûcheron s'offusque de l'arbre que le garde ignore.
>
> **UNE PRÉCAUTION, APPRISE D'UN LAG PRÉCÉDENT** : `relation_de` est appelé par l'IA pour chaque paire d'êtres et à chaque pas. Refaire la somme de deux cent quarante faits à chaque regard serait le lag en ville — le dépôt en a déjà payé un avec la carte de lumière refaite à chaque tick. L'opinion se garde **par paire**, et se refait quand un fait nouveau arrive ou quand assez de temps a passé pour que la fraîcheur ait bougé.

## Les cinq factions nommées

| faction | ce qu'elle compte |
|---|---|
| **Gardiens des bois** | la nature détruite, la chasse, l'industrie — et se moquent de qui commande |
| **Compagnies de métier** | ce qui produit ; détestent le vol et ce qui trouble le commerce |
| **Gens d'armes** | l'ordre ; le sang versé dans la rue est leur affaire, celui d'une bête dans les bois ne l'est pas |
| **Petit peuple** | qui aide et qui frappe, et rien d'autre ne les regarde beaucoup |
| **Cercle du soufre** | la cruauté et le désordre les amusent, l'entraide les ennuie — on ne s'en fait des amis qu'en faisant ce que les autres réprouvent |

**On appartient à une faction** par sa race, par sa fonction de village, ou par un tag d'être — et l'on peut appartenir à plusieurs : un garde nain est à la fois gens d'armes et compagnie de métier, et sa relation les additionne.

> [!success] Complété le 2026-09-09 au soir — **le PNJ colporte**
> **La rumeur existait et personne ne pouvait l'entendre.** Un fait tagué parcourait la carte, les factions s'en offusquaient, la relation d'un PNJ en tenait compte — mais **aucun PNJ ne le disait**. Un joueur voyait donc un garde le regarder de travers *sans jamais apprendre pourquoi*, et le système entier restait de la plomberie.
> La réplique **« on raconte »** dit le fait le plus **frais** arrivé jusqu'ici — jamais un fait dont le PNJ est l'auteur, jamais un fait dont la nouvelle n'est pas encore là (la fraîcheur le dit déjà, il suffit de la respecter). **Et le ton vient des VALEURS de celui qui parle, pas d'une table de phrases** : la même somme qui décide de sa relation décide de son indignation. *Le bûcheron s'indigne de l'arbre abattu, le garde hausse les épaules, le Cercle du soufre s'en amuse* — un seul fait, trois tons, et rien d'écrit deux fois.

## Ce qui reste

- **Les royaumes ne portent pas encore de valeurs.** `Surface._lier_royaumes` reste une fonction **pure de la graine** : deux royaumes ne se haïssent toujours pas *pour quelque chose*. C'est la suite naturelle, et elle demande qu'un royaume porte des valeurs comme une faction.
- ~~Le dialogue ne colporte pas encore~~ — **fait le 2026-09-09 au soir** (voir le callout ci-dessus).
- **L'écran ne montre pas les factions** — la réputation à l'écran est la ligne 38.

## Liens
- **Dépend de** : [[Réputation et relations]]
- **Alimente** : [[Génération des royaumes PNJ]], [[Dialogue PNJ]]
- **Voir aussi** : [[Créatures]], [[Races]], [[Fonctions]]
