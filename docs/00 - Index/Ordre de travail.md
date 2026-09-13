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

~~1. **Le sens de la vérité des catalogues.**~~ — **TRANCHÉ par le designer le 2026-09-09 : « la note est la
   source ».** La flèche va donc de la note vers la donnée, et elle n'a plus le droit de tourner : `gen_materials.py`
   (tables → fiches) est le seul chemin de travail, `regen_catalogues.py` (fiches → tables) **refuse désormais de
   s'exécuter** sans `--vraiment` — c'est un outil de sauvetage, plus une passe d'entretien.
   **La validation à la main que cette question annonçait n'a plus lieu d'être** : les 94 lignes reversées et les
   chiffres étirés du 2026-09-08 sont dans les tables depuis, et les deux sens s'accordent maintenant **exactement** —
   `regen_catalogues.py --verifier` rend douze catalogues « à jour », 0 ajout, 0 correction, et
   `verif_generateurs.py` prouve l'aller. La décision ne coûte donc rien : elle scelle un accord déjà atteint.
   **Ce qu'il a fallu réparer pour le dire** : `regen_catalogues.py` portait un en-tête à treize colonnes et aurait
   **effacé les 247 points de fusion** ; et son `--verifier` annonçait six matériaux « à ajouter » à chaque passage
   parce qu'il ignorait les cinq alias d'identifiant et le nom à rallonge du guano. *Un vérificateur qui crie toujours
   au loup n'est plus lu.*
   **Ce que la décision NE couvre pas, et il faut le dire** : huit champs des fiches n'ont aucune note pour source —
   `palier`, `palier_fixe`, `stats_base`, `sous_categorie`, `tags`, `noise`, `wuxing`, `harvest`. Le générateur les
   **préserve** au lieu de les écrire. `sous_categorie` est lu par le jeu sur 76 fiches. Les reverser dans des notes
   est le prolongement naturel de la décision ; c'est un chantier à part, et il n'est pas fait.
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

~~19. **`chain_gauge` cesse de vouloir dire « c'est le boss »**~~ — **DÉJÀ FAIT le 2026-09-08**, et cette file ne
    l'avait pas enregistré (constaté le 2026-09-09 en la relisant). La victoire se lit sur `boss_donjon`, le drapeau
    que le générateur pose sur la créature de la salle du fond du DERNIER étage ; `chain_gauge` ne veut plus dire que
    ce qu'il dit, une jauge de chaîne Wu Xing.
~~20. **La faute d'indentation de la quête**~~ — **DÉJÀ FAIT le 2026-09-08.** La quête « videz le donjon » et le
    signal `dungeon_cleared` sont sortis du `elif` « donjon corrompu, boss non vaincu » : ils appartiennent à la
    victoire, quel que soit le genre du donjon.
~~21. **Un boss propre par thème**~~ — **FAIT le 2026-09-09.** Les sept thèmes partageaient `chef_de_bande` : un
    chef de bandits gardait le donjon de feu, celui d'eau et celui de métal — et il n'appartenait au pool d'**aucun**
    d'entre eux, pas même celui de la ruine. Désormais kitsune dans les bois, lindworm dans l'eau, jorogumo dans le
    feu, basilic dans le métal, tengu au repaire, griffon dans les ruines, tsuchigumo dans la terre.
    **La règle se vérifie plutôt qu'elle ne se discute**, et un test la tient : le boss est une créature **du pool de
    son thème** — la culmination de ce qu'on a croisé, pas un étranger — et c'est **la plus forte** du pool, parce
    que `boss_donjon` ne fait que le désigner et ne le renforce pas. **C'est le test qui m'a appris la règle
    exacte** : mes deux critères entrent en tension dès qu'un pool en recoupe un autre (le repaire partage la
    jorogumo avec le feu), et la formulation juste, indépendante de l'ordre de lecture, est « aucune créature du pool
    n'est plus forte que le boss, **sauf si elle garde déjà un autre thème** ».
    **DEUX TESTS ENCODAIENT L'ANCIEN CONTENU, ET L'UN D'EUX ÉTAIT UN PIÈGE.** Le premier attendait `chef_de_bande`
    en dur. Le second exigeait le tag `elite` — et la tentation était de le donner aux sept nouveaux boss pour le
    faire passer. **C'aurait été refaire le défaut de la ligne 19** : poser sur une **espèce** un tag qui décrit un
    **rôle**, si bien que chaque kitsune serait devenue une élite jusque dans les couloirs. `elite` n'est d'ailleurs
    lu par aucune ligne de code. Les deux tests disent maintenant la règle : l'être marqué est la créature que son
    thème déclare.
~~22. **Incarner un compagnon cesse de faire perdre la jauge de chaîne en silence**~~ — **DÉJÀ FAIT** : l'incarnation
    dit maintenant au journal si le corps qu'on prend porte une jauge de chaîne (`journal.incarne_sans_chaine`,
    `journal.incarne_avec_chaine`).
    *La leçon vaut d'être gardée : une file de travail qui n'est pas rayée à mesure fait relire trois fois du travail
    fini. Ces trois lignes ont été vérifiées dans le code avant d'être rayées, pas de mémoire.*

## Palier 5 — les champs, chacun apparié à sa stat

**Les cinq stats ne peuvent pas être posées d'un coup** : la sonde des stats de matière sort en échec dès que plus
d'une stat n'est lue par aucune formule. Cinq stats posées avant leurs champs = quatre muettes = sonde rouge.
**Ce n'est donc pas un chantier, c'est cinq chantiers appariés.** Et après le palier 2, ce sont quatre chemins
**parallèles**, pas une chaîne.

22 bis. ~~**L'inertie thermique**~~ — **FAIT le 2026-09-08, sur une question du designer.** Le champ de chaleur ne lisait que `isolation` alors que la note promettait aussi `densite` (la masse thermique). Corrigé : une matière dense met du temps à changer de température. *Leçon de méthode : la promesse était relevée dans la note du matin mais absente de cette file — c'est la question du designer qui l'a rattrapée, pas moi.*

~~23. **`fusion`**~~ — **FAIT le 2026-09-09.** 247 points de fusion en **degrés réels**, entrés comme 14e colonne des
    douze tables (la table fait foi ; `verif_generateurs.py` prouve la reproduction des 247 fiches). **Le blocage
    annoncé n'existait plus** : la note renvoyait à « la remise en accord des catalogues », faite au palier 2 — les
    tables et les fiches se correspondent 247 pour 247. Mesuré avant d'être cru.
    **La définition du 2026-09-08 était fausse** : elle disait « 0 = elle ne fond pas », or 0 °C est le point de fusion
    RÉEL de la glace, de la neige, du givre, de la grêle, de l'eau et du sang — les matières que cette ligne cite en
    premier. Ce qui ne fond pas porte donc **9999** ; les liquides portent leur point de **congélation**, négatif.
    **Le consommateur** (`SimTerrain._fondre`) : le sol qui cuit (gypse → plâtre à 150 °C, calcaire → chaux à 825,
    argile → brique à 1000) et le filon qui coule (malachite → cuivre à 200, cinabre → mercure à 580, galène → plomb
    à 1114). Le tableau de `thermique.fusion` ne porte **aucune température** : il dit ce que la chose devient, le
    seuil est sur la fiche. **`test_fusion` prouve par un contrôle NÉGATIF** — deux sols chauffés à la même
    température, un seul cuit.
    **Ce que la donnée a refusé** : un feu monte à 1100 °C, une coulée à 1150 ; le **sable** fond à 1710 et ne
    vitrifiera donc jamais ainsi, alors que « le sable vitrifie » était dans l'énoncé. Il faut un four. *Baisser le
    nombre pour rendre la démonstration jolie aurait été mentir sur le monde réel.* Et le branchement a corrigé un
    nombre : la lave à 1200 se serait figée à l'instant, la source imposant 1150 — le solidus d'un basalte est 900.
    **Reste** : « la neige fond, l'eau gèle, la cire coule » demandent que la neige, le gel et la cire soient des
    **tuiles** ; ce sont aujourd'hui deux drapeaux de fenêtre et une matière d'objet.
24. ~~**Le champ de danger**~~ — **FAIT le 2026-09-08.** Il gradue (1-100) et absorbe les deux sources que l'IA ne voyait pas : **les nuages de gaz** (elle marchait dans le poison) et **la chaleur** (une tuile à 300 °C sans flamme). Le code de l'IA n'a pas changé d'une ligne. **Et le reste est fait le 2026-09-09 : le chemin PÈSE le grade.** Deux nombres en données — `danger_refus` (100 : ce qui tue à coup sûr ne se négocie pas, et sans seuil un coût finit toujours par être payé) et `danger_cout_par_grade` (100 ticks le point, un pas en coûtant 300). **Le calibrage est venu de ce que le champ émet vraiment** : à 50, un gaz à statut (60) serait resté refusé comme avant et le grade aurait été lu sans rien changer pour lui. **Un défaut trouvé en chemin** : le garde-fou des miroirs recompilait `danger_a` avec 1 au lieu du grade — invisible tant que le chemin ne faisait que refuser, faux le jour où le grade se paie. `test_danger_pese` demande un **comportement**, pas seulement l'égalité GDScript/C++ : deux implémentations qui refusent tout seraient d'accord. Voir [[Émergence — les champs partagés]].

*Ce que le champ remplaçait :* Ni stat, ni champ préalable ; ses trois sources existent déjà
    (chaleur, gaz, lave) et la structure à remplacer est là, binaire, lue par le noyau C++ et par deux endroits de
    l'IA. **C'est le seul chantier de ce palier codable aujourd'hui.** L'ordre du designer le place après le bruit : je
    le signale sans le réordonner — c'est sa décision.
