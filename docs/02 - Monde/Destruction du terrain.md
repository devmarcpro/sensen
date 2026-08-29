---
aliases: ["Destruction du terrain", "Destruction", "Modelage du terrain"]
tags: [monde, construction, décidé]
domaine: monde
statut: décidé
etape: 2
---

Ce que le joueur peut détruire et modeler, et les deux garde-fous qui empêchent le vandalisme cumulé de casser le monde.

**Ce qui est permis ([[Hauteur de terrain ±10]]) :**
- **abaisser ou élever une tuile** (tranchée, talus) ;
- **détruire un mur ou un bâtiment** (la tuile redevient sol) ;
- **abattre un arbre**.

La destruction reste tactiquement lisible — effondrer le pont, ouvrir une brèche, inonder la tranchée — sans permettre le tunnel arbitraire. Elle vaut pour les bâtiments PNJ comme pour les siens ([[Construction cadrée]]).

**Ce qui disparaît ([[Construction cadrée]])** : la subdivision de blocs à résolution variable, le tunnel arbitraire, la forteresse voxel sculptée bloc à bloc.

**Deux garde-fous de simulation ([[Sorts cataclysmiques]]) :** le **plancher et le plafond de hauteur** (0 et 20) bornent naturellement le vandalisme cumulé ; la **régénération des cases sauvages** ([[Claims et persistance]]) répare le terrain hors des claims — le joueur peut défigurer le monde, le monde se soigne. Sur les cases claim en revanche, les dégâts **persistent**, ce qui rend une attaque de royaume réellement traumatisante.

**Gain technique ([[Décisions fondatrices]], [[Multijoueur]]) :** risque levé — destruction discrète à la tuile, beaucoup moins coûteuse et bien plus simple à synchroniser en réseau que la physique voxel fine. La destruction à la tuile se synchronise comme un événement discret (« cette tuile a été modifiée »), exactement comme Terraria/Minecraft.

**Explosions :** voir [[Explosions]].

> [!success] Décidé le 2026-08-27 — creuser dans le donjon
> Les murs du labyrinthe portent le tag `destructible` (`data/tile_contents.json`) ; le bord de la cellule est de la `roche` sans ce tag. Intention `creuser` (clic sur un mur adjacent) : **10 ticks, 6 d'endurance, 5 XP de Terrassement** (`combat_rules.creuser`), la tuile devient du sol. Pas encore de ressource récoltée ni d'outil requis (attend l'artisanat, étape 7) — le joueur peut donc tracer son propre chemin dans le labyrinthe au prix du temps et de l'endurance.

> [!success] Codé le 2026-08-28 — terrasser, et le monde qui se soigne
> Intention `terrasser` (clic droit sur une tuile de sol adjacente → *Abaisser* / *Élever*) : **±1 de hauteur** dans `[0, 20]`, `combat_rules.terrasser` (12 ticks, 8 d'endurance, 5 XP de Terrassement), refusée sur une tuile occupée, un contenu bloquant ou un meuble ; l'élévation exige une **pioche ou une pelle en main** (`fonct.outil` = `pioche`), l'abaissement se fait à mains nues — décision : la tranchée est toujours possible, le talus demande l'outil. **Régénération des cases sauvages** : chaque modification de terrain (creuser, terrasser, démonter) mémorise l'état d'origine dans `Simulation.modifs_terrain` (idx → {h, contenu}) ; **chaque semaine**, les modifications situées **hors des claims** sont annulées (hauteur et contenu rendus, seulement si la tuile est libre) — sur un claim elles persistent. Décision : la mémoire vit avec la grille chargée (elle n'est pas sauvegardée) ; une cellule rechargée depuis la fenêtre glissante repart de sa génération, ce qui est la régénération elle-même.

> [!success] Corrigé le 2026-08-29 — la mémoire du terrain suivait la fenêtre, pas le monde
> Suite du bug des feux. `modifs_terrain` (ce que le monde doit rendre) et `portails` (les brèches du Passeur) étaient des **index de grille** ; or la **fenêtre glisse** à chaque cellule traversée et les index changent de sens — `contenants` était remappé à la main, ces deux-là non. Conséquence : après une traversée de cellule, la régénération hebdomadaire restaurait des **hauteurs et des contenus au mauvais endroit** (elle réécrivait le terrain de la cellule d'arrivée), et un portail se retrouvait sur une tuile sans rapport. Les deux sont désormais indexés par **position monde** (`Vector2i`), qui ne bouge pas quand la fenêtre glisse ; `e.portails` aussi. Ils sont vidés au changement de lieu (camp ↔ donjon : deux espaces de coordonnées distincts).

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Grille continue]]
- **Alimente** : [[Sorts cataclysmiques]], [[Construction cadrée]], [[Défense et raids]]
- **Voir aussi** : [[Explosions]], [[Claims et persistance]], [[Multijoueur]], [[Risques majeurs]]
