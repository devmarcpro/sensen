---
aliases: ["E.22", "Annexe E.22", "Eau et liquides", "Liquides", "Eau"]
tags: [monde, simulation, décidé]
domaine: monde
statut: décidé
etape: 8
---

> [!note] Adapté au pivot tactique
> Modèle réécrit en **2D + hauteur** ([[Hauteur de terrain ±10]]). L'automate par blocs 3D d'origine est archivé (GDD source, historique git).

Un automate cellulaire sur la grille — l'eau remplit les creux du terrain, jamais une simulation de fluide.

```
MODÈLE — automate cellulaire par tuiles, 2D + hauteur (3.6) :
- Une tuile de liquide est SOURCE (niveau 8/8) ou ÉCOULEMENT (niveau 7→1).
- Propagation : un liquide s'écoule d'abord vers la tuile voisine de
  hauteur INFÉRIEURE (il descend le relief et remplit les creux), sinon
  s'étale à hauteur égale en perdant 1 niveau par tuile (portée 7 tuiles
  pour l'eau, 3 pour les liquides visqueux — lave, boue, goudron, huile :
  champ `viscosite` dérivé de la friction).
- Vitesse : mise à jour des tuiles liquides actives tous les 5 ticks
  (eau) / 15 ticks (visqueux) — file de tuiles "à recalculer", seuls
  les liquides en mouvement coûtent quelque chose.
- Les sources sont INFINIES en récolte au seau (un lac ne se vide pas
  en le puisant) mais une tuile source détruite/déplacée disparaît.
  Pas de "bassin infini 2x2" : une source ne se duplique jamais
  (différence assumée avec Minecraft, évite les exploits d'eau).
- Une tranchée creusée sous le niveau d'un lac s'inonde ; un talus
  élevé endigue (3.6 : « inonder la tranchée » est une manœuvre
  tactique voulue).

INTERACTIONS (par tags/stats, section 10 + A.4.5) :
- Lave + eau adjacentes → obsidienne (contact source) ou pierre
  (contact écoulement). La lave enflamme les tuiles flammabilite > 0
  adjacentes ; dégâts de contact 3d6 feu/tour.
- L'eau éteint le statut Brûlure ; nettoie certains statuts de surface.
- Conductivité : la foudre (modules F.2) frappant l'eau se propage à
  toutes les entités dans la nappe d'eau connexe (rayon 5) — l'eau
  salée (CÉl 90) étend le rayon à 8.
- Le courant pousse les entités et objets au sol (direction de
  l'écoulement, force faible).

NAGE ET IMMERSION :
- Nager = Athlétisme ; vitesse = f(compétence), le poids porté tire
  vers le fond (surcharge = on coule, largage d'objets possible).
- Souffle : jauge 30 s + Endurance*2 ; à 0 → 1d6 dégâts/tour.
  respiration_aquatique (tag F.7) = immunité.
- Dans l'eau : vision réduite, pas de combat à distance sauf arbalète
  (malus -4), mêlée à -2, feu impossible, foudre déconseillée (cf. plus
  haut — y compris pour le lanceur).
- La pluie (météo, E.28) remplit les cavités ouvertes d'1 niveau max —
  pas d'inondation générale.

BATEAUX (pont vers les véhicules, 13) : un véhicule flotte si
flottabilite moyenne >= 50 (A.4.5) ; il repose sur les tuiles d'eau
et suit le courant s'il n'est pas dirigé. Détail du pilotage :
avec le système véhicules (E.24).
Réseau : le host simule, les écoulements sont des mutations de tuiles
standard (E.11) — rien de nouveau à synchroniser.
```

**Coût ([[Simulation du monde — performance]]) :** file active uniquement — un lac stable coûte 0. Inchangé.

> [!success] Codé le 2026-08-28 — la mer, statique
> Les tuiles de mer (altitude < `planete.mer.altitude` = 0,30) sont un contenu `eau` (source, niveau 8/8), **hauteur 8** (décision : la note ne chiffre pas le niveau de la mer ; la référence du sol étant 10, la mer est deux niveaux sous la plaine, un talus la borde). L'eau bloque le passage tant que la nage attend ; elle ne bloque pas la vue. L'automate (écoulement, lacs, rivières, pluie) et les interactions (lave, foudre, évaporation) attendent.

