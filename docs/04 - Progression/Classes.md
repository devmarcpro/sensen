---
aliases: ["C.3", "Annexe C.3", "Classes", "Classes de départ", "Le Sabre", "Le Souffle", "La Braise", "La Trace", "La Balance", "Le Vent", "La Paume", "Le Creuset"]
tags: [progression, contenu, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!success] Renommées le 2026-08-26
> Les classes de départ passent de noms génériques (Guerrier, Mage, Artisan, Chasseur, Marchand, Vagabond) à des **noms français évocateurs**, cohérents avec [[Identité visuelle chinoise]] — *« ce qui distingue réellement Sensen, bien plus qu'une perspective »*. Chaque classe porte désormais un **talent** ([[Talents de classe]]).

Les 8 classes visibles : un kit **et un talent** qui définit une façon de jouer.

| Classe | Kit (stats + équipement + compétences de départ) | Talent |
|---|---|---|
| **Le Sabre** | +2 For/+1 End ; épée fer, bouclier bois ; niv. 5 en Épée, Bouclier | **Râtelier vivant** |
| **Le Souffle** | +2 Vol/+1 Per ; bâton, 1 grimoire simple ; niv. 5 en Magie, Méditation, 3 modules de base | **Communion des cinq** |
| **La Braise** | +2 Dex/+1 For ; outils complets qualité Correct ; niv. 5 en Forge et 1 métier au choix | **Main du métal** |
| **La Trace** | +2 Dex/+1 Per ; arc, 20 flèches ; niv. 5 en Arc, Dressage | **Meute** |
| **La Balance** | +2 Cha/+1 Per ; 500 or, étal portatif ; niv. 5 en Négociation, Lecture | **Œil du prix** |
| **La Paume** | +2 Vol/+1 Cha ; herbes et bandages, 1 grimoire de Vie ; niv. 5 en domaine Vie, Alchimie | **Souffle rendu** |
| **Le Creuset** | +2 Per/+1 Vol ; alambic portatif, 6 fioles ; niv. 5 en Alchimie, Herboristerie | **Fiole vive** |
| **Le Vent** | +1 partout ; rien ; +15 points de création en plus | **Sans maître** (aucun, mais peut en apprendre un) |

**Correspondance avec les anciens noms :** Guerrier → Le Sabre · Mage → Le Souffle · Artisan puis Forgeron → **La Braise** · Chasseur → La Trace · Marchand → La Balance · Vagabond → Le Vent.

**Ajoutées le 2026-08-26 :** **La Paume** (soigneur) comble le trou signalé — le design promettait que *« les builds de soutien ont un accès plein au système central »* ([[Jauge de chaîne Wu Xing]] : un soin en position finale résout à ×0.7) sans qu'aucune classe ne l'incarne. **Le Creuset** (alchimiste) donne un porteur à l'Alambic et aux potions.

> **Le renommage résout trois collisions de vocabulaire.** *Forgeron*, *Chasseur* et *Marchand* désignaient à la fois une classe, une créature ([[Créatures]]) et — pour les deux premiers — une fonction ([[Fonctions]]). Chaque mot ne désigne plus qu'une chose.

## Les onze classes cachées

Elles ne sont pas au menu de création : **elles s'apprennent d'un PNJ qui les porte** (relation ≥ 75, comme les recettes exotiques). Détail et talents : [[Talents de classe]].

**Le Passeur** (portails) · **Le Sablier** (tempo) · **Le Sceau** (glyphes) · **Le Masque** (postures) · **Le Porteur** (saisit et lance) · **L'Ombre** (dissimulation, pièges) · **L'Écarlate** (jauge de sang) · **Le Rieur** (dés) · **Le Fossoyeur** (relève les morts) · **La Mèche** (bombes) · **L'Engrenage** (tourelles).

**Les deux dernières sont technologiques**, et c'est pour ça qu'elles sont cachées : la technologie du monde se **retrouve** dans les ruines profondes, comme les recettes du [[Palier industriel]]. Un tourellier s'apprend au même endroit qu'un haut fourneau.

