---
aliases: ["4.2", "4.2 Matériaux, récolte et artisanat", "4.2 stats", "C.5", "Annexe C.5", "13 stats", "Stats des matériaux", "Matériaux"]
tags: [objets, matériaux, décidé]
domaine: objets
statut: décidé
etape: 6
---

Chaque matériau porte 13 statistiques fixes. Le choix du matériau dans un craft est un arbitrage multidimensionnel, pas seulement dureté/poids.

**Catégories de matériaux :** chaque matériau appartient à une catégorie (bois, minerai, roche, liquide, synthétique, etc.). Voir [[Catégories de matériaux]].

**Stats par matériau :** chaque matériau possède ses propres statistiques individuelles fixes, indépendamment de sa catégorie. **13 stats** (effets détaillés en [[Application des stats de matériau]], schéma en [[Schéma matériau]]) :
- `durete` — dégâts, protection, récolte
- `densite` — poids, vitesse d'arme
- `valeur_base` — économie
- `conductivite_mana` — efficacité magique (réduction des coûts en mana)
- `flammabilite` — prend feu, vitesse de combustion
- `isolation` — protection chaleur/froid
- `conductivite_electrique` — sensibilité/propagation de la foudre
- `flottabilite` — flotte ou coule (crucial pour les véhicules navals)
- `luminosite` — émet de la lumière (éclairage, visibilité/discrétion)
- `fertilite` — rendement agricole du sol ([[Agriculture et élevage]])
- `transparence` — laisse passer la lumière/le regard (fenêtres, serres)
- `elasticite` — amortit les chutes, puissance des arcs
- `friction` — surfaces glissantes (glace) ou routes rapides (pavés)

Le choix du matériau dans un craft est donc un **arbitrage multidimensionnel**, pas seulement dureté/poids.

**Rappel C.5 :** les 13 stats sont `durete`, `densite`, `valeur_base`, `conductivite_mana`, `flammabilite`, `isolation`, `conductivite_electrique`, `flottabilite`, `luminosite`, `fertilite`, `transparence`, `elasticite`, `friction`. Tags dérivés par seuils ([[Schéma matériau]]) + tags manuels : `organique`, `corrompu`.

**Important :** les matériaux bruts n'ont **pas de "qualité"** — seulement leurs stats fixes. La récolte n'améliore jamais la qualité d'un matériau, seulement la vitesse/quantité obtenue ([[Récolte]]).

**Décision :** *Stats par matériau : résolu* — 13 stats, chiffrées pour les **153 matériaux** du catalogue ([[Catalogue matériaux — Bois]] et suivants).

**Vecteur Wu Xing dérivé de la catégorie :** voir [[Wu Xing hors combat]].