> [!success] Codé le 2026-08-28 — la nage et le souffle
> Le contenu `eau` **ne bloque plus le passage** : il porte le tag `nage`, et `Grille.cout_pas` lui donne `deplacement.nage` (6, deux fois un pas de plaine) — les ticks passent ensuite par Athlétisme comme tout déplacement (« nager = Athlétisme »). **Le poids tire vers le fond** : un être en surcharge (`poids_de(e).facteur > 1`) **ne peut pas entrer dans l'eau** (journal) — décision : plutôt que couler, on refuse ; larguer des objets reste le geste. **Souffle** : `e.souffle`, max `= souffle_base (300 ticks = 30 s) + Endurance × 2`, décroît d'un par tick dans l'eau et se remplit hors de l'eau ; à 0, **1d6 par période de 10 ticks** (`_tiquer_souffle`, sur l'horloge de l'être) ; le tag `respiration_aquatique` immunise — la **potion de respiration aquatique** (roseau, statut qui accorde le tag, 5 min) ferme la liste des potions. **Dans l'eau** : mêlée à **−2 dés**, et une capacité dont l'élément dominant est le **Feu** ne part pas (journal). Le HUD affiche le souffle quand on nage. L'IA nage comme tout le monde (même coût de pas). Vision réduite, arbalète et foudre attendent.

> [!success] Codé le 2026-08-28 — l'automate d'eau, première passe
> Contenu `eau` = **source** (niveau 8) ; nouveau contenu `eau_ecoulement` (niveau 1-7 dans `Grille.niveau_eau`, tags `liquide`/`nage`/`ecoulement`, se nage et gèle comme la source). **Automate** (`Simulation._tiquer_eau`, toutes les `eau.periode_ticks` = 5 ticks de monde, budget `tuiles_par_pas` = 64) : une tuile active verse vers ses **4 voisines** — voisine **plus basse** → niveau 7 (elle descend le relief et remplit les creux), voisine **de même hauteur** → niveau − 1 (elle s'étale, portée 7), voisine plus haute ou bloquante → rien ; une tuile dont le niveau monte redevient active. Décisions : **l'eau ne se retire pas encore** (pas d'assèchement — la retirer demande l'inverse de la propagation, attend) ; **rien ne s'active au chargement** (la mer reste statique tant qu'on n'y touche pas — sinon toute côte basse s'inonderait à chaque visite) ; **ce qui active** : creuser ou terrasser une tuile **voisine d'un liquide** (« la tranchée s'inonde », « le talus endigue » puisqu'une voisine plus haute ne reçoit rien), et la **pluie** (`_pluie` à chaque heure de pluie : `pluie_tuiles` creux locaux — plus bas que leurs 4 voisines — reçoivent 1 niveau, +1 max par heure, jamais au-dessus de 1 sans source : « les cavités ouvertes d'1 niveau max »). Les tuiles d'écoulement sont marquées (`grille.marquer`) donc persistées par cellule. La lave, la foudre dans l'eau, le courant et l'évaporation attendent.

> [!success] Codé le 2026-08-28 — conductivité : la foudre court dans l'eau
> Un impact de foudre (Météo) sur une tuile de liquide se propage à **toutes les entités de la nappe connexe** (voisinage 4, tuiles `liquide` non gelées) jusqu'à **`eau.foudre_rayon_eau` = 5** tuiles — **8** (`foudre_rayon_mer`) si la tuile frappée est une **source** (décision : la mer est salée, CÉl 90 ; les écoulements et flaques sont d'eau douce). Même 3d8 que l'impact, journal `journal.foudre_eau`. Rien n'est prévu pour les capacités : aucun module ne porte encore un élément foudre — quand il viendra, `_frapper_foudre` est le point d'entrée.

