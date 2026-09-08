---
aliases: ["Émergence — le monde vivant", "Monde vivant", "Écosystème", "Génération du monde — émergence"]
tags: [vision, monde, décidé, à-juger]
domaine: vision
statut: décidé
etape: 12
---

Ce qui manque à la **génération du monde**, à l'**écosystème**, aux **PNJ** et à la **physique** pour que le jeu soit
émergent. Compagnon de [[Émergence — les champs partagés]], qui porte la règle et les huit champs déjà décidés.

## Comment cette liste a été obtenue, et ce qu'elle vaut

Six agents ont lu le code — pas les notes — pour établir d'abord **ce qui existe**, puis ce qui manque. Chacun des
**32 manques** proposés est passé devant deux sceptiques : l'un cherchait à prouver que c'était déjà codé, l'autre que
ce n'était pas un champ partagé mais un système de plus. Les sceptiques ont surtout fait une chose utile : **réduire
les grosses propositions à de petites corrections précises**.

> [!warning] Honnêteté sur la vérification
> La limite de session a tué **25 des 72 agents**, presque tous des sceptiques. Un manque sans verdict a été écarté par
> le script : c'est un **faux négatif**, pas un jugement. Ce qui est marqué *vérifié* ci-dessous l'a été ; le reste est
> une proposition argumentée que personne n'a encore attaquée. Je le signale à chaque ligne.

## Ce qui existe déjà — et c'est beaucoup plus qu'on ne croit

**La génération du monde est déjà causale sur deux couches, et sur deux seulement.** Il y a une **vraie tectonique à
plaques** (24 germes en Voronoï, 40 % continentales, points chauds, et même un vecteur de dérive par plaque… qui n'est
lu nulle part). Le seuil de la mer n'est pas choisi mais **calibré** : la continentalité est échantillonnée, triée, et
le seuil pris au quantile qui donne exactement la part de terres demandée. L'**altitude** et la **sismicité** sont
dérivées de la tectonique — chaînes de montagnes sur les sutures continent/continent, cordillère côtière sur les
sutures continent/océan. Les continents sont réunis par union-find, les régions sont un Voronoï jittéré, chacune avec
sa culture. **Mais les six autres couches de bruit — température, humidité, mana, danger, végétation, ressources —
restent libres, indépendantes les unes des autres et de la géographie.**

**La physique a deux vrais champs propagés** : la **lumière** 0-15 (avec noyau C++) et la **chaleur** (codée le
2026-09-08). Plus un automate d'eau incrémental complet (niveaux 1-7, sources, courant qui emporte les êtres légers),
la lave qui fige en obsidienne, le feu, les couches Z, et une météo qui est une **fonction pure** — un bruit spatial
lent qui défile, jamais simulé. Les conséquences météo codées sont réelles : la pluie remplit les creux fermés,
l'évaporation, la canicule qui enflamme, l'arrachage en tempête, et **la foudre qui vise la tuile la plus haute
pondérée par la conductivité électrique du matériau — le paratonnerre émergent existe déjà**.

**Les PNJ sont le domaine le plus fourni.** Traits, souhait, histoire à paramètres, dialogue d'ambiance à onze
conditions avec anti-répétition, cadeaux et goûts, **opinions PNJ→PNJ** formées par quartier (époux +60, traits
partagés +15, traits opposés −15, même élément astral +10), commerce et douanes, compagnons, vieillissement, quêtes et
guildes, **réputation à trois étages** avec voie de rédemption, familles déduites des lits, naissances, majorité qui
hérite du métier ET du poste, migration, deuil qui démasque le tueur, royaumes avec ères et blasons, lois et
infractions avec témoin qui doit VOIR, diplomatie, guerres, conquête de village, caravanes coupées entre belligérants.

**L'écosystème est, lui, presque vide** — et c'est le contraste le plus net du dossier.

---

## Les manques, par ce qu'ils feraient émerger

### 1. La physique — trois champs qui se tiennent

**Le vent, comme champ vectoriel par tuile** (direction + force), pas comme étiquette météo globale. *Vérifié absent.*
Aujourd'hui « vent » est un tag d'état météo qui ne fait qu'un multiplicateur. Lecteurs immédiats : la chaleur (elle
attise déjà), la fumée, l'odeur, le gaz, les projectiles. **Ce qu'il remplace** : le multiplicateur global.
*Ce qu'il fait émerger* : un incendie qui remonte une vallée dans un sens et qu'on peut couper **en avant du front** ;
un mineur qui perce une poche de grisou et voit le nuage venir **vers lui** parce que la galerie tire ; une salle sans
courant d'air où la fumée s'accumule et tue, alors que la même salle porte ouverte est vivable. **Il doit être calculé
sous terre comme en surface** — sinon la ventilation d'une galerie n'existe pas. Coût moyen.

