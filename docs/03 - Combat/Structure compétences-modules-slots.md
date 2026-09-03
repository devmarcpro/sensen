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
> **Instruction du designer** (assemblage sans limite) : « tous les modules devraient pouvoir s'assembler entre eux, no limit, la seule limite c'est le résultat et les stats ». Or `composer_capacite` refusait encore toute séquence plus longue que `modules_base + N_arme / par_niveau_modules` — **deux modules** au niveau 0, ce qui interdisait de fait l'assemblage libre dès la première partie. Désormais la **longueur d'une séquence n'est plus bornée** : c'est le prix (ticks, mana ou endurance, × la surface pour les effets par tuile) et les charges de modules qui limitent, comme le veut la note [[Six types de modules et assemblage]]. ~~Le **nombre de capacités composées** reste borné par les slots~~ **Levé aussi le 2026-08-30** (« pas de limite de sorts créés ») : on compose autant de capacités qu'on veut ; la hotbar n'en montre que dix à la fois, les autres se lancent depuis l'écran Capacités. ~~L'ancienne fonction de slots ne borne plus rien ; elle reste dans les règles pour une éventuelle marche arrière.~~ **Retirée le 2026-09-03** : le plafond par comptage est remplacé par la **grille de composition** — `grille_composition()` donne la silhouette de l'arme tenue, `emboitement()` dit si les pièces y tiennent ([[Six types de modules et assemblage]], callout du 2026-09-03). **Fait le 2026-08-30** : le composeur avertit dès que la séquence dépasse le seuil de télégraphie (`actions.telegraphe_seuil_ticks`) — visible de tous, interruptible. **À juger** : sans plafond, une séquence de dix modules à 60 ticks se joue-t-elle encore ?

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

> [!success] Tranché le 2026-09-03 — **le charisme, ce sont les buffs, les débuffs et les invocations** (designer)
> « Pour le charisme je me dis que le mieux serait d'en faire des sorts de buff, débuff, invocation, etc. »
> **Et ces sorts existent déjà** — ils étaient simplement tous rangés sous la volonté, comme les 68 autres noyaux à mana. Il n'y a donc rien à écrire : il y a à **trier**, exactement comme pour les classes et pour les armes.
> **Le critère** : le charisme agit sur **l'esprit d'autrui** ou **rallie les siens** ; la volonté agit sur la **matière et l'énergie**. Un effroi fait fuir — c'est du charisme. Une entrave immobilise avec des racines — c'est de la volonté. La distinction n'est pas « bon ou mauvais sort », c'est **sur quoi le sort agit**.
>
> | passent au charisme | pourquoi |
> |---|---|
> | **effroi**, **torpeur**, **silence**, **épuisement**, **marque** | on brise le moral, on impose sa présence |
> | **célérité**, **égide**, **communion**, **transfert**, **réserve** | on soutient un allié — la moitié utile d'un meneur |
> | **convocation**, **rappel à la vie**, **renaissance** | on appelle, et quelqu'un vient |
> | **pari**, **offrande** | déjà là : l'aplomb et le don |
>
> **Ce que ça donne** : la volonté passe de 70 à 56 noyaux, le charisme de 2 à **16**. Le déséquilibre ne disparaît pas — la volonté garde tous les élémentaires et tout le terrain — mais le charisme cesse d'être une voie sans répertoire.
> **Ce que ça ne règle pas, et qu'il faut dire** : la perception reste à 2 et l'endurance à 4. Elles n'ont pas d'équivalent naturel dans le catalogue actuel, qui a été écrit avant que les six voies existent. Là, il faudra écrire du contenu — ou assumer que ces voies s'expriment par les armes plutôt que par les sorts.

