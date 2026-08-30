---
aliases: ["Structure des compétences", "Slots", "Compétences et modules", "Structure compétences/modules/slots"]
tags: [combat, build, décidé]
domaine: combat
statut: décidé
etape: 0
---

L'emboîtement arme → compétences → modules, façon Noita + Elin, et la croissance des slots avec le niveau d'arme.

**Structure des compétences (façon Noita + Elin) :**
- Chaque **type d'arme** possède un nombre de **slots de compétences**.
- Chaque **compétence** possède un nombre de **slots de modules**.
- Les **modules** s'assemblent façon Noita (modificateurs de sort/attaque) et sont **communs à toutes les armes** : n'importe quel module peut s'équiper dans n'importe quel type d'arme (pas de restriction par arme).
- Chaque module a un **coût en mana** : plus un module/sort est complexe, plus il coûte de mana à utiliser.
- Le **mana se régénère façon Elin** : récupération passive dans le temps (chance de récupération par tour, influencée par une compétence dédiée), accélérée par le repos. Voir [[Mana]].

**Décision — Slots : croissants avec le niveau d'arme :**
- slots de compétences par arme = `2 + floor(N_arme/20)` (**max 6**) ;
- slots de modules par compétence = `2 + floor(N_arme/25)` (**max 5**).

La progression d'arme débloque de la **complexité de build**, pas seulement des chiffres.

**Coût en mana d'une compétence assemblée ([[Mana]]) :**
```
cout_total = somme des couts des modules équipés dans la compétence
cout_module_effectif = cout_base_module / skill_factor(N_module)
```
Monter un module en niveau le rend plus puissant ET moins coûteux (puissance : `effet_base * skill_factor(N_module)`).

**Les capacités hors slots ([[Talents de classe]]) :** un **talent de classe** est un module qui **n'occupe aucun emplacement** et n'a pas besoin d'être trouvé. Il monte par l'usage comme les autres. C'est la seule chose qui échappe au compte de slots — et c'est volontaire : *le talent est un plancher, pas une cage*, les slots restent entièrement libres pour ce qu'on ramasse.

