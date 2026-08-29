---
aliases: ["F.3", "Annexe F.3", "Créatures", "Bestiaire", "Races animales", "Catalogue des créatures"]
tags: [contenu, êtres, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

> [!warning] Restructuré le 2026-08-26
> L'ancien F.3 mélangeait **des espèces** (loup, ours) et **des humains à métier** (forgeron, bandit, roi) dans une même liste. Depuis [[Les trois axes — race, classe, fonction]], ce n'est plus tenable : un forgeron n'est pas une créature, c'est `humain · La Braise · artisan · résident`.
> **Cette note ne contient plus que des races animales.** Les humains sont désormais des **combinaisons** — voir [[Profils de PNJ]].

Le bestiaire : **19 races animales**, réelles. La menace vient des bêtes, des humains hostiles et de l'environnement.

*Format : nom — squelette — niv. combat approx — profil IA — recrutable — notes. Toutes suivent le schéma [[Schéma créature]], avec `race` = l'espèce. **Aucune créature fantastique — décision ferme** ([[Ouvert — Créatures fantastiques]]).*

## Plaines et forêts tempérées

Loup (quadrupède, nv 6, bete_sauvage, meutes 1d4+1, dressage) · Sanglier (quadrupède, nv 8, bete_sauvage acculée, dressage) · Cerf (quadrupède, nv 3, fuit, dressage) · Renard (quadrupède, nv 3, fuit, dressage) · Essaim d'abeilles (amorphe, nv 4, hostile près de la ruche, jamais — miel récoltable)

## Désert

Scorpion (quadrupède bas, nv 7, hostile, dressage, statut poison) · Vautour (volant, nv 5, hostile si blessé détecté, dressage) · Chameau sauvage (quadrupède, nv 6, fuit, dressage — monture endurante)

## Toundra et taïga

Ours polaire (quadrupède, nv 18, bete_sauvage, dressage, fourrure isolante) · Loup blanc (quadrupède, nv 8, meutes, dressage) · Renne (quadrupède, nv 4, fuit, dressage/élevage) · Morse (quadrupède, nv 12, bete_sauvage sur la côte, dressage)

## Marécage

Crocodile (quadrupède bas, nv 14, embuscade aquatique, dressage) · Nuée de moustiques (amorphe, nv 4, hostile, jamais, dégâts continus faibles + risque infection) · Serpent venimeux (amorphe, nv 8, hostile si approché, dressage, poison)

## Montagne

Aigle (volant, nv 7, bete_sauvage, dressage) · Ours brun (quadrupède, nv 16, bete_sauvage, dressage) · Bouquetin (quadrupède, nv 4, fuit, dressage/élevage) · Lynx (quadrupède, nv 9, embuscade, dressage)

## Ce qui étend le bestiaire

**Les espèces d'élevage** ([[Catalogue des groupes d'élevage]], Annexe H) — 35 groupes, chacun une fiche de données : insectes, poissons, serpents, vers à soie, ruches, tortues, phalènes… Ce sont des races au même titre, avec un bloc `génome` en plus.

**Les créatures de donjon** ([[Génération de donjon]]) : les niches sont occupées par les **humains hostiles** ([[Profils de PNJ]]) et les **bêtes tanières** (ours, loups) — un donjon est une ruine investie, pas une crypte magique. La haute corruption produit des bêtes réelles de plus haut niveau et des **variantes rares** ([[Monstres rares]]), pas d'autres espèces.

## Drop rare universel — la statue 1:1

