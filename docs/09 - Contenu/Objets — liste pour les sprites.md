---
aliases: ["Liste des objets", "Sprites des objets"]
tags: [contenu, art, généré]
domaine: contenu
statut: décidé
etape: 1
---

> [!important] Demande du designer (2026-09-05) : « je vais générer les sprites des items, donne-moi la liste des armes avec leurs composants, pareil pour les outils, l'équipement et autres items »
> Cette note est **générée** par `tools/liste_objets.py` depuis `godot/data` et `locale/fr.csv` : rien n'y est écrit à la main, la relancer la remet à jour. Elle compte ce que le jeu sait fabriquer, ramasser ou poser, avec ce qui fait la silhouette d'un objet : son **type**, son **emplacement**, ses **composants** et les **familles de matériaux** que chaque composant accepte.
>
> **Où vont les sprites.** `godot/assets/objets/` ([[Direction artistique]], 2026-09-05). **On ne dessine pas les armes, on dessine les composants** : un objet assemblé (arme, outil, bouclier, armure, bijou, munition) n'a pas de sprite propre — son icône est composée des sprites de ses composants, `composants/<id>.png` (ou `composants/<id>_<variante>.png` quand l'objet porte `variante_visuelle` : épée droite, sabre courbe, rapière fine), chacun teinté par sa matière ; la colonne « sprite » de chaque table dit lesquels. Les objets qui ne s'assemblent pas (consommables, gemmes, livres, meubles, stations) sont un fichier `<id>.png` ; les matières, un fichier par forme dans `matieres/`. Gris neutre, carré, fond transparent ; le jeu prend un sprite dès qu'il existe et garde son pictogramme par code sinon ; `tools/verif_sprites.py` dit ce qui manque.
>
> **Ce qui fait un objet, pour le dessin.** Un objet assemblé est une *base* (épée, cuirasse, pioche) dont chaque *composant* est taillé dans un *matériau* — c'est le matériau qui donne la couleur ([[Palette de couleurs des matériaux]]) et la qualité qui donne l'état. Dessiner les composants, c'est donc dessiner toutes les armes à la fois : l'épée à lame d'os et poignée d'ivoire que le joueur a fabriquée ressemble à ce qu'elle est. Les objets `proto_*` sont les pièces de fortune du prototype (une matière fixe, pas de composants) : mêmes silhouettes que leurs bases assemblées. Le jeu dessine aujourd'hui des pictogrammes par code (`Pictos.dessiner_objet`, une case de 10 × 10 unités, avec des alias : sabre et rapière → épée, stylet → dague, hallebarde → lance, baguette → bâton magique…) — les sprites peuvent suivre ces regroupements ou distinguer chaque objet. Conventions : [[Direction artistique]] (lisibilité avant réalisme, teintes des cinq éléments) et le gabarit d'encrage `gabarit-encrage-sprites.pdf` dans ce dossier.

## 1. Les armes (42, dont 6 de fortune)