## Ce qui a changé, ce qui n'a pas changé

**Ce qui a changé :** la classe ne détermine plus *uniquement* le kit de départ — elle porte un **talent permanent** ([[Talents de classe]]).

**Ce qui n'a pas changé :** **aucun plafond, aucune pénalité** liés à la classe. *Le talent est un plancher, pas une cage* — tous les slots restent libres, le build émerge par-dessus.

**Ce qui a bougé de catalogue :** « artisan » n'est plus une classe mais une **fonction** ([[Fonctions]] : craft et vend ce qu'il craft) ; *ce* qu'un artisan produit dépend de sa classe.

**Potentiels de base ([[Potentiel]]) :** chaque race ([[Races]]) ET chaque classe définit ses potentiels de base par stat et par familles de compétences (champ `base_potentials`) — ex. Le Souffle : domaines de magie 120, armes lourdes 60. Les valeurs vivent dans `data/classes/` ([[Décision — Pipeline de contenu]]).

Race et classe **s'additionnent** : le plancher final est la moyenne des deux valeurs quand elles diffèrent (un Nain Souffle a 90 en Forge et 90 en magie — ni spécialiste ni nul). C'est ce qui rend les combinaisons mécaniquement distinctes.

**Équipement initial ([[Début de partie]]) :** kit de la classe, rien d'autre.

> [!success] Corrigé le 2026-08-29 — cinq classes cachées distribuaient des compétences qui n'existent pas
> Trouvé par `tools/audit_donnees.py` : les fiches des classes cachées, écrites à la main, donnaient des niveaux de départ dans **`arcanes`**, **`tir`**, **`artisanat`** et **`perception`** — quatre ids absents de `data/competences/` (les vrais sont `magie_arcane`, `arbalete`, `forge`…, et *perception* est une **stat**, pas une compétence). Les points partaient dans le vide : ni fiche, ni famille de potentiel, ni progression par l'usage. Corrigé au plus près du thème de chaque classe : **Le Passeur** magie de l'Espace + Athlétisme, **Le Sablier** magie Arcane + Esquive, **Le Sceau** Enchantement + Encaissement, **Le Fossoyeur** magie de la Corruption + Encaissement, **L'Engrenage** Arbalète + Forge. L'audit vérifie désormais que toute compétence citée par une classe existe.

> [!success] Codé le 2026-09-02 — les 57 capacités de départ relues une à une (designer, point 72)
> Quand la portée est devenue un module, les capacités des 19 classes l'ont reçu par **transcription mécanique** de l'ancienne portée implicite de leur forme. Or presque toutes les formes portaient à 5-6 tuiles : **les 57 capacités se sont donc retrouvées en `jet_long`**, sans exception. L'Écarlate — la classe de sang, d'épée et d'encaissement — lançait son Saignement à six tuiles, et payait cinq ticks pour ça.
> Chaque capacité porte maintenant la portée de **son style**, lue sur les compétences de départ de sa classe : `contact` pour celles qui vivent au corps à corps (L'Écarlate, L'Ombre, Le Sabre, Le Masque, Le Porteur, Le Rieur), `jet_court` pour les érudits et les alchimistes, `jet_long` pour les tireurs et les mages de feu, et `sur_soi` pour les formes qui **suivent le trajet du lanceur** (`chemin`) — elles n'avaient aucun sens ancrées sur une tuile lointaine. Une classe de mêlée gagne au passage les ticks qu'elle payait pour une portée dont elle n'avait pas l'usage.


