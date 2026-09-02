---
aliases: ["B.2", "Annexe B.2", "Catégories de matériaux", "material_categories"]
tags: [objets, matériaux, données, schéma, décidé]
domaine: objets
statut: décidé
etape: 6
---

Les catégories de matériaux, chacune liée à un outil, une compétence de récolte et une station de transformation.

**Décision (4.2) — Catégories figées (11, alignées sur le catalogue [[Catalogue matériaux — Bois]] et suivants) :** bois, métal (minerai), roche, terre, végétal/fibre, liquide, minéral, fossile, gemme/cristal, météorologique, synthétique.

**Table outils/compétences par catégorie** — `data/material_categories.json` :

```json
{
  "bois":        { "tool": "hache",   "harvest_skill": "bucheronnage", "station_transform": "scierie" },
  "minerai":     { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "forge" },
  "roche":       { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "tailleur_pierre" },
  "terre":       { "tool": "pelle",   "harvest_skill": "terrassement", "station_transform": null },
  "vegetal":     { "tool": "faucille","harvest_skill": "herboristerie","station_transform": "atelier_tissage" },
  "liquide":     { "tool": "seau",    "harvest_skill": "collecte",     "station_transform": "alambic" },
  "cristal":     { "tool": "pioche",  "harvest_skill": "minage",       "station_transform": "table_enchantement" },
  "synthetique": { "tool": null,      "harvest_skill": null,           "station_transform": "atelier" }
}
```

> *Note : la table B.2 énumère 8 entrées ; la décision de la section 4.2 fige **11** catégories (ajoutant minéral, fossile, météorologique). Les catégories supplémentaires suivent la même structure — outil pioche / compétence Minage pour minéral et fossile, cf. les en-têtes du catalogue [[Catalogue matériaux — Minéraux]] et [[Catalogue matériaux — Fossiles]] ; les matériaux météorologiques ([[Catalogue matériaux — Météorologiques]]) apparaissent/disparaissent selon la météo et sont récoltables.*

**Vecteur Wu Xing dérivé de la catégorie ([[Wu Xing hors combat]]) :** métal→Métal, bois/fibre→Bois, roche/terre→Terre, liquide/glace→Eau, forte flammabilité→Feu — avec un champ `wuxing` optionnel pour les exceptions.

