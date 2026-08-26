---
aliases: ["Exemples — dix PNJ générés", "Dix PNJ", "Exemples de fiches PNJ", "PNJ générés"]
tags: [contenu, êtres, données, référence]
domaine: contenu
statut: décidé
etape: 9
---

> [!note] Sortie de générateur, pas de contenu écrit à la main
> Ces dix fiches sont **produites** par les règles du design, avec la graine `0x4E62`. Elles servent de **référence d'implémentation** : une fiche conforme à [[Blocs de l'être]] et [[Schéma créature]] ressemble à ça, tous blocs remplis. Les JSON vivent dans `godot/data/exemples_pnj/`.

Dix PNJ tirés au hasard, avec absolument toutes leurs données — la preuve par l'exemple que le schéma unique tient.

## Ce que le tirage a produit

| # | Nom | Race | Classe | Fonction | `role` | Sexe | Âge | Culture |
|---|---|---|---|---|---|---|---|---|
| 1 | **Zhao Meiming** | humain | La Trace | herboriste | `resident` | M | 40 | Sino |
| 2 | **Eirnar Stensson** | nain | Le Sabre | garde | `garde` | M | 92 | Nordique/germanique |
| 3 | **Freyvald Stensson** | humain | Le Vent | commercant | `resident` | M | 40 | Nordique/germanique |
| 4 | **Yarka Volkic** | humain | La Balance | dirigeant | `resident` | F | 35 | Slave |
| 5 | **Eilys DunOwen** | elfe | La Trace | fermier | `resident` | M | 136 | Celte |
| 6 | **Taldre ApCormac** | elfe | Le Vent | fermier | `resident` | F | 167 | Celte |
| 7 | **Deirys Glenmore** | humain | Le Vent | couturier | `resident` | M | 32 | Celte |
| 8 | **Bjordis Ulfberg** | nain | La Trace | eleveur | `resident` | F | 102 | Nordique/germanique |
| 9 | **Eirvald Stenberg** | humain | Le Souffle | aventurier | `sauvage` | M | 53 | Nordique/germanique |
| 10 | **Ludomir Belov** | nain | L'Ombre 🔒 | commercant | `resident` | M | 65 | Slave |

🔒 = **classe cachée** (tirage à ≈ 2 %, hors pool de fonction — [[Fonctions]]). Le tirage en a sorti une sur dix : c'est de la chance, l'espérance est de 0,2.

## Corps — stats, dérivées, astrologie

Stats : `base 9 ± 2`, `+` modificateurs de race ([[Races]]), `+2` dans la stat de la classe, `×` facteur de croissance si l'âge est sous la maturité. Dérivées calculées par les formules de [[Stats de personnage]].

| # | For | Dex | End | Vol | Per | Cha | PV max | Mana max | Port. kg | Escorte | Apnée | Signe |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 7 | 10 | 6 | 5 | 8 | 11 | 44 | 35 | 65 | 3 | 42 s | Métal-Lapin |
| 2 | 13 | 13 | 10 | 12 | 8 | 11 | 60 | 56 | 95 | 3 | 50 s | Bois-Cheval |
| 3 | 9 | 10 | 10 | 8 | 12 | 10 | 60 | 44 | 75 | 3 | 50 s | Eau-Serpent |
| 4 | 6 | 6 | 8 | 14 | 6 | 14 | 52 | 62 | 60 | 3 | 46 s | Terre-Cochon |
| 5 | 8 | 15 | 9 | 11 | 10 | 10 | 56 | 53 | 70 | 3 | 48 s | Terre-Chèvre |
| 6 | 11 | 9 | 11 | 8 | 9 | 11 | 64 | 44 | 85 | 3 | 52 s | Terre-Bœuf |
| 7 | 9 | 5 | 9 | 6 | 12 | 10 | 56 | 38 | 75 | 3 | 48 s | Bois-Serpent |
| 8 | 12 | 12 | 10 | 6 | 7 | 10 | 60 | 38 | 90 | 3 | 50 s | Métal-Tigre |
| 9 | 14 | 8 | 10 | 8 | 8 | 5 | 60 | 44 | 100 | 2 | 50 s | Métal-Dragon |
| 10 | 9 | 10 | 10 | 10 | 6 | 6 | 60 | 50 | 75 | 2 | 50 s | Bois-Cochon |

