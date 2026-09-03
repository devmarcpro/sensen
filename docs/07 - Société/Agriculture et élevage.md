---
aliases: ["7.4", "7.4 Agriculture et élevage", "Agriculture", "Élevage", "Abstraction hors-site principe"]
tags: [société, décidé]
domaine: société
statut: décidé
etape: 10
---

Cultiver partout avec un rendement variable, un système de faim qui oblige à manger, et l'élevage qui réutilise le système de créatures.

- **Cultures :** cultivables **partout**, avec un **rendement variable selon le biome** (le biome influence l'efficacité, pas la possibilité de cultiver).
- **Faim/nutrition :** un système de faim **oblige le joueur à manger régulièrement** — mécanique de survie active, pas un simple bonus optionnel. Voir [[Faim]].
- **Élevage :** les animaux de ferme utilisent le **même système modulaire de créatures** que les monstres/PNJ ([[Schéma unifié créature-PNJ]]) — pas de système séparé.

> [!success] Spécifié en profondeur par l'Annexe H
> L'élevage est désormais **un jeu dans le jeu** — attraper, croiser, compléter — avec hérédité, génétique et collection : [[Élevage — intention et familles]]. Mécanismes : [[Règle d'anneau]], [[Loci — les dix types]], [[Conditions de reproduction]]. Contenu : [[Catalogue des groupes d'élevage]] (35 groupes), [[Vivarium — loci et variétés]] (référence implémentée). **Les saisons sont activées avec lui** ([[Décision — Saisons activées à l'étape 10]]).

**Principe transversal : abstraction hors-site**

Toute gestion de ville/village/base (cultures, élevage, boutique passive — [[Commerce et boutiques]], etc.) doit être **abstraite** quand le joueur n'est pas physiquement présent sur place, plutôt que simulée en temps réel dans le détail. Ce système d'abstraction est noté comme un **chantier à développer plus tard en profondeur**, mais il concerne déjà plusieurs mécaniques déjà posées : agriculture/élevage, boutiques passives, régénération des cases sauvages ([[Claims et persistance]]). Voir [[Abstraction hors-site]] et [[Risques majeurs]].

**Décisions (résolu) :**
- **Faim : [[Faim]]** (jauge 0-100, −1/90 s, paliers de malus, plancher 1 PV). **PNJ : [[Faim des PNJ]]** (auto-nourris au garde-manger, proposition validée par défaut).
- **Abstraction hors-site : [[Abstraction hors-site]]** — résolution par **formules** (jamais de simulation accélérée), rapport au retour.

**Formule de rendement ([[Application des stats de matériau]]) :** `rendement_final = rendement_biome (`farming_yield`, [[Biomes — schéma]]) × (0.5 + fertilite_sol / 100)`.

**Effets météo ([[Météo]]) :** pluie → +15 % vitesse de pousse ; canicule → les cultures flétrissent sans arrosage manuel.

**Rôle de case ([[Rôles de cases]]) :** « Champs » — constructions légères uniquement, parcelles agricoles actives, assignation de PNJ fermiers.

**Engrais ([[Catalogue matériaux — Minéraux]]) :** Guano (fertilité 95, engrais puissant), Phosphorite (80), Tourbe compactée (55).

**Cultures de départ :** voir [[Plantes]] (8 cultures cultivables en champs).

**Timers ([[Simulation du monde — performance]]) :** les cultures ne tournent PAS par tick — chaque instance stocke son échéance dans une timer wheel globale. 10 000 cultures plantées = coût nul entre deux échéances.

> [!success] Codé le 2026-08-28 — étape 10.2, les parcelles
> Les 8 cultures sont en données (`data/plants/`, et un consommable du même id) ; **la graine est la récolte** : planter consomme 1 unité (le coffre de départ en contient, les marchands en vendent). Planter (inventaire, touche H sur une culture — L lit) sur une tuile libre adjacente d'une cellule **Champs** — décision : le rôle Champs est requis (« parcelles agricoles actives »). Chaque parcelle stocke son **échéance** (`duree_jours × ticks_par_jour`, −15 % si pluie au semis) : rien ne tourne par tick, une seule vérification horaire. À l'échéance la parcelle mûrit ; la récolte (clic) donne `recolte_base × farming_yield(biome) × (0,5 + fertilité/100)` ; **canicule au moment de la récolte → ×0,5** (le flétrissement sans arrosage est simplifié ainsi ; l'arrosage manuel n'est pas codé). Fertilité = `stats.fertilite` du sol de la tuile (terre 45, terre fertile 75) ; **engrais** : clic sur une parcelle avec Guano (95), Phosphorite (80) ou Tourbe compactée (55) brut dans le sac. L'élevage (Annexe H) et les saisons restent à faire.

> [!note] Réglages — `combat_rules.agriculture_recolte` : `des`, `moyenne` et `competence` — le rendement d'une parcelle mûre est base × rendement × fertilité × jet/moyenne × skill_factor(Agriculture). Pointeur ajouté le 2026-09-04.

## Liens
- **Dépend de** : [[Schéma unifié créature-PNJ]], [[Biomes — schéma]], [[Rôles de cases]], [[Application des stats de matériau]]
- **Alimente** : [[Faim]], [[Cuisine et alchimie]], [[Abstraction hors-site]], [[Population et exploitation]], [[Plantes]]
- **Voir aussi** : [[Météo]], [[Faim des PNJ]], [[Catalogue matériaux — Minéraux]], [[Simulation du monde — performance]], [[Risques majeurs]], [[Potentiel]]
