---
aliases: ["Prompt sprites", "Bibliothèque de sprites", "Manifeste des sprites"]
tags: [êtres, art, technique, décidé]
domaine: êtres
statut: décidé
etape: 1
---

> [!important] Document du designer (2026-09-05, matin) — reproduit tel quel ci-dessous. **Le pipeline scripté qui devait le mettre en œuvre est abandonné le même jour à 11 h (designer : « je m'en occuperai moi-même plus tard ») ; le document reste comme sa description de ce qu'il veut**, voir [[Direction artistique]].
> Le designer a écrit ce prompt pour générer la bibliothèque de sprites, pièce par pièce, et un second document (`AGENT-sprites.md`, retiré du dépôt avec le pipeline) pour la session d'agent qui devait construire le rendu. Le premier fait foi : la [[Direction artistique]] les résume dans son callout du 5 septembre (9 h). Trois relevés faits en les lisant, sans toucher au texte : le dépôt compte **dix-sept** composants et non seize (la `sertissure` des bijoux, `data/components/sertissure.json`) ; **85** créatures sur six rigs (32 quadrupèdes, 20 humanoïdes, 17 volants, 7 arachnides, 6 amorphes, 3 serpentins) ; et ce prompt garde les pixels-marqueurs d'ancrage quand `AGENT-sprites.md` leur préfère un JSON d'ancrages à côté du PNG — la session dédiée tranchera en écrivant le callout de [[Squelette modulaire et points d'attache]]. Le champ `variante_visuelle` existe depuis ce matin dans le schéma des objets (épée droite, sabre courbe, rapière fine) ; l'icône d'inventaire d'un objet assemblé se compose déjà des sprites de ses composants quand ils existent (`Pictos._dessiner_assemblage`).

# Prompt de génération — bibliothèque de sprites de 森森 Sensen

Dérivé de `godot/data/rigs/*.json`, `godot/data/apparence.json`, `docs/01 - Vision/Direction artistique.md` et `docs/06 - Êtres/Squelette modulaire et points d'attache.md`.

**Usage :** coller BLOC A + BLOC B en tête de chaque génération, puis une seule ligne du manifeste (BLOC C) instanciée dans le gabarit (BLOC D). Un sprite = une image = une requête. Ne jamais demander une planche : les segments doivent rester des fichiers séparés, sinon le paperdoll ne peut pas les articuler.

---

## BLOC A — Contexte artistique (fixe)

```
Tu produis un élément d'une bibliothèque de sprites pour un roguelike tactique
isométrique nommé 森森 Sensen. Les personnages sont des billboards paperdoll :
un corps est assemblé à l'écran à partir de segments séparés, articulés autour
de leurs joints. Tu ne dessines JAMAIS un personnage entier — seulement la
pièce demandée, isolée.

Rendu : IMAGE DE SYNTHÈSE PRÉ-RENDUE, ANNÉES 90.
- La pièce est un objet 3D rendu puis aplati en sprite, comme les jeux
  pré-rendus 32 bits : géométrie basse (200 à 800 triangles), volumes
  primitifs assemblés — cylindres, cubes biseautés, sphères aplaties.
- Ombrage lisse d'époque : diffus + spéculaire dur et net, aucun PBR,
  aucune illumination globale, aucune occlusion ambiante, aucun bloom.
  Un terme ambiant constant remplace le rebond.
- Le grain d'époque vient du rendu en 4× réduit ensuite à la taille cible,
  pas d'un filtre. Un léger banding des valeurs est acceptable, voire juste.
- Aucun micro-détail, aucune texture photo : la lisibilité vient de la
  silhouette et de deux ou trois plans de valeur, pas de la surface.
- Lumière unique et IDENTIQUE pour toute la bibliothèque : clé en haut à
  gauche à 45°, ambiant faible, aucune autre source. Deux pièces éclairées
  différemment ne s'assemblent pas.

Direction artistique :
- Identité chinoise assumée, pas médiéval-européen. Motifs, formes d'armure
  et d'arme d'Asie de l'Est — tenus par la géométrie, pas par une texture.
- La lisibilité prime sur le réalisme : silhouette distincte et reconnaissable
  à 40 px de haut, aucun détail qui disparaît à petite taille.
- Vue de FACE uniquement, projection orthographique, aucune perspective,
  aucun raccourci, aucun trois-quarts. (Décision du 2026-09-01 : le paperdoll
  n'a qu'une seule orientation dessinée.)
- Aucune ombre portée au sol, aucun sol, aucun décor, aucun cadre, aucun texte.
- Pose neutre, membre droit dans l'axe : l'animation vient de la rotation des
  segments en jeu, pas du dessin.
```

