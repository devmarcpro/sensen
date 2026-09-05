---
aliases: ["7.1", "7.1 Commerce et boutiques", "Commerce", "Boutiques"]
tags: [société, économie, décidé]
domaine: société
statut: décidé
etape: 9
---

Vendre aux marchands, ou tenir sa propre boutique passive sur son claim — façon Elona, sans avoir à être présent.

- **Vendre à des marchands PNJ existants** : possible directement, comme dans un RPG classique.
- **Tenir sa propre boutique** : possible aussi, en boutique **passive sur sa case claim** — les PNJ viennent acheter tout seuls, façon Elona (le joueur n'a pas besoin d'être présent pour vendre). Voir [[Boutique passive]].
- **Prix :** un **prix suggéré est calculé automatiquement** (probablement à partir de la rareté/qualité/matériaux de l'objet — à relier au système de qualité, [[Qualité d'artisanat]]), mais le joueur peut **ajuster ce prix librement**. Voir [[Prix suggéré]].
- **Monnaie :** une **monnaie unique** (or), pas de multi-devises ni de troc.

**Décisions (résolu) :**
- **Prix : formule [[Prix suggéré]]** (valeur matériaux × 1.5 × qualité × rareté × réputation).
- **Limite : l'étal est un meuble physique** ([[Meubles]], 12 slots) — plus d'étals = plus de slots de vente.
- **Consultation à distance : non au lancement** — l'or s'accumule dans le coffre de la boutique, relevé sur place ([[Boutique passive]]) ; consultation à distance = extension future.

**Portefeuille de PNJ fini ([[Économie — sources et puits]]) :** un marchand à sec **refuse d'acheter en or** au-delà de son stock — il propose un **troc en objets** de valeur équivalente plutôt qu'un refus sec.

**Douanes ([[Lois et infractions]]) :** à la vente en boutique d'un royaume différent de l'origine du bien, `prix_final = prix_suggere × (1 - tariffs[categorie])`.

**Signal :** `item_sold` sur l'EventBus, écouté par l'or et la réputation marchande ([[EventBus]]).