## Liens
- **Dépend de** : [[Combat tactique sur grille]], [[Progression par l'usage]]
- **Alimente** : [[Six types de modules et assemblage]], [[Mana]], [[Vocabulaire des modules — six axes]]
- **Voir aussi** : [[Grimoires et manuels]], [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Écrans d'interface]], [[Tooltips contextuels]]

## 2026-09-03 — L'identité des six stats, et le rangement des armes qui en découle

Le designer tranche, et il tranche dans le bon ordre : **l'identité d'abord, le reste ensuite.**

> « force c'est le guerrier donc des grosses armes au corps à corps, dextérité c'est des armes plus
> petites genre des dagues c'est la vitesse qui prime, volonté c'est le mage, perception c'est le
> tireur le sniper il attaque de loin, le charisme c'est le barde avec ses instruments il boost ses
> alliés et endurance c'est les armes de corps à corps à grandes allonges genre les lances hallebarde »

| stat | l'archétype | le critère d'une arme |
|---|---|---|
| force | le guerrier | contact, lourde ou d'impact |
| dextérité | la lame rapide | contact, légère — la vitesse prime |
| endurance | la ligne | contact, **allonge ≥ 2** |
| volonté | le mage | focus de mana |
| perception | le tireur | **projectile, à distance** |
| charisme | le barde | instrument, il soutient les siens |

Le catalogue n'était pas rangé comme ça. La dextérité tenait **tout** le tir du jeu (arc, arbalète,
fronde, pistolet) alors que le tir est l'identité de la perception ; la lance était sous la force
alors que son allonge de 2,5 en fait l'arme de l'endurance ; et la perception avait un stylet
d'allonge 1 — une dague, sous la stat du sniper.

**Ce qui bouge** (les compétences changent de stat ; les armes ne changent pas de chiffre) :

    arc, arbalète, fronde, armes à poudre   dextérité -> PERCEPTION   le tir est au tireur
    lance, bâton                            dex/force -> ENDURANCE    allonge 2,5 et 2,0
    rapière                                 force     -> DEXTÉRITÉ    via une compétence `escrime`
    stylet                                  perception-> DEXTÉRITÉ    via la compétence `dague`

La rapière avait besoin d'une compétence à elle : elle partageait `epee` avec l'épée et le sabre,
et on ne déplace pas les trois pour une seule. `escrime` est donc la lame de finesse — vitesse 2,4,
volume 2,2 — là où `epee` reste la lame du guerrier.

Après : force 7, dextérité 7, endurance 4, perception 6, volonté 6, charisme 3. Avant, c'était
force 9 / dextérité 10 contre endurance 2 / perception 3. Aucune voie n'est plus un placard.

**Deux choses que je n'ai pas déplacées, et pourquoi.** Les armes de **jet** (couteau, hachette,
javelot) portent à 5-8 cases : à la lettre du critère c'est « de loin », mais un couteau lancé est un
geste de main rapide, pas un tir posé — elles restent à la dextérité. Le **fouet** a la plus grande
allonge du jeu (3,0) et devrait donc partir à l'endurance, mais il pèse 1,0 pour une vitesse de 2,2 :
c'est une arme de finesse, elle reste à la dextérité. Dans les deux cas le critère de l'archétype bat
le chiffre brut ; si le designer préfère la lettre, c'est une ligne à changer dans `competences/`.

**Ce que ça ne règle pas :** le charisme n'a que trois armes, toutes des instruments, et l'endurance
quatre. Ce sont les deux voies à étoffer — et l'identité, maintenant, dit quoi y écrire.

### Six armes par stat (designer 2026-09-03)

> « fais en sorte que chaque stat ait 6 armes et qu'elles se différencient toutes »

Deux armes rejoignent l'endurance **par le critère d'allonge déjà posé**, pas pour faire le compte :
le **fléau** porte à 2,0 et le **fouet** à 3,0. Le fouet est le cas que j'avais laissé en suspens la
veille — je disais que son poids de 1,0 en faisait une arme de finesse ; l'allonge l'emporte, c'est
la plus grande du jeu. Le fléau partageait la compétence `masse` avec la masse et le marteau, qui
frappent au contact : il lui fallait la sienne, `armes_a_chaine` — ce qui se balance au bout d'une
longe.

Le charisme passe de trois instruments à six, et la famille se lit sur **une seule échelle** : plus
un instrument s'engage dans l'endurance, moins il sert au mana.

| instrument | mains | dés | vitesse | mana | endurance | sa signature |
|---|---|---|---|---|---|---|
| flûte | 1 | 1d3 | 2,8 | **1,05** | 1,20 | la seule du charisme qui serve *aussi* au mana |
| cor | 1 | 1d3 | 2,0 | 0,90 | 1,25 | la plus légère à porter |
| cymbales | 1 | 1d8 | 1,6 | 0,75 | 1,35 | la seule qui frappe vraiment (crit 19) |
| luth | 1 | 1d4 | 1,8 | 0,85 | 1,45 | l'équilibre de la famille |
| tambour | 2 | 1d6 | 1,2 | 0,70 | 1,65 | deux mains, la puissance sans le mana |
| vielle | 2 | 2d4 | 0,9 | **0,55** | **1,85** | la plus forte affinité d'endurance du jeu |

Six échelons distincts, dans les deux sens. Aucune n'est le doublon d'une autre — la sonde le
vérifie, et l'échelle donne au joueur charisme un vrai arbitrage plutôt qu'un choix cosmétique.

**Une arme écrite puis retirée :** une `pique` à portée 3,5 et portée minimale 2 — la seule arme
lourde qui ne peut pas frapper au corps à corps. Elle aurait porté l'endurance à sept. Elle est
notée ici parce que l'idée est bonne et que le jour où l'endurance s'étoffera, c'est par là qu'il
faut commencer.

Total : 36 armes, six par voie.

### Les instruments jouaient contre leur propre voie (2026-09-03)

Le designer groupe les monnaies : **mana pour la volonté et le charisme**. Cette phrase révèle une
contradiction que les données portaient déjà, et que personne n'avait vue.

Les quatorze noyaux de charisme coûtent du **mana**. Les six instruments du charisme, eux, avaient
été écrits comme focus de l'**endurance** — la vielle donnait 1,85 en endurance et **0,55 en mana**.
Autrement dit : un barde qui équipait son meilleur instrument **divisait par deux la puissance de ses
propres sorts**. La famille entière punissait la voie qu'elle était censée servir.

Les deux valeurs sont donc échangées. L'échelle ne change pas de forme — plus un instrument
s'engage, plus il est exclusif — elle change simplement de monnaie :

| instrument | mana | endurance |
|---|---|---|
| flûte | 1,20 | 1,05 |
| cor | 1,25 | 0,90 |
| cymbales | 1,35 | 0,75 |
| luth | 1,45 | 0,85 |
| tambour | 1,65 | 0,70 |
| vielle | **1,85** | 0,55 |

**Pour revenir en arrière**, il suffit de ré-échanger `mana` et `endurance` dans les six fichiers de
`functionalities/`. Aucune autre donnée n'en dépend.

C'est le genre d'erreur qu'aucune sonde ne trouve : chaque valeur était valide, l'échelle était
cohérente, l'audit passait au vert. Il fallait qu'une décision de design vienne dire à quelle monnaie
la voie appartenait pour que le contresens devienne visible.

### Trois monnaies, et la philosophie des paires (designer 2026-09-03)

Le designer groupe : **mana** pour volonté + charisme, une monnaie pour force + endurance, une pour
perception + dextérité. Puis il corrige la lecture que j'en avais faite :

> « C'est pas vraiment qu'une stat tient et l'autre dépense, mais plutôt que **volonté est dépendante
> du mana pour le combat alors que charisme s'en sert en bonus** — c'est plutôt la philosophie des
> paires. »

C'est une correction de fond, pas de vocabulaire. Ma version faisait de la paire un **couple
mécanique** : l'une remplit, l'autre vide, personne ne se suffit. La sienne en fait un **rapport de
dépendance** : chaque monnaie a un **propriétaire**, dont tout le combat en dépend et qui porte donc
la réserve, et un **invité**, qui s'en sert par-dessus sa propre façon de se battre.

| monnaie | le propriétaire (en dépend, porte la réserve) | l'invité (s'en sert en bonus) |
|---|---|---|
| mana | volonté — le mage ne fait que ça | charisme |
| vigueur | force — chaque coup la paie | endurance |
| sang-froid | dextérité — feintes, désarmements, empoignes | perception |