~~24 ter. **LE CHAMP D'AIR**~~ — **FAIT le 2026-09-12** : un nuage est une charge par tuile qui diffuse, monte ou coule selon sa masse (`1 + pente × Δhauteur × (1 − masse)` — une formule, quinze comportements), se dilue à ciel ouvert et s'accumule dans un espace clos ; les effets se déclenchent par concentration, le danger se gradue, le champ se voit bouger. **L'air est le complément du gaz** (`air = 1 − charge`), et il alimente le souffle qui existait déjà pour la noyade : la suffocation a cessé d'être une étiquette. `test_champ_air` mesure la montée et la descente. *Ce qui reste : une pièce hermétique sans gaz n'étouffe personne — la consommation d'air est un second mécanisme.* — *remonté ici le 2026-09-08 sur une question du designer : « tu rajoutes le gaz dans le
    sol mais est-ce que tu fais pareil pour l'air ? ».* **Non, et l'asymétrie est exacte.**
    **Sous terre le gaz est une vraie chose** : des poches placées par le bruit, percées à la pioche, un volume, une
    inondation par les galeries ouvertes, l'inflammation, l'explosion.
    **Une fois sorti, il n'existe plus.** `_liberer_gaz` fait **une seule** inondation et dépose N tuiles dans une
    liste ; `_tiquer_zones` ne fait qu'**enlever celles qui ont expiré**. Un nuage ne diffuse jamais, ne se déplace
    jamais, ne se mélange jamais, ne se dilue jamais. Et **il n'y a pas d'air du tout** : ni oxygène, ni confinement,
    ni respiration — l'asphyxie est simulée par une **étiquette** (`statut: epuisement`), pas par une absence d'air.
    **La donnée qui manquait est posée** (2026-09-08) : les quinze gaz ont désormais une **masse relative à l'air**,
    calculée sur les masses molaires réelles. Le méthane à 0,55 **monte** — c'est le grisou qui attend une lampe au
    toit d'une galerie ; le dioxyde de carbone à 1,52 **coule** — c'est la mofette au fond d'un puits ; le radon à 7,67
    stagne au fond des caves. Avant, les quinze se comportaient pareil : ils restaient où ils étaient nés.
    **Ce que le champ remplacerait** : la liste de zones figées, entièrement. Un nuage devient une **charge par tuile**
    qui diffuse, monte ou coule selon sa masse, se dilue à l'air libre et **s'accumule dans un espace clos**. La
    suffocation cesse d'être une étiquette.
    **Ce qu'il lit et ce qui le lit** : il lit les **couches Z** (monter d'un étage a enfin un sens pour un gaz) et le
    **vent** quand il existera (c'est lui qui décide si un nuage stagne ou se dilue — la ventilation d'une galerie) ;
    il est lu par le **champ de danger** (fait), l'**ignition** du champ de chaleur, la **vue** (la fumée aveugle) et
    demain le **champ sonore**.
    **Il est ici, juste après le danger, et pas plus bas** : le danger vient de rendre les nuages visibles à l'IA, ce
    champ les rend *mobiles* — c'est la suite directe, et le grisou qui monte est ce qui fait qu'une mine se joue.

~~25. **Le champ de support** avec `portance`~~ — **FAIT le 2026-09-09.** `portance` est la **deuxième** des cinq
    colonnes : 247 valeurs de 0 à 100, dans l'ordre du monde réel et non dans ses unités (les gemmes sont dures et
    **cassantes**, le plomb et l'or sont **mous** — c'est là que `durete` trompait, et c'est ce qui justifie une stat
    séparée). Le champ lit cette stat et rien d'autre : `portee_base + portee_par_portance × portance` dit jusqu'où un
    plafond porte — granit six tuiles, terre une et demie, sable rien. Aucune portée n'est écrite matière par matière.
    **Étayer est devenu un geste sans une ligne d'interface neuve** : l'`etai` est un meuble, il se fabrique à
    l'établi, il ne bloque pas le passage et il porte.
    **Deux choix qui ne se voient qu'en écrivant** : l'éboulement pose un mur **destructible** (une galerie bouchée se
    rouvre à la pioche), et un occupant n'est jamais enfermé dans la pierre — on le blesse, on le pousse, et faute de
    place le plafond **grogne** en attendant. `test_support` prouve par un **contrôle négatif** : la même galerie, au
    même endroit, ne change que la matière — le granit tient, la terre tombe.
    **Les deux manques annoncés ont été comblés le jour même** (designer : « fais le nécessaire alors »). Le verrou
    « en mine » est devenu une **question physique** — *y a-t-il quelque chose au-dessus ?* : sous terre oui, à la
    couche d'un étage la tuile où l'on marche EST un plancher, à ciel ouvert il n'y a rien à faire tomber. Et la
    **troisième dimension** est là : un plancher tient par du plein dessous ou par un mur de sa couche à portée, et
    il a fallu une règle de plus pour que la propagation soit vraie — le **mur** d'étage, qui ne peut pas se juger
    localement (deux murs se porteraient mutuellement à jamais) : c'est le **groupe** qui tient, s'il repose quelque
    part sur du plein, le parcours borné par `composante_max`. **Abattre les murs du bas fait tomber l'étage, et
    celui du dessus avec** — `test_support_etages` le compte.
    **Deux trouvailles en sortant de la mine** : « ce qui soutient » se lisait *bloque le passage*, or l'AIR d'une
    couche bloque le passage sans rien porter — un plancher se serait cru tenu par le vide ; et la première version
    du test a rougi **à bon droit**, un arbre du terrain portant le plancher par en dessous. *Quand une géométrie est
    le sujet d'un test, elle se pose entièrement à la main.*
    **Une règle a manqué et c'est un test qui l'a dite** : en sortant de la mine, la portée s'est mise à juger les
    salles que le GÉNÉRATEUR avait taillées — un coup de pioche dans une ruine faisait tomber un hall de dix tuiles.
    `test_recolte` a rougi à bon droit : le champ condamnait le contenu existant. **Ce qui a été creusé, pas ce qui a
    été bâti** — le champ ne juge que les tuiles marquées `modifies`, que le jeu tenait déjà.
    **Reste** : la démolition par les PNJ et les royaumes ne nourrit pas encore le champ.
~~26. **Le champ sonore** avec `absorption`~~ — **FAIT le 2026-09-09**, le jour où le designer l'a **nommé**
    (`sonore` ; `bruit` restant au bruit de Perlin). Le mot était libre — deux occurrences, deux commentaires sur
    « l'onde sonore » du barde, donc une future *source*. `son` a été écarté sur mesure : libre comme identifiant mais
    présent 367 fois en prose, c'est le possessif français — *un mot qu'on ne peut pas chercher est un mot pris.*
    **LE SON CONTOURNE** : il suit le plus court chemin sonore, pas une ligne droite — un cri passe par la porte
    ouverte plutôt qu'à travers le mur. `absorption` (troisième des cinq colonnes, 247 valeurs) dit ce que chaque
    matière en mange, et **c'est la stat qui diverge le plus des deux autres** : le liège est mou, ne porte rien et
    étouffe mieux que le granit ; l'acier est dur, porte tout et transmet le son comme un fil ; la neige (95) rend un
    monde silencieux. **L'IA remonte la pente du champ** sans savoir ce qu'elle a entendu, et la **Discrétion**
    retranche au volume qu'on ÉMET — se cacher devient un lieu. `test_sonore` écoute à la même distance des deux
    côtés du même couloir et ne change que la matière du mur.
    **Le combat sonne depuis le 2026-09-09 au soir** *(question du designer : « que veux-tu dire par le combat qui
    ne sonne pas encore »).* Les volumes de `coup`, `mort` et `porte` étaient écrits dans les données et n'avaient
    **aucun émetteur** — une bataille était muette pour l'IA, on pouvait égorger quelqu'un à six tuiles d'un garde
    sans qu'il tourne la tête. Le coup sonne sur le **passage obligé de tous les dégâts** (une arme, une action de
    créature, une explosion, un statut : tout passe par là), le cri porte plus loin que le coup, et la porte est
    atténuée par la Discrétion de qui l'ouvre. *C'était le défaut du champ de danger, reproduit le soir même sur le
    champ sonore : un nombre écrit et lu par personne.*
    **Reste** : le champ ignore les couches Z — un combat à l'étage ne s'entend pas d'en bas.
    *(Note : le module `absorption` existe aussi dans le catalogue des noyaux — il meurt au palier 6, mais tout grep
    sera ambigu pendant les deux chantiers.)*
    **Et une bonne nouvelle mesurée** : le piège annoncé — « bâtie sur le patron de la lumière, elle hériterait du
    défaut au carré » — **a été évité**. Le champ de chaleur a écrit son propre patron incrémental. La dépendance court
    donc **dans l'autre sens** : c'est la carte de lumière qu'il faudra refaire sur le patron de la chaleur. Celui qui
    écrira le son doit copier la chaleur, surtout pas la lumière.

