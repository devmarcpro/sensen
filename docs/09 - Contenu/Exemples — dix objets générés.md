---
aliases: ["Exemples — dix objets générés", "Dix objets", "Exemples d'objets", "Objets générés"]
tags: [objets, contenu, données, référence]
domaine: contenu
statut: décidé
etape: 3
---

> [!note] Sortie de générateur, pas de contenu écrit à la main
> Dix objets **produits** par les règles du craft compositionnel et du loot, graine `0x3333`. Référence d'implémentation pour [[Schéma objet et recette]], [[Stats et qualité de l'assemblage]] et [[Loot — affixes, gemmes et rareté]]. Les JSON vivent dans `godot/data/exemples_items/`. Pendant pour les êtres : [[Exemples — dix PNJ générés]].

Dix objets tirés au hasard, avec absolument toutes leurs données — de la moyenne pondérée des matériaux jusqu'au prix suggéré.

## Ce que le tirage a produit

| # | Nom affiché | Type | Rareté | Qualité | Palier | Élément | Affixes | Sertissures | Prix suggéré |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Dague en cobalt** | arme | commun | 1.54 | Bon | Métal | 0 | 0 | 25.6 or |
| 2 | **Arc en frêne** | arme | commun | 0.95 | Correct | Bois | 0 | 0 | 7.6 or |
| 3 | **Casque de cuir en cuir de loup** | armure | commun | 1.89 | Excellent | Bois | 0 | 0 | 15.6 or |
| 4 | **Arc exact du guetteur** | arme | rare | 0.89 | Correct | Bois | 1 | 1 | 16.5 or |
| 5 | **Casque de l'orage** | armure | exceptionnel | 1.44 | Bon | Bois | 2 | 2 | 168.8 or |
| 6 | **Pioche en fer** | outil | commun | 0.90 | Correct | Métal | 0 | 0 | 9.4 or |
| 7 | **Bottes de cuir en cuir de loup** | armure | inhabituel | 1.70 | Excellent | Bois | 1 | 1 | 35.1 or |
| 8 | **Arc en bambou** | arme | commun | 1.01 | Correct | Bois | 0 | 0 | 7.1 or |
| 9 | **Dague sobre de braise** | arme | rare | 2.13 | Chef-d'œuvre | Métal | 2 | 1 | 283.7 or |
| 10 | **Jambières de cuir en cuir d'ours** | armure | commun | 1.94 | Excellent | Bois | 0 | 0 | 31.1 or |

Les objets **craftés** n'ont ni affixe ni sertissure : c'est la règle d'or *« l'atelier améliore, le donjon transforme »* ([[Loot — affixes, gemmes et rareté]]), et elle se voit directement dans la colonne prix — un casque exceptionnel vaut plus de dix fois un casque crafté de meilleure qualité.

## Composition — les trois slots et la moyenne pondérée

Poids de slot : arme/outil **tête 0.70 · manche 0.25 · fixations 0.05** · armure **plaque 0.75 · sangles 0.20 · fixations 0.05** ([[Composants]]).

| # | Slot lourd (0.70 / 0.75) | Slot moyen (0.25 / 0.20) | Fixations (0.05) |
|---|---|---|---|
| 1 | Tête d'arme — **Cobalt** | Manche — Hêtre | Bronze |
| 2 | Fût d'arc — **Frêne** | Manche — Frêne | Acier |
| 3 | Plaque — **Cuir de loup** | Sangles — Lin | Fer |
| 4 | Fût d'arc — **Chêne** | Manche — Hêtre | Cuivre |
| 5 | Plaque — **Soie** | Sangles — Cuir de loup | Bronze |
| 6 | Tête d'outil — **Fer** | Manche — Bambou | Fer |
| 7 | Plaque — **Cuir de loup** | Sangles — Cuir de loup | Fer |
| 8 | Fût d'arc — **Bambou** | Manche — Frêne | Acier |
| 9 | Tête d'arme — **Titane** | Manche — If | Fer |
| 10 | Plaque — **Cuir d'ours** | Sangles — Cuir d'ours | Cuivre |

**Les 13 stats composites** ([[Matériaux — 13 stats]]), `Σ stat_matériau × poids_slot` :

| # | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| 1 | 20.1 | 10.45 | 11.1 | 20.5 | 15.5 | 12.25 | 45.35 | 22.05 | 1.4 | 0 | 0 | 16.7 | 30.75 |
| 2 | 11.95 | 4.45 | 5.35 | 12 | 57 | 33.5 | 8.35 | 79.95 | 0 | 0 | 0 | 59.65 | 44 |
| 3 | 8.6 | 3.25 | 5.5 | 8.5 | 43 | 41.6 | 10.95 | 59.15 | 0 | 0 | 2 | 48.75 | 41.25 |
| 4 | 12.2 | 6.2 | 4.05 | 10.5 | 57.5 | 33.25 | 9 | 76 | 0 | 0 | 0 | 25.25 | 44.75 |
| 5 | 6.55 | 2.65 | 15 | 23.6 | 51.5 | 39.25 | 8.85 | 66.2 | 0 | 0 | 15 | 56.6 | 31.75 |
| 6 | 20.5 | 9.75 | 7 | 11.25 | 18.75 | 11.25 | 57.5 | 24.75 | 0 | 0 | 0 | 26.25 | 28.75 |
| 7 | 9.8 | 3.45 | 6.1 | 8.1 | 38 | 43 | 11.35 | 57.15 | 0 | 0 | 0 | 52.75 | 39.25 |
| 8 | 9.15 | 3.75 | 4.65 | 14.1 | 67.5 | 30 | 8.35 | 84.15 | 0 | 0 | 0 | 68.75 | 40.5 |
| 9 | 26.9 | 7.7 | 30.65 | 18.1 | 13.75 | 13.35 | 36.5 | 25.25 | 0 | 0 | 0 | 35.4 | 30 |
| 10 | 12.2 | 4.3 | 10.7 | 9.1 | 36.1 | 49.65 | 11.85 | 55.35 | 0 | 0 | 0 | 46.35 | 41.15 |

## Qualité — le chemin complet

