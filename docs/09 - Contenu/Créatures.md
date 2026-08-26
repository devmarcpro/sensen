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

## Liens
- **Dépend de** : [[Schéma créature]], [[Les trois axes — race, classe, fonction]], [[Squelette modulaire et points d'attache]]
- **Alimente** : [[Profils de PNJ]], [[Catalogue matériaux — Paramétriques]], [[Monstres rares]], [[Actions des créatures]], [[Génération de donjon]]
- **Voir aussi** : [[Apprivoisement et recrutement]], [[Catalogue des groupes d'élevage]], [[Cycle jour-nuit et sommeil]], [[Ouvert — Créatures fantastiques]]