> [!success] Codé le 2026-08-28 — le retrait de l'eau, la source détruite, l'évaporation
> L'inverse de la propagation : à chaque pas de l'automate, une tuile d'**écoulement** active qui n'est **plus alimentée** (`_alimentee` : en remontant le courant — voisine plus haute liquide, ou de même hauteur d'un niveau supérieur — on n'atteint aucune source ; un simple regard aux voisines ne suffit pas, un bord qui s'assèche « nourrirait » l'intérieur ; parcours borné à 128 tuiles) **et qui n'est pas un creux** (`_en_creux` : une voisine au moins de même hauteur ou plus basse sans liquide — sinon l'eau reste dans le trou) **perd un niveau** (`_retirer_eau`) — et une tuile non alimentée **ne verse plus** (sinon l'intérieur d'une nappe réalimente sans fin son bord qui s'assèche) ; à 0 la tuile s'assèche (journal `journal.retrait`) et ses voisines sont réévaluées — la nappe se rétracte de proche en proche. **Une source détruite disparaît** : élever la tuile d'une source (`terrasser`, sens +1) la retire (`_retirer_source`) et réveille ses voisines ; élever une tuile d'écoulement la **comble**. **Évaporation** (Météo) : à chaque heure dont l'état porte l'effet `evapore` (canicule), toute flaque non alimentée — creux compris — perd un niveau (`_evaporation`). Le **niveau** des écoulements est désormais persisté avec la cellule (`Monde.capturer`, champ `eau`). Décision : pas d'évaporation hors canicule (la note ne chiffre rien ; une flaque de pluie dure jusqu'au prochain soleil de plomb).

> [!success] Codé le 2026-08-28 — la lave : contact, ignition, rencontre avec l'eau
> Contenu **`lave`** (tags `liquide`/`source`/`lave`/`danger`, ne bloque ni le passage ni la vue, luminosité 90 : elle éclaire), posée par le générateur de donjon dès l'étage `lave.etage_min` (5) : `lave.mares` (1-3) mares de `lave.taille` (6-20) tuiles de sol, jamais sur l'entrée, l'escalier ni un coffre. **Contact** : un être sur une tuile de lave prend `lave.degats` (3d6, feu) et la Brûlure à chaque pas de l'automate d'eau (5 ticks) — `Grille.dangers` la marque, donc l'IA la contourne et en sort ; le joueur, lui, peut y entrer (c'est son problème). **Ignition** : chaque pas, les 4 voisines inflammables prennent feu (le feu de tuile, *Météo*). **Lave + eau** : à chaque pas, une lave voisine d'un liquide se **fige** — `lave.obsidienne_source` (obsidienne) au contact d'une **source** d'eau, `lave.pierre_ecoulement` (basalte) au contact d'un **écoulement** ; l'eau touchée s'évapore (l'écoulement disparaît, une source reste). Décisions : la lave **ne coule pas encore** (l'étalement visqueux, portée 3 tous les 15 ticks, attend — les mares sont statiques et c'est déjà tactique) ; pas de lave en surface (aucun biome volcanique n'en pose : le désert de cendres attend un volcan). Le courant reste à faire.

> [!success] Codé le 2026-08-28 — le courant : ce qui flotte descend
> Au passage, `Grille.niveau_liquide` retourne désormais le niveau mémorisé même quand le **contenu** de la tuile a été remplacé (poser du butin dans une rivière écrasait le contenu `eau_ecoulement` : la tuile paraissait sèche). **Direction** (`Simulation.courant_de`) : d'une tuile d'écoulement vers la voisine où l'eau va — la plus basse d'abord, sinon celle du niveau le plus faible ; `Vector2i.ZERO` sur une source, sur une eau gelée, ou dans un creux sans issue (l'eau y stagne). **Force faible** : à chaque pas de l'automate (5 ticks), un être dans un écoulement est poussé d'une tuile avec la chance `eau.courant_chance` (0,25), **sauf** s'il est **plus lourd que le courant** — un être dont la charge dépasse `eau.courant_poids` (0,5) de sa capacité de poids tient debout : équipé lourd, on ne dérive pas. La poussée est un vrai déplacement (elle réveille le combat, elle peut faire tomber dans la lave) mais **ne coûte aucun tick** à qui la subit. Les **objets au sol** (`contenants` de type butin) suivent le même courant à la même chance, et fusionnent avec le tas d'arrivée — ce qui tombe dans une rivière part au fil de l'eau. Décision : pas de vitesse ni d'accumulation d'élan (« force faible » dans la note) ; les coffres, eux, ne bougent jamais.

## Liens
- **Dépend de** : [[Hauteur de terrain ±10]], [[Application des stats de matériau]], [[Simulation à ticks]]
- **Alimente** : [[Véhicules]], [[Catalogue matériaux — Liquides]], [[Météo]]
- **Voir aussi** : [[Statuts]], [[Modules]], [[Réseau]], [[Simulation du monde — performance]], [[Compétences — liste]], [[Destruction du terrain]]