Et l'invité n'est pas démuni, parce que **la solution B tient en même temps** : chaque stat desserre
une rareté qui existe déjà. L'endurance a les PV, le charisme a les corps alliés, la perception a la
portée. Le propriétaire a la barre, l'invité a la rareté — les deux systèmes ne s'excluent pas, ils
se complètent.

```
mana_max      = 20 + volonté   × 3     (inchangé)
vigueur_max   = 60 + force     × 4     (avant : un plafond FIXE de 100)
sangfroid_max = 20 + dextérité × 3     (nouveau)
santé_max     = 20 + endurance × 4     (inchangé — c'est la rareté de l'endurance)
```

**Le sang-froid est le troisième comportement, et il est l'inverse des deux autres.** La vigueur
revient à 2/tick — elle limite ton *rythme*. Le mana revient 160× plus lentement — il limite ton
*budget* sur un étage. Le sang-froid, lui, **ne se gagne pas en agissant : il se gagne en ne bougeant
pas.** Hors combat il revient seul ; en combat il ne monte que si le corps est immobile depuis six
ticks. Celui qui se replace perd son sang-froid, celui qui tient sa ligne le construit. On réutilise
`immobile_depuis`, que la canalisation et Pied ferme lisent déjà : un seul compteur d'immobilité pour
tout le jeu.

