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

## Liens
- **Dépend de** : [[Qualité d'artisanat]], [[Claims et persistance]]
- **Alimente** : [[Prix suggéré]], [[Boutique passive]], [[Économie — sources et puits]]
- **Voir aussi** : [[Meubles]], [[Lois et infractions]], [[Barèmes économiques]], [[Dialogue PNJ]], [[Écrans d'interface]], [[EventBus]]
