---
aliases: ["7.4", "7.4 Agriculture et élevage", "Agriculture", "Élevage", "Abstraction hors-site principe"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 10
---

Cultiver partout avec un rendement variable, un système de faim qui oblige à manger, et l'élevage qui réutilise le système de créatures.

- **Cultures :** cultivables **partout**, avec un **rendement variable selon le biome** (le biome influence l'efficacité, pas la possibilité de cultiver).
- **Faim/nutrition :** un système de faim **oblige le joueur à manger régulièrement** — mécanique de survie active, pas un simple bonus optionnel. Voir [[Faim]].
- **Élevage :** les animaux de ferme utilisent le **même système modulaire de créatures** que les monstres/PNJ ([[Schéma unifié créature-PNJ]]) — pas de système séparé.

> [!success] Spécifié en profondeur par l'Annexe H
> L'élevage est désormais **un jeu dans le jeu** — attraper, croiser, compléter — avec hérédité, génétique et collection : [[Élevage — intention et familles]]. Mécanismes : [[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]]. Contenu : [[Catalogue des groupes d'élevage]] (35 groupes), [[Vivarium — loci et variétés]] (référence implémentée). **Les saisons sont activées avec lui** ([[Décision — Saisons activées à l'étape 10]]).

**Principe transversal : abstraction hors-site**

Toute gestion de ville/village/base (cultures, élevage, boutique passive — [[Commerce et boutiques]], etc.) doit être **abstraite** quand le joueur n'est pas physiquement présent sur place, plutôt que simulée en temps réel dans le détail. Ce système d'abstraction est noté comme un **chantier à développer plus tard en profondeur**, mais il concerne déjà plusieurs mécaniques déjà posées : agriculture/élevage, boutiques passives, régénération des cases sauvages ([[Claims et persistance]]). Voir [[Abstraction hors-site]] et [[Risques majeurs]].

**Décisions (résolu) :**
- **Faim : [[Faim]]** (jauge 0-100, −1/90 s, paliers de malus, plancher 1 PV). **PNJ : [[Faim des PNJ]]** (auto-nourris au garde-manger, proposition validée par défaut).
- **Abstraction hors-site : [[Abstraction hors-site]]** — résolution par **formules** (jamais de simulation accélérée), rapport au retour.

**Formule de rendement ([[Application des stats de matériau]]) :** `rendement_final = rendement_biome (`farming_yield`, [[Biomes — schéma]]) × (0.5 + fertilite_sol / 100)`.

**Effets météo ([[Météo]]) :** pluie → +15 % vitesse de pousse ; canicule → les cultures flétrissent sans arrosage manuel.

**Rôle de case ([[Rôles de cases]]) :** « Champs » — constructions légères uniquement, parcelles agricoles actives, assignation de PNJ fermiers.

**Engrais ([[Catalogue matériaux — Minéraux]]) :** Guano (fertilité 95, engrais puissant), Phosphorite (80), Tourbe compactée (55).

**Cultures de départ :** voir [[Plantes]] (8 cultures cultivables en champs).

**Timers ([[Simulation du monde — performance]]) :** les cultures ne tournent PAS par tick — chaque instance stocke son échéance dans une timer wheel globale. 10 000 cultures plantées = coût nul entre deux échéances.

> [!success] Codé le 2026-08-28 — étape 10.2, les parcelles
> Les 8 cultures sont en données (`data/plants/`, et un consommable du même id) ; **la graine est la récolte** : planter consomme 1 unité (le coffre de départ en contient, les marchands en vendent). Planter (inventaire, touche H sur une culture — L lit) sur une tuile libre adjacente d'une cellule **Champs** — décision : le rôle Champs est requis (« parcelles agricoles actives »). Chaque parcelle stocke son **échéance** (`duree_jours × ticks_par_jour`, −15 % si pluie au semis) : rien ne tourne par tick, une seule vérification horaire. À l'échéance la parcelle mûrit ; la récolte (clic) donne `recolte_base × farming_yield(biome) × (0,5 + fertilité/100)` ; **canicule au moment de la récolte → ×0,5** (le flétrissement sans arrosage est simplifié ainsi ; l'arrosage manuel n'est pas codé). Fertilité = `stats.fertilite` du sol de la tuile (terre 45, terre fertile 75) ; **engrais** : clic sur une parcelle avec Guano (95), Phosphorite (80) ou Tourbe compactée (55) brut dans le sac. L'élevage (Annexe H) et les saisons restent à faire.

> [!note] Réglages — `combat_rules.agriculture_recolte` : `des`, `moyenne` et `competence` — le rendement d'une parcelle mûre est base × rendement × fertilité × jet/moyenne × skill_factor(Agriculture). Pointeur ajouté le 2026-09-04.

> [!important] Décidé le 2026-09-06, 23 h — les champs vivent au rythme des saisons (designer : « j'aimerais que tu travailles sur l'agriculture, donc avec les champs et les enclos »)
> Un champ de ville était un rectangle de parcelles semées d'une seule culture, récoltées et ressemées à l'identique chaque semaine, sans mémoire ni saison. Il devient une **terre qu'on mène** :
> - **La saison décide** : chaque culture porte ses `saisons` de semis (`data/plants/culture/`). Semée dans sa saison, elle pousse à plein ; hors saison, elle met `hors_saison.duree` fois plus longtemps et rend `hors_saison.rendement` de sa récolte ; **en hiver on ne sème pas** — le champ attend le printemps. Le fermier sème donc ce qui convient au mois, parmi les cultures de son biome.
> - **La rotation** : un champ garde en mémoire ce qu'il a porté (`derniere_plante`). Semer autre chose que la récolte précédente vaut `rotation_bonus` de rendement ; répéter la même culture épuise la terre (la fertilité de ses tuiles baisse de `fertilite_par_recolte`).
> - **La jachère** : après `recoltes_avant_jachere` récoltes, le champ se repose `jours_jachere` jours — rien n'y pousse, la fertilité remonte de `fertilite_rendue`. Un champ en jachère se voit (ses tuiles sont de la terre nue, sans culture).
> - **L'irrigation** : un champ dont une tuile touche l'eau à `irrigation.distance` tuiles rend `irrigation.bonus` de plus, et **tient la canicule** (le facteur de canicule ne s'y applique pas). C'est ce qui fait qu'une ville de bord de rivière nourrit plus de monde qu'une ville de plateau — et c'est la génération qui décide, en posant les champs près de l'eau quand il y en a.
> - **Ce que ça change pour le joueur** : ses propres parcelles suivent les mêmes règles (semer hors saison est possible et coûteux), et un fermier assigné à un périmètre « champs » applique la rotation et la jachère à sa place.
> Ce que ça ne fait pas encore : l'irrigation construite (canaux, puits), les engrais répandus par les fermiers, les mauvaises récoltes et les famines (les prix les diront quand l'économie s'en saisira).

> [!important] Décidé le 2026-09-06, 23 h 20 — un enclos est un troupeau qui vit (designer : « l'agriculture, donc avec les champs et les enclos »)
> Les bêtes d'un enclos produisaient une matière par semaine, indéfiniment, sans manger ni vieillir : un décor à intervalle. Un troupeau devient une **économie animale** :
> - **Il faut le nourrir.** Chaque semaine, le troupeau consomme `fourrage_par_bete` unités de culture prises dans les stocks de la ville (le grain d'abord). Une ville qui n'a pas récolté ne nourrit pas ses bêtes : sous `famine_seuil` de fourrage, une bête meurt (le journal le dit) et rien ne naît.
> - **Il croît.** Nourri et à l'aise (moins de `capacite` bêtes par enclos), chaque bête a `naissance_chance` de donner un petit dans la semaine, `naissances_max_semaine` par enclos — la bête naît dans l'enclos, du même espèce, bétail du même territoire ; dans une ville endormie (hors fenêtre), elle naît endormie comme les enfants des PNJ.
> - **Il se tond à sa saison.** Un produit peut porter une `saison` (la laine au printemps) : hors de cette saison, la bête ne le donne pas. Le lait, lui, coule toute l'année.
> - **On l'abat.** Au-delà de `capacite`, le surplus part à la boucherie : `abattage` donne de la viande, du cuir et du suif aux stocks — c'est ainsi qu'une ville d'élevage nourrit ses gens et fournit ses tanneurs.
> Ce que ça ne fait pas encore : les races et les lignées (une bête ne vaut pas mieux qu'une autre), le pâturage tuile à tuile (l'herbe ne se broute pas), les maladies du troupeau.

> [!important] Décidé le 2026-09-07, 1 h — les champs sont aux abords, et au bord de l'eau quand il y en a
> Un champ se posait sur le premier rectangle libre tiré au hasard dans la cellule : on en trouvait entre deux maisons, au pied de la place. Désormais la génération les cherche **depuis les bords du quartier vers le centre** (la ville au milieu, les terres autour, comme partout où l'on a bâti avant les tracteurs) et **préfère les abords de l'eau** : parmi les emplacements libres, celui dont une tuile touche l'eau à `irrigation.distance` gagne — c'est lui qui sera irrigué et qui tiendra la canicule. Sans eau dans la cellule, le premier terrain des abords fait l'affaire. L'enclos suit la même règle, sans la préférence pour l'eau.
> Ce que ça donne : une ville de rivière a ses champs le long de la berge et nourrit plus de monde ; une ville de plateau a ses champs en couronne et souffre l'été. La règle de rendement (irrigation) existait déjà — c'est la génération qui lui donne enfin de quoi mordre.

> [!important] Décidé le 2026-09-07, 7 h — le verger : ce qui pousse sans qu'on le ressème (designer : « l'agriculture donc avec les champs et les enclos »)
> Un champ, on le laboure, on le sème, on le récolte, on le change de culture. Un **verger** ne se conduit pas ainsi : on plante une fois, on cueille des années, et l'on n'y fait ni rotation ni jachère. Il entre dans la génération à côté des champs :
> - **Un enclos de buissons** (framboisier, myrtillier, vigne, houblon selon le biome), aux abords comme les champs, dans les quartiers agricoles et résidentiels — et une ville **grenier** ou **forestière** en a un de plus.
> - **Il ne tourne pas** : à la cueillette, la même espèce repart (`plante_a_semer` rend la plante du verger). **Il ne se repose pas** : la jachère l'ignore, la terre d'un verger ne s'épuise pas comme celle d'un champ.
> - **Il se voit** : ses tuiles portent un contenu à elles (`verger`, `verger_mur`) — un vert sombre qui rougit à maturité, distinct des rangs clairs d'un champ de céréales. Hors de sa saison, un buisson met le même temps de retard qu'une culture (la règle d'`hors_saison` vaut pour lui).
> Ce que ça ne fait pas encore : les arbres fruitiers hauts (le verger est un buisson, pas un pommier — les arbres bloquent la vue et il faudrait décider si l'on passe dessous), le vin (la vigne rend du raisin, pas du vin : il y faudrait une cuve et une recette), et la cueillette à la main par le joueur dans le verger d'un PNJ (elle marche, mais personne ne s'en offusque).

> [!important] Décidé le 2026-09-07, 14 h — un village garde des bêtes : l'enclos descend au centre des petites agglomérations
> La revue en images (`capture.tscn -- --palier village --sur enclos`) a répondu « AUCUN enclos trouvé ». Ce n'était pas un défaut de l'outil : les enclos ne se posaient que dans les quartiers **agricoles**, qui n'apparaissent qu'à partir du bourg (quatre cellules). Un hameau et un village n'avaient donc **aucune bête** — alors que ce sont précisément les plus petites agglomérations qui vivent de leur troupeau.
> Le centre d'un hameau ou d'un village reçoit désormais son enclos, comme il reçoit déjà ses champs (`champs.quartiers` contient « centre » depuis B2). Le cœur d'un bourg et plus reste sans enclos (`enclos.paliers_sans_centre`) : ses bêtes sont dans ses quartiers agricoles, et l'on ne parque pas un troupeau sur le parvis d'un château.
> Ce que la capture montre : un enclos clôturé, ses bêtes dedans (un mouflon, un sanglier — l'élevage du jeu domestique des espèces sauvages, il n'y a pas de vache au catalogue), le champ en damier à côté. Cela se lit.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Biomes — schéma]], [[Rôles de cases]], [[Application des stats de matériau]]
- **Alimente** : [[Faim]], [[Cuisine et alchimie]], [[Abstraction hors-site]], [[Population et exploitation]], [[Plantes]]
- **Voir aussi** : [[Météo]], [[Faim des PNJ]], [[Catalogue matériaux — Minéraux]], [[Simulation du monde — performance]], [[Risques majeurs]], [[Potentiel]]