**La charge de l'air** — une densité par tuile (fumée, gaz, brume, poussière). *Vérifié absent.* **Ce qu'il remplace,
et c'est le point** : les gaz d'aujourd'hui **ne sont pas un champ**. Une poche percée inonde N tuiles **une fois**,
pose des zones à durée fixe qui **ne diffusent jamais, ne se déplacent jamais, ne se mélangent jamais**.
*Ce qu'il fait émerger* : se cacher devient un **lieu** et non un nombre ; un incendie tue par la fumée avant les
flammes, et vite sous un plafond bas ; une garnison voit le panache d'un village qui brûle à l'horizon. Coût gros.

**L'humidité par tuile** — le compagnon obligé du champ de chaleur. *Vérifié absent : `humidite` est une couche de
bruit pure, sans état, impossible à écrire.* *Ce qu'il fait émerger* : un feu de camp sous la pluie survit s'il est
sous un toit — donc **construire un abri devient un geste utile** ; on mouille un toit de chaume avant que l'incendie
n'arrive, et ça marche parce que la flammabilité lit la tuile et non la météo ; après une averse, la forêt ne prend
plus pendant un moment. Coût moyen, effet immédiat sur un champ déjà codé.

> **Deux propositions écartées, avec leur raison** — et l'écart a produit quelque chose.
> - **L'électricité n'est pas un champ qui manque : c'est un lecteur.** `conductivite_electrique` n'a **qu'un seul
>   lecteur** dans tout le dépôt. Mais le deuxième est **déjà décidé dans le coffre et jamais codé** :
>   [[Application des stats de matériau]] promet des dégâts de foudre pondérés par la conductivité de l'**armure** —
>   un facteur 3 entre le cuir et le fer. Cette formule n'existe nulle part. **C'est une dette, pas un champ.**
> - **La pression est déjà couverte, en deux morceaux** : la moitié hydraulique est le point « l'eau qui pèse » déjà
>   décidé, la moitié aérienne est le champ de vent ci-dessus.

### 2. L'écosystème — le domaine le plus vide, et le moins cher à remplir

**L'effectif par espèce et par cellule** — le champ que la densité de faune imite déjà mal. *Ce qu'il fait émerger* :
**les loups s'effondrent quelques semaines après qu'on a vidé les cerfs, sans qu'aucune ligne ne relie les deux.** Une
espèce disparaît d'une région et n'y revient que par diffusion depuis les cellules voisines — **la migration n'est
alors pas un système, c'est ce que fait la diffusion du champ**, et le territoire d'une espèce est simplement la zone
où son effectif est haut. Coût moyen. *(Non attaqué : la limite de session a tué ses deux sceptiques.)*

**Le régime alimentaire en donnée sur la fiche de créature.** Coût petit. C'est **la seule pièce qui manque** pour que
la chaîne alimentaire sorte des données au lieu d'être écrite en code : une année de blé ne nourrit pas les cochons
comme les moutons, et l'apprivoisement se fait à l'appât juste.

**La saison lue par le sauvage.** Coût petit — le champ existe (cinq saisons Wu Xing de 120 jours), **la faune et la
flore sauvage l'ignorent**. La forêt d'hiver se vide et n'offre plus rien à cueillir ; les oiseaux d'eau disparaissent
à l'automne. **La migration s'obtient sans code de migration.**

**La biomasse par tuile** — la quantité de vivant, là où il n'y a qu'un index de contenu. Coût gros. Une forêt brûlée
repousse en couvert bas **avant** de redevenir forêt ; un pâturage surchargé se pèle et le troupeau y meurt de faim
**sans qu'on ait écrit de règle de surpâturage** ; un feu court vite sur la lande et lentement sous un couvert humide.

**La réserve d'une cellule** — ce qu'il reste à en tirer. Ce qu'on extrait s'épuise **pour de bon**, et le reste du jeu
s'en aperçoit sans qu'on l'écrive : une vallée chassée à blanc fait monter le prix du cuir dans les trois villes
voisines ; une ville minière dont la veine est tarie voit ses mineurs migrer.

> **Écarté** : les migrations saisonnières et les territoires d'animaux **comme systèmes à part**. Ils sortent
> gratuitement des trois premiers. Ajouter des tanières par-dessus, ce serait l'erreur que la règle interdit.

### 3. La génération du monde — il n'est pas encore une conséquence

**La température et l'humidité doivent être DÉDUITES de la géographie.** Coût **petit**, et c'est le meilleur rapport
de tout le dossier. *Le fait qui décide* : le monde est une mappemonde rectangulaire 2:1 et **il n'a aucune latitude**.
Les chaînes de montagnes existent déjà, posées sur les sutures — mais il n'y a **pas d'ombre pluviométrique** derrière
elles. *Ce que ça fait émerger* : des pôles et un équateur, des déserts sous le vent et des forêts au vent du même
massif, des côtes tempérées et des intérieurs continentaux.