`qualite_produite = clamp_min(0.1, (N/(N+25)) × 2 × random(0.85, 1.15))` par composant, puis
`qualite_objet = (Σ qualite_composant × poids_slot) × jet_assemblage` borné **[0.7, 1.3]** ([[Stats et qualité de l'assemblage]]).

| # | Niv. artisan | Qualités des composants | Jet d'assemblage | Qualité finale | Palier |
|---|---|---|---|---|---|
| 1 | 64 | tete 1.29 · manche 1.42 · fixations 1.54 | **×1.151** | **1.539** | Bon |
| 2 | 50 | tete 1.16 · manche 1.18 · fixations 1.41 | **×0.809** | **0.951** | Correct |
| 3 | 63 | plaque 1.44 · sangles 1.53 · fixations 1.52 | **×1.293** | **1.890** | Excellent |
| 4 | 19 | tete 0.99 · manche 0.82 · fixations 0.83 | **×0.951** | **0.891** | Correct |
| 5 | 67 | plaque 1.31 · sangles 1.47 · fixations 1.28 | **×1.079** | **1.443** | Bon |
| 6 | 49 | tete 1.24 · manche 1.17 · fixations 1.20 | **×0.732** | **0.895** | Correct |
| 7 | 91 | plaque 1.51 · sangles 1.72 · fixations 1.75 | **×1.088** | **1.704** | Excellent |
| 8 | 51 | tete 1.22 · manche 1.54 · fixations 1.45 | **×0.771** | **1.012** | Correct |
| 9 | 95 | tete 1.77 · manche 1.45 · fixations 1.70 | **×1.260** | **2.128** | Chef-d'œuvre |
| 10 | 81 | plaque 1.53 · sangles 1.42 · fixations 1.30 | **×1.297** | **1.940** | Excellent |

Le n°4 est l'illustration du garde-fou : composants à 0.72, **jet d'assemblage à 1.24** — l'assembleur a sublimé sans jamais pouvoir annuler le travail des composants.

## Armes et outils

`degats = jet(dés) × (dureté_BASE / 20) × qualité` · `vitesse = vitesse_base × (poids_ref / poids_réel)^0.75` bornée **[0.4, 1.8] × base** ([[Stats d'armes]]).

| # | Fonctionnalité | Dés | Crit | Dégâts moy. | Type | Portée | Volume | Poids réf. | Poids réel | Vitesse | Ticks/att. |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Dague | 1d6 | 19-20 | **5.41** | perçant | 1 | 1.6 | 1.92 kg | **1.67 kg** | 3.33 | 3.0 |
| 2 | Arc | 2d6 | 20 | **4.13** | perçant | 25 | 1.4 | 1.68 kg | **0.62 kg** | 2.7 | 3.7 |
| 4 | Arc | 2d6 | 20 | **3.43** | perçant | 25 | 1.4 | 1.68 kg | **0.87 kg** | 2.46 | 4.07 |
| 6 | Pioche | 1d6 | 20 | **3.21** | contondant | 1 | 3.0 | 3.6 kg | **2.92 kg** | 1.76 | 5.68 |
| 8 | Arc | 2d6 | 20 | **3.48** | perçant | 25 | 1.4 | 1.68 kg | **0.53 kg** | 2.7 | 3.7 |
| 9 | Dague | 1d6 | 19-20 | **10.02** | perçant | 1 | 1.6 | 1.92 kg | **1.23 kg** | 4.19 | 2.39 |

**Modulation d'arc par l'élasticité du bois** ([[Application des stats de matériau]]) — `degats *= (0.8 + elasticite / 250)` :

| # | Fût | Élasticité composite | Modulateur |
|---|---|---|---|
| 2 | Frêne | 59.65 | ×1.039 |
| 4 | Chêne | 25.25 | ×0.901 |
| 8 | Bambou | 68.75 | ×1.075 |

**L'outil** (n°6) porte en plus `functionality: "recolte_minage"`, sa compétence de récolte **Minage** et son `seuil_irrecoltabilite` **20.5** — la dureté composite décide de ce qu'il peut mordre ([[Récolte]] : outil trop faible = rebond).

## Armures

`armure_zone = dureté_composite / 4 × qualité × (1 + niveau_construction / 100) × matrice[construction][type_dégâts]` ([[Armure par zone et constructions]]).

| # | Pièce | Construction | Zone | ×zone | Niv. constr. | Base | **tranchant** | **perforant** | **contondant** | Poids |
|---|---|---|---|---|---|---|---|---|---|---|
| 3 | Casque | Cuir | `tete` | ×2.5 | 72 | 6.99 | 7.69 | 5.94 | 6.99 | 1.95 kg |
| 5 | Casque | Matelassé | `tete` | ×2.5 | 61 | 3.80 | 3.61 | 3.04 | 4.76 | 1.59 kg |
| 7 | Bottes | Cuir | `pieds` | ×0.8 | 43 | 5.97 | 6.57 | 5.07 | 5.97 | 1.04 kg |
| 10 | Jambières | Cuir | `jambes` | ×0.8 | 76 | 10.41 | 11.46 | 8.85 | 10.41 | 3.01 kg |

La réduction ne s'applique qu'à **50 %** contre les dégâts magiques ; la vraie défense magique reste l'alignement Wu Xing de la pièce.

## Wu Xing composite

Chaque objet porte ses éléments **au prorata des poids de slot** ([[Stats et qualité de l'assemblage]]). L'élément d'une arme est celui de sa tête, que le poids 0.70 fait toujours dominer ; les combos d'engendrement acceptent tout élément porté à **≥ 25 %** ([[Wu Xing — cycles et vecteurs]]).

| # | Vecteur | Dominant | Éligible aux combos (≥ 25 %) |
|---|---|---|---|
| 1 | Métal 75 % · Bois 25 % | **Métal** | Métal · Bois |
| 2 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 3 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 4 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 5 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 6 | Métal 75 % · Bois 25 % | **Métal** | Métal · Bois |
| 7 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 8 | Bois 95 % · Métal 5 % | **Bois** | Bois |
| 9 | Métal 75 % · Bois 25 % | **Métal** | Métal · Bois |
| 10 | Bois 95 % · Métal 5 % | **Bois** | Bois |

## Affixes — des générateurs paramétrés, jamais des effets fixes

**4. Arc exact du guetteur** *(rare)* — provenance : donjon_938D, étage 7, coffre

- `affixe:849488` · famille **wu_xing** · gabarit `+1 segment de chaîne` · paramètres tirés `{}` → **« +1 segment de chaîne »**

**5. Casque de l'orage** *(exceptionnel)* — provenance : donjon_476A, étage 1, autel

- `affixe:AF6097` · famille **rythmique** · gabarit `tous les [4-7] coups : ignore [50-100] % d'armure` · paramètres tirés `{"n": 4, "pct": 100}` → **« tous les 4 coups : ignore 100 % d'armure »**
- `affixe:A414A1` · famille **conditionnel** · gabarit `sous [30-60] % PV : +[1-3] dés` · paramètres tirés `{"seuil_pv": 40, "des": 1}` → **« sous 40 % PV : +1 dés »**

**7. Bottes de cuir en cuir de loup** *(inhabituel)* — provenance : donjon_9BEF, étage 1, monstre rare

- `affixe:BBA61D` · famille **conditionnel** · gabarit `corruption >= [40-70] : +[15-30] %` · paramètres tirés `{"corruption": 40, "pct": 24}` → **« corruption >= 40 : +24 % »**

**9. Dague sobre de braise** *(rare)* — provenance : donjon_A500, étage 3, autel

- `affixe:D03038` · famille **wu_xing** · gabarit `+[20-40] % [élément] au vecteur` · paramètres tirés `{"element": "Feu", "pct": 34}` → **« +34 % Feu au vecteur »**
- `affixe:907B92` · famille **conditionnel** · gabarit `sous [30-60] % PV : +[1-3] dés` · paramètres tirés `{"seuil_pv": 40, "des": 2}` → **« sous 40 % PV : +2 dés »**

Chaque ligne du pool est **un gabarit à fourchettes**, pas un effet écrit : `« une attaque sur [2-4] porte [élément] »` couvre 15 variantes d'une seule entrée de données. C'est ce qui permet aux joueurs de comparer deux drops du *même* affixe.

## Sertissures et gemmes

| # | Slots | Contenu |
|---|---|---|
| 4 | 1 | **Onyx** (Métal) — taille *Bon* ×1.35 → +[1-3] dégâts Métal, tiré à **2** |
| 5 | 2 | *vide*<br>**Topaze** (Terre) — taille *Bon* ×1.40 → +[1-3] dégâts Terre, tiré à **2** |
| 7 | 1 | **Saphir** (Eau) — taille *Correct* ×1.06 → +[1-3] dégâts Eau, tiré à **2** |
| 9 | 1 | *vide* |

Les gemmes ne portent **que des nombres plats**, jamais une règle. Une arme à slots **vides** est un loot précieux en soi ; désertir détruit la gemme.

## Prix

`prix_suggere = valeur_base_objet × qualite × facteur_rarete × facteur_reputation` ([[Prix suggéré]]), à réputation neutre (×1.0).

| # | Valeur des matériaux (×1.5) | Qualité | `facteur_rarete` | **Prix suggéré** |
|---|---|---|---|---|
| 1 | 16.65 | ×1.539 | ×1.00 | **25.6 or** |
| 2 | 8.02 | ×0.951 | ×1.00 | **7.6 or** |
| 3 | 8.25 | ×1.890 | ×1.00 | **15.6 or** |
| 4 | 6.07 | ×0.891 | ×3.05 | **16.5 or** |
| 5 | 22.50 | ×1.443 | ×5.20 | **168.8 or** |
| 6 | 10.50 | ×0.895 | ×1.00 | **9.4 or** |
| 7 | 9.15 | ×1.704 | ×2.25 | **35.1 or** |
| 8 | 6.98 | ×1.012 | ×1.00 | **7.1 or** |
| 9 | 45.97 | ×2.128 | ×2.90 | **283.7 or** |
| 10 | 16.05 | ×1.940 | ×1.00 | **31.1 or** |

## Les cinq trous que ce tirage a révélés

Comme pour [[Exemples — dix PNJ générés]], générer pour de vrai a trouvé ce que la relecture ne trouvait pas. **Tous comblés :**

| Trou | Symptôme | Corrigé dans |
|---|---|---|
| La matrice construction × type de dégâts n'avait **aucun chiffre** | « fort contre le tranchant » — de combien ? Impossible à coder | [[Armure par zone et constructions]] — matrice complète, bande **0.80–1.30** |
| `facteur_rarete` cité dans la formule de prix, **défini nulle part** | tout loot valait le prix d'un craft | [[Prix suggéré]] — 1.0 / 1.4 / 2.2 / 4.0 / 10.0, +0.35 par affixe, +0.50 par gemme |
| `poids_reference` et `poids_reel` consommés par la formule de vitesse, **jamais définis** | la vitesse d'arme n'était pas calculable | [[Stats d'armes]] — un champ `volume` déclaré, les deux poids en dérivent |
| Aucune **règle de nommage** d'un objet crafté | rien ne disait comment appeler une épée | [[Schéma objet et recette]] — `{Fonctionnalité} en {matériau de tête}`, `{Pièce} de {construction} en {matériau}` |
| Les noms générés **ne s'accordaient pas en genre** | « Arc exacte », « Bottes fervent » | [[Schéma objet et recette]] — champ `genre_grammatical` (`ms`/`fs`/`mp`/`fp`) par fonctionnalité et par pièce |

> [!question] Ce que le générateur a refusé de produire — et il a eu raison
> La rareté **artefact** existe dans la grille, mais [[Loot — affixes, gemmes et rareté]] la définit par *« effets uniques hors pools, ni sertissable ni infusable »*. Un générateur ne peut donc rien en produire : sans pool, il sortirait un objet **vide**. Ce n'est pas un trou de spec, c'est la spec qui dit que **les artefacts sont du contenu écrit à la main** — comme les PNJ uniques. À écrire un par un dans `data/items/artefacts/`, jamais à générer.

## Liens
- **Dépend de** : [[Schéma objet et recette]], [[Craft compositionnel]], [[Stats et qualité de l'assemblage]], [[Loot — affixes, gemmes et rareté]]
- **Alimente** : [[Décision — Pipeline de contenu]], [[Prix suggéré]], [[Armure par zone et constructions]]
- **Voir aussi** : [[Exemples — dix PNJ générés]], [[Matériaux — 13 stats]], [[Qualité d'artisanat]], [[Stats d'armes]], [[Composants]], [[Catalogue matériaux — Métaux]], [[Catalogue matériaux — Bois]], [[Catalogue matériaux — Gemmes]], [[Wu Xing — cycles et vecteurs]], [[Récolte]]