## BLOC B — Contraintes techniques (fixe)

```
Format :
- PNG RGBA, fond 100 % transparent, un seul sujet centré.
- Échelle source : 8 px = 1 unité de rig. Un humain fait 35 unités (280 px).
- Bords nets, pas d'anti-aliasing mou, pas de flou, pas de dégradé de fond.

Orientation du segment (règle absolue) :
- L'origine du segment — son point d'attache au parent — est au CENTRE DU BORD
  BAS de l'image.
- Le segment s'étend vers le HAUT. Hauteur de l'image = « longueur » du rig,
  largeur de l'image = « largeur » du rig.
- Le sujet remplit la largeur ; aucune marge horizontale décorative.

Couleur :
- Tout est rendu en GRIS NEUTRE (saturation 0), valeurs entre 20 % et 90 %.
  La teinte réelle vient d'un remapping de palette en shader — matériau pour
  l'équipement, génome pour le corps. Toute couleur saturée dans le sprite
  casse la recoloration.
- Le modelé (lumière, spéculaire, plans d'ombre) reste entièrement dans la
  valeur : c'est lui qui survit à la teinture. Le matériau ne se lit donc pas
  à la couleur mais au spéculaire — étroit et fort pour le métal, large et
  faible pour le bois.
- Bords nets contre le fond transparent : pas de halo clair, pas d'ombre
  portée sur l'alpha.
- Exception : les pixels-marqueurs d'ancrage, en couleur pure, 1 px, retirés
  à l'import :
    #FFFF00 cou · #00FF7F épaule · #00E07F coude · #00C07F poignet
    #FF00BF prise · #00BFFF hanche · #00A0FF genou · #0080FF cheville
    #FF7F00 dos · #7F00FF aile · #FF0000 queue · #00FFBF monture
  Placer un marqueur à chaque ancrage porté par le segment, aux coordonnées
  [le long, en travers] du rig, comptées depuis l'origine.

Miroir : on ne dessine QUE le côté gauche. Le côté droit est obtenu par
miroir horizontal en jeu. Ne jamais livrer une paire.
```

## BLOC C — Le manifeste

Dimensions en px à l'échelle 8 (largeur × hauteur = largeur × longueur du rig).

### 1. Corps humanoïde — 56 sprites

