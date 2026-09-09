---
aliases: ["12.1", "12.1 Points d'attache", "Points d'attache", "Paperdoll", "Couleurs réservées", "9.1", "9.2", "Rig humanoïde", "Segments"]
tags: [êtres, art, technique, décidé]
domaine: êtres
statut: décidé
etape: 1
---

> [!note] Adapté au pivot tactique
> Le pipeline d'import (marqueurs de couleurs réservées, points d'attache typés) s'applique aux **sprites** du paperdoll — même principe que l'import `.vox` d'origine.

Le pipeline d'assemblage : des points d'ancrage nommés encodés dans les sprites, une couleur réservée par type d'attache.

**Principe :** l'assemblage des parties du corps est un **paperdoll en couches de sprites** ([[Direction artistique]]) — chaque partie est un sprite avec ses **points d'ancrage nommés** et son ordre de superposition.

---

## Le rig humanoïde — 14 segments

> [!success] Décidé le 2026-08-26
> Remplace l'ancienne bibliothèque à 4 types de parties (tête / torse / bras / jambes). Le rig articulé permet l'animation par pivots **sans dessiner une seule frame**.

| Segment | Nombre | Note |
|---|---|---|
| tête | 1 | |
| **torse** | 1 | **torse et bassin fusionnés** — un seul sprite du cou aux hanches |
| bras haut | 2 | G / D |
| bras bas | 2 | G / D — avant-bras |
| **main** | 2 | G / D — segment propre ; c'est elle qui porte l'arme |
| jambe haut | 2 | G / D — cuisse |
| jambe bas | 2 | G / D — mollet |
| pied | 2 | G / D |

**Le rig EST la grille d'armure.** Les 5 slots d'armure ([[Équipement — 14 slots]]) sont déjà mappés sur les zones de coup ([[Zones de coup par dénivelé]]) et couvrent exactement ces segments :

| Slot d'armure | Segments peints | Zone de coup |
|---|---|---|
| Casque | tête | ×2.5 |
| Cuirasse | torse | ×1.0 |
| Brassards-gants | bras haut, bras bas, **main** | — |
| Jambières | jambe haut, jambe bas | ×0.8 |
| Bottes | pied | ×0.8 |

Conséquence : **l'équipement visible est gratuit**, et un coup à la tête peut s'afficher sur la tête.

## Les directions se font par superposition

**Une seule passe de sprites. Aucune direction n'est redessinée.** L'orientation est produite par trois données, jamais par de l'art supplémentaire :

1. **L'ordre de calque** — de face, les deux bras passent devant le torse ; de dos, derrière ; de profil, le bras proche devant et le bras loin derrière.
2. **Les décalages d'ancrage** — les épaules et les hanches se resserrent ou s'écartent selon l'angle, ce qui donne la rotation du buste.
3. **Le miroir horizontal** — W, NW et SW sont les miroirs de E, NE et SE.

```
data/rigs/humanoide.json
{
  "segments": [...],
  "facings": {
    "S":  { "ordre": [bras_D…, bras_G…, tête, torse, jambes…], "offsets": {…} },
    "SE": { … },  "E": { … },  "NE": { … },  "N": { … },
    "SW": { "miroir": "SE" }, "W": { "miroir": "E" }, "NW": { "miroir": "NE" }
  }
}
```

Ce sont **des données, pas des dessins** — cinq orientations à décrire, trois obtenues par miroir. Cohérent avec [[Direction artistique]] : *peu d'animation, beaucoup de feedback d'interface*.

> [!warning] La tête est le seul point où la superposition ne suffit pas
> Un bras ou une jambe se relit correctement sous n'importe quel angle ; **un visage, non** — une tête dessinée de trois quarts lit mal de dos. La parade la moins chère : **3 vues par tête** (face, profil, dos) au lieu d'une, sélectionnées par le `facing`. Ça porte la bibliothèque de 12 à 36 sprites de tête, et **aucun autre segment n'a besoin de cette exception**. À confirmer au premier essai visuel.

## Le coût en assets

**Bibliothèque humaine de base** — 8 types de sprites (le côté G/D vient du miroir) :

```
12 têtes (×3 vues = 36) + 8 torses + 8 bras haut + 8 bras bas
+ 8 mains + 8 jambes haut + 8 jambes bas + 8 pieds
≈ 92 sprites — une fois, pour TOUS les humains du jeu
```

