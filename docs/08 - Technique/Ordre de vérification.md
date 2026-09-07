---
aliases: ["G.8", "Annexe G.8", "Ordre de vérification", "Critères de perf par étape"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les critères voxel d'origine (mutation de bloc, « façade 64 blocs 4px meshée < 4 ms ») et l'ancien ordre D.3 sont retirés — archivés dans le GDD source. Les critères ci-dessous suivent les 11 étapes tactiques ; chiffres décidés en [[Décision — Budgets et critères de performance tactiques]].

Un critère de performance à valider avant de passer à l'étape suivante. **Un critère raté = on optimise AVANT d'empiler le système suivant.**

**Le principe (conservé de G.8) :** chaque étape de [[Ordre de construction]] a son critère de perf AVANT de passer à la suivante, sur machine moyenne cible.

**Critères par étape ([[Décision — Budgets et critères de performance tactiques]]) :**

```
É0  Prototype de combat : grille 32×32 + 10 entités, 60 fps,
    prévisualisations et timeline sans latence perceptible.
É1  Paperdoll : 50 créatures en billboards composés < 4 ms de rendu.
É2  Donjon : étage généré < 100 ms, transition < 250 ms.
É3  Loot : génération d'un objet à affixes < 1 ms.
É4  Progression : recalcul complet des stats d'un personnage < 0.5 ms
    (le résolveur E.4 est appelé partout).
É8  Monde : streaming en déplacement rapide, aucune frame > 16 ms ;
    voyage rapide + chargement de cellule < 1 s.
É9  100 PNJ en niveau logique ≈ coût de 3 PNJ pleins (cf. E.18).
É11 2 joueurs LAN : mutation visible < 100 ms chez l'autre.
```

**Principe parallèle ([[Contraintes permanentes]]) :** *une brique à la fois, chacune avec un critère de sortie formulé AVANT de commencer.*

> [!success] Codé le 2026-08-31 — les critères mesurables sans écran ont un test
> `test_budgets` (suite) : É2 étage < 100 ms, É3 objet à affixes < 1 ms, É4 recalcul de stats < 0,5 ms, tick de simulation < 8 ms. Restent à l'œil ou au profil : les critères de rendu (fps, frames > 16 ms — `capture.tscn --disable-vsync` mesure déjà le coût moyen d'image) et le réseau (É11). La cellule de surface est mesurée dans `test_surface` (< 250 ms, budget de 32 ms différé).