> [!bug] Corrigé le 2026-09-02 — un personnage neuf ne pouvait pas frapper du tout
> Trouvé en relançant le robot de parcours après la journée de refonte du combat : **trois morts, quinze coups reçus, zéro coup porté**, et une ligne qui disait tout — « cible abandonnée : d=1, portée (1, 1) ». À distance 1, avec la ligne de vue, l'attaque était refusée vingt fois de suite.
> **Deux causes, toutes deux des écarts avec ce que dit le coffre.** D'abord, les **19 classes avaient un `equipement` et un `ratelier` vides** alors que cette note et [[Création de personnage]] promettent un *kit de départ* : un personnage créé arrivait donc **les mains nues et sans armure**. Ensuite, `_attaquer_arme` refuse une main vide — or il n'existait **aucune fonctionnalité « mains nues »**, malgré une compétence `mains_nues`, une dureté `mains_nues_durete` et une affinité de sorts dédiée dans les règles. Le Masque et Le Porteur, dont l'identité **est** le combat à mains nues, ne pouvaient pas se battre.
> **Corrigé des deux côtés** : chaque classe reçoit le kit de son style (arme, bouclier ou arc, armure de cuir, torche) et son râtelier ; et une main vide frappe désormais avec la fonctionnalité `mains_nues` — `1d3` contondant, portée 1, dureté 1 — qui existait partout sauf là où il fallait.


> [!success] Tranché le 2026-09-02 — **retravailler les classes en profondeur** (designer)
> « Retravaille les classes en profondeur. » Le banc mesure un écart de **43 fois** entre la première et la dernière : Le Sabre rend 16,20 PV par tick avec Projection, Le Fossoyeur 0,38 avec Roche. Les trois classes de tête frappent toutes **au contact** — le contact ne paie ni portée, ni dilution, ni atténuation, et frappe une seule cible à pleine puissance. Les dernières sont lointaines et lentes : vingt ticks pour deux points de vie.
> Le designer ne demande pas un réglage mais une **reprise de fond**. Ce n'est donc pas « ajouter des dés aux classes faibles » : c'est relire ce que chaque classe **promet** et vérifier que son kit de départ le tient. Une classe lointaine doit payer sa distance par autre chose que l'impuissance — de la portée utile, du contrôle, de la zone, ou des noyaux assez gros pour que la dilution ne la vide pas.
> **Fait le 2026-09-02.** Les dix-neuf kits sont réécrits. Ce que la mesure a montré en cours de route, et qui n'était pas ce que je croyais :
> - **Le problème n'était pas la portée, c'était la FORME.** Le même noyau `eclat` rendait 46 PV en `point` et 5 PV en `diagonale` — la forme étale la puissance sur ses tuiles, la dilution fait le reste. Les classes lointaines n'étaient pas vidées par leur distance mais par des formes larges qu'on leur avait données sans y penser.
> - **Toutes les classes puisaient dans la même poignée de noyaux** — étincelle, éboulement, ronce, flamme — avec pour seule différence leur portée. Quatre-vingt-huit noyaux existent en dix familles ; les kits n'en touchaient qu'une trentaine, presque tous des dégâts. Le Passeur lançait des brasiers au lieu d'ouvrir des brèches, Le Fossoyeur gelait au lieu de relever.
> - **Le banc a une règle que je ne connaissais pas** et qui est juste : une seule capacité sans effet mesurable par classe, **sa signature**. Les autres doivent faire quelque chose. Douze kits violaient cette règle après ma première passe ; la seconde les a corrigés.
> **Résultat** : zéro souci au banc, et l'écart du meilleur au pire rendement offensif passe de **43 fois à 11 fois** — Le Rieur à 6,75 PV par tick, Le Passeur à 0,62. Ce qui reste tient à la règle : le contact ne paie ni portée ni dilution, et les gros noyaux lointains coûtent vingt ticks. **Les chiffres du banc varient d'un passage à l'autre** (l'arme équipée change les sorts de contact) : ils disent un ordre de grandeur, pas une valeur.
> **La règle que je ne toucherai pas sans qu'on me le dise** : la dilution en 1/√n, l'atténuation par la distance et le coût en ticks de la portée sont des décisions du designer. C'est le **contenu** des classes qui bouge, pas le moteur.

