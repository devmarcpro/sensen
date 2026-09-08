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

## Palier 0 — deux questions, zéro ligne de code

Elles coûtent au designer une phrase, et elles coûtent une semaine si elles arrivent tard.

1. **Le sens de la vérité des catalogues.** La note redevient-elle la source (il faut alors valider à la main les 94
   lignes reversées et les chiffres étirés), ou la donnée devient-elle la source et la note son reflet ? **Tant que ce
   n'est pas tranché, les tables réalignées le 2026-09-08 rederiveront au prochain équilibrage** — c'est exactement ce
   qui est arrivé une première fois.
2. **Les champs avant ou après le jeu fini ?** Le designer a tranché l'ordre *des six champs entre eux*, pas leur place
   par rapport à la pause, la mort et les touches. Cet ordre-ci les place après (paliers 1 à 3), en le disant.

## Palier 1 — la séance `sim_sauvegarde.gd` : la partie te revient entière

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

## Palier 2 — trois lignes de Python qui rouvrent tout le chantier matériaux

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

## Palier 3 — la séance `main.gd` : le jeu redevient un jeu

Quatre lignes dans deux fonctions du même fichier, plus une séance sur les écrans. **Deux chaînes de dépendance
internes**, et elles comptent.

13. **Trente secondes, avant tout le reste** : effacer les deux chaînes d'aide mortes des CSV. Elles décrivent des
    touches disparues, personne ne les lit — le seul danger est que celui qui écrira l'écran d'aide les recopie.
14. **Le menu de triche sur `V` : une garde de débogage, PAS une suppression.** Le coffre se contredit ici — la file
    écrit « triche à retirer » quand [[Écrans d'interface]] enregistre l'accord explicite du designer sur cette touche.
    C'est la note du designer qui gagne.
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

## Palier 4 — le donjon dit la vérité

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
28. **Réécrire les contenus sur les champs** : un noyau de feu dira `{chaleur: 400}` et le reste suivra seul.
    **Ce palier dissout deux lignes plus bas** : les 23 sorts qui ne produisent rien disparaissent entièrement, et la
    moitié « données » du sort au contact gratuit avec eux.

## Palier 7 — les quatre champs restants, dans l'ordre du designer

29. **La rumeur qui circule** (aucun bloqueur — elle pourrait se faire au palier 5 ; l'ordre du designer la place ici).
30. **Le temps long** — usure, ruine, repousse — avec `alteration`.
31. **Les besoins au-delà de la faim** : soif, sommeil, peur qui dure (aucun bloqueur non plus).
32. **L'eau qui pèse** — pression, poids, érosion — avec `permeabilite`.

## Palier 8 — les nombres cessent de mentir

**Trois lignes écrivent dans le même fichier de règles** : à faire ensemble, une seule relecture.

33. **Le sort au contact qui ne coûte ni tick ni mana.** La règle est dans la **grammaire** que le designer garde :
    elle survivra à la purge et ressuscitera au premier noyau d'arme réécrit. À corriger là, pas dans les données.
34. **Le mana qui se régénère 160 fois plus lentement que la vigueur.** Le chiffre juste dépend du nouveau tarif des
    sorts : **après** le palier 6, pas avant.
35. **L'équilibrage jamais corrigé.** *Correction importante* : « légendaire » et « mythique » ne sont pas
    inatteignables à cause de la table des paliers — c'est le **plafond de qualité d'artisanat** qui borne le produit
    juste sous le seuil. Monter les seuils de la table, le réflexe, ne changerait rien.
    Le palier de matière plat après le niveau 14 est **bloqué par le palier 2** (il faut écrire des matériaux).
36. **L'XP d'armure — et ce n'est pas « deux fichiers de compétence manquants ».** La fonction qui associe une
    compétence à une stat renvoie « volonté » pour toute clé inconnue — la porte de sortie prévue pour les modules — et
    la compétence est créée sans broncher. **Une robe entraîne donc silencieusement la Volonté et fabrique une
    compétence fantôme comptée dans le niveau de combat.** La tautologie du test est ce qui a permis à ça de vivre.

## Palier 9 — le jeu montre ce qu'il sait

**Les trois lignes sont le même travail dans les mêmes trois fichiers**, et la plus visible est presque gratuite : la
fonction qui met en forme le coût d'une capacité et sa chaîne traduite existent depuis longtemps, personne ne les
appelle.

37. **Le coût d'une capacité, écrit au moment de la lancer** (le déficit se paie en points de vie).
38. **La réputation à l'écran** — village, royaume, globale.
39. **Le refus visible** : aujourd'hui il part au journal, que le panneau recouvre.

## Palier 10 — ce qui existe et qu'on ne verra jamais

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
46. **Les cellules jamais déchargées.** *Dépendance nette* : **après** la ligne 44, jamais avant — évincer les cellules
    tant que la pré-génération coûte 13 ms rendrait le défaut **pire** (aujourd'hui, revenir sur ses pas est gratuit).

## Palier 12 — les tests, le coffre, et l'ancienne file

47. **Les tests qui ne prouvent rien**, dont plusieurs **cachent** des défauts réparés en chemin, et **le coffre qui se
    contredit** (le mana de la Méditation, le portefeuille du roi, trois nombres pour le catalogue des statuts).
    Plus **l'ancienne file** jamais revue : les saisonniers, le chômage qui pousse à migrer, les tombes qui
    vieillissent, les événements en zone logique, **une guerre qui ne fait rien**, le nom de la vocation à l'écran,
    l'irrigation construite, les mauvaises récoltes, la cuve et le moulin, les descriptions de modules non traduisibles.

## Palier 13 — ce qui n'est pas à moi

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