Par voie (la stat de la compétence de l'arme). Dés, type de dégâts et portée viennent de la fonctionnalité ; les composants et leurs matériaux des recettes de composants.

| Arme | id · sprite | Voie · compétence | Mains | Dés · type · portée | Composants (slot → composant — matériaux) |
|---|---|---|---|---|---|
| **Hache d'armes** | `craft_hache_d_armes`<br>`composants/tete_outil.png + composants/manche_long.png + composants/garde.png` | Force · Hache d'armes | 2 | 3d6 · tranchant · 1–1.5 | `tete` → **Tête d'outil** — lingot de métal, obsidienne taillée, os massif, roche taillée<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Marteau de guerre** | `craft_marteau_de_guerre`<br>`composants/tete_arme_lourde.png + composants/manche_long.png + composants/contrepoids.png` | Force · Masse | 2 | 4d6 · contondant · 1–1.5 | `tete` → **Tête d'arme lourde** — granit noir taillé, lingot de métal, météorite (lingot), roche taillée<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`contrepoids` → **Contrepoids** — lingot de métal, roche taillée |
| **Masse** | `craft_masse`<br>`composants/tete_arme_lourde.png + composants/manche_court.png + composants/contrepoids.png` | Force · Masse | 1 | 2d8 · contondant · 1–1.5 | `tete` → **Tête d'arme lourde** — granit noir taillé, lingot de métal, météorite (lingot), roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os<br>`contrepoids` → **Contrepoids** — lingot de métal, roche taillée |
| **Masse** *(fortune, fer)* | `proto_masse`<br>`— (pictogramme)` | Force · Masse | 1 | 2d8 · contondant · 1–1.5 | — |
| **Pavois** | `craft_pavois`<br>`composants/plaque.png + composants/poignee.png + composants/sangles.png` | Force · Masse | 2 | 2d4 · contondant · 1–1.5 | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie |
| **Sabre** | `craft_sabre`<br>`composants/lame_longue.png + composants/poignee.png + composants/garde.png · variante courbe` | Force · Épée | 1 | 1d12 · tranchant · 1–1.5 | `tete` → **Lame longue** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Épée** | `craft_epee`<br>`composants/lame_longue.png + composants/poignee.png + composants/garde.png · variante droite` | Force · Épée | 1 | 2d6 · tranchant · 1–1.5 | `tete` → **Lame longue** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Épée** *(fortune, fer)* | `proto_epee`<br>`— (pictogramme)` | Force · Épée | 1 | 2d6 · tranchant · 1–1.5 | — |
| **Couteaux de jet** | `craft_couteau_de_jet`<br>`composants/lame_courte.png + composants/poignee.png` | Dextérité · Armes de jet | 1 | 1d6 · perforant · 2–6.0 | `tete` → **Lame courte** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Dague** | `craft_dague`<br>`composants/lame_courte.png + composants/poignee.png + composants/garde.png` | Dextérité · Dague | 1 | 1d6 · perforant · 1–1.0 | `tete` → **Lame courte** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Dague** *(fortune, fer)* | `proto_dague`<br>`— (pictogramme)` | Dextérité · Dague | 1 | 1d6 · perforant · 1–1.0 | — |
| **Hachettes de jet** | `craft_hachette_de_jet`<br>`composants/tete_outil.png + composants/manche_court.png` | Dextérité · Armes de jet | 1 | 2d4 · tranchant · 2–5.0 | `tete` → **Tête d'outil** — lingot de métal, obsidienne taillée, os massif, roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Javelots** | `craft_javelot`<br>`composants/pointe.png + composants/manche_long.png` | Dextérité · Armes de jet | 1 | 2d6 · perforant · 2–8.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os |
| **Rapière** | `craft_rapiere`<br>`composants/lame_longue.png + composants/poignee.png + composants/garde.png · variante fine` | Dextérité · Escrime | 1 | 1d10 · perforant · 1–1.5 | `tete` → **Lame longue** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Stylet** | `craft_stylet`<br>`composants/lame_courte.png + composants/poignee.png + composants/garde.png` | Dextérité · Dague | 1 | 1d4 · perforant · 1–1.0 | `tete` → **Lame courte** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Bâton** | `craft_baton`<br>`composants/manche_long.png + composants/poignee.png + composants/contrepoids.png` | Endurance · Bâton | 2 | 2d4 · contondant · 1–2.0 | `tete` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`contrepoids` → **Contrepoids** — lingot de métal, roche taillée |
| **Fléau** | `craft_fleau`<br>`composants/tete_arme_lourde.png + composants/manche_court.png + composants/contrepoids.png` | Endurance · Armes à chaîne | 2 | 2d8 · contondant · 1–2.0 | `tete` → **Tête d'arme lourde** — granit noir taillé, lingot de métal, météorite (lingot), roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os<br>`contrepoids` → **Contrepoids** — lingot de métal, roche taillée |
| **Fouet** | `craft_fouet`<br>`composants/sangles.png + composants/poignee.png` | Endurance · Fouet | 1 | 1d4 · tranchant · 2–3.0 | `tete` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Hallebarde** | `craft_hallebarde`<br>`composants/pointe.png + composants/manche_long.png + composants/contrepoids.png` | Endurance · Armes d'hast | 2 | 2d8 · tranchant · 2–2.5 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`contrepoids` → **Contrepoids** — lingot de métal, roche taillée |
| **Lance** | `craft_lance`<br>`composants/pointe.png + composants/manche_long.png + composants/garde.png` | Endurance · Lance | 2 | 2d8 · perforant · 2–2.5 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Lance** *(fortune, frene)* | `proto_lance`<br>`— (pictogramme)` | Endurance · Lance | 2 | 2d8 · perforant · 2–2.5 | — |
| **Pique** | `craft_pique`<br>`composants/pointe.png + composants/manche_long.png + composants/garde.png` | Endurance · Armes d'hast | 2 | 2d6 · perforant · 2–3.5 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`garde` → **Garde** — lingot de métal, os |
| **Baguette** | `craft_baguette`<br>`composants/monture.png + composants/poignee.png` | Volonté · Contrôle du mana | 1 | 1d4 · perforant · 1–1.5 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Bâton magique** | `craft_baton_magique`<br>`composants/pointe.png + composants/manche_long.png` | Volonté · Bâton magique | 1 | 1d4 · contondant · 1–1.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os |
| **Bâton magique** *(fortune, chene)* | `proto_baton_magique`<br>`— (pictogramme)` | Volonté · Bâton magique | 1 | 1d4 · contondant · 1–1.0 | — |
| **Grimoire de main** | `craft_grimoire_de_main`<br>`composants/monture.png + composants/poignee.png` | Volonté · Contrôle du mana | 2 | 1d3 · contondant · 1–1.0 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Orbe** | `craft_orbe`<br>`composants/monture.png + composants/poignee.png` | Volonté · Contrôle du mana | 1 | 1d3 · contondant · 1–1.0 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Sceptre** | `craft_sceptre`<br>`composants/monture.png + composants/manche_court.png` | Volonté · Contrôle du mana | 1 | 1d6 · contondant · 1–1.5 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Talisman** | `craft_talisman`<br>`composants/monture.png` | Volonté · Contrôle du mana | 1 | 1d3 · contondant · 1–1.0 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os |
| **Arbalète** | `craft_arbalete`<br>`composants/pointe.png + composants/manche_long.png + composants/corde.png` | Perception · Arbalète | 2 | 3d6 · perforant · 2–22.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |
| **Arc** | `craft_arc`<br>`composants/lame_courte.png + composants/manche_long.png + composants/corde.png` | Perception · Arc | 1 | 2d6 · perforant · 2–25.0 | `tete` → **Lame courte** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |
| **Arc** *(fortune, if)* | `proto_arc`<br>`— (pictogramme)` | Perception · Arc | 2 | 2d6 · perforant · 2–25.0 | — |
| **Arc long** | `craft_arc_long`<br>`composants/pointe.png + composants/manche_long.png + composants/corde.png` | Perception · Précision | 2 | 2d8 · perforant · 3–30.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |
| **Fronde** | `craft_fronde`<br>`composants/sangles.png + composants/poignee.png + composants/corde.png` | Perception · Fronde | 1 | 1d8 · contondant · 3–14.0 | `tete` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |
| **Pistolet** | `craft_pistolet`<br>`composants/pointe.png + composants/poignee.png` | Perception · Armes à poudre | 1 | 3d8 · perforant · 2–12.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Sarbacane** | `craft_sarbacane`<br>`composants/pointe.png + composants/manche_long.png` | Perception · Précision | 1 | 1d4 · perforant · 2–9.0 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche long** — bois (planche), ivoire, lingot de métal, os |
| **Cor** | `craft_cor`<br>`composants/monture.png + composants/manche_court.png` | Charisme · Musique | 1 | 1d3 · contondant · 1–1.0 · zone 4 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Cymbales** | `craft_cymbales`<br>`composants/plaque.png + composants/poignee.png` | Charisme · Musique | 1 | 1d8 · contondant · 1–1.0 · zone 1 | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Flûte** | `craft_flute`<br>`composants/monture.png + composants/manche_court.png` | Charisme · Musique | 1 | 1d3 · contondant · 1–1.0 · zone 3 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Luth** | `craft_luth`<br>`composants/monture.png + composants/manche_court.png + composants/corde.png` | Charisme · Musique | 1 | 1d4 · contondant · 1–1.0 · zone 2 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |
| **Tambour** | `craft_tambour`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Charisme · Musique | 2 | 1d6 · contondant · 1–1.0 · zone 3 | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Vielle** | `craft_vielle`<br>`composants/monture.png + composants/manche_court.png + composants/corde.png` | Charisme · Musique | 2 | 2d4 · contondant · 1–1.0 · zone 2 | `tete` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os<br>`corde` → **Corde** — fibre (lin, chanvre, coton), soie |

## 2. Les outils (11) et les boucliers (2)

| Outil | id · sprite | Fonction | Mains · emplacement | Composants |
|---|---|---|---|---|
| **Faucille** | `craft_faucille`<br>`composants/lame_courte.png + composants/poignee.png` | Faucille | 1 · Main principale | `tete` → **Lame courte** — lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre<br>`manche` → **Poignée** — bois (planche), ivoire, lingot de métal, os |
| **Faucille de fer** *(fortune, fer)* | `proto_faucille`<br>`— (pictogramme)` | Faucille | 1 · Main principale | — |
| **Hache** | `craft_hache`<br>`composants/tete_outil.png + composants/manche_court.png` | Hache | 1 · Main principale | `tete` → **Tête d'outil** — lingot de métal, obsidienne taillée, os massif, roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Hache de fer** *(fortune, fer)* | `proto_hache`<br>`— (pictogramme)` | Hache | 1 · Main principale | — |
| **Pelle** | `craft_pelle`<br>`composants/tete_outil.png + composants/manche_court.png` | Pelle | 1 · Main principale | `tete` → **Tête d'outil** — lingot de métal, obsidienne taillée, os massif, roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Pelle de fer** *(fortune, fer)* | `proto_pelle`<br>`— (pictogramme)` | Pelle | 1 · Main principale | — |
| **Pioche** | `craft_pioche`<br>`composants/tete_outil.png + composants/manche_court.png` | Pioche | 1 · Main principale | `tete` → **Tête d'outil** — lingot de métal, obsidienne taillée, os massif, roche taillée<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Pioche de fer** *(fortune, fer)* | `proto_pioche`<br>`— (pictogramme)` | Pioche | 1 · Main principale | — |
| **Seau** | `craft_seau`<br>`composants/plaque.png + composants/sangles.png` | Seau | 1 · Main principale | `tete` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie |
| **Seau de bois** *(fortune, chene)* | `proto_seau`<br>`— (pictogramme)` | Seau | 1 · Main principale | — |
| **Torche** | `torche`<br>`composants/manche_court.png + composants/sangles.png` | — · lumière 70 | 1 · Main secondaire | `manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie |
| **Bouclier** | `craft_bouclier`<br>`composants/plaque.png + composants/sangles.png` | Bouclier · bras, plaque | 1 · Main secondaire | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie |
| **Bouclier** *(fortune, chene)* | `proto_bouclier`<br>`— (pictogramme)` | Bouclier | 1 · Main secondaire | — |

## 3. Armures et vêtements (21)

L'emplacement dit où la pièce se porte, la zone ce qu'elle couvre, la construction sa matière dominante (plaque, tissu, matelassé, rituel, cuir, mailles). Les vêtements ont une *étoffe* là où les armures ont une *plaque*.

| Pièce | id · sprite | Emplacement · zone | Construction | Composants |
|---|---|---|---|---|
| **Bottes** | `craft_bottes`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Bottes · pieds | plaque | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Brassards** | `craft_brassards`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Brassards · bras | plaque | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Cape** | `cape`<br>`cape.png` | Dos · torse | matelassée | dos, cape |
| **Capuche** | `craft_capuche`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Casque · tête | tissu | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Casque** | `craft_casque`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Casque · tête | plaque | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Casque de cuir** *(fortune, cuir)* | `proto_casque_cuir`<br>`— (pictogramme)` | Casque · tête | cuir | fortune |
| **Casque de fer** *(fortune, fer)* | `proto_casque_fer`<br>`— (pictogramme)` | Casque · tête | plaque | fortune |
| **Chausses** | `craft_chausses`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Jambières · jambes | tissu | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Chaussons** | `craft_chaussons`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Bottes · pieds | tissu | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Coiffe** | `craft_coiffe`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Casque · tête | rituel | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Cuirasse** | `craft_cuirasse`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Cuirasse · torse | plaque | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Cuirasse de cuir** *(fortune, cuir)* | `proto_cuirasse_cuir`<br>`— (pictogramme)` | Cuirasse · torse | cuir | fortune |
| **Cuirasse de mailles** *(fortune, fer)* | `proto_cuirasse_mailles`<br>`— (pictogramme)` | Cuirasse · torse | mailles | fortune |
| **Gambison** | `craft_gambison`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Cuirasse · torse | matelassée | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Jambières** | `craft_jambieres`<br>`composants/plaque.png + composants/sangles.png + composants/doublure.png` | Jambières · jambes | plaque | `plaque` → **Plaque** — écaille, lingot de métal, os massif<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Jambières de cuir** *(fortune, cuir)* | `proto_jambieres_cuir`<br>`— (pictogramme)` | Jambières · jambes | cuir | fortune |
| **Manchettes** | `craft_manchettes`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Brassards · bras | tissu | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Robe** | `craft_robe`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Cuirasse · torse | rituel | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Sac à dos** | `sac_a_dos`<br>`sac_a_dos.png` | Dos · torse | matelassée | dos, sac |
| **Tunique** | `craft_tunique`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Cuirasse · torse | tissu | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |
| **Étole** | `craft_etole`<br>`composants/etoffe.png + composants/sangles.png + composants/doublure.png` | Dos · torse | rituel | `plaque` → **Étoffe** — cuir, fibre (lin, chanvre, coton), soie<br>`sangles` → **Sangles** — cuir, fibre (lin, chanvre, coton), soie<br>`doublure` → **Doublure** — cuir, fibre (lin, chanvre, coton) |

## 4. Bijoux (4) et gemmes (10)

| Bijou | id · sprite | Emplacement | Composants |
|---|---|---|---|
| **Amulette** | `craft_amulette`<br>`composants/monture.png + composants/sertissure.png` | Amulette | `monture` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`sertissure` → **Sertissure** — fibre (lin, chanvre, coton), lingot de métal |
| **Amulette** *(fortune, or)* | `proto_amulette`<br>`— (pictogramme)` | Amulette | — |
| **Anneau** | `craft_anneau`<br>`composants/monture.png + composants/sertissure.png` | Anneau | `monture` → **Monture** — lingot de métal, or ou argent (lingot), os<br>`sertissure` → **Sertissure** — fibre (lin, chanvre, coton), lingot de métal |
| **Anneau** *(fortune, argent)* | `proto_anneau`<br>`— (pictogramme)` | Anneau | — |

Une gemme se sertit dans la sertissure d'un bijou ; sa couleur est celle de son élément quand elle en a un.

| Gemme | id · sprite | Matériau | Élément | Ce qu'elle porte |
|---|---|---|---|---|
| **Ambre** | `gemme_ambre`<br>`gemme_ambre.png` | Ambre | — | endurance_max, Athlétisme, Esquive |
| **Améthyste** | `gemme_amethyste`<br>`gemme_amethyste.png` | Améthyste | — | mana_max, Méditation |
| **Diamant** | `gemme_diamant`<br>`gemme_diamant.png` | Diamant | — | qualite |
| **Grenat** | `gemme_grenat`<br>`gemme_grenat.png` | Grenat | — | sante_max, Force, Endurance |
| **Onyx** | `gemme_onyx`<br>`gemme_onyx.png` | Onyx | Métal | dégâts Métal, Métal, affinite |
| **Opale** | `gemme_opale`<br>`gemme_opale.png` | Opale | — | duree_statuts, Volonté, Charisme |
| **Rubis** | `gemme_rubis`<br>`gemme_rubis.png` | Rubis | Feu | dégâts Feu, Feu, affinite |
| **Saphir** | `gemme_saphir`<br>`gemme_saphir.png` | Saphir | Eau | dégâts Eau, Eau/Glace, affinite |
| **Topaze** | `gemme_topaze`<br>`gemme_topaze.png` | Topaze | Terre | dégâts Terre, Terre, affinite |
| **Émeraude** | `gemme_emeraude`<br>`gemme_emeraude.png` | Émeraude | Bois | dégâts Bois, Foudre/Vie, affinite |

## 5. Munitions (6)

| Munition | id | Par pile | Composants |
|---|---|---|---|
| **Balles** | `craft_balles` | 10 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé |
| **Billes** | `craft_billes` | 30 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé |
| **Carreaux** | `craft_carreaux` | 15 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Flèches** | `craft_fleches` | 20 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé<br>`manche` → **Manche court** — bois (planche), ivoire, lingot de métal, os |
| **Flèches** *(fortune)* | `proto_fleches` | 20 | bois |
| **Fléchettes** | `craft_flechettes` | 25 | `tete` → **Pointe** — dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé |

## 6. Les composants (17)

Chaque composant est une pièce à part entière (elle se fabrique, se ramasse, se stocke) : un sprite par composant, teinté par sa matière.

| Composant | id · sprite | Slot | Familles de matériaux | Station | Sert à |
|---|---|---|---|---|---|
| **Contrepoids** | `contrepoids`<br>`composants/contrepoids.png` | contrepoids | lingot de métal, roche taillée | enclume, tailleur_de_pierre | Masse, Marteau de guerre, Fléau, Bâton |
| **Corde** | `corde`<br>`composants/corde.png` | corde | fibre (lin, chanvre, coton), soie | atelier_tissage | Arc, Arbalète, Fronde, Vielle |
| **Doublure** | `doublure`<br>`composants/doublure.png` | doublure | cuir, fibre (lin, chanvre, coton) | atelier_tissage, tannerie | Cuirasse, Casque, Brassards, Jambières, Bottes, Gambison |
| **Garde** | `garde`<br>`composants/garde.png` | garde | lingot de métal, os | enclume, tailleur_de_pierre | Épée, Sabre, Rapière, Dague, Lance, Hache d'armes |
| **Lame courte** | `lame_courte`<br>`composants/lame_courte.png` | tete | lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre | enclume, etabli, tailleur_de_pierre | Dague |
| **Lame longue** | `lame_longue`<br>`composants/lame_longue.png` | tete | lingot de métal, obsidienne taillée, or ou argent (lingot), os, verre | enclume, etabli, tailleur_de_pierre | Épée |
| **Manche court** | `manche_court`<br>`composants/manche_court.png` | manche | bois (planche), ivoire, lingot de métal, os | enclume, etabli, scierie | Pioche, Masse, Dague, Flûte, Vielle |
| **Manche long** | `manche_long`<br>`composants/manche_long.png` | manche | bois (planche), ivoire, lingot de métal, os | enclume, etabli, scierie | Lance |
| **Monture** | `monture`<br>`composants/monture.png` | monture | lingot de métal, or ou argent (lingot), os | enclume, etabli | Flûte, Vielle |
| **Plaque** | `plaque`<br>`composants/plaque.png` | plaque | écaille, lingot de métal, os massif | enclume, etabli | Cymbales |
| **Poignée** | `poignee`<br>`composants/poignee.png` | manche | bois (planche), ivoire, lingot de métal, os | enclume, etabli, scierie | Épée, Dague, Cymbales |
| **Pointe** | `pointe`<br>`composants/pointe.png` | tete | dent ou croc, lingot de métal, obsidienne taillée, os, silex taillé | enclume, etabli, tailleur_de_pierre | Lance, Arc |
| **Sangles** | `sangles`<br>`composants/sangles.png` | sangles | cuir, fibre (lin, chanvre, coton), soie | atelier_tissage | — |
| **Sertissure** | `sertissure`<br>`composants/sertissure.png` | sertissure | fibre (lin, chanvre, coton), lingot de métal | atelier_tissage, enclume | Anneau, Amulette |
| **Tête d'arme lourde** | `tete_arme_lourde`<br>`composants/tete_arme_lourde.png` | tete | granit noir taillé, lingot de métal, météorite (lingot), roche taillée | enclume, tailleur_de_pierre | Masse |
| **Tête d'outil** | `tete_outil`<br>`composants/tete_outil.png` | tete | lingot de métal, obsidienne taillée, os massif, roche taillée | enclume, etabli, tailleur_de_pierre | Pioche |
| **Étoffe** | `etoffe`<br>`composants/etoffe.png` | plaque | cuir, fibre (lin, chanvre, coton), soie | atelier_tissage, tannerie | Tunique, Robe, Capuche, Coiffe, Chausses, Manchettes, Chaussons, Étole |

## 7. Livres et parchemins (6)

| Objet | id | Type | Tags |
|---|---|---|---|
| **Livre de module** | `livre_module` | manuel | livre, module_unique |
| **Manuel** | `manuel` | manuel | livre |
| **Plan industriel** | `plan_industriel` | manuel | livre, plan |
| **Trame — {grille}** | `trame` | manuel | livre, trame |
| **Grimoire** | `grimoire` | grimoire | livre |
| **Parchemin** | `parchemin` | parchemin | empilable |

## 8. Consommables (67)

Une potion non identifiée se montre comme une **fiole** d'une des 8 apparences : trouble, irisée, fumeuse, laiteuse, sombre, pétillante, terne, ambrée. Identifiée, elle prend le nom de son distillat. Les ingrédients (herbes, champignons, cultures, parties de bêtes) sont ce qu'on cueille, récolte ou dépèce.

### Potions (fioles) (14)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Antipoison** | `potion_antipoison` | potion | — | — |
| **Poison de lame** | `poison_de_lame` | potion | — | — |
| **Potion de charisme** | `potion_charisme` | potion | — | — |
| **Potion de dextérité** | `potion_dexterite` | potion | — | — |
| **Potion de force** | `potion_force` | potion | — | — |
| **Potion de mana** | `potion_mana` | potion | — | — |
| **Potion de perception** | `potion_perception` | potion | — | — |
| **Potion de respiration aquatique** | `potion_respiration_aquatique` | potion | — | — |
| **Potion de résistance au feu** | `potion_resistance_feu` | potion | — | — |
| **Potion de résistance au froid** | `potion_resistance_froid` | potion | — | — |
| **Potion de soin** | `potion_soin` | potion | — | — |
| **Potion de vigueur** | `potion_endurance` | potion | — | — |
| **Potion de vision nocturne** | `potion_vision_nocturne` | potion | — | — |
| **Potion de volonté** | `potion_volonte` | potion | — | — |

### Plats cuisinés (5)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Pain** | `pain` | plat | Bois 60 %, Terre 25 %, Feu 15 % | — |
| **Poisson grillé** | `poisson_grille` | plat | Eau 80 %, Bois 20 % | — |
| **Ragoût** | `ragout` | plat | Bois 50 %, Eau 50 % | — |
| **Ration de voyage** | `ration_de_voyage` | plat | Bois 50 %, Eau 50 % | — |
| **Viande grillée** | `viande_grillee` | plat, viande | Bois 50 %, Eau 50 % | — |

### Viandes (1)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Viande crue** | `viande_crue` | viande | Bois 50 %, Eau 50 % | — |

### Cultures (récoltes des champs) (12)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Blé** | `ble` | culture, ingrédient | Bois 70 %, Terre 30 % | — |
| **Carotte** | `carotte` | culture, ingrédient | Terre 60 %, Bois 40 % | — |
| **Chou** | `chou` | culture, ingrédient | Bois 80 %, Eau 20 % | — |
| **Citrouille** | `citrouille` | culture, ingrédient | Terre 50 %, Bois 50 % | — |
| **Framboisier** | `framboisier` | buisson, ingrédient, culture | Bois 80 %, Eau 20 % | — |
| **Houblon** | `houblon` | buisson, ingrédient, culture | Bois 80 %, Terre 20 % | — |
| **Myrtillier** | `myrtillier` | buisson, ingrédient, culture | Bois 70 %, Eau 30 % | — |
| **Oignon** | `oignon` | culture, ingrédient | Feu 50 %, Terre 50 % | — |
| **Orge** | `orge` | culture, ingrédient | Bois 70 %, Terre 30 % | — |
| **Pomme de terre** | `pomme_de_terre` | culture, ingrédient | Terre 70 %, Bois 30 % | — |
| **Tomate** | `tomate` | culture, ingrédient | Bois 50 %, Eau 50 % | — |
| **Vigne** | `vigne` | buisson, ingrédient, culture | Bois 60 %, Feu 20 %, Terre 20 % | — |

### Herbes, champignons et buissons (cueillette) (10)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Achillée** | `achillee` | herbe, ingrédient | Bois 70 %, Terre 30 % | Potion de soin |
| **Amanite** | `amanite` | champignon, ingrédient, herbe | Terre 50 %, Feu 30 %, Eau 20 % | Poison de lame |
| **Belladone** | `belladone` | herbe, ingrédient | Bois 50 %, Eau 30 %, Terre 20 % | Potion de vision nocturne |
| **Camomille** | `camomille` | herbe, ingrédient | Bois 60 %, Eau 40 % | Antipoison |
| **Champignon des prés** | `champignon_des_pres` | champignon, ingrédient | Terre 60 %, Eau 40 % | — |
| **Fleurs sauvages** | `fleurs_sauvages` | décoratif, ingrédient, herbe | Bois 60 %, Feu 40 % | Potion de charisme |
| **Menthe** | `menthe` | herbe, ingrédient | Bois 50 %, Eau 50 % | Potion de résistance au feu |
| **Ortie** | `ortie` | herbe, ingrédient | Bois 80 %, Feu 20 % | Potion de résistance au froid |
| **Roseau** | `roseau` | décoratif, ingrédient, herbe | Bois 50 %, Eau 50 % | Potion de respiration aquatique |
| **Sauge** | `sauge` | herbe, ingrédient | Bois 60 %, Métal 20 %, Eau 20 % | Potion de mana |

### Parties de créatures (10)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Carapace** | `carapace` | ingrédient, partie | — | Potion de vigueur |
| **Corne** | `corne` | ingrédient, partie | — | Potion de force |
| **Dent** | `dent` | ingrédient, partie | — | Potion de dextérité |
| **Défense** | `defense` | ingrédient, partie | — | Potion de dextérité |
| **Griffe** | `griffe` | ingrédient, partie | — | Potion de force |
| **Os** | `os` | ingrédient, partie | — | Potion de volonté |
| **Peau** | `peau` | ingrédient, partie | — | Potion de vigueur |
| **Plume** | `plume` | ingrédient, partie | — | Potion de perception |
| **Écaille** | `ecaille` | ingrédient, partie | — | Potion de dextérité |
| **Œil** | `oeil` | ingrédient, partie | — | Potion de perception |

### Autres (15)

| Objet | id | Tags | Élément(s) | Distillat |
|---|---|---|---|---|
| **Antidote** | `antidote` | soin | — | — |
| **Baies** | `baies` | ingrédient | Bois 60 %, Eau 40 % | — |
| **Bandage** | `bandage` | soin | — | — |
| **Bombe** | `bombe` | bombe | — | — |
| **Champignon bleu** | `champignon_bleu` | ingrédient | Terre 60 %, Bois 40 % | — |
| **Essence de mana** | `essence_de_mana` | — | — | — |
| **Fiole de soin** | `fiole_de_soin` | soin | — | — |
| **Fruit de mana** | `fruit_de_mana` | — | — | — |
| **Grande fiole de soin** | `grande_fiole_de_soin` | soin | — | — |
| **Huile d'arme** | `huile_d_arme` | — | — | — |
| **Miel** | `miel` | ingrédient | Bois 60 %, Terre 40 % | — |
| **Ration moisie** | `ration_moisie` | — | — | — |
| **Spécimen** | `specimen` | spécimen, élevage | — | — |
| **Âme d'un compagnon** | `ame` | âme | — | — |
| **Élixir de hâte** | `elixir_de_hate` | — | — | — |

## 9. Les matériaux : 245 matières, 6 formes

Une matière brute ou transformée est un objet empilable : un sprite par **forme** (teinté par la matière) suffit — `assets/objets/matieres/<forme>.png`. Formes : `brut`, `lingot`, `pierre_taillee`, `planche`, `taillee`, `tissu`.

| Catégorie | Matières |
|---|---|
| **animal** (20) | Boyau, Carapace, Corne, Crin, Cuir, Fourrure, Laine, Os, Os de seiche, Os massif, Plume, Soie, Soie d'araignée, Suif, Tendon, Vessie, croc, ivoire, Éponge, écaille |
| **bois** (40) | Acacia, Acajou, Aulne, Balsa, Bambou, Bois calciné, Bois flotté, Bouleau, Buis, Cerisier, Charme, Châtaignier, Chêne, Cyprès, Cèdre, Eucalyptus, Frêne, Gaïac, Hêtre, If, Liège (chêne-liège), Mélèze, Noisetier, Noyer, Olivier, Orme, Palmier (stipe), Peuplier, Pin, Platane, Pommier, Robinier (faux acacia), Sapin, Saule, Séquoia, Teck, Tilleul, Ébène, Épicéa, Érable |
| **fossile** (10) | Ammonite, Bois pétrifié, Coquillage fossile, Corail, Dent fossile, Géode, Météorite ferreuse, Nacre, Os fossile, Trilobite |
| **gemme** (15) | Agate, Aigue-marine, Améthyste, Diamant, Grenat, Jade, Onyx, Opale, Perle, Quartz, Rubis, Saphir, Topaze, Tourmaline, Émeraude |
| **liquide** (18) | Alcool, Boue, Eau, Eau salée, Encre, Essence de térébenthine, Goudron, Huile, Lait, Lave, Lessive de cendre, Mercure, Miel, Sang, Saumure, Sève, Venin, Vinaigre |
| **métal** (32) | Acier, Acier au tungstène, Acier au vanadium, Acier damassé, Acier inoxydable, Acier trempé, Aluminium (bauxite), Antimoine, Argent, Bismuth, Bronze, Chrome (chromite), Cobalt, Cuivre, Fer, Fonte, Laiton, Magnésium, Maillechort, Manganèse, Molybdène, Nickel, Or, Palladium, Platine, Plomb, Titane, Tungstène, Vanadium, Zinc, Électrum, Étain |
| **météorologique** (4) | Givre, Glace, Grêle, Neige |
| **minéral** (31) | Alun, Ambre, Amiante, Anthracite, Argile réfractaire, Azurite, Bitume, Borax, Chaux, Cinabre, Fluorine, Galène, Graphite, Guano/salpêtre de grotte, Houille, Hématite, Lapis-lazuli, Lignite, Magnétite, Malachite, Mica, Ocre, Phosphorite, Potasse, Pyrite, Salpêtre, Sel gemme, Sel marin, Soufre, Tourbe compactée, Turquoise |
| **roche** (29) | Andésite, Ardoise, Basalte, Brèche volcanique, Calcaire, Calcite (spath), Conglomérat, Craie, Diorite, Dolomie, Gneiss, Granit, Granit noir (gabbro), Grès, Gypse, Kimberlite, Marbre, Obsidienne, Pierre, Pierre de lave, Pierre ponce, Péridotite, Quartzite, Rhyolite, Schiste, Serpentinite, Silex, Travertin, Tuf volcanique |
| **synthétique** (19) | Brique, Brique réfractaire, Béton, Caoutchouc, Charbon de bois, Chaume tressé, Cire, Colle d'os, Cuir bouilli, Feutre, Papier, Parchemin, Plâtre, Poix, Porcelaine, Savon, Scorie, Verre, Verre trempé |
| **terre** (12) | Argile, Cendre, Gravier, Humus, Latérite, Limon, Marne, Sable, Sable noir, Terre, Terre fertile, Tourbe |
| **végétal et fibre** (15) | Amidon, Chanvre, Coton, Gomme arabique, Jute, Latex, Lin, Osier, Paille, Rotin, Résine, Sisal, Tanin, Varech, Écorce |

## 10. Meubles (25) et stations portatives (11)

Un meuble se pose sur une tuile (il a une emprise et parfois une lumière) ; une station portative se porte dans le sac et se pose pour fabriquer. Les matières de recette disent de quoi ils ont l'air.

| Meuble | id | Recette (matières) | Lumière · bloque le passage |
|---|---|---|---|
| **Autel domestique** | `meuble_autel_domestique` | 4 roche (pierre taillée), 1 gemme (taillée) | 10 · oui |
| **Bassin** | `meuble_bassin` | 2 bois (planche), 1 roche (bloc) | — · oui |
| **Bibliothèque** | `meuble_bibliotheque` | 4 bois (planche) | — · oui |
| **Chaise** | `meuble_chaise` | 1 bois (planche) | — · oui |
| **Cheminée** | `meuble_cheminee` | 4 roche (pierre taillée) | 40 · oui |
| **Clayette à vers** | `meuble_clayette` | 3 bois (planche) | — · oui |
| **Coffre** | `meuble_coffre` | 3 bois (planche), 1 métal (lingot) | — · oui |
| **Enclos** | `meuble_enclos` | 3 bois (planche) | — · oui |
| **Garde-manger** | `meuble_garde_manger` | 3 bois (planche) | — · oui |
| **Grand coffre** | `meuble_grand_coffre` | 6 bois (planche), 2 métal (lingot) | — · oui |
| **Hall de guilde** | `meuble_hall_de_guilde` | 6 bois (planche) | 1 · oui |
| **Lanterne de cristal** | `meuble_lanterne_de_cristal` | 1 gemme (taillée), 1 métal (lingot) | 95 · oui |
| **Lit** | `meuble_lit` | 3 bois (planche), 2 végétal et fibre (tissu) | — · oui |
| **Lit de paille** | `meuble_lit_de_paille` | 2  (brut), 1 bois (planche) | — · oui |
| **Rucher** | `meuble_rucher` | 3 bois (planche) | — · oui |
| **Râtelier d'armes** | `meuble_ratelier_d_armes` | 3 bois (planche), 1 métal (lingot) | — · oui |
| **Statue** | `meuble_statue` | — | — · oui |
| **Table** | `meuble_table` | 2 bois (planche) | — · oui |
| **Tapis** | `meuble_tapis` | 2 végétal et fibre (tissu), 1  () | — · non |
| **Terrarium** | `meuble_terrarium` | 3 bois (planche) | — · oui |
| **Torchère** | `meuble_torchere` | 1 métal (lingot), 1 bois (planche) | 80 · oui |
| **Tourelle** | `meuble_tourelle` | 4 bois (planche), 2 métal (lingot) | — · oui |
| **Trophée** | `meuble_trophee` | 2 bois (planche), 1  () | — · oui |
| **Vivarium** | `meuble_vivarium` | 3 bois (planche) | 1 · oui |
| **Étal de vente** | `meuble_etal_de_vente` | 3 bois (planche) | — · oui |

| Station | id | Recette (matières) | Compétence |
|---|---|---|---|
| **Alambic** | `station_alambic` | 2 métal (lingot), 2 bois (planche) | Alchimie |
| **Atelier de tissage** | `station_atelier_tissage` | 4 bois (planche), 2 végétal et fibre (tissu) | Tissage |
| **Billot de boucher** | `station_billot_de_boucher` | 3 bois (planche), 1 métal (lingot) | Cuisine |
| **Cuisine** | `station_cuisine` | 4 roche (pierre taillée), 1 métal (lingot) | Cuisine |
| **Enclume** | `station_enclume` | 4 métal (lingot) | Forge |
| **Forge** | `station_forge` | 6 roche (pierre taillée), 2 métal (lingot) | Forge |
| **Scierie** | `station_scierie` | 4 bois (planche), 2 métal (lingot) | Menuiserie |
| **Table d'enchantement** | `station_table_enchantement` | 4 bois (planche), 2 gemme (taillée) | Enchantement |
| **Tailleur de pierre** | `station_tailleur_de_pierre` | 3 roche (pierre taillée) | Taille de pierre |
| **Tannerie** | `station_tannerie` | 4 bois (planche), 2 animal (brut) | Cuir |
| **Établi** | `station_etabli` | 4 bois (planche) | Menuiserie |

## Liens
- [[Composants]] · [[Recettes de composants]] · [[Palette de couleurs des matériaux]] · [[Direction artistique]] · [[Potions]] · [[Nourriture]] · [[Meubles]] · [[Effets d'équipement types]]
