---
aliases: ["5.1", "5.1 Combat", "Combat tactique", "Combat"]
tags: [combat, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les règles générales du combat : pas de jet de toucher, la géométrie décide, et la lisibilité EST le game feel.

**Combat tactique sur grille, en action-time** ([[Action-time à ticks]]) :

- **Pas de jet de toucher.** Une cible à portée est touchée. Ce qui décide de l'issue, c'est le **placement**, le **tempo** (coûts en ticks) et les **éléments** — jamais un jet d'esquive.
- **Zones dérivées du DÉNIVELÉ**, jamais visées : voir [[Zones de coup par dénivelé]].
- **Portée en tuiles** : chaque arme a sa portée (1 pour une dague, 2 pour une lance, N pour un arc) et éventuellement un **minimum** (une lance est mauvaise au contact). L'allonge devient de la géométrie de grille.
- **Garde en posture** : voir [[Garde en posture]].
- **Attaque lourde** : voir [[Attaque lourde et télégraphe]].
- **Endurance longue et lente** ([[Endurance]]) : le combat se gère sur la durée. Attendre est une action qui rend de l'endurance.
- **Les jets de dés survivent hors combat** : le **jet de compétence universel** (1d20 + compétence/2 + stat/4 vs difficulté) reste la résolution de la lecture ([[Lecture des livres]]), du dressage, de la négociation, de la discrétion ([[Lois et infractions]]), de la capture. Voir [[Jet de compétence universel]].
- **Les dés de dégâts restent** : chaque arme a ses dés ([[Pipeline de résolution du combat]]).
- **La lisibilité EST le game feel** d'un tactique : timeline des prochaines actions, coûts en ticks affichés sur les tuiles atteignables, prévisualisation des dégâts avec le détail du calcul, journal de combat. L'effort visuel passe là, pas dans l'animation.
- **Structure des compétences (façon Noita + Elin)** : voir [[Structure compétences-modules-slots]].
- **Ciblage des modules sur la grille** : les modules ont une **portée en tuiles** et une **forme d'effet** (cible unique, ligne, cône, zone en croix ou en carré) prévisualisée avant validation — l'assemblage façon Noita produit des *formes*, pas des trajectoires physiques. La ligne de vue est bloquée par le dénivelé ([[Hauteur de terrain ±10]]).
- **Progression infinie par l'usage (façon Elin) :**
  - Les modules montent de niveau en étant utilisés, sans plafond.
  - Les types d'armes montent de niveau en étant utilisés, sans plafond.
  - **L'XP de combat vaut les dégâts appliqués** ([[XP de combat]]) — trois pistes simultanées.
- **Statuts de contrôle** : voir [[Statuts de contrôle et anti-stunlock]].
- **Compagnons** : ils agissent à leur propre compteur, comme toute entité. Le joueur leur donne des **consignes** (suivre / tenir la position / cibler en priorité / repli / posture agressive-défensive) modifiables à tout moment, gratuitement — donner un ordre ne coûte pas de ticks, seul l'agir en coûte. Voir [[Compagnons]].

**Acquisition des modules :** voir [[Grimoires et manuels]].

**Les sept trous du combat sont tranchés :** [[Décision — Multi-ennemis et jauge]] · [[Décision — Vocabulaire d'attaque des créatures]] · [[Décision — Fuite et désengagement]] · [[Décision — Chaîne côté ennemis]] · [[Décision — Boucliers]] · [[Décision — Projectiles]] · [[Décision — Esquive active]] (historique : [[Trous connus du combat]]).

> [!success] Codé le 2026-09-01 — la zone de lancer s'allume en vert (designer)
> « avant de lancer un sort la zone où le sort peut être placé devrait être en vert ». Jusqu'ici, une capacité visée ne montrait sa forme **que sous le curseur** : il fallait promener la souris pour découvrir jusqu'où on pouvait poser le sort, et une tuile refusée ne se distinguait qu'après coup. Dès qu'une capacité est visée, **toutes les tuiles où elle peut être placée** s'allument en vert pâle (`capacite_visable` par tuile, dans le carré de sa portée maximale) ; la forme visée continue de se dessiner par-dessus, en bleu, sous le curseur. Une portée nulle (`soi`) n'allume que la case du lanceur.


> [!success] Décidé le 2026-09-01 — une portée est un disque, plus un carré (designer)
> « on voit sur les captures que la portée n'est pas bonne, ça ne devrait pas être un carré ». C'était exact et visible : la zone verte formait un carré parfait alors que l'aperçu dessinait, juste à côté, un **anneau rond**. La cause : `Grille.distance` est une distance de Tchebychev (le maximum des deux écarts), et une boule de Tchebychev **est** un carré. Elle reste la mesure du **contact et du déplacement** — deux cases en diagonale sont bien voisines. Mais la **portée d'une capacité** se mesure désormais en **distance euclidienne arrondie** (`Grille.portee_entre`) : à portée 6, une cible en diagonale est à 8 cases de vol d'oiseau, donc hors de portée — ce que le carré autorisait. Le disque est ce que l'anneau de l'aperçu promettait depuis le début.



> [!important] Décidé le 2026-09-08, 14 h — **chaque membre est simulé** : un personnage cesse d'être une entité avec une barre de vie (designer : « on va faire en sorte que les personnages ne soient pas juste une entité avec une barre de vie mais que chaque membre soit simulé »)
> **La bonne nouvelle d'abord : la géométrie existe déjà, ce sont les conséquences qui manquent.** Le dépôt porte cinq zones (`tete` ×2,5, `torse` ×1,0, `bras`, `jambes` ×0,8, `pieds`) avec leur table de répartition moyenne, une **armure par pièce** (dureté composite × qualité × matrice construction/type de dégâts), un squelette (`skeleton_template`) et un paperdoll par emplacement.
> **Ce qui n'existe pas** :
> - **Un membre n'a pas d'état.** Tous les dégâts tombent dans un seul `sante`. Aucune blessure, aucune fracture, aucune perte de fonction.
> - **La zone frappée n'est pas choisie** : elle est décidée par le seul **dénivelé** — l'attaquant plus haut frappe la tête, à égalité le torse, plus bas les jambes. Conséquence directe et jamais relevée : **`bras` et `pieds` ne sont jamais touchés** par un coup ordinaire, alors qu'ils figurent dans la table des moyennes.
> - Donc la zone ne sert aujourd'hui qu'à **multiplier un nombre**. C'est exactement « une entité avec une barre de vie ».
>
> **Ce que la simulation par membre ferait émerger** (et pourquoi c'est une règle du monde, pas une mécanique de combat) : un bras brisé qui empêche l'arme à deux mains, une jambe qui double le coût de déplacement, une main qui lâche ce qu'elle tient, une hémorragie qui tue après le combat si on ne la soigne pas, un ennemi qui **fuit parce qu'il est estropié** et non parce qu'un seuil de PV est passé. Et surtout : **la médecine, l'infirmité durable et le temps de convalescence** deviennent du jeu.
>
> **Ce que ça touche, et il faut le dire avant de commencer** : `degats_finaux` et `_appliquer_degats` sont le cœur le plus chaud du code, l'IA décide sur des considérations qui liraient l'état des membres, le HUD et le paperdoll doivent le montrer, et **la suite entière suppose une seule jauge de santé**. C'est un chantier lourd — mais il se raccorde à deux décisions déjà prises : un **module de sort devient une modulation d'une règle du monde** (donc « viser un membre » est une règle, pas un effet), et la **quantité de mouvement** qui écrase (un rocher qui tombe brise un os plutôt que de retirer des points).
>
> **Trois questions qui ne sont pas à moi** :
> - **Quel grain ?** Une intégrité par zone (0-100), ou des blessures nommées qu'on accumule (entaille, fracture, brûlure, hémorragie) ?
> - **Jusqu'où va l'irréversible ?** Un membre peut-il être perdu pour de bon — et le joueur peut-il finir manchot pour le reste de la partie ?
> - **Est-ce que ça vaut pour tout le monde ?** Les cinq zones humanoïdes ne vont ni à un loup, ni à un essaim, ni à une calèche. Faut-il des silhouettes par squelette (`silhouette: humanoide` existe déjà sur la fiche de créature) ?


> [!important] Élargi le 2026-09-08, 21 h — le corps devient un **plan de parties**, avec des membres qu'on perd, qu'on remplace, qu'on ajoute, et des **organes qui coûtent de la place** (designer : « un personnage est composé de membres, un personnage peut perdre ses membres, les membres peuvent être remplacés ou même certains rajoutés, membres et organes — plusieurs estomacs = pouvoir manger plus mais demande plus de place »)
> **Ce que ça change par rapport au callout précédent** : celui-ci parlait de donner un *état* aux cinq zones existantes. Ici, la liste elle-même devient variable. Ce n'est plus « la tête a 40 points de vie », c'est **« ce corps a deux bras, et il pourrait en avoir un, ou trois »**.
>
> **Ce qui existe aujourd'hui tient en une étiquette.** L'anatomie entière est `corps.silhouette` = `"humanoide"`, plus une **liste d'exceptions** : une silhouette non humanoïde ne peut équiper que les emplacements listés dans `talents.incarnation.slots_bete` — c'est ainsi qu'un cerf refuse un casque (« pas de mains »). Il n'y a pas de partie du corps dans les données : il y a un mot, et un cas particulier.
>
> **Les quatre choses demandées, et ce que chacune coûte :**
> - **Perdre un membre.** C'est la suite directe de l'état par zone : un membre a une intégrité, et sous un seuil il est perdu. Le vrai coût n'est pas là — il est en dessous.
> - **Les emplacements d'équipement doivent DÉRIVER du corps.** C'est le point le plus lourd, et il est structurel : `e.equipement` a aujourd'hui des clés **fixes** (`main_principale`, `main_secondaire`, la tête, le torse…). Perdre un bras doit retirer un emplacement, en gagner un doit en ajouter. Tant que les emplacements sont une liste écrite d'avance, rien du reste n'est possible.
> - **Remplacer et ajouter.** Prothèse, greffe, membre de plus : c'est un **axe de contenu entier**, et il se raccorde exactement à la réécriture des modules — une greffe est du contenu qui **module une règle du monde**, pas un effet à elle.
> - **Les organes, et le budget de place.** C'est la partie la plus neuve, et la plus intéressante : un organe **occupe du volume** dans le corps. Deux estomacs font manger plus **et laissent moins de place** pour autre chose. Ça introduit une dimension qui n'existe nulle part aujourd'hui — une **contenance interne** — et c'est elle qui rend le choix intéressant : on n'ajoute pas, on **arbitre**.
>
> **Ce que ça tranche, au passage** : la question n° 6 des [[Décisions en attente]] (« les cinq zones humanoïdes valent-elles pour un loup, un essaim, une calèche ? ») **devient sans objet**. La réponse est : le corps est une **donnée**, un plan par créature, et `silhouette` en devient l'ancêtre.
>
> **Ce que ça touche, et il faut le dire avant de commencer** : `degats_finaux` et `_appliquer_degats` sont le cœur le plus chaud du code ; le **paperdoll dessine par emplacement**, donc un corps à géométrie variable change ce qui est dessiné ; et la suite entière suppose **à la fois** une jauge de santé unique **et** des emplacements fixes. C'est le chantier le plus intrusif de tout ce qui est en file.
>
> **Et c'est le modèle de Caves of Qud**, que le designer a nommé le même jour en parlant de l'exploration : des parties de corps en données, des membres perdus, des greffes et des mutations qui en ajoutent. Les deux demandes vont dans la même direction — ce n'est pas une coïncidence, et il vaudra mieux en parler ensemble.


> [!success] Codé le 2026-09-08 — **on ne se bloque plus entre amis** (designer : « possible d'être sur la même case qu'un PNJ non hostile »)
> **Ce que la grille permet, et ce qu'elle ne permet pas** : elle ne tient qu'**un occupant par tuile** — et son miroir `occ` dans le noyau C++ non plus. Deux êtres ne peuvent donc pas s'y tenir vraiment sans changer le modèle d'occupation, le pathfinding, le ciblage et la passe de dessin.
> **Ce qui est fait à la place, et qui donne le même résultat en jeu** : marcher sur un être **non hostile** **ÉCHANGE** les deux places. Un villageois ne ferme plus une porte ni un couloir, un compagnon ne coince plus son maître dans un cul-de-sac. Celui qu'on croise ne paie rien : c'est une politesse, pas une action.
> **Deux refus subsistent, et ils sont voulus** : un **ennemi** barre toujours le passage — c'est lui qu'on attaque, pas qu'on contourne ; et un être **enraciné** (statut qui bloque le déplacement) ou **à cheval** ne se pousse pas.
> `test_simulation` le prouve dans les deux sens : l'échange accepté et la grille qui suit, le pas refusé sur un hostile.

> [!success] Codé le 2026-09-09 — **une tuile tient une pile** (designer 2026-09-08 : « les entités peuvent se stack sur la même case, un PNJ peut porter un PNJ qui porte un PNJ »)
> **La règle** : on marche sur une tuile occupée si **aucun** de ses occupants n'est hostile, et on arrive **au sommet** de la pile ; un ennemi barre toujours le passage, c'est lui qu'on attaque. La hauteur est en données — `combat_rules.deplacement.pile_max`, trois, parce que « un PNJ peut porter un PNJ qui porte un PNJ ». L'escalier obéit à la même règle à son autre bout.
> **Le modèle, et c'est lui qui a rendu le changement petit** : `occupants` garde sa forme d'avant (index → un id) et désigne le **sommet** ; un second dictionnaire `piles` ne porte que les tuiles à plusieurs. Les 183 lecteurs d'`occupant()` n'ont pas eu une ligne à changer, et le **miroir d'octets du noyau C++ garde son sens** — il dit « il y a quelqu'un », ce qui est toujours vrai. Le noyau n'a pas bougé.
> **`liberer` prend un id** : sans lui il retire le sommet (ce qui reste juste quand on est seul sur sa tuile), avec lui il retire le bon être — car depuis la pile, on peut être SOUS quelqu'un.
> **UN DÉFAUT QUE LA PILE A RÉVÉLÉ** : avant, `placer` sur une tuile déjà occupée **écrasait silencieusement** l'occupant — le dictionnaire ne gardait que le dernier venu, et l'être évincé continuait de croire qu'il tenait cette tuile. C'était une corruption discrète, que rien ne signalait ; un test la traversait sans le savoir. `placer` empile désormais, ce qui est le comportement juste d'une primitive — mais il faut savoir que les chemins de spawn qui posaient un être sur une tuile occupée fabriquent maintenant une pile au lieu d'une corruption. Les deux sont des défauts d'appelant ; le second se voit.
> **Ce qui reste** : le **chemin** ne traverse toujours pas un ami. Le pas passe, l'itinéraire non — le noyau n'ignore qu'un seul id. Voir [[Ordre de travail]], ligne 26 nonies. Et **porter** quelqu'un est une relation, pas une pile : ligne 26 decies.

## Liens
- **Dépend de** : [[Action-time à ticks]], [[Grille continue]], [[Hauteur de terrain ±10]]
- **Alimente** : [[Zones de coup par dénivelé]], [[Garde en posture]], [[Attaque lourde et télégraphe]], [[XP de combat]], [[Pipeline de résolution du combat]]
- **Voir aussi** : [[Structure compétences-modules-slots]], [[Endurance]], [[Statuts de contrôle et anti-stunlock]], [[Compagnons]], [[Trous connus du combat]], [[Écrans d'interface]]