**Recettes par catégorie ([[Fabrication d'outils]]) :** un outil peut être fabriqué avec n'importe quel matériau, tant que les matériaux utilisés correspondent aux **catégories** requises par la recette.

**Familles de matériaux dans le craft compositionnel :** le champ `material_family` de [[Composants]] reprend cette logique de catégorie acceptée.

**Tarifs douaniers par catégorie :** [[Gouvernance, lois et diplomatie]] (`tariffs` de [[Schéma royaume]]).

> [!success] Codé le 2026-08-28 — `data/material_categories.json`, les 11 catégories
> Complété pour les trois catégories que la table ne donnait pas : `mineral` et `fossile` → pioche / Minage (comme leurs en-têtes de catalogue) ; **`meteorologique` → pelle / Terrassement** (décidé ici : on pellette la neige et la glace). Ids des stations en snake_case (`tailleur_de_pierre`, `atelier_tissage`, `table_enchantement`, `etabli`).

> [!success] Codé le 2026-09-01 — le cuir dit de quelle bête il vient (designer, point 69)
> « un casque en cuir ne devrait pas être juste ça, en cuir de quoi ? ». Il n'existait qu'un seul matériau `cuir`, et tanner deux peaux — de loup, d'ours polaire ou de basilic — donnait la même matière.
> **Première version, refusée par le designer le jour même** : j'avais écrit **vingt-deux fichiers de matériau**, un par espèce à peau. « Les cuirs ne doivent pas être codés en dur, l'espèce est un modificateur sur l'item. » Il a raison, et c'est la règle du coffre : un matériau par espèce, c'est du contenu figé à maintenir, et il aurait fallu recommencer pour l'os, la fourrure, la corne, puis pour chaque bête ajoutée.
> **La bonne forme** : **un seul** matériau `cuir`, et l'**espèce voyage sur l'objet**. La peau porte son espèce depuis la dépouille, la pile de cuir tannée en hérite, le composant façonné aussi, et l'objet assemblé la porte jusqu'à son nom. Les stats du matériau sont **modulées à l'instanciation** par les stats de la bête, selon une formule qui vit dans `combat_rules.craft.materiau_espece` — quelles stats bougent, et de combien par point. Un ours polaire durcit et alourdit son cuir, un serpent venimeux l'assouplit et l'allège. Zéro fichier par espèce, zéro clé de traduction par espèce : le nom se compose (`material.avec_espece`), et **la mécanique vaudra pour l'os et la fourrure sans une ligne de plus**.


> [!success] Codé le 2026-09-01 — toute matière tirée d'une bête dit de laquelle (designer, point 70)
> « c'est pareil pour l'os, la fourrure etc, on doit toujours savoir de quelle créature ça vient car les stats ne sont pas les mêmes ». Le mécanisme du cuir étant générique — l'espèce voyage sur l'objet et module les stats du matériau — il ne restait qu'à le brancher. Trois transformations nouvelles, toutes marquées `herite_espece` : **travailler l'os** (deux os → un os massif), **tailler un croc** (deux dents → un croc) et **préparer une fourrure** (deux peaux → une fourrure). Chacune rend une matière qui porte sa bête, donc ses stats : un os d'ours des cavernes est plus dur qu'un os de lynx, et la fourrure d'un ours polaire isole plus.
> **Deux familles mortes rouvertes** : `dent_croc` et `fourrure` n'avaient aucun matériau au catalogue — les recettes de composant qui les demandaient étaient donc **toujours sautées** au loot, ce qui appauvrissait le tirage exactement comme l'écaille. Le croc entre au catalogue ; la fourrure y était déjà mais rien ne la produisait.


> [!bug] Corrigé le 2026-09-02 — la famille `ecaille` était vide, et le loot s'en trouvait appauvri
> Dernière des trois familles mortes repérées le 2026-09-01 : `ecaille` ne désignait **aucun matériau**. La recette de composant `plaque_ecaille` était donc **toujours sautée** au tirage — une armure ne pouvait sortir qu'en os massif ou en métal, alors que le catalogue promettait trois voies. Les six bêtes écailleuses (crocodile, serpents, basilic, lindworm, kappa) laissent désormais une **écaille** au jet de Chasseur ; deux écailles se durcissent en matériau `ecaille` (recette `durcir_ecaille`, héritant l'espèce comme le cuir et l'os). Une écaille de basilic n'est pas une écaille de crocodile. Les trois familles annoncées pour une plaque d'armure existent enfin toutes les trois.


> [!success] Tranché le 2026-09-02 — chaque matériau porte un **palier** (designer)
> « Pour les matériaux il va falloir rajouter des paliers de rareté/puissance pour vraiment différencier le loot early/mid/endgame, et du coup plus différencier les stats des équipements qui en découlent, et leur difficulté à extraire. »
> **Ce qui existait déjà, et pourquoi ça ne suffisait pas.** `minerais_par_etage.tiers` range déjà les **minerais** en bandes de profondeur — mais seulement eux : les bois, les cuirs, les os, les tissus, les gemmes taillées n'y figurent pas, et rien ne les empêche de tomber dès le premier étage. Et ces bandes ne servaient qu'à **où** un matériau apparaît : ni ses stats, ni sa récolte n'en tenaient compte.
> **Les cinq paliers.** Chaque matériau porte désormais `palier`, de **1** (ce qu'on ramasse au camp) à **5** (ce qu'on arrache au fond d'un gouffre). Le palier commande trois choses à la fois, et c'est là tout son intérêt :
> - **où il tombe** : un palier a sa profondeur minimale ; le titane ne sort pas à l'étage 2, et le drap de soie non plus ;
> - **ce qu'il vaut** : un multiplicateur de stats par palier, appliqué à l'objet assemblé — c'est ce qui creuse l'écart entre une épée du début et une épée de la fin, au-delà du seul écart de dureté écrit dans les fiches ;
> - **ce qu'il coûte à extraire** : les ticks de récolte et le seuil d'outil montent avec le palier. Un matériau de fin de partie ne se ramasse pas à la pioche de départ, même si on le trouve.
> **Comment les paliers ont été posés.** Par dérivation, pas à la main : un minerai hérite du tier de `minerais_par_etage` ; les autres sont classés **dans leur catégorie** par un score de puissance (dureté, valeur de base, conductivité de mana) et répartis en cinq quintiles. Le classement se fait par catégorie parce qu'un bois de palier 5 reste un bois : on compare un chêne aux autres bois, pas au platine. Les valeurs sont **en données**, une par fiche : le designer peut en corriger une sans toucher au reste.


> [!success] Codé le 2026-09-02 — la catégorie **animal** (designer : « si tu ressens le besoin tu peux rajouter des catégories »)
> Seize matières d'origine animale étaient rangées en « végétal » : cuir, os, os massif, croc, écaille, ivoire, fourrure, laine, soie, corne, tendon, plume, crin, boyau, os de seiche, éponge. Ce n'était pas qu'une étiquette — la catégorie décide de **l'outil et de la compétence de récolte**, de la **station de transformation** et du **plafond de palier**. On écorche une bête au couteau, on ne la fauche pas ; on tanne une peau, on ne la tisse pas.
> **L'élément reste le Bois**, comme pour le végétal : dans les cinq éléments, le Bois est celui du vivant qui pousse — la chair et l'os en sont autant que la tige. C'est le choix prudent, il tient en une ligne de `wuxing.materiaux_par_categorie` si le designer en veut un autre.
> Le test qui comptait « 11 catégories » vérifie désormais la **règle** : toute catégorie utilisée par une fiche doit être décrite, sinon on ne sait ni la récolter ni la travailler.


## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Schéma matériau]]
- **Alimente** : [[Récolte]], [[Stations de transformation]], [[Composants]], [[Wu Xing hors combat]]
- **Voir aussi** : [[Compétences — liste]], [[Schéma royaume]], [[Catalogue matériaux — Bois]], [[Fabrication d'outils]]