~~26 ter. **UNE TUILE TIENT UNE PILE**~~ — **FAITE le 2026-09-09** *(designer 2026-09-08 : « les entités peuvent se
    stack sur la même case, un PNJ peut porter un PNJ qui porte un PNJ ; si un PNJ non hostile bloque une porte le
    joueur peut passer par-dessus »).* L'échange posé ce jour-là — celui qu'on croise prenait la place qu'on quittait
    — donnait le bon résultat en jeu sans faire une pile ; il a disparu.
    **Le choix de modèle, et c'est lui qui a rendu le changement petit** : `occupants` garde sa forme (index → UN id)
    et désigne désormais le **sommet** ; un second dictionnaire `piles` ne porte que les tuiles à **plusieurs**.
    Conséquences : les **183 lecteurs** d'`occupant()` n'ont pas eu une ligne à changer — ils lisent le sommet,
    c'est-à-dire l'être qu'on vise, qu'on attaque, qu'on survole —, le **miroir d'octets `occ`** du noyau C++ garde
    exactement son sens (1 = il y a quelqu'un), et **le noyau n'a pas bougé**. Une tuile à un seul occupant ne coûte
    rien de plus qu'avant, ce qui est le cas de toutes sauf une poignée.
    **Ce qui a changé ailleurs** : `liberer(pos)` prend un `id` optionnel — sans lui il retire le sommet, ce qui
    reste juste partout où l'appelant est seul sur sa tuile ; les **38 appels** des systèmes donnent maintenant leur
    id, parce qu'un être peut être SOUS un autre. Le client dessine celui qui est monté `styles.sprites.pile_hauteur`
    pixels plus haut et devant. La hauteur de pile est en données (`deplacement.pile_max` = 3, « un PNJ peut porter
    un PNJ qui porte un PNJ »). Un ennemi ne s'escalade jamais : c'est lui qu'on attaque.
    **CE QUI RESTE, et c'est la ligne 26 nonies** : le CHEMIN ne traverse toujours pas un ami.

~~26 nonies. **LE CHEMIN TRAVERSE LES AMIS**~~ — **FAIT le 2026-09-09** *(designer 2026-09-08 : « si un PNJ non
    hostile bloque une porte le joueur peut passer par-dessus »).* Le pas passait depuis le matin ; c'était
    l'**itinéraire** qui restait fermé — un villageois dans une embrasure ne bloquait plus le pas mais bloquait
    encore le chemin, donc un clic lointain contournait ou échouait.
    **La forme choisie, et pourquoi** : ni un ensemble d'ids passé à chaque appel (une recherche visite des milliers
    de tuiles ; une recherche dans un dictionnaire par tuile visitée coûte cher), ni un balayage des êtres par appel.
    Un **miroir d'octets** `bloque_a`, de la même forme que `occ` : 1 = cette tuile barre CE marcheur-là. C'est
    `O(1)` par nœud visité, exactement comme avant. `Simulation.bloque_pour(e)` le construit en partant d'`occ` et en
    **effaçant** les tuiles de ceux qui ne lui sont pas hostiles — `O(êtres)` une fois, **en cache par camp et par
    tick**, parce que `SimPnj.ennemis` est affaire de camp partout sauf pour un civil fâché contre le joueur (la clé
    du cache porte alors l'id).
    **Un tableau vide garde le sens d'avant** — toute tuile occupée barre —, donc la génération, les sondes et les
    tests n'ont rien eu à changer, et le noyau C++ non plus tant qu'on ne lui passe rien.
    **Les deux côtés dans le même commit** : `chemin` et `atteignables` en GDScript **et** en C++ (DLL reconstruite),
    et le test prouve sur un couloir d'une tuile de large que les deux rendent le même chemin et les mêmes
    atteignables à travers l'ami — sans le miroir, l'autre bout reste hors d'atteinte.

~~26 duodecies. **LE VILLAGEOIS NE REJOINT PAS SON COIN DE PLACE À 21 H.**~~ — **CE N'ÉTAIT PAS UN DÉFAUT DU JEU**
    (2026-09-09). Le villageois porte `horaires_decalage` = **+2** : c'est un lève-tôt, et à 21 h du monde il en est
    à 19 h — donc encore à son poste, où il se tient déjà. Sa routine score alors zéro (« arrivé »), et `attendre`
    l'emporte avec 1,00. **C'est juste.** C'était la sonde qui lui reprochait de ne pas être à une heure qui n'est
    pas la sienne ; elle règle maintenant l'horloge du monde de façon à ce que **son** heure soit celle qu'on veut
    éprouver, et la sonde entière est passée de 39 soucis à **rien à signaler**.
    **MES DEUX HYPOTHÈSES ÉTAIENT FAUSSES, ET C'EST LA LEÇON.** J'avais écrit que le coin de place tombait
    peut-être sur une tuile inatteignable — un chemin de dix pas y menait —, et que le test de `tests_villages`
    prouvait peut-être seulement que la routine *désigne* la bonne tuile sans prouver qu'on peut y *aller* — ce test
    choisit exprès un villageois **sans** ce trait, il prouvait donc exactement la bonne chose. Deviner coûte plus
    cher que faire parler l'outil : c'est en faisant imprimer à la sonde ce qu'elle **voyait** — la cible visée, la
    longueur du chemin, ce que la tuile porte, la décision prise et son score, puis la cible que l'IA vise
    elle-même — que la réponse est tombée en trois essais.
    **DEUX CHOSES RESTENT, ET ELLES SERVIRONT ENCORE** : l'IA écrit désormais sa décision (`ia_action`, `ia_score`)
    à chaque choix — sans quoi « il ne va pas vers sa cible » ne se corrige pas, il fait relire le code au hasard ;
    et une sonde qui signale un souci en dit maintenant la **cause visible**, pas seulement le symptôme.

~~26 decies. **PORTER N'EST PAS ÊTRE AU MÊME ENDROIT.**~~ — **FAIT le 2026-09-09.** La ligne attendait le corps
    (28 bis) « parce que porter un corps est le premier usage qu'on en fera » ; le corps est un plan de parties
    depuis le matin même, donc la relation a pu s'écrire.
    **Trois conséquences, et ce sont elles qui FONT la relation** : le porté **suit** à la tuile près, sans chemin ni
    décision propre ; il **n'occupe plus** de tuile — on ne le vise pas, on ne le contourne pas ; et il **pèse** —
    la charge du joueur passe de 11 à 91 quand il hisse un corps, et l'eau le refuse comme n'importe quelle
    surcharge. Un cadavre est le fardeau le plus lourd qu'on puisse tenir.
    **Qui peut être porté** : un mort, toujours ; un vivant seulement s'il est de son camp ET hors de combat — on
    n'emporte pas un ennemi conscient sur l'épaule.
    *Le compilateur a attrapé une collision de vocabulaire en deux secondes* : `deposer` était déjà pris (il dépose
    des ressources dans un stock), et deux sens sous un même nom sont exactement ce que [[Vocabulaire]] refuse — le
    verbe qui repose un corps s'appelle donc `reposer_porte`.

~~26 undecies. **LES MEUBLES S'EMPILENT AUSSI**~~ — **FAIT le 2026-09-09** *(designer 2026-09-08 : « on peut aussi
    mettre des meubles les uns sur les autres »).* Le même remède que pour les êtres, écrit et prouvé la veille :
    `meubles` garde sa forme (index → un id) et désigne le **sommet** — les 154 lecteurs de `grille.meubles[i]` lisent
    toujours le meuble qu'on voit, qu'on utilise, qu'on démonte —, un second dictionnaire `piles_meubles` ne porte que
    les tuiles à plusieurs, et les écritures directes passent désormais par `poser_meuble` / `retirer_meuble`.
    **Ce qui diffère des êtres, et qui a demandé du soin** : (a) une tuile de meuble porte un **contenu** de tuile, et
    ce contenu est celui de la PILE — elle bloque le passage dès qu'un seul de ses meubles bloque ; (b) le sac se
    souvient de ce qu'on a posé (`objets_poses`), et cette mémoire devient une **liste** pour que démonter rende le
    bon objet ; (c) démonter ne vide le **contenant** que si c'est lui qu'on retire — ôter le lit posé sur le coffre
    ne vide plus le coffre.
    **UN DÉFAUT QUE LE TEST A ATTRAPÉ** : la capture d'une cellule ne gardait qu'**un** meuble par tuile
    (`"meuble": str(g.meubles.get(gi))`). Une pile perdait donc son dessous au premier aller-retour hors de la
    cellule. Elle garde maintenant toute la pile, et relit la forme d'avant sans migration.

26 quater. **UN ÉTAGE NE MONTRE QUE SON NIVEAU** *(designer 2026-09-08 : « pour les étages, quand on est à un autre
    étage, est seulement rendu ce qu'il y a à ce niveau Z »).* **C'est un RENVERSEMENT de la décision du 2026-09-06**,
    et il faut le dire : les couches Z ont été posées avec la règle inverse — « à l'étage, par-dessus les murs de son
    niveau, l'air se voit, et la rue par lui ». Le champ de vue le fait exprès (`simulation.gd`, `maj_vision`), la
    passe `_dessiner_etage` ne dessine que les tuiles du bâtiment du joueur **par-dessus** un terrain toujours dessiné
    au niveau 0, et le brouillard reçoit `zj` pour laisser voir la rue.
    **Ce que le designer demande à la place** : un étage est un **niveau à part entière**, comme dans Dwarf Fortress
    et Caves of Qud — les deux jeux qu'il a nommés pour la refonte de l'exploration. À l'étage 1, on voit l'étage 1 ;
    dehors, il n'y a rien à cet endroit-là, et c'est le vide qu'il faut montrer.
    **Ce que ça touche** : la passe des morceaux de terrain dessine les tuiles **plates** (`s.idx(x, y)`) — elle doit
    dessiner `Grille.en_couche(t, zj)` ; le brouillard et les toits pareil ; `_dessiner_etage` disparaît, absorbée
    par la passe principale ; et la **vision** cesse de traverser vers le bas. Côté noyau C++, les trois passes
    prennent un `zj` de plus.
    **Ce qu'il faut trancher avec le designer avant** : ce qu'on voit **par une ouverture** — un escalier, un trou,
    un balcon. Ne rien montrer du niveau du dessous rend un étage aveugle ; tout montrer, c'est l'état actuel.
    **UN DÉFAUT VISIBLE DÈS AUJOURD'HUI, ET IL EST DANS CE CODE-LÀ** *(designer 2026-09-08 : « vérifie pas juste le
    mur le plus bas mais aussi ceux qui sont rendus plus haut »)* : depuis un étage, le décor sort en **damier** —
    une tuile dessinée, une tuile noire. La règle est dans `PassesGD.voit` : à `zj > 0`, une tuile du sol n'est vue
    que si **la tuile juste au-dessus d'elle, au niveau du joueur, est de l'AIR** (`contenu == vide`) et dans son
    champ de vue. Partout où la couche du joueur porte quelque chose, le sol dessous devient invisible — d'où
    l'alternance. C'est la conséquence exacte de la règle « l'air se voit, et la rue par lui », et **elle disparaît
    avec elle** : ne rien réparer ici, la réécriture par niveau la remplace en entier.