> [!success] Codé le 2026-08-28 — `data/materials/` (155 fichiers), `tools/gen_materials.py`
> Les **155 lignes des 11 tables de catalogue** (la table fait foi, pas l'en-tête) sont transcrites par `tools/gen_materials.py` : 13 stats, couleur de la palette (unique, vérifiée au boot), outil/compétence de la catégorie, surcharge `wuxing` de [[Décision — Surcharges Wu Xing des matériaux]] (44 matériaux), clés `material.<id>.name` dans `locale/fr.csv`. Les gabarits paramétriques (feuilles, pousses, parties de créatures) attendent leurs sources (arbres, dépeçage). L'id est le slug du nom sans parenthèse : `aluminium`, `chrome`, `guano`.

> [!success] Codé le 2026-09-02 — trente-et-un matériaux de plus, et une passe de cohérence sur les 166 anciens (designer)
> « Il manque pas mal de matériaux », puis « profites-en pour repasser sur ceux qu'on avait déjà », puis « tu peux rééquilibrer, j'ai écrit aucune stats ».
> **Ce qui manquait était fonctionnel, pas décoratif.** De quoi faire un **arc composite** (corne, tendon), une corde (crin, boyau), un empennage (plume) — un jeu d'assemblage où l'on ne pouvait ni corder un arc ni empenner une flèche. Les matières **travaillées** que l'artisanat produit et que rien ne représentait : cuir bouilli (l'armure légère historique), charbon de bois (qui fait l'acier), poix, cire, feutre, porcelaine. Des métaux qui ont un **caractère** et pas seulement une dureté : la fonte casse, l'acier damassé est le haut du panier, l'électrum est un alliage naturel. Des minéraux qui **font** quelque chose : magnétite, hématite, galène, alun.
>
> **Le principe de la passe de cohérence** : les chiffres doivent respecter l'**ordre** du monde réel, pas ses unités. Un joueur ne connaît pas la densité du plomb, mais il sait que le plomb est plus lourd que le fer et que l'ébène coule. Quand le catalogue contredit ce savoir-là, il ment ; quand il le respecte, il s'apprend tout seul.
> - **Les densités des métaux** étaient approximatives et parfois fausses : le bismuth passait pour plus lourd que le plomb, le tungstène pour plus lourd que le platine. Ce n'est pas cosmétique — la densité décide du **poids porté** et de la **vitesse d'arme** (un manche dense frappe plus lentement) : l'erreur se voyait en jeu. Vingt-six densités alignées sur le réel, arrondi.
> - **Les gemmes étaient des conductrices électriques** — topaze 70, améthyste 45 — alors que ce sont des isolants, et leur dureté ignorait l'échelle de Mohs qui les classe depuis deux siècles. Dureté = Mohs × 5 : le diamant devient la matière la plus dure du jeu, ce qu'il est.
> - **Trois contradictions isolées** : le buis et l'ébène **flottaient**, alors que ce sont précisément les deux bois qui coulent ; la glace était plus dense que l'eau ; le sel gemme sec conduisait le courant.
> - **L'os était plus dur que le tungstène** (34 contre 42, le fer à 25). C'était la cause du butin saturé d'armures en os dont le designer s'était plaint, et le palier dérivé le rangeait en matière de fin de partie. Ramené à 16.
> - **Dix matières manufacturées n'avaient ni outil ni compétence de récolte** : démolir un mur de brique ou une vitre ne rendait rien. La maçonnerie se défait à la pioche, le papier et le caoutchouc se découpent.
> Cinquante-huit corrections sur quarante-cinq fiches. La courbe du butin par niveau de donjon ne bouge pas.


> [!success] Codé le 2026-09-09 — **`absorption` est écrite** : la troisième des cinq, et celle qui justifie le mieux d'avoir des stats séparées (ordre de travail 26)
> **247 valeurs de 0 à 100**, dans l'ordre du monde réel. Ce que chacun sait sans être acousticien : le **textile** et la **fibre** étouffent le mieux — c'est pour ça qu'on tend des tentures ; la **roche** étouffe par la masse mais réfléchit ; le **métal** et le **verre** sont les pires, ils sonnent — une cloche est en bronze, pas en laine ; le **liquide** ne barre rien, c'est par là que le son passe.
> **C'est la stat qui diverge le plus de `durete` et de `portance`, et c'est ce qui la justifie** : le **liège** (92) est mou, ne porte rien, et étouffe mieux que le granit (40) ; l'**acier** (10) est dur, porte tout, et transmet le son comme un fil ; la **neige** (95) rend un monde silencieux, ce que chacun a entendu une fois. Le **plomb** (62) est la grande exception métallique — c'est l'écran acoustique du monde réel.
> **Deux colonnes sur cinq restent à écrire** (`permeabilite`, `alteration`) : la note en dit maintenant **16**.

> [!success] Codé le 2026-09-09 — **`portance` est écrite** : la deuxième des cinq colonnes, et la mine cesse d'être un gouffre (ordre de travail 25)
> **247 valeurs de 0 à 100**, entrées comme 15e colonne des douze tables. Contrairement à `fusion`, ce n'est **pas** une grandeur du monde réel avec son unité : la résistance en flexion se mesure en mégapascals et un joueur n'en a que faire. C'est la seconde moitié de la règle du 2026-09-02 qui s'applique — **respecter l'ordre du monde réel, pas ses unités**. Ce que le joueur sait : l'acier tient mieux que la fonte, le granit mieux que la craie, la roche mieux que la terre, et le sable ne tient pas du tout.
> **Deux familles où `durete` trompait, et c'est ce qui justifie une stat séparée** : les **gemmes** sont dures et **cassantes** — un diamant raye tout et se fend d'un coup de marteau, sa portance est moyenne, pas maximale ; le **plomb** et l'**or** sont des métaux **mous**, ils fléchissent sous leur propre poids — le plomb (22) porte moins qu'un chêne (78).
> **Ce que le champ en fait** : `portee_base + portee_par_portance × portance` donne la distance qu'une tuile ouverte peut avoir jusqu'à son soutien le plus proche. Granit six tuiles, terre une et demie, sable rien. Voir [[Émergence — les champs partagés]].
> **Trois colonnes sur cinq restent à écrire** (`absorption`, `permeabilite`, `alteration`) : la note en dit maintenant **15**.

> [!success] Codé le 2026-09-09 — **`fusion` est écrite** : la première des cinq colonnes, et la chaleur ne sait plus seulement brûler (ordre de travail 23)
> **247 matières, 247 points de fusion, en degrés réels.** La colonne `Fus` est entrée dans les douze tables — la table fait foi, `gen_materials.py` la transcrit, `verif_generateurs.py` prouve qu'il reproduit les 247 fiches champ par champ. Il n'y avait plus rien à débloquer : la note disait « après la remise en accord des catalogues », et cette remise est faite depuis le palier 2 — **les tables et les fiches se correspondent 247 pour 247**. J'ai mesuré avant de croire la note.
>
> **La définition écrite le 2026-09-08 était fausse, et d'une façon qu'on ne voit qu'en écrivant les valeurs.** Elle disait « **0 = elle ne fond pas** ». Or 0 °C est le point de fusion **réel** de la glace, de la neige, du givre, de la grêle, de l'eau et du sang — c'est-à-dire des matières que la ligne 23 cite en tout premier (« la neige fond, l'eau gèle »). Le sentinelle et la donnée se confondaient exactement là où ça comptait. Ce qui ne fond pas porte donc **9999** : aucune température du jeu ne l'atteint, et le zéro redevient une vraie température. Les valeurs **négatives** sont voulues de la même façon : pour un liquide, la fusion est son point de **congélation** — le mercure à −39, l'alcool à −114, la saumure à −21.
>
> **Le consommateur, dans le champ de chaleur** — `SimTerrain._fondre`. Le tableau de `thermique.fusion` ne porte **aucune température** : il dit seulement ce que la chose *devient*. Le seuil est lu sur la fiche. C'est pour cela que le tableau est court et que le comportement est riche.
> · **Le sol qui cuit** : un dallage de gypse rend du plâtre à 150 °C, le calcaire et ses cousins de la chaux à 825, l'argile de la brique à 1000. Un four sans recette.
> · **Le filon qui coule** : la malachite et l'azurite rendent leur cuivre à 200 °C, le cinabre son mercure à 580, la pyrite son fer à 743, la galène son plomb à 1114. Une veine de malachite grillée au bord d'un feu devient du cuivre dans la paroi — **personne n'a écrit cette scène**.
>
> **Ce que la donnée m'a refusé, et que je préfère écrire plutôt que de tricher** : un feu impose 1100 °C, une coulée 1150. Le **sable** fond à 1710 — il ne vitrifiera donc **jamais** au contact d'un feu de camp, alors que « le sable vitrifie » est dans l'énoncé de la ligne 23. C'est exact : il faut un four. Baisser le nombre pour rendre la démonstration jolie aurait été mentir sur le monde réel, qui est la règle du designer.
> **Et un nombre que seul le branchement a révélé** : j'avais donné 1200 °C à la lave, alors que la source lave du champ impose 1150. Toute la lave du monde se serait figée à l'instant même. Le solidus d'un basalte est vers 900 : c'est la valeur juste, et c'est le consommateur qui a posé la question.
>
> **Le contrôle négatif est la vraie preuve** (`test_fusion`) : voir un sol de gypse cuire à 400 °C ne prouverait rien — un seuil écrit en dur à 100 le ferait passer aussi. Le test pose donc deux sols côte à côte et les chauffe à **la même** température : le gypse cuit, le calcaire non. La différence ne peut venir que de la fiche.
>
> **Ce qui reste de la ligne 23**, et il faut le dire : « la neige fond, l'eau gèle, la cire coule » demandent des choses que le monde ne modélise pas encore **en tuiles** — la neige et le gel sont des **drapeaux de grille** posés par la météo, la cire est une matière d'objet. Le champ sait fondre ; ce sont ces trois-là qui doivent devenir des tuiles pour qu'il les absorbe. **Quatre colonnes sur cinq restent à écrire** (`portance`, `absorption`, `permeabilite`, `alteration`) : la note en dit donc **14**, pas encore 18.

