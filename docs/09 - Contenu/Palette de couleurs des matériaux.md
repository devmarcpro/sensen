---
aliases: ["F.1.1", "Annexe F.1.1", "Palette", "Couleurs des matériaux", "Palette de couleurs"]
tags: [contenu, matériaux, art, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 1
---

> [!note] Adapté au pivot tactique
> Adapté au pivot : le bruit et le remapping de palette s'appliquent par tuile/pixel — mécanisme inchangé.

Chaque hex est unique dans le catalogue — un doublon est une erreur bloquante de données.

*Chaque hex est unique dans le catalogue. Familles de teintes par catégorie pour la lisibilité (bois = bruns, métaux = gris/métalliques, cristaux = saturés...) ; les nuances proches se départagent en jeu par leur bruit.*

**Bois :** Pin #C8A96E · Sapin #CBB183 · Épicéa #D6BC8A · Mélèze #B98D5C · Cèdre #B57452 · Chêne #8B5A2B · Hêtre #C69C6D · Bouleau #E3CDA4 · Érable #D2A46B · Frêne #CFB489 · Orme #9C7248 · If #A66A3A · Noyer #6B4426 · Cerisier #9E4F32 · Olivier #8A7B4A · Ébène #2B211C · Gaïac #4A3B23 · Acajou #7C3B24 · Teck #8F6236 · Balsa #EFDFBC · Bambou #B9BA6D · Saule #A89A6B · Liège #B08D62 · Peuplier #DCC79B · Tilleul #E8D9B0 · Charme #C2AD85 · Robinier #A98A3F · Châtaignier #93683B · Platane #C79B72 · Aulne #B57B54 · Buis #D9C27E · Cyprès #A28A55 · Séquoia #A0522D · Palmier #C4A05A · Acacia #B4763B · Eucalyptus #A9997A · Pommier #A5643C · Noisetier #C09468 · Bois flotté #B7AC97 · Bois calciné #3A322C

**Métaux :** Cuivre #C26E43 · Étain #B8BCC0 · Zinc #AEB4B8 · Bronze #B08D57 · Laiton #C9A34C · Fer #8E8E93 · Acier #A9ADB3 · Acier trempé #7E848D · Argent #D9DCE1 · Or #E8C34A · Platine #E4E6E9 · Plomb #5F6470 · Nickel #B9B6A8 · Cobalt #4A5E8F · Titane #9FA8B5 · Tungstène #55585F · Aluminium #CED3D6 · Chrome #C4CBD4 · Manganèse #8A8290 · Bismuth #B78CA8 · Antimoine #9A9AA6

**Roches :** Pierre #9B9B93 · Granit #A79E96 · Granit noir #45434A · Diorite #C5C2BB · Andésite #8A8A82 · Calcaire #D6CDB4 · Dolomie #CFC4A6 · Craie #EFEBDD · Marbre #E7E3DC · Quartzite #D8CFC7 · Schiste #6E7276 · Gneiss #918878 · Basalte #4F4F52 · Tuf volcanique #B5A48C · Pierre ponce #C9C3B6 · Obsidienne #1E1B24 · Silex #6B655C · Grès #D2B285 · Ardoise #5A616B · Gypse #E9E2D2 · Rhyolite #C79C8A · Péridotite #5E6B4E · Serpentinite #5E7D62 · Travertin #DDC9A6 · Conglomérat #AF9C82 · Brèche volcanique #8D6E5C · Kimberlite #566068 · Calcite #EFE8DA

**Terres :** Terre #6E4F31 · Terre fertile #4E3A22 · Tourbe #3F3428 · Sable #E4D3A1 · Argile #B0764F · Gravier #A29A8D

**Végétaux/fibres :** Lin #E9E2C8 · Coton #F5F1E6 · Paille #E5CE7E · Chanvre #C9BE93 · Laine #EDE6D6 · Soie #F2EBDD · Cuir #8A5A33 · Fourrure #A9885E

**Liquides :** Eau #3F76B8 · Eau salée #2E6494 · Lave #E2531F · Huile #6E5B23 · Goudron #26221E · Boue #5C4A35 · Sève #C79038

**Minéraux :** Houille #26262A · Lignite #423A32 · Anthracite #17171C · Soufre #E8D33F · Salpêtre #E5E0CB · Sel gemme #F0E8E0 · Graphite #4B4E55 · Mica #C7B98F · Pyrite #C9A83C · Malachite #2E8B57 · Argile réfractaire #C8A182 · Guano #8F8358 · Tourbe compactée #4A3E2E · Bitume #1C1A18 · Cinabre #B02A1E · Ocre #C9862B · Lapis-lazuli #26529C · Turquoise #40B5AD · Ambre #E0A030 · Fluorine #7FD48A · Amiante #C4C8BE · Phosphorite #97917B

**Météorologiques :** Glace #B8E0EE · Neige #FAFBFD

**Fossiles :** Os fossile #D8CCAE · Ammonite #B79C74 · Bois pétrifié #7A6A58 · Coquillage fossile #D9CDBD · Géode #93A0B6 · Météorite ferreuse #443F45

**Gemmes :** Quartz #E8E4EC · Améthyste #8A4FBF · Topaze #E8B33C · Grenat #8E1F2F · Opale #DCE8E4 · Jade #3D9B6B · Rubis #C81E3C · Saphir #1E4FA8 · Émeraude #1F9E5A · Diamant #EDF5F7 · Onyx #2E3038

**Synthétiques :** Verre #C6DEE4 · Brique #A9502F · Chaume tressé #D3B76A · Papier #F3EEDF

**Validation au boot ([[Schéma matériau]]) :** GameData valide qu'aucune couleur n'est dupliquée dans tout le catalogue ET qu'aucune n'entre en collision avec les **couleurs réservées** (stand-in matériaux + marqueurs d'attache, `data/palette_materiaux.json`) — *un doublon = erreur bloquante de données*.

**Couleurs réservées à ne pas heurter ([[Squelette modulaire et points d'attache]]) :** #00FF00, #FF00FF, #00FFFF, #FFFF00. *Aucune de ces valeurs n'existe dans la palette F.1.1 (vérifié).*

**Rendu ([[Direction artistique]]) :** remapping des couleurs stand-in en shader (palette 256 entrées passée en uniform/texture 256×1). Le bruit par tuile/pixel est généré EN SHADER — zéro mémoire de texture.

**Recolorisation par instance ([[Entités et pathfinding — performance]]) :** réutilisée par les monstres rares (or/argent/prismatique) et le drop de statue 1:1 (recolorisée en pierre).

## Liens
- **Dépend de** : [[Schéma matériau]], [[Direction artistique]]
- **Alimente** : [[Décision — Structure de données de la grille]], [[Squelette modulaire et points d'attache]], [[Monstres rares]]
- **Voir aussi** : [[Catalogue matériaux — Bois]], [[Catalogue matériaux — Métaux]], [[Catalogue matériaux — Roches]], [[Catalogue matériaux — Gemmes]], [[Catalogue matériaux — Paramétriques]], [[Entités et pathfinding — performance]]