8 variantes par type (les carrures et tailles sont des facteurs d'échelle, pas des dessins).

| Segment | px | Variantes | Ancrages à marquer |
|---|---|---|---|
| `torse` | 72 × 112 | 8 | cou (112,0) · épaule_G (96,-40) · hanche_G (0,-20) · dos (64,0) |
| `bras_haut` | 24 × 64 | 8 | coude (64,0) |
| `bras_bas` | 24 × 56 | 8 | poignet (56,0) |
| `main` | 24 × 24 | 8 | prise (16,0) |
| `jambe_haut` | 32 × 56 | 8 | genou (56,0) |
| `jambe_bas` | 28 × 48 | 8 | cheville (48,0) |
| `pied` | 24 × 32 | 8 | — |

### 2. Tête humanoïde — 28 sprites, en couches

Cinq calques recalés sur le même canevas **64 × 64 px**, l'ancrage `cou` au centre du bord bas. Le visage est le volume de base ; les traits sont des volumes posés dessus, chacun avec son petit plan d'ombre sur le visage — c'est ce plan qui donne le relief, pas le contour.

| Calque | Variantes |
|---|---|
| visage (crâne nu) | 5 — ronde, ovale, carrée, allongée, en cœur |
| yeux | 5 — points, fentes, grands, en amande, tombants |
| nez | 5 — droit, crochu, plat, fin, busqué |
| bouche | 4 — fine, large, sourire, boudeuse |
| cheveux | 7 — courts, longs, queue, chauve, crête, chignon, tresses |
| barbe | 2 — courte, longue |

Les autres loci d'`apparence.json` (`sourcils`, `paupieres`, `oreilles`, `marque`, `machoire`, `menton`, `pommettes`, `implantation`) et les 5 curseurs continus restent **procéduraux** — tracés ou déformés par le code par-dessus le sprite de visage. Les dessiner ferait exploser la combinatoire (5 × 3 × 3 × 3 = 135 visages pour la seule forme du crâne).

### 3. Armure — 40 sprites

5 constructions × 8 segments. « La construction est la forme, le matériau est la teinte » : ce sont les seules armures du jeu, les centaines de variantes viennent du remapping.

- Constructions : `matelasse`, `cuir`, `mailles`, `ecailles`, `plaque`
- Segments peints : casque (tête) · cuirasse (torse) · brassard haut · brassard bas · gant · jambière haute · jambière basse · botte
- Chaque pièce est dessinée **au canevas de son segment** (§1), en surcouche : elle doit recouvrir la silhouette du segment nu sans la déborder de plus de 2 unités.
- L'épaisseur du contour lit la construction en jeu (0,6 matelassé → 2,2 plaque) : la forme dessinée doit aller dans le même sens — matelassé mou et rembourré, plaque rigide et anguleuse.

### 4. Armes — on ne dessine pas les armes, on dessine les composants

Correction du manifeste précédent. Les 43 armes assemblées de `data/items/arme|bouclier|outil/` **n'ont pas de forme propre** : chacune déclare 1 à 3 slots remplis par un composant de `data/components/`, et le composant porte le matériau. Dessiner 43 armes reviendrait à redessiner 12 fois le même manche court.

**On dessine donc les 16 composants, et une arme est un assemblage** — exactement la logique du paperdoll, transposée à l'objet.

| Composant | Slot | Familles de matériaux possibles | Armes qui l'utilisent |
|---|---|---|---|
| `lame_longue` | tete | lingot_metal, obsidienne, or_argent, os, verre | 3 |
| `lame_courte` | tete | lingot_metal, obsidienne, or_argent, os, verre | 5 |
| `pointe` | tete | dent_croc, lingot_metal, obsidienne, os, silex | 9 |
| `tete_arme_lourde` | tete | granit_noir, lingot_metal, meteorite, roche_taillee | 3 |
| `tete_outil` | tete | lingot_metal, obsidienne, os_massif, roche_taillee | 5 |
| `monture` | tete | lingot_metal, or_argent, os | 9 |
| `manche_long` | manche | bois, ivoire, lingot_metal, os | 12 |
| `manche_court` | manche | bois, ivoire, lingot_metal, os | 12 |
| `poignee` | manche | bois, ivoire, lingot_metal, os | 16 |
| `garde` | garde | lingot_metal, os | 8 |
| `contrepoids` | contrepoids | lingot_metal, roche_taillee | 5 |
| `corde` | corde | fibre, soie | 6 |
| `plaque` | plaque | ecaille, lingot_metal, os_massif | 4 |
| `sangles` | sangles | cuir, fibre, soie | 7 |
| `etoffe` | plaque | cuir, fibre, soie | 1 |
| `doublure` | doublure | cuir, fibre | 1 |

**3 variantes de forme par composant → 48 sprites**, contre ≈ 108 fichiers si on dessinait chaque arme en calques. Et le gain n'est pas que comptable : l'épée à lame d'os et poignée d'ivoire que le joueur a fabriquée **ressemble** enfin à ce qu'elle est.

Le prix à payer : épée, rapière et sabre partagent `lame_longue` et deviendraient identiques. La parade est un champ `variante_visuelle` sur l'objet (`droite`, `courbe`, `fine`) qui choisit laquelle des 3 formes du composant employer — une donnée, pas un dessin de plus.

**Règles de dessin d'un composant :**
- Canevas par slot : `tete` 48 × 96 px · `manche` 24 × 160 px (long) ou 24 × 80 px (court) · `garde` 56 × 24 px · `contrepoids` 32 × 32 px · `plaque` 72 × 96 px · `corde` et `sangles` 16 × 128 px.
- Origine au centre du bord bas = le point de jonction avec le composant du slot `manche`. Le manche porte l'ancrage `prise` à la hauteur de la main.
- Un composant = un matériau = **un fichier en gris**, teinté seul. C'est ce qui rend la règle des nuances de gris suffisante ici.

Le détail complet des 43 assemblages est en annexe.

### 5. Rigs non humanoïdes — ≈ 62 sprites

86 créatures se répartissent sur 6 rigs. Mêmes règles d'origine et de marqueurs.

| Rig | Créatures | Bibliothèque | px par segment |
|---|---|---|---|
| quadrupède | 32 | 4 torses, 6 têtes, 6 pattes, 4 pieds | torse 64×160 · tête 48×56 · patte 20×48 · pied 20×32 |
| volant | 17 | 4 torses, 4 têtes, 4 ailes | torse 48×80 · tête 32×32 · aile 40×112 |
| arachnide | 7 | 4 torses, 4 têtes, 4 pattes | torse 72×96 · tête 32×40 · patte 16×56 |
| amorphe | 6 | 6 corps entiers | 96×96 |
| serpentin | 3 | 4 têtes, 4 corps, 4 anneaux | tête 40×48 · corps 48×80 · anneau 40×64 |

### 6. Végétaux — 12 sprites

4 silhouettes (`feuillu`, `conifere`, `buisson`, `herbe`) × 3 variantes de forme. Billboards entiers, origine au centre du bord bas (le pied de la plante). Niveaux de gris : le feuillage est teinté par le matériau de l'essence. Taille de référence dans les données (`chene` : 40 × 30 unités → 240 × 320 px).

**Total ≈ 246 sprites** (56 corps + 28 têtes + 40 armure + 48 composants d'arme + 62 non-humanoïdes + 12 végétaux). L'estimation de 130 de la note ne comptait que l'humain de face et son armure — les têtes en couches, les 5 autres rigs, les armes et les végétaux s'ajoutent.

## BLOC D — Gabarit à instancier

```
[BLOC A]
[BLOC B]

Pièce demandée : {SEGMENT} — variante « {VARIANTE} »
Rig : {RIG}
Canevas : {L} × {H} px
Ancrages à marquer : {ANCRAGES}
Description : {une phrase — la forme, la matière apparente, ce qui distingue
cette variante des autres du même segment}
```

Exemple instancié :

```
Pièce demandée : torse — variante « robe de lettré »
Rig : humanoïde
Canevas : 72 × 112 px
Ancrages à marquer : cou (112,0) · épaule_G (96,-40) · hanche_G (0,-20) · dos (64,0)
Description : buste vêtu d'une robe croisée à col rond, ceinture nouée haut
sur la taille ; le drapé se résume à trois ou quatre grands plis en facettes
franches, le col est un tore aplati, la ceinture un anneau qui pince la
taille. Aucune armure, silhouette élancée.
```

---

## Trois points avant de lancer la production

1. **La cohérence d'éclairage est le vrai risque.** Un dessin au trait pardonne une lumière qui bouge ; un volume rendu, non — deux segments éclairés différemment se voient immédiatement au montage, et ça ne se rattrape pas au shader. C'est l'argument décisif pour le rendu 3D scripté plutôt que la génération d'images : une collection d'éclairage liée dans Blender rend le problème structurellement impossible.

2. **Les couleurs réservées ne sont pas encore dans les données.** La note les déclare dans `palette_materiaux.json → anchors` ; le fichier généré par `gen_palette.py` n'a pas cette section. Le script d'import n'a rien à lire tant qu'elle n'existe pas — à ajouter au générateur avant le premier import, sinon les marqueurs resteront visibles dans les sprites.

3. **Le contrat de remplacement.** `paperdoll.gd` dessine aujourd'hui chaque segment comme un rectangle procédural, et la DA du 2026-09-01 dit que le code doit rester *remplaçable* par une image. Le point d'entrée est `_placer()` / `_poser_segments()` : tant qu'un sprite respecte origine-au-bord-bas et axe vertical, il se substitue au rectangle sans toucher au rig, aux facings ni aux poses. Ça vaut la peine de valider le contrat sur **un seul segment** (le torse) avant de commander les 240 autres.

---

## Annexe — les 43 armes assemblées

Relevé de `godot/data/items/arme|bouclier|outil/`. Les `proto_*` sont les armes du prototype, sans composants (dureté et qualité fixées à la main).

| Arme | Mains | Composants (slot → composant) | Station / compétence |
|---|---|---|---|
| `arbalete` | 2 | tete → `pointe` · manche → `manche_long` · corde → `corde` | etabli / menuiserie |
| `arc` | 1 | tete → `lame_courte` · manche → `manche_long` · corde → `corde` | etabli / menuiserie |
| `arc_long` | 2 | tete → `pointe` · manche → `manche_long` · corde → `corde` | etabli / menuiserie |
| `baguette` | 1 | tete → `monture` · manche → `poignee` | etabli / menuiserie |
| `baton` | 2 | tete → `manche_long` · manche → `poignee` · contrepoids → `contrepoids` | etabli / menuiserie |
| `baton_magique` | 1 | tete → `pointe` · manche → `manche_long` | etabli / menuiserie |
| `bouclier` | 1 | plaque → `plaque` · sangles → `sangles` | etabli / forge |
| `cor` | 1 | tete → `monture` · manche → `manche_court` | etabli / menuiserie |
| `couteau_de_jet` | 1 | tete → `lame_courte` · manche → `poignee` | etabli / forge |
| `cymbales` | 1 | plaque → `plaque` · manche → `poignee` | forge / forge |
| `dague` | 1 | tete → `lame_courte` · manche → `poignee` · garde → `garde` | etabli / forge |
| `epee` | 1 | tete → `lame_longue` · manche → `poignee` · garde → `garde` | etabli / forge |
| `faucille` | 1 | tete → `lame_courte` · manche → `poignee` | etabli / menuiserie |
| `fleau` | 2 | tete → `tete_arme_lourde` · manche → `manche_court` · contrepoids → `contrepoids` | forge / forge |
| `flute` | 1 | tete → `monture` · manche → `manche_court` | etabli / menuiserie |
| `fouet` | 1 | tete → `sangles` · manche → `poignee` | etabli / tissage |
| `fronde` | 1 | tete → `sangles` · manche → `poignee` · corde → `corde` | etabli / tissage |
| `grimoire_de_main` | 2 | tete → `monture` · manche → `poignee` | table_enchantement / enchantement |
| `hache` | 1 | tete → `tete_outil` · manche → `manche_court` | etabli / menuiserie |
| `hache_d_armes` | 2 | tete → `tete_outil` · manche → `manche_long` · garde → `garde` | forge / forge |
| `hachette_de_jet` | 1 | tete → `tete_outil` · manche → `manche_court` | etabli / forge |
| `hallebarde` | 2 | tete → `pointe` · manche → `manche_long` · contrepoids → `contrepoids` | forge / forge |
| `javelot` | 1 | tete → `pointe` · manche → `manche_long` | etabli / menuiserie |
| `lance` | 2 | tete → `pointe` · manche → `manche_long` · garde → `garde` | etabli / forge |
| `luth` | 1 | tete → `monture` · manche → `manche_court` · corde → `corde` | atelier_tissage / menuiserie |
| `marteau_de_guerre` | 2 | tete → `tete_arme_lourde` · manche → `manche_long` · contrepoids → `contrepoids` | forge / forge |
| `masse` | 1 | tete → `tete_arme_lourde` · manche → `manche_court` · contrepoids → `contrepoids` | etabli / forge |
| `orbe` | 1 | tete → `monture` · manche → `poignee` | table_enchantement / enchantement |
| `pavois` | 2 | plaque → `plaque` · manche → `poignee` · sangles → `sangles` | forge / forge |
| `pelle` | 1 | tete → `tete_outil` · manche → `manche_court` | etabli / menuiserie |
| `pioche` | 1 | tete → `tete_outil` · manche → `manche_court` | etabli / menuiserie |
| `pique` | 2 | tete → `pointe` · manche → `manche_long` · garde → `garde` | etabli / forge |
| `pistolet` | 1 | tete → `pointe` · manche → `poignee` | forge / forge |
| `rapiere` | 1 | tete → `lame_longue` · manche → `poignee` · garde → `garde` | forge / forge |
| `sabre` | 1 | tete → `lame_longue` · manche → `poignee` · garde → `garde` | forge / forge |
| `sarbacane` | 1 | tete → `pointe` · manche → `manche_long` | etabli / menuiserie |
| `sceptre` | 1 | tete → `monture` · manche → `manche_court` | table_enchantement / enchantement |
| `seau` | 1 | tete → `plaque` · sangles → `sangles` | etabli / menuiserie |
| `stylet` | 1 | tete → `lame_courte` · manche → `poignee` · garde → `garde` | forge / forge |
| `talisman` | 1 | tete → `monture` | table_enchantement / enchantement |
| `tambour` | 2 | plaque → `etoffe` · sangles → `sangles` · doublure → `doublure` | atelier_tissage / tissage |
| `torche` | 1 | manche → `manche_court` · sangles → `sangles` | etabli / menuiserie |
| `vielle` | 2 | tete → `monture` · manche → `manche_court` · corde → `corde` | atelier_tissage / menuiserie |

## Liens
- **Dépend de** : [[Squelette modulaire et points d'attache]], [[Direction artistique]], [[Composants]], [[Recettes de composants]]
- **Alimente** : [[Objets — liste pour les sprites]], [[Palette de couleurs des matériaux]]
