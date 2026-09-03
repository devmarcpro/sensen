---
aliases: ["Rôles de l'être", "role", "Sauvage apprivoisé résident garde bétail"]
tags: [êtres, société, décidé]
domaine: êtres
statut: décidé
etape: 9
---

> [!success] Annexe H — intégré le 2026-08-26
> Le champ `role` de [[Blocs de l'être]], détaillé. Il **absorbe et généralise** `housing_default` ([[Habitat des PNJ]]) et `recruitable` ([[Schéma créature]]).

Cinq rôles, une seule échelle, valable du mouton au roi.

## L'échelle

`sauvage` → `apprivoisé` → `résident` → `garde` → `bétail`

| Rôle | Ce que ça veut dire |
|---|---|
| **sauvage** | vit dans le monde, hors territoire ; profil IA `bete_sauvage` ou `hostile` ([[IA des créatures]]) |
| **apprivoisé** | lié au joueur, le suit ou l'attend — c'est l'état des compagnons ([[Compagnons]]) |
| **résident** | vit sur le territoire, a un logement ([[Habitat des PNJ]]) et peut prendre un poste ([[Population et exploitation]]) |
| **garde** | résident affecté à la défense ([[Défense et raids]]) |
| **bétail** | exploité — n'a besoin que d'un toit, produit, se reproduit ([[Conditions de reproduction]]) |

**Un être change de rôle selon sa place dans le monde, jamais selon son espèce.** Aucune transition n'est interdite par type.

> **`role` ≠ `fonction`.** Le rôle dit ta **place vis-à-vis du joueur** ; la [[Fonctions|fonction]] dit ton **occupation dans le monde**. Un forgeron peut être `résident` ou `sauvage` sans changer de métier. *(Le mot « garde » existe des deux côtés : un PNJ peut avoir le role `garde` — affecté à la défense — et la fonction `garde` — c'est son métier. Deux champs distincts.)*

## Ce qui décide d'une transition

Deux valeurs du bloc `esprit` et une du bloc `social` ([[Blocs de l'être]]) :

- la **dressabilité** — à quel point l'être accepte d'être dirigé (jet de [[Apprivoisement et recrutement]]) ;
- l'**intelligence** — ce qu'il peut comprendre comme ordre ou comme poste ;
- la **relation** ([[Réputation et relations]]) — combien il vous doit.

## Le prix, pas l'interdiction

> Un être qui a un métier, une famille, une culture et un nom qu'on connaît **ne se met pas en enclos. Il part, ou il se retourne.**

Ce n'est pas une interdiction, c'est une **conséquence** — la même grammaire que les lois des royaumes ([[Lois et infractions]]), qui n'interdisent rien mais font payer.

Les prix déjà chiffrés dans le coffre s'appliquent tels quels :
- **rétrogradation en bétail** ([[Habitat des PNJ]]) : relation **−30**, humeur **−20**, durables tant que le statut persiste ;
- **capture d'un PNJ important** ([[Population et exploitation]]) : réputation du royaume concerné effondrée, hostilité, primes — *capturer un roi et le mettre en enclos est possible, et coûte exactement ce que ça devrait coûter*.

**Le nouveau : un être à `esprit` développé peut refuser activement.** Sous un seuil de relation, une transition vers `bétail` déclenche la fuite (l'être quitte le territoire, [[Entretien et taxes]] a déjà le précédent : *1 PNJ peut quitter le territoire par semaine*) ou l'hostilité. C'est le pendant de la dressabilité, pas une règle d'espèce.

> [!success] Constaté le 2026-09-03 — `housing_default` n'est pas un champ : voir [[Blocs de l'être]]
> Le logement est un lit dans le territoire, attribué au résident ; la fiche ne porte que `role` et `fonction`.

## Liens
- **Dépend de** : [[Blocs de l'être]], [[Apprivoisement et recrutement]], [[Réputation et relations]]
- **Alimente** : [[Habitat des PNJ]], [[Population et exploitation]], [[Compagnons]], [[Conditions de reproduction]]
- **Voir aussi** : [[Schéma créature]], [[IA des créatures]], [[Lois et infractions]], [[Défense et raids]]