> [!important] Décidé le 2026-09-08 — cinq stats manquent aux matériaux, et ce sont exactement celles que les champs liraient (designer : « il doit manquer des stats aux matériaux pour mettre tous les systèmes en place non ? »)
> **La question est juste, et la réponse se déduit** : chaque champ de [[Émergence — les champs partagés]] a besoin d'une propriété de matière pour dire *comment* la tuile réagit, et treize stats n'en offrent que la moitié. Le champ de chaleur codé ce matin lit `isolation`, `flammabilite` et `densite` — il n'a rien pour dire qu'une chose **fond**. Les cinq suivantes ne sont pas des décorations : chacune est **la stat sans laquelle un champ décidé ne peut pas exister**.
>
> | Stat | Ce qu'elle dit | Le champ qui la lit | Ce qu'on perd sans elle |
> |---|---|---|---|
> | `fusion` | la température (°C) où la matière change d'état ; **0 = elle ne fond pas** (elle brûle, se décompose, ou tient jusqu'à disparaître) | **chaleur** | La chaleur ne sait que **brûler**. Rien ne fond, rien ne cuit, rien ne vitrifie : ni la glace au soleil, ni la cire près d'une flamme, ni le sable en verre, ni le minerai en lingot. Le four et la forge restent des recettes hors du monde. |
> | `portance` | combien la matière tient **en porte-à-faux** avant de céder (0-100) | **support / gravité** | Pas d'effondrement possible : la seule chose qui sépare une mine d'un gouffre ([[Mine sous une cellule]]) reste non codée, et **étayer** ne peut pas devenir un geste. |
> | `absorption` | ce que la matière **étouffe du bruit** (0-100) | **bruit** | Un cri traverse un donjon comme s'il n'y avait pas de murs. Le champ de bruit — « celui qui manque le plus » — serait une simple distance, pas un lieu. |
> | `permeabilite` | ce que l'**eau** traverse (0-100) | **eau qui pèse** | Une nappe n'a aucune raison d'exister (c'est l'argile imperméable qui la retient), un barrage ne tient pas, et le sable ne filtre pas. Les poches d'eau du 2026-09-07 restent des robinets. |
> | `alteration` | la vitesse à laquelle la matière **se dégrade exposée** (0-100) | **temps long** | Rien ne vieillit : pas de ruine, pas de rouille, pas de reconquête par la nature. |
>
> **Ce qui n'est PAS une stat manquante**, et pourquoi : la *chaleur spécifique* — `densite` la porte déjà (une matière dense change de température lentement) ; la *conductivité thermique* — `isolation` est son inverse, en avoir deux serait deux vérités ; la *toxicité* — elle appartient au gaz et à la plante, pas à la tuile ([[Gaz dans le sol]] a son propre fichier) ; la *résistance chimique* — la chimie générale est explicitement hors périmètre.
>
> **La contrainte de méthode, et elle s'est révélée pire que prévu** : `tools/gen_materials.py` **efface et régénère** les 248 fiches depuis les tables des onze catalogues — « la table fait foi, pas le script ». Sauf que la vérification faite le 2026-09-08 dit que **ce n'est plus vrai** : 94 matériaux sur 248 n'ont plus de ligne de table, et sur les 154 restants la dureté diverge sur 140 fiches (le diamant : 40 dans la note, 140 dans la donnée). Les cinq stats entreront bien comme **cinq colonnes des tables**, mais **après** la remise en accord des catalogues — voir [[Vers la production]], ligne 141. Et les valeurs suivent la règle de la passe du 2026-09-02 : **respecter l'ordre du monde réel, pas ses unités** — un joueur ignore le point de fusion du plomb, mais il sait que le plomb fond avant le fer et que la glace fond avant tout.
>
> **Le titre de cette note ment à partir de maintenant** : elle en dira **18**. Renommée quand les colonnes sont écrites, l'alias « 13 stats » conservé pour les 39 liens du coffre.



