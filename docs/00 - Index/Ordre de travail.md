---
aliases: ["Ordre de travail", "File d'attente", "Ce qu'il reste à faire", "Priorités"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 12
---

Tout ce qui reste à faire, dans un seul ordre. Demandé par le designer le 2026-09-08 : « organise par ordre les choses
à faire », puis « pour que l'ordre soit plus logique ».

## Comment cet ordre a été obtenu

La première version rangeait par **gravité** — ce qui abîme le plus ce qu'on construit dessus. C'était un ordre
décrété. Celui-ci est **déduit** : six agents ont lu le code pour extraire les dépendances réelles (qui bloque quoi,
quoi vit dans le même fichier, quel travail serait jeté s'il était fait trop tôt), puis quatre ordres complets ont été
proposés sous quatre principes concurrents — dépendances techniques, localité de fichier, valeur pour le joueur,
risque de travail jeté — chacun obligé d'avouer les dépendances qu'il violait. Les 66 dépendances trouvées sont dans
[[Vers la production]] ; les plus contre-intuitives sont citées ci-dessous à l'endroit où elles commandent l'ordre.

**Trois règles de tri, dans cet ordre de priorité :**
1. **Une dépendance technique l'emporte sur une préférence.** Si A serait refait ou annulé par B, A passe après B.
2. **Un fichier, une séance.** Ce qui se corrige dans le même fichier se corrige le même jour. `sim_sauvegarde.gd`
   porte cinq lignes ; `main.gd` en porte quatre ; `combat_rules.json` en porte trois.
3. **À dépendances égales, le moins cher passe devant** — surtout s'il débloque beaucoup.

**Les décisions du designer sont traitées comme des arêtes du graphe, pas comme des préférences** : « les champs
d'abord, la suppression des modules ensuite », la grammaire qui survit, et l'ordre des six champs confirmé le
2026-09-08 à 7 h.

---

> [!question] Toutes les questions qui attendent le designer sont désormais dans **une seule note** : [[Décisions en attente]] (21 questions, écrite le 2026-09-08). Le palier 0 ci-dessous n'en garde que les deux qui commandent l'ordre de ce document.

## Palier 0 — deux questions, zéro ligne de code

Elles coûtent au designer une phrase, et elles coûtent une semaine si elles arrivent tard.

1. **Le sens de la vérité des catalogues.** La note redevient-elle la source (il faut alors valider à la main les 94
   lignes reversées et les chiffres étirés), ou la donnée devient-elle la source et la note son reflet ? **Tant que ce
   n'est pas tranché, les tables réalignées le 2026-09-08 rederiveront au prochain équilibrage** — c'est exactement ce
   qui est arrivé une première fois.
2. **Les champs avant ou après le jeu fini ?** Le designer a tranché l'ordre *des six champs entre eux*, pas leur place
   par rapport à la pause, la mort et les touches. Cet ordre-ci les place après (paliers 1 à 3), en le disant.

## ~~Palier 1~~ — la séance `sim_sauvegarde.gd` : la partie te revient entière — **FAIT le 2026-09-08**

> [!success] Les six défauts sont corrigés et prouvés — voir [[Sauvegarde]] (callout du 2026-09-08).
> `test_sauvegarde_des_lieux` couvre la mine, le gouffre et le donjon de corruption ; `test_sauvegarde_ne_touche_pas_la_partie` vérifie qu'une sauvegarde en plein combat ne le dissout pas.
> **Reste de ce palier** : le **thread** et la copie-sur-écriture (la sauvegarde s'écrit toujours en entier sur le fil principal, alors que cette note exige un thread) — la seule ligne du palier qui demande encore du travail.

**Six des sept lignes vivent dans deux fichiers seulement.** Une seule séance sur `sim_sauvegarde.gd` couvre quatre
défauts du palier, plus la purge des objets du palier 11.

3. **Le drapeau `mine` et la relecture de `mines_creusees` doivent atterrir ENSEMBLE** — restaurer l'un sans l'autre
   régénère la mine en roche pleine, exactement ce que le joueur perd aujourd'hui. Et la relecture doit se placer
   **avant** l'appel à `charger_donjon`, pas seulement avant le `return` : `charger_donjon` lit `sim.mines_creusees`.
4. **`charger_donjon` doit fusionner au lieu d'écraser `sim.donjon`.** Ce n'est **pas** un défaut de sauvegarde : il
   frappe en session vivante — descendre d'un étage dans un gouffre perd déjà `gouffre`, entrer dans un donjon de
   corruption perd déjà `corrompu` et `niveau`. **C'est la ligne qui débloque le plus de tout le graphe** : elle
   commande les lignes 12, 13 et 27.
5. **`gouffres_vides` est une persistance entièrement morte**, pas seulement mal rechargée : son unique écrivain en jeu
   est inatteignable parce que `charger_donjon` a détruit la clé `gouffre` 42 lignes plus haut, dans la même fonction.
   La corriger sans la ligne 4 ne fait que relire un dictionnaire toujours vide.
6. **`Monde.nettoyages` n'est jamais sauvegardé** → un donjon de corruption vaincu revient.
7. **`sauvegarder()` dissout le combat en cours** sans passer par la fin de combat.
8. **L'écriture atomique — et le piège.** Le `remove` avant `rename` est là parce que `DirAccess.rename_absolute`
   échoue sur Windows quand la cible existe : **le retirer naïvement fait échouer toute sauvegarde après la première**.
   En revanche, une seule ligne déplacée retire la moitié du risque : `world.json` est écrit **en premier** et c'est le
   seul fichier que `Sauvegarde.existe` teste — une coupure au milieu laisse une partie que l'écran Charger liste comme
   valide. **L'écrire en dernier.**
9. **La purge de `sim.objets`** (78 % de fantômes) vit trois lignes au-dessus de la boucle de surface : à faire pendant
   que le fichier est ouvert. **Piège** : le RNG du butin est semé sur `sim.objets.size()` — purger le dictionnaire
   vivant casserait le déterminisme. Purger **à l'écriture seulement**, ou passer par un compteur monotone.
10. **Le thread et la copie-sur-écriture**, plus le test de sauvegarde en expédition étendu à la mine, au gouffre et au
    donjon de corruption. **Un seul des neuf allers-retours de sauvegarde du dépôt entre dans un donjon** — c'est très
    exactement pourquoi six défauts ont survécu à 2 376 assertions vertes.

> *Après ce palier* : une partie rechargée est la partie qu'on avait quittée.

## ~~Palier 2~~ — le chantier matériaux est rouvert — **FAIT le 2026-09-08**

> [!success] `gen_materials.py` ne détruit plus rien et reproduit les 247 fiches champ par champ — voir [[Matériaux — 13 stats]] (callout du 2026-09-08). Il fallait bien plus que « trois lignes » : sept champs à préserver, cinq alias d'identifiant, 92 couleurs à reverser dans la note, et un motif de lecture aveugle aux minuscules. `tools/verif_generateurs.py` le prouve et empêchera la dérive de revenir.
> **Ce qui reste** : le **sens de la vérité** (palier 0, question 1) — sans réponse, les tables et la palette rederiveront au prochain équilibrage.

**Le meilleur rapport déblocage/coût de tout le graphe.** Trois corrections de quelques lignes dans un seul fichier.

11. **Désamorcer `gen_materials.py`** : ajouter *Animal* à `CATALOGUES`, aligner 5 identifiants mal slugués, et
    reporter `palier`, `stats_base` et surtout **`sous_categorie`** — la seule des trois que le jeu lise vraiment
    (76 fiches). **Aujourd'hui le script ne détruit rien : il plante** sur le contrôle de palette avant d'arriver à la
    suppression. Ce garde-fou est **accidentel** et saute dès qu'on complète la palette : la préservation des clés doit
    donc se faire **avant ou avec** la palette, jamais après.
12. **Puis la palette** (mécanique et sûre : les 247 fiches portent déjà 247 couleurs distinctes), **puis** l'outil
    tables ← fiches — `tools/regen_catalogues.py`, désormais dans le dépôt, mais suspendu à la réponse du palier 0.

> *Après ce palier* : tout chantier matériaux redevient sûr — donc les cinq stats s'ouvrent, donc trois champs
> s'ouvrent derrière elles.

## ~~Palier 3~~ — la séance `main.gd` : le jeu redevient un jeu — **FAIT le 2026-09-08**

> [!success] Pause, écran de mort, `InputMap` et réglages persistés — prouvés par `sonde_ecrans`, qui monte `main.tscn` en entier. Voir [[Écrans d'interface]] (callout du 2026-09-08).
> **Ce qui reste de ce palier** : le **rappel des touches en jeu** (il peut maintenant LIRE l'InputMap au lieu d'être une troisième liste à la main), l'**écran d'options complété** (résolution, taille de texte, remappage à la souris), et **Options + Quitter au menu Tab**. Le socle est là ; il ne manque que l'écran qui l'affiche.

Quatre lignes dans deux fonctions du même fichier, plus une séance sur les écrans. **Deux chaînes de dépendance
internes**, et elles comptent.

13. ~~**Trente secondes** : effacer les chaînes d'aide mortes des CSV.~~ **FAIT le 2026-09-08** — elles étaient
    trois, pas deux ; et le nettoyage a révélé qu'une clé vivante (`arena.banc_objets.name`) était écrite **dans** le
    bloc que `gen_materials.py` régénère : elle a été effacée en silence, puis remise **hors** du bloc, et le
    générateur refuse désormais d'écraser un bloc qui contient autre chose que des clés `material.`.
14. ~~**Le menu de triche sur `V`**~~ **FAIT le 2026-09-08** — une garde, pas une suppression : la note du designer
    l'emporte sur la file. `V` n'ouvre plus rien dans un exécutable publié (`--export-release`), et le designer garde
    une porte de service (`Sensen.exe -- --triche`). Voir [[Écrans d'interface]].
15. **La pause n'est pas à inventer, elle existe** : le chargement coupe déjà l'horloge du monde. Il s'agit de la
    rebrancher sur « un écran est ouvert ». **Piège** : couper l'horloge NE SUFFIT PAS — en donjon, le monde avance par
    une boucle que le drapeau n'arrête pas ; il faut le retour anticipé en plus. Et **ZQSD échappe à toutes les gardes
    d'écran parce qu'il est sondé, pas événementiel** : le défaut n'est pas dans les écrans, il est dans la boucle de
    corps. Comme le designer a décidé « une option = une lettre », les quatre touches de marche *sont* quatre lettres
    d'option.
16. **L'écran de mort — et c'est deux chantiers, pas un.** L'écran est du client ; mais « avant d'avoir dormi une fois,
    mourir ne coûte rien » est une **règle de simulation**. Un écran seul ne répare pas la seconde moitié.
    **La pause doit précéder la mort** : un panneau de mort par-dessus un monde qui tourne est le même défaut sous un
    autre nom.
17. **L'`InputMap` doit précéder le rappel des touches**, sinon le rappel devient une **troisième** liste écrite à la
    main après le README et les chaînes mortes — c'est-à-dire la reproduction exacte du défaut qu'on répare.
18. **La sortie propre, les options enregistrées, Options et Quitter au menu Tab, la résolution et la taille de texte**
    — même séance sur les écrans, fonctions voisines.
    **Avertissement** : aucun test headless ne tape une touche. Le juge de tout ce palier est la sonde des écrans, à
    lancer à part, pas la suite.

> *Après ce palier* : on peut le mettre en pause, mourir, et le jouer avec ses mains.

## ~~Palier 4~~ — le donjon dit la vérité — **FAIT le 2026-09-08**

> [!success] Les quatre lignes sont faites et prouvées — voir [[Jauge de chaîne Wu Xing]] (callout du 2026-09-08). **Trois des quatre étaient un seul emprunt de vocabulaire** : `chain_gauge`, le drapeau de la jauge de chaîne Wu Xing, servait à dire « c'est le boss ». La quatrième n'était pas le bug annoncé : perdre la jauge en changeant de corps est **voulu** (elle est au corps, pas au joueur) ; ce qui manquait, c'était de le **dire**.

Débloqué par la ligne 4, et **il partage vingt-cinq lignes de code avec le palier 1** : `Monde.nettoyages` s'écrit dans
le bloc exact qu'il faut rouvrir. Les deux se font dans la même passe, ou l'on édite ce bloc deux fois.

19. **`chain_gauge` cesse de vouloir dire « c'est le boss »** — aujourd'hui une brute de couloir donne un artefact
    garanti et marque le donjon nettoyé.
20. **Le troisième angle du même défaut est une faute d'indentation** : la quête « videz le donjon » et le signal
    `dungeon_cleared` sont sous la branche « donjon corrompu, boss **non** vaincu ». La quête ne se valide donc que si
    l'on a échoué — et jamais dans un donjon ordinaire.
21. **Un boss propre par thème** (les douze créatures de folklore). **Bloqué par la ligne 19, et c'est contre-intuitif** :
    ça ressemble à huit valeurs JSON, mais poser le drapeau sur des créatures de folklore **multiplie le défaut 19 par
    douze** tant qu'il signifie « artefact garanti ».
22. **Incarner un compagnon cesse de faire perdre la jauge de chaîne en silence** (dix lignes, aucun bloqueur : peut
    sauter n'importe où, y compris dans la journée du palier 1).
    **Deux tests encodent le bug et tomberont volontairement** — ils posent le drapeau sur un loup pour exiger un
    artefact, et attendent le chef de bande en dur.

## Palier 5 — les champs, chacun apparié à sa stat

**Les cinq stats ne peuvent pas être posées d'un coup** : la sonde des stats de matière sort en échec dès que plus
d'une stat n'est lue par aucune formule. Cinq stats posées avant leurs champs = quatre muettes = sonde rouge.
**Ce n'est donc pas un chantier, c'est cinq chantiers appariés.** Et après le palier 2, ce sont quatre chemins
**parallèles**, pas une chaîne.

22 bis. ~~**L'inertie thermique**~~ — **FAIT le 2026-09-08, sur une question du designer.** Le champ de chaleur ne lisait que `isolation` alors que la note promettait aussi `densite` (la masse thermique). Corrigé : une matière dense met du temps à changer de température. *Leçon de méthode : la promesse était relevée dans la note du matin mais absente de cette file — c'est la question du designer qui l'a rattrapée, pas moi.*

23. **`fusion`** — la seule des cinq dont le consommateur existe déjà. Elle **finit** le champ de chaleur : la neige
    fond, l'eau gèle, la cire coule, le sable vitrifie, le minerai devient lingot. C'est aussi elle qui permettra à la
    chaleur d'absorber enfin la neige, le gel et la température ressentie.
24. **Le champ de danger — et il n'a AUCUN bloqueur.** Ni stat, ni champ préalable ; ses trois sources existent déjà
    (chaleur, gaz, lave) et la structure à remplacer est là, binaire, lue par le noyau C++ et par deux endroits de
    l'IA. **C'est le seul chantier de ce palier codable aujourd'hui.** L'ordre du designer le place après le bruit : je
    le signale sans le réordonner — c'est sa décision.
25. **Le champ de support** avec `portance` — l'effondrement, la seule chose qui sépare une mine d'un gouffre.
26. **Le champ sonore** avec `absorption`. **Il ne peut pas s'appeler `bruit`** : le mot désigne déjà le bruit de
    Perlin partout dans le code. À trancher avant la première ligne.
    *(Note : le module `absorption` existe aussi dans le catalogue des noyaux — il meurt au palier 6, mais tout grep
    sera ambigu pendant les deux chantiers.)*
    **Et une bonne nouvelle mesurée** : le piège annoncé — « bâtie sur le patron de la lumière, elle hériterait du
    défaut au carré » — **a été évité**. Le champ de chaleur a écrit son propre patron incrémental. La dépendance court
    donc **dans l'autre sens** : c'est la carte de lumière qu'il faudra refaire sur le patron de la chaleur. Celui qui
    écrira le son doit copier la chaleur, surtout pas la lumière.

## Palier 6 — les 236 contenus meurent, la grammaire reste

27. **Supprimer les 236 contenus de modules**, les branches d'effet en dur et les listes des fiches de classe.
    **Correction du chiffre** : ce ne sont pas 13 fichiers de tests qui dépendent des modules mais **15**, dont un avec
    40 références, plus **57 capacités écrites en dur dans les 19 fiches de classe**.
    Techniquement, aucun champ ne bloque cette suppression : **c'est une décision d'ordre du designer, pas une
    dépendance** — et elle est bonne, parce qu'elle garde le filet levé pendant la partie risquée.
27 bis. **Les corps en mouvement ont une masse et une quantité de mouvement** — *décidé le 2026-09-08 : « les modules
    seraient des modulations des règles du monde. Donc oui on a besoin de l'inertie — par exemple un sort qui jette un
    rocher droit devant ».* **Aujourd'hui un projectile est une ligne de Bresenham résolue d'un coup** : rien ne voyage,
    rien n'a de masse. Il faut un corps lancé qui traverse les tuiles au fil des ticks, avec `masse × vitesse` comme
    donnée partagée — lue par les dégâts, le recul, la destruction du terrain, le champ de bruit et le support.
    La donnée d'entrée existe : `Regles` calcule déjà le poids d'un objet depuis la `densite` de sa matière.
    **Trois sources, une seule règle** (précisé le 2026-09-08) : la même `masse × vitesse` qu'elle vienne d'un bras,
    d'une hauteur ou d'un moteur. Ce qui manque est étroit : `degats_chute` ne connaît que la **hauteur** (un
    caillou et un bloc de granit font le même mal), une chute ne blesse **que celui qui tombe** — lâcher un
    rocher sur un ennemi d'un étage plus bas ne lui fait rien —, et un véhicule (`caleche`, `train`, codés) ne
    heurte personne. La règle unique **absorberait** les dégâts de chute, la ligne de projectile, l'éboulement du
    champ de support et donne au véhicule sa collision gratuitement : quatre règles, une donnée.
    **C'est un préalable à la ligne 28** : on ne module que ce qui existe, et « lancer » doit être une règle du
    monde avant d'être un noyau de sort. **Trois arbitrages appartiennent au designer** avant de coder — le grain de la
    vitesse sur une grille à ticks, la propagation du recul, et si le joueur lui-même est un corps avec un élan.

28. **Réécrire les contenus sur les champs** : un noyau de feu dira `{chaleur: 400}` et le reste suivra seul.
    **Reformulé le 2026-09-08** : un module ne produit plus d'effet, il **tourne un bouton d'une règle du monde**.
    Conséquence directe : **chaque champ manquant est un module qu'on ne pourra pas écrire.**
    **Ce palier dissout deux lignes plus bas** : les 23 sorts qui ne produisent rien disparaissent entièrement, et la
    moitié « données » du sort au contact gratuit avec eux.

## Palier 7 — les quatre champs restants, dans l'ordre du designer

29. **La rumeur qui circule** (aucun bloqueur — elle pourrait se faire au palier 5 ; l'ordre du designer la place ici).
29 bis. **Les factions par tags idéologiques** — *validé le 2026-09-08 sur un avis extérieur, voir [[Vers la production]] ligne 149.*
    **Le fait vérifié** : `Surface._lier_royaumes` calcule la relation entre deux royaumes à partir d'**attributs
    présents** (race, culture, gouvernance, écart de taille) plus un aléa, et son commentaire le dit lui-même —
    « une fonction **PURE** de la graine et de la paire ». **Deux royaumes ne se haïssent jamais POUR quelque chose**,
    et rien de ce que fait le joueur ne change une relation entre pays.
    **Ce qu'il faut** : des actions qui portent des **tags** (`nature_detruite`, `industrie`, `sang_verse`…) et des
    factions qui portent des **valeurs**, la réputation s'ajustant seule. La matière première existe : cultures par
    région, types de gouvernance, réputation à trois étages, vecteurs Wu Xing.
    **Il est ici et pas ailleurs parce qu'il est le lecteur naturel de la rumeur** : elle transporte le fait, les tags
    décident qui s'en offusque. À faire **avec** la ligne 29, pas avant.
30. **Le temps long** — usure, ruine, repousse — avec `alteration`.
31. **Les besoins au-delà de la faim** : soif, sommeil, peur qui dure (aucun bloqueur non plus).
32. **L'eau qui pèse** — pression, poids, érosion — avec `permeabilite`.

## Palier 8 — les nombres cessent de mentir

32 bis. **L'équipement d'un PNJ et le stock de sa ville** — **RÉFUTÉ le 2026-09-08 sous la forme annoncée**, par trois
    sceptiques indépendants qui convergent. Ce qui a été vérifié à la main derrière eux :
    - **Le stock est vide à l'instant précis où un garde reçoit son épée.** `creer_territoire` pose `stocks: {}` et la
      boucle des PNJ suit **immédiatement**, dans la même fonction. Pondérer par un dictionnaire vide = facteur 1
      partout = la distribution d'aujourd'hui, au bit près.
    - **Il n'y a pas de « prochains gardes ».** Le repeuplement engendre des `villageois` (équipement vide), et un garde
      vivant n'est **jamais ré-équipé** : son kit est tiré une fois, puis sauvegardé. La boucle de rétroaction promise
      n'a **aucun client**.
    - **« Du cuir et du bois » est hors d'atteinte** : `chene` est **palier 3**, donc écarté du tirage à niveau 1 ;
      `fer` est **palier 2**, donc déjà plafonné. Une pondération multiplicative ne peut pas ressusciter une clé
      absente. Il faudrait changer la règle des paliers **pour tout le jeu, donjons compris** — autre décision.
    **Ce qui survit, et qui est vrai** :
    - **Le marchand itinérant et le stock d'échoppe**, eux, lisent une ville dont les stocks sont **remplis** : c'est là
      qu'une ville appauvrie deviendrait visible sans inventer une seule donnée. *Petit, et ça marche.*
    - **À l'engendrement, lire le PÉRIMÈTRE et non le stock** : `per.dominant` est renseigné **avant** la boucle des
      PNJ. Résultat honnête : « un garde d'un village posé sur un filon de cuivre porte du cuivre » — de la
      **géologie**, pas de l'économie. Et le seul écart visible dans la palette est le cuivre (orange) et le laiton
      (doré) contre cinq gris : le paperdoll ne peint que la pièce maîtresse.
    **À trancher par le designer** : faut-il une **relève de garnison** (un repeuplement qui puisse rendre un garde) ?
    Sans elle, rien de ce qui précède ne peut mordre sur les gardes.
    *Leçon de méthode : cette vérification a coûté six agents et évité d'écrire une fonctionnalité qui n'aurait rien
    changé à l'écran. C'est exactement ce à quoi sert la réfutation avant de coder.*

## Palier 9 — le jeu montre ce qu'il sait

**Les trois lignes sont le même travail dans les mêmes trois fichiers**, et la plus visible est presque gratuite : la
fonction qui met en forme le coût d'une capacité et sa chaîne traduite existent depuis longtemps, personne ne les
appelle.

37. **Le coût d'une capacité, écrit au moment de la lancer** (le déficit se paie en points de vie).
38. **La réputation à l'écran** — village, royaume, globale.
39. **Le refus visible** : aujourd'hui il part au journal, que le panneau recouvre.

## Palier 10 — ce qui existe et qu'on ne verra jamais

39 bis. **Le voyage devient un TRAJET** — ⚠️ **SUSPENDU le 2026-09-08 à 15 h 30** : le designer veut revoir l'exploration et la génération du monde en entier (« plus Caves of Qud / Dwarf Fortress que JRPG classique / Elin / Elona », [[Vers la production]] ligne 154). Un trajet cellule par cellule sur un écran de carte est une amélioration *dans* le modèle actuel ; si le modèle change, elle devient sans objet. **Ne pas coder avant d'en avoir reparlé.** — *décidé le 2026-09-08 : « un système comme Fallout 1 où le joueur clique
    n'importe où sur la carte et le personnage s'y déplace petit à petit avec événements ».* Aujourd'hui cliquer loin
    **téléporte** (l'horloge avance du coût entier d'un coup) et le pas à pas de cellule en cellule est le « Dragon
    Quest » que le designer veut remplacer. Les pièces existent : coût par cellule, réduction par la route, gestion de
    l'arrivée, pas d'une cellule. Le trajet, c'est **une file de cellules, une cadence et un point d'interruption**.
    **Il est ici et pas plus haut parce qu'il est le théâtre des « événements en zone logique »** (ligne 43), qui n'ont
    aujourd'hui aucun endroit où se produire, et parce que la fréquence des rencontres voudra lire le **champ de
    danger** (ligne 24). Le faire avant, c'est le faire deux fois. Voir [[Carte du monde]].


40. **Effacer le code mort de la génération de village.** *La ligne d'origine était fausse et à l'envers* : les
    bâtiments **se rangent** le long des rues depuis le 2026-09-07 ; ce sont deux autres fonctions qui n'ont plus
    d'appelant, dont celle qui tirait au hasard. Il ne reste qu'à supprimer.
41. **Poser la bibliothèque de préfabs de donjon** (12 salles, 8 connecteurs), chargée à chaque démarrage et jamais
    utilisée. **Attention** : poser des préfabs alourdit la génération d'un étage — à mesurer au palier 11.
42. **Les 30 bois inatteignables.** Le chemin décide de la dépendance : par les fiches de matériau, c'est bloqué par le
    palier 2 **et** il faut écrire le lecteur qui n'existe pas ; par les tables de biome, ce n'est bloqué par rien.
43. **Les signaux sans auditeur.** *Correction* : ils ne sont pas douze mais **dix** — deux ont un auditeur dynamique,
    invisible au grep, via les bulles d'onboarding. En revanche `locale_changed` est bien mort des deux côtés.
    `dungeon_cleared` est déjà traité au palier 4 : c'est la même plaie vue de l'autre côté.

## Palier 11 — la performance, quand la simulation a fini de grossir

**Mesurer avant, pas pendant** : chaque champ ajouté aggrave le coût d'un recentrage de fenêtre (chaque champ remplit
sa carte entière au changement de grille).

44. **Le franchissement de cellule.** *Chiffre corrigé* : ~13 ms par cellule, pas 31, depuis le portage C++ — mais
    toujours six à sept fois le budget, et trois cellules dans la même image.
45. **La carte de lumière — et c'est pire que ce qui était écrit.** Elle n'est pas refaite « quand une tuile change » :
    elle est refaite **à chaque tick de monde** dès que quelqu'un lit la lumière, et son lecteur en jeu est la vision
    de l'IA, appelée par paire observateur/cible la nuit en ville. **À refaire sur le patron de la chaleur.**
46. **Les cellules jamais déchargées** — *l'avis extérieur du 2026-09-08 tape exactement ici : la moitié « recompresser quand le joueur part » du principe macro/micro est la seule qui manque à Sensen.* *Dépendance nette* : **après** la ligne 44, jamais avant — évincer les cellules
    tant que la pré-génération coûte 13 ms rendrait le défaut **pire** (aujourd'hui, revenir sur ses pas est gratuit).

## Palier 12 — les tests, le coffre, et l'ancienne file

47. **Les tests qui ne prouvent rien**, dont plusieurs **cachent** des défauts réparés en chemin, et **le coffre qui se
    contredit** (le mana de la Méditation, le portefeuille du roi, trois nombres pour le catalogue des statuts).
    Plus **l'ancienne file** jamais revue : les saisonniers, le chômage qui pousse à migrer, les tombes qui
    vieillissent, les événements en zone logique, **une guerre qui ne fait rien**, le nom de la vocation à l'écran,
    l'irrigation construite, les mauvaises récoltes, la cuve et le moulin, les descriptions de modules non traduisibles.

> [!warning] Deux choses **écartées** le 2026-09-08, pour qu'on ne les repropose pas
> - **Le GOAP (planificateur d'actions)** : Sensen n'a jamais eu d'arbres de comportement — `data/ai_profiles/` est
>   déjà une utility AI pondérée. Un planificateur serait un système entier à côté d'elle, pour des séquences dont un
>   jeu à tuiles vues de dessus n'a pas besoin. Ce qui manque à cette IA, ce sont **les jauges** et le **champ de
>   danger**, tous deux déjà en file.
> - **Porter la simulation politique en C++** : le noyau sert là où c'est un balayage de tableau contigu — chemins,
>   lumière, chaleur. Un passage hebdomadaire sur quelques centaines de royaumes est du GDScript sans problème.

## Palier 13 — ce qui n'est pas à moi

*Le détail, et tout le reste de ce qui attend une décision : [[Décisions en attente]].*

48. **Le jeu est muet** : zéro fichier audio. Je peux poser l'architecture ; les sons sont un choix du designer.
49. **La difficulté de départ** — jugeable dès la fin du palier 3, pas plus tard : dès qu'il y a une pause et un écran
    de mort, la question se regarde.

---

## Ce que cet ordre coûte, honnêtement

- **Il retarde les champs.** Le designer a déclaré le chantier des modules « en cours » ; cet ordre le place au palier
  5, après la sauvegarde, les matériaux et le jeu jouable. C'est l'arbitrage du **palier 0, question 2** — et s'il
  répond « les champs d'abord », les paliers 5 à 7 remontent devant le palier 3 sans rien casser d'autre.
- **Il retarde le champ de danger**, qui n'a aucun bloqueur et pourrait être fait aujourd'hui. Je respecte l'ordre
  confirmé par le designer.
- **Pendant les quatre premiers paliers, la suite reste verte sur des tests dont on sait qu'ils prouvent peu.** Le
  palier 12 est en avant-dernier alors qu'il est le filet de tout le reste. C'est le prix de faire d'abord ce qui perd
  du jeu.
- **Trois lignes sont coupées en morceaux** : l'écran de mort (client + simulation), le sort au contact (grammaire +
  données), les signaux (le donjon au palier 4, le reste au palier 10). Les « 47 chantiers » ne sont donc pas 47 blocs.

## Liens
- **Dépend de** : [[Vers la production]], [[Émergence — les champs partagés]], [[Ordre de construction]]
- **Alimente** : [[Ordre de vérification]], [[Risques majeurs]]
- **Voir aussi** : [[Sauvegarde]], [[Matériaux — 13 stats]], [[Mine sous une cellule]], [[Budgets de performance]], [[Écrans d'interface]]
