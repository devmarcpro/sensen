---
aliases: ["6.1", "6.1 Races et classes", "Création de personnage", "Création"]
tags: [progression, décidé]
domaine: progression
statut: décidé
etape: 4
---

Une création détaillée, pas un menu déroulant : stats à répartir, race, classe, apparence et date de naissance.

- **Races :** un mélange de races fantasy classiques (humain, elfe, nain...) et de races originales, propres au monde du jeu. Voir [[Races]].
- **Classe :** un **kit de départ et un talent** qui définit une façon de jouer ([[Talents de classe]]). Aucune restriction durable ensuite — pas de plafond ni de pénalité, le talent est *un plancher, pas une cage*. Voir [[Classes]].
- **Fonction :** ce que le personnage fait de ses journées ([[Fonctions]]) — celle du joueur est **aventurier** par défaut.
- **Création de personnage détaillée :** répartition de points, choix multiples — pas un simple menu déroulant simplifié.

**Décisions (résolu, Annexe C) :**
- **Races : [[Races]]** est la liste de lancement (3 races, chacune avec son talent — [[Talents de race]]). **Classes : [[Classes]]** (8 visibles, kit + talent — [[Talents de classe]]). **Création : [[Stats de personnage]]** — 6 stats, 30 points à répartir (base 5, max 15 à la création), + race, classe, apparence (choix des parties du corps, [[Schéma unifié créature-PNJ]]).
- **Date de naissance choisie librement** (sélecteur avec aperçu des effets) : voir [[Astrologie — cycle sexagésimal]].

**Les trois axes ([[Les trois axes — race, classe, fonction]]) :** race (qui tu es) · classe (ce que tu sais) · fonction (ce que tu fais). **Tout PNJ les porte aussi** — un *elfe · éliotrope · aventurier*, un *humain · forgeron · artisan*.

**Deux modes de création :** on **construit** un personnage de race visible (30 points à répartir) ; on **devient** une race cachée en jeu, avec ses stats propres ([[Talents de race]]) — jamais dans le menu.

**Séquence de démarrage complète :** voir [[Début de partie]].

> [!success] Codé le 2026-08-27 — écran de création du prototype
> Au lancement : race (R), classe (C), 30 points à répartir (+15 pour Le Vent, max +10 par stat, base 5), année de naissance (← →, signe affiché), Entrée. `Etres.creer_personnage()` produit une **fiche identique à celles de `data/creatures/`** (le joueur reste un être comme les autres) : stats = base + points + bonus de race + bonus de classe, kit de la classe (`data/classes/`), compétences de départ, potentiels de base pour toutes les compétences et les six stats, tags du talent de race (Œil de la pierre → `detection_filons`). L'apparence (parties du corps) et les **talents actifs** attendent leurs systèmes. `data/races/` et `data/classes/` sont les catalogues promis par [[Races]] et [[Classes]].

> [!success] Complété le 2026-08-28
> Les talents existent : l'écran de création affiche le **talent de classe** (nom et description) et le **talent de race** ; Le Vent affiche « aucun (à apprendre d'un maître) ». L'apparence attend toujours les sprites (décision du designer).

> [!success] Décidé et codé le 2026-09-01 — les **serments**, prononcés à la création (designer)
> Le designer voulait le principe du *nen* de Hunter × Hunter : **la contrainte fait la force**. Les 22 modules `condition` en sont déjà une forme — frapper de dos donne +3 dés —, mais ils ne coûtent rien et se choisissent au lancer : c'est du bonus conditionnel, pas un pari. Le serment est l'autre moitié, et il se prononce **à la création**, là où il est irrévocable : un quatrième volet « Serments » à côté de Personnage, Apparence et Pose.
> **Ce qu'est un serment** : une contrainte tenue **toute la partie**, vérifiée en continu, qui donne un bonus permanent tant qu'elle tient. La rompre **ne se pardonne pas** — le bonus est perdu pour la partie, définitivement, et le journal le dit. On peut en prononcer plusieurs : leurs bonus se cumulent, leurs risques aussi.
> **Les six premiers** : *Corps nu* (aucune armure) · *Mains nues* (aucune arme) · *Pauvreté* (jamais plus de cent pièces d'or) · *Sobriété* (aucune potion) · *Végétarien* (aucune viande) · *Silence* (aucun grimoire ni manuel lu). Chacun donne un bonus proportionné à ce qu'il retire — le plus dur, *Corps nu*, donne le plus. Tout vit dans `data/serments/` : un fichier par serment, son prédicat, son bonus, sa rupture.


## Liens
- **Dépend de** : [[Progression par l'usage]]
- **Alimente** : [[Races]], [[Classes]], [[Astrologie — cycle sexagésimal]], [[Stats de personnage]], [[Début de partie]]
- **Voir aussi** : [[Potentiel]], [[Schéma unifié créature-PNJ]], [[Squelette modulaire et points d'attache]]