**Écran dédié ([[Écrans d'interface]]) :** *Commerce (achat/vente, gestion d'étal)*.

> [!success] Codé le 2026-08-28 — étape 9.A, l'or, le marchand, l'écran Commerce
> **L'or** existe : `e.or` sur tout être (le joueur part à 0), portefeuille du PNJ = `base(fonction) × (1 + rang × 0,5)` (`data/functions/*.portefeuille` : villageois 30, marchand 300 — [[Barèmes économiques]]), recharge +15 % par semaine (`Monde.semaine`). **Prix suggéré** tel quel : `valeur_base_objet × qualité × facteur_rareté × facteur_réputation`, `valeur_base_objet = Σ valeur_base des matériaux × quantités × 1,5` (objet assemblé : ses composants ; matériau brut : sa valeur ; objet du prototype : son matériau × `valeur_par_defaut`), table `facteur_rarete` de [[Prix suggéré]] (1 / 1,4 / 2,2 / 4 / 10, +0,35 par affixe, +0,5 par sertissure occupée), `facteur_reputation = 1 + relation/200` borné [0,5 ; 2], paliers −49..−20 : +25 %, +20..+49 : −10 %. **Décision** : le marchand **achète à 50 %** du prix suggéré et **refuse quand il est à sec** (le troc automatique attend) ; il vend son stock au prix suggéré. L'écran montre **le détail du calcul**. Signal `item_sold`. La boutique passive, l'étal du joueur, les douanes attendent.

> [!success] Corrigé le 2026-08-29 — une boutique tenait une **liste d'objets**, pas un métier
> Signalé par le designer : le craft et les boutiques désignaient des **choses définies** là où le jeu se veut piloté par des **catégories**. C'était vrai à la lettre — `shop_types/*.json` portait un champ `inventaire` avec les ids écrits à la main (`["proto_epee", "proto_hache", "proto_pioche", …]`), et les deux créatures marchandes un `inventaire_marchand` du même genre. Conséquence directe : **un objet ajouté au jeu n'était vendu nulle part** tant qu'on n'éditait pas six fichiers à la main — la pelle et le seau ajoutés le matin même n'étaient dans aucune boutique.
> Un type de boutique décrit désormais **ce qu'il vend, par catégorie** : `selection: [{filtre, nombre}]`, où le **filtre** se lit `types_any` / `tags_any` / `tags_all` / `tags_none` / `categories_materiau` / `exclut` (`GameData.filtrer` et `GameData.tirer`, résultat trié et mis en cache). L'armurier vend « les armures et boucliers de prototype **en métal** », le tailleur « les mêmes **en végétal ou en bois** » (cuir, lin, soie), l'alchimiste « les potions » et « les parties de bête », l'épicier « les cultures et les ingrédients, ni potion ni herbe », l'herboriste « les herbes, champignons et baies ». **Décisions** : les catégories de matériau viennent de `materials.*.category`, pas d'une liste de matériaux ; quatre soins reçoivent un tag **`soin`** (bandage, fioles, antidote) — le tag manquait pour dire « ce que vend un armurier en plus des plaques » ; le marchand se **réapprovisionne** quand son stock est vide, à la recharge hebdomadaire des bourses ; le tirage est semé par `(graine, id du marchand, semaine)`, donc reproductible.

> [!bug] Corrigé le 2026-09-02 — cent soixante-dix-neuf ennemis tués, zéro pièce d'or
> Mesuré sur la collecte du robot : six étages, 179 kills, 47 ramassages… et **0 or**. Rien dans le jeu ne donnait de monnaie : ni les hostiles, ni les coffres. Toute l'économie — acheter chez le forgeron, payer l'entretien, commander à un artisan — reposait donc sur la seule **vente** de son butin. Un hostile laisse désormais une **bourse** : un nombre de pièces tiré autour de sa valeur (ses PV et son niveau de combat), avec une chance par palier de profondeur. Un bandit d'étage 1 laisse quelques pièces, un boss d'étage 5 de quoi s'équiper. Les réglages sont dans `loot_rules.drops.or`.


> [!success] Constaté le 2026-09-03 — `inventaire_marchand` est codé sous le nom `stock_marchand`
> La fiche d'une créature marchande porte `stock_marchand` (une liste de blocs de sélection, assemblée au boot en boutique) ; le nom proposé ici n'a jamais été celui du code. Rien d'autre ne change.

> [!success] Codé le 2026-09-05, 15 h — le jour de marché (Calendrier)
> Chaque agglomération a son jour de marché, un jour de la semaine tiré de son nom (`Calendrier.jour_de_marche`). Ce jour-là, au lever du jour, ses marchands regarnissent leur étal jusqu'à `marche.stock_mult` fois un garnissage complet (`_garnir_marche`, le plafond vient de `stock_garni` noté par `_garnir_stock`), et `prix_suggere` multiplie ses prix par `marche.prix_mult` (0,9 — le champ `marche` du détail). Le journal dit « c'est jour de marché à X » si un marchand a regarni ; le marchand le dit aussi (réplique `marche`). Les autres jours, rien ne change — et le réapprovisionnement hebdomadaire d'un étal vidé reste.

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Claims et persistance]]
- **Alimente** : [[Prix suggéré]], [[Boutique passive]], [[Économie — sources et puits]]
- **Voir aussi** : [[Meubles]], [[Lois et infractions]], [[Barèmes économiques]], [[Dialogue PNJ]], [[Écrans d'interface]], [[EventBus]]

> [!bug] 2026-09-05, 12 h 50 — le designer : « les commerces sont cassés, la plupart n'ont rien à vendre ou vendent seulement des boucliers non craft »
> Mesuré par `sonde_commerce.tscn` (les filtres de chaque boutique, un étal garni de chaque type, les marchands du village le plus proche). **Le tailleur** vendait quatre `proto_bouclier` : son filtre demandait des armures « prototype » en matière végétale ou bois, écrit quand les vêtements assemblés n'existaient pas encore — depuis, le seul objet qui y répond est le bouclier de fortune en chêne. Il vend désormais les **vêtements** (armures `vetement` ou `rituel`, en fibre, soie ou cuir : tunique, robe, capuche, coiffe, chausses, chaussons, manchettes, étole) et parfois une cape ou un sac. Les six autres filtres tirent bien (14 potions, 14 armures assemblées, 16 denrées, 36 armes…) et la génération rend des objets composés. **Second trou** : le réapprovisionnement hebdomadaire ne regarnissait qu'une boutique typée ; un marchand ou un forgeron « de fiche » (`stock_marchand`) vidé par le joueur ne vendait plus jamais rien — `_reapprovisionner` regarnit les deux. **Troisième** : le maître de guilde portait `commerce_possible` sans stock ni boutique — « Commercer » ouvrait un étal vide ; il ne le porte plus (il donne des quêtes, [[Dialogue PNJ]] : « Commercer : tag commerce_possible + PNJ marchand/étal »). Test `test_boutiques_vendent` ; la sonde est dans le README.
