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

**Gain technique ([[Décisions fondatrices]], [[Multijoueur]]) :** risque levé — destruction discrète à la tuile, beaucoup moins coûteuse et bien plus simple à synchroniser en réseau que la physique voxel fine. La destruction par blocs pleins se synchronise comme un événement discret (« ce bloc a été détruit »), exactement comme Terraria/Minecraft.

**Explosions :** voir [[Explosions]].

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Grille continue]]
- **Alimente** : [[Sorts cataclysmiques]], [[Construction cadrée]], [[Défense et raids]]
- **Voir aussi** : [[Explosions]], [[Claims et persistance]], [[Multijoueur]], [[Risques majeurs]]
