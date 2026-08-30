---
aliases: ["H.5", "Annexe H.5", "Catalogue des groupes d'élevage", "Groupes d'élevage", "35 groupes"]
tags: [contenu, élevage, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Trente-cinq groupes, **zéro système** : chacun est une fiche de données ([[Décision — Pipeline de contenu]], catalogue `species/`). Six sont recommandés au lancement, un par famille ([[Élevage — intention et familles]]).

Le catalogue complet, par famille de verbe.

## Grille à remplir

| Animal | Capture | Habitat | Moteur | Locus en plus | Condition clé | Registre |
|---|---|---|---|---|---|---|
| Insectes | filet | vivarium | anneau | — | place libre | grille |
| Poissons | ligne | bassin | anneau | taille | eau 18-26°, taille min | records |
| Grenouilles | filet | bassin | anneau + acquis | forme (acquis au têtard) | densité du bassin | grille |
| Lézards | appât | terrarium | anneau | mue (âge) | chaleur 24-34° | grille |
| Escargots | ramassage | terrarium | anneau | spirale (récessif) | humidité, **pas de sexe** | grille |
| Volailles | achat | enclos | anneau | ponte (en tension avec le plumage) | grain en réserve | double grille |
| Carpes koï | ligne | bassin | déformation | taches (carte) | bassin ≥ 4 cases | galerie |

## Trait caché

| Animal | Capture | Habitat | Moteur | Locus | Condition clé | Registre |
|---|---|---|---|---|---|---|
| Serpents | appât | terrarium | anneau + récessif | écailles | après une mue, sexes opposés | phénotypes + porteurs |
| Chats | apprivoisement | foyer | lié au sexe | pelage | robes impossibles sur mâle | grille + généalogie |
| Limaces | ramassage | terrarium | double croisé | — | hermaphrodite, **deux portées** | grille |

## Coût par croisement

| Animal | Capture | Habitat | Locus | Condition clé | Coût |
|---|---|---|---|---|---|
| Vers à soie | achat | clayette | finesse du fil | 4 mûriers | filer **tue** la chrysalide |
| Araignées | filet | terrarium | venin | — | 40 % de perte du mâle |
| Huîtres | ramassage | parc | orient | eau salée, courant | ouvrir tue la bête |
| Chauves-souris | appât nocturne | grotte | écholocation | **un petit par an** | temps |
| Crabes | casier | bassin | pince | fenêtre de 2 jours après mue | synchronisation |

## Population autonome

| Animal | Capture | Habitat | On collectionne | Condition clé | Produit en veille |
|---|---|---|---|---|---|
| Ruches | essaimage | rucher | les **miels** | fleurs à portée, saison | miel, cire |
| Fourmilières | reine capturée | nid | les **compositions de castes** | alimentation des larves | matériaux |
| Loups | apprivoisement | tanière | les **meutes** (rang hérité) | hiérarchie stable | viandes, peaux |
| Pigeons | appât | colombier | orientation | deux claims reliés | transport entre cellules |
| Moutons | achat | enclos | finesse de toison | pâture, tonte saisonnière | écheveaux millésimés |
| Coraux | bouturage | bassin | les **architectures** | lumière, courant, 3 cases | volume |

*La production en veille passe par [[Abstraction hors-site]] — résolution par formules, jamais de simulation.*

## L'individu qui évolue

| Animal | Capture | Habitat | Locus | Condition clé | Registre |
|---|---|---|---|---|---|
| Tortues | ramassage | enclos | dossière (âge) | maturité à 4 ans in-game | patrimoine |
| Cervidés | apprivoisement | parc | ramure (âge) | rut d'automne | **bois tombés** |
| Rapaces | prise au nid | volière | école (acquis) | heures de vol, faim tenue | écoles de dressage |
| Montures | apprivoisement | écurie | endurance, vitesse, tempérament | maturité, épreuve | **studbook** |
| Scarabées de combat | filet | arène | force, allonge | victoires enregistrées | palmarès |

## Le monde décide

| Animal | Capture | Habitat | Locus | Condition clé | Registre |
|---|---|---|---|---|---|
| Phalènes | piège lumineux | vivarium | mélanisme (acquis du lieu) | **la corruption locale sélectionne** | grille + carte |
| Hirondelles | nichoir | nichoir | — | migrent une saison sur deux, **rapportent du génome d'ailleurs** | grille |
| Anguilles | nasse | bassin | — | frayent **seulement relâchées** en mer | grille |
| Champignons | ramassage | cave | — | **le substrat décide** de la couleur | familles de substrat |
| Coquillages | ramassage | — | automate cellulaire | plage, marée · **aucune reproduction** | familles de règle |
| Lucioles | filet nocturne | vivarium | rythme (séquence) | obscurité, colonie ≥ 6 | séquences |

*Les phalènes lisent la corruption effective de [[Dérive de la corruption]] : une région que le joueur pacifie change la couleur de ses papillons. C'est le mélanisme industriel, mécanisé — et la démonstration la plus nette que le monde décide.*

## Gestion et débordement

| Animal | Habitat | Particularité |
|---|---|---|
| Lapins | clapier | la population **double** chaque semaine — trancher ou saturer |
| Sangliers | enclos | les évadés forment des hardes qui ravagent tes champs |
| Oiseaux chanteurs | volière | ne s'accouplent que si les **chants sont compatibles** ([[Ouvert — Oiseaux chanteurs]]) |

> [!success] Codé le 2026-08-28 — les six familles, une espèce chacune, en données
> `data/species/` : **carpe** (grille à remplir, filet sur l'eau, vivarium), **serpent** (trait caché : locus `ecailles` récessif, appât — une viande crue du sac — sur toute tuile, terrarium, couvée après 1 semaine d'âge), **ver à soie** (coût par croisement : `couts` [4 choux du stock du territoire], ramassage sur un arbre, clayette), **ruche** (population autonome : locus `colonie` qui croît chaque semaine jusqu'à 10, `production` = miel × population/4 au printemps-été-fin d'été, essaimage = ramassage sur une plante), **tortue** (individu qui évolue : locus `dossiere` de type `age`, +1 par semaine, couvée à 4 semaines d'âge, enclos), **phalène** (le monde décide : locus `melanisme` **acquis** de la corruption effective de la cellule à la naissance ou à la capture, piège lumineux la nuit sur une plante, vivarium). Registre : les loci `age`/`colonie`/`acquis` s'expriment au passage hebdomadaire ; `lie_au_sexe`, `carte`, `automate` attendent. Le filage de la soie (tue la chrysalide) n'est pas codé.

> [!success] Mis à jour le 2026-08-31 — le filage de la soie est codé (le « n'est pas codé » ci-dessus est périmé)
> `recipes/transformation/filer_soie.json` : à l'**atelier de tissage** (compétence Tissage), **1 spécimen de ver à soie** du sac → **1 soie brute**, la qualité portée par le locus `finesse` (`output.par_locus`) ; consommer le spécimen tue bien la chrysalide. L'assembleur lit les entrées `espece` depuis la fiche du spécimen. Balayage du coffre : la note n'avait pas suivi.

> [!success] Codé le 2026-08-28 — chat, coquillage, filage
> Deux espèces de plus pour les trois derniers loci : le **chat** (pelage lié au sexe, appât, enclos) et le **coquillage** (spirale récessive, motif automate, ramassage sur l'eau, vivarium). **Filer la soie** : recette `filer_soie` à l'atelier de tissage — entrée « un spécimen de ver à soie » (entrée de recette par `espece`), sortie **soie brute**, quantité = finesse du ver arrondie ; le ver est consommé (« filer tue la chrysalide »).

> [!success] Codé le 2026-08-29 — luciole et carpe de bassin : dix espèces, le palier des dix s'ouvre
> Deux groupes de plus, **zéro code nouveau** (les deux derniers types de loci codés trouvent enfin un porteur) : la **luciole** (groupe *Lucioles*, « le monde décide ») — filet **de nuit** sur une plante, vivarium, locus `rythme` de type **`sequence`** (4 temps, registre `sequences`), condition `colonie` ≥ 6 spécimens dans l'habitat pour qu'elles s'accordent et se reproduisent ; et la **truite d'étang** (groupe *Poissons* ; renommée le 2026-08-29 — « poisson de bassin » se confondait avec la carpe de bassin) — capture à la **ligne** sur l'eau, habitat **bassin** (nouveau meuble : 6 places, à l'établi, 8 planches et 4 pierres), locus `taille` de type **`nombre`** (registre `records` : le plus gros spécimen jamais vu), condition de **température 18-26 °C**. Décisions : le bassin est un meuble comme les autres (pas de tuile d'eau à creuser — ça viendrait avec les véhicules et les bateaux) ; la nuit est une **condition de capture**, déjà lue par `_capturer` (`capture.nuit`), pas une nouvelle mécanique. Avec dix espèces, le palier « 10 espèces → deux couvées par habitat » devient atteignable.

## Liens
- **Dépend de** : [[Élevage — intention et familles]], [[Loci — les dix types]], [[Conditions de reproduction]]
- **Alimente** : [[Vivarium — loci et variétés]], [[Intégration de l'élevage au moteur]]
- **Voir aussi** : [[Décision — Saisons activées à l'étape 10]], [[Abstraction hors-site]], [[Dérive de la corruption]], [[Créatures]], [[Ouvert — Oiseaux chanteurs]], [[Ouvert — Hybrides]]