> [!success] Codé le 2026-09-08 — `gen_materials.py` désamorcé : il détruisait 24 fiches et sept champs, et il ne s'en apercevait pas parce qu'il mourait avant
> **Ce qu'il aurait fait s'il avait tourné** (mesuré avec ses propres fonctions, avant de toucher à rien) : supprimer **24 des 247 fiches** — les **20 matières animales**, dont aucun catalogue n'était déclaré dans `CATALOGUES`, et **4 aciers et une essence** dont l'id abrégé ne se déduit pas du nom affiché (`acier_inox` contre « Acier inoxydable »). Et effacer **sept champs** ajoutés après lui : `palier`, `stats_base`, `sous_categorie`, `tags`, `noise.seed_offset`, `wuxing`, `harvest`.
>
> **Il ne détruisait pourtant rien** — il **plantait**, sur la première couleur de palette manquante (92 des 247 en manquaient), une ligne avant la boucle de suppression. **Ce garde-fou était accidentel** : compléter la palette l'aurait fait sauter. C'est pourquoi la préservation des champs a été faite **avant** d'y toucher.
>
> **Ce que la comparaison champ par champ a révélé, et qui est le vrai enseignement** : la donnée porte **partout** des décisions plus récentes que la note. 44 fiches ont une surcharge Wu Xing que la note de décision ne déclare pas ; 26 ont un outil de récolte plus fin que celui de leur catégorie (le corail se coupe à la dague, pas à la pioche — c'est à ça que sert `sous_categorie`) ; 13 ont délibérément **aucun** tag là où la règle en imposait un ; et les tags eux-mêmes sont bien plus riches que le seul `organique` que le script savait produire (`marin`, `toxique`, `industriel`, `os`, `ivoire`, `dent_croc`, `ecaille`, `carapace`).
>
> **La règle retenue** : le générateur ne possède plus que ce qu'il **déduit des tables** — les 13 stats, la clé de nom, la catégorie, la couleur. Tout ce qu'une main a réglé depuis lui est **rendu tel quel**. Au passage, `noise.seed_offset` était dérivé du **rang d'insertion** : ajouter un matériau au milieu d'un catalogue décalait le bruit de tous les suivants. Préservé, il ne bouge plus.
>
> **Le contrôle de palette dit maintenant tout ce qui manque** au lieu de mourir sur le premier — et il refuse toujours d'écrire, mais sans avoir rien supprimé. La palette a été complétée depuis les fiches (`tools/regen_palette.py`, 92 couleurs jamais reversées dans la note), et son motif de lecture accepte enfin les hexadécimaux en minuscules.
>
> **Preuve** : `tools/verif_generateurs.py` relance la chaîne complète et compare **chaque champ de chaque fiche**. Il dit aujourd'hui : *247 fiches après, le générateur les reproduit toutes*. À relancer après toute retouche d'un catalogue, de la palette ou du générateur.

## Liens
- **Dépend de** : [[Data-driven design]]
- **Alimente** : [[Application des stats de matériau]], [[Schéma matériau]], [[Stats d'un objet crafté]], [[Récolte]], [[Craft compositionnel]]
- **Voir aussi** : [[Catégories de matériaux]], [[Wu Xing hors combat]], [[Qualité d'artisanat]], [[Catalogue matériaux — Bois]]