Huit noyaux changent de monnaie — les six de dextérité (estoc, botte, feinte, désarmement, empoigne,
rupture) et les deux de perception (estimation, traque). Dépenser à vide se paie en PV, comme la
surchauffe du mana et l'épuisement de la vigueur.

**Ce que je n'ai pas fait, et pourquoi.** La monnaie s'appelle « vigueur » à l'écran mais sa clé
interne reste `endurance` : le renommage touchait 92 fichiers de données et 118 endroits du code, dont
le HUD, au moment même où j'ajoutais une monnaie. Le gain était la clarté du nom, le risque était de
casser l'existant — j'ai pris le nom d'affichage et laissé la clé. C'est une dette, elle est écrite
ici.

**Et la perception a enfin sa rareté.** Le bloc `vision` était le seul des six à être vide — il ne
contenait qu'une hauteur d'œil, quand la force avait `poids.par_force` et le charisme
`compagnons.par_charisme` depuis toujours. Une arme à projectile gagne désormais
`perception × 0,5` tuiles de portée. Le contact n'y gagne rien : voir mieux n'allonge pas le bras.

### La vigueur et l'endurance ne portent plus le même nom (designer 2026-09-03)

> « Sépare bien vigueur et endurance. »

La dette écrite trois heures plus tôt est payée. La **stat** s'appelle `endurance`, la **monnaie**
s'appelle `vigueur`, et plus rien ne les confond : ni les données, ni le code, ni l'écran.

Ce qui a bougé : `cout_endurance` → `cout_vigueur` sur 92 modules et actions de créature · le bloc
`endurance` de `combat_rules` → `vigueur` · les champs d'être `endurance`, `endurance_max`,
`tick_endurance` → `vigueur`, `vigueur_max`, `tick_vigueur` · la monnaie d'un plan · les clés
`affinite_sorts` des 33 armes · l'affixe `meca_endurance_max` → `meca_vigueur_max` (fichier compris)
et les trois types d'affixe de parade · la clé de traduction. **182 fichiers de données, 20 de code.**

Ce qui n'a PAS bougé, et c'est tout l'intérêt de l'opération : `stats.endurance`,
`sante_max_par_endurance`, `souffle_par_endurance`, les listes des six stats. La stat garde son nom
partout où c'est d'elle qu'on parle.

> [!warning] Le piège du renommage global, payé et documenté
> Remplacer `"endurance"` par `"vigueur"` partout a corrompu **neuf littéraux de stats** — des
> dictionnaires comme `sante_max({"endurance": 10})` ou `{"force": 8, "dexterite": 3, "endurance": 3}`
> devenus muets. La suite les a tous attrapés : trois plantages francs et six assertions fausses.
> **Un renommage qui traverse la frontière stat/monnaie ne peut pas être aveugle** : il faut lister
> les formes composées (`cout_`, `tick_`, `_max`), puis les receveurs d'entité un par un, et mettre
> à l'abri les formes de stats avant de toucher au reste.

