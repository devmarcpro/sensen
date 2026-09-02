---
aliases: ["Mine", "Minage en profondeur", "Puits de mine", "Mine sous une cellule"]
tags: [monde, terrain, ressources, décidé]
domaine: monde
statut: décidé
etape: 2
---

# Mine sous une cellule

> [!success] Tranché le 2026-09-02 — **le minage en profondeur se creuse sous une cellule du joueur** (designer)
> L'idée venait du designer, façon Dwarf Fortress : « on rajoute un escalier pour descendre et l'étage du dessous est généré, plus c'est profond plus les minerais sont rares et les roches ont une dureté élevée. » Puis, sur la question de l'emplacement : « le minage en profondeur se fait sur une cellule au joueur. »
> **Ce que la réponse tranche.** On ne creuse pas n'importe où : il faut que la cellule vous **appartienne**, donc qu'elle soit revendiquée ([[Claims et persistance]]). Une mine est un **ouvrage**, pas une excursion — elle demande un territoire, elle reste, et elle donne une raison de plus de revendiquer une cellule pour ce qu'il y a **dessous** plutôt que dessus.

## Ce que c'est, et ce que ce n'est pas

Une mine n'est **pas un donjon**. Un donjon est fait de salles et de couloirs qu'on parcourt ; une mine est un bloc de roche pleine dans lequel il n'y a **rien**, sauf ce qu'on y creuse. On n'y explore pas : on y **ouvre** un espace, et l'espace qu'on a ouvert reste ouvert.

C'est la différence qui justifie qu'elle existe à côté du [[Donjons — structure et intégration|gouffre]], qui est lui aussi infini et descendant. Le gouffre **mesure** le joueur : il est peuplé, il donne du butin, on y meurt. La mine **récompense le travail** : elle est vide, lente, sûre, et ce qu'on en tire, on l'a extrait soi-même.

## Ce qui est déjà en place et que la mine réutilise

Rien de tout cela n'est écrit pour la mine — elle branche des mécanismes qui existaient :

- **le creusement** ([[Destruction du terrain]]) : une tuile destructible tombe en un nombre de ticks calculé sur la dureté du matériau, la force de l'outil, le niveau de compétence et le **palier** de la matière. C'est déjà « plus c'est profond, plus c'est dur » — il suffit de mettre des matières profondes en bas ;
- **les bandes de matériau par profondeur** ([[Stratification verticale]], [[Minerais par profondeur]]) : `palette_mur` dit quelle roche règne à quelle profondeur, et les poches de bruit y déplacent une strate de ±1 ;
- **les paliers de matériau** : un palier élevé relève le seuil d'outil exigé et allonge l'extraction. Une pioche de départ **rebondit** sur ce qui est trop profond pour elle, ce qui est exactement la porte qu'on veut.

## Comment ça marche, dans le code

`Mine.generer_etage` tient en trente lignes et c'est le signe que le découpage est bon : il n'y a ni salle, ni couloir, ni graphe à mailler — un bloc plein, une chambre de trois cases au centre, et le bord en roche pour qu'on ne creuse pas jusqu'au vide. Tout le reste est emprunté : `charger_donjon` charge un étage de mine comme un étage de donjon, ses `spawns`, `coffres` et `filons` étant vides, les boucles qui les posent ne font simplement rien.

**Le puits se creuse sous ses pieds** (`creuser_un_puits`). C'est la promesse de Dwarf Fortress : on décide où descendre, on ne cherche pas un escalier que le monde aurait posé. Au camp sur une cellule revendiquée, il ouvre la mine ; dans la mine, il perce vers l'étage suivant. Sans claim, il refuse et le dit.

**La galerie reste ouverte.** On ne sauvegarde pas la grille — elle est déterministe — mais la **liste des tuiles enlevées**, par mine et par étage, dans `mines_creusees`. Quelques centaines d'entiers pour un chantier, et redescendre dans sa mine c'est retrouver son travail, pas la roche.

> [!bug] Trouvé le 2026-09-03 par la sonde de la mine — **la palette de mur ramollissait en descendant**
> Les étages 1-2 sont en pierre (dureté 13) et la bande 3-4 était en ardoise (**12**) : la difficulté d'extraction **baissait** d'un cran en descendant, alors que [[Stratification verticale]] promet l'inverse. Un point d'écart ne se voit pas dans un donjon, où l'on traverse les murs sans les creuser ; il se voit dans une mine, où creuser **est** le jeu. La pente est désormais monotone — pierre 13, brèche volcanique 21, andésite 31, basalte 48, granit 53, granit noir 66 — et la sonde échoue si elle s'inverse à nouveau.

> [!bug] Trouvé le 2026-09-03 à l'écran — **le jeu mentait au joueur sur ce qu'il regardait**
> La sonde vérifiait les règles et les trouvait bonnes. La capture, elle, a montré trois choses qu'aucune règle ne couvrait : le bandeau annonçait « DONJON Ruine · étage 4/999 · salles 0 » et invitait à « marcher sur l'escalier » dans une mine qui n'en a aucun ; la chambre d'arrivée s'affichait en **gazon vert** à quatre étages sous terre, parce que le sol héritait du dehors ; et le mode de temps disait « DONJON ». Une mine dit maintenant qu'elle est une mine, son sol prend la couleur de sa strate, et l'invite parle de creuser.
> **Ce que j'en retiens** : une sonde prouve qu'un système obeit à ses règles ; elle ne voit pas qu'il raconte la mauvaise histoire. Les deux vérifications ne se remplacent pas.

## Les deux questions que je n'ai pas tranchées

Elles restent au designer, et j'ai posé une hypothèse pour ne pas bloquer :

1. **La mine partage-t-elle l'échelle de profondeur du gouffre, ou tient-elle la sienne ?** *Hypothèse retenue* : la sienne, plus lente. Un étage de mine vaut environ **la moitié** d'un étage de gouffre en profondeur de matériau, parce qu'on descend à la pioche et non par un escalier déjà construit. Si le designer veut la même échelle, c'est un chiffre.
2. **Est-ce que des créatures y descendent ?** *Hypothèse retenue* : **non** — on n'y risque que l'effondrement, l'endurance et la faim. C'est ce qui la sépare le plus nettement du gouffre, et c'est réversible d'une ligne : le peuplement d'étage existe déjà.

## Liens

- **Repose sur** : [[Claims et persistance]], [[Destruction du terrain]], [[Stratification verticale]], [[Minerais par profondeur]], [[Récolte]]
- **Se distingue de** : [[Donjons — structure et intégration]], [[Génération de donjon]]
- **Alimente** : [[Craft compositionnel]], [[Catégories de matériaux]]
