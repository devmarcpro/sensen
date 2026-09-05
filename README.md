# 森森 Sensen

Un **roguelike tactique** en monde infini, généré procéduralement et totalement continu, en vue isométrique sur grille — combat en **action-time à ticks** structuré par les cinq éléments du **Wu Xing** et sa jauge de chaîne, progression par l'usage à la Elona/Elin, endgame de construction de royaume.

> **L'identité du jeu tient en une phrase :** un jeu de **décisions**, pas de dextérité.

**Moteur : Godot 4.6** · GDScript typé (pas de GDExtension) · PC (Steam), solo et coop 4-8 en host-and-join · aucun asset : tout est dessiné par code.

---

## Sommaire

1. [Jouer](#jouer) — lancer le jeu, les contrôles
2. [En images](#en-images) — captures d'écran
2. [Ce qui tourne aujourd'hui](#ce-qui-tourne-aujourdhui) — les systèmes jouables, par thème
3. [Juger le jeu](#juger-le-jeu) — ce qui attend un œil humain
4. [Structure du dépôt](#structure-du-dépôt)
5. [Développement](#développement) — boucle de validation, outils
6. [Lire le design](#lire-le-design) — le coffre Obsidian

---

## Jouer

Ouvrir `godot/` avec **Godot 4.6** et lancer (F5). Au premier lancement après un clone :
`& $godot --headless --path godot --import` (construit le cache des classes).

La partie démarre par la **création de personnage** (R race, C classe, ↑↓ répartir les points, ←→ année de naissance, Entrée), puis au **camp de base** — une cellule du monde généré, dont on peut sortir à pied.

### Contrôles (tranchés le 2026-08-28)

| Touche | Action |
|---|---|
| **ZQSD** / **clic gauche** | se déplacer · cliquer un ennemi l'attaque avec l'action sélectionnée · cliquer un PNJ ouvre le dialogue |
| **E** | interagir avec ce qui est sous la souris si adjacent, sinon la première chose interactive autour (PNJ, coffre, lit, escalier, parcelle, place de village, eau, bête, plante, mur) |
| **R** | ramasser ce qui est au sol |
| **Clic droit** | **toutes** les options possibles sur la tuile ou l'être visé — c'est le geste à connaître |
| **Tab** | le menu : inventaire, atelier, feuille, capacités, carte, territoire, périmètre, registre, sauvegarder, volet latéral, minimap, débogage |
| **P** | au camp : dessiner un périmètre (récolte de bois, de minerai, de plantes, résidentiel, stockage) — choisir le type, puis cliquer les deux coins |
| **F4** | le volet latéral (monde, personnage, compagnons, journal, inventaire) : afficher / masquer — aussi au menu |
| **1 → 0** | la hotbar : armes du râtelier, capacités, bombes, attaque lourde, garde, attendre — la touche sélectionne, la ligne de visée suit la souris, le clic lance |
| **Échap** | fermer un écran / annuler une visée |
| molette, clic milieu | zoomer, déplacer la vue |

Dans les écrans : flèches et Entrée, plus les raccourcis lettres **affichés dans l'en-tête** de chaque écran (aucun raccourci global caché).

---

## En images

Des GIF pris par `scenes/tests/capture.tscn` (tout est dessiné par code — aucun asset) ; ils sont dans [`captures/anim/`](captures/anim/), rendus en **plein écran** (1920×1080) puis montés à 900 px. Chaque scène est **jouée** : le monde avance entre deux images, le joueur marche, les listes défilent, un sort se pose pièce par pièce, une semaine passe à la base. Les scènes sont **jouées avant d'être photographiées** : `--graine N` fixe le monde, `--explorer N` descend dans le donjon, `--marcher N` parcourt les alentours, `--loot N` remplit le sac d'objets assemblés et équipe le personnage, `--modules` apprend tout le catalogue, `--sorts` compose des capacités, `--talents` pose brèches et affûts, `--revele N` découvre les cellules alentour pour que la carte montre ce qu'un joueur finit par voir (gouffres, donjons, royaumes), `--creature`, `--chaine`, `--visee` mettent un combat en scène. **Les scènes de monde sont animées** (`--gif N --gif-pas P --gif-ticks T --gif-marcher N` rend une suite d'images, `tools/monter_gif.py` les monte) : on y voit le personnage marcher, l'horloge tourner, le combat se résoudre et la pluie tomber — un jeu vécu, pas un décor vide.

| | |
|---|---|
| ![Écran principal](captures/anim/titre.gif) **Écran principal** — nouvelle partie, continuer, charger | ![Camp de base](captures/anim/camp.gif) **Le camp de base** — une cellule du monde, HUD (compas, horloge, Wu Xing, barres, hotbar) |
| ![Carte du monde](captures/anim/carte.gif) **La carte du monde** — biomes, danger, donjons, filons, voyage rapide | ![Village](captures/anim/village.gif) **Un village PNJ** — place, bâtiments, habitants nommés, dialogue au clic |
| ![Donjon](captures/anim/donjon.gif) **Un étage de donjon** — blocs pleins, brouillard de guerre, lueur ambiante | ![Combat](captures/anim/combat.gif) **Le combat** — action-time à ticks, résolution simultanée, ennemis typés |
| ![Composeur](captures/anim/composeur.gif) **Le composeur de sorts** — formes, noyaux, modificateurs en glisser-déposer, Wu Xing du sort et aperçu | ![Création du personnage](captures/anim/creation.gif) **La création du personnage** — nom, race, classe, stats, les trois jauges, dix loci d'apparence ; les sorts de départ viennent de la classe |
| ![Inventaire](captures/anim/inventaire.gif) **L'inventaire** — l'avatar et ses cases d'équipement, le sac en liste triable, le Wu Xing de l'objet | ![Atelier](captures/anim/atelier.gif) **L'atelier** — les recettes en cartes, l'obtention de chaque composant dépliée |
| ![Orage](captures/anim/pluie.gif) **Un orage sur le camp** — la pluie dessinée par code, la foudre au journal, la météo au HUD | ![Création du monde](captures/anim/monde.gif) **La création du monde** — l'aperçu de la mappemonde entière et les sept réglages de génération |
| ![Capacités](captures/anim/capacites.gif) **Les capacités** — les sorts assemblés, leur coût, la hotbar en glisser-déposer | ![Commerce](captures/anim/commerce.gif) **Le commerce** — le stock d'un marchand, ses prix, et les objets encore non identifiés |
| ![Charger une partie](captures/anim/parties.gif) **Charger une partie** — une sauvegarde par partie ; la ligne pointée dessine le personnage et déplie l'état de son monde | ![Grande base](captures/anim/grande_base.gif) **Une grande base** — cinq cellules revendiquées, zones de récolte et stockages dessinés, douze chaumières bâties d'elles-mêmes pour vingt résidents (six semaines simulées) |
| ![Compagnons en donjon](captures/anim/compagnons.gif) **Deux compagnons en donjon** — recrutés au camp, ils descendent avec le joueur, entrent dans ses combats et frappent ; le HUD les suit (nom, vie, ordre), le volet de droite aussi | |

---

## Ce qui tourne aujourd'hui

Les étapes 0 à 10 de l'ordre de construction sont codées. Par thème :

**Combat** — action-time à ticks (une horloge par combat, une par être), grille isométrique avec relief, zones de coup par dénivelé, garde en posture, attaque lourde télégraphée, le blessé qui tremble et rougit à chaque coup, endurance, mana, jauge de chaîne Wu Xing, capacités composées depuis les modules appris (forme + noyau + modificateurs + liaisons), statuts et anti-stunlock, IA utility pilotée par les données.

**Exploration** — donjons de 128×128 (14-24 salles reliées en réseau maillé), brouillard de guerre par ligne de vue et Perception, éclairage (torches, meubles lumineux), creuser et terrasser, filons par profondeur et strates, coffres, monstres rares.

**Monde** — monde infini par cellules de 128×128, huit couches de bruit (altitude, température, humidité, mana, danger, végétation, sismique, ressources), biomes, routes, hameaux et villes, carte du monde et voyage rapide, cycle jour/nuit (24 000 ticks), **calendrier** (douze mois de trente jours nommés par les animaux du cycle, sept jours nommés, les années depuis 1 020, le jour de marché de chaque agglomération, dix fêtes, l'anniversaire de chaque PNJ), saisons, **météo** en fonction pure du temps et du lieu.

**Le monde qui bouge** — automate d'eau (une tranchée creusée au bord d'un lac s'inonde, un talus endigue, la pluie remplit les creux, une nappe qui n'est plus alimentée se retire, la canicule assèche), **courant** qui emporte ce qui flotte, gel qui rend la mer marchable, **foudre** d'orage pondérée par la hauteur et la conductivité des matériaux (paratonnerre émergent), **feu de tuile** qui prend, se propage selon la flammabilité, brûle qui s'y tient et s'éteint sous la pluie, **lave** dans les étages profonds qui se fige en obsidienne au contact de l'eau.

**Objets** — loot par profondeur (rareté, affixes, gemmes serties, uniques d'artefact), craft compositionnel (matériaux → composants → objets, les stats se calculent), stations de transformation, alchimie et potions, cuisine, poids porté et surcharge.

**Vivre** — faim et nourriture, sommeil, PNJ nommés avec relations, rumeurs et routines horaires, dialogue, commerce au prix suggéré, quêtes et guildes, compagnons (recrutement, ordres, postures, échange d'équipement, résurrection), apprivoisement, agriculture, élevage à génétique (8 espèces, registre et paliers).

**Territoire** — claims, rôles de cellule, résidents engagés ou arrivés d'eux-mêmes, assignés à une fonction et à un périmètre de récolte dessiné (bois, minerai, plantes) avec un stockage par poste, résidentiel où les chaumières se bâtissent seules, repas hebdomadaire, stocks et trésor, boutique passive, raids hebdomadaires, gouvernances, royaumes PNJ avec lois et douanes, accords diplomatiques, conquête de village.

**Villes** — la population décide de tout : cinq paliers (hameau, village, bourg, ville, cité), une agglomération couvre jusqu'à neuf cellules, chacune un quartier typé (centre, résidentiel, artisanal, marchand, agricole) avec sa grille de rues, ses parcelles le long des rues, ses logements, ses boutiques (jamais deux du même type), ses ateliers à stations, ses entrepôts, son siège du pouvoir selon la gouvernance du royaume (château, mairie, temple, comptoir, caserne), ses champs (de vraies parcelles que ses fermiers récoltent et ressèment) et son enclos de bêtes. **Une ville est un territoire, le même que le camp du joueur** : périmètres, résidents assignés, stocks, trésor, la même semaine ; le joueur qui la prend la gère avec ses outils de camp.

**Économie et transports** — les stocks d'une ville font ses prix par catégorie (nourriture, bois, pierre, métal, tissu, outils, luxe : pénurie 1,6, surplus 0,7), elle use ce qu'elle consomme et verse sa taxe au royaume ; les marchands itinérants arrivent par la route le jour de marché avec le surplus de leur ville ; des rails suivent les routes d'un royaume et un train passe aux heures du calendrier (on monte, on paie, on descend à la gare voisine), une calèche fait le tour des quartiers, un cheval apprivoisé ou acheté à l'écurie se monte (le pas coûte moitié moins, pied à terre en combat).

**Royaumes** — chaque royaume est un pays : population, armée, humeur du peuple, trésor nourri par ses villes, un règne daté du calendrier et une ère nommée (l'ère de la Grue, du Fer…), un blason dont ses gardes portent le fanion, des événements hebdomadaires (disette, bonne récolte, édit, révolte, levée de taxes, guerre et paix avec un voisin) que la carte affiche et que les PNJ racontent en rumeurs.

**Carte du monde** — les flèches font marcher le joueur de cellule en cellule (façon Dragon Quest), Maj + flèches font défiler, le clic marche loin ou revendique.

**PNJ** — chacun a deux traits de caractère qui agissent (prix, relation, horaires, production, fuite), une histoire, un souhait, des opinions sur ses voisins ; on lui offre des cadeaux ; sa fiche s'ouvre avec la relation (caractère à 50, souhait à 75, histoire et opinions à 90).

**Compagnons** — recrutés au village (tout humanoïde non hostile : gratuit au seuil de relation, sinon 40 or) ou apprivoisés, ils suivent partout : en donjon, d'étage en étage, et rentrent au camp avec le joueur ; ordres et postures, un HUD les montre (nom, vie, ordre) ; désarmés, ils frappent à mains nues.

**Interface** — un volet latéral (F4) : monde, personnage, compagnons, journal, inventaire ; les écrans d'inventaire, d'atelier, de composition, de commerce et de territoire ; un voile sous tout menu.

Ce qui reste ouvert, en détail : **`docs/00 - Index/Vers la production.md`**.

---

## Juger le jeu

Le code peut vérifier qu'une règle s'applique ; il ne peut pas dire si c'est **bon**. Les questions qui attendent un œil humain, rangées dans l'ordre d'une session de jeu :

**`docs/00 - Index/À juger — parcours de jeu.md`**

L'étape 11 (coop) ne commencera pas avant qu'un solo soit jugé bon.

---

## Structure du dépôt

| Chemin | Ce que c'est |
|---|---|
| [`godot/`](godot/) | Le projet Godot — `autoload/`, `data/`, `systems/`, `scenes/`, `locale/` |
| [`godot/data/`](godot/data/) | **Tout le contenu du jeu, en JSON** — un fichier par entrée, rangé en sous-dossiers thématiques ([README](godot/data/README.md)) |
| [`docs/`](docs/) | Le design complet : un **coffre Obsidian** de notes atomiques, reliées et navigables |
| [`tools/`](tools/) | Outillage — `check_vault.py` (intégrité du coffre) et les générateurs de données |
| [`archive/`](archive/) | Le GDD source monolithique (v2.0) — référence historique ; les notes de `docs/` font foi |
| [`AGENT.md`](AGENT.md) | Le prompt de développement autonome — règles de travail, boucle de validation, ordre |

### Dans `godot/`

- `autoload/game_data.gd` charge et **valide** tout `data/` au boot (schémas, erreurs `fichier → champ`, bloquant en debug ; F5 recharge à chaud). Depuis le 2026-08-29, un catalogue peut être **rangé en sous-dossiers** (`data/modules/noyau/`, `data/items/arme/`…) : l'id reste le nom du fichier, le dossier n'est qu'un classement pour l'humain.
- `systems/combat/simulation.gd` est **l'autorité** : une partie solo est une partie hébergée dont la porte est fermée. Le client (`scenes/demo/main.gd`) n'envoie que des **intentions** et n'affiche que ce que la simulation lui dit.
- `scenes/entities/creature.tscn` est la scène **unique** de tout être — le joueur n'est pas un type à part. Rig et équipement visible viennent des données.

---

## Développement

Quatre contraintes permanentes, dès la première ligne de code :

1. **Une partie solo EST une partie multijoueur hébergée** dont la porte est fermée — serveur autoritaire même en solo, intentions côté client, déterminisme par ticks.
2. **Une brique à la fois**, avec un critère de sortie formulé avant de commencer.
3. **`tr()` dès le premier écran** — aucune string affichable en dur, jamais. **Français et anglais sont complets** (1 983 clés chacun) ; japonais et chinois visés au lancement.
4. **Tout le contenu est de la donnée** — JSON validé au boot, hot-reload, zéro valeur de gameplay en dur.

### La boucle de validation

Après chaque incrément, dans cet ordre :

```powershell
$godot = "C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe"

& $godot --headless --path godot --import                                             # une fois après un clone (cache des classes)
& $godot --headless --path godot res://scenes/tests/test_combat.tscn                  # la suite de tests (~5 min)
& $godot --headless --path godot res://scenes/demo/main.tscn --quit-after 60          # la scène tourne sans erreur
python tools/check_vault.py                                                           # le coffre est intègre
python tools/audit_donnees.py                                                         # les liens entre catalogues tiennent
python tools/i18n_couverture.py                                                       # couverture de traduction (fr et en : 100 %)
```

Aucune sortie ne doit contenir `SCRIPT ERROR`, et la suite doit finir par `TESTS : tout passe`.

### Les autres outils

```powershell
# Chasse aux bugs : des intentions au hasard pendant N pas (aussi : --bete, --ia). Lire les SCRIPT ERROR.
# Le bilan final dit si le joueur a survécu et où il est ; « vivants 1 » juste après un voyage est normal (la faune
# de la cellule d'arrivée n'a pas encore éclos), pas un bug.
& $godot --headless --path godot res://scenes/tests/fuzz.tscn -- --pas 3000 --graine 7

# Rapport des critères mesurables de la spécification du prototype
& $godot --headless --path godot res://scenes/tests/test_criteres.tscn

# Capture d'écran (fenêtré — le `--` avant les options est obligatoire)
& $godot --path godot --disable-vsync res://scenes/tests/capture.tscn -- --arene 3 --heure 12 --frames 8 --sortie user://c.png
#   autres options : --donjon --torche --raid --talents --carte --ecran inventaire|menu|gestion|atelier|composer
#   --langue en · --graine N · --perimetre bois · --maison --assigner · --commerce --echange · --sorts gel+1 · --grande_base N (N semaines) · --ligne N (sélectionne la N-ième ligne de l'écran)
#   GIF : --gif N --gif-pas P --gif-ticks T [--gif-marcher M] --frames 400, puis python tools/monter_gif.py user://prefixe sortie.gif 900 350
#   --gif-action defiler|composer|carte|monde|creation|semaine : ce qui change entre deux prises d'un écran (liste qui défile, sort posé pièce à pièce, carte qui glisse, autre graine, volet suivant, une semaine à la base)
#   --arene gorge (un NOM d'arène, pas un index) · --sans-survol : pas de bulle de prévisualisation sur la créature la plus proche · --dump : à chaque prise, les combats (horloge, participants) et les êtres à huit tuiles du joueur sur la sortie standard · --arme <base> : un objet assemblé généré et équipé (craft_pioche…) · --zoom Z : la vue rapprochée
#   les PNG sortent dans %APPDATA%\Godot\app_userdata\Sensen\
```

Un seul Godot à la fois (le fuzz dure ~4 min, la suite ~5). Une capture statique ne juge pas la fluidité — il faut le dire à l'humain qui lit.

### Les sondes

Vingt-huit scènes `scenes/tests/sonde_*.tscn`, chacune mesure une chose et l'écrit en clair (`python tools/verif_scripts.py` les compile toutes). Les plus utiles :

```powershell
& $godot --headless --path godot res://scenes/tests/sonde_ecrans.tscn            # chaque écran à quatre tailles de fenêtre : rien ne sort du cadre
& $godot --headless --path godot res://scenes/tests/sonde_perf_etage.tscn        # où passent les millisecondes d'un étage de donjon (budget É2 : 100 ms)
& $godot --headless --path godot res://scenes/tests/sonde_perf_generation.tscn   # le coût d'un objet généré
& $godot --headless --path godot res://scenes/tests/sonde_ia.tscn                # errance, cible, meute
& $godot --headless --path godot res://scenes/tests/sonde_ia_pnj.tscn            # ennemis et alliés, scène par scène (--seulement compagnons,camp)
& $godot --headless --path godot res://scenes/tests/sonde_commerce.tscn          # les boutiques (filtres, étals garnis, marchands du village le plus proche) et ses guichets de quêtes
python -X utf8 tools/liste_objets.py       # la liste des objets pour les sprites (note générée)
python -X utf8 tools/verif_sprites.py      # les sprites d'objets attendus dans godot/assets/objets/, présents, manquants
& $godot --headless --path godot res://scenes/tests/sonde_journal.tscn           # les lignes identiques du journal se cumulent
# Une grande base sur la durée : cinq cellules, zones de récolte, vingt engagés, puis N semaines (Gestion de base)
& $godot --headless --path godot res://scenes/tests/sonde_grande_base.tscn -- --graine_monde 9 --residents 20 --semaines 12 --tresor 1000
#   options : --etal (un étal garni du stock) · --tempo (le coût d'une image au camp) · --profil (la semaine étape par étape) · --sauvegarde (aller-retour)
# Un hameau sur la durée : la moitié tuée, combien de semaines pour se repeupler ; décimé, devient-il abandonné (Villages PNJ)
& $godot --headless --path godot res://scenes/tests/sonde_village.tscn -- --graine_monde 9 --semaines 30
# Une ville à la population (Villes B1) : la plus grande agglomération à portée, ses quartiers, ses lits, ses rues, ses gens ; chargée, son territoire ; puis des semaines chronométrées
& $godot --headless --path godot res://scenes/tests/sonde_ville.tscn -- --graine_monde 9 --semaines 4
# Les PNJ d'une ville : traits, souhaits, histoires, opinions, et combien se ressemblent
& $godot --headless --path godot res://scenes/tests/sonde_pnj.tscn -- --graine_monde 21
# Les royaumes autour du camp : état, règne, ère, blason, puis douze semaines d'événements
& $godot --headless --path godot res://scenes/tests/sonde_royaume.tscn -- --graine_monde 21 --semaines 12
# Captures : --ville (la plus grande agglomération à portée, révélée, vue reculée), --village (le hameau le plus proche), --maison, --creature, --compagnons, --arme <base>, --zoom Z, --plein-ecran
# Le robot joue le client : descend les étages, se bat, meurt ou pas (fenêtré ; --equiper N --sorts N pour un robot équipé ; --compagnons N pour une escorte armée, notée à chaque étage)
& $godot --path godot res://scenes/tests/parcours.tscn -- --graine 73 --etages 4 --frames 8000 --equiper 3 --sorts 3 --sortie user://robot
```

### Générateurs de données

`audit_donnees.py` vérifie les liens **entre** catalogues, que ni les schémas ni `check_vault.py` ne voient : une famille de matériaux qu'aucune recette ne produit, une dépouille sans objet, un habitat d'élevage sans meuble. `tools/gen_*.py` transcrivent des tableaux des notes en JSON (`gen_materials.py`, `gen_affixes.py`, `gen_status_effects.py`, `gen_creature_actions.py`, `gen_dungeon_prefabs.py`, `gen_name_cultures.py`, `gen_palette.py`, `gen_progression_data.py`, `gen_rigs.py`, `gen_arenas.py`), et `structure_modules.py` ajoute la forme structurée des effets de modules. Ils écrivent dans les sous-dossiers de rangement et **effacent ce qu'ils régénèrent** : ne pas éditer à la main un fichier qu'un générateur possède.

---

## Exécutable (alpha)

Les versions jouables sont dans les [Releases](https://github.com/devmarcpro/sensen/releases) du dépôt (Windows x86_64, `.pck` embarqué — décompresser et lancer `Sensen.exe`). Pour reconstruire :

```
# une fois : les gabarits d'export 4.6.3 dans %APPDATA%\Godot\export_templates\4.6.3.stable\
& $godot --headless --path godot --export-release "Windows Desktop" ../build/Sensen.exe
```

Le préréglage est `godot/export_presets.cfg` (tests exclus, données JSON et locales incluses).

Pour publier une pré-version : GitHub CLI est installé (`gh` 2.98). Le jeton du gestionnaire d'identifiants Windows n'a pas le scope `read:org` qu'exige `gh auth login`, mais il suffit pour les commandes : passer par la variable `GH_TOKEN` (lue via `git credential fill`), puis `gh release create <tag> <archive> --prerelease --notes-file <notes>`.

## Lire le design

Ouvrir [`docs/`](docs/) comme coffre dans **Obsidian**. Point d'entrée : `00 - Index/Sensen — Index général.md`.

- **La note fait foi.** Le code applique les notes ; il ne les invente pas. Quand un détail manque, on tranche l'option la plus simple et cohérente et on l'écrit dans la note (callout daté) **avant** de coder.
- Chaque note porte en **alias** les références du GDD (`A.4.6`, `E.3`, `B.13`…) — tous les renvois résolvent.
- Frontmatter filtrable : `statut` (décidé / à-trancher / playtest / contenu-à-produire), `etape` (0-11), `domaine`.
- Les callouts `> [!success] Codé le …` disent ce qui est implémenté et **quelles décisions ont été prises en chemin**.
- `docs/99 - Ouvert/` archive les questions tranchées depuis : chaque note y porte sa décision et sa date.
- `python tools/check_vault.py` vérifie liens morts, frontmatter incomplet et comptages périmés (sortie non nulle si erreur).

### L'ordre de construction

Chaque étape produit quelque chose de **jouable et jugeable**, jamais une brique invisible.

| # | Étape | Ce qu'on obtient | État |
|---|---|---|---|
| 0 | Prototype de combat isolé | *le combat est-il bon ?* | codé |
| 1 | Combat rapatrié + paperdoll minimal | un combat propre dans le vrai projet | codé |
| 2 | Génération de donjon | un espace clos à explorer | codé |
| 3 | Loot (affixes, gemmes, rareté) | une raison de descendre | codé |
| 4 | Progression (usage, potentiel) | une raison de recommencer | codé |
| 5 | ⭐ **Jalon — roguelike de bout en bout** | entrer, combattre, looter, progresser, ressortir | codé |
| 6 | Matériaux + craft compositionnel | fabriquer ce qu'on n'a pas looté | codé |
| 7 | Camp de base | un point d'ancrage entre deux expéditions | codé |
| 8 | Génération du monde | un monde à parcourir entre les donjons | codé |
| 9 | PNJ et villages | un monde habité | codé |
| 10 | Royaumes, lois, économie, claims | l'endgame de territoire | codé |
| 11 | Coop | dernier chantier | **jamais avant un solo jugé bon** |
