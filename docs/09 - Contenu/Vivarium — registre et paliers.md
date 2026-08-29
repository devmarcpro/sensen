---
aliases: ["H.6 registre", "Vivarium — registre et paliers", "Registre", "Paliers de collection", "Courbe de collection"]
tags: [contenu, élevage, progression, décidé]
domaine: contenu
statut: décidé
etape: 10
---

> [!success] Annexe H — intégré le 2026-08-26
> Le registre, les paliers, et la courbe mesurée. **On ne finit pas** — et c'est voulu.

Ce qu'on collectionne, ce que ça rapporte, et combien de temps ça prend.

## Le registre

**Une espèce à la fois** — à 32 espèces × 320 cases, la page d'un seul tenant est injouable. Vignette de l'espèce, sélecteur de couleur de motif, puis grille croisant les **16 couleurs principales** et les **20 motifs**.

*Le registre rejoint la liste de [[Écrans d'interface]] ; sa contrainte de lisibilité est testée ([[Tests de conformité — élevage]], test 7).*

**Modes de rendu par groupe** ([[Intégration de l'élevage au moteur]]) : `grille`, `records`, `galerie`, `familles`, `séquences`, `studbook` — six modes couvrent les trente-cinq groupes.

## Paliers

**Deux pistes parallèles, parce que la complétion totale n'est pas l'objectif.**

| Variétés | Effet |
|---|---|
| 25 | Élevage **+10 de potentiel de base** ([[Potentiel]]) |
| 75 | captures plus sûres (**+2** au jet) |
| 200 | éclosions **25 % plus rapides** |
| 500 | chatoyants **trois fois plus fréquents** |
| 1 200 | **+10 de potentiel** sur toute la branche Vie |
| 3 000 | les collectionneurs paient **le double** |

| Espèces | Effet |
|---|---|
| 10 | **deux couvées de plus** par vivarium |
| 20 | les commandes rapportent **moitié plus** |
| 32 | bestiaire complet — captures **+4** |

**Troisième piste, pour les connaisseurs :** les **palettes complètes** — une couleur principale d'une espèce avec ses 300 combinaisons de motif et de couleur de motif.

*Les bonus de potentiel passent par le système standard ([[Potentiel]] : plancher de potentiel de base) — aucune mécanique de récompense nouvelle.*

## Courbe mesurée

Joueur qui vise les cases vides, sur toutes les espèces en parallèle :

| Variétés | Couvées | 1 vivarium | 3 | 6 |
|---|---|---|---|---|
| 200 | 133 | 1 h | — | — |
| 500 | 498 | 5 h | 2 h | 1 h |
| 1 200 | 1 392 | 13 h | 4 h | 2 h |
| 3 000 | 3 892 | 36 h | 12 h | 6 h |
| 6 000 | 9 346 | 86 h | 29 h | 14 h |

> **On ne finit pas.** Compléter une seule espèce demande environ **9 000 couvées**. C'est la longue traîne du collectionneur, et **c'est voulu** — les objectifs réels sont les **espèces**, les **paliers** et les **palettes**.

C'est la même philosophie que la progression sans plafond du jeu ([[Progression par l'usage]], [[Loci — les dix types]] : *pas de plafond*) : l'asymptote est le but, pas le mur.

> [!success] Codé le 2026-08-28 — l'écran de registre (B) et deux paliers
> Écran **Registre** (touche B) : une ligne par espèce — mode de registre, variétés obtenues / possibles (produit des anneaux `couleur × motif`, sinon des loci qualitatifs), **records** des loci `nombre` (le plus gros spécimen jamais vu) ; le détail liste, par couleur, les motifs obtenus (`grille`), les records (`records`) ou les allèles vus (`phenotypes`, `patrimoine`). En-tête : total de variétés, espèces découvertes, paliers atteints. **Paliers codés** (`combat_rules.elevage.paliers`) : 75 variétés → **+2 aux captures** ; 10 espèces → **deux couvées de plus** par habitat ; bestiaire complet → **+4**. Les paliers de potentiel, d'éclosion, de chatoyants et de prix attendent (chatoyants et collectionneurs ne sont pas codés). Une seule espèce à la fois dans le détail, comme le veut la note.

> [!success] Codé le 2026-08-29 — les six paliers de variétés et les trois d'espèces
> `Simulation.paliers_elevage()` rend maintenant tous les effets du tableau, en données (`combat_rules.elevage.paliers`) : **25 variétés** → `potentiel` +10 sur la compétence **Élevage** ; **75** → **+2** au jet de capture ; **200** → `eclosion` −25 % sur l'âge de maturité exigé par la reproduction (`conditions_repro`, condition `age`, plancher 1 semaine) ; **500** → chatoyants ×3 (déjà codé, lu au même endroit) ; **1 200** → `potentiel_vie` +10 sur **toute la branche Vie** (`competences.*.famille == "vie"`) ; **3 000** → les collectionneurs paient double (`commande` ×2). Espèces : **10** → une couvée de plus par habitat (8 espèces au catalogue aujourd'hui : ce palier attend deux espèces de plus) ; **20** → `commande_pct` +50 % sur les commandes ; **32 / bestiaire complet** → capture **+4**. Les bonus de potentiel sont un **plancher sur le potentiel de base** (`potentiels_base + n`, jamais un cumul : réappliquer le palier ne monte pas deux fois) posé par `_appliquer_paliers_potentiel()` à chaque nouvelle variété enregistrée (`_paliers_potentiel(e)`, sur le joueur et ses compagnons) : aucune mécanique de récompense nouvelle, comme le demande la note. Décision : les paliers de potentiel ne touchent que le **camp du joueur** — un PNJ d'un autre royaume ne profite pas du registre.

> [!success] Codé le 2026-08-29 — le registre suit les loci de l'espèce, et l'écran rend chaque mode
> Deux défauts corrigés. **La clé de variété** était figée à `couleur|motif` : une espèce dont ce qui se collectionne n'est ni l'un ni l'autre (le **rythme** de la luciole, le **motif d'automate** du coquillage, la **taille** de la truite) voyait toutes ses variétés se confondre. Elle est désormais construite depuis les **loci qualitatifs** de l'espèce (`anneau`, `sequence`, `automate`, `carte`, `acquis`), dans l'ordre du catalogue — `Simulation.cle_variete`. **`varietes_possibles`** compte de même : produit des `n` des anneaux, `valeurs^n` pour une séquence, `n` pour un automate ou un acquis. Mesuré : la luciole passe de 6 variétés possibles à **96** (6 couleurs × 2⁴ rythmes), le coquillage de 10 à **120**, la carpe à **128**. **L'écran de registre** (B) rend enfin les six modes de la note au lieu d'une grille unique : `grille` (couleur × motifs), `records` (le plus gros spécimen par locus `nombre`), `sequences` (les rythmes observés), `galerie` (les cartes de taches vues), `familles` (les règles d'automate rencontrées), `phenotypes` / `patrimoine` (les allèles vus). Décision : les registres anciens (sauvegardes) ne sont pas migrés — ils repartent d'une clé neuve à la première couvée ; c'est un prototype, et la migration coûterait plus que le contenu perdu.

## Liens
- **Dépend de** : [[Vivarium — loci et variétés]], [[Vivarium — capture et élevage]]
- **Alimente** : [[Potentiel]], [[Écrans d'interface]], [[Commerce et boutiques]]
- **Voir aussi** : [[Progression par l'usage]], [[Intégration de l'élevage au moteur]], [[Tests de conformité — élevage]], [[Élevage — intention et familles]]
