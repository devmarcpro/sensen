---
aliases: ["Prototype de combat — spécification", "Prototype de combat", "Étape 0", "Spécification du prototype"]
tags: [combat, production, spécification, décidé]
domaine: combat
statut: décidé
etape: 0
---

> [!success] Rédigé et décidé le 2026-08-26
> Le « document séparé » exigé par [[Ordre de construction]] pour l'étape 0. Sur délégation du designer : tout est fixé pour que l'implémentation n'ait aucune question à se poser. *Le combat est-il bon ? Rien ne démarre avant un oui.*

La spécification exécutable du prototype de combat isolé — périmètre, contenu exact, ordre d'implémentation, et le critère de « oui ».

## 1. Objectif

Prouver que le cœur du jeu — **action-time à ticks + Wu Xing + jauge de chaîne sur une grille à dénivelé** — produit des décisions intéressantes, lisibles et rejouables. Le prototype est un projet Godot jetable dans `godot/` (scène `prototype_combat.tscn`) mais **ses données et ses systèmes sont écrits pour être rapatriés tels quels à l'étape 1**.

## 2. Périmètre — ce qui est DANS le prototype

**Systèmes (tous déjà spécifiés — liens = la spec) :**
- Boucle de tick et compteurs d'action ([[Boucle de tick]]) — coûts de référence tels quels.
- Déplacement avec modificateurs de dénivelé, chute, ligne de vue ([[Hauteur de terrain ±10]]).
- Zones de coup par dénivelé ([[Zones de coup par dénivelé]]) et armure par zone plate ([[Armure par zone et constructions]] — valeurs fixées à la main, pas de craft).
- Garde et garde-bouclier ([[Garde en posture]], [[Décision — Boucliers]]), attaque lourde et télégraphe ([[Attaque lourde et télégraphe]]), endurance ([[Endurance]]), mana ([[Mana]]).
- Wu Xing complet : vecteurs, domination, jauge de chaîne 5 segments, décroissance 30 ticks, résolveur non offensif ([[Domination et multiplicateurs]], [[Jauge de chaîne Wu Xing]]).
- Assemblage de capacités : les 6 types de modules, slots fixés à 3 compétences × 3 modules pour le prototype ([[Six types de modules et assemblage]]).
- Statuts et anti-stunlock ([[Statuts]], [[Statuts de contrôle et anti-stunlock]]).
- Projectiles, friendly fire des zones, munitions ([[Décision — Projectiles]]).
- Fuite et désengagement, y compris côté IA ([[Décision — Fuite et désengagement]]).
- IA utility avec actions de créatures en données ([[IA des créatures]], [[Décision — Vocabulaire d'attaque des créatures]], catalogue [[Actions des créatures]]).
- Jauge de chaîne des élites/boss et interruption ([[Décision — Chaîne côté ennemis]]).
- Esquive = mobilité de combat ([[Décision — Esquive active]]).
- XP des trois pistes **affichée en fin de combat** (écran récapitulatif [[XP de combat]]) — non persistée.

**Contenu :**
- **6 armes** au râtelier (swap 4 ticks) : Dague (Métal), Épée (Métal), Masse (Terre), Lance (Bois), Arc (Bois, distance), Bâton magique (support des modules) — profils de [[Stats d'armes]], vecteurs mono-élément préconfigurés (le craft n'existe pas encore : l'élément est une donnée de l'arme du prototype). Un **bouclier**.
- **17 modules** : les 5 de Feu, 5 d'Eau/Glace, 4 de Foudre, les **5 de Métal** ([[Modules]], [[Ouvert — Modules du domaine Métal]] → catalogue) — de quoi fermer la rotation des cinq éléments par la magie — plus Frappe lourde et Balayage (manuels).
- **6 adversaires** (bêtes : [[Créatures]] · humains : [[Profils de PNJ]] · actions dans [[Actions des créatures]]) : Loup ×3 (meute — teste le multi-ennemis et l'encerclement), Sanglier (charge télégraphiée), Bandit ×2 (humain armé, garde), Chef de bande (**élite à jauge de chaîne** — teste l'interruption), Aigle (volant), Scorpion (poison).
- **3 arènes fixes en données** (`data/prototype_arenas/*.json`, grilles 32×32 avec hauteurs 0-20 posées à la main) : *Plaine au talus* (dénivelés doux, initiation), *Gorge* (falaises Δ≥3, lignes de vue coupées, chutes), *Ruine à estrades* (combat vertical dense, escalier, glyphes).

**UI — c'est LE livrable de game feel ([[Combat tactique sur grille]] : la lisibilité EST le game feel) :**
timeline des prochaines actions · coûts en ticks sur les tuiles atteignables · prévisualisation des dégâts avec détail du calcul · jauge de chaîne sous le réticule + multiplicateur prévu au survol · icônes d'intention/télégraphes avec zones · journal de combat · jauges des élites. Rendu des entités : **billboards placeholder** (silhouettes teintées) — aucun asset final requis.

## 3. Périmètre — ce qui est HORS du prototype

Potentiel, loot/affixes, craft, sauvegarde, monde/génération, PNJ civils, compagnons, réseau. **Mais les [[Contraintes permanentes]] s'appliquent dès la première ligne** : logique côté « serveur » (même processus), le contrôle envoie des intentions, aucune lecture d'input dans les systèmes, `tr()` sur chaque string affichée, tout le contenu en JSON validé au boot ([[Data-driven design]]).

## 4. Ordre d'implémentation (jalons internes, chacun jouable)

1. GameData + EventBus + TickManager ([[Décisions d'architecture]]) ; arène chargée depuis JSON, rendu tuiles + hauteur.
2. Déplacement au compteur, coûts de dénivelé, caméra isométrique.
3. Attaque de mêlée, zones par dénivelé, armure plate, PV, mort.
4. Garde, attaque lourde + télégraphe, endurance, action attendre.
5. Vecteurs Wu Xing + domination (affichage au survol).
6. Jauge de chaîne complète (transitions, décroissance, résolveur, gain intermédiaire).
7. Râtelier et swap d'arme ; bouclier.
8. Mana + assemblage de modules + les 17 modules ; friendly fire des zones.
9. Arc/projectiles, munitions.
10. IA utility + 6 créatures + actions/télégraphes ; fuite des deux côtés.
11. Jauge des élites + interruption.
12. Écran de fin de combat (XP des trois pistes) ; polissage UI.

**Critère de perf ([[Ordre de vérification]], É0) :** grille 32×32 + 10 entités, 60 fps, timeline sans latence perceptible.

## 5. Le critère de « oui » — comment on juge honnêtement

**Mesurable (sur les rencontres de référence, une par arène) :**
- Les deux voies de chaîne ([[Jauge de chaîne Wu Xing]]) — rotation parfaite et construction/détonation — produisent des dégâts totaux **à ±15 %** l'une de l'autre quand elles sont bien jouées. Sinon : retoucher les bonus de transition, pas le système.
- Le swap d'arme est rentable **dans certains cas seulement** — s'il l'est toujours ou jamais, les chiffres sont à revoir (le test est écrit dans la note).
- Une rencontre de référence dure **60 à 200 ticks** — assez pour une chaîne complète, jamais une guerre d'usure.
- L'anti-stunlock tient : aucun enchaînement de contrôles ne prive le joueur de plus de 20 ticks consécutifs.

**Qualitatif (grille de questions, à remplir après 10 combats par arène) :**
- Est-ce que je planifie 2-3 actions à l'avance en lisant la timeline ?
- Est-ce que l'encerclement me fait peur, et est-ce que le dénivelé me fait envie ?
- Est-ce qu'interrompre la chaîne du chef de bande est un moment fort ?
- Est-ce que je comprends *pourquoi* j'ai gagné ou perdu, à chaque fois, sans ouvrir le journal ?
- Ai-je envie de relancer une 11ᵉ fois ?

**La règle de décision :** tout « non » qualitatif → itérer sur le prototype (chiffres, UI, contenu) et rejuger. Le passage à l'étape 1 exige **tous les critères mesurables verts et zéro « non » qualitatif**. Si trois itérations n'y arrivent pas, le problème est structurel : remonter à [[Décisions fondatrices]] — et c'est précisément ce que le prototype existe pour découvrir avant d'avoir construit un monde autour.

> [!success] Jalons 1 à 4 codés le 2026-08-26
> `godot/` contient : autoloads **GameData** (validation de schéma, F5), **EventBus** (file + dispatch en fin de pas), **TickManager** (horloges multiples) ; `systems/grid/grille.gd` (SoA, A* 8 directions, ligne de vue, contenus) ; `systems/combat/` — `horloge.gd`, `des.gd`, `regles.gd` (toutes les formules, lues dans `data/combat_rules.json`), `etres.gd`, `simulation.gd` (l'autorité : intentions → résolution, une horloge par combat, IA utility, actions de créatures) ; `scenes/demo/main.gd` = le **client** (rendu polygonal, intentions, timeline, coûts sur les tuiles, prévisualisation avec détail du calcul, télégraphes, journal). Les **3 arènes** sont dans `data/prototype_arenas/` (`tools/gen_arenas.py` les pose), les **24 actions** dans `data/creature_actions/`, les 6 adversaires dans `data/creatures/`. Tests : `scenes/tests/test_combat.tscn` (headless, `assert`). **Schéma d'arène complété** : `spawns.player` est `{creature, pos}` — le joueur est une fiche comme les autres.
> **Jalons 5 à 7 codés le même jour** : `systems/combat/wuxing.gd` + `data/wuxing.json` (vecteurs, domination offensive/défensive, jauge de chaîne : transitions, décroissance 30 ticks, gain intermédiaire, résolveur, interruption), affichage au survol (élément contre alignement, ×, position du segment, résolution prévue) et pastilles colorées sous chaque porteur de jauge ; râtelier (touches 1-7, swap 4 ticks) et bouclier (garde front + flancs, `6 + dégâts/8`, tient la lourde ; rangé par une arme à deux mains).
> Restent : 8 (mana, modules, résolveur non offensif ×0.7), 9 (projectiles, tir refusé si un allié masque, munitions), 10 (statuts, fuite IA par Discrétion, embuscade), 11 (interruption de la jauge des élites par les contrôles — la fonction `interrompre` existe), 12 (écran de fin, XP des trois pistes, polissage).

## Liens
- **Dépend de** : [[Ordre de construction]], [[Contraintes permanentes]], [[Décisions d'architecture]], toutes les notes de combat (étape 0)
- **Alimente** : [[Vers la production]], [[Ordre de vérification]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Actions des créatures]], [[Modules]], [[Créatures]]
