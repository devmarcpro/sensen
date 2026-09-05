---
aliases: ["Un monde réel", "Programme monde réel", "Villes vivantes", "Calendrier", "Monde réel"]
tags: [société, monde, simulation, décidé, designer]
domaine: société
statut: décidé
etape: 11
---

Le programme du 5 septembre : des villes dont la taille suit la population, des PNJ qui se distinguent, des royaumes qui simulent un vrai pays, un calendrier, et l'agriculture au cœur des villes. Quand tout cela tient et se vérifie, la 0.5.0.

## Les directives du designer (2026-09-05, de 14 h 15 à 14 h 40, reproduites telles quelles)

> « retravaille les villes pour que la taille de la ville dépende de la population donc qu'une ville puisse même occupé plusieurs cellules, avoir des districts , des rues, de la variété, des logements, des commerces, des zones de production, une économie etc. chaque ville doit être réel et vivante »
>
> « idem pour les pnj chaque pnj doit donner l'impression d'être vivant et réel et se différencier des autres »
>
> « pareil du coup pour l'échelle royaume qui est au dessus de la ville, le royaume doit avoir une réelle identité propre et simulé un vrai pays »
>
> « tu en profiteras pour rajouter le calendrier, très important pour le realisme et les fonctionnalités »
>
> « avec aussi l'agriculture évidemment très très très important pour les villes […] j'ai oublié de dire mais l'agriculture c'est les champs/les animaux etc »
>
> « selon la politique du royaume le dirigeant d'une ville change, une mairie ? un château ? ça dépend »
>
> « et quand tu auras fini tout ça on pourra passer à la 0.5.0 »
>
> (15 h 20) « marchands itinérants, marchés, fêtes, etc » — « rails avec trains pour lier les villes d'un même royaume, chevaux montés et calèches pour transport intra muros etc » — « un camp et une ville sont identiques donc s'il y a des résidences à un endroit c'est qu'il y a un périmètre de résidence, tu vois ce que je veux dire ? la gestion de camp et les villes sont exactement pareils, seule différence c'est que la ville est générée. mais l'intérêt c'est que le joueur puisse faire ses propres villes et contrôler les villes générées. »

Ce sont des directives, pas des questions : elles s'appliquent. Ce qui reste à trancher — les chiffres, les seuils, ce qui plaît ou non à l'écran — est consigné dans [[À juger — parcours de jeu]] avec la façon de le défaire ([[Prompt de la boucle]]).

## Ce qui existe déjà, et sur quoi le programme s'appuie

- **Les villages d'une cellule** ([[Villages PNJ — repeuplement et décimation]], [[Génération des royaumes PNJ]]) : une place, trois à douze bâtiments préfabriqués (`data/village_buildings/`) posés en anneaux, des boutiques et des halls tirés sans doublon selon la taille du royaume pour sa capitale, un résident par lit, un garde sur la place, le dirigeant dans la capitale. Un chemin de chaque porte à la place. Repeuplement hebdomadaire jusqu'à la capacité (les lits), décimation, abandon, conquête.
- **Les royaumes** ([[Schéma royaume]], [[Gouvernance, lois et diplomatie]], [[Génération des royaumes PNJ]]) : déterministes par secteur, avec nom, gouvernance, culture de nommage, race dominante, territoire contigu qui ne franchit pas l'eau, capitale, routes, lois, douanes, accords, successions et vacances, raids.
- **Les PNJ** ([[Âge des PNJ]], [[Apparence — données et équipement]], [[IA des créatures]], [[Dialogue PNJ]], [[Génération de noms]]) : un nom de leur culture, un âge et une espérance de vie, une famille, une humeur, une fonction, un potentiel, des loci visuels, des routines par horaires, des répliques par gabarits, des relations avec le joueur.
- **Le temps** ([[Cycle jour-nuit et sommeil]], [[Météo]], [[Boucle de tick]]) : l'heure (24 000 ticks par jour), la semaine de sept jours qui cadence toute l'économie (entretien, taxes, repeuplement, vieillissement), l'année et ses cinq saisons Wu Xing avec leur température (120 jours jusqu'au 5 septembre 16 h 40, 360 depuis).
- **L'agriculture du joueur** ([[Agriculture et élevage]], [[Élevage — intention et familles]], [[Population et exploitation]]) : parcelles, fertilité et engrais, semis et récolte par saison, élevage avec généalogie, postes de travail des résidents.

## Le programme, dans l'ordre

Chaque chunk suit la règle du coffre : un callout daté **ici** avant le code, tout en données JSON validées par schéma, une sonde qui mesure, des tests, des captures regardées, les chiffres choisis consignés dans [[À juger — parcours de jeu]].