**Le relief du monde n'atteint jamais la hauteur des tuiles** : une cellule de montagne est une plaine. Coût moyen.
C'est ce qui manque pour qu'existent une vallée, un col, un versant — et les frontières naturelles que
[[Décision — Monde fini]] promet en toutes lettres.

**Aucune eau douce dans le monde** : ni rivière, ni lac, ni écoulement calculé — **alors que l'automate d'eau est écrit
et tourne**. La seule eau posée par la génération est la mer, uniformément sous une altitude. Coût gros, et c'est le
manque le plus visible : le confluent, le gué, le delta, la source de montagne, la vallée fertile.

**Les gens ne s'installent pas où il y a de quoi vivre** : un village est **un dé à 4 %** par cellule, et sa vocation
est écrite après coup. Des villes au confluent, au col, au pied du filon — et des déserts humains entre elles.
Aujourd'hui la forme d'un royaume est un Dijkstra sur du bruit de danger.

**Le minerai est une table indexée sur le bruit de danger**, pas une histoire géologique. Le charbon dans les bassins
sédimentaires, le cuivre sur les arcs volcaniques, le marbre sous les vieilles chaînes : une **raison** de prospecter
ici plutôt que là, et un savoir de joueur qui se transporte d'un monde à l'autre.

### 4. Les PNJ

**L'humeur comme champ accumulé, et non comme formule réécrite chaque semaine.** *Le seul manque du dossier qu'un
sceptique ait confirmé sans réserve — et il l'a durci* : cinq lecteurs vérifiés, neuf écrivains. Aujourd'hui l'humeur
est **écrasée** chaque semaine sans jamais avoir été lue : **la ville oublie ses morts au tour d'horloge suivant.**
Coût petit. **Ce n'est pas un champ nouveau, c'est un défaut dans un champ que le coffre nomme déjà** — à ranger avec
les défauts de sauvegarde, pas devant les six champs décidés.

**La mémoire d'un être : ce qu'il a vu, de qui, et depuis quand.** *À moitié là* — la mémoire d'un être envers un
individu existe sous les noms `social.relations`, `social.opinions` et l'aggro. Ce qui manque est le **fait daté et
attribué** : voler sans témoin devient réellement impuni, voler devant un enfant devient dangereux plus tard. **C'est
le carburant du champ de rumeur déjà décidé.**

**Le lien entre deux êtres — un seul champ à la place de quatre tables parallèles.** *Vérifié absent.* Aujourd'hui la
simulation de société la plus riche du jeu (les opinions de quartier) n'est lue que par le dialogue. Un ami qui vient
à la rescousse parce que **l'IA** lit le lien ; un garde qui hésite devant son cousin.

**L'appartenance graduée : à quel point cet être tient à son groupe.** Coût énorme, et c'est **le manque le plus
criant du domaine** : *aucun PNJ ne peut devenir quoi que ce soit*. Un bandit n'existe que comme fiche de créature
peuplant un donjon — jamais comme un villageois affamé, sans lit, dont l'attachement à sa ville est tombé à zéro.

**Faire vivre un champ déjà là : la compétence des PNJ, l'apprentissage, la transmission.** Une ville produit mieux que
sa voisine parce qu'un maître y a formé trois apprentis ; **tuer le forgeron d'un village coûte vraiment quelque
chose** ; l'enfant qui hérite du poste hérite d'un savoir incomplet et le village décline.

**Le souhait promu en but lisible par l'IA.** Deux souhaits qui visent le même lit ou le même poste font un conflit
qu'on n'a pas écrit. *Réserve honnête du proposant lui-même* : si ça devient un planificateur d'actions à part, c'est
un système de plus.

> **Écarté** : une culture qui se propage (mode, religion, technique) **en tant que système**. Le champ de **rumeur**
> déjà décidé transporte exactement la même chose sur les mêmes routes de caravanes.

### 5. La boucle entre le joueur et le monde

**Le joueur n'écrit rien dans le champ économique qui existe déjà.** Coût **petit**, et la machinerie attend : la ville
qu'on enrichit grandit vraiment (la fonction qui bâtit des logements existe et attend de l'or) ; vendre cent peaux
fait tomber le prix des peaux **dans cette ville** ; acheter tout le grain d'un village y déclenche la pénurie.

**Le contrôle d'une cellule : qui la tient, en un nombre qui bouge.** Coût gros. *Le monde continue sans le joueur* :
deux royaumes se disputent une bande de cellules pendant qu'il est au fond d'un donjon, et la carte n'est plus la même
au retour.

