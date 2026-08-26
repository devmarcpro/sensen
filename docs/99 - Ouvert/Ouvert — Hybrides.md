---
aliases: ["Ouvert — Hybrides", "H.10 hybrides", "Hybrides"]
tags: [ouvert, élevage, à-trancher]
domaine: société
statut: à-trancher
etape: 10
---

> [!question] Ouvert — Annexe H.10
> Question laissée ouverte par l'Annexe H elle-même. **Non bloquante** : le système fonctionne sans.

**La question :** deux espèces proches donnant rarement **une troisième, introuvable en liberté**.

**Ce que ça apporterait :** la collection décollerait — la seule voie d'accès à ces espèces serait **l'élevage**, ce qui prolonge exactement la logique déjà en place ([[Vivarium — capture et élevage]] : *les prises sauvages sont ternes par construction*, l'éleveur bat le chasseur).

**Ce que ça coûte :** la condition `espèces différentes` est aujourd'hui un refus sec dans `peutSeReproduire` ([[Conditions de reproduction]]). L'ouvrir demande de déclarer des **paires compatibles** en données (une table `hybrides` : espèce A + espèce B → espèce C, avec une probabilité) et de décider **comment le génome se transmet** entre deux jeux de loci qui ne coïncident pas forcément.

**Piste :** n'autoriser les hybrides qu'entre espèces **partageant exactement leur liste de loci** — la fusion devient triviale (chaque locus s'hérite normalement), et la contrainte devient un critère de conception des fiches plutôt qu'un cas particulier de code. Cohérent avec la règle d'or de [[Élevage — intention et familles]].

**Ce qui en dépend :** rien de structurel — c'est une extension pure, à ajouter quand le socle tourne.

## Liens
- **Dépend de** : [[Élevage — intention et familles]], [[Catalogue des groupes d'élevage]]
- **Voir aussi** : [[Loci — les dix types]], [[Règle d'anneau]], [[Vivarium — loci et variétés]], [[Carte — Ouvert]]
