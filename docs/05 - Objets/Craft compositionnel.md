---
aliases: ["4.2.1", "4.2.1 Craft compositionnel", "Craft compositionnel", "Composants craft"]
tags: [objets, craft, décidé]
domaine: objets
statut: décidé
etape: 6
---

Un objet n'est plus une recette monolithique mais un assemblage de composants, chacun dans n'importe quel matériau — la liberté est totale en théorie, gatée par la connaissance des recettes en pratique.

**Principe :** un objet n'est plus une recette monolithique (« épée = 3 bois + 3 métal ») mais un **assemblage de composants**, chaque composant étant crafté séparément, dans **n'importe quel matériau** — la liberté est totale en théorie, gatée par la **connaissance des recettes** en pratique.

**Structure standardisée (granularité figée — éviter les 10 000 items) :**
- Chaque objet = **2 composants majeurs** (porteurs des stats : tête/lame + manche pour outils et armes ; plaque + sangles pour les armures...) + **1 slot de fixations générique** (rivets, ligatures, colle — composant standard partagé par toutes les recettes d'une même table, qui module légèrement la qualité d'assemblage selon son matériau).
- Les composants sont **réutilisés partout** : le même « manche court » sert à la pioche, la hache et le marteau — peu de *types* de composants, beaucoup de *matériaux* possibles. Catalogue de composants en [[Composants]].

