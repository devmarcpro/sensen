---
aliases: ["Vers la production", "Roadmap de pré-production", "Ce qui manque"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 0
---

**Le design est complet et décidé.** Il ne reste ni question bloquante ni valeur à inventer : tout ce qui était ouvert porte une décision ou un défaut chiffré. Ce qui suit est l'état de production — ce qui est fait, et ce qui reste à *produire* (assets, code).

> [!important] Étape 0 — les 12 jalons sont codés, reste le jugement (2026-08-26, soir)
> La démo 0 est devenue le **prototype de combat** : `godot/scenes/demo/main.tscn` charge les **3 arènes** depuis `data/prototype_arenas/` (Tab pour changer), avec autoloads GameData/EventBus/TickManager, grille SoA + A* 8 directions + ligne de vue, simulation autoritaire (intentions → résolution), une horloge par combat, mêlée avec zones par dénivelé et armure plate, garde frontale, attaque lourde télégraphée, endurance, attendre, chute, IA utility en données et les 24 actions de créatures ; **Wu Xing** (vecteurs, domination, jauge de chaîne avec décroissance et résolveur, prévisualisation au survol), **râtelier** (1-7) et **bouclier** ; **modules assemblés** (F1-F3 : trois capacités, mana, surchauffe, friendly fire des zones, conditions) ; **projectiles** (arc, munitions, trajectoire), **statuts** (14, anti-stunlock, interruption de la jauge des élites), **écran de fin** (durée en ticks, XP des pistes). Tests headless : `scenes/tests/test_combat.tscn`. Détail et jalons restants : [[Prototype de combat — spécification]].
>
> **À juger à l'œil (ouvrir `godot/` dans l'éditeur, F5) — questions à trancher :**
> 1. *Lisibilité de l'iso 32×32 à 40×20 px par tuile* : le relief se lit-il ? Faut-il des ombres de flanc plus marquées ou une grille ? (molette : zoom, clic milieu : déplacer la vue)
> 2. *Rythme des horloges de combat* : `DELAI_PAS = 0.12 s` entre deux pas — trop lent ? trop rapide pour suivre les loups ?
> 3. *Le télégraphe* (« ! » + tuiles rouges pendant une lourde ou une charge) : est-il vu à temps ?
> 4. *Les coûts sur les tuiles* (jaune, budget 12 ticks) : utiles ou bruit ?
> 6. *Les capacités* (F1 puis clic) : la forme bleue prévisualisée et l'infobulle suffisent-elles à comprendre ce qui va partir, pour qui, à quel prix ?
> 7. *Les critères mesurables* : la durée d'une rencontre s'affiche à l'écran de fin (cible 60-200 ticks). Les deux autres sont **calculés** par `scenes/tests/test_criteres.tscn` (dégâts moyens, vraies règles, vraies données — relancer après chaque retouche de JSON) :
>    - **Deux voies de chaîne** (cible ±15 %) : rotation parfaite lance→Étincelle→masse→épée→Gel = **68.8** dégâts en 43 ticks ; construction/détonation dague×4→Gel = **44.4** en 24 ticks ; masse×4→épée lourde = **108.8** en 46 ticks ; épée×5 = 80.0 en 30 ticks. **Écart 36 % : hors cible.** Cause visible : les charges légères (Étincelle 1d4) et le coût des deux swaps pèsent sur la rotation, la lourde ×2.2 pèse lourd dans la détonation. La spec dit *« retoucher les bonus de transition, pas le système »* — décision de chiffres à prendre par le designer (pistes : +0.35 → +0.45 sur l'engendrement, ou une charge moyenne dans la rotation).
>    - **Swap rentable dans certains cas seulement** : par tick, le swap ne paie **jamais** dans les quatre séquences testées (épée×5 : 2.39/tick contre 1.94 avec deux swaps ; dague×5 : 2.59 contre 2.50 dague→épée lourde). **Hors cible** : *« si la réponse est toujours la même, les chiffres sont à revoir »* — 4 ticks de swap contre +0.25 de différence de transition, c'est trop cher ou trop peu payé.
> **Tranché le 2026-08-27 par le designer** (notes datées) : pas de rotation de caméra, ZQSD 8 directions, joueur centré ([[Écrans d'interface]]) · terrain plat, reliefs en exception ([[Génération par couches de bruit]]) · exploration en temps réel conservée · vitesse de déplacement = Athlétisme + modificateur de race, jamais une stat fixe ([[Boucle de tick]]) · dégâts d'arme × skill_factor(arme) × skill_factor(type) × niveaux d'élément pondérés ([[Pipeline de résolution du combat]]) · niveau de module → ticks / skill_factor, plancher 50 % ([[Structure compétences-modules-slots]]). Tout est codé (crochets de niveaux à 0 jusqu'à l'étape 4).
> [!important] Étape 8.2b — tectonique, mer, 12 biomes (2026-08-28)
> Plaques, continentalité warpée, seuil calibré à 35 % de terres, chaînes sur les sutures, mer en tuiles d'eau (hauteur 8), les 12 biomes. La cellule de départ reste au centre du monde : elle peut tomber en mer — `planete.cellule_depart` est alors déplacée au premier point de terre trouvé en spirale (garde-fou de [[Début de partie]], < 200 tuiles marchables). **À juger** : la forme des côtes, la part de mer visible depuis le camp, la lisibilité des biomes par la couleur du sol et les arbres.
> [!important] Étape 8.2a — un monde continu qu'on traverse à pied (2026-08-28)
> Fenêtre glissante de 3×3 cellules, coordonnées monde, recentrage au changement de cellule, cache + pré-génération en thread, modifications et découvertes capturées par cellule (un mur posé dans une cellule qu'on quitte y est encore au retour). **À juger** : le recentrage (un à-coup au passage d'une cellule ? mesuré ~150-300 ms quand la cellule n'est pas pré-générée), la continuité visuelle entre cellules. Tectonique, eau, autres biomes, minimap et sauvegarde sur disque suivent (8.2b-c).
> [!important] Végétaux en billboards (2026-08-28)
> Instruction du designer : arbres et plantes sont des sprites billboard dessinés par code (silhouettes feuillu/conifère/palme/buisson/herbe, teinte de l'essence), plus des blocs. Plantes sauvages récoltables à la faucille. **À juger** : les silhouettes (assez lisibles ? assez variées ?), la taille des arbres par rapport aux personnages, l'occultation d'un être derrière un arbre.
> [!important] Fluidité des déplacements (2026-08-28)
> Retour du designer : « les déplacements ne sont pas fluides ». Causes : le terrain statique était **entièrement redessiné à chaque pas** (le champ de vue change à chaque pas → 1 700 tuiles), et les êtres comme la caméra **sautaient** de tuile en tuile. Corrigé : le brouillard est une **couche à part** (opaque sur le jamais-vu, translucide sur le mémorisé) redessinée seule ; le terrain ne se redessine que quand la fenêtre se décale ; les paperdolls et la caméra **glissent** vers leur tuile (interpolation exponentielle, ≈ 0,2 s) ; les touches ZQSD sont relues toutes les 50 ms. **À juger** : la vitesse du glissement, le rendu translucide du mémorisé.
> [!important] Étape 8.1 — une cellule de surface générée (2026-08-28)
> Le camp est désormais une cellule du monde : 8 couches de bruit, 4 biomes, sol coloré par son matériau, arbres/rochers/filons selon le biome, relief plat avec 2-5 accidents posés (talus, estrade, piton, cratère, gorge). **À juger — c'est ici que se valide la décision « plat + exceptions »** : le camp a-t-il l'air d'un lieu ? Les accidents sont-ils assez nombreux/visibles ? La couleur de sol par biome (terre, herbe, sable) suffit-elle à lire le biome ? Tectonique, eau, streaming et carte suivent (8.2-8.3).
> [!important] Étape 7.2 — faim, nourriture, cuisine, poids porté (2026-08-28) : l'étape 7 est complète
> Jauge de faim dans l'en-tête, 18 consommables, viande des animaux, plats à la Cuisine avec potentiel, manger (inventaire : G ou bouton), poids porté avec surcharge. **À juger** : la vitesse de la faim (2 h 30 de jeu actif), le −10 % de stats sous 25, la capacité (un humain Force 5 : 55 — une forge de 80 ne se porte pas, c'est voulu), la lisibilité du poids dans l'en-tête.
> [!important] Étape 7.1 — le camp de base (2026-08-28)
> Une cellule de camp plate (arbres, rochers, filons de surface, coffre de départ avec hache, pioche et lit de paille), l'entrée du donjon (E), retour au camp en sortant. Poser meubles et stations (inventaire : P), murs (M) et portes (O) à la tuile, démonter au clic, coffres (ranger/prendre), dormir sur un lit (Reposé, potentiel, respawn). **À juger** : le camp vide au départ est-il assez lisible ; le rythme (récolter du bois à la hache, scier, poser) ; la mort en donjon qui renvoie au camp. Faim, nourriture, cuisine et poids porté suivent (7.2).
> [!important] Écrans : inventaire, atelier, feuille (2026-08-28)
> Demande du designer (« tu as pu faire tous les menus, l'inventaire ? » — non, tout était en texte). Trois panneaux en Control nodes, l'infobulle exhaustive, la navigation récursive des recettes, desequiper/jeter. **À juger** : la lisibilité des panneaux (police 13, fond sombre), le fait que le jeu continue de tourner derrière un écran ouvert (temps réel d'exploration : un ennemi peut arriver), l'absence de glisser-déposer (liste + boutons seulement).
> [!important] Étape 6.4 — composants et assemblage (2026-08-28) : la boucle de craft est complète
> Pioche → filon → fondre → façonner un composant (Enclume) → assembler à l'Établi une « Dague en fer » avec sa qualité, son vecteur Wu Xing, sa vitesse de manche ; l'objet s'équipe et frappe. **À juger** : l'atelier texte devient long (plates + composants + objets) ; la qualité aléatoire (0,85-1,15) est-elle lisible ; le poids 0,70 de la tête suffit-il à ce que le manche compte.
> [!important] Étape 6.3 — stations et transformations plates (2026-08-28)
> F ouvre l'atelier : les recettes des stations du sac (l'établi de départ, les stations trouvées en coffre). Fondre, scier, tailler, tisser. **À juger** : l'atelier en liste texte (chiffre = fabriquer), le fait de porter une forge dans le sac sans poids porté, les 20 ticks de base.
> [!important] Tables de sculpture abandonnées (2026-08-28)
> Instruction du designer : plus d'éditeur, plus de modèles sculptés, plus d'accès par rang de guilde. Callouts posés sur les trois notes de sculpture et sur celles qui y renvoyaient.
> [!important] Étape 6.2 — récolte en donjon (2026-08-28)
> Filons colorés dans les murs, pioche dans les coffres, clic sur un mur avec la pioche en main : récolte selon la formule de la note (Fer sur pierre : 6 ticks), matériaux empilés dans le sac. **À juger** : la lisibilité des filons (la couleur de la palette suffit-elle ?), la densité (8-16 par étage), le fait que creuser sans outil détruise le matériau.
> [!important] Étape 6 ouverte — matériaux en données (2026-08-28)
> Le designer a relancé sans juger le jalon 5 : l'étape 6 s'ouvre. Premier incrément : les **155 matériaux** des catalogues en données, validés au boot (couleur unique, tags dérivés, Wu Xing). Rien de visible encore ; la récolte en donjon vient ensuite.
> [!important] Brouillard de guerre (2026-08-28)
> Le joueur découvre l'étage avec sa vision (Perception, ligne de vue) ; les tuiles vues restent en grisé, les êtres hors de vue disparaissent. **À juger** : la portée (Perception 5-10 tuiles, est-ce trop court dans des salles de 16 ?), le grisé des tuiles mémorisées, l'absence d'indice pour un ennemi qui s'approche hors de vue (un son ? une ombre ?).
> [!important] Cellule 128×128, réseau maillé (2026-08-28)
> Sur instruction du designer : retour à 128×128, 14-24 salles, chaque salle reliée à ses 3 voisines les plus proches + boucles + impasses longues, virages plus fréquents. **À juger** : la densité (trop de couloirs ?), la longueur d'une expédition sur un étage de 128×128, le temps de trame avec un étage plus grand.
> [!important] Donjon façon Elin / ToME, faces des murs corrigées (2026-08-27, nuit)
> Salles de trois tailles + couloirs sinueux, boucles et impasses (plus de labyrinthe sur trame). Les blocs de mur dessinaient leurs **faces arrière** (d'où les « triangles ») : ce sont maintenant le dessus et les deux faces avant, sans grille. Couloirs de 2 à 3 tuiles et blocs de 2 niveaux (`hauteur_vue`) : en iso, un couloir d'une tuile disparaissait derrière les blocs devant lui. Les êtres hors de la fenêtre de vue ne sont plus redessinés : 5 ms par image dans le donjon (contre 20). **À juger** : la proportion petites/grandes salles, la sinuosité des couloirs, la hauteur des blocs (2 niveaux) ; si les couloirs restent trop cachés, l'alternative est un rendu « en coupe » (murs devant un sol visible dessinés plus bas ou translucides).
> [!important] Cellule 64×64, salles procédurales, murs en blocs (2026-08-27, soir)
> Sur instruction du designer : cellule de 64×64, salles rectangulaires tirées au hasard (façon Elin, 4-8 par étage, 4-9 de côté, 1-3 portes), tous les murs de la fenêtre dessinés en blocs pleins. **À juger** : la taille des salles et la densité du labyrinthe dans 64×64 ; le relief des blocs (3 niveaux de hauteur vue, arête dessinée) ; 16 ms par image en moyenne dans le donjon avec tous les blocs (pire 25 ms), à surveiller.
> [!important] Donjon refait en labyrinthe (2026-08-27)
> Sur instruction du designer : un étage = une cellule de 128×128, labyrinthe + salles, murs destructibles (clic sur un mur adjacent, 10 ticks), deux escaliers par étage, bord en roche. Le dessin du terrain est **fenêtré** autour du joueur (rayon 24 tuiles) : 13 ms par image en moyenne dans le donjon (6 ms en arène), pire 21 ms — au-dessus de la cible de 16,7 ms en pointe, à surveiller (`capture.tscn -- --arene 3`). **À juger** : la lisibilité du labyrinthe en iso (couloirs de 3 tuiles), le coût de creuser (10 ticks / 6 d'endurance : trop bon marché ?), la taille de la cellule pour une expédition (8 à 14 salles par étage).
> [!important] ⭐ Étape 5 — le jalon est atteignable : entrer, combattre, looter, progresser, ressortir (2026-08-27)
> Tab jusqu'au donjon (ou création puis Tab ×3) : descendre par la cage dorée, remonter et sortir par l'entrée verte ; les étages restent dans l'état où on les laisse ; l'écran d'expédition récapitule et une nouvelle expédition enchaîne avec le même personnage. **C'est le jalon « à juger honnêtement avant toute suite »** ([[Ordre de construction]]) — le code s'arrête ici en attendant ce jugement : jouer trois expéditions, remplir la grille qualitative de [[Prototype de combat — spécification]] § 5, et dire si l'étape 6 (matériaux, craft) s'ouvre ou si on itère.
> [!important] Étape 4 codée — progression (2026-08-27)
> Progression par l'usage réelle (courbe, potentiel, 58 compétences en données, stats qui montent par la moitié de l'XP), création de personnage au lancement (race, classe, 30 points, signe), potentiels de base race + classe + astrologie, niveaux dérivés, feuille (C), mort et respawn. **À juger** : l'écran de création texte (R/C/↑↓/+−/←→/Entrée) est-il assez clair ? Le rythme des niveaux en combat (Épée 1 après ~100 dégâts) ? Les talents de race/classe actifs attendent leurs systèmes (ne sont que des tags).
> [!important] Étape 3 codée — loot (2026-08-27)
> Affixes générateurs (36 gabarits, budget de rareté), grille de rareté par étage, effets passifs et stats effectives, coffres dans les salles, butin à la mort, monstres rares (2 %, ×2.5, drop garanti), sac (⇧chiffre pour équiper, R pour ramasser). Gemmes taillées et serties (T, plafond +15), grimoires et manuels lus (L, jet de Lecture, échecs à effet). **À juger** : les noms générés (« Épée de braise (une attaque sur 2 porte Feu) [rare] ») sont-ils lisibles ou trop bavards ? Les coffres (caisses brunes) se voient-ils ?
> [!important] Étape 2 codée — génération de donjon (2026-08-27)
> Tab après les trois arènes : un **donjon « ruine »** généré (12 salles + 8 connecteurs en JSON, graphe façon Daggerfall, 2-3 étages, escalier = E sur la cage dorée, boss au fond). Peuplé par le thème, joué avec le même combat. **À juger à l'œil** : la lisibilité des salles murées de roche, la variété des étages, la densité des créatures. Détail : [[Génération de donjon]], [[Décision — Prefabs de donjon en tuiles]].
> [!important] Étape 1 codée — rig, paperdoll, tooltips, locale (2026-08-27)
> Le combat est le vrai projet (même scène, `scenes/demo/main.tscn`) ; s'y ajoutent **`creature.tscn`**, la scène unique de tout être ([[Squelette modulaire et points d'attache]] : rigs JSON des 4 templates, équipement visible par slot, teinte par matériau, animation par pivots — en rectangles procéduraux, sans asset), les **tooltips contextuels** en données ([[Tooltips contextuels]]), `locale/en.csv` pour l'interface. **À juger à l'œil** : la lisibilité des silhouettes (humanoïde 14 segments, loup, aigle, scorpion), l'équipement visible, la frappe animée — capture `capture.tscn --arene 2`.
> **Réglage du 2026-08-27** (« propose un jeu de valeurs, on ajustera plus tard ») : engendrement +0.45, swap 3 ticks — voir [[Jauge de chaîne Wu Xing]]. Le swap est désormais mixte ✓ ; l'écart des deux voies reste hors cible (rotation entre −40 % et +30 % selon la construction comparée) : le critère est à préciser, pas les bonus. **Le designer a choisi de passer à l'étape 1** sans le « oui » formel sur le combat — le jugement d'œil reste dû, sur le vrai projet.
> 9. *Critère de perf É0* ([[Décision — Budgets et critères de performance tactiques]] : 32×32 + 10 entités, 60 fps) : mesuré par `capture.tscn --frames 120` avec `--disable-vsync` sur la machine de développement — **3,5 ms par image en moyenne, 12,5 ms au pire** (avant optimisation : 44 ms, le terrain était redessiné à chaque image ; il est désormais une couche statique, les tuiles hautes devant une entité sont redessinées par-dessus pour garder l'occultation). Reste à mesurer sur la machine de référence (PC 2020, GPU intégré).
> 8. *Rendu vérifié par capture automatique* (`scenes/tests/capture.tscn`, fenêtré) : les trois arènes se dessinent, murs et estrades lisibles, panneaux de texte à gauche/droite. Le panneau gauche recouvre le coin nord-ouest de la carte — à juger (le déplacer, ou déplacer la vue au clic milieu).
> 5. *La jauge de chaîne* (pastilles sous le personnage + ligne « chaîne : Métal → Métal ») : lit-on d'un coup d'œil où l'on en est et ce que le prochain coup fera ? Le swap d'arme (4 ticks pour +0.35) donne-t-il envie ?
>
> [!note] Démo 0 (2026-08-26, matin)
> `godot/scenes/demo/main.tscn` : grille iso 24×24 générée (hauteurs 0-20, continentalité + crête ridged), tri de profondeur, déplacement au clic par A* qui applique les **coûts de pente** de [[Hauteur de terrain ±10]] (3/5/8/∞, descente 2), et l'**horloge à ticks** de [[Boucle de tick]] : 10 ticks/s en exploration, **0 tick sans action** en combat, chaque entité agit quand son compteur est le plus bas. Un loup chasse et mord (aggro à 6 tuiles). Aucun asset — tout est polygones. Validée en headless (Godot 4.6.3). **À juger à l'œil : ouvrir `godot/` dans l'éditeur et lancer.**

> [!success] Bloquant levé le 2026-08-26
> Le catalogue [[Modules]] est **transcrit dans son schéma** — `cout_ticks` sur les 61 entrées, durées en ticks, économies séparées (mana pour les grimoires, **endurance** pour les manuels). Les 61 JSON sont écrits dans `godot/data/modules/`. Audit : [[Décision — Transcription du catalogue de modules]].

## 1. ✅ Validé — les 8 décisions post-pivot (2026-08-26, sur délégation)

- [x] [[Décision — Structure de données de la grille]] · [[Décision — Budgets et critères de performance tactiques]] · [[Décision — Sculpture en pixel art]] · [[Décision — Prefabs de donjon en tuiles]] · [[Décision — Pièces en 2D]] · [[Décision — Altitude sur 21 niveaux]] · [[Décision — Minerais et strates après le pivot]] · [[Décision — Minimap en 2D]]

## 2. Le document du prototype de combat (étape 0)

[[Ordre de construction]] : *« Prototype de combat isolé (**document séparé**) — le combat est-il bon ? Rien ne démarre avant un oui. »*
- [x] **Les sept trous du combat sont tranchés** (2026-08-26) : [[Décision — Multi-ennemis et jauge]], [[Décision — Vocabulaire d'attaque des créatures]], [[Décision — Fuite et désengagement]], [[Décision — Chaîne côté ennemis]], [[Décision — Boucliers]], [[Décision — Projectiles]], [[Décision — Esquive active]].
- [x] **Le document est rédigé** : [[Prototype de combat — spécification]] — périmètre, contenu exact, 12 jalons d'implémentation, critère de « oui » mesurable et qualitatif.

## 3. ✅ Défauts fixés pour toutes les questions de playtest

Chacune porte désormais une **valeur chiffrée implémentable** — le code ne se pose aucune question, le playtest ajuste ([[Carte — Ouvert]]) :
- [x] [[Ouvert — Axe des niveaux de recette]] (stabilité du jet) · [[Ouvert — Compensation de l'arme mixte]] (choix du segment) · [[Ouvert — Répartitions Arcane Espace Corruption]] (vecteurs A.4.6) · [[Ouvert — Fourchettes des gemmes]] (A.12 + 36 gabarits) · [[Ouvert — Saisons]] (non incluses)
- [x] [[Ouvert — Taille des salles de donjon]] (24 prefabs) · [[Ouvert — Réapparition d'un donjon]] (règle des foyers) · [[Ouvert — Tiers de monstres rares]] (un tier) · [[Ouvert — Interprétation dureté et qualité]] (clos)

## 4. Contenu à produire (données — nécessaire par étape, pas au jour 1)

- [x] **5 modules du domaine Métal** — au catalogue [[Modules]] (2026-08-26).
- [x] **Catalogue des actions de créatures** : 24 actions + 2 règles, affectations pour les 19 races animales ([[Actions des créatures]], 2026-08-26).
- [x] **Onyx** ajouté au catalogue des gemmes et à la palette (2026-08-26).
- [x] **Recettes de composants** : matrice complète bases/exotiques/sources ([[Recettes de composants]], 2026-08-26).
- [x] **Affinités de cuisine** : table complète, le Feu vient de la cuisson et le Métal du sel ([[Décision — Affinités de cuisine]], 2026-08-26).
- [x] **Surcharges Wu Xing** : les 154 matériaux passés en revue, table complète ([[Décision — Surcharges Wu Xing des matériaux]], 2026-08-26).
- [x] **Pools de noms** : les 9 cultures restantes écrites ([[Pools de noms des cultures]], 2026-08-26).
- [ ] Traductions en/ja/zh — les clés `tr()` existent dès le jour 1, les textes peuvent suivre ([[Localisation]]).

## 4 bis. Annexe H — élevage, génétique et collection *(intégrée le 2026-08-26)*

- [x] **15 notes** : mécanismes ([[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]]), contenu ([[Catalogue des groupes d'élevage]], vivarium ×3), moteur ([[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]]), et le socle des êtres ([[Blocs de l'être]], [[Apparence — données et équipement]], [[Rôles de l'être]]).
- [x] **Catalogue `species/`** squeletté avec son template ([[Décision — Pipeline de contenu]]).
- [x] **Saisons activées** à l'étape 10 — [[Décision — Saisons activées à l'étape 10]] renverse [[Ouvert — Saisons]].
- [ ] **Assets d'élevage** (étape 10) : silhouettes 13×13 des 32 espèces d'insectes, 20 motifs procéduraux, écran de registre.
- [ ] Fiches `species/` des 6 groupes recommandés au lancement (un par famille).

## 4 ter. Les trois axes et les talents *(décidé le 2026-08-26)*

- [x] [[Les trois axes — race, classe, fonction]], [[Talents de race]], [[Talents de classe]], [[Fonctions]], [[Ouvert — Changer de personnage]] + 5ᵉ contrainte permanente.
- [x] **19 classes nommées et dotées d'un talent** ([[Classes]], [[Talents de classe]]) — 8 visibles en français évocateur, 11 cachées dont 2 technologiques.
- [x] **Bestiaire restructuré** : [[Créatures]] = 19 races animales, [[Profils de PNJ]] = combinaisons tirées.
- [ ] **Modules signature** de chaque classe cachée (au-delà du talent) — contenu, étape 4+.
- [ ] **Fiches de races cachées** : Vampire, Spectre, Lycanthrope (`data/races/`) — étape 4+.
- [ ] **Pools de classes par fonction** pour la génération de PNJ ([[Talents de classe]] : classes cachées ≈ 2 %) — étape 9.

## 5. Assets à produire (aucun n'existe)

- [ ] **Étape 0-1 :** une silhouette paperdoll + quelques pièces d'équipement visibles ; les teintes des cinq éléments (jauge, effets — [[Direction artistique]]) ; l'UI de lisibilité (timeline, prévisualisations, journal — c'est LE game feel).
- [ ] **Étape 1 :** bibliothèque du **rig humanoïde 14 segments** ([[Squelette modulaire et points d'attache]]) ≈ **92 sprites** (12 têtes ×3 vues, torses, bras haut/bas, mains, jambes haut/bas, pieds) + **40 sprites d'armure** (5 constructions × 8 segments) = **≈ 130 sprites pour tous les humains du jeu**. Puis quadrupède/volant/amorphe.
- [ ] **Étape 1 :** la table `data/rigs/humanoide.json` — ordre de calque et décalages d'ancrage pour 5 orientations (3 obtenues par miroir).
- [ ] **Étape 2 :** premiers prefabs de donjon (2-3 salles + connecteurs suffisent pour valider le pipeline).
- [ ] Police UI à couverture CJK (type Noto Sans CJK) testée dans les 4 langues ([[Localisation]]).

## 6. Chantier technique (le squelette existe, le code non)

- [x] **Pipeline de contenu décidé et squeletté** ([[Décision — Pipeline de contenu]]) : `godot/data/` contient les 24 catalogues avec leurs `_template.json` et son README — ajouter du contenu = ajouter un fichier JSON.

- [x] Projet Godot 4.6 : autoloads **GameData/EventBus/TickManager** en place ([[Décisions d'architecture]], [[Simulation à ticks]]), validation de schémas au boot (bloquante en debug, F5 recharge), `tr()` sur toute chaîne affichée (`locale/fr.csv`, `en.csv`) — 2026-08-26.
- [x] Les [[Contraintes permanentes]] tiennent dès la première ligne : `Simulation` autoritaire et `main.gd` client dans le même processus mais pas le même code ; aucune logique dans `_process` (le seul `delta` est converti en ticks par le TickManager) ; une horloge par combat ; le joueur est une fiche `creatures/aventurier.json` comme les autres.
- [ ] Critère de perf avant chaque étape ([[Ordre de vérification]]).

## 7. Gouvernance du design

- [x] Le coffre `docs/` est la **source de vérité** ; `archive/SENSEN_GDD.md` est figé (il contient encore le texte voxel — c'est voulu, c'est une archive).
- [ ] À chaque décision prise (propositions, playtest) : mettre à jour la note concernée, retirer la mention « proposé », passer le `statut` à `décidé`.

## Le chemin critique, en une ligne

**~~Valider P2 + P7~~ ✅ → ~~écrire le document du prototype de combat~~ ✅ → ~~produire les 5 modules Métal + le catalogue d'actions~~ ✅ → ~~les 12 jalons de l'étape 0~~ ✅ → **juger le combat** ([[Prototype de combat — spécification]] § 5 : 10 combats par arène, critères mesurables et grille qualitative) → itérer sur les chiffres (JSON + F5) → étape 1 → juger le combat. Tout le reste peut suivre la cadence des 11 étapes.

## Liens
- **Dépend de** : [[Ordre de construction]], [[Héritage voxel — audit]], [[Trous connus du combat]]
- **Alimente** : [[Ordre de vérification]], [[Carte — Ouvert]]
- **Voir aussi** : [[Contraintes permanentes]], [[Décisions fondatrices]], [[Arborescence du projet]]