> [!success] Tranché le 2026-09-03 — **classe et sous-classe** (designer)
> « Il y a la classe du personnage, et la classe/style de jeu — par exemple mage avec volonté. » Puis : « ce qu'on a qu'à faire, c'est la classe et la sous-classe : les 19 qu'on a, triées par classes. »
> **Une classe mère par stat**, comme il y a désormais une famille d'armes par stat, et les dix-neuf classes historiques deviennent ses **sous-classes**. Le tri suit la **stat dominante que chaque sous-classe déclarait déjà** dans son `bonus_stats` : il ne décide rien, il rend visible ce qui y était écrit.
>
> | classe | stat | sous-classes |
> |---|---|---|
> | **Guerrier** | force | L'Écarlate · Le Porteur · Le Sabre · La Braise |
> | **Rôdeur** | dextérité | L'Engrenage · L'Ombre · La Mèche · La Trace · Le Masque |
> | **Mage** | volonté | La Paume · Le Fossoyeur · Le Passeur · Le Sablier · Le Souffle |
> | **Sentinelle** | endurance | Le Vent · Le Sceau |
> | **Érudit** | perception | Le Creuset |
> | **Meneur** | charisme | La Balance · Le Rieur |
>
> **Le déséquilibre est hérité, pas inventé** : cinq sous-classes pour le rôdeur et le mage, **une seule** pour l'érudit. C'est la répartition qui existait déjà dans les données ; la ranger l'a simplement rendue visible. Reste au designer de décider s'il faut la corriger ou l'assumer.
> **`verif_classes.tscn` garde la structure** : elle échoue si une sous-classe ne relève d'aucune classe — elle serait injouable à la création — ou si une classe n'a aucune sous-classe, ce qui serait un nom vide dans le menu.

## Liens
- **Dépend de** : [[Création de personnage]], [[Les trois axes — race, classe, fonction]]
- **Alimente** : [[Talents de classe]], [[Potentiel]], [[Début de partie]], [[Fonctions]]
- **Voir aussi** : [[Races]], [[Talents de race]], [[Compétences — liste]], [[Identité visuelle chinoise]], [[Créatures]]

> [!success] Décidé et codé le 2026-09-04 — l'arme de départ d'une classe est une arme de la **voie de sa classe mère**
> Mesuré avec le robot, une fois qu'il a su changer de classe et garder son kit : **sept classes sur dix-neuf partaient avec le même bâton magique en cuivre**, dont l'érudit (Le Creuset), la meneuse (La Balance) et la sentinelle (Le Sceau) — trois classes mères qui ne sont pas la volonté. Le Fossoyeur, un mage, partait à la masse. Et deux rôdeurs (L'Engrenage, La Trace) partaient à l'arc, qui est depuis le 3 septembre l'arme du tireur, pas de la lame rapide.
> La règle du 3 septembre dit : une voie par stat, une famille d'armes par voie, et la classe mère d'une classe est sa stat. Un kit qui met un bâton de mage dans les mains d'une meneuse contredit cette règle avant même le premier combat. On applique donc, sans toucher aux talents ni aux capacités : **Le Creuset** part à la **sarbacane** (perception — l'érudit alchimiste et ses fléchettes), **La Balance** au **luth** et **Le Rieur** à la **flûte** (charisme — les instruments sont les armes du meneur), **Le Sceau** à la **lance** (endurance — la sentinelle tient la ligne), **Le Fossoyeur** au **bâton magique** (volonté). **L'Engrenage** et **La Trace** gardent leur arc : c'est leur classe mère qui change, de rôdeur à **érudit**, parce que c'est l'arc qui dit qui elles sont — trois érudits, trois rôdeurs. Le Porteur et Le Masque restent à mains nues, c'est leur identité. Les kits de capacités doivent tenir dans la grille de la nouvelle arme : `verif_classes` le vérifie.
> Ce que ça ne règle pas, et qui reste au designer ([[À juger — parcours de jeu]]) : la **qualité** des armes de départ (pauvre / misérable), avec laquelle quatre classes sur six ne tuent rien au premier étage.
