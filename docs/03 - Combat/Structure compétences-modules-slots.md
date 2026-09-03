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

> [!success] Chantier clos le 2026-08-29, callout ajouté au balayage du 2026-08-31 — plus aucun slot inerte
> Le constat des « 50 slots inertes » ci-dessus est réglé depuis le 2026-08-29 (sept lots : 86 noyaux, 5 conditions, 14 modificateurs — voir [[Vers la production]]) ; `tools/audit_donnees.py` mesure aujourd'hui **0 slot inerte sur 105, budget 0**, et refuse toute régression. Le banc `test_modules` exécute les 8 536 plans sur un mannequin réel : zéro module sans effet observable.

> [!success] Décidé et codé le 2026-08-30 — **l'arme équipée entre dans tout sort**, et chaque module dit ce qu'il ajoute
> **Instruction du designer** : « quand un sort est lancé l'arme équipée rentre dans le calcul : un sort *mana* sera plus efficace avec une arme magique (un sceptre), un sort *endurance* avec une arme physique ; il faut voir à chaque module ce qu'il rajoute — dégâts, ticks, élément, ressources — et le sort finalisé doit tout afficher ». **L'affinité d'arme** : chaque fonctionnalité porte `affinite_sorts: {mana, endurance}` — le bâton magique **×1,3 mana / ×0,7 endurance**, l'épée, la masse, la lance, la hache **×0,8 mana / ×1,2 endurance**, la dague et l'arc **×0,9 / ×1,1**, le bouclier et les outils **×0,9 / ×0,9** (un seau n'est l'ami d'aucun sort), les mains nues **×1 / ×1**. Le multiplicateur s'applique à la **puissance** du plan (dés et soins) selon la **monnaie** du sort. **Décision** : c'est la fonctionnalité qui porte l'affinité, pas l'objet — un sceptre de bois et un sceptre d'os canalisent pareil ; l'élément de l'arme, lui, continue d'alimenter les noyaux `arme` comme avant.
> **La contribution de chaque module** : l'écran *Composer* calcule, pour chaque module de la séquence, **le plan avec et sans lui** et affiche la différence — ticks, ressource, dés, portée, taille, géométrie, éléments, effets. Rien n'est écrit à la main dans les fiches : c'est l'assembleur lui-même qui répond, avec l'arme tenue et les niveaux du personnage. Le sort finalisé garde son aperçu exhaustif, désormais avec l'affinité d'arme et la **fourchette** du coût.
> **Le coût varie** (« aucun chiffre fixe », étendu aux coûts sur « oui » du designer) : la ressource payée est `ressource × jet(cout_variance_des) / moyenne` — `2d6/7`, donc de ×0,29 à ×1,71 autour de 1. L'aperçu affiche la fourchette, pas un chiffre. **Décision** : la variance est **globale** (une seule notation dans `combat_rules.modules`) et non par module — un module qui aurait sa propre variance serait un chiffre fixe de plus à équilibrer.

> [!success] Décidé et codé le 2026-08-30 — plus de plafond de **modules par capacité** ; les slots de **capacités** restent
> **Instruction du designer** (assemblage sans limite) : « tous les modules devraient pouvoir s'assembler entre eux, no limit, la seule limite c'est le résultat et les stats ». Or `composer_capacite` refusait encore toute séquence plus longue que `modules_base + N_arme / par_niveau_modules` — **deux modules** au niveau 0, ce qui interdisait de fait l'assemblage libre dès la première partie. Désormais la **longueur d'une séquence n'est plus bornée** : c'est le prix (ticks, mana ou endurance, × la surface pour les effets par tuile) et les charges de modules qui limitent, comme le veut la note [[Six types de modules et assemblage]]. ~~Le **nombre de capacités composées** reste borné par les slots~~ **Levé aussi le 2026-08-30** (« pas de limite de sorts créés ») : on compose autant de capacités qu'on veut ; la hotbar n'en montre que dix à la fois, les autres se lancent depuis l'écran Capacités. `slots_capacites()` ne borne plus rien ; il reste dans les règles pour une éventuelle marche arrière. `slots_capacites().modules` n'est plus lu par la composition ; il reste dans les règles pour l'affichage historique et une éventuelle marche arrière. **Fait le 2026-08-30** : le composeur avertit dès que la séquence dépasse le seuil de télégraphie (`actions.telegraphe_seuil_ticks`) — visible de tous, interruptible. **À juger** : sans plafond, une séquence de dix modules à 60 ticks se joue-t-elle encore ?

> [!success] Tranché le 2026-09-03 — **il n'y avait qu'une seule arme magique** (designer)
> « La puissance du sort devrait être affectée par l'arme à dégât magique équipée : sceptre, bâton magique, etc. »
> **La règle existait déjà** — c'est la même instruction, donnée le 2026-08-31, qui a produit `affinite_sorts` : un sort *mana* est plus efficace avec une arme magique, un sort *endurance* avec une arme physique. **Ce qui manquait, c'est le contenu.** Le designer nommait « un sceptre » dès la première fois ; il n'y en a jamais eu. Le catalogue comptait **une** arme magique, le bâton, à ×1,30 mana — quand les **mains nues** sont à ×1,00. Choisir de canaliser ne rapportait que trente pour cent, payés par une arme qui frappe à 0,42 PV par tick.
> **Ce que ça change au déséquilibre mesuré le même jour** : les sorts au contact montent sur les dégâts de l'arme équipée, les sorts élémentaires à distance ne comptent que sur eux-mêmes — d'où un facteur quatre-vingt-quatre entre les kits de classe. Une vraie famille d'armes magiques donne aux seconds **leur propre axe de progression**, au lieu de raboter les premiers.
> **Trois armes ajoutées, un seul axe qui les sépare** — combien de sort contre combien de coup :
>
> | arme | mana | endurance | dés | vitesse | ce qu'elle est |
> |---|---|---|---|---|---|
> | **Orbe** | **×1,70** | ×0,55 | 1d3 | 1,4 | le maximum de sort, presque aucune arme |
> | **Sceptre** | ×1,45 | ×0,75 | 1d6 | 1,6 | le compromis : on canalise, on peut encore frapper |
> | **Baguette** | ×1,25 | ×0,85 | 1d4 | 2,4 | rapide, moins puissante — pour qui alterne |
> | Bâton magique *(existant)* | ×1,30 | ×0,70 | 1d4 | 1,8 | inchangé |
>
> **Le principe, pour les prochaines** : une arme magique se paie en **capacité à frapper**, jamais en autre chose. L'orbe est le cas extrême — 1d3, soit moins que les poings — et c'est ce qui rend son ×1,70 acceptable.

> [!success] Tranché le 2026-09-03 — **dix focus, trois axes pour les séparer** (designer)
> « Rajoute des armes magiques et fais en sorte qu'elles aient toutes leurs spécificités. »
> Un seul axe — la puissance canalisée — ne suffisait pas : dix baguettes qui ne diffèrent que par un chiffre, c'est neuf baguettes de trop. **Un axe a donc été ajouté au moteur** :
> - **`cout_mana_mult`** : le **talisman** ne rend pas les sorts plus forts (×1,05, presque rien), il les rend **moins chers** (×0,65) — donc plus nombreux. C'est la seule réponse au vrai goulot mesuré le même jour : *six sorts par étage*, faute de mana.
>
> | focus | mana | élément | coût | dés | mains | ce qui n'appartient qu'à lui |
> |---|---|---|---|---|---|---|
> | **Orbe** | ×1,70 | — | — | 1d3 | 1 | la puissance brute maximale |
> | **Grimoire de main** | ×1,55 | — | — | 1d3 | **2** | presque autant, mais les deux mains prises |
> | **Sceptre** | ×1,45 | — | — | 1d6 | 1 | le compromis : on canalise et on frappe encore |
> | **Bâton magique** | ×1,30 | — | — | 1d4 | 1 | l'historique, inchangé |
> | **Baguette** | ×1,25 | — | — | 1d4 | 1 | vitesse 2,4 : le plus rapide |
> | **Talisman** | ×1,05 | — | **×0,65** | 1d3 | 1 | le nombre plutôt que la force |
>
> > [!warning] Retiré le 2026-09-03, une heure après — **les quatre focus élémentaires** (designer)
> > « Retire les armes magiques élémentaires ». Bâton de cendre, sceptre de jade, trident rituel et marteau runique sont partis, **et le levier `affinite_element` avec eux** : un mécanisme que plus aucune fiche n'utilise trompe le prochain lecteur, qui le croit vivant. Il reste **six focus**, séparés par la puissance canalisée, le coût en mana, les mains et les dés.
> > **Ce que j'en retiens** : l'affinité élémentaire par l'arme faisait porter le Wu Xing par un objet, quand le Wu Xing du jeu se joue déjà dans le **sort** et dans la **matière**. J'ai ajouté un troisième endroit où le même système se décide, sans que personne me l'ait demandé.
>
> **La règle qui tient l'ensemble** : une arme magique se paie en **capacité à frapper**, jamais en autre chose. L'orbe frappe moins fort que les poings ; le marteau runique, qui frappe vraiment, ne canalise que ×1,10.
> **La sonde le garde** : `sonde_canalisation.tscn` échoue si un focus ne canalise pas mieux que les mains nues, si une arme physique ne coûte rien, si l'écart orbe/épée tombe sous 1,5, ou si **deux focus ont la même puissance, le même élément et le même coût**. Et `sonde_armes.tscn` compare désormais aussi ces trois axes — sans quoi elle déclarait un sceptre de jade identique à un sceptre ordinaire, puisqu'ils frappent pareil.

> [!success] Tranché le 2026-09-03 — **chaque noyau monte sur sa propre stat** (designer : « on va retravailler les modules pour que ça rentre dans notre nouveau système »)
> **Le point de blocage, mesuré.** `degats_sort` lit **une seule stat pour tous les sorts** : `volonte`. Un cri de ralliement, une frappe d'épaule, un tir précis — tout montait sur la volonté. Le système venait pourtant d'acquérir six voies : une classe, une famille d'armes et une construction d'armure par stat. Les **modules étaient la seule pièce qui n'y entrait pas**, et c'est la plus importante : ils sont l'identité du jeu.
> **Ce qui change** : chaque noyau déclare la stat qui le porte (`stat`), et `degats_sort` la lit au lieu de supposer la volonté. Rien d'autre ne bouge — ni les dés, ni les coûts, ni les écoles élémentaires.
> **Le tri suit ce que les noyaux disaient déjà**, comme pour les classes : la monnaie et la famille. Un noyau qui coûte du **mana** relève de la **volonté** ; un noyau qui coûte de l'**endurance** relève du corps, et sa famille dit lequel.
>
> | stat | noyaux | ce qu'elle porte |
> |---|---|---|
> | **volonté** | les 68 noyaux à mana | tout ce qui se paie en mana reste à l'esprit |
> | **force** | Arme lourde, Espace physique | frappe, charge d'épaule, fauchage, projection, élan, poussée |
> | **dextérité** | Arme fine, Contrôle physique | estoc, botte, feinte, désarmement, empoigne, rupture |
> | **endurance** | Défense et Terrain physiques | ancrage, trempe, bombe, tourelle |
> | **perception** | Ressource d'observation | estimation, traque |
> | **charisme** | Ressource sociale | pari, offrande |
>
> **La règle de conception** : on ne déplace pas un noyau pour équilibrer un tableau. Chaque affectation doit se lire sur ce que le noyau **fait** — un désarmement est une affaire de main, pas de bras ; une estimation est une affaire d'œil. Là où le doute existait, la monnaie a tranché.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Progression par l'usage]]
- **Alimente** : [[Six types de modules et assemblage]], [[Mana]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Grimoires et manuels]], [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Écrans d'interface]], [[Tooltips contextuels]]