- **A. Le calendrier** — la fondation : les marchés, les fêtes, les anniversaires, les règnes et les saisons agricoles en dépendent. Codé en premier (callout ci-dessous).
- **B. Les villes** — **une ville est un territoire, le même que le camp du joueur** (designer, 15 h 20) : des cellules à rôle, des périmètres, des résidents assignés, des stocks, un trésor — bâtis par la génération au lieu du joueur, vivants par les mêmes fonctions hebdomadaires ; le joueur bâtit ses villes avec ses outils de camp et contrôle celles qu'il prend. La population décide de tout : de la taille (une agglomération peut couvrir plusieurs cellules, chacune un quartier typé), des rues qui relient les quartiers, des logements, des commerces, des zones de production, **des champs et des bêtes autour de la ville**, d'une économie hebdomadaire (ce que la ville produit, consomme, stocke, et le prix qui en découle), du siège du pouvoir selon la gouvernance du royaume (mairie, château, temple, comptoir, caserne), des marchands itinérants et des marchés, puis des transports (rails et trains entre les villes d'un royaume, chevaux montés, calèches). → [[Villes — population, quartiers et économie]] (B0 territoires, B1 génération, B2 champs et bêtes, B3 économie et marchands itinérants, B4 transports).
- **C. Les PNJ** — chacun se distingue : des traits de caractère en données qui changent ses répliques, ses prix, ses horaires et ses envies ; une histoire courte ; des souhaits qui font des quêtes ; un anniversaire et un signe ; ce qu'il sait et ce qu'il dit du monde.
- **D. Les royaumes** — un pays simulé chaque semaine : population, trésor, armée, humeur du peuple, règne et ère, blason et couleurs sur les gardes et les bannières, événements (couronnement, disette, édit, guerre), échanges entre ses villes.
- **E. La 0.5.0** — quand A à D tiennent, sont vérifiés par la suite, les sondes et les captures, et que le designer les a vus : le deuxième chiffre bouge, sur sa décision ([[Prompt de la boucle]] : le deuxième chiffre ne bouge que sur décision du designer, et il l'a dite).

> [!success] Décidé et codé le 2026-09-05, 15 h — A, le calendrier
> **Ce qui est décidé** (`data/calendrier.json`, validé par son schéma dans `data/schemas/`, lu par `Calendrier`, une classe statique de `systems/worldgen/`) :
> - **L'année fait 360 jours : douze mois de trente jours** (designer, 16 h 40 : « pour le calendrier on va plutôt faire 12 mois de 30 jours » — la première version disait douze mois de dix jours sur l'année de 120 jours de [[Âge des PNJ]] ; `combat_rules.age.jours_par_an` et `planete.cycle.saisons.jours_par_an` passent à 360, les cinq saisons gardent leurs proportions : printemps 90 jours, été 60, fin d'été 30, automne 90, hiver 90). Les mois portent les douze animaux du cycle sexagésimal ([[Astrologie — cycle sexagésimal]]) : Rat, Bœuf, Tigre (printemps), Lapin, Dragon (été), Serpent (fin d'été), Cheval, Chèvre, Singe (automne), Coq, Chien, Cochon (hiver) — les bornes des saisons tombent exactement sur des débuts de mois.
> - **La semaine reste de sept jours** (`planete.corruption.ticks_par_semaine`, la cadence de tout ce qui est hebdomadaire) et ses jours s'appellent jour du Soleil, de la Lune, du Feu, de l'Eau, du Bois, du Métal, de la Terre — la semaine d'Asie orientale, qui va à un monde Wu Xing. Le jour de la semaine ne se recale pas sur l'année (360 = 7 × 51 + 3 : il dérive de trois jours par an, comme le nôtre d'un).
> - **Les années se comptent** à partir de `annee_depart` (1 020 : l'écran de création propose une naissance en l'an 1 000, [[Écrans d'interface]] — le personnage a vingt ans). Une partie commence le 1 du Rat de l'an 1 020, un jour du Soleil, à 8 h.
> - `Calendrier.date(jour)` → {annee, mois, jour_mois, jour_semaine, jour_de_l_an} ; `Calendrier.texte(date)` → « jour du Feu, 7 du Cheval, an 1 020 ». Le bloc d'information et le volet montrent la date ; **le journal ouvre chaque nouveau jour par sa date**.
> - **Le jour de marché** : chaque agglomération a le sien, un jour de la semaine tiré de son nom ; ce jour-là ses marchands se réapprovisionnent (`marche.stock_mult`) et vendent moins cher (`marche.prix_mult`), et le journal le dit en arrivant.
> - **Les fêtes** (`fetes`) : trois communes à toutes les cultures — le nouvel an (1 du Rat), les semailles (15 du Tigre), les moissons (30 du Singe, le dernier jour de l'automne) — et une par culture de nommage : les lanternes (sino), Yule (nordique), les saturnales (latine), Samain (celte), hanami (nipponne), Kupala (slave), Yennayer (arabo-berbère). Le jour d'une fête, les civils de la culture tiennent la place au lieu de leur poste (la routine « fête » vaut « social » toute la journée, pour les profils d'IA qui portent `fetes: true` — le civil, pas le garde), leur humeur monte de `fetes.humeur`, et le journal l'annonce. **Une partie commence donc un jour de fête** (le 1 du Rat) : le premier village visité est sur sa place ; les tests qui regardent la routine se placent un jour calme.
> - **L'anniversaire** de chaque PNJ (mois et jour tirés de son identifiant) et **son signe** dérivé de son année de naissance (l'année courante moins son âge) — le signe des PNJ manquait ([[Âge des PNJ]] le promettait « gratuitement »). Le règne des royaumes (D) datera ses années sur ce calendrier.
> - **Sauvegarde** : rien à sauver, la date est une fonction des ticks du monde.
> **Revers** : `annee_depart`, les noms, les fêtes et les deux facteurs du marché sont des données ; les longueurs des mois, `age.jours_par_an` et `saisons.jours_par_an` doivent rester d'accord (le test le vérifie). Le jour de la semaine et le jour de marché sont des lectures pures : aucun état.

## Liens
- **Dépend de** : [[Villages PNJ — repeuplement et décimation]], [[Génération des royaumes PNJ]], [[Schéma royaume]], [[Âge des PNJ]], [[Cycle jour-nuit et sommeil]], [[Agriculture et élevage]]
- **Alimente** : [[Villes — population, quartiers et économie]], [[Commerce et boutiques]], [[Dialogue PNJ]], [[IA des créatures]], [[Écrans d'interface]], [[Vers la production]]
- **Voir aussi** : [[À juger — parcours de jeu]], [[Prompt de la boucle]], [[Astrologie — cycle sexagésimal]]