**Armure — on ne dessine pas par objet, mais par construction.** [[Armure par zone et constructions]] a déjà décidé que les types d'armure n'existent pas comme étiquettes : ils émergent des **5 constructions** (Matelassé, Cuir, Mailles, Écailles, Plaque), *« la construction donne le profil, le matériau donne les chiffres »*. Donc, visuellement : **la construction est la forme, le matériau est la teinte**.

```
5 constructions × 8 segments ≈ 40 sprites
→ pour la TOTALITÉ de l'armure du jeu
```

Les centaines de variantes de matériau viennent du **remapping de palette en shader**, déjà en place ([[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]]). Une arme = un sprite, accroché à l'ancrage `prise`.

**Total de départ ≈ 130 sprites** pour le paperdoll humain complet et toute son armure.

## Les ancrages

Neuf types, avec un suffixe `_G` / `_D` plutôt qu'une couleur par côté :

| Ancrage | Relie | | Ancrage | Relie |
|---|---|---|---|---|
| `cou` | torse → tête | | `hanche` | torse → jambe haut |
| `épaule` | torse → bras haut | | `genou` | jambe haut → jambe bas |
| `coude` | bras haut → bras bas | | `cheville` | jambe bas → pied |
| `poignet` | bras bas → main | | `dos` | torse → cape, sac |
| `prise` | main → arme, outil | | | |

**Couleurs réservées** (`data/palette_materiaux.json`, section `anchors`) :

| Couleur | Ancrage | | Couleur | Ancrage |
|---|---|---|---|---|
| `#FFFF00` | cou | | `#00FF7F` | épaule |
| `#00E07F` | coude | | `#00C07F` | poignet |
| `#FF00BF` | prise (arme, outil) | | `#00BFFF` | hanche |
| `#00A0FF` | genou | | `#0080FF` | cheville |
| `#FF7F00` | dos | | `#7F00FF` · `#FF0000` · `#00FFBF` | aile · queue · monture |

