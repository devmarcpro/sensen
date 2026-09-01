---
aliases: ["E.3", "Annexe E.3", "Pipeline de combat", "Résolution du combat", "E.3.3", "E.3.4"]
tags: [combat, technique, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Les six étapes de résolution d'une attaque, avec les jets de dés explicites façon roguelike.

Combat et actions risquées reposent sur des **jets de dés explicites**, façon roguelike (ToME/Elona) — lisibles en mode tactique, générateurs de variance et de récit. Notation XdY dans les données.

```
Une attaque (arme ou compétence-module) :
1. Coût : mana (A.6) déduit — ou surchauffe (A.5).
2. JET DE TOUCHER :
     attaque = 1d20 + N_arme/2 + Dex/4
     défense = 10 + N_esquive/2 - malus_poids_armure
     attaque >= défense → touché.
     1d20 naturel 20 → CRITIQUE (dégâts max +50 %) ; naturel 1 → échec
     critique (raté + le défenseur gagne une riposte gratuite).
     DEGRÉS DE RÉUSSITE : battre la défense de 10+ = coup solide
     (dégâts +25 %) — garde la marge signifiante à haut niveau,
     quand les bonus N/2 dépassent l'amplitude du d20.
3. JET DE DÉGÂTS (le jet de TOUCHER n'existe plus — la géométrie
     décide, 5.1 ; les dés de dégâts, eux, sont conservés) :
     bruts = jet(des_fonctionnalité, cf. B.3.1)
             * (durete_BASE/20) * qualite    (règle A.4.1)
             + For/4 (mêlée) ou Dex/4 (distance)
             + effets des modules actifs (leurs propres dés)
     puis multiplicateur élémentaire Wu Xing (A.4.6) si l'attaque
     porte un élément : domination x1.5 / dominé x0.65 / engendré
     x0.8 — affiché au survol en mode tactique.
4. MITIGATION À JET : l'armure ENCAISSE un jet
     reduction = jet(des_protection_totale)  — chaque pièce contribue
     ses dés selon dureté/qualité/facteur_slot (A.4.2) ;
     degats_finaux = max(0, bruts - reduction)
5. Application santé + événements EventBus : `damage_dealt`,
   `creature_killed` si mort (écoutés par quêtes, XP, réputation).
6. XP : attaquant gagne XP d'arme et de modules utilisés ; défenseur
   gagne XP d'Esquive et d'Encaissement.
UI mode tactique : au survol d'une cible, afficher chance de toucher,
fourchette de dégâts, chance de critique — la lisibilité est le but.
Statuts (brûlure, gel, poison...) : appliqués par tags des modules,
tickés en phase 2 de E.1, données dans data/status_effects/.
Le host tire tous les dés (autorité, E.11) — RNG seedé par tick pour
la reproductibilité en debug.
```

> **Note de cohérence :** l'étape 2 (jet de toucher) et l'étape 4 (mitigation à jet) sont **remplacées** par les décisions ultérieures de la direction tactique — [[Combat tactique sur grille]] supprime le jet de toucher (« une cible à portée est touchée »), et [[Armure par zone et constructions]] remplace la mitigation par dés par une **réduction plate par zone**. Le texte intégral d'origine est conservé ci-dessus ; les étapes 1, 3, 5 et 6 restent en vigueur telles quelles. Voir [[Décisions fondatrices]] (« Armure par zone → supprime la mitigation par dés, cause structurelle de l'écrasement des dégâts »).

**Jet de compétence universel (hors combat) :** voir [[Jet de compétence universel]].