~~26 quater bis. **LA PROFONDEUR DU SQUELETTE**~~ — **FAITE le 2026-09-08 au soir** *(designer : « tu te souviens
    de la profondeur pour les rigs des pantins ? on peut s'en occuper maintenant ? »)*. Un segment est désormais une
    **orientation dans l'espace du corps** : `x` la droite de l'écran, `y` le bas (le corps est debout, cet axe ne
    tourne pas), `z` la profondeur. `angle` garde son sens — l'angle dans le plan (x, y) —, `profondeur` (degrés) fait
    sortir le segment de ce plan, et un ancrage porte trois nombres. Le corps subit un **lacet** continu tiré de son
    orientation de grille (`atan2(x − y, x + y)` : l'isométrie regarde la grille depuis le sud-est), puis tout est
    projeté — une unité de profondeur vaut `styles.sprites.profondeur_ecran`, la même demi-hauteur que les tuiles.
    **Ce qui a disparu** : les huit `ordre` et les huit `offsets` de chacun des six rigs. Il reste **un** `ordre` par
    rig, qui ne fait que départager deux segments à la même profondeur. L'ordre de dessin est le tri par `z`.
    **Ce qu'on gagne, visible** : autant d'angles que le rig en DÉCLARE, au lieu de trois (`capture.tscn -- --pantins` en fait la
    planche), et une pose peut dire `[angle, profondeur]` — un bras qui part en arrière, que la 2D ne savait pas dire.
    *Le designer en a demandé **quatre** le 2026-09-09 — la face, le dos et les deux profils, ce qu'il dessine à la main. La
    profondeur reste entière dessous : c'est la table des orientations qui borne les vues, pas le modèle.*
    **Le compromis assumé** : la LARGEUR d'un segment reste face à la caméra (seule sa mesure se raccourcit, jamais
    en dessous de `largeur_min_profil`) — sinon un bras vu de tranche devient un trait. La longueur, elle, se
    raccourcit pour de bon : c'est ça, la profondeur.
    **Ce qui reste** : les rigs **animaux** (quadrupède, arachnide, serpentin, volant) sont encore écrits dans le plan
    de l'écran — un quadrupède est dessiné de profil, pas de face — donc ils portent `lacet_actif: false` et ne
    tournent pas encore. Les réécrire en espace du corps leur donnerait, comme à l'humanoïde, une vue de face et une
    vue de dos gratuites. **C'est la ligne 26 septies.**

~~26 septies. **LES RIGS ANIMAUX EN ESPACE DU CORPS**~~ — **FAIT le 2026-09-09** (boucle autonome). Le quadrupède,
    l'arachnide, le serpentin et le volant étaient écrits comme des **dessins de profil** : leur axe long était l'axe
    `x` de l'écran, et leur séparation gauche/droite un décalage vertical. Réécrits, leur axe long est l'axe de
    **profondeur** : à lacet nul le museau vient vers la caméra — une vue de face qu'on n'avait pas —, à 90 degrés le
    corps se remet à l'horizontale et l'on retrouve exactement le profil d'avant. Leur écart gauche/droite redevient
    ce qu'il est, un écart le long de l'axe des épaules, que le lacet transforme en profondeur tout seul ; et l'écart
    des pattes **le long** du corps devient un écart de profondeur, si bien que les pattes avant se dessinent devant
    les pattes arrière sans qu'on l'écrive. Le serpent ondule désormais dans le plan **horizontal**, vu en plongée
    comme le reste du monde, au lieu d'onduler verticalement comme un ressort. L'amorphe garde `lacet_actif: false` :
    une masse n'a pas d'orientation, et la faire tourner ne ferait que l'amincir.
    **Ce qui est à ton œil** : un quadrupède vu de face est un tronc court avec quatre pattes — c'est juste, et c'est
    plus pauvre qu'un profil. La planche des huit angles est dans [[À juger — parcours de jeu]] ; si la vue de face
    ne te plaît pas, `lacet_actif: false` sur un rig le rend immobile, et c'est **un booléen par rig**, rien d'autre.

~~26 octies. **UN SEGMENT A UNE ÉPAISSEUR**~~ — **FAIT le 2026-09-09**, dans la foulée. *(Rayée le 2026-09-09 au soir : elle se disait faite dans son propre texte sans être barrée — une file qu'on ne raye pas fait relire du travail fini.)* La profondeur avait laissé un
    chiffre magique : un segment vu de tranche gardait `largeur × 0,35`, une borne posée pour qu'un bras ne devienne
    pas un trait. C'était un manque de modèle — un corps a **deux** mesures de travers, d'une épaule à l'autre et de
    la poitrine au dos. Un segment est désormais un **cylindre à section elliptique** (`largeur`, `epaisseur`) et sa
    silhouette est la projection de cette ellipse : un torse vu de profil fait son épaisseur, pas une fraction
    arbitraire de sa largeur. La borne ne sert plus que de plancher absolu (0,12).

~~26 terdecies. **DEUX BÂTIMENTS SUR TREIZE SONT ENCLAVÉS DANS UNE CELLULE DE VILLE.**~~ — **FAIT le 2026-09-09.**
    La génération ouvre désormais un passage vers toute porte coupée du reste de la cellule, et **dit ce qu'elle a
    réparé** (`village.portes_rattrapees` : le bâtiment, la tuile, et si c'est un obstacle dégagé ou un mur percé).
    Ce qu'elle ne sait pas ouvrir va dans `village.portes_enclavees` — une cellule qui échoue le dit.
    **Ce n'étaient pas des murs, c'étaient des ARBRES**, et je ne l'ai su qu'à la troisième version. Le passage
    cherche donc d'abord un obstacle **naturel** à dégager — un arbre s'abat — et ne perce une porte dans un mur que
    si l'enclave n'est bornée que par de la pierre.
    **DEUX VERSIONS FAUSSES AVANT LA BONNE, ET LES DEUX FOIS LA MÊME ERREUR** : juger sur un état qui n'est pas
    celui qui comptera.
    1. La première inondait depuis les tuiles de `rue`. Or le chemin qui relie une porte à la rue dépose jusqu'à
       huit pavés **devant elle**, même quand il n'aboutit nulle part : l'inondation partait donc de l'intérieur de
       l'enclave et la déclarait atteinte. Elle mesurait « pavé », pas « relié à la ville ». Remède : découper le
       sol en **composantes connexes** et appeler « la ville » la plus grande — plus aucun point de départ à choisir.
    2. La seconde jugeait la marchabilité **au moment où elle tournait**. Mais la cellule retire les arbres, les
       rochers, les filons et l'eau du sol à sa **toute dernière ligne**, après le village : la passe voyait
       3 559 tuiles de sol là où il en resterait 3 311, donc une composante là où le jeu en aurait deux. Remède :
       exclure ces obstacles elle-même — juger la marchabilité **telle qu'elle sera**.
    **Et les trois fois, c'est la trace qui a tranché, jamais le raisonnement.** Chaque hypothèse a été fausse ; ce
    qui a fait avancer, c'est d'imprimer ce que le code **voyait** — la composante de chaque porte, la taille des
    inondations des deux côtés, puis les compteurs de `sol`, `murs` et `portes` au moment exact de chaque passe.
    **Le test** (`test_portes_sans_enclave`) refait la cellule qui échouait et vérifie les deux choses : que la
    génération a bien eu à rattraper — sinon il ne prouverait plus rien le jour où le monde changera — et qu'aucune
    porte ne reste hors de la plus grande composante.

## Palier 6 — les 236 contenus meurent, la grammaire reste

~~27. **Supprimer les 236 contenus de modules**, les branches d'effet en dur et les listes des fiches de classe.~~ — **FAIT le 2026-09-13.** `data/modules/` est vide (un README dit pourquoi). **L'expérience du catalogue vide a remplacé le grep** : 77 échecs dans 24 tests, dont **deux seulement étaient du code du jeu** (le butin qui tirait un grimoire dans une liste vide, une charge armée sans noyau) — réparés. Les 22 autres empruntaient un contenu pour prouver une règle de grammaire : ils assemblent désormais **70 pièces figées** dans `scenes/tests/fixtures/modules/`, que la suite seule charge (`GameData.charger_banc_d_essai`) — et la suite vérifie que le jeu, lui, n'en porte aucune. **Trois données mortes sont parties avec** : les trois sorts de la fiche placeholder et sa `signature`, les `sorts_recommandes` de la création (que plus aucun écran ne lisait), 323 clés de traduction par langue, et `tools/structure_modules.py`. Suite verte en 876 s, zéro erreur de script. —
    > [!info] **Inventaire refait le 2026-09-12, avant d'ouvrir le chantier** — les chiffres du 2026-09-08 avaient vieilli.
    > · **« Les listes des fiches de classe » est FAIT** : les talents et les classes ont été mis de côté le 2026-09-09 (il ne reste qu'une fiche, le placeholder). Les 57 capacités écrites en dur sont parties avec elles.
    > · **Les 236 contenus sont toujours là**, en sept types (condition, déclencheur, forme, liaison, modificateur, noyau, portée), et **29 fichiers** en citent par leur nom — dont 11 de tests et 9 tests déjà désactivés (« on en a rien à battre des modules de sorts », Vers la production 180).
    > · **LE PIÈGE DU CHANTIER : 36 identifiants sont des HOMONYMES** — `saignement`, `aveugle`, `epuisement` sont aussi des statuts, `ombre` un élément, `absorption` une stat, `gel` un état. Un `grep` sur leur nom accuse des lignes qui ne parlent pas de sorts ([[Vocabulaire]] le disait pour `absorption`). **Les 200 autres sont propres aux modules** : ce sont eux qu'on peut chercher sans mentir, et les 36 se relisent à la main.
    > **L'ordre, pour que la suite reste verte à chaque pas** : (1) la grammaire survit à un catalogue **vide** — chaque lecteur tient sans contenu ; (2) chaque test qui asserte sur un contenu est repointé vers la grammaire ou désactivé avec sa raison ; (3) **alors seulement** les 236 fichiers partent ; (4) la suite.
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

~~28 bis. **LE CORPS DEVIENT UN PLAN DE PARTIES**~~ — **FAIT le 2026-09-09** *(designer : « oui on y va » sur la
    question 6 bis, puis quatre précisions le même jour).* Le corps est un **plan en données**, un par silhouette
    (`data/plans_corps/`), et les **emplacements d'équipement en dérivent** : perdre un bras retire un emplacement,
    et ce qui s'y trouvait retombe dans le sac.
    **LE CHANTIER ÉTAIT BIEN PLUS PETIT QUE CETTE LIGNE NE LE CROYAIT, et c'est mesurable.** Elle annonçait « le plus
    intrusif de toute la file » parce que « les emplacements sont une liste écrite d'avance ». Or la consolidation du
    2026-09-04 les avait déjà ramenés à **une** source en données, lue par **quatre** endroits, tous du client — la
    simulation, elle, lit `e.equipement[slot]` par clé et n'a jamais connu la liste. *Une estimation d'intrusivité
    vieillit aussi vite que le code qu'elle décrit.*
    **Les quatre précisions du designer, et ce qu'elles ont changé** :
    · **le monde réel, donc des ORGANES** — cœur, poumons, foie, reins, estomac, cerveau, yeux ; et l'anatomie de
      *son* animal pour chacun : sacs aériens et gésier pour l'oiseau, poumons-livres et filières pour l'araignée,
      **un seul** poumon fonctionnel pour le serpent, **aucun organe** pour la gelée ;
    · **il y a bien de la SANTÉ PAR PARTIES** — chaque partie a sa réserve (`part_sante × sante_max`) ;
    · **les non-humanoïdes portent de l'équipement** — mais **« un torse est un torse »** : une pièce d'armure suit
      la FORME du membre, pas l'espèce. J'avais inventé neuf types (barde, chanfrein, fers, chaperon, serres…), le
      designer les a réduits à **deux** — `protege_ailes` et `protege_queue`, les seuls membres sans équivalent
      humain. *Le bon partage n'était pas par espèce, il était par forme.*
    · **l'HYDRATATION** est notée à la ligne 31, avec son porteur naturel : les reins existent maintenant.
    **TROIS DÉFAUTS QUE LA SUITE M'A LEVÉS, ET ILS ÉTAIENT TOUS LES MIENS.** (1) Le routage d'un coup vers une partie
    tirait dans `des`, LE dé du combat : le résultat restait déterministe mais la **séquence** changeait, et six
    tests calibrés sur des jets ont rougi d'un coup — *un consommateur neuf ne perturbe pas un flux existant*,
    l'anatomie a son propre dé. (2) Mes organes étaient **en sucre** : un cœur à 0,15 de la santé maximale touché une
    fois sur dix se crevait à chaque échange, et les cibles mouraient bien avant l'heure. (3) Le plus intéressant :
    je mettais **deux compteurs de mort sur la même chose** — une partie vitale EXTERNE (le torse, la tête) *est* le
    corps, et le corps a déjà la santé globale. *Ce qui se perd, ce sont les membres et les organes ; ce qui tue,
    c'est le compteur global.*
    **Reste** : les prothèses et les greffes, qui sont du contenu modulant une règle — donc de la grammaire des
    modules, lignes 27-28 ; et la contenance interne (décision 6 ter, toujours ouverte).
~~28 ter. **LES CADAVRES RESTENT, ET SE DÉMONTENT**~~ — **FAIT le 2026-09-09** *(designer 2026-09-08 : « il va
    falloir faire en sorte que les cadavres restent, comme ça le joueur peut loot, faire le nécromancien, récupérer
    des membres, des organes — pour se les greffer, les vendre, les greffer sur un PNJ, construire une chimère,
    porter le corps et s'en servir comme projectile »).*
    **CE QUI EST FAIT** : le cadavre est **dessiné** (il entre dans la liste d'image, `vivants()` gardant son sens
    partout ailleurs) et **teinté par son âge** ; il est **persisté** (l'écriture ne filtrait déjà pas les morts) ;
    il est une **cible d'interaction** — l'option « fouiller la dépouille » ouvre l'**écran d'anatomie braqué sur
    lui**, et non un second écran qui redirait les mêmes lignes ; il **pourrit** en cinq stades ; et l'on y
    **prélève** membres et organes, qui deviennent des objets paramétriques qu'on porte et qu'on vend.
    **ET LA POURRITURE NE COÛTE RIEN** : un stade se déduit de `mort_tick`, rien ne se tique. *Ce qui peut se
    déduire ne se balaie pas.*
    **Reste de cette ligne** : **greffer** (grammaire des modules, 27-28) et **lancer un corps** (27 bis).
    ---
    *L'énoncé d'origine, pour mémoire :*
    **Ce qui existe déjà, et c'est plus que je ne croyais** : un être mort n'est **pas effacé** — `vivant = false`, sa
    tuile est libérée, et il reste dans `sim.entites` avec son corps, son équipement et son sac. Le **Fossoyeur** sait
    déjà en trouver un au sol (`not x.vivant and x.pos == q`) et le relever. La dépouille (`depouille`) fait déjà
    tomber la viande et le cuir.
    **Ce qui manque, et c'est net** : `vivants()` filtre les morts, donc un cadavre n'est **ni dessiné, ni sauvegardé,
    ni visé** — il existe dans la mémoire de la partie et nulle part ailleurs. Il faut : le **dessiner** (la pose
    « mort » du rig existe), le **persister**, en faire une **cible d'interaction** (le fouiller comme un coffre —
    l'écran du coffre du 2026-09-08 est déjà le bon écran), et le faire **pourrir** (le temps long, ligne 30).
    **Et pour en retirer un membre ou un organe, il faut la ligne 28 bis** : tant que le corps est une étiquette et
    les emplacements des clés fixes, il n'y a rien à prélever. C'est pour ça que cette ligne est ici et pas ailleurs.
    **Porter un corps et le lancer** demande en plus la **masse et la quantité de mouvement** de la ligne 27 bis :
    un cadavre est le projectile le plus lourd qu'un personnage puisse tenir.
    **Ce que ça ouvre** : le nécromancien, la greffe, la chimère, la vente d'organes — et le cadavre qui traîne, qui
    est aussi ce qui rend une bataille lisible une heure après.

28 quater. **CE QUI ARRIVE À UN CORPS : maladies, drogues, vaccins, médicaments, déformations, mutations**
    *(designer 2026-09-09, en marge de l'anatomie : « à noter, maladies, drogues, vaccins, médicaments,
    déformations, mutations, etc »).* **Noté, pas codé.**
    **Elles se rangent ici, et pas ailleurs, pour une raison** : ce sont toutes des choses qui **modulent une règle
    du monde sur un corps** — exactement ce que la grammaire des lignes 27-28 doit devenir, et exactement là où la
    prothèse et la greffe attendent déjà (28 bis, 28 ter). Les écrire avant, c'est écrire deux fois la même
    grammaire.
    **Le porteur existe depuis le 2026-09-09** : le corps est un **plan de parties** avec ses organes, sa santé par
    partie et ses sens. Chacune de ces six choses a donc déjà un endroit où s'accrocher, et c'est ce qui rend la
    ligne peu coûteuse le jour venu :
    · une **maladie** attaque un organe nommé — une pneumonie prend les poumons, une néphrite les reins ; sa
      contagion est un champ partagé de plus, et il faudra dire lequel (le contact ? l'air ? l'eau ?) ;
    · un **médicament** rend de la santé À UNE PARTIE, ce que rien ne sait faire aujourd'hui (le soin par partie
      manque, et il manque déjà sans les médicaments) ;
    · un **vaccin** est le premier effet du jeu qui agit sur ce qui n'est **pas encore arrivé** — une immunité, donc
      un état du corps et non un statut à durée ;
    · une **drogue** est un modificateur à contrepartie, avec accoutumance et manque : c'est le cas d'école du
      module qui n'est pas qu'un bonus ;
    · une **déformation** et une **mutation** touchent au plan lui-même — ajouter une partie, en changer les
      chiffres, en supprimer une. **C'est le seul de ces six qui demande que le plan de corps devienne modifiable
      PAR ÊTRE**, alors qu'il est aujourd'hui partagé par silhouette. À voir en premier le jour venu.
    **LES TROIS QUESTIONS SONT TRANCHÉES — designer, 2026-09-09 : « oui pour tout ».**
    · **La contagion est un CHAMP PARTAGÉ**, au même titre que le bruit et l'odeur. C'est la réponse la plus lourde
      des trois, et la plus cohérente : une épidémie devient un **lieu** et non un compteur par individu, elle se
      propage, elle s'atténue, elle stagne dans une pièce close — et l'on peut **fuir** un quartier malade, ce qu'un
      jet de contagion par contact ne permet pas. Elle hérite du patron de la chaleur, comme les quatre autres.
    · **Une mutation est HÉRITABLE.** Elle ne peut donc pas être un simple statut : elle doit vivre dans le **plan de
      corps de l'être** et se transmettre à la naissance. C'est ce qui exige que le plan devienne modifiable PAR
      ÊTRE — le point signalé ci-dessus devient obligatoire, plus seulement souhaitable. L'élevage (les bêtes
      domestiques du 2026-09-07) en devient un terrain d'expérience : on sélectionne ce qu'on reproduit.
    · **Une maladie touche AUSSI les bêtes.** Rien ne réserve la pathologie aux êtres pensants : un troupeau qui
      tombe malade est une catastrophe de village, et la faune malade est un signal que le joueur peut lire.
    *Ces trois réponses agrandissent la ligne plutôt qu'elles ne la simplifient — c'est noté, et c'est assumé.*

## Palier 7 — les quatre champs restants, dans l'ordre du designer

~~29. **La rumeur qui circule**~~ — **FAITE le 2026-09-09**, avec 29 bis, parce que les deux ne sont qu'un système. Voir [[Rumeur et factions]].
~~29 bis. **Les factions par tags idéologiques — et une faction par espèce**~~ — **FAITES le 2026-09-09** *(élargi le 2026-09-08 par le designer : « réputation par factions, une faction par espèce »).* La réputation existe déjà par PNJ, par village, par royaume et globalement ; **l'étage des factions manque**, et avec lui l'idée qu'une **espèce** en est une — aujourd'hui, chasser les cerfs jusqu'au dernier ne fâche personne. C'est le **lecteur naturel** de la rumeur (ligne 29) : elle transporte le fait, la faction décide qui s'en offusque. Les trois — rumeur, tags, factions — sont un seul système, à écrire ensemble.

*L'analyse d'origine :* — *validé le 2026-09-08 sur un avis extérieur, voir [[Vers la production]] ligne 149.*
    **Le fait vérifié** : `Surface._lier_royaumes` calcule la relation entre deux royaumes à partir d'**attributs
    présents** (race, culture, gouvernance, écart de taille) plus un aléa, et son commentaire le dit lui-même —
    « une fonction **PURE** de la graine et de la paire ». **Deux royaumes ne se haïssent jamais POUR quelque chose**,
    et rien de ce que fait le joueur ne change une relation entre pays.
    **Ce qu'il faut** : des actions qui portent des **tags** (`nature_detruite`, `industrie`, `sang_verse`…) et des
    factions qui portent des **valeurs**, la réputation s'ajustant seule. La matière première existe : cultures par
    région, types de gouvernance, réputation à trois étages, vecteurs Wu Xing.
    **Il est ici et pas ailleurs parce qu'il est le lecteur naturel de la rumeur** : elle transporte le fait, les tags
    décident qui s'en offusque. À faire **avec** la ligne 29, pas avant.
    **CE QUI EST FAIT** : les faits tagués, la rumeur DÉDUITE (rien ne se propage : un observateur sait à
    partir de sa distance et du temps écoulé), les cinq factions nommées, l'espèce comme faction implicite,
    et `relation_de` qui ajoute ce que les factions du PNJ pensent, **et la réplique « on raconte »** qui rend enfin
    le système audible : le PNJ dit le fait le plus frais arrivé jusqu'ici, sur le ton de ses propres valeurs.
    **Ce qui reste** : les ROYAUMES ne
    portent toujours pas de valeurs — `_lier_royaumes` reste une fonction pure de la graine, et c'est la
    moitié de l'analyse d'origine qui n'est pas comblée ; le dialogue ne colporte pas encore.
29 ter. **LES SOUS-RACES, ET CHACUNE SA SOUS-FACTION** *(designer 2026-09-10 : « sous classes (homme bêtes =
    homme chats, hommes chiens, etc.), chacun a sa sous faction »).* **Noté, pas codé.**
    **CE QUI EXISTE DÉJÀ, ET C'EST PRESQUE TOUT LE MÉCANISME** : `SimRumeur.factions_de` DÉRIVE déjà une faction
    d'espèce (`espece:<id>`) sans qu'aucun fichier ne la déclare, et la réputation est une **somme sur toutes les
    factions dont on est membre**. Une sous-faction par sous-race est exactement le même tour, avec un `parent` en
    plus.
    **LE POINT DE CONCEPTION, ET IL EST LÀ** : une sous-faction doit **hériter** de sa mère, sinon on obtient des
    factions isolées qui ne se parlent pas. Un homme-chat appartient à `race:homme_chat` **et** à `race:homme_bete`
    **et** aux factions idéologiques ; ce qui offense les hommes-bêtes l'offense, et ce qui touche les chats
    l'offense **plus**. La somme sait déjà additionner des appartenances multiples — il n'y a rien à réécrire.
    **CE QUE ÇA COÛTE VRAIMENT** : un `parent` sur la fiche de race, quelques lignes dans `factions_de`, et **du
    contenu** — un fichier par sous-race, avec ses bonus, son espérance de vie et surtout **son visage**. C'est là
    qu'est le vrai prix : un homme-chat veut son museau court et ses oreilles pointues, un homme-chien son museau
    long et ses oreilles tombantes. Les marqueurs de visage du 2026-09-09 rendent ce travail possible sans code ;
    **il reste du dessin**, et le dessin est au designer.
    **CE QUE ÇA OUVRE** : une politique interne aux peuples. Chasser un cerf fâche les cerfs ; frapper un
    homme-chat fâchera les chats plus fort que les hommes-bêtes en général, et un village d'hommes-chiens s'en
    souviendra autrement qu'un village mêlé.

29 quater. **LES VILLES SONT VRAIMENT VIVANTES** *(designer 2026-09-10 : « les villes sont vraiment vivantes, par
    exemple les villes cyberjunkie sont en chaos constant, les PNJ se jettent des bouteilles d'alcool, se battent,
    se droguent »).* **Noté, pas codé.**
    **CE N'EST PAS UNE IA NOUVELLE, ET C'EST CE QUI LA REND ABORDABLE.** Un PNJ suit déjà une routine à trois
    plages — `poste`, `social`, `lit` — tirée de sa fonction, décalée par ses traits, suspendue les jours de fête.
    Une ville en chaos n'est pas un autre cerveau : c'est un **caractère de ville** qui (1) **repondère** ces
    plages — beaucoup de `social`, peu de `poste` — et (2) **débloque une poignée d'actes** que personne ne fait
    aujourd'hui : boire, jeter une bouteille, se battre entre civils, se droguer.
    **ET LES CONSÉQUENCES SONT DÉJÀ ÉCRITES**, ce qui est le meilleur argument pour cette ligne : une rixe est un
    fait `frapper_civil`, donc taguée `sang_verse` et `ordre_trouble`. Une ville où l'on se bat tout le temps est
    donc une ville **que les gens d'armes détestent et que le Cercle du soufre adore**, sans une règle de plus. Le
    système de rumeur et de factions du 2026-09-09 se paie ici.
    **UNE DÉPENDANCE NETTE** : « se droguer » demande les **drogues** de la ligne 28 quater. Sans elles, une ville
    cyberjunkie n'est qu'un générateur de bagarres — la moitié de l'image manque.
    **UNE QUESTION DE REGISTRE, ET ELLE N'EST PAS À MOI** : « cyberjunkie » suppose un registre technologique. Le
    monde a déjà des **robots** et un palier industriel, donc ce n'est pas une rupture — mais cela décide de ce à
    quoi une ville peut ressembler, et jusqu'où va le mélange. *Voir [[Décisions en attente]].*
    **CE QU'IL FAUDRAIT EN DONNÉES** : un `caractere` par village (paisible, laborieux, chaotique, dévot…), ses
    poids de routine, ses actes permis, et ce qu'il fait aux prix et à la garde. Le reste existe.

29 quinquies. **LE TÉMOIN, ET L'ABSENCE QUI SE REMARQUE** *(designer 2026-09-10 : « tuer un robot devant tout le
    village fait baisser la réputation drastiquement… mais si le robot est tué discrètement, caché dans un coin, et
    que le corps est débarrassé, les autres ne peuvent pas savoir donc pas de répercussions — mais les PNJ vont se
    demander où est passé le PNJ mort, ça va affecter tout le monde »).* **Noté, pas codé.**
    **C'EST LA LIGNE QUI DISTINGUE LE JEU**, et la seconde moitié est meilleure que la première.

    **1. LE TÉMOIN — une demi-journée, et le plus fort effet du lot.** `SimRumeur.rapporter` enregistre aujourd'hui
    un fait **quoi qu'il arrive** : le monde sait tout, tout le temps. Il devrait exiger **quelqu'un qui a vu** — et
    le code existe déjà, mot pour mot, dans `SimRoyaumes._infraction` : le témoin civil le plus proche qui voit
    l'auteur, jet de Perception contre Discrétion, +4 la nuit. Cette seule condition transforme le système social en
    **système d'infiltration** : la Discrétion cesse d'être un modificateur de portée pour devenir *ce qui décide si
    le monde apprend*. Et elle donne son sens noir à ce qui est déjà codé — porter un corps (26 decies), le cacher,
    le laisser devenir des ossements.

    **2. L'ABSENCE EST UN FAIT SANS AUTEUR, et c'est la trouvaille.** Un meurtre a un auteur ; une disparition n'en a
    pas. « On ne voit plus le forgeron » se range donc dans la rumeur comme un fait d'un genre nouveau — sujet, lieu,
    heure, **pas d'auteur** — et il ne produit pas de l'hostilité mais de l'**inquiétude**. Personne ne t'accuse ;
    la ville change autour de toi. Les prix montent, on rentre plus tôt, les gardes patrouillent, et quelqu'un te
    demande *à toi* si tu l'as vu.
    **QUI LE REMARQUE, ET QUAND** : d'abord **ceux qui avaient une relation avec lui** (`social.relations` existe
    déjà), puis le village. Un proche s'en aperçoit en un jour, la ville en une semaine — la même mécanique de délai
    que la rumeur, appliquée à un manque au lieu d'un événement.

    **3. LE CORPS SENT, ET C'EST LE CHAMP D'ODEUR QUI LE TROUVE.** Une dépouille émet dans le champ d'odeur, et
    **d'autant plus fort qu'elle gonfle** (28 ter). Un PNJ qui passe près d'elle et **dont le nez fonctionne**
    (`Etres.sens_actif(e, "odorat")` — les organes de sens, 28 bis) la découvre. La disparition devient alors un
    **corps trouvé** : un meurtre est su, mais **toujours sans auteur** tant que personne n'a vu. *Cacher un corps
    n'est donc pas binaire : c'est un DÉLAI.* Et le temps joue pour toi — passé la putréfaction, les ossements ne
    sentent plus rien.
    **Quatre systèmes déjà écrits se rejoignent ici** : l'anatomie (le nez), le champ d'odeur, les stades de
    pourriture, la rumeur. *C'est le meilleur signe qu'une ligne est à sa place.*

    **LE PIÈGE À CONNAÎTRE AVANT DE CODER** : « absent » ne doit pas vouloir dire « dormant ». Un PNJ hors de la
    fenêtre est mis de côté dans `Monde.dormants` — s'il compte comme disparu, tout village qu'on quitte se croira
    décimé. La comparaison honnête est **le rôle du village contre les vivants** : `monde.villages[nom].capacite` et
    le `village` que chaque PNJ porte. Une passe hebdomadaire suffit.

    **CE QUE ÇA OUVRE, ET C'EST LA PHRASE DU JEU** : *on peut distancer sa propre réputation*. Tuer sans témoin,
    marcher trois jours, être accueilli — puis voir la nouvelle vous rattraper. Ou ne jamais être rattrapé, si le
    corps est devenu des ossements au fond d'une mine.

~~30. **Le temps long** — usure, ruine, repousse — avec `alteration`.~~ — **LA RUINE ET LA REPOUSSE FAITES le
    2026-09-09** ; **l'usure d'un objet reste**.
    **CE QUI N'ALLAIT PAS, ET QUI N'ÉTAIT PAS UN MANQUE MAIS UNE FAUTE** : la repousse existait déjà — chaque
    semaine, le monde effaçait les modifications de terrain hors des claims. Mais **d'un coup, toutes à la
    fois, sans regarder la matière** : un mur de granit et un toit de chaume tombaient à la même seconde, et
    le passage creusé dans la roche se refermait aussi vite qu'un sentier dans les roseaux. C'était une
    repousse, pas un temps long.
    **CE QUE LA COLONNE `alteration` APPORTE** : le DÉLAI. Ce qui est **debout** décide en premier — un mur
    bâti résiste par SA matière, pas par celle qu'il a remplacée ; à défaut, c'est la matière **retirée** qui
    dit à quelle vitesse le monde la remet. **Et le délai ne se tique pas** : la modification porte l'heure où
    elle a été faite, et la passe hebdomadaire compare — même économie que la pourriture d'une dépouille et
    que la rumeur. *Ce qui peut se déduire ne se balaie pas.*
    ~~**RESTE L'USURE D'UN OBJET**~~ — **FAITE le 2026-09-09 au soir**, et la ligne 30 est entière.
    **LA PRÉCAUTION A DÉCIDÉ DU DESSIN** : `qualite` est lue par les dégâts, par l'armure et par les prix, et des
    dizaines de tests sont calibrés dessus. On n'y touche donc PAS. L'usure est un **champ à part**, à zéro par
    défaut, et une seule fonction — `qualite_utile` — combine les deux au moment de s'en servir : *un objet qui n'a
    jamais servi se comporte exactement comme avant, à la virgule près.*
    **TROIS GESTES USENT**, et ce sont les trois où la matière travaille : frapper (l'arme), encaisser (la pièce
    d'armure touchée), creuser (l'outil). Rien d'autre — un manteau porté ne se troue pas parce que le temps passe.
    La vitesse vient de l'`alteration` du matériau : *une lame de fer s'émousse, une lame d'or serait ridicule mais
    ne s'abîmerait pas* — la même stat qui dit pourquoi l'or vaut cher.
    **ET IL Y A UN CHEMIN DE RETOUR** : un mécanisme qui ne fait que dégrader est un impôt, pas une règle. Une unité
    de la matière de l'objet, à une station de sa recette, et l'usure retombe — *on ne rend jamais un objet NEUF, on
    le maintient.* Le plafond tient l'autre bout : un objet usé est mauvais, il n'est jamais inutile.
~~31. **Les besoins au-delà de la faim** : soif, sommeil, peur qui dure~~ — **LIGNE ENTIÈRE le 2026-09-13.**
    ~~**L'HYDRATATION**~~ — **FAITE le 2026-09-09 au soir** *(designer : « on rajoutera l'hydratation aussi »).*
    Elle est la faim avec des nombres plus courts — trois semaines sans manger, trois jours sans boire —, les deux
    malus de stats se cumulent, et elle n'a demandé **aucune règle nouvelle**. On boit à même l'eau (gratuit,
    abondant, risqué : une eau de mare passe le jet d'infection de la viande crue) ou un objet qui porte
    `hydratation` sur sa fiche. **Et les reins ont cessé d'attendre** : leur bloc `perdu` a remplacé leur `attend`
    — un rein en moins fait boire plus souvent. C'était le seul manque ÉCRIT du plan de corps.
    ~~**Restent** : le **sommeil** et la **peur qui dure**~~ — faits tous deux le 2026-09-13.
    ~~**LA PEUR QUI DURE**~~ — **FAITE le 2026-09-13.** Le sang-froid est la jauge du combat ; la **frayeur** est sa **trace**. Même patron que le sommeil : une valeur et l'heure du dernier choc, **éteinte par demi-vie** (une demi-journée) déduite à la lecture. Deux chocs — frôler la mort (passer sous 25 % : 40 points), voir tomber un des siens à 12 tuiles (30) — et un effet : **le sang-froid revient moins vite** (au quart, à pleine frayeur), parce qu'on ne retient pas son souffle quand on tremble. Une nuit la divise par deux. **Seul le camp du joueur en garde une trace** : la faune et les PNJ ont déjà leur fuite.
    ~~**LE SOMMEIL**~~ — **FAIT le 2026-09-13.** **La fatigue n'est pas une jauge qu'on décrémente : c'est le temps écoulé depuis le réveil**, lu à la demande — la règle du coffre, *ce qui peut se déduire ne se balaie pas*, comme la pourriture d'un cadavre se lit depuis sa mort. On ne garde que `veille_depuis` et le palier atteint (pour recalculer les stats et le dire au journal). Seize heures debout : on bâille ; un jour : toutes les stats × 0,9 ; deux jours : × 0,75 **à la place** — et **il ne tue pas**, on devient mauvais à tout. Une nuit dans un lit remet le compteur. Il se cumule à la faim et à la soif : trois manques, trois malus. Le volet n'affiche une ligne que fatigué. **Le test éprouve la déduction elle-même** : sauter deux jours d'un coup donne le même palier que les vivre.
    **UN DÉFAUT JUMEAU, TROUVÉ ET LAISSÉ** : `Etres.creer` pose `faim_tick: 0` — une valeur de fiche, pas une heure.
    Un être créé alors que l'horloge du monde en est à cinq millions de ticks se voit donc retirer d'un coup tout
    le temps écoulé **depuis le début du monde**. La soif l'a révélé en tuant des PNJ à leur naissance ; sa cadence
    étant plus courte, elle vidait la jauge là où la faim n'en ôte que la moitié. **La soif est corrigée** (elle
    s'estampille à la première lecture) ; **la faim ne l'est pas**, parce que les nombres de ses tests sont
    calibrés sur ce comportement — un PNJ de village naît à moitié affamé, et plusieurs seuils s'y accrochent.
    *C'est un manque écrit, pas un manque tu.*
    **CORRIGÉ le 2026-09-13** : la faim s'estampille à la première lecture, comme la soif. **Et la raison de l'avoir laissé était périmée** : la suite est passée verte du premier coup, aucun seuil ne s'y accrochait plus. *Une dette écrite se revérifie ; elle peut s'être payée seule.*
32. **L'eau qui pèse** — ~~pression~~, ~~poids~~, ~~érosion~~ — avec `permeabilite`. **L'INFILTRATION FAITE le
    2026-09-09** ; la pression et l'érosion restent.
    **La quinzième et dernière des cinq colonnes est écrite.** Un creux était jusqu'ici un bassin PARFAIT quel
    que soit son fond — on tenait un étang sur du sable, et un trou creusé dans le gravier gardait sa pluie
    pour l'éternité. Le fond décide désormais : l'argile (3) retient, le sable (92) vide, la ponce (74) boit.
    **Et creuser un bassin devient un ouvrage** : il faut la bonne matière au fond, ou l'y poser.
    **UNE PARTICULARITÉ DE CETTE COLONNE, ET ELLE EST HONNÊTE À DIRE** : les quatre autres se déduisaient de
    stats existantes ; celle-ci ne le peut pas — la perméabilité est affaire de GRAIN, pas de densité, et
    l'argile et le sable ont chez nous la même densité. Une trentaine de matières dont la perméabilité est le
    trait définissant portent donc leur valeur en clair. C'est du contenu, pas du code en dur.
    ~~**RESTENT** : la **pression** et l'**érosion**~~ — **FAITES le 2026-09-09 au soir**, et la ligne 32 est
    entière. **J'avais écrit qu'elles demandaient une CHARGE** ; c'était vrai d'une charge *générale* — un automate
    où chaque tuile porte une pression et la transmet — et **faux des deux effets qu'on voulait**. *Mieux vaut les
    avoir simples que les attendre parfaits.*
    **LA PRESSION VIENT DE LA PROFONDEUR** : percer une poche posait un niveau 8 sur la brèche — un robinet, comme
    la note le disait en toutes lettres. La poche percée est désormais une **source** qui alimente d'autant plus
    longtemps qu'on l'a trouvée bas : elle inonde la galerie au lieu de mouiller une dalle, et elle **s'épuise**.
    **L'ÉROSION** : une eau qui *court* use ce qu'elle traverse, à la vitesse de l'`alteration` du sol — le même
    `alteration` que la ruine et que l'usure des objets, pour la troisième fois de la journée. Un ruisseau creuse
    son lit. **Elle est bornée à UN niveau par tuile, exprès** : sans ce garde-fou, un ruisseau creuserait un canyon
    sans fond et personne ne s'en apercevrait avant que le monde ne soit troué. Hors des claims seulement — ce qu'on
    entretient ne s'use pas.
    **ET LE TEST A LEVÉ DEUX FAUTES EN DEUX PASSES** : la garde de l'automate ne regardait que les tuiles *actives*,
    si bien qu'une nappe percée sur une grille sèche n'alimentait jamais (*un état neuf doit entrer dans TOUTES les
    gardes qui décident si l'on tourne*) ; et le niveau 8 est celui d'une **source**, que `_poser_eau` refuse parce
    qu'il sert à l'écoulement et borne à 7.

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

~~37. **Le coût d'une capacité, écrit au moment de la lancer**~~ — **FAIT le 2026-09-09**. Le déficit se paie en
    points de vie depuis longtemps, et le joueur ne l'apprenait qu'APRÈS, par une ligne de journal, une fois les PV
    partis. Il se lit maintenant sur la ligne de la hotbar : *« coût 40 mana (il t'en reste 5) — il t'en manque 35 :
    70 PV »*. **Un coût qu'on découvre en le payant n'est pas un coût, c'est une punition.**
~~38. **La réputation à l'écran**~~ — **FAITE le 2026-09-09** : village, royaume, globale — **et ce que les factions
    en pensent**, qui n'existait à l'écran nulle part. Seules celles qui ont un avis se montrent, sans quoi la ligne
    serait un mur de zéros. *La rumeur du soir devient lisible.*
~~39. **Le refus visible**~~ — **FAIT le 2026-09-09**. Un bandeau reprend la dernière ligne du journal, en grand, au
    centre bas, et s'efface en quelques secondes. **Il est sur sa PROPRE couche, au-dessus des écrans** — et c'est
    la sonde qui l'a exigé : le premier jet était un `Control` du HUD, or les écrans sont un `CanvasLayer` à
    `layer = 10` qui passe par-dessus toute cette couche quel que soit l'ordre où on l'a monté. Le bandeau serait
    donc resté **sous le panneau**, c'est-à-dire exactement le défaut que la ligne corrige. *Un message qu'on ne
    peut pas voir n'a pas été dit.*

## Palier 10 — ce qui existe et qu'on ne verra jamais

39 bis. **Le voyage devient un TRAJET** — ⚠️ **SUSPENDU le 2026-09-08 à 15 h 30** : le designer veut revoir l'exploration et la génération du monde en entier (« plus Caves of Qud / Dwarf Fortress que JRPG classique / Elin / Elona », [[Vers la production]] ligne 154). Un trajet cellule par cellule sur un écran de carte est une amélioration *dans* le modèle actuel ; si le modèle change, elle devient sans objet. **Ne pas coder avant d'en avoir reparlé.** — *décidé le 2026-09-08 : « un système comme Fallout 1 où le joueur clique
    n'importe où sur la carte et le personnage s'y déplace petit à petit avec événements ».* Aujourd'hui cliquer loin
    **téléporte** (l'horloge avance du coût entier d'un coup) et le pas à pas de cellule en cellule est le « Dragon
    Quest » que le designer veut remplacer. Les pièces existent : coût par cellule, réduction par la route, gestion de
    l'arrivée, pas d'une cellule. Le trajet, c'est **une file de cellules, une cadence et un point d'interruption**.
    **Il est ici et pas plus haut parce qu'il est le théâtre des « événements en zone logique »** (ligne 43), qui n'ont
    aujourd'hui aucun endroit où se produire, et parce que la fréquence des rencontres voudra lire le **champ de
    danger** (ligne 24). Le faire avant, c'est le faire deux fois. Voir [[Carte du monde]].


~~40. **Effacer le code mort de la génération de village.**~~ — **FAIT le 2026-09-12** : la ligne annonçait deux fonctions sans appelant, **il y en avait trois** (75 lignes) — `_parcelle` (46 lignes, la plus grosse, que la ligne ne nommait pas), `_rectangle_libre` (« celle qui tirait au hasard ») et `culture_de_region`. **Vérifié avant de supprimer** : la fonctionnalité « une région parle la même langue » est bien vivante — `_palette_village` lit la culture de la région en direct —, seul le raccourci était inutile. *Supprimer un raccourci sans regarder ce qu'il enveloppe, c'est faire passer une fonctionnalité morte pour un nettoyage réussi.* — *La ligne d'origine était fausse et à l'envers* : les
    bâtiments **se rangent** le long des rues depuis le 2026-09-07 ; ce sont deux autres fonctions qui n'ont plus
    d'appelant, dont celle qui tirait au hasard. Il ne reste qu'à supprimer.
~~41. **Poser la bibliothèque de préfabs de donjon** (12 salles, 8 connecteurs), chargée à chaque démarrage et jamais
    utilisée.~~ — **FAIT le 2026-09-13 pour les salles.** `theme.prefabs` (chance 0,25 par salle, 2 au plus par étage, tailles petite à grande) mêle des plans dessinés aux rectangles ; chaque thème dit quels `floor_theme` il accepte (ruine et repaire les leurs, terre et métal la mine, bois, eau et feu la ruine). **Le plan est estampé tel qu'il est dessiné** — sol, reliefs chiffrés, portes — et **les couloirs arrivent PAR UNE PORTE** (`_ancre` : la tuile devant la porte la plus proche), au lieu de percer le mur dessiné. Un thème sans bloc `prefabs` ne tire aucun dé de plus : son étage reste celui d'avant. **Mesure** : 10 préfabs sur 8 étages, 5 plans différents, tous rejoints par une porte ; l'étage se génère en 22,5 ms (critère É2 : 100). Capture : `capture.tscn -- --donjon --prefab`.
    **Un test comptait sans le dire sur un escalier désert** : les préfabs ont redessiné l'étage, deux scorpions y veillaient et le combat retenait le joueur hors de la file. Le test prouve qu'on descend AVEC SON ÉTAT — il calme désormais l'escalier lui-même. **Reste** : les **8 connecteurs** (les couloirs sont toujours creusés, pas posés) et ~~les `special_tags`~~ — **lus le jour même** : le dernier étage essaie d'abord une salle `boss_room_eligible` et y met son boss (5 derniers étages sur 5), l'arrivée passe dans une salle `entree_eligible` quand l'étage en a une, une salle `treasure_eligible` garde un coffre de plus. *Le premier essai mettait l'arène en tête de liste — donc à l'arrivée : on entrait chez le boss.*
~~42. **Les 30 bois inatteignables.**~~ — **FAIT le 2026-09-13, par les tables de biome.** **22 essences poussent désormais là où elles poussent vraiment** — charme, érable, tilleul, châtaignier, merisier, noisetier et if en forêt tempérée ; orme, peuplier, noyer, pommier, platane et robinier en plaine ; aulne et cyprès au marais ; cèdre, séquoia et buis en montagne ; acacia, chêne-liège et eucalyptus au désert aride ; palmier sur la côte — **et la densité totale de chaque biome n'a pas bougé** : on partage la forêt, on ne la double pas. Les villages en profitent seuls, leur bois étant tiré parmi les essences du biome.
    **Huit restent, et chacun a sa raison écrite dans l'audit** : six sont **tropicaux** (acajou, balsa, ébène, teck, gaïac, bambou) et attendent un biome tropical — la génération du monde est en révision chez le designer (39 bis) ; deux ne sont **pas des essences mais des transformations** (`bois_calcine`, `bois_flotte`) et attendent que le feu et l'eau les produisent.
    **POURQUOI PERSONNE NE LES VOYAIT** : `tools/audit_donnees.py` comptait `world_gen.mode == "biome"` comme une source — une promesse que rien ne tenait (`biome_tags` est vide sur les 40 bois, et aucun code ne le lit). L'audit lit maintenant les tables, et en corrigeant il a appris deux sources qu'il ignorait (`drops_chasse`, `elevage.produits` : la laine n'était pas orpheline) et en a démasqué une vraie : **`meteorite_ferreuse` n'a aucune source**.
42 bis. **Les 57 matériaux bruts qu'on ne peut obtenir nulle part** — levés en corrigeant l'audit de la ligne 42, **et le chiffre est cette fois vérifié à la source**, pas estimé. Une matière brute n'entre dans un sac que par **trois portes** (`SimTerrain._donner_materiau`) : récolter une tuile qui la porte, sortir d'une recette, retirer un stock du territoire. L'audit lit maintenant ces portes — tables de biome, tiers **et fossiles** de `minerais_par_etage`, guano des repaires, gemmes des géodes, `elevage.produits` — et **ne compte plus** `depouille` ni `drops_chasse` : ce sont des **objets** consommables dont l'id est parfois homonyme d'une matière (l'`os` qu'on dépèce n'est pas la matière `os` qu'une recette demande).
    **Ce qui reste, par nature** : **roches, minéraux, terres** (galène, hématite, magnétite, azurite, kaolin, alun, borax, potasse, chaux, uraninite, amiante, gravier, humus, limon, marne, tourbe, latérite, sable noir…) — la géologie, qui irait dans les filons et les strates ; **parties animales** (os, corne, carapace, tendon, boyau, vessie, soie d'araignée, venin, os de seiche, nacre, corail, éponge, miel, cire) — qui demandent que la chasse rende **aussi** la matière, pas seulement l'objet ; **transformés** (colle d'os, cuir bouilli, feutre, parchemin, plâtre, poix, porcelaine, scorie, goudron, essence de térébenthine) — qui attendent leur recette ; **liquides et météo** (eau, eau salée, saumure, sang, mercure, lave, givre, glace, grêle) — qui demandent un contenant ou un champ ; et **les fossiles orphelins** (dent fossile, trilobite, bois pétrifié, météorite ferreuse).
    **Aucune de ces matières n'est absente du jeu** : la table de l'inattendu (`sim_objets`) les pose toutes comme composants d'objets trouvés ou vendus — un manche en os existe. Ce qui manque, c'est **la matière brute**, donc le craft qui en part. **L'audit reste borné aux bois** jusqu'à ce que chaque famille ait sa porte.
~~43. **Les signaux sans auditeur.**~~ — **FAIT le 2026-09-12, et PAS comme la ligne le demandait** : un signal émis sans auditeur est un point d'extension, pas un défaut. Un seul était vraiment mort (`locale_changed`, retiré) ; les douze autres sont gelés avec leur raison par `tools/verif_signaux.py`, qui échoue sur le treizième et sur tout signal **écouté mais jamais émis** — voir [[Ordre de vérification]]. — *Correction* : ils ne sont pas douze mais **dix** — deux ont un auditeur dynamique,
    invisible au grep, via les bulles d'onboarding. En revanche `locale_changed` est bien mort des deux côtés.
    `dungeon_cleared` est déjà traité au palier 4 : c'est la même plaie vue de l'autre côté.

## Palier 11 — la performance, quand la simulation a fini de grossir

**Mesurer avant, pas pendant** : chaque champ ajouté aggrave le coût d'un recentrage de fenêtre (chaque champ remplit
sa carte entière au changement de grille).

> [!success] La **chasse au lag du 2026-09-08** (carte blanche du designer) a déjà pris les leviers bon marché de ce
> palier : la carte de lumière (ligne 45), les occulteurs fantômes, et le **champ de vue du joueur** — qui empruntait la
> portée de détection d'une IA et ne voyait que cinq tuiles, si bien que toute la ville était du **mémorisé**. Pire
> image **46,1 → 36,6 ms**. Aucun de ces trois n'était du C++. Détail et méthode : [[Budgets de performance]].


44. **Le franchissement de cellule.** *Chiffre corrigé* : ~13 ms par cellule, pas 31, depuis le portage C++ — mais
    toujours six à sept fois le budget, et trois cellules dans la même image.
45. ~~**La carte de lumière**~~ — **FAIT le 2026-09-08** : elle était refaite **entièrement à chaque tick de monde**
    dès que quelqu'un lisait la lumière. Refaite sur le patron de la chaleur (une signature : tuiles, porteurs de
    lumière, heure) — **cent recalculs → zéro** sur cent ticks immobiles, prouvé par `test_lumiere_incrementale`.
45 bis. **Fusionner les silhouettes mémorisées adjacentes — et c'est le seul endroit qui reste où le C++ servirait.**
    *La réponse mesurée à « tu peux pas réécrire certaines fonctions en C++ ? » (designer, 2026-09-08) : les deux
    passes chaudes **y sont déjà**, et le C++ y est la **moitié bon marché** — un morceau de terrain, c'est 0,23 ms de
    noyau contre 0,87 ms de soumission ; le brouillard, 7,3 contre 12,7. Le calcul n'est pas le mur, la **soumission**
    l'est.* Donc le levier n'est pas de calculer plus vite mais d'avoir **moins à soumettre** : la part mémorisée d'une
    ville est dessinée en aplats, **une tuile à la fois**, alors que des voisines de même teinte pourraient n'être
    **qu'un rectangle**. C'est une boucle pure, elle a sa place dans `SensenGrille.brouillard` qui bâtit déjà le
    tableau, et c'est de la **géométrie en moins** — pas un portage de plus. Voir [[Modules de la simulation et le C++]].
45 ter. **D'où viennent les ~1 240 appels de dessin par image ?** Le nombre n'a pas bougé d'un pouce entre les deux
    branches de l'A/B du champ de vue (1 236 contre 1 242) : il ne dépend donc **pas** de ce qui est vu. **À
    instrumenter avant de toucher quoi que ce soit** — je ne connais pas leur répartition, et la ligne 45 bis pourrait
    n'en retirer aucun si les aplats mémorisés partagent déjà une commande.
46. **Les cellules jamais déchargées** — *l'avis extérieur du 2026-09-08 tape exactement ici : la moitié « recompresser quand le joueur part » du principe macro/micro est la seule qui manque à Sensen.* *Dépendance nette* : **après** la ligne 44, jamais avant — évincer les cellules
    tant que la pré-génération coûte 13 ms rendrait le défaut **pire** (aujourd'hui, revenir sur ses pas est gratuit).

## Palier 12 — les tests, le coffre, et l'ancienne file

47. ~~**Les tests qui ne prouvent rien**~~ — **FAIT le 2026-09-13** (section 8 de [[Vers la production]], entière : l'XP d'armure, la fourchette de dégâts, le froid et le chaud, les échecs de lecture, les budgets — dont un budget de tick jamais mesuré qui a levé le courant —, huit assertions toujours vraies, les sondes à code 0). *Reste de cette ligne : l'ancienne file.* —, dont plusieurs **cachent** des défauts réparés en chemin, et ~~**le coffre qui se
    contredit**~~ — **FAIT le 2026-09-13**, les onze contradictions du balayage (voir [[Vers la production]], section 9) ; une seule a demandé du code : la Méditation, dont la réserve promise n'avait jamais été codée.
    Plus **l'ancienne file** jamais revue : les saisonniers, le chômage qui pousse à migrer, les tombes qui
    vieillissent, les événements en zone logique, ~~**une guerre qui ne fait rien**~~ *(faite le 2026-09-13 : pertes, solde de campagne, reddition et tribut)*, le nom de la vocation à l'écran,
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