Aucune ne figure dans la palette des matériaux ([[Palette de couleurs des matériaux]]) ni dans les stand-in de recette (#00FF00, #FF00FF, #00FFFF, #FFFF00), **sauf `#FFFF00`** qui est partagé : les marqueurs d'attache vivent dans les sprites de **parties de corps**, les stand-in dans les sprites d'**objets et de prefabs** — deux pipelines d'import distincts, aucune collision possible. GameData le vérifie au boot.

**Règle de miroir :** on dessine **un seul côté**, l'autre est miré. Surcharge explicite possible pour l'asymétrique — une épaulière unique, le bras au bouclier.

---

## Le pipeline

- Sur chaque partie, l'artiste place des **pixels-marqueurs** aux emplacements de connexion.
- À l'import, le script détecte ces marqueurs, **les retire du sprite visible**, et enregistre leur position comme point d'attache dans la ressource.
- À l'assemblage, le jeu aligne l'ancrage de chaque segment sur le correspondant du parent — n'importe quelle partie de la bibliothèque se branche sur n'importe quelle autre, tant que les types d'ancrage correspondent.

**L'apparence vient des données ([[Apparence — données et équipement]]) :** la silhouette est déclarée par l'espèce, les couleurs et motifs viennent du **génome** ([[Loci — les dix types]]) — donc héritables et sélectionnables ([[Règle d'anneau]]) — et les pièces d'équipement s'attachent aux ancrages. Le même pipeline dessine un roi, un mouton et un papillon.

**Bénéfices dérivés :**
- Les templates de morphologie ([[Schéma unifié créature-PNJ]]) deviennent triviaux : un quadrupède est un torse portant 4 chaînes `épaule → coude → pied` au lieu de 2 bras + 2 jambes.
- Les ancrages servent aussi de **pivots d'animation** — marche, frappe et garde s'obtiennent en faisant tourner les segments autour de leurs articulations, **sans dessiner de frames**.
- Extensible aux **points d'équipement visibles** (l'arme à `prise`, la cape à `dos`).

**Décisions :**
- **Templates de squelette au lancement : 4** — bipède/humanoïde, quadrupède, volant, amorphe ([[IA des créatures]]/[[Créatures]]). Extensible par données.
- **Bibliothèques au lancement :** humanoïde = le rig 14 segments ci-dessus · quadrupède 6 têtes / 4 torses / 6 pattes · volant 4 têtes / 4 torses / 4 ailes · amorphe 6 corps entiers.
- **Règle de recrutement par type (défauts, surchargés en [[Schéma créature]]) :** humanoïdes intelligents → `relation` · bêtes/animaux → `dressage` · PNJ uniques → `dressage` à DD très élevé ou `quete` · certains → `jamais`.
- **Couleurs stand-in de matériaux figées** : #00FF00 (catégorie 1 de la recette), #FF00FF (cat. 2), #00FFFF (cat. 3), #FFFF00 (cat. 4) — remappées à la teinte du matériau réel au rendu.

**Même technique réutilisée par :** les prefabs de donjon ([[Salles et connecteurs]]), les modèles d'objets ([[Schéma objet et recette]]), les blocs fonctionnels de véhicules ([[Véhicules]]).

**Import des parties ([[Décisions d'architecture]]) :** script d'import custom qui détecte les pixels-marqueurs de couleurs réservées, les retire du sprite visible, et les exporte comme liste de points d'attache typés `{type, côté, position}`.

**Rendu partagé ([[Entités et pathfinding — performance]]) :** les parties sont des ressources **partagées** ; recolorisation par palette en shader (paramètre d'instance) — 100 villageois = ~8 jeux de parties distincts en mémoire.

> [!success] Codé le 2026-08-27 — le rig avant les sprites
> `data/rigs/{humanoide, quadrupede, volant, amorphe}.json` (`tools/gen_rigs.py`) portent le **vrai rig** : segments accrochés à l'ancrage de leur parent (longueur, largeur, angle de repos, ancrages portés `[le long, en travers]`, zone de coup), **facings** (ordre de calque + décalages d'ancrage pour S/SE/E/NE/N, W/NW/SW par **miroir**), `slots_segments` (quel slot d'armure peint quels segments) et `prise_arme` / `prise_bouclier`. `scenes/entities/creature.tscn` (`paperdoll.gd`) est la scène unique de tout être : elle lit la fiche (silhouette → rig), l'équipement (pièce → segments peints, contour selon la **construction**, teinte selon le **matériau** — `data/palette_materiaux.json`, transcrit de [[Palette de couleurs des matériaux]]), l'arme à `prise`. **Sans aucun asset** : chaque segment est un rectangle procédural — quand les sprites arriveront, ils remplaceront le rectangle ; le rig, les facings et les ancrages restent. L'animation par pivots existe (la frappe fait tourner le bras d'arme). Les **3 vues de tête** sont notées (`vue_tete`) mais indiscernables sur un cercle : à confirmer au premier essai visuel, comme prévu. Le génome n'existant pas encore sur les fiches, la couleur du corps est la `teinte` de la fiche.

> [!success] Décidé le 2026-09-01 — une seule vue : de face (designer, point 54)
> Le rig déclarait cinq orientations dessinées (S, SE, E, NE, N) et trois miroirs. Le designer tranche : **le paperdoll est de face, et seulement de face**. Le rendu prend donc toujours l'orientation `S` — l'orientation de l'être continue d'exister **côté jeu** (la garde frontale, les zones de coup par dénivelé, l'embuscade, le champ de vision en dépendent), elle ne change simplement plus le dessin.
>
> Ce que ça achète : un visage lisible tout le temps, des traits qui n'ont plus à survivre à un profil ni à un dos, et — le jour où le projet acceptera des images ([[Direction artistique]]) — la possibilité de brancher un atlas 2D **de face** sans le redessiner sous huit angles. Les blocs `facings` restent dans les données des rigs : ils ne coûtent rien et gardent la porte ouverte si une seconde vue redevient utile.

> [!success] Décidé et codé le 2026-09-01 — le joueur articule ses poses (designer, point 63)
> Le rig est déjà une liste d'angles par segment, et le Paperdoll sait déjà appliquer un delta d'angle (l'animation de frappe s'en sert). Une **pose** n'est donc rien d'autre qu'un dictionnaire `segment → angle`, et le joueur peut le remplir lui-même.
>
> À la création, une ligne **Pose** choisit l'**action** à mettre en scène — repos, marche, attaque au corps à corps, sort, garde, sommeil, mort — puis l'aperçu devient un **pantin** : on clique un segment, on le fait pivoter à la souris ou aux flèches, et la pose est **enregistrée dans le personnage** (`poses`, sauvegardée avec la partie). En jeu, le Paperdoll rejoue la pose de l'action en cours ; sans pose enregistrée, il garde le rig par défaut, exactement comme avant.
>
> Les actions posables et l'amplitude autorisée vivent dans `data/poses.json` — aucune n'est écrite dans le code, et un rig non humanoïde s'articule aussi bien qu'un autre.

> [!important] Décidé et codé le 2026-09-06, 20 h 20 — ce qu'on tient est dessiné comme à l'inventaire, montage ou pictogramme (designer : « quand une arme est équipée, elle devrait avoir le même sprite que dans l'inventaire »)
> Le contrat du 2026-09-05 (l'arme tenue est le même montage que son icône) ne valait que pour les objets dont toutes les pièces ont un sprite ; sans montage, le paperdoll traçait un trait par compétence (une ligne pour l'épée, un arc de cercle pour l'arc) et l'autre main dessinait toujours un disque — la torche en main secondaire était un bouclier. Désormais `Paperdoll._dessine_tenu_picto` pose dans la main **le pictogramme même de l'inventaire** (`Pictos.dessiner_objet`, par `Pictos.nom_picto`), dans une case de `styles.sprites.picto_tenu_unites` unités de rig, tourné avec la main : le point de prise et l'axe de chaque pictogramme (`styles.sprites.pictos_tenus`, en dixièmes de case) se posent sur la main et sur le bras — la diagonale d'une lame, la verticale d'un arc, le manche d'une torche. Les deux mains : l'arme, et le bouclier, la torche ou la dague de l'autre main. Le montage pré-rendu garde la priorité quand il existe.

> [!success] Codé le 2026-09-06, 21 h — les membres par planches, sinon par code
> `Paperdoll._planche_membre` : un segment dont le dossier `assets/membres/<segment>/` a des cases se dessine par sa case (carrée, de la longueur du segment, centrée sur son axe, le bas à l'origine), miroir pour le côté gauche, variante par carrure, teinte du segment ; sinon le polygone d'avant. La tête et chaque trait du visage de même (`_planche_visage`, la case est la tête entière). Voir [[Direction artistique]] (callout du 2026-09-06, 21 h).


> [!success] Codé le 2026-09-08 — le **torse se coupe en bassin + torse**, et la case d'un membre devient carrée **centrée** (designer : « sépare torse en bassin et torse »)
> **La coupe ne déplace rien.** Le bassin part de la hanche et fait 5, le torse le prolonge et fait 9 : le cou reste à **14** de la hanche, les épaules à **12**, les hanches à **0** — exactement où ils étaient. Les jambes pendent du bassin, qui devient la **racine** du rig ; le bassin porte la zone de dégâts `torse`, donc `zone_de_coup` et tout le combat ne bougent pas d'un chiffre ; la cuirasse habille les deux segments. Le rig passe de 14 à **15 segments** (`test_noyau_passes` le vérifie, racine comprise).
> **Et une erreur de règle trouvée en posant la planche du bassin** : la case d'un membre faisait la **longueur** du segment. Ça marchait tant qu'un membre était plus long que large — le bassin est plus **large** que long (8 contre 5), et sa planche sortait écrasée dans une case de 5. La case est désormais **carrée, centrée sur le segment, de côté `max(longueur, largeur)`** ; pour tout membre allongé, `cote == longueur` et le calcul est celui d'avant, au pixel près.
> **Une arme dans chaque main** : `equipement` range chaque objet dans **son** emplacement, donc deux épées finissaient toutes deux dans la main principale. `equipement_slots` dit *dans quel emplacement*, s'applique après la liste et gagne — c'est ce qui permet de tenir une arme dans la seconde main sans toucher aux vingt kits de classe, dont la liste reste intacte. L'aperçu de la création refaisait cet équipement dans son coin et montrait autre chose que la partie : il lit les mêmes données maintenant.


> [!success] Codé le 2026-09-08 — **les planches de membres aux proportions du rig** (designer : « ajuste les tailles des sprites pour que les proportions soient bonnes et qu'il n'y ait pas de vide »)
> **D'où venait le vide.** La case d'un membre est un **carré** de côté `max(longueur, largeur)`, centrée sur le segment : celui-ci n'en occupe donc que `longueur / côté` en hauteur et `largeur / côté` en largeur. Or chaque dessin occupait, lui, la fraction que l'artiste avait laissée dans son PNG — un avant-bras dont le trait remplissait 56 % de la case laissait 44 % de rien entre le coude et le poignet. Les membres flottaient, séparés.
> **Ce qui est fait** : chaque planche est recadrée sur son contenu et reposée **exactement dans le rectangle que le rig déclare**. Plus de vide le long d'un membre, et une largeur qui est celle du squelette. L'étirement n'est pas une déformation : le rectangle cible a les proportions du segment, et le dessin a été fait pour ce membre-là.
> **Le dessin d'origine est gardé** dans un `.source/` à côté de chaque planche : un recalage se refait, un dessin perdu ne se retrouve pas. Refaire l'opération après avoir changé le rig repart de la source, jamais du résultat.

> [!success] Codé le 2026-09-08, soir — **le squelette a une profondeur** (designer : « rajouter la profondeur, comme ça on pourrait avoir les personnages dans les 8 angles et faire des poses plus complexes »)
> **Le repère du corps**, lacet nul (le personnage nous fait face) : `x` la droite de l'écran, `y` le BAS de l'écran — le corps est debout, cet axe ne tourne pas —, `z` la profondeur vers le fond. `angle` garde exactement son sens d'avant : l'angle dans le plan (x, y). `profondeur` (degrés, 0 par défaut) fait sortir le segment de ce plan, vers l'avant quand elle est positive. Un ancrage porte trois nombres : `[le_long, en_travers, en_profondeur]`, le troisième le long de la normale du parent — pour un segment vertical, cette normale pointe vers l'**arrière**, d'où les valeurs négatives des épaules et des hanches, qui sont devant le plan du torse.
> **Le lacet** est continu, tiré de l'orientation de grille : `atan2(x − y, x + y)`, parce que l'isométrie regarde la grille depuis le sud-est. Les huit `orientations` du rig ne servent plus qu'à nommer le lacet le plus proche pour choisir la vue de la tête (face, profil, dos).
> **La projection** : une unité de profondeur vaut `styles.sprites.profondeur_ecran` — `[0, −0,5]`, la même demi-hauteur que les tuiles du monde. La **longueur** d'un segment se raccourcit donc pour de bon quand il plonge vers nous ; sa **largeur**, elle, reste face à la caméra et seule sa mesure diminue, bornée par `largeur_min_profil`. Sans cette borne, un bras vu de tranche deviendrait un trait.
> **Ce qui a disparu des données** : les huit `ordre` de calque et les huit `offsets` d'ancrage de chacun des six rigs. Il reste **un** `ordre` par rig, et il ne sert qu'à départager deux segments à la même profondeur (un serpent à plat, une méduse) — sans lui, `sort_custom` n'étant pas stable, le pantin scintillerait.
> **Ce que ça ouvre** : les huit angles au lieu de trois, et une pose qui peut dire `[angle, profondeur]` — un bras qui part en arrière, que la 2D ne savait pas exprimer. `capture.tscn -- --pantins` dessine la planche des huit angles côte à côte : c'est le seul moyen de juger une profondeur, une capture de jeu ne montrant jamais qu'un angle.
> **Ce qui reste** : les rigs animaux gardent `lacet_actif: false` (voir [[Ordre de travail]], ligne 26 septies).

> [!success] Codé le 2026-09-09 — **toute la faune tourne, et un segment a une épaisseur** (boucle autonome, ordre de travail 26 septies et 26 octies)
> **Les rigs animaux en espace du corps.** Le quadrupède, l'arachnide, le serpentin et le volant étaient des dessins de profil : leur axe long était l'axe `x` de l'écran. Leur axe long est désormais l'axe de **profondeur** — à lacet nul le museau vient vers la caméra, à 90 degrés on retrouve exactement le profil d'avant. Trois conséquences qui ne coûtent rien : une **vue de face** et une **vue de dos** gratuites pour toute la faune ; l'écart des pattes le long du corps devient un écart de profondeur, donc les pattes avant se dessinent devant les arrière **sans ordre écrit** ; et le serpent ondule dans le plan **horizontal**, vu en plongée comme le reste du monde.
> **Un segment est un cylindre, pas un ruban.** La profondeur avait laissé un chiffre magique : `largeur × largeur_min_profil` pour un segment vu de tranche. Un corps a deux mesures de travers — `largeur` d'une épaule à l'autre, `epaisseur` de la poitrine au dos — et la silhouette à l'écran est la projection de cette ellipse : `sqrt((largeur·u)² + (epaisseur·v)²)`. Un torse de profil fait son épaisseur. `largeur_min_profil` n'est plus qu'un plancher absolu (0,12) pour qu'un segment vu de bout ne devienne jamais un trait ; `epaisseur` omise vaut `largeur × styles.sprites.epaisseur_defaut`.
> **L'outil** : `capture.tscn -- --pantins [rig]` dessine les huit angles de n'importe quel rig côte à côte.

> [!success] Codé le 2026-09-09 — **une seule orientation : le personnage est toujours de face** (designer : « retire toutes les orientations du personnage, je veux qu'il soit uniquement de face »)
> **Le changement a coûté une table de trois lignes à une ligne, et pas une ligne de code.** C'est la preuve que la mécanique posée le matin même tenait sa promesse : « c'est CETTE TABLE qui décide combien de vues existent ». Avec une seule entrée, le calage du lacet continu rend toujours la même vue — le corps ne tourne jamais, la tête garde sa planche de face, et les huit directions de marche rendent le même dessin. Voulu.
> **Ce qui disparaît avec les profils** : les questions que trois vues posaient au dessinateur — quelle vue montre un personnage qui s'éloigne, quel profil gagne un pas droit vers le haut, dans quel ordre déclarer la table. Elles n'ont plus d'objet. **Une planche de visage par personnage suffit.**
> **Ce qui reste possible d'une édition** : remettre les deux profils (E 90, W −90), ajouter le dos (N 180) ou les quatre trois-quarts est une modification de `ORIENTATIONS` dans `tools/gen_rigs.py`, régénération comprise. Rien d'autre à toucher.
> **Un test encodait le contenu au lieu de la règle**, et il aurait rougi sans qu'aucune règle soit violée : il exigeait « trois orientations, dont W à −90 ». Il dit maintenant ce qui doit être vrai — au moins une vue, chacune avec un lacet dans le tour complet. *C'est le même piège que le boss `elite` d'hier : un test qui recopie le contenu du jour interdit au designer de changer d'avis.*

> [!info] ~~Codé le 2026-09-09 — **trois orientations par personnage**~~ — *remplacé le jour même par la vue unique ci-dessus ; gardé pour la mécanique, qui n'a pas changé*
> **C'est la table du rig qui décide, pas une constante.** Le corps se cale sur l'orientation la plus proche parmi celles que le rig **déclare** : trois aujourd'hui — la face et les deux profils, ce que le designer dessine à la main. Y rajouter le dos (N 180) ou les quatre trois-quarts rendrait ces vues-là sans toucher une ligne de code.
> **Le calage se fait à l'ÉCRAN, pas sur un angle de grille**, et c'est ce qui évite un choix arbitraire. Sur un angle, les quatre pas le long des axes de la grille tombent à égalité parfaite entre deux vues — 45° est à mi-chemin de 0 et de 90 — et il faut trancher par une règle inventée ; or toute règle arbitraire est un choix de design déguisé en détail technique. L'isométrie tranche seule : un pas de grille (1, 0) va à l'écran vers `(1 ; 0,5)`, l'écrasement de moitié le rend beaucoup plus horizontal que vertical. On compare donc la direction du mouvement à l'écran au **regard** de chaque vue, lui aussi à l'écran — la face regarde vers `(0 ; 0,5)`, le profil droit vers `(1 ; 0)`. Plus aucune égalité.
> **LES CONSÉQUENCES, ET ELLES COMPTENT POUR CELUI QUI DESSINE.** Avec trois vues, sur les huit directions de marche : **une** montre la face (descendre droit vers le bas de l'écran), quatre le profil droit, trois le profil gauche.
> · **Il n'y a plus de dos** : un personnage qui s'éloigne montre un profil, donc son visage. C'est le prix de trois vues, et beaucoup de jeux l'assument.
> · **Un être à l'arrêt qui n'a jamais marché fait face à la caméra** (le repli du calage est la direction « vers nous ») ; celui qui a marché garde sa dernière orientation.
> · **Un pas droit vers le haut est à égalité parfaite** entre les deux profils — aucun des deux ne regarde de ce côté. C'est **l'ordre de la table** qui tranche, la première déclarée gagnant : `S, E, W` fait regarder à droite en s'éloignant, `S, W, E` ferait regarder à gauche. C'est le seul endroit où l'ordre de cette table compte, et il est écrit dedans.
> `capture.tscn -- --pantins [rig]` dessine les huit directions de marche calées sur les vues déclarées : deux colonnes identiques disent que deux directions partagent une vue.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Direction artistique]], [[Décisions d'architecture]]
- **Alimente** : [[Schéma créature]], [[Apparence — données et équipement]], [[Équipement — 14 slots]], [[Armure par zone et constructions]], [[Monstres rares]]
- **Voir aussi** : [[Palette de couleurs des matériaux]], [[Entités et pathfinding — performance]], [[Zones de coup par dénivelé]], [[Créatures]], [[Création de personnage]]