> [!note] 2026-09-06 — le noyau C++ entre dans l'ordre de vérification
> Quand `cpp/` change : `tools/build_cpp.ps1` (la DLL sort dans `godot/addons/sensen_grille/bin/`), `--import`, puis `-- --seul test_noyau_cpp` — le test compare le noyau et le GDScript paire par paire (chemins, atteignables, lignes et champ de vue, coûts, sur l'arène et sur une fenêtre de monde avec eau, portes, dangers, neige, gel) et vérifie les miroirs (`occ`, `danger_a`, `eau_a`, `frott_a`). La suite complète tourne avec le noyau chargé ; sans la DLL, tout se calcule en GDScript et le test le dit ([[Modules de la simulation et le C++]]).

> [!success] Codé le 2026-09-02 — le robot sait collecter sans mourir, et rend son sac
> Deux drapeaux de plus au parcours : **`--invincible`** (PV, endurance et mana rendus à chaque image) pour mesurer ce que le jeu **donne** plutôt que si l'on survit, et **`--inventaire <chemin>`** qui écrit le sac complet en JSON à la fin — une entrée par objet avec son nom rendu, son type, son matériau, son espèce, sa qualité, sa rareté, son poids, son vecteur Wu Xing, ses affixes et ses composants. Six étages, 97 objets : c'est ce qui a montré que 41 % du butin est une fiole non identifiée et que les boucliers ne sont pas assemblés.


> [!bug] Corrigé le 2026-09-02 — la v0.3.0-alpha ne se lançait pas, et la suite était verte
> Le designer : « le jeu ne se lance pas, même l'alpha 0.3.0 sur le repo » — puis « je crois que le problème est sur `main.gd` ». Exact. En ajoutant le parchemin à la hotbar, mon remplacement de texte a visé la **mauvaise occurrence** de `"objet":` : le cas s'est inséré au milieu du `match` de `hotbar_entrees` au lieu de celui de la sélection, et `main.gd` ne compilait plus. **Parse Error dès le chargement, jeu mort au lancement.**
> **Pourquoi rien ne l'a vu** : la suite de tests ne charge **jamais** `scenes/demo/*.gd`. Elle instancie la simulation, pas les écrans. Elle est donc restée verte sur un jeu qui ne démarrait pas, et j'ai publié une release à partir de là.
> **Le garde-fou** : `tools/verif_scripts.py` ouvre la scène principale dans Godot et **refuse** toute *Parse Error*, *Compilation failed* ou *SCRIPT ERROR*. Il tourne avec les autres outils avant chaque commit et chaque publication. Une suite verte ne prouvait pas que le jeu démarre ; maintenant si.


> [!success] Codé le 2026-09-02 — les scènes de monde se montrent en **GIF** (designer)
> « refais toutes les captures et rajoutes-en, et fais-en des GIF plutôt que de simples captures ». Une image fixe ne montre ni l'horloge qui tourne, ni le combat qui se résout, ni la pluie. `capture.tscn` sait désormais rendre une **suite d'images** : `--gif N` (nombre de prises), `--gif-pas P` (images de rendu entre deux), `--gif-ticks T` (ticks de simulation avancés entre deux) et `--gif-marcher N` (pas du joueur entre deux) — c'est ce dernier qui fait vraiment le film, sans mouvement un GIF n'est qu'une image répétée. Godot ne sait pas écrire de GIF : `tools/monter_gif.py` monte les PNG, les met à l'échelle et quantifie la palette. Le README anime le camp, le village, le donjon, le combat et l'orage ; les écrans d'interface restent des images fixes, où rien ne bouge.


> [!success] 2026-09-04, 18 h 30 — toutes les images du README en GIF, scènes jouées (designer)
> « Refais toutes les captures d'écran du README en GIF avec simulation complète pour qu'on voie bien ce qui se passe. » Un écran ouvert ne bouge pas tout seul : `capture.tscn` reçoit `--gif-action` — **defiler** (la sélection de la liste avance d'une ligne à chaque prise, le détail suit : inventaire, atelier, commerce, capacités, titre, parties), **composer** (les pièces de `--sequence` se posent une à une sur la grille), **carte** (la carte glisse), **monde** (une autre graine à chaque prise, l'aperçu change), **creation** (les volets se succèdent), **semaine** (une semaine de la grande base passe entre deux prises : les chaumières se bâtissent). Les scènes de monde gardent `--gif-marcher` et `--gif-ticks`. Seize GIF, une commande chacun (`scratchpad/gifs.sh` du jour, reproduite dans le README), montés à 900 px par `tools/monter_gif.py`.

> [!success] Codé le 2026-09-02 — deux sondes de plus, parce que les tests ne voient pas tout
> `scenes/tests/sonde_monde.tscn` **compte ce que la carte montre** — donjons de corruption, gouffres, régions, part des terres. C'est elle qui a chiffré les « beaucoup beaucoup trop » de donjons (319 pour un carré de 81 cellules) et démasqué le donjon de départ de niveau 121.
> `scenes/tests/sonde_journal.tscn` vérifie que les lignes répétées du journal se cumulent. La suite ne charge jamais les scripts d'écran : elle ouvre donc la scène du jeu et parle à son journal.
> Les deux tournent en une poignée de secondes et disent des **chiffres**, là où une capture ne dit qu'une impression.


> [!info] Ajout du 2026-09-03 — **la sonde des écrans**
> `Godot --headless --path godot res://scenes/tests/sonde_ecrans.tscn` — huit écrans, quatre tailles de fenêtre, et l'échec nomme le fautif. À passer avec les autres avant de pousser dès qu'un écran change de mise en page : c'est la seule vérification qui rende durable la règle « rien n'est coupé », qu'une capture regardée une fois ne fait que constater.

> [!info] Ajout du 2026-09-03 — **la sonde de la faune**
> `Godot --headless --path godot res://scenes/tests/sonde_faune.tscn` — chaque bête s'instancie (action, squelette, dépouille) et chaque biome annonce sa part de paisible, jour et nuit. À passer dès qu'on touche au catalogue des créatures ou aux pools de biome : une action mal orthographiée dans une fiche ne se voit autrement qu'en jeu, au moment où la bête apparaît.

> [!info] Ajout du 2026-09-03 — **la sonde de la mine**
> `Godot --headless --path godot res://scenes/tests/sonde_mine.tscn` — le puits refuse hors claim, l'étage est plein et sans habitant, la roche durcit en descendant, et la galerie creusée est encore là après un aller-retour au jour. C'est elle qui a trouvé que la palette de mur s'inversait entre les étages 2 et 3.

> [!info] Ajout du 2026-09-03 — **la sonde de l'espèce**
> `Godot --headless --path godot res://scenes/tests/sonde_espece.tscn` — la bête voyage-t-elle de la dépouille jusqu'à la matière ? Elle tabule la dureté de l'os pour sept espèces et vérifie sur pied qu'une matière brute tirée d'un corps porte bien son espèce. À passer dès qu'on touche au dépeçage, aux recettes ou à `materiau_espece`.

> [!info] Ajout du 2026-09-03 — **les sondes de l'IA et du jet**
> `res://scenes/tests/sonde_ia.tscn` : le roam mène quelque part (éloignement mesuré après cent tours), l'aggro vise qui a frappé, l'alerte réveille les voisins, et le temps fait tout retomber. `res://scenes/tests/sonde_jet.tscn` : la pile diminue, l'objet lancé retombe au sol avec sa matière, la main se vide. À passer dès qu'on touche aux profils d'IA ou à la résolution d'attaque.

> [!info] Ajout du 2026-09-03 — **la documentation promet-elle des choses que le code n'a pas ?**
> `python tools/verif_doc_code.py` — `check_vault.py` vérifie que les **liens entre notes** tiennent ; personne ne vérifiait que les **identifiants cités dans les notes** existent. Une note peut nommer un fichier, une clé de configuration ou une fonction disparus depuis six semaines, et rien ne le dit. C'est la rouille la plus sournoise d'un coffre qui fait autorité : le jour où on le relit pour retrouver comment marche un système, il ment.
> **Ce qu'il a trouvé du premier coup** : six notes nommaient data/reserved_colors.json (cité ici en texte simple : il n'existe plus), renommé en `palette_materiaux.json` ; deux autres citaient ore_bands.json et strata.json, fondus dans `minerais_par_etage.json` ; une clé loot_rules.bases_consommables (citée ici en texte simple : elle n'existe pas) ; et surtout une note qui décrivait les artefacts comme du contenu écrit à la main dans un dossier jamais créé, **alors que le code les génère** depuis longtemps.
> **Le principe qui le rend utilisable** : il ne juge que ce qui est vérifiable sans ambiguïté — chemins, clés de catalogue connu, fonctions en snake_case entre accents graves. La prose française est laissée tranquille. Un outil qui crie au loup est un outil qu'on désactive, et son premier jet donnait dix-neuf faux positifs sur la seule forme `combat_rules.json`, où « json » était pris pour une clé.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Budgets de performance]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Contraintes permanentes]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Réseau et sauvegarde — performance]], [[LOD de simulation]]

> [!bug] 2026-09-04, 23 h 15 — cinq tests définis que la suite ne lançait jamais, et un « --seul » qui ne prouvait rien
> La suite `test_combat.tscn` lance ses tests par une **liste écrite à la main** (`_lancer("test_…")`), pas par découverte. Quatre tests écrits le soir même (`test_bete_engage_sur_son_horloge`, `test_cri_de_ralliement`, `test_routine_civile`, `test_proie_n_engage_pas`) et un ancien (`test_brouillard`, 27 août) n'y figuraient pas ; `--seul <fragment>` filtre cette même liste, si bien que « --seul cri_de_ralliement » affichait « TESTS : tout passe » en ne jouant **que** la vérification des données. Vu en comparant `func test_` (177) et `_lancer(` (172). Désormais `_verifier_tous_lances` compte comme un échec tout `test_*` défini et absent de la liste, et les cinq sont lancés. Leçon d'outillage : un « ok 1 » après un `--seul` est le signe que rien n'a tourné.

> [!success] Codé le 2026-09-07, 14 h — la pré-publication ne dépend plus d'un jeton sur le poste (designer : « fais tout ce qu'il faut pour pouvoir publier sur github, je t'autorise tout »)
> **Ce qui est vrai aujourd'hui** : les 37 annonces existent, toutes en pré-version et toutes avec leur zip, jusqu'à [v0.5.6-alpha](https://github.com/devmarcpro/sensen/releases/tag/v0.5.6-alpha) publiée ce matin. La publication n'est donc pas cassée. Ce qui est fragile, c'est **d'où** elle part : `gh auth status` sur ce poste répond « not logged into any GitHub hosts », et la lecture du mot de passe du gestionnaire d'identifiants de Git y est refusée. `git push` marche — il a son propre chemin —, `gh release create` non. Une passe de boucle peut donc pousser une étiquette et ne pas pouvoir l'annoncer.
> **Le remède, `.github/workflows/prepublication.yml`** : Actions reçoit son propre jeton (`secrets.GITHUB_TOKEN`), donc c'est lui qui publie, et pousser l'étiquette suffit. **workflow_dispatch** avec le nom d'une étiquette rattrape celles déjà poussées.
> - **Le corps de l'annonce est le message de l'étiquette annotée** — `git tag -a v0.5.7-alpha -m "…"`. Une étiquette qui porte *alpha*, *beta* ou *rc* part en **pré-version** ; les autres en version courante.
> - **« Une release sans binaire n'est pas une release »** ([[Prompt de la boucle]]) : l'exécutable est **exporté dans l'action**, depuis l'étiquette, avant l'annonce — Godot et ses gabarits téléchargés, `--import` puis `--export-release "Windows Desktop"`. Si l'export ne rend pas d'exécutable, ou si la DLL du noyau ne l'accompagne pas, **rien n'est publié**. Le noyau C++ n'est pas rebâti : la DLL versionnée est dans le dépôt, à côté du code qui l'a produite.
> - **Idempotent** : si l'annonce existe déjà, l'action se contente de lui joindre le binaire (`--clobber`). On peut donc rejouer la main sans rien casser, et l'action ne marche pas sur les pieds d'une publication faite à la main.
> - **Ce qu'il reste à faire au designer, une fois** : vérifier qu'Actions est activé sur le dépôt (Settings → Actions → Allow all actions) et que son jeton a le droit d'écrire (Settings → Actions → General → Workflow permissions → Read and write). Sans cela l'action tourne et échoue sur `gh release create` — et la publication à la main reste le chemin.
> - **Éprouvé sur la v0.5.7-alpha** : l'étiquette poussée a déclenché l'action, qui a téléchargé Godot et ses gabarits, exporté l'exécutable et publié la pré-version avec son zip — du premier coup, sans rien demander au designer (Actions avait déjà le droit d'écrire). **Un défaut, corrigé dans la foulée** : le corps publié était le message du dernier commit et non l'annonce de l'étiquette. `actions/checkout` avait posé une étiquette *légère*, dont `%(contents)` est vide, et le repli s'était déclenché sans bruit. L'action refetche donc l'étiquette explicitement (`git fetch origin refs/tags/X:refs/tags/X`, puis `git for-each-ref`), et **remet le corps d'une annonce qui existe déjà** au lieu de le laisser périmé — c'est ce qui a permis de réparer la v0.5.7-alpha sans la republier à la main.
> - **Et une leçon payée comptant : ne pas resupprimer une étiquette publiée.** Pour rejouer l'action avec le correctif ci-dessus, j'ai supprimé puis repoussé `v0.5.7-alpha`. Or **supprimer l'étiquette d'une annonce publiée la fait retomber en brouillon** chez GitHub : l'action l'a bien retrouvée (elle est authentifiée), lui a remis son corps et son binaire, et s'est déclarée verte — mais l'annonce était devenue invisible du dehors. L'action **republie** donc explicitement (`gh release edit --draft=false --prerelease=…`) à chaque passage. La bonne façon de rejouer une publication reste **workflow_dispatch** depuis l'onglet Actions, qui prend toujours l'action de la branche par défaut, et non un aller-retour sur l'étiquette.

> [!success] Codé le 2026-09-07, 16 h — `tools/verif_reglages.py` : un réglage lu que rien n'écrit
> Les trois défauts de la matinée (le trésor des royaumes, la diplomatie gelée, les routes qui refusaient des hostiles qui n'existaient pas) sont **le même défaut** : *une règle qui lit un état que rien n'écrit*. Elle ne casse rien, ne lève aucune erreur, ne rougit dans aucun test — elle retombe sur son défaut, et la branche qui en dépend ne s'ouvre jamais. Je les ai trouvés à l'œil, en lisant une sortie de sonde. Il fallait un outil.
> **Ce qu'il fait** : il relève tout littéral que le code **lit** (`.get("x"`, `.has("x")`, `["x"]`), tout littéral que le code **écrit** (`"x":`, `d["x"] =`, `.x =`), et toutes les **chaînes des données** (clés *et* valeurs — un identifiant est souvent une valeur, dans une liste d'emplacements ou de tags). Ce qui est lu sans être ni écrit ni présent dans les données est signalé : la lecture retombe toujours sur son défaut.
> **Ce qu'il a trouvé du premier coup** — quatre nombres de jeu qui ne vivaient qu'en **défaut de code**, contre la règle « rien de chiffré dans le code » :
> - `corruption.donjons.grappes_par_region` et `rayon_grappe`. Le `_doc` du bloc les **nomme explicitement** — « exprimée en GRAPPES PAR RÉGION, pas en pourcentage à plat », le réglage que le designer avait demandé le 2026-09-02 en disant « beaucoup beaucoup trop » — et ni l'une ni l'autre n'était dans le JSON : la densité des donjons tournait sur `2` et `1`, écrits dans `monde.gd`.
> - `cycle.discretion_nuit` (4 niveaux de discrétion gagnés la nuit) et `styles.sprites.px_par_unite` (8).
> Les quatre sont posés en données **à la valeur qu'ils avaient**, pour ne rien changer au jeu : ce qui change, c'est qu'on peut désormais les régler.
> **Le reste est un gel assumé** (`tools/verif_reglages_baseline.txt`), un par un : `meteo_locale`, `ecaille_choix` et `statue_mult` sont des **surcharges facultatives** qu'aucune donnée n'a besoin de porter ; `humeur_min` est une condition d'événement offerte mais qu'aucun événement n'utilise ; `race_dominante` est le terme mort de la diplomatie, gardé pour le jour où une race non humaine reviendra ; `__alt__` et `sim` sont des marqueurs internes.

> [!bug] Trouvé et corrigé le 2026-09-07, 16 h 45 — l'autre sens : une donnée réglée que le code ne lit jamais
> L'outil du matin cherche un réglage **lu** que rien n'écrit. Retourné, il cherche un réglage **écrit** que rien ne lit — et il en sort 247 candidats sur les fichiers de configuration. La plupart sont du bruit (une clé lue par une variable, une table d'identifiants), mais l'un d'eux touche une demande du designer de la veille.
> **`styles.brouillard.toit_memorise`** : le `_doc` du bloc promet que « les toits s'assombrissent de `toit_memorise` / `toit_jamais_vu` ». `toit_jamais_vu` est bien lu et passé aux deux passes de dessin. `toit_memorise`, lui, n'est lu **nulle part** — et les **deux** implémentations, le GDScript et le C++, écrivent `darkened(0.55)` **en dur**. La valeur en donnée vaut justement 0,55 : rien n'était visiblement cassé, mais le réglage ne réglait rien. Il est désormais lu et passé en paramètre (`sombre_memorise`) aux deux chemins ; la DLL du noyau est rebâtie et versionnée avec le code qui l'a produite.
> **Le test le prouve, et il fallait le construire exprès** : la première version de l'assertion échouait, parce que dans la scène du village le joueur voit tous les toits — la branche « mémorisé, hors de vue » ne s'ouvrait jamais. C'est d'ailleurs pour cela que la valeur en dur n'avait jamais été remarquée. Avec une vue vide et `tout_vu` faux, tout ce qui est découvert y tombe : `toit_memorise` à 0,0 et à 0,9 rendent bien deux jeux de couleurs différents, et le noyau suit le GDScript.
> **Ce que le balayage a trouvé d'autre**, et que je laisse en l'état après lecture : `faim.ticks_par_palier` (la famine tourne sur `periode_zero`, ce reste ne sert plus), `ia.ticks_entre_decisions`, `engagement.lumiere_rayon`, `corruption.donjons.rayon_region`, `compagnons.statut_resurrection`, `elevage.age_adulte_semaines`, `astrologie.relation_trine` et `relation_opposition`, `material_categories.*.harvest_skill` et `station_transform`. Aucun n'a de jumeau écrit en dur qui divergerait — ce sont des réglages **prévus et pas encore branchés**, pas des bugs. Ils valent une passe à eux seuls : ou bien on branche la règle qu'ils annoncent, ou bien on les retire pour que les données cessent de promettre ce que le jeu ne fait pas.

> [!bug] Trouvé et corrigé le 2026-09-07, 20 h — deux objets ont porté le même identifiant
> Ajouter cent objets de contenu (les plantes, les aliments) a fait rougir `test_assemblage`, qui n'a rien à voir avec l'agriculture : une lame façonnée devenait la garde façonnée deux crans plus tard, et la dague ne s'assemblait plus. **Ce n'était pas le contenu, c'était un défaut latent qu'il a réveillé.**
> L'identifiant d'un objet s'écrivait `"%s#%d_%d" % [base, profondeur, _n + rng.randi() % 1000]` — un compteur **plus** un aléa, dans un seul nombre. Deux objets dont le compteur diffère de 2 et le tirage de −2 portent alors le **même uid** ; le second écrase le premier dans `sim.items`, et le sac contient deux fois le même identifiant. Le contenu neuf a seulement déplacé `sim.objets.size()`, qui sert de graine au tirage, jusqu'à faire tomber la collision.
> Le compteur et l'aléa sont désormais **deux champs** (`base#profondeur_n_alea`) : le compteur est monotone, l'unicité est structurelle. Et le test compte maintenant les identifiants **distincts**, pas seulement les objets — la vérification qui aurait vu le défaut.
> **La leçon** : quand un test sans rapport rougit après un ajout de contenu, c'est souvent qu'on a déplacé une graine. Chercher ce que le contenu a *décalé* avant de chercher ce qu'il a *cassé*.