Il reste un endroit où les deux se ressemblent encore, et c'est voulu : `sante_max_par_endurance`
dit bien que **les PV sont la rareté de la stat endurance** — l'invitée de la vigueur n'est pas
démunie, elle a sa propre barre.

### Un noyau martial est une autre façon d'utiliser son arme — ou son corps (designer 2026-09-03)

> « Je pense que la bonne façon de voir les modules pour les capacités autres que les sorts, c'est de
> voir ça comme une autre façon d'utiliser son arme entre autres. »
> « On peut même s'amuser en faisant des modules qui utilisent les parties du corps du personnage,
> par exemple coup de tête. »

La mesure d'abord : sur les **20 noyaux martiaux** (ceux qui coûtent de la vigueur ou du sang-froid),
**3 seulement montaient sur l'arme** (`power_base: "arme"`). Les 17 autres se répartissaient en deux
cas très différents, et il fallait les séparer avant de toucher à quoi que ce soit :

- **quinze n'ont aucun dé.** Empoigne saisit, désarmement fait lâcher, ancrage pose un statut,
  poussée déplace. Ils n'ont rien à hériter de l'arme : ce ne sont pas des coups.
- **deux frappaient avec des dés inventés** — charge d'épaule (1d6) et saignement (1d4). Ceux-là
  rendaient l'arme tenue **sans importance** : charger avec un marteau de guerre ou avec une flûte
  faisait exactement le même mal. Ils montent désormais sur l'arme, dés et élément compris.

Et le **corps** est l'exception assumée à ce principe, parce qu'elle en est le miroir :

| noyau | voie | monnaie | dés | sa signature |
|---|---|---|---|---|
| coup de tête | force | vigueur 10 | 1d6 | +5 ticks au compteur de la cible |
| coup de genou | force | vigueur 8 | 1d8 | le plus fort du répertoire, au contact strict |
| coup de coude | dextérité | sang-froid 6 | 1d4 | trois ticks : le plus rapide du jeu |
| coup de pied | endurance | vigueur 9 | 1d4 | repousse d'une tuile — on fait de la place |

Leurs dés sont **fixes et ne viennent jamais de l'arme**. C'est leur faiblesse et c'est leur raison
d'être : ils fonctionnent **les mains prises et une fois désarmé**. Un noyau martial est une autre
façon d'utiliser son arme ; un noyau de corps est ce qui reste quand on n'en a plus.

L'endurance passe de quatre noyaux à cinq, la dextérité de six à sept. **La perception reste à deux**
— et cette fois ce n'est plus faute de contenu à écrire, c'est que sa voie ne s'exprime pas par des
coups. Elle attend des noyaux d'information : voir avant, viser mieux, savoir où frapper.

### La perception ne frappe pas, elle sait (2026-09-03)

La voie du tireur n'avait que deux noyaux, et j'ai d'abord cru que c'était faute de contenu à écrire.
C'était faux : **sa voie ne s'exprime pas par des coups.** Un noyau de perception ne fait pas de
dégâts — il transforme du temps passé à regarder en avantage. Quatre noyaux d'**information**, tous
payés en sang-froid, la monnaie qui se gagne en ne bougeant pas : la boucle se referme sur elle-même.

| noyau | sur | ce que ça donne | sang-froid |
|---|---|---|---|
| visée | soi | +2 dés pendant 40 ticks | 10 |
| point faible | la cible | vulnérabilité ×1,35 pendant 50 ticks | 12 |
| lecture du geste | la cible | armure ×0,75 pendant 40 ticks | 11 |
| aux aguets | soi | détection ×1,6 pendant 60 ticks | 7 |

Chacun réutilise un modificateur de statut que le moteur lisait déjà (`des`, `vulnerabilite`,
`armure`, `detection`) : aucune ligne de simulation n'a changé. La perception passe de deux noyaux à
six, et la sonde ne signale plus aucune voie maigre.

> [!warning] Une régression du renommage, trouvée en passant
> Le statut **Épuisement** bloque une monnaie. Sa cible disait `endurance` quand le plan dit désormais
> `vigueur` : il ne bloquait plus rien, **sans le moindre message**. Corrigé, et un test parcourt
> désormais tous les statuts qui bloquent une monnaie pour vérifier qu'ils en nomment une qui existe.