**Le tableau de quêtes ne lit rien du monde** — et ce n'est pas un champ, c'est **un lecteur qui manque**, pour un coût
petit. Des quêtes que personne n'a scriptées : le village dont il a tué le forgeron affiche une prime pour en faire
venir un ; la ville qu'il a affamée demande du grain.

---

## L'histoire pré-simulée du monde : la réponse est non, et voici pourquoi

C'était la question la plus lourde. **Les faits d'abord**, tous vérifiés :
- **Le calendrier promet 1 019 années dont il n'existe pas une ligne de donnée.**
- **Un royaume naît adulte** à l'instant où on le regarde : son avènement est l'année de départ moins 0 à 30 ans, et il
  n'y a rien avant.
- **La diplomatie est explicitement sans mémoire, et c'est une décision écrite dans le code** : la relation entre deux
  royaumes est une *fonction pure* de la graine et de la paire. Deux royaumes ne se haïssent jamais **pour** quelque
  chose.
- **Une « ruine » n'est pas un lieu du monde** : c'est un thème de donjon. C'est un repaire de bandits qui s'appelle
  ruine.
- Le journal d'un royaume est **plafonné à dix entrées**, et le seul endroit où il atteint le joueur en lit **une**.
- **L'obstacle est structurel** : toute l'architecture des royaumes est bâtie pour que **l'ordre d'engendrement n'ait
  aucune importance** (génération paresseuse, par secteur, « on ne lie que le connu »). Or une histoire est globale et
  **ordonnée**. C'est au cœur du fichier.
- Ce qui joue **pour** : les royaumes ne sont pas sauvegardés, ils se refont de la graine. **Un passé qui est fonction
  pure de la graine ne coûterait pas un octet de sauvegarde.**
- Et le coffre a **déjà refusé l'histoire écrite** ([[Ouvert — Lore]] : des noms propres générés, jamais écrits à la
  main). La seule voie qui lui reste ouverte est l'histoire **engendrée**.

**Verdict** : pas de simulateur de figures historiques — c'est **le journal d'un champ, pas un champ**. Il aurait son
producteur unique et son écran unique, et ne partagerait aucune donnée avec le combat, l'IA, l'économie ou le terrain.
C'est le contre-exemple exact de la règle. **Mais trois choses petites donnent l'essentiel de l'effet** :

1. **La lignée : un enfant doit porter le nom de son parent.** C'est **déjà décidé dans le coffre** ([[Génération de noms]]) et **jamais codé** : à la naissance, le lien de filiation n'est pas écrit avant l'habillage, et le nom de
   famille est tiré indépendamment. Quelques lignes. *Ce que ça donne* : un nom qui revient — le garde s'appelle comme
   le roi mort dont on parle en ville.
2. **Amorcer le journal des royaumes à la génération**, en fonction pure de la graine, au lieu de le laisser vide.
   *Le défaut vérifié* : au début d'une partie, **aucun PNJ du monde ne peut parler de son royaume**, parce que la
   réplique de rumeur exige un journal non vide et que tout royaume naît avec un journal vide.
3. **L'identité du bâtisseur d'un lieu** — le royaume et la culture, **pas la date**. C'est ce que veulent le thème de
   donjon et le butin, et le canal existe déjà (`provenance`).

## Ce que je NE ferais pas

Aux trois refus de [[Émergence — les champs partagés]] — pas de physique continue, pas de chimie générale, pas
d'économie à agents — s'en ajoute un **quatrième** : **pas de simulateur de figures historiques (un mode « Legends »)**.
C'est le journal d'un champ, pas un champ ; la rumeur qui circule est le champ.

## Ce qui n'est pas à moi

- **L'ordre.** Rien ici ne passe devant les huit champs déjà décidés ni devant l'[[Ordre de travail]]. Trois lignes
  sont pourtant **petites et à fort effet**, et mériteraient d'être glissées tôt : l'humeur accumulée (c'est un
  défaut), la latitude et l'ombre pluviométrique, et le joueur qui écrit dans l'économie.
- **Jusqu'où va l'écosystème.** C'est le domaine le plus vide et le moins cher, mais il ajoute une simulation par
  cellule à un monde qui en a déjà une par semaine.
- **Si le monde doit avoir un passé du tout.** Le refus ci-dessus porte sur la *forme* (pas de simulateur de figures),
  pas sur l'envie. Les trois petites choses suffisent-elles ?

## Liens
- **Dépend de** : [[Émergence — les champs partagés]], [[Décisions fondatrices]], [[Grille continue]]
- **Alimente** : [[Ordre de travail]], [[IA des créatures]], [[Villes — population, quartiers et économie]]
- **Voir aussi** : [[Météo]], [[Eau et liquides]], [[Gaz dans le sol]], [[Agriculture et élevage]], [[Réputation et relations]], [[Génération des royaumes PNJ]]