**Les jauges de classe ([[Talents de classe]]) :** certains talents portent une barre propre à la classe (la jauge de sang de L'Écarlate), calquée sur la [[Jauge de chaîne Wu Xing]] — **même objet de code, autres conditions de remplissage**. Aucun système parallèle.

**Règles d'assemblage détaillées :** voir [[Six types de modules et assemblage]].

**Écran dédié ([[Écrans d'interface]]) :** *Assemblage de compétences (slots armes/modules, coûts mana)*.

> [!success] Décidé le 2026-08-27 — le niveau d'un module réduit aussi ses ticks
> Tranché par le designer : « plus une attaque est complexe, plus elle coûte de ressources et de ticks ; moins si les modules employés sont haut niveau ». En plus de `cout_module_effectif = cout_base / skill_factor(N_module)` (ressource, sans plancher), chaque module de la séquence contribue `ticks_effectifs = max(ticks_base × 0,5, ticks_base / skill_factor(N_module))` — **plancher à 50 %** : la complexité coûte toujours du temps, un module de niveau 100 ne devient jamais gratuit. Les surcoûts en ticks des formes, modificateurs, conditions, déclencheurs et liaisons suivent la même règle, chacun avec son propre niveau.

> [!success] Codé le 2026-08-28 — l'assemblage de capacités
> Menu (Tab) → **Capacités** : la liste des capacités du joueur (Entrée : supprimer), puis **Nouvelle capacité** → écran de composition : les modules appris (`modules_connus`, groupés par type ; les modules des trois capacités de départ sont connus d'office) s'ajoutent à la **séquence** dans l'ordre choisi (Entrée ajoute / retire), l'aperçu montre le plan assemblé (géométrie, coût, dés, erreurs) ; *Valider* crée la capacité, nommée d'après son noyau, qui arrive dans la hotbar. **Slots** : `capacités max = 2 + ⌊N_arme/20⌋` (max 6), `modules par capacité = 2 + ⌊N_arme/25⌋` (max 5), N_arme = niveau de la compétence de l'arme en main (`combat_rules.capacites`). Une séquence sans noyau ou avec deux noyaux est refusée par l'assembleur existant. Les slots « par type d'arme » sont simplifiés en une liste unique du joueur (décision : la hotbar est l'unique râtelier de capacités).

> [!success] Vérifié le 2026-08-29 — tout le catalogue de modules passé au banc
> Demande du designer : *tester la création de sorts avec les modules*. `test_creation_de_sorts` monte un banc sur **tout le catalogue** (178 modules) plutôt que sur trois exemples : les **86 noyaux** assemblés seuls, les **16 formes** avec un noyau, **300 séquences de 1 à 5 modules tirées au hasard** dans les six types, puis un aller-retour complet *composer → lancer en jeu* sur cinq géométries. Invariants vérifiés sur chaque plan accepté : un noyau (à la racine, ou dans la **charge différée** quand la séquence s'ouvre sur un déclencheur), des ticks ≥ 1, une portée dont le minimum ne dépasse pas le maximum, une ressource ≥ 0, une monnaie connue. **Résultat : rien de cassé** — 115 des 300 séquences aléatoires s'assemblent, les 185 autres sont **refusées proprement** (deux noyaux sans Alternance, aucun noyau) ; les refus attendus le sont bien, et aucun plan à moitié construit n'est accepté. Une seule leçon, sur le **test** et non sur le code : un plan ouvert par un déclencheur porte légitimement son noyau dans `charge_suivante`, comme le prescrivent les [[Vocabulaire des modules — six axes|six types de modules]].

> [!success] Corrigé le 2026-08-29 — trois bugs trouvés en **exécutant** les 86 noyaux, pas en les assemblant
> Le banc de la passe précédente vérifiait que les sorts se *composent*. Les **lancer** sur une cible réelle a fait tomber trois choses. **(1)** Trois noyaux (`aiguille`, `eclat`, `fonte`) écrivaient leur élément **`"métal"` avec un accent** : `WuXing.relation` accède directement à sa table (`w.domine[att]`) et **plantait** à chaque coup porté par ces sorts — le multiplicateur élémentaire n'était jamais calculé. Corrigé, et l'audit vérifie désormais **tout nom d'élément** cité en données (modules, créatures, objets, matériaux, affixes, statuts, actions, biomes). **(2)** *Alternance* : le plan du **second noyau** (`plan.alt`) était lancé tel quel alors qu'il n'héritait ni du `name_key`, ni de l'`id`, ni de l'`arme`, ni de la `fonct` du plan principal — un emploi sur deux plantait donc en pleine résolution (et un noyau d'arme n'aurait rien trouvé à frapper). Les quatre attaches sont recopiées. **(3)** Le journal de dégâts lisait `plan.name_key` sans défaut : une erreur y interrompait **toute la charge** (la fonction rendait `null`, et l'appelant plantait à son tour sur `res.a_touche`). Lecture défensive. Les trois n'étaient visibles que parce que le test **exécute** chaque noyau : aucun n'apparaît à l'assemblage.

> [!important] Constat du 2026-08-29 — **47 noyaux sur 86 ne font rien quand on les lance**
> Le banc d'exécution a révélé bien plus qu'un bug : la moitié du catalogue est **inerte**. Un noyau porte deux choses — la liste de ses `effets` (« statut », « terrain », « déplacement », « invocation », « tempo »…) et le champ **`effet`** qui donne la **donnée** que l'effet consomme (quel statut, quelle hauteur, quel contenu de tuile). **62 noyaux sur 86 ont un `effet` vide** ; pour ceux dont l'effet est *dégâts* ou *soin* ce n'est pas grave (la puissance vient de `power_base`), mais pour les autres le sort part, coûte ses ticks et sa ressource, et **ne produit rien** — silencieusement. Le compte exact : **50 slots inertes** — 28 `statut` (Ancrage, Aveuglement, Silence, Trempe, Voile…), 8 `terrain` (Ancre, Balise, Nappe, Portail, Racine…), 6 `déplacement` (Projection, Fauchage, Lévitation, Traversée…), 4 `invocation` (Bombe, Tourelle, Relevé, Écho de chair), 4 `dégâts`/`soin` sans `power_base` (Cataclysme, Fosse, Rappel à la vie, Transfert). Beaucoup demandent en plus des **statuts qui n'existent pas** (le catalogue en compte 17). `tools/audit_donnees.py` mesure le chiffre à chaque passage et **refuse qu'il augmente** (budget 50, à faire descendre) — c'est un chantier de contenu, pas un bug ponctuel.

> [!success] Décidé et codé le 2026-08-30 — **l'arme équipée entre dans tout sort**, et chaque module dit ce qu'il ajoute
> **Instruction du designer** : « quand un sort est lancé l'arme équipée rentre dans le calcul : un sort *mana* sera plus efficace avec une arme magique (un sceptre), un sort *endurance* avec une arme physique ; il faut voir à chaque module ce qu'il rajoute — dégâts, ticks, élément, ressources — et le sort finalisé doit tout afficher ». **L'affinité d'arme** : chaque fonctionnalité porte `affinite_sorts: {mana, endurance}` — le bâton magique **×1,3 mana / ×0,7 endurance**, l'épée, la masse, la lance, la hache **×0,8 mana / ×1,2 endurance**, la dague et l'arc **×0,9 / ×1,1**, le bouclier et les outils **×0,9 / ×0,9** (un seau n'est l'ami d'aucun sort), les mains nues **×1 / ×1**. Le multiplicateur s'applique à la **puissance** du plan (dés et soins) selon la **monnaie** du sort. **Décision** : c'est la fonctionnalité qui porte l'affinité, pas l'objet — un sceptre de bois et un sceptre d'os canalisent pareil ; l'élément de l'arme, lui, continue d'alimenter les noyaux `arme` comme avant.
> **La contribution de chaque module** : l'écran *Composer* calcule, pour chaque module de la séquence, **le plan avec et sans lui** et affiche la différence — ticks, ressource, dés, portée, taille, géométrie, éléments, effets. Rien n'est écrit à la main dans les fiches : c'est l'assembleur lui-même qui répond, avec l'arme tenue et les niveaux du personnage. Le sort finalisé garde son aperçu exhaustif, désormais avec l'affinité d'arme et la **fourchette** du coût.
> **Le coût varie** (« aucun chiffre fixe », étendu aux coûts sur « oui » du designer) : la ressource payée est `ressource × jet(cout_variance_des) / moyenne` — `2d6/7`, donc de ×0,29 à ×1,71 autour de 1. L'aperçu affiche la fourchette, pas un chiffre. **Décision** : la variance est **globale** (une seule notation dans `combat_rules.modules`) et non par module — un module qui aurait sa propre variance serait un chiffre fixe de plus à équilibrer.

> [!success] Décidé et codé le 2026-08-30 — plus de plafond de **modules par capacité** ; les slots de **capacités** restent
> **Instruction du designer** (assemblage sans limite) : « tous les modules devraient pouvoir s'assembler entre eux, no limit, la seule limite c'est le résultat et les stats ». Or `composer_capacite` refusait encore toute séquence plus longue que `modules_base + N_arme / par_niveau_modules` — **deux modules** au niveau 0, ce qui interdisait de fait l'assemblage libre dès la première partie. Désormais la **longueur d'une séquence n'est plus bornée** : c'est le prix (ticks, mana ou endurance, × la surface pour les effets par tuile) et les charges de modules qui limitent, comme le veut la note [[Six types de modules et assemblage]]. ~~Le **nombre de capacités composées** reste borné par les slots~~ **Levé aussi le 2026-08-30** (« pas de limite de sorts créés ») : on compose autant de capacités qu'on veut ; la hotbar n'en montre que dix à la fois, les autres se lancent depuis l'écran Capacités. `slots_capacites()` ne borne plus rien ; il reste dans les règles pour une éventuelle marche arrière. `slots_capacites().modules` n'est plus lu par la composition ; il reste dans les règles pour l'affichage historique et une éventuelle marche arrière. **Fait le 2026-08-30** : le composeur avertit dès que la séquence dépasse le seuil de télégraphie (`actions.telegraphe_seuil_ticks`) — visible de tous, interruptible. **À juger** : sans plafond, une séquence de dix modules à 60 ticks se joue-t-elle encore ?

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Progression par l'usage]]
- **Alimente** : [[Six types de modules et assemblage]], [[Mana]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Grimoires et manuels]], [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Écrans d'interface]], [[Tooltips contextuels]]
