---
aliases: ["Décision — Surcharges Wu Xing des matériaux", "Ouvert — Surcharges wuxing des matériaux", "Surcharges wuxing", "Vecteurs des matériaux"]
tags: [contenu, wuxing, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

> [!success] Décidé le 2026-08-26
> Table produite sur délégation — le passage complet des 154 matériaux. Tout matériau **absent** de cette table suit la règle de sa catégorie. Champ `wuxing` de [[Schéma matériau]].

Les vecteurs Wu Xing des matériaux dont la catégorie ment — et la règle des gemmes, qui manquait.

## Rappel des règles par catégorie ([[Wu Xing hors combat]])

métal → `{metal:1}` · bois, végétal/fibre → `{bois:1}` · roche, terre, minéral, fossile → `{terre:1}` · liquide → `{eau:1}` · **gemme/cristal → `{terre:1}` par défaut** (règle ajoutée ici : les cristaux sont de la terre) · météorologique → `{eau:1}` (règle ajoutée : glace et neige sont de l'eau) · synthétique → selon composition. Plus les deux lois : *plus la transformation est violente, plus le Feu entre* ; *plus un matériau est composite, plus son vecteur s'aplatit* ([[Palier industriel]]).

## La table des surcharges (champ `wuxing`)

**Combustibles et volcaniques (le Feu entre) :**

| Matériau | wuxing |
|---|---|
| Houille, Lignite, Anthracite, Tourbe compactée | feu 0.7 / terre 0.3 |
| Soufre | feu 0.7 / terre 0.3 |
| Salpêtre | feu 0.5 / terre 0.5 |
| Lave | feu 0.8 / terre 0.2 |
| Huile | feu 0.6 / eau 0.4 |
| Goudron, Bitume | feu 0.5 / terre 0.5 |
| Obsidienne | terre 0.6 / feu 0.4 |
| Basalte, Rhyolite, Brèche volcanique | terre 0.8 / feu 0.2 |
| Tuf volcanique, Pierre ponce | terre 0.7 / feu 0.3 |
| Pyrite | metal 0.5 / feu 0.3 / terre 0.2 |
| Cinabre | feu 0.5 / terre 0.5 |
| Bois calciné | feu 0.5 / bois 0.5 |

**Organiques et fossiles :**

| Matériau | wuxing |
|---|---|
| Ambre | bois 0.6 / terre 0.4 |
| Os (paramétrique), Os fossile | bois 0.4 / terre 0.6 |
| Sève | bois 0.7 / eau 0.3 |
| Guano | bois 0.5 / terre 0.5 |
| Bois pétrifié | terre 0.7 / bois 0.3 |
| Ammonite, Coquillage fossile | terre 0.7 / eau 0.3 |
| Sel gemme | terre 0.6 / eau 0.4 |
| Malachite | metal 0.5 / terre 0.5 |
| Météorite ferreuse | metal 0.8 / feu 0.2 |

**Gemmes (cohérentes avec la table de sertissage de [[Loot — affixes, gemmes et rareté]]) :**

| Gemme | wuxing | | Gemme | wuxing |
|---|---|---|---|---|
| Rubis | feu 0.6 / terre 0.4 | | Saphir | eau 0.6 / terre 0.4 |
| Émeraude | bois 0.6 / terre 0.4 | | Topaze | terre 1.0 |
| Onyx | metal 0.6 / terre 0.4 | | Améthyste | bois 0.5 / terre 0.5 |
| Opale | eau 0.5 / terre 0.5 | | Jade | terre 0.6 / bois 0.4 |
| Grenat | terre 0.6 / feu 0.4 | | Quartz | terre 1.0 *(règle)* |
| Diamant | terre 0.8 / metal 0.2 | | | |

**Synthétiques et transformations (le Feu de la fonte) :**

| Matériau | wuxing |
|---|---|
| Verre | terre 0.5 / feu 0.5 |
| Brique | terre 0.7 / feu 0.3 |
| Glace, Neige | eau 1.0 |
| Aciers alliés, béton… ([[Palier industriel]]) | vecteurs plats déjà chiffrés dans la note |

**Suivent la règle sans surcharge (vérifié)** : tous les bois et fibres (Bois), tous les métaux purs (Métal), toutes les roches non volcaniques, terres et minéraux restants (Terre), eau/eau salée/boue (Eau), cuir/fourrure/laine/soie (Bois — parti pris assumé : la fibre prime sur l'origine animale), papier/chaume (Bois), Lapis-lazuli/Turquoise/Fluorine/Calcite/Mica/Graphite/Amiante/Phosphorite/Ocre/Argile réfractaire (Terre).

> [!success] Codé — trace ajoutée le 2026-09-04
> Chaque matériau porte son vecteur `wuxing` dans sa fiche (`data/materials/`), et une arme assemblée prend le vecteur de sa matière (arme mixte : vecteur complet, choix du segment). Les surcharges décidées ici sont les valeurs des fiches.

## Liens
- **Dépend de** : [[Wu Xing hors combat]], [[Schéma matériau]], [[Matériaux — 13 stats]]
- **Alimente** : [[Craft compositionnel]], [[Stats et qualité de l'assemblage]], [[Domination et multiplicateurs]], [[Catalogue matériaux — Gemmes]]
- **Voir aussi** : [[Palier industriel]], [[Loot — affixes, gemmes et rareté]], [[Décision — Affinités de cuisine]]
