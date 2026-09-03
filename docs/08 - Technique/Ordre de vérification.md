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

> [!success] Codé le 2026-09-02 — le robot sait collecter sans mourir, et rend son sac
> Deux drapeaux de plus au parcours : **`--invincible`** (PV, endurance et mana rendus à chaque image) pour mesurer ce que le jeu **donne** plutôt que si l'on survit, et **`--inventaire <chemin>`** qui écrit le sac complet en JSON à la fin — une entrée par objet avec son nom rendu, son type, son matériau, son espèce, sa qualité, sa rareté, son poids, son vecteur Wu Xing, ses affixes et ses composants. Six étages, 97 objets : c'est ce qui a montré que 41 % du butin est une fiole non identifiée et que les boucliers ne sont pas assemblés.


> [!bug] Corrigé le 2026-09-02 — la v0.3.0-alpha ne se lançait pas, et la suite était verte
> Le designer : « le jeu ne se lance pas, même l'alpha 0.3.0 sur le repo » — puis « je crois que le problème est sur `main.gd` ». Exact. En ajoutant le parchemin à la hotbar, mon remplacement de texte a visé la **mauvaise occurrence** de `"objet":` : le cas s'est inséré au milieu du `match` de `hotbar_entrees` au lieu de celui de la sélection, et `main.gd` ne compilait plus. **Parse Error dès le chargement, jeu mort au lancement.**
> **Pourquoi rien ne l'a vu** : la suite de tests ne charge **jamais** `scenes/demo/*.gd`. Elle instancie la simulation, pas les écrans. Elle est donc restée verte sur un jeu qui ne démarrait pas, et j'ai publié une release à partir de là.
> **Le garde-fou** : `tools/verif_scripts.py` ouvre la scène principale dans Godot et **refuse** toute *Parse Error*, *Compilation failed* ou *SCRIPT ERROR*. Il tourne avec les autres outils avant chaque commit et chaque publication. Une suite verte ne prouvait pas que le jeu démarre ; maintenant si.


> [!success] Codé le 2026-09-02 — les scènes de monde se montrent en **GIF** (designer)
> « refais toutes les captures et rajoutes-en, et fais-en des GIF plutôt que de simples captures ». Une image fixe ne montre ni l'horloge qui tourne, ni le combat qui se résout, ni la pluie. `capture.tscn` sait désormais rendre une **suite d'images** : `--gif N` (nombre de prises), `--gif-pas P` (images de rendu entre deux), `--gif-ticks T` (ticks de simulation avancés entre deux) et `--gif-marcher N` (pas du joueur entre deux) — c'est ce dernier qui fait vraiment le film, sans mouvement un GIF n'est qu'une image répétée. Godot ne sait pas écrire de GIF : `tools/monter_gif.py` monte les PNG, les met à l'échelle et quantifie la palette. Le README anime le camp, le village, le donjon, le combat et l'orage ; les écrans d'interface restent des images fixes, où rien ne bouge.


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
> **Ce qu'il a trouvé du premier coup** : six notes nommaient `data/reserved_colors.json`, renommé en `palette_materiaux.json` ; deux autres citaient `ore_bands.json` et `strata.json`, fondus dans `minerais_par_etage.json` ; une clé `loot_rules.bases_consommables` qui n'existe pas ; et surtout une note qui décrivait les artefacts comme du contenu écrit à la main dans un dossier jamais créé, **alors que le code les génère** depuis longtemps.
> **Le principe qui le rend utilisable** : il ne juge que ce qui est vérifiable sans ambiguïté — chemins, clés de catalogue connu, fonctions en snake_case entre accents graves. La prose française est laissée tranquille. Un outil qui crie au loup est un outil qu'on désactive, et son premier jet donnait dix-neuf faux positifs sur la seule forme `combat_rules.json`, où « json » était pris pour une clé.

## Liens
- **Dépend de** : [[Optimisation — principes]], [[Budgets de performance]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Contraintes permanentes]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Réseau et sauvegarde — performance]], [[LOD de simulation]]