Toute créature a une faible chance (défaut **0.5 %**, pondérable par race) de dropper une **statue d'elle-même à l'échelle 1:1** — un meuble décoratif ([[Meubles]]) généré automatiquement : le modèle assemblé exact de la créature (ses parties tirées, [[Squelette modulaire et points d'attache]]), **recolorisé en pierre** via le remapping de palette existant ([[Entités et pathfinding — performance]] — zéro asset à produire). Trophée de chasse ultime, objet de collection et de prestige (humeur/déco), valeur de vente ∝ niveau de la créature.

## Rappels de systèmes

**Profils d'IA ([[IA des créatures]]) :** `hostile`, `bete_sauvage`, `civil`, `garde`, `assaillant`, `compagnon`.

**Actions ([[Actions des créatures]]) :** 24 actions partagées par famille — morsures, charges télégraphiées, meute, embuscade, volants.

**Spawns nocturnes ([[Cycle jour-nuit et sommeil]]) :** les tables de spawn par biome ont un volet « nuit » — loups en chasse, prédateurs embusqués, humains hostiles en maraude.

**Viandes et parties dérivées :** [[Catalogue matériaux — Paramétriques]].

> [!success] Décidé le 2026-08-26 — les six adversaires du prototype, chiffrés
> Aucune fiche ne donnait de stats : voici celles de `data/creatures/` (six stats, PV = 20 + End × 4 — [[Stats de personnage]]), valeurs de premier équilibrage à ajuster au playtest :
>
> | Fiche | For | Dex | End | Vol | Per | Cha | PV | Actions / arme | IA |
> |---|---|---|---|---|---|---|---|---|---|
> | Loup | 7 | 12 | 5 | 3 | 12 | 2 | 40 | morsure, harcelement_meute, hurlement | hostile |
> | Sanglier | 12 | 6 | 10 | 4 | 8 | 2 | 60 | coup_de_defenses, charge | hostile |
> | Bandit | 11 | 10 | 9 | 7 | 9 | 8 | 56 | épée + cuirasse de cuir | hostile |
> | Chef de bande | 13 | 12 | 12 | 9 | 10 | 12 | 68 | épée, bouclier, casque de fer, mailles + cri_de_ralliement, enchainement (`chain_gauge`) | hostile |
> | Aigle | 5 | 15 | 4 | 3 | 16 | 2 | 36 | serres, pique_plongeant (volant) | hostile |
> | Scorpion | 6 | 9 | 6 | 2 | 8 | 1 | 44 | pique_venimeuse, pinces | hostile |
> | *Aventurier (joueur)* | 12 | 10 | 12 | 8 | 10 | 8 | 68 | épée, casque et cuirasse de cuir ; râtelier des 6 armes + bouclier | — |
>
> **Profil IA des bêtes dans les arènes :** le catalogue donne `bete_sauvage` au loup et au sanglier ; le prototype les met en **`hostile`** — ce sont des loups **en chasse** ([[Cycle jour-nuit et sommeil]] : « loups en chasse » la nuit) et un sanglier **acculé** dans sa gorge, ce que la spec exige pour tester l'encerclement et la charge. Le profil est un champ de la fiche, changer d'avis = éditer un JSON. La **détection** est `Perception` tuiles avec ligne de vue ([[IA des créatures]]).

> [!success] Codé le 2026-08-28 — étape 9.B : la faune de surface (`planete.faune`, biomes `faune` / `faune_nuit`)
> Champ `faune` (`[{id, density}]`) et `faune_nuit` par biome, sur le modèle de `vegetation` ; nouveaux : cerf et renard (profil `proie` : fuient, errent), le loup et le sanglier reprennent `bete_sauvage` de jour et le loup redevient `hostile` en **meute (1d4+1)** la nuit. Spawn (décision, la note ne chiffrait rien) : toutes les 200 ticks, si moins de **12 bêtes** dans la fenêtre, une bête (ou une meute) apparaît dans l'anneau **12-40 tuiles** hors ligne de vue, tirée dans la faune du biome de la tuile — **densité ×2 la nuit** avec le volet nuit ; **despawn** au-delà de 60 tuiles hors combat (jamais de suppression brutale sous les yeux). La Discrétion +4 est codée (2026-08-29 : elle réduit la portée de détection). Les 15 autres races du bestiaire s'ajoutent en données.

> [!success] Codé le 2026-08-28 — les 19 races animales
> Douze fiches de plus dans `data/creatures/` (le bestiaire en comptait sept) : essaim d'abeilles, vautour, chameau sauvage, ours polaire, loup blanc, renne, morse, crocodile, nuée de moustiques, serpent venimeux, ours brun, bouquetin, lynx — stats calées sur le niveau approximatif de la note (Force ≈ nv + 2 pour les grands prédateurs, Dextérité pour les embusqués), actions de créature du catalogue (dard d'essaim, becquetage/serres, ruade, coup de patte / masse écrasante / morsure puissante, mâchoire verrouillée / embuscade, nuée, morsure venimeuse, coup de tête / bond, griffure / bond), `depouille` en parties de créatures ; `rare_chance` par défaut pour les prédateurs, 0 pour les nuées (jamais recrutables, tag `nuee`). **Les biomes les reçoivent** : désert (vautour, chameau), toundra (ours polaire, loup blanc, renne, morse), taïga (loup blanc, renne), marécage (crocodile, moustiques, serpent), montagne (ours brun, bouquetin, lynx), plaine/forêt (essaim). Le dressage suit les tags existants (`bete`, `proie`) ; les montures (chameau) attendent les véhicules.

## Liens
- **Dépend de** : [[Schéma créature]], [[Les trois axes — race, classe, fonction]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[Profils de PNJ]], [[Catalogue matériaux — Paramétriques]], [[Monstres rares]], [[Actions des créatures]], [[Génération de donjon]]
- **Voir aussi** : [[Apprivoisement et recrutement]], [[Catalogue des groupes d'élevage]], [[Cycle jour-nuit et sommeil]], [[Ouvert — Créatures fantastiques]]