> [!success] Décidé le 2026-08-27 — les niveaux de compétence entrent dans les dégâts d'arme
> Tranché par le designer. L'étape 3 devient :
> `bruts = jet(dés) × (dureté_base/20) × qualité × skill_factor(N_arme) × skill_factor(N_type_dégâts) × Σ_e [proportion_e × (1 + niveau_élément_e / 100)] + For/4 (mêlée) ou Dex/4 (distance)`
> avec `skill_factor(N) = 1 + N × 0,02` ([[Progression par l'usage]]). Trois compétences pèsent donc sur chaque coup — **l'arme** (Épée, Arc…), **le type de dégâts** (tranchant / perforant / contondant) et **l'élément dominant employé, pondéré par sa part dans le vecteur** (une arme mixte gagne moins qu'une pure — terme déjà présent dans [[Domination et multiplicateurs]]). Les niveaux sont à 0 jusqu'à l'étape 4 : le code porte les crochets (`competences` sur chaque être), le facteur vaut 1.

> [!success] Décidé et codé le 2026-08-30 — **« magique » est un type de dégâts à part entière**
> **Instruction du designer** : « on devrait rajouter les dégâts magiques plutôt que null ». Jusqu'ici les actions de créature ne connaissaient que tranchant / perforant / contondant (ou rien), et les sorts appliquaient un cas particulier (armure de contondant × `magie_facteur`). Désormais `magique` est dans l'énumération du schéma des actions de créature (la *Flammèche* du Feu follet le porte), la **matrice d'armure** a une colonne `magique` par construction (0,5 partout en premier jet — le même 0,5 qu'avant, mais réglable par construction : des mailles pourraient mieux tenir la magie que du cuir), et `Regles.armure_piece` la lit comme n'importe quel type (repli : contondant × `magie_facteur` si une construction n'a pas la colonne). Le cas particulier des sorts est retiré ; l'XP par type ignore toujours `magique` (elle passe par l'élément).

> [!success] Décidé et codé le 2026-09-01 — un sort roule comme un coup d'arme (designer)
> « il faudrait faire des jets en prenant en compte la composition du sort, les niveaux des modules, les niveaux des compétences, les types de dégâts utilisés, l'arme équipée ». **Mesuré avant de toucher** : un coup d'arme roulait `jet × (dureté/20 × qualité × compétences) + stat/4` — arme, qualité, compétence d'arme, compétence de type de dégâts, affinités élémentaires et Force ou Dextérité. Un sort roulait `jet × mult`. **Rien d'autre** : ni stat — la Volonté ne servait à rien —, ni compétence, ni ce qu'on tenait en main. Les compétences `magie_feu`, `magie_eau`, `magie_arcane` gagnaient de l'XP à chaque lancer **et n'étaient lues nulle part** ; Le Souffle démarrait avec `magie_feu: 5` qui ne lui donnait pas un dégât.
> **La formule du sort devient le miroir de celle de l'arme** : `jet × (focus × école × affinités) + Volonté/4`. L'**école** est `magie_<élément dominant>` — celle-là même qui gagnait l'XP —, les **affinités** sont les `element_*` pondérées par le vecteur du sort (le calcul existait déjà pour les armes), et le **focus** est ce qu'on tient : un bâton magique ou un grimoire multiplie par sa dureté et sa qualité, comme une arme le fait pour un coup. Mains nues, le facteur vaut 1 — on lance toujours, en moins fort.
> **Ce que je n'y ai pas mis, exprès** : le **niveau des modules**. Il réduit déjà les ticks et le coût ; s'il ajoutait la puissance, un module de haut niveau serait à la fois plus rapide, moins cher et plus fort, et la composition cesserait d'être un choix. Les modules paient la **vitesse**, les compétences et l'équipement paient la **force**.


## Liens
- **Dépend de** : [[Boucle de tick]], [[Mana]], [[Stats d'armes]], [[Fonctionnalité]]
- **Alimente** : [[XP de combat]], [[Statuts]], [[Armure par zone et constructions]], [[Domination et multiplicateurs]]
- **Voir aussi** : [[Jet de compétence universel]], [[Combat tactique sur grille]], [[Zones de coup par dénivelé]], [[EventBus]], [[Réseau]], [[Armures et poids porté]]
