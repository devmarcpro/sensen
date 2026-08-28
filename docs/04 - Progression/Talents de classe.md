---
aliases: ["Talents de classe", "Talent de classe", "Classes cachées", "Passeur", "Capacité de classe", "Jauge de classe", "La Mèche", "L'Engrenage", "La Paume", "Le Creuset"]
tags: [progression, combat, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!warning] Amende une décision écrite
> Le GDD disait : *« Classe : détermine **uniquement** des bonus de stats/équipement de départ »* ([[Création de personnage]]). **Amendé le 2026-08-26** : chaque classe porte un talent qui définit une façon de jouer — justifié par **ToME** ([[Piliers d'inspiration]]), où les classes ont une mécanique définissante dès le début et où le build émerge *à l'intérieur* de cette identité.

Un talent de classe est **actif** : une capacité qu'on emploie. **19 classes** — 8 visibles, 11 cachées.

## Le mécanisme

**Un talent de classe est une capacité hors slots** : un module ([[Vocabulaire des modules — six axes]]) qui n'occupe **aucun emplacement** de [[Structure compétences-modules-slots]] et n'a pas besoin d'être trouvé. Il monte par l'usage ([[Progression par l'usage]]).

> **Le talent est un plancher, pas une cage.** Tous les slots restent libres pour ce qu'on ramasse — le build émerge par-dessus une identité, au lieu d'émerger de rien.

**Certains talents portent une jauge de classe** — une barre propre à la classe, lue et remplie par ses propres règles, calquée sur la [[Jauge de chaîne Wu Xing]] (même objet de code, autres conditions de remplissage). C'est le mécanisme générique qui évite d'écrire une exception par classe.

## Les huit visibles

| Classe | Talent | Ce que ça change |
|---|---|---|
| **Le Sabre** | *Râtelier vivant* — une fois par chaîne, **changer d'arme coûte 0 tick** | mord sur l'arbitrage central du combat ([[Jauge de chaîne Wu Xing]] : +0.10 en restant, +0.35 en payant 4 ticks). Le Sabre s'offre la rotation parfaite que les autres ne peuvent pas |
| **Le Souffle** | *Communion des cinq* — possède le module d'office, hors slot : **l'élément de son arme tourne seul** dans le cycle ([[Cinq accès au cycle]]) | accès permanent au cycle sans arsenal ni or |
| **La Braise** | *Main du métal* — **reforge** un objet looté : remplacer un composant ([[Craft compositionnel]]) **sans perdre ses affixes** | l'atelier n'invente toujours pas d'affixes ([[Loot — affixes, gemmes et rareté]] : *loot-only*), mais il en change le support. Le loot mort disparaît |
| **La Trace** | *Meute* — **son compagnon partage sa jauge de chaîne** : les coups du compagnon posent des segments ([[Compagnons]]) | deux corps, une chaîne — le seul build qui construit sa rotation à deux |
| **La Balance** | *Œil du prix* — voit le **portefeuille réel** et le prix d'acceptation de chaque PNJ ([[Barèmes économiques]]) ; +1 place d'escorte | le commerce devient de l'information au lieu du tâtonnement |
| **La Paume** | *Souffle rendu* — ses **soins posent un segment de chaîne de l'élément de la cible soignée** ([[Jauge de chaîne Wu Xing]]) | le soigneur devient un **tisseur de chaîne** : il construit la rotation de son groupe. Contrepartie : ses attaques d'arme ne posent **aucun** segment — il ne construit que par les autres |
| **Le Creuset** | *Fiole vive* — ses potions deviennent **projetables en zone** (forme `carre r1`, tous les alliés dedans) et il porte **2 potions actives par famille** au lieu d'1 ([[Nourriture, potentiel et potions]]) | chaque potion lancée consomme **le double d'ingrédients** |
| **Le Vent** | *Sans maître* — commence **sans talent**, mais peut en apprendre un auprès de n'importe quel maître — **et en changer** | le seul qui goûte à tout, jamais le meilleur nulle part |

## Les onze cachées

**Elles ne sont pas au menu : elles s'apprennent d'un PNJ qui les porte.** Puisque chaque PNJ a une classe ([[Les trois axes — race, classe, fonction]]), un Passeur existe quelque part — le trouver *est* le déblocage. Mécanisme existant : **enseignement à relation ≥ 75** ([[L'information comme récompense]]).

| Classe | Talent | Contrepartie | Source |
|---|---|---|---|
| **Le Passeur** | **deux tuiles appairées permanentes** — portails hors slot, sans mana d'entretien, repositionnables ([[Familles de capacités de la grille]]) | mana max **−30 %** : le corps paie la brèche en permanence | *Éliotrope* |
| **Le Sablier** | effet **`tempo`** ([[Vocabulaire des modules — six axes]]) : retarde le compteur d'un ennemi, avance le sien, vole du tempo | chaque emploi coûte **de la santé** (le temps se paie en soi) ; plafonné par l'anti-stunlock | *Xelor* |
| **Le Sceau** | grave des **glyphes** persistants, plusieurs simultanés, qu'il déclenche à distance | ses glyphes coûtent 2× en mana ; **immobile pendant la gravure** (canalisation visible) | *Feca* |
| **Le Masque** | change de **posture** instantanément (0 tick) en changeant de masque — cumule les bonus de deux postures | ne peut pas prendre la garde ([[Garde en posture]]) : le masque occupe la main secondaire | *Zobal* |
| **Le Porteur** | effet **`saisie`** : saisit une entité adjacente et la **lance** — alliés compris | pendant la saisie, ne peut ni attaquer ni se garder ; la cible saisie peut se débattre (jet de Force) | *Pandawa* |
| **L'Ombre** | statut **Dissimulé** hors combat et après chaque mise à mort ; ses pièges ne sont pas visibles | dégâts **−25 %** en attaque frontale : il ne vaut que par le dos et le flanc | *Sram* |
| **L'Écarlate** | **jauge de sang** : les dégâts subis la remplissent, elle multiplie les dégâts infligés (jusqu'à ×1.8 pleine) | la jauge se vide en **soignant** — il doit choisir entre survivre et frapper | *Sacrieur* |
| **Le Rieur** | **relance** un jet de dés par combat ([[Pipeline de résolution du combat]]) ; ses critiques s'étendent (19-20) | les échecs critiques s'étendent aussi (1-2) — il joue sur les deux queues | *Ecaflip* |
| **Le Fossoyeur** | relève les cadavres du champ de bataille en **invocations temporaires** (occupent une tuile) | réputation en chute continue dans toute zone civilisée ([[Réputation et relations]]) | — |
| **La Mèche** | *Chaîne d'amorces* — pose des bombes à retardement (`declencheur` après N ticks) qui **s'amorcent mutuellement** : une explosion déclenche les bombes adjacentes ([[Explosions]]) | **friendly fire intégral** ([[Décision — Projectiles]]) : ses bombes le blessent aussi | *Roublard* |
| **L'Engrenage** | *Affût* — déploie une **tourelle portative** qui occupe une tuile, tire à chaque tick sur la cible la plus proche et **hérite de l'élément de l'arme équipée** | une seule tourelle déployée ; elle consomme les **munitions de son carquois** ([[Équipement — 14 slots]]) | *Steamer* |

*(Le **Meneur** — invocateur permanent à la Osamodas — est écarté : il chevauchait *Meute* de La Trace.)*

## La technologie existe

**La Mèche et L'Engrenage établissent que Sensen a une couche technologique** — et elle a déjà son ancrage : le **palier industriel** ([[Palier industriel]]), avec ses aciers alliés, son haut fourneau, son laminoir et son combustible, plus les **tourelles** de [[Défense et raids]].

**C'est pour ça que ces deux classes sont cachées.** La technologie du monde est *retrouvée*, pas connue : les recettes industrielles viennent des ruines profondes et des marchands des capitales. Un tourellier s'apprend au même endroit que le haut fourneau — ce qui donne à la découverte technique un visage, en plus d'une recette.

## Ce que ça demande aux systèmes

Trois ajouts, tous génériques — **aucune exception par classe** :

1. **Effet `tempo`** ([[Vocabulaire des modules — six axes]]) — agit sur les compteurs d'action de [[Boucle de tick]]. **Garde-fou obligatoire :** un retard est un contrôle dur déguisé ; il compte dans le budget de [[Statuts de contrôle et anti-stunlock]] (jamais plus de 20 ticks cumulés, pas de réapplication dans les 50 ticks suivants).
2. **Effet `saisie`** — l'attaquant contrôle le déplacement d'une entité adjacente, qui libère sa tuile et devient projetable ([[Hauteur de terrain ±10]] : les chutes font (hauteur−2)×5).
3. **Jauge de classe** — barre propre à une classe, même objet de code que la [[Jauge de chaîne Wu Xing]].

Et trois statuts nouveaux ([[Statuts]]) : **Dissimulé**, **Saisi**, **Retardé**.

## Les PNJ ont des classes — avec une règle

- La classe d'un PNJ est tirée dans un **pool restreint par fonction** ([[Fonctions]], champ `classes_possibles`).
- Les **classes cachées sont rares** (≈ 2 % des PNJ à fonction compatible) : le bandit-Passeur est un événement, pas un tirage.
- **C'est ce qui rend l'apprentissage possible** — sans porteurs, aucune classe cachée ne serait trouvable.

> [!success] Codé le 2026-08-28 — le cadre et cinq talents visibles
> Catalogue `data/talents/` (nom, description, `classe`/`race`, `cache`) ; `Simulation.talents_de(e)` = talent de la classe + talent de la race + `talents_appris`. Codés : **Râtelier vivant** (Le Sabre : un changement d'arme à 0 tick par chaîne, le compteur se réarme quand la chaîne se résout), **Souffle rendu** (La Paume : chaque soin pose un segment de l'élément dominant de la cible ; ses coups d'arme n'en posent aucun), **Meute** (La Trace : les coups de ses compagnons posent des segments sur **sa** jauge), **Œil du prix** (La Balance : +1 place d'escorte ; la bourse des marchands n'est lisible que par elle — les autres voient « ? »), **Sans maître** (Le Vent : commence sans talent, apprend celui d'un PNJ à relation ≥ 75 — option *Apprendre* du dialogue — et peut en changer). Les PNJ portent désormais une **classe** tirée parmi `classes_possibles` de leur fonction : trouver un Passeur reste possible quand ses talents existeront. Attendent : Communion des cinq, Main du métal, Fiole vive, les onze cachés (jauges de classe, portails, glyphes…).

> [!success] Codé le 2026-08-28 — Main du métal, Fiole vive
> **Main du métal** (La Braise) : intention `reforger` (inventaire, touche B sur un objet à composants, puis un composant du sac de la même famille de slot) — à la station de la recette de l'objet ; le composant remplace celui du slot, **stats, éléments, qualité et matériau sont recalculés** à partir des matériaux des composants présents (moyenne pondérée par `craft.poids`, sans le jet d'assemblage — simplification consignée), **les affixes restent**. Décision : seuls les objets dont la base a des `slots` se reforgent (les prototypes n'ont pas de composants). **Fiole vive** (Le Creuset) : boire une potion l'applique aussi aux **alliés adjacents** (forme carré r1) ; la distillation consomme **le double** d'ingrédients. **Communion des cinq** attend (le cycle automatique de l'élément d'arme demande le mécanisme des cinq accès).

> [!success] Codé le 2026-08-28 — La Mèche, première classe cachée
> `classes/la_meche.json` (tag `cache`, hors création : s'apprend d'un PNJ qui la porte, comme les autres) et le talent **Chaîne d'amorces** : quand une bombe explose, **les bombes en attente dans son rayon explosent aussitôt** (en chaîne, dans l'ordre de proximité), et la classe porte le **friendly fire intégral** que toutes les bombes ont déjà. Les PNJ tirent leur classe parmi `classes_possibles` — pour qu'un Passeur ou une Mèche existe quelque part, une fonction doit lister la classe : l'artisan et le mineur peuvent être La Mèche. Reste des cachées : Passeur, Sablier, Sceau, Masque, Porteur, Ombre, Écarlate, Rieur, Fossoyeur, Engrenage. **Constat** : les capacités du joueur sont encore les trois de la fiche `aventurier` — l'assemblage de capacités depuis `modules_connus` (Structure compétences-modules-slots) n'a pas d'écran ; c'est le prochain chantier, préalable au domaine de Vie.

> [!success] Codé le 2026-08-28 — Communion des cinq
> Le Souffle : l'élément de son arme **tourne seul** dans le cycle d'engendrement (bois → feu → terre → metal → eau) à chaque coup qui pose un segment — `e.element_communion` remplace l'élément de l'arme dans `_affixes_offensifs` ; chaque rotation coûte `combat_rules.talents.communion_des_cinq.mana` (2) de mana d'entretien, sans mana l'élément reste. Accès n° 2 des [[Cinq accès au cycle]] ; l'enchantement déclencheur, les anneaux de transmutation et les armes fantomatiques attendent.

> [!success] Codé le 2026-08-28 — L'Ombre et Le Rieur, et le jet de coup
> Un **jet de d20 par coup d'arme** est ajouté au pipeline (il n'existait pas ; `crit_range` des fonctionnalités le prévoyait) : `≥ crit_range` (20) → **critique ×1,5** (`combat_rules.degats.crit_mult`) ; `≤ fumble_max` (1) → **coup raté** (0 dégâts, journal). **Le Rieur** (classe cachée, talent *Deux queues*) : critiques 19-20 **et** échecs 1-2, plus **une relance par combat** d'un jet raté (réarmée à chaque engagement). **L'Ombre** (classe cachée, talent *Dissimulation*) : statut **Dissimulé** (`status_effects/dissimule`, un jour) après chaque mise à mort — les IA ne le voient qu'adjacent ; attaquer le lève ; ses coups **de face** font −25 % (dos et flancs intacts). Le « hors combat » de la note n'est pas encore un déclencheur (seule la mise à mort dissimule) ; les pièges invisibles attendent les pièges.

> [!success] Codé le 2026-08-28 — L'Écarlate et Le Porteur
> **L'Écarlate** (talent *Jauge de sang*) : `e.sang` 0-100, remplie par les dégâts subis (+dégâts), multiplie les dégâts infligés à l'arme (`× (1 + 0,8 × sang/100)`, ×1,8 pleine) ; **tout soin la vide** (capacité de soin, plat, potion de soin, sommeil) — décision : vidée d'un coup plutôt que proportionnellement, pour que le choix « survivre ou frapper » soit net. Le HUD montre `sang N %`. **Le Porteur** (talent *Saisie*) : intention `saisir` (clic droit → *Saisir*) sur un être adjacent, alliés compris — l'être est `saisi` (statut de contrôle, il ne bouge plus) ; tant qu'il porte, le Porteur **ne peut ni attaquer ni se garder** ; `lancer_etre` (clic droit sur une tuile → *Lancer*) projette l'être de 3 tuiles dans la direction visée avec `1d6` de dégâts à l'arrivée ; la cible saisie **se débat** à son tour (jet de Force opposé, `_ia_se_debattre`) et se libère si elle gagne. La jauge de sang est bien « le même objet de code » que la jauge de chaîne côté données (un entier borné) — pas de classe à part.

> [!success] Codé le 2026-08-28 — Le Passeur et Le Sablier
> **Le Passeur** (talent *Brèche*) : clic droit sur une tuile libre adjacente → *Poser un portail* ; deux portails au plus, **poser un troisième déplace le plus ancien** (repositionnables), hors slot et sans entretien ; **n'importe qui** debout sur un portail peut *Traverser* (E) vers son jumeau s'il est libre — les IA ne les empruntent pas encore. Contrepartie : **mana max × 0,7** (`mana_max_mult` posé sur l'être, lu par `Etres.recalculer`). **Le Sablier** (talent *Maître du tempo*) : clic droit sur un ennemi à ≤ 3 tuiles → *Voler du tempo* : l'ennemi est retardé de `tempo_vole` ticks (par `_tempo`, donc dans le budget anti-stunlock : refusé pendant le verrou), le Sablier avance le sien d'autant, et **paie `sante` points de santé** (5) — jamais sous 1. Décision : le vol est une intention à part (pas un module), pour ne pas dépendre de l'écran de composition.

> [!success] Codé le 2026-08-28 — Le Masque et Le Sceau
> **Le Masque** (talent *Masques*) : les « postures » n'existaient pas hors la garde — décision : un **masque est un statut** (`status_effects/masque_*.json`, tag `masque`, modificateurs `stat:` ; trois masques : Taureau +3 Force +2 Endurance, Renard +3 Dextérité +2 Agilité, Hibou +3 Esprit +2 Perception). Clic droit sur sa propre tuile → *Porter le masque …* : **0 tick**, deux masques au plus (le troisième remplace le plus ancien), le même masque se retire. Contrepartie : **la garde est refusée** (le masque occupe la main secondaire). Aucune donnée d'objet-masque : le masque est le statut, pas un item — à revoir quand les sprites viendront. **Le Sceau** (talent *Graveur*) : ses glyphes (`entree`) **ne s'effacent jamais** (échéance repoussée hors horizon), coûtent **2× le mana** (le second prélèvement se fait à la pose) et la gravure applique le statut **Gravure** (immobile `gravure_ticks` = 6 ticks, sans anti-stunlock — ce n'est pas un contrôle subi). Clic droit sur l'un de ses glyphes à ≤ 8 tuiles → *Déclencher* : la charge part sur la tuile, occupée ou non ; plusieurs glyphes coexistent déjà (ils s'accumulent dans `glyphes`).

> [!success] Codé le 2026-08-28 — Le Fossoyeur et L'Engrenage : les onze cachées sont codées
> **Le Fossoyeur** (talent *Releveur*) : clic droit sur un cadavre à ≤ 2 tuiles → *Relever* : un **nouvel être de la même fiche** se lève sur la tuile du cadavre (libre), au camp du Fossoyeur, `maitre` = lui, tag `releve`, et **meurt seul** après `duree_ticks` (60) — expiré dans `_tiquer_differes` comme les glyphes ; un cadavre ne se relève qu'une fois. Contrepartie : **chaque relève coûte `reputation` (−10) auprès de tous les villages connus** — décision : la « chute continue » est portée par l'acte (il n'y a pas de crochet journalier de réputation), à revoir si un jour de jeu en reçoit un. **L'Engrenage** (talent *Affût*) : clic droit sur une tuile libre adjacente → *Déployer l'affût* : une **tourelle portative** (contenu `barriere`, dessinée en gris) ; une seule — redéployer la déplace ; elle tire toutes les `cadence_ticks` (4) sur l'ennemi le plus proche à `portee` (6) en ligne de vue, `degats` (1d6) avec **les éléments de l'arme équipée** ; chaque tir **consomme une munition du carquois**, et **sans munition l'affût se replie**. Décision : « à chaque tick » de la note devient une cadence de 4 ticks, sinon un carquois de 20 flèches se vide en 20 ticks.

> [!success] Codé le 2026-08-28 — l'effet `saisie` du module Empoigne
> Le dernier effet de module encore vide : **Empoigne** (noyau de contrôle, signature du Porteur mais lisible par tous) **saisit la première cible vivante adjacente** de la forme — même mécanique que le talent (`_saisir` sans l'exigence du talent : statut *Saisi*, `porte` / `saisi_par`, la cible se débat à son tour), puis *Lancer* au clic droit comme pour le Porteur. Décision : **quiconque porte quelqu'un ne frappe ni ne se garde** — la contrepartie du talent est en fait la contrepartie de l'acte, la garde est désormais refusée aussi. Ce qui distingue Le Porteur : saisir sans capacité, sans mana ni endurance, à chaque tour.

> [!success] Codé le 2026-08-29 — les IA empruntent les portails
> `Simulation.portail_utile(e, but)` : parmi les portails à `breche.ia_portee` (8) tuiles ou moins d'un être, celui dont le **jumeau libre** rapproche le plus du but, à condition de gagner au moins `breche.ia_gain_min` (6) tuiles. `_ia_pas_vers` (poursuite) et `_ia_pas_routine` (routine, patrouille, suivi d'un compagnon) l'interrogent d'abord : debout **sur** le portail retenu, l'IA *traverse* (même coût que pour le joueur) ; sinon elle fait un pas vers lui. Décision : **tout le monde** emprunte les portails, y compris les bêtes et les assaillants d'un raid — c'est la contrepartie assumée d'une brèche laissée ouverte près de chez soi ; le Passeur peut toujours la déplacer (poser un troisième portail efface le plus ancien).

> [!success] Codé le 2026-08-29 — les IA empruntent les portails
> `Simulation.portail_utile(e, but)` : parmi les portails à `breche.ia_portee` (8) tuiles ou moins d'un être, celui dont le **jumeau libre** rapproche le plus du but, à condition de gagner au moins `breche.ia_gain_min` (6) tuiles. `_ia_pas_vers` (poursuite) et `_ia_pas_routine` (routine, patrouille, suivi d'un compagnon) l'interrogent d'abord : debout **sur** le portail retenu, l'IA *traverse* (même coût que pour le joueur) ; sinon elle fait un pas vers lui. Décision : **tout le monde** emprunte les portails, y compris les bêtes et les assaillants d'un raid — c'est la contrepartie assumée d'une brèche laissée ouverte près de chez soi ; le Passeur peut toujours la déplacer (poser un troisième portail efface le plus ancien).

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Classes]], [[Structure compétences-modules-slots]], [[Vocabulaire des modules — six axes]]
- **Alimente** : [[Fonctions]], [[Création de personnage]], [[Schéma créature]], [[Statuts]]
- **Voir aussi** : [[Talents de race]], [[Jauge de chaîne Wu Xing]], [[Boucle de tick]], [[Familles de capacités de la grille]], [[L'information comme récompense]], [[Piliers d'inspiration]]