## Génome — les loci humanoïdes

**Neuf loci déclarés par les races humanoïdes**, un par mécanique de [[Loci — les dix types]]. C'est ce qui rend l'apparence *héritable* ([[Règle d'anneau]]) au lieu d'être tirée dans un `parts_pool`.

| Locus | Type | Domaine | Hérédité |
|---|---|---|---|
| `teint` | `nombre` | indice de mélanine 0-100 | moyenne des parents + dérive gaussienne (var 0.08) |
| `cheveux_couleur` | `anneau` | noir · brun · châtain · blond · roux · auburn (n=6) | 34/34/16/16 — un enfant de blond et de noir peut être châtain ou auburn |
| `yeux_couleur` | `anneau` | noir · brun · ambre · vert · gris · bleu (n=6) | idem |
| `taille` | `nombre` | 110-230 cm, base par race, ±6 cm selon le sexe | moyenne + dérive (var 0.04) |
| `carrure` | `nombre` | indice 0-100 | moyenne + dérive (var 0.06) |
| `taches_rousseur` | `recessif` | allèles `R`/`r`, visible seulement en `rr` | un allèle pris à chaque parent |
| `pilosite_faciale` | `lie_au_sexe` | 0-100, ne s'exprime que si `sexe == M` | porté indépendamment du sexe, exprimé selon lui |
| `grisonnement` | `age` | 0.0 → 1.0, seuil par race (~38 / 110 / 210 ans) | non tiré : s'exprime avec le temps, passage hebdomadaire |
| `traits_visage` | `carte` | identifiant de carte déformable | déformation de la carte d'un parent (mut 0.12) |

**Variantes par race :** l'**elfe** perd `pilosite_faciale` et gagne `oreille_longueur` (`nombre`, mm au-dessus du crâne). Le **nain** gagne `barbe_densite` (`nombre`) et `tresses_de_clan` (`acquis` — **non hérité**, fixé par la culture après la naissance : marteau, enclume, veine, aucune).

**Ce que ça donne sur les dix :**

| # | Teint | Cheveux | Yeux | Taille | Carrure | Rousseur | Pilosité | Grison. | Carte visage | Spécifique |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 31 (clair) | blond | noir | 163 cm | 31 | porteur (`Rr`) | 53 | 0.03 (seuil 39) | `carte_E073` | — |
| 2 | 30 (clair) | roux | vert | 145 cm | 46 | porteur (`Rr`) | 23 | 0.00 (seuil 116) | `carte_B53A` | barbe 52 · tresses *enclume* |
| 3 | 51 (mat) | auburn | noir | 185 cm | 54 | non (`RR`) | 74 | 0.00 (seuil 42) | `carte_73B3` | — |
| 4 | 80 (sombre) | châtain | noir | 165 cm | 39 | porteur (`Rr`) | 0 | 0.00 (seuil 39) | `carte_66C1` | — |
| 5 | 41 (mat) | roux | ambre | 191 cm | 51 | porteur (`rR`) | — | 0.00 (seuil 192) | `carte_0442` | oreille 71 mm |
| 6 | 58 (brun) | noir | gris | 181 cm | 57 | porteur (`Rr`) | — | 0.00 (seuil 182) | `carte_6B4F` | oreille 76 mm |
| 7 | 50 (mat) | roux | gris | 201 cm | 61 | porteur (`Rr`) | 57 | 0.00 (seuil 41) | `carte_2588` | — |
| 8 | 45 (mat) | roux | brun | 130 cm | 49 | porteur (`Rr`) | 0 | 0.00 (seuil 122) | `carte_BC8A` | barbe 86 · tresses *veine* |
| 9 | 44 (mat) | roux | vert | 174 cm | 62 | **visible** (`rr`) | 59 | 0.38 (seuil 38) | `carte_3BDD` | — |
| 10 | 54 (mat) | brun | ambre | 133 cm | 66 | porteur (`rR`) | 39 | 0.00 (seuil 120) | `carte_765B` | barbe 87 · tresses *aucune* |

## Esprit, social, agenda

`intelligence` et `dressabilite` décident des transitions de [[Rôles de l'être]]. `relations.joueur` part de 50 ± 8 et bouge par [[Réputation et relations]].

| # | Intelligence | Tempérament | Dressabilité | Lignée | Rang | Rel. joueur | `recruitable` |
|---|---|---|---|---|---|---|---|
| 1 | 73 | calculateur | 22 | `lignee_525E` | — | 40 | `relation` (seuil 60) |
| 2 | 40 | curieux | 12 | `lignee_C96D` | — | 44 | `relation` (seuil 60) |
| 3 | 77 | loyal | 22 | `lignee_1610` | — | 59 | `relation` (seuil 60) |
| 4 | 59 | farouche | 26 | `lignee_FFF2` | souverain | 60 | `jamais` (seuil 90) |
| 5 | 42 | farouche | 17 | `lignee_DAE1` | — | 48 | `relation` (seuil 60) |
| 6 | 48 | curieux | 8 | `lignee_E461` | — | 56 | `relation` (seuil 60) |
| 7 | 53 | loyal | 12 | `lignee_5FD9` | — | 49 | `relation` (seuil 60) |
| 8 | 79 | farouche | 35 | `lignee_0F7C` | — | 62 | `relation` (seuil 60) |
| 9 | 70 | curieux | 15 | `lignee_FBD8` | — | 70 | `relation` (seuil 60) |
| 10 | 68 | irascible | 37 | `lignee_70FA` | — | 27 | `relation` (seuil 60) |

**`foyer`, `poste`, `ordre`, `territoire` sont `null` sur toutes les fiches** : ce sont des champs d'**instanciation dans un monde**, remplis quand le PNJ est posé dans un village ou un claim ([[Population et exploitation]], [[Habitat des PNJ]]). Une fiche générée hors monde les laisse vides — c'est correct, pas un oubli.

## Potentiels de base

Moyenne du potentiel de race et de celui de classe ([[Races]]), **+10** par domaine touché par l'élément et l'animal astrologiques ([[Astrologie — cycle sexagésimal]]). Défaut 80, ou 90 pour l'humain, ou 100 pour Le Vent.

- **1. Zhao Meiming** — Herboristerie **115** · Arbalète **105** · Arc **105** · Discrétion **105** · Dressage **105** · Esquive **95** · Métal **95** · Taille de pierre **95** · Forge **85** · Encaissement **75**
- **2. Eirnar Stensson** — Encaissement **120** · Bouclier **100** · Deux Mains **100** · Forge **100** · Minage **100** · Taille de pierre **100** · Épée **100** · Agriculture **90** · Athlétisme **90** · Dressage **90** · Alchimie **70** · Discrétion **70** · Foudre/Vie **70** · Eau/Glace **60** · Feu **60** · Métal **60** · Terre **60**
- **3. Freyvald Stensson** — Alchimie **115** · Eau/Glace **105** · Navigation **105** · Perception **105**
- **4. Yarka Volkic** — Charisme **105** · Leadership **105** · Lecture **105** · Négociation **105** · Construction **95** · Cuisine **95** · Encaissement **95** · Terre **95** · Minage **85** · Deux Mains **75** · Hache **75** · Masse **75**
- **5. Eilys DunOwen** — Terre **110** · Arbalète **100** · Arc **100** · Contrôle du Mana **100** · Discrétion **100** · Dressage **100** · Eau/Glace **100** · Feu **100** · Foudre/Vie **100** · Herboristerie **100** · Méditation **100** · Métal **100** · Construction **90** · Minage **90** · Taille de pierre **90** · Tissage **90** · Encaissement **60** · Forge **60**
- **6. Taldre ApCormac** — Terre **120** · Contrôle du Mana **110** · Eau/Glace **110** · Feu **110** · Foudre/Vie **110** · Méditation **110** · Métal **110** · Agriculture **100** · Construction **100** · Minage **100** · Encaissement **90** · Forge **80**
- **7. Deirys Glenmore** — Agriculture **105** · Alchimie **105** · Foudre/Vie **105** · Perception **105**
- **8. Bjordis Ulfberg** — Taille de pierre **110** · Arbalète **100** · Arc **100** · Dressage **100** · Forge **100** · Herboristerie **100** · Minage **100** · Athlétisme **90** · Deux Mains **90** · Discrétion **90** · Encaissement **90** · Métal **80** · Eau/Glace **70** · Feu **70** · Foudre/Vie **70** · Terre **70**
- **9. Eirvald Stenberg** — Contrôle du Mana **115** · Métal **115** · Eau/Glace **105** · Feu **105** · Foudre/Vie **105** · Méditation **105** · Terre **105** · Forge **95** · Leadership **95** · Taille de pierre **95** · Deux Mains **75** · Hache **75** · Masse **75**
- **10. Ludomir Belov** — Encaissement **110** · Forge **100** · Minage **100** · Taille de pierre **100** · Agriculture **90** · Cuisine **90** · Foudre/Vie **80** · Discrétion **70** · Eau/Glace **70** · Feu **70** · Métal **70** · Terre **70**

## Talents

| # | Talent de race | Talent de classe | Second talent (Polyvalent) |
|---|---|---|---|
| 1 | Polyvalent | Meute | **Fiole vive** *(Le Creuset)* |
| 2 | Œil de la pierre | Râtelier vivant | — |
| 3 | Polyvalent | *aucun au départ* | — |
| 4 | Polyvalent | Œil du prix | **Souffle rendu** *(La Paume)* |
| 5 | Chair de mana | Meute | — |
| 6 | Chair de mana | *aucun au départ* | — |
| 7 | Polyvalent | *aucun au départ* | — |
| 8 | Œil de la pierre | Meute | — |
| 9 | Polyvalent | Communion des cinq | **Main du métal** *(La Braise)* |
| 10 | Œil de la pierre | Dissimulé · −25 % en frontal 🔒 | — |

## Reproduction

Toutes les fiches humanoïdes portent le même bloc `repro` — moteur `couple`, quatre conditions, portée de 1, un coût :

```js
{
  "moteur": "couple",
  "conditions": [
    {
      "c": "sexe"
    },
    {
      "c": "age",
      "min": 17
    },
    {
      "c": "habitat",
      "v": "logement"
    },
    {
      "c": "place"
    }
  ],
  "portee": {
    "min": 1,
    "max": 1,
    "gestation_jours": 30
  },
  "couts": [
    "portee_unique_annuelle"
  ]
}
```

La condition `age.min` vaut la **maturité de la race** — 17 ans pour l'humain, 55 pour le nain, 77 pour l'elfe ([[Races]]). Le reste est évalué par l'évaluateur unique de [[Conditions de reproduction]], qui renvoie **pourquoi** ça échoue.

## Les cinq trous que ce tirage a révélés

Générer pour de vrai a trouvé cinq manques que la relecture n'avait pas vus. **Tous sont désormais comblés :**

| Trou | Symptôme | Corrigé dans |
|---|---|---|
| Pools de noms non genrés | des « Tariq » femmes, des « Freydis » hommes, des patronymes en `-sdottir` sur des hommes | [[Pools de noms des cultures]] — `prenom_b_m` / `prenom_b_f`, patronymes genrés en nordique et slave |
| `classes_possibles` par fonction jamais écrit | rien ne disait quelle classe un forgeron pouvait avoir | [[Fonctions]] — la table des pools, plus la pondération des fonctions |
| `lifespan` cité partout, chiffré nulle part | impossible de tirer un âge | [[Races]] — 80 / 250 / 350 ans, maturité à 22 % |
| *Polyvalent* × *Sans maître* | un humain Le Vent aurait eu « deux fois rien » | [[Talents de race]] — `talents.classe` est `null` pour Le Vent ; Polyvalent lui accorde **deux apprentissages** |
| Loci humanoïdes non déclarés | le génome d'un humain n'existait qu'en principe | cette note, section *Génome* — neuf loci, un par mécanique |

> **C'est l'argument pour générer tôt.** Une spec se relit sans jamais buter ; un générateur bute à la première contradiction.

**Pendant pour les objets :** [[Exemples — dix objets générés]].

## Liens
- **Dépend de** : [[Blocs de l'être]], [[Schéma créature]], [[Les trois axes — race, classe, fonction]], [[Loci — les dix types]]
- **Alimente** : [[Décision — Pipeline de contenu]], [[Profils de PNJ]], [[Apparence — données et équipement]]
- **Voir aussi** : [[Races]], [[Classes]], [[Fonctions]], [[Talents de race]], [[Talents de classe]], [[Pools de noms des cultures]], [[Conditions de reproduction]], [[Rôles de l'être]], [[Astrologie — cycle sexagésimal]], [[Stats de personnage]]