**Composant logique :** la recette d'un objet référence des **slots typés** (« une tête de pioche »), jamais un matériau (« une tête en fer »). Chaque composant a ses **recettes d'obtention** par familles de matériaux, chacune avec sa table requise et sa condition de déblocage (schéma [[Composant et recette d'obtention]]).

**L'équilibrage par la connaissance :**
- Les **recettes de base** (manche en bois, tête en lingot métallique...) sont connues d'office.
- Les **recettes exotiques** (manche en os, en or, lame d'obsidienne, de verre...) s'**apprennent** : loot de donjon (parchemins de recette, même logique que les grimoires [[Grimoires et manuels]]), achat chez des marchands spécialisés, enseignement de guilde (secrets d'artisans par rang, [[Quêtes et guildes]]) — et certaines demandent une **table plus avancée**. Nouvelle boucle de collection, parallèle aux modules.

**Navigation des recettes (l'UI qui enseigne le système) :**
- La recette affiche ses slots de composants ; **cliquer sur un composant déplie son obtention** (tête de pioche → un lingot, à l'enclume), **récursivement** (lingot → minerai + four ; minerai → où ça se mine). La recette EST le tutoriel — cohérent avec [[Tooltips contextuels]] (information pure, jamais de verrou).
- **Recettes non connues : affichées en silhouette** (« ??? — recette inconnue, se trouve en donjon/guilde ») — la découverte reste visible sans être révélée. Les recettes de base sont toujours dépliables intégralement.

**Friction early game — résolue par la boucle existante, pas par un mode simplifié :** le loot de donjon ([[Donjons — structure et intégration]]) et les boutiques couvrent le besoin d'équipement pendant que le joueur apprend le craft. Le craft n'est pas la porte d'entrée obligée de l'équipement.

**Fonte et façonnage séparés (chaîne du métal) :**
- **Four/Forge** : fonte — minerai → lingot (+ sable → verre, argile → brique).
- **Enclume** (nouvelle station, [[Stations de transformation]]) : façonnage — lingot → composants métalliques (têtes, lames, plaques, rivets).
- Les autres chaînes suivent la même logique avec leurs stations existantes : Scierie → composants en bois (manches, hampes), Atelier de tissage → sangles/rembourrages, Tailleur de pierre → composants en pierre.

**Qualité — par composant, avec jet d'assemblage ([[Stats et qualité de l'assemblage]]) :** chaque composant a sa propre qualité ([[Qualité d'artisanat]], sur la compétence de sa station) ; l'assemblage final fait une **moyenne pondérée des qualités des composants + un jet sur la compétence d'assemblage** — un maître assembleur tire le meilleur de composants moyens, un débutant gâche des composants excellents.

**Wu Xing composite ([[Wu Xing — cycles et vecteurs]]) :** l'alignement élémentaire de l'objet dérive de ses composants — une arme manche-bois/tête-métal est alignée **Bois ET Métal** (chaque alignement au prorata du poids du composant). Tout-métal = fort contre Bois mais vulnérable au Feu ; mixte = polyvalent sans bonus franc. Le choix des matériaux de composants devient un choix d'alignement.

**Niveaux de recette — les doublons approfondissent :** chaque recette a **5 niveaux** ; apprendre une recette déjà connue la fait monter (coût croissant : N doublons pour passer au niveau N, soit 10 au total). Aucun parchemin n'est un loot mort. L'enseignement par un artisan à haute relation ([[Réputation et relations]]) devient le moyen **volontaire** de cibler une recette précise. *Axe de bonus à trancher au playtest* (efficacité matière / vitesse et lots / stabilité du jet) — **contrainte non négociable : le niveau de recette ne multiplie jamais la qualité**, sinon farmer des parchemins court-circuite la progression de compétence. → [[Ouvert — Axe des niveaux de recette]]

**Généralisation :** ce paradigme couvre armes, outils, armures — et les véhicules ([[Véhicules]]) fonctionnaient *déjà* ainsi (coque + roues + mât) : le craft entier du jeu devient un seul modèle compositionnel.

*(La chimie élémentaire — Extracteur/Synthétiseur, 58 éléments — a été **supprimée** le 2026-08-09 : trop lourde en contenu pour un système purement endgame, et redondante avec le Wu Xing sur « de quoi est fait un matériau ». Une seule couche élémentaire subsiste, dérivée de la catégorie ([[Wu Xing hors combat]]). Le rôle d'endgame d'artisanat est repris par les **recettes industrielles** — voir [[Palier industriel]].)*

**Contenu à produire :** [[Ouvert — Recettes de composants par famille]].

> [!success] Codé le 2026-08-28 — `data/components/` (14), `data/component_recipes/` (la matrice), objets assemblés `data/items/craft_*`
> Le modèle de la note tel quel : un objet = ses **slots** de composants (`slots` de la fiche d'objet) + une recette d'assemblage (station, compétence) ; un composant = une recette d'obtention par **famille de matériaux** (`data/material_families.json` traduit chaque famille en filtre : catégorie/matériau + forme — `lingot_metal` = tout métal en lingot, `bois` = toute essence en planche…). Un composant consomme **une unité** de la famille et porte les 13 stats et le vecteur Wu Xing de son matériau, plus sa **qualité** (A.3 sur la compétence de sa station). Les recettes exotiques (`unlocked_by_default: false`) attendent leurs sources (`e.recettes_connues`) — parchemins, marchands, guildes viennent avec les étapes 3-9. **Décisions** : l'assemblage se fait à l'**Établi** (la « table d'assemblage » de la note), avec la compétence de la recette d'objet (Forge pour les armes et armures de métal, Menuiserie pour les outils) ; les niveaux de recette restent ouverts ([[Ouvert — Axe des niveaux de recette]]) et ne sont pas codés. Le laminoir (contrepoids en tungstène) attend le [[Palier industriel]].

> [!success] Codé le 2026-08-29 — le tannage : la famille `cuir` avait des recettes mais aucune source
> Trou trouvé en relisant les données : `material_families.cuir` (matériau `cuir`, forme brute) alimente `component_recipes/sangles_cuir` et les armures légères, mais **rien au monde ne produisait de cuir** — ni loot, ni filon, ni recette. Nouvelle recette **`tanner_cuir`** (atelier de tissage, compétence **Cuir**, 2 peaux → 1 cuir brut) : la peau des bêtes (`creatures.*.depouille`) devient la matière des sangles et des armures. Décision : le tannage se fait à l'**atelier de tissage** (pas de cuve à tanner : la note *Stations de transformation* en fixe neuf, on n'en ajoute pas une dixième pour une recette).

> [!success] Corrigé le 2026-08-29 — 33 recettes « meuble_x → meuble_x » supprimées
> Troisième pan du défaut signalé par le designer. `recipes/` portait **une recette par meuble et par station** (`meuble_chaise`, `meuble_table`, `station_forge`… — 24 + 9), chacune ne disant qu'une chose : « ce meuble coûte ça ». Un meuble neuf n'était donc constructible qu'après l'écriture d'un fichier de plus, avec sa clé de localisation. Le **coût monte sur la fiche de l'objet** (`items/meuble/*.json` → `recipe: {station, craft_skill, inputs}`), et `GameData._deriver_recettes_objets` en dérive la recette au chargement, sous l'id de l'objet — rien ne change pour le code qui lit `catalogues.recipes`, ni pour les intentions `fabriquer`. **Décisions** : le nom de la recette est le nom de l'objet (33 clés de traduction en moins) ; un objet à `slots` ne dérive rien (il passe par l'assemblage) ; une recette plate du même nom qu'un objet à coût est une **erreur de données** au boot. Les 24 recettes de transformation (fondre, scier, tanner…) restent des recettes : elles transforment une catégorie en une forme, elles sont déjà catégorielles.

> [!important] Doctrine — tranchée par le designer le 2026-09-02 : **on fabrique n'importe quoi avec n'importe quoi**
> « On peut craft n'importe quoi avec n'importe quoi, mais le problème c'est la recette. Un manche en bois est basique, il peut se faire avec une des premières tables de craft sans problème ; par contre un manche en eau de mer demandera une table de craft particulière qui permet de craft avec les liquides, et d'avoir acheté ou trouvé une recette qui permet de craft un manche avec un liquide. Il n'y a pas de recette *lame de corail* fixe, ça ne marche pas comme ça, rien n'est défini. »
>
> **Ce que cela veut dire.** Aucune paire matière → composant n'est écrite quelque part et autorisée d'avance. Un manche peut être fait de n'importe quelle matière du monde. Ce qui **limite**, ce sont deux choses, et deux seulement :
> - **la recette** : savoir tirer un manche d'un *liquide* est un savoir qu'on achète ou qu'on trouve, pas un acquis ;
> - **la station** : une table qui ne sait travailler que le solide ne fera jamais un manche d'eau de mer, même avec la recette en main.
> Autrement dit, la difficulté ne tient pas à la matière mais à **la distance entre cette matière et ce qu'on sait en faire**. Le bois est facile parce que tout le monde sait le travailler et que la première table suffit ; l'eau de mer est difficile parce qu'il faut un atelier et un savoir qui ne s'inventent pas.
>
> **Ce que j'avais compris de travers, écrit ici pour que personne ne le refasse.** Le 2026-09-02, voyant qu'aucune matière d'Eau ne pouvait entrer dans un objet, j'ai créé des recettes « lame de corail », « plaque d'obsidienne », « sangles de varech » — c'est-à-dire exactement le modèle que le designer venait d'écarter : des paires fixes, décidées d'avance, qui referment ce que le design veut ouvert. Elles ont été retirées. **La bonne question n'était pas « quelles paires autoriser » mais « quelle station et quelle recette ouvrent quelle classe de matière ».**

> [!success] Tranché le 2026-09-03 — **une échelle de fréquence par composant** (designer)
> « Il faudrait que chaque loot ait par composant une échelle de fréquence/absurdité : par exemple un manche, le plus fréquent c'est qu'il soit en bois, un peu moins en métal, et le plus absurde c'est en eau — plus c'est absurde, moins ça a de chance d'apparaître. »
> **Ce qui existait** : un seul poids, `poids_hors_attente` = 0,04, pour **tout** ce qui n'est pas la matière attendue. Un manche en métal et un manche en eau de mer avaient donc exactement la même chance de sortir — l'un est un peu inhabituel, l'autre est une curiosité de foire. La mesure du même jour disait la conséquence : **46 % des objets assemblés** portaient une pièce hors de l'attendu, là où la note promettait « presque jamais ». Le plat de la règle expliquait les deux défauts à la fois — trop souvent, et sans gradation.
> **Ce qu'on met à la place** : une échelle **par emplacement**, catégorie par catégorie. L'emplacement est la bonne maille — un manche est un manche, qu'il aille sur une hache ou sur une torche — et c'est exactement l'exemple du designer. Les valeurs se lisent comme des fréquences relatives : 1,0 la matière évidente, 0,3 plausible, 0,05 étrange, 0,005 absurde. Le liquide et le météorologique ferment toutes les échelles.
>
> **Ce qui sort vraiment, mesuré sur mille tirages au niveau 12** :
>
> | emplacement | ce qu'on trouve |
> |---|---|
> | **manche** | bois **52 %** · métal **43 %** · animal 4 % · végétal 1 % |
> | **sangles** | végétal 56 % · animal 36 % · synthétique 4 % · métal 2 % |
> | **tête** | métal 73 % · roche 15 % · animal 7 % · végétal 2 % |
> | **plaque** | métal 91 % · animal 7 % |
> | **monture** | métal 95 % · animal 3 % |
> | **fixations** | métal 83 % · végétal 10 % · **liquide 3 %** · animal 2 % |
>
> Le manche suit l'exemple à la lettre. Et le liquide en fixations n'est pas une anomalie : `fixations_std_seve` est une recette **écrite à la main** — la sève comme colle. L'échelle ne s'applique qu'à ce qui est **hors** du pool attendu ; ce qu'une recette déclare garde son poids plein.
>
> **L'effet d'ensemble** : les pièces hors de l'attendu passent de 20-25 % à **4-8 %**, et les objets qui en portent une de 46-51 % à **10-19 %**. « Presque jamais » redevient vrai, et ce qui sort est plausible — des sangles en fourrure plutôt qu'une lame en cuir.
>
> > [!warning] Le piège de cache qu'il a fallu voir en même temps
> **Étendu le même jour — jusqu'à la sous-catégorie** (designer : « développe encore plus ce système avec toutes les catégories, les sous catégories et tous les crafts pour qu'on ait aucune lacune »). La maille « catégorie » était trop grosse : dans `animal`, une **peau** fait des sangles évidentes, un **tendon** une fixation évidente, un **boyau** une corde acceptable — et un **organe**, non. Tous valaient pareil. La lecture va désormais du plus précis au plus général : `catégorie/sous_catégorie`, puis `catégorie`, puis 1,0 — une fiche sans sous-catégorie se comporte donc exactement comme avant.
>
> **Ce que ça donne, mesuré à la maille fine** (mille six cents tirages, niveau 12) :
>
> | emplacement | ce qu'on trouve |
> |---|---|
> | **sangles** | végétal/fibre 52 % · animal/fibre 21 % · animal/peau 18 % · synthétique 5 % · **animal/organe 1 %** |
> | **manche** | bois 56 % · métal 39 % · **animal/os 4 %** |
> | **plaque** | métal 88 % · **animal/carapace 5 %** · animal/os 4 % · animal/peau 1 % |
> | **fixations** | métal 85 % · végétal/fibre 8 % · liquide/organique 3 % · animal/fibre 1 % |
>
> La carapace fait une meilleure plaque que la peau, la peau de meilleures sangles que l'os, et l'organe reste une curiosité partout. **Aucune lacune** : chacun des six emplacements couvre les douze catégories et les quinze sous-catégories, vérifié paire par paire.
>
> Au passage, la **sève** et le **lait** quittent `liquide/eau` pour `liquide/organique` : ce sont des liquides aqueux, mais ils sortent d'un vivant — et c'est la sève qui colle, pas l'eau.
>
> > Les poids de tirage sont **mis en cache** par pool de candidats. Or deux emplacements peuvent puiser dans le même pool — une tête et une plaque sont toutes deux limitées aux matières dures — et ils ont désormais des poids **différents** pour l'inattendu. Sans ajouter l'emplacement à la clé, le second aurait récupéré les poids du premier et l'échelle n'aurait servi qu'à moitié, **en silence**. Un cache qui ignore une dimension nouvelle ne se plaint jamais.

> [!success] Tranché le 2026-09-03 — **trois composants maximum par objet** (designer)
> « Non, c'est trop : 3 composants max par craft. »
> **Le contexte de la décision, parce qu'elle corrige une de mes initiatives.** En cherchant les lacunes de la chaîne de craft, j'avais trouvé trois composants — `garde`, `contrepoids`, `rembourrage` — qui existaient avec leurs recettes, leurs traductions et un `used_by` désignant l'épée et la masse, **sans qu'aucun objet ne les porte**. Du contenu mort et invisible. J'ai comblé le trou en ajoutant une quatrième pièce à l'épée et à la masse.
> **La lacune était réelle, ma façon de la combler non.** La bonne réponse n'était pas d'agrandir l'objet mais de **retirer ce qui ne rentre pas** : au-delà de trois pièces, l'assemblage devient illisible et chaque pièce de plus dilue le poids des autres dans la moyenne pondérée. `garde` et `contrepoids` sont supprimés avec leurs recettes ; le `rembourrage`, lui, avait sa place — il devient la pièce souple du **gambison**, une cuirasse matelassée, qui reste à trois composants.
> **La limite est désormais vérifiée** : `loot_rules.assemblage.composants_max` = 3, et la règle 30 de `audit_donnees.py` refuse tout objet qui la dépasse. Testé en ajoutant un quatrième emplacement à l'épée : l'audit la nomme.

> [!success] Tranché le 2026-09-03 — **la troisième pièce dit ce qu'est l'objet** (designer : « on va faire C »)
> **Le constat qui a ouvert la discussion.** `fixations_std` était sur **40 objets sur 43**, et c'était le **seul** composant de fixation du catalogue. Ce n'était donc pas un choix mais une constante déguisée en variable — et sous la limite de trois pièces, elle mangeait **un tiers de chaque objet**, un tiers du poids de ses stats, sans jamais rien différencier. Vingt-neuf objets sur quarante-trois avaient exactement la même formule : tête, manche, fixations.
> **Trois issues avaient été posées** : (A) supprimer la fixation et n'avoir que deux pièces qui pèsent 50 % chacune ; (B) écrire plusieurs fixations réelles ; (C) faire varier la troisième pièce selon la **famille** d'objet. Le designer a choisi **C**.
>
> **Ce que devient la troisième pièce, famille par famille** :
>
> | famille | pièces | ce que la troisième apporte |
> |---|---|---|
> | arme tranchante ou perforante de contact | tête · manche · **garde** | la parade : sa dureté protège la main qui tient |
> | arme contondante ou lourde | tête · manche · **contrepoids** | l'équilibre : il compense la densité du manche et rend l'arme plus vive |
> | arme à distance | tête · manche · **corde** | la puissance : c'est **son élasticité** qui arme le tir |
> | armure | plaque · sangles · **doublure** | l'isolation : ce qui protège du froid et du chaud |
> | bijou | monture · **sertissure** | ce qui tient la gemme |
> | outil, arme de jet, focus | tête · manche | **deux pièces** — la limite est un plafond, pas une obligation |
>
> **La règle qui rend C différent de B** : chaque troisième pièce a un **effet mécanique propre**, pas seulement un nom. Une garde qui ne ferait rien serait une fixation repeinte.
> **Et la corde répond à une demande du même jour** : le designer voulait que l'élasticité fasse la puissance d'un arc. Elle la faisait déjà, mais à travers la moyenne pondérée de *toutes* les pièces — une corde de soie d'araignée noyée dans un fût de chêne. Avec une pièce dédiée, la puissance vient de **ce qui se tend**, ce qui est à la fois plus juste et plus lisible.

> [!success] Constaté le 2026-09-03 — `fixations_std_seve` a été retirée avec les fixations (troisième pièce, 2026-09-03)
> La fixation standard, sur quarante objets sur quarante-trois, ne différenciait rien ; elle a cédé la place à une troisième pièce qui dit ce qu'est l'objet (garde, contrepoids, corde, doublure, sertissure). La recette de sève est partie avec elle. Voir le callout du 2026-09-03 dans [[Structure compétences-modules-slots]].

## Liens
- **Dépend de** : [[Composants]], [[Composant et recette d'obtention]], [[Stations de transformation]], [[Qualité d'artisanat]]
- **Alimente** : [[Stats et qualité de l'assemblage]], [[Palier industriel]], [[Équipement — 14 slots]], [[Armure par zone et constructions]], [[Véhicules]]
- **Voir aussi** : [[Wu Xing — cycles et vecteurs]], [[Armes fantomatiques]], [[Grimoires et manuels]], [[Quêtes et guildes]], [[Tooltips contextuels]], [[Ouvert — Axe des niveaux de recette]], [[Ouvert — Recettes de composants par famille]]
