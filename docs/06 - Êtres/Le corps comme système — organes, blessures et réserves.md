---
aliases: ["Le corps comme système", "Stats des organes", "Greffe", "Blessures en couches", "La vie comme réserve", "Marché des organes"]
tags: [êtres, combat, économie, à décider, designer]
domaine: êtres
statut: à décider
etape: 11
---

Cinq idées du designer, le 2026-09-10 en fin de journée, dans une seule conversation. Elles se sont enchaînées d'elles-mêmes, et à la relecture **elles n'en font qu'une** : elles décrivent toutes le même corps, vu de cinq côtés. Cette note les garde entières — avec ce qui existe déjà pour les porter, ce qui les met en danger, et **la seule question qui les commande toutes**.

Rien de tout cela n'est décidé. C'est une exploration, écrite avant tout code.

## Ce qui existe déjà, et qu'il ne faut pas réinventer

Deux corrections à ce que je croyais en début de conversation, et elles changent le point de départ :

- **Le soin par partie EXISTE** depuis le 2026-09-09 ([[Squelette modulaire et points d'attache]], commit `4678d00c`). Hors combat, une partie entamée se répare, bien plus lentement que la santé globale ; une nuit remet le corps d'aplomb. Et surtout : **un membre perdu ne repousse pas — c'est la prothèse qui le remplacera, pas le temps.**
- **Les organes font DÉJÀ quelque chose**, par leur bloc `perdu` : un poumon perdu retranche 25 % de la vigueur maximale, un estomac perdu fait creuser la faim 1,6 fois plus vite, un rein perdu 1,5 fois la soif. **Le code ne connaît aucun nom d'organe : il additionne ce que le plan lui donne.**

C'est capital pour la suite : la mécanique demandée ci-dessous n'est pas à inventer, elle est à **retourner**. `perdu` dit ce qu'on perd en le perdant ; il manque son symétrique, `donne`, qui dirait ce qu'il apporte tant qu'il est là.

Existent aussi : `SimCadavres.prelever` (on ouvre un corps et on en sort une pièce), les **rangs d'annexes** des points d'attache (un œil greffé se *verrait* : l'ancre est déjà dessinée sur chaque tête), les vingt tissus animaux du catalogue de matériaux (`os`, `tendon`, `cuir`, `suif`, `carapace`, `corne`, `croc`, `ivoire`, `boyau`, `vessie`…), le témoin et la disparition ([[Ordre de travail]] 29 quinquies), les villes-territoires avec leurs stocks et leurs caravanes, et **quatre jauges** sur tout être : PV, vigueur, mana, sang-froid.

---

## 1. Les stats sont la somme des membres et des organes

> [!quote] Le designer, 2026-09-10
> « Et si les stats d'un personnage étaient la somme de ses membres/organes, et si un membre/organe perdu = perte de stats, et si on greffe un organe avec de meilleures stats on devient plus fort ; on peut faire monter des organes sur soi puis les greffer autre part ou les revendre. »

**Ce que ça change :** les stats deviennent des **objets**. Ta Force n'est plus un nombre que tu as monté, c'est *ce qu'il y a dans tes bras*.

**La forme saine** — et c'est un point technique qui a des conséquences de design : ne pas faire les stats *purement* la somme des parties, sinon un corps amputé de tout tombe à zéro et les nombres deviennent absurdes aux extrêmes. **Le plan de corps donne la base, l'organe donne l'écart.** La race reste un socle (elle a déjà `bonus_stats`) et *ton* corps est une déviation de ce socle.

**La spirale de la mort** est le premier danger : si perdre un membre fait perdre des stats, se blesser rend moins bon à ne pas se blesser. L'antidote est dans l'idée elle-même : **la perte ouvre un emplacement**. Un bras arraché n'est pas un malus, c'est un logement vide — plus faible jusqu'à ce qu'on le remplisse, plus fort qu'avant avec une bonne greffe. *La blessure devient la porte d'entrée.*

**« Faire monter des organes sur soi »** est la plus belle partie et la plus dangereuse : à l'usage, le jeu optimal devient *greffer un foie neuf, farmer, revendre le foie monté*. Le frein qui vaut d'être exploré n'est pas un plafond arbitraire : **un organe ne grandit que dans un corps qui le maltraite**. Un cœur monte quand on court, qu'on saigne, qu'on se bat à bas PV ; un foie quand on est empoisonné ; des poumons en altitude ou sous l'eau. On ne farme pas un foie *tranquillement* — il faut vivre dangereusement d'une manière précise, et chaque organe demande alors un style de jeu différent.

**Chaque greffe laisse une trace** — une cicatrice, un point de plafond en moins, un risque de rejet — sinon un organe légendaire circule à l'infini. Un cœur frais et un cœur trois fois transplanté ne sont pas la même marchandise. Avec, en face, une **tolérance du corps** : au-delà d'un seuil, ça rejette, ça pourrit, ça mute — et la monstruosité entre par la porte du système au lieu d'une case à cocher.

**Le problème des PNJ, qu'on oublie toujours :** si les organes sont des stats, chaque villageois est un tas de stats qui marche et un village est un entrepôt. C'est soit le pire (le jeu optimal est d'égorger tout le monde), soit **le meilleur** : la raison de ne pas récolter le village, c'est que le village s'en aperçoit. **Le témoin et la disparition passent d'une jolie idée morale à la contrainte centrale du jeu.**

## 2. Les prix flottent, comme une bourse

> [!quote] Le designer, 2026-09-10
> « Et si tous les prix étaient style bourse ? »

Le prix de Sensen est **déjà calculé** — `valeur_base × qualité × rareté × réputation` ([[Commerce et boutiques]], [[Prix suggéré]]) — il ne sait simplement pas **où il se trouve**. Le passer en bourse, c'est lui ajouter un seul terme : *ce que ce lieu-ci en pense aujourd'hui*.

**On ne simule pas un prix, on le déduit.** Ne jamais stocker un prix : stocker ce qui le cause — et c'est déjà simulé, puisque chaque ville est un territoire avec ses stocks, ses périmètres, son trésor et ses caravanes.

> `prix_ici = prix_objet × f(ce que la ville en a, ce qu'elle produit, ce que la route apporte, ce qui vient d'arriver)`

C'est le motif du dépôt (la pourriture d'un cadavre, la fraîcheur d'une rumeur, l'usure d'un objet) : **ce qui peut se déduire ne se balaie pas.** Ça règle au passage la sauvegarde — sinon il faudrait écrire un prix par bien et par ville, pour des centaines de villes, et le laisser dériver sur cent heures. Et une sécheresse à trois cellules fait monter le pain **toute seule**, sans qu'aucune règle « sécheresse → pain » soit écrite.

**Trois pièges, trois parades qui sont elles-mêmes du jeu :**
- *L'arbitrage bat l'aventure* → **tes propres échanges déplacent le prix** (vendre deux cents fers écroule le fer local : ça s'auto-limite sans plafond inventé) ; les caravanes te font concurrence ; le poids et la route font payer le volume.
- *Un prix qui bouge sans cause lisible se lit comme du bruit* → `sim_rumeur` porte des faits datés qui voyagent : « les mines de X sont noyées » arrive avant ou avec la hausse. Le prix devient **une information qu'on sait lire**, et celui qui écoutait aux tavernes savait avant le marché.
- *Ça taxe le joueur qui ne veut pas commercer* → **le pain et les clous restent ennuyeux** ; seul ce qui est rare, transportable et convoité oscille. Le marché devient facultatif.

**Pas de courbes, pas d'historique de cours.** Spéculer sur de l'information incomplète est un jeu ; spéculer sur un graphique est de l'arithmétique.

**Ce que ça casse :** le portefeuille du marchand (il refuse à sec, se recharge de 15 % par semaine) — un joueur riche assèche une ville en une visite. La parade est le même levier : **une ville qui a dépensé son or paie moins**, et c'est encore un signal de prix.

**Et ça résout l'objection faite aux organes en 1** : pas de cotation, mais **des besoins**. Une peste, et des poumons sains valent une fortune *là, ce mois-ci* ; un culte cherche une fournaise de daemon cette saison ; une guerre, et ce sont les bras qui montent. Vendre un organe cesse d'être « encaisser » pour devenir **trouver qui en a besoin avant quelqu'un d'autre**. La monnaie de Sensen n'est plus l'or, c'est la rareté.

## 3. Le corps en couches — os, peau, tendons

> [!quote] Le designer, 2026-09-10
> « Et si pour les organes/membres on faisait absolument tout, donc tous les os, la peau, les tendons, etc. ? »

**Le piège est dans la formulation** : il y a une différence entre plus de *parties* et plus de *résolution*. Un humanoïde a 24 parties ; un squelette réel en compte 206 rien qu'en os. Les ajouter donne un menu de ciblage inutilisable, un écran d'anatomie qui est un annuaire, et surtout des parties **indiscernables en jeu** — perdre son quatrième métacarpien ne fait rien qu'on puisse nommer. *C'est un nom, pas une mécanique.*

**Des COUCHES, pas des parties.** Une partie cesse d'être une réserve unique : elle est faite de tissus, en profondeur — **peau → chair → tendon/nerf → os → organe**. Une blessure les traverse dans l'ordre, et **c'est l'arme qui décide jusqu'où**. Une lame ouvre la peau et la chair ; une masse ignore la peau et casse l'os ; un pic va au fond ; l'acide mange de l'extérieur.

Chaque couche est mécaniquement distincte, et ça se sent : peau ouverte = ça saigne ; chair déchirée = perte de Force ; **tendon sectionné = le membre est mort mais toujours attaché** (le plus bel état, et il n'existe nulle part) ; os brisé = ça ne porte plus ; organe détruit = mort ou capacité perdue. Les types de dégâts prennent enfin un sens — tranchant, contondant, perforant ne sont plus trois multiplicateurs mais trois façons d'atteindre une profondeur. **L'armure devient une couche de plus**, à l'extérieur de la peau : que la maille arrête la taille mais pas l'écrasement **tombe du système** au lieu d'être écrit.

**L'argument qui emporte le morceau :** les tissus existent déjà, comme **matières d'artisanat** (`os`, `tendon`, `cuir`, `suif`, `carapace`, `écaille`, `corne`, `croc`, `ivoire`, `boyau`, `vessie`…, 20 fiches dans `materials/animal/`). Un corps fait de couches *est* un corps fait de matières premières : le dépeçage cesse d'être une table de butin pour devenir une **lecture du corps**, et la même écaille qui blinde en greffe se tanne en armure. Ça referme d'un coup **dépeçage → matières → artisanat → greffe** sans presque rien inventer.

**Ne pas donner les mêmes tissus à tout le monde** : une gelée n'a pas d'os, un robot a du blindage et des servos. La liste vient du **plan de corps**, déjà par race — donc gratuit.

## 4. Les blessures sont des objets, et elles s'influencent

> [!quote] Le designer, 2026-09-10
> « Et possible que chaque coup, selon le type / ennemi / situation / attaque, attaque des endroits différents de différentes façons, et qu'on puisse voir précisément les dégâts à quel endroit, et qu'un membre puisse être touché à plusieurs endroits différents de différentes manières, et que les blessures différentes affectent les suivantes ? »

**Le geste qui débloque tout : une blessure est un objet, pas une soustraction.** Un membre porte une **liste** de blessures — couche, face, profondeur, type, **tick** — et sa santé se **déduit** de ses blessures au lieu d'être stockée. Encore le motif du dépôt. Bonne nouvelle technique : **47 endroits lisent `sante_partie`, un seul écrit** (`_appliquer_degats`) — on change ce qu'il y a derrière la fonction, pas sa signature.

**« Les blessures affectent les suivantes » devient alors gratuit.** On n'écrit aucune table d'interactions : on donne à une blessure un lieu, une profondeur et une date, et les interactions *apparaissent* —
- un coup dans une plaie ouverte porte plus loin (la peau n'y est plus, l'armure y est fendue) : **viser une blessure devient une tactique sans qu'on ait écrit un bonus** ;
- une brûlure cautérise une entaille qui saigne ;
- un os déjà fêlé casse au coup suivant — un seuil, pas une accumulation ;
- une plaie s'infecte avec le temps et gagne les faces voisines ;
- une cicatrice tient moins bien : **l'histoire d'un corps est écrite dessus**, et ça se voit au prix (§1, §2).

**Le seul endroit où freiner : les « endroits » sur un membre.** Modéliser une position en 2D, c'est des boîtes de collision et une structure spatiale que le joueur ne perçoit pas. **Un membre a trois faces** — extérieur, intérieur, articulation. Deux blessures dans la même face interagissent, dans deux faces différentes non. C'est la ligne entre *faisable* et *projet de recherche*.

**Une attaque cesse d'être un nombre et devient un MOTIF** : combien de plaies, à quelle profondeur, dans quelle couche, sur quelles faces. L'estoc fait une plaie profonde, la taille une longue et peu profonde, la masse un large écrasement, une nuée de crocs huit petites. Ce qui la module existe déjà : l'arme (types de dégâts), le corps de l'attaquant (un quadrupède mord bas, un géant frappe à la tête), la situation ([[Zones de coup par dénivelé]]).

**Trois coûts :** le journal doit dire **la conséquence** et non l'anatomie (« il lâche son épée » vaut mieux que « tendon fléchisseur sectionné ») ; **les blessures fusionnent** (deux entailles proches dans la même face et la même couche deviennent une plaie plus profonde) sinon la liste croît sans fin ; et un être intact ne stocke rien — on écrit l'écart, jamais l'état.

**La profondeur est SUBIE, pas choisie** : le joueur choisit une partie et une arme, la profondeur est la conséquence du jet. Sinon chaque attaque devient un sous-menu. Une exception qui vaut de l'or : **le coup préparé sur une cible immobilisée**, où l'on choisit sa profondeur — ce qui donne à l'assassinat et à la chirurgie exactement la même mécanique.

## 5. La vie est une réserve qui fuit

> [!quote] Le designer, 2026-09-10
> « Et si la vie était la quantité de sang / oxygène, etc. ? » puis « et si le joueur devait gérer les litres de son corps ? »

**N'ajoute aucune jauge : requalifie les quatre qui existent.** Et la mécanique pour qu'une propriété du corps déplace le *plafond* d'une jauge existe aussi — le talent Carapace de l'insectoïde porte `vigueur_max: -15`, et le `perdu` d'un poumon porte `vigueur_max_pct: -25`. **Un organe qui fait ça, c'est le même code.**

- **PV → le sang.** Il ne baisse plus quand on te touche : il baisse **quand tu fuis**. Un coup n'ôte pas de la vie, il **ouvre une fuite**. On ne meurt pas à zéro, on meurt exsangue — et ce n'est pas la même chose, **parce que quelqu'un peut intervenir entre les deux**.
- **Vigueur → le souffle.** Elle l'est déjà à moitié. Les poumons fixent son plafond (déjà vrai), le cœur sa vitesse de retour.
- **Sang-froid → le choc et la douleur.** Ce qui fait trembler les mains, pas une seconde barre de vie.
- **Mana** ne bouge pas.

**Une fuite est un débit et un tick de départ** : le sang à l'instant T se *calcule*. On ne décrémente pas soixante fois par seconde sur chaque villageois — c'est ce qui fait la différence entre une idée magnifique et une idée qui tourne dans une cité de 247 habitants.

**Ce que PV confondait, et qu'on sépare enfin :** *un membre cesse de fonctionner* (structurel, par partie — ce que lisent les 47 lecteurs) et *un corps cesse de vivre* (une réserve). Deux choses qui n'ont rien à voir vivaient dans le même nombre.

**Ce que ça achète, en une phrase : le temps devient la ressource.** Une artère sectionnée n'est pas « −40 PV », c'est **deux minutes** — pendant lesquelles on peut fuir, garrotter, cautériser au feu, ou décider que tuer l'autre d'abord vaut le risque. Et le garrot est l'exemple parfait du §4 : il arrête la fuite **et affame le membre**. Un deuxième compte à rebours démarre : on a gagné du temps contre un bras.

### Les litres : l'unité oui, la comptabilité non

Le dépôt a déjà tranché ça une fois. La colonne `fusion` des matériaux est en **degrés Celsius réels**, avec ce commentaire : *« le champ de chaleur est déjà en degrés, il n'y a donc pas d'unité à inventer »*. Le contre-exemple est juste à côté : la soif est un compteur abstrait dont le `ticks_par_point` a dû être réglé **à la main, deux fois** (30 000 puis 45 000). **Une unité réelle se vérifie ; une échelle inventée se marchande.**

Ce que les litres achètent **au concepteur** : le volume sanguin se déduit de la masse (≈ 7 %), donc de `echelle` et de `carrure` — douze races réglées sans table ; le débit d'une plaie est un volume par minute, mesuré et non choisi ; une outre fait un litre et tout le monde sait ce que ça veut dire ; une transfusion et un prix au litre tombent tout seuls.

Ce qu'ils coûtent **au joueur** s'il doit les gérer : personne n'a envie de faire l'appoint de 0,3 L, personne ne perçoit la différence entre 4,6 et 4,4 L, et l'écran devient un tableau de bord. **Le joueur gère du temps et des conséquences ; le jeu gère des litres.**

**Mais il y a un endroit où les litres se jouent : le joueur gère les litres qu'il TRANSPORTE, pas ceux qu'il CONTIENT.** L'eau qu'on porte dans un désert (le poids existe), l'air d'une pièce qui s'inonde (les niveaux d'eau existent), une dose de poison dans un volume qu'on peut diluer, le sang comme marchandise. Dans tous ces cas le volume est **dehors** : fini, visible, et le choix est net.

> **La règle générale : la profondeur est gratuite tant qu'elle est DÉDUITE ; elle devient chère dès qu'elle est AFFICHÉE ET EXIGÉE.**
> Simule comme un physicien, montre comme un romancier, demande comme un joueur.

---

## La question unique

Les cinq idées n'en font qu'une, et les questions qu'elles posent — l'amputation définitive, le marché lu ou joué, la profondeur choisie ou subie, les jauges ou les symptômes, les litres unité ou tâche — sont **la même question sous cinq angles** :

> [!question] **Le corps est-il un ATELIER qu'on optimise, ou une CHOSE FRAGILE qu'on porte ?**
> · **Atelier** → on collectionne, on greffe, on optimise ; la perte est un coût, pas un drame. *Caves of Qud.*
> · **Chose fragile** → chaque cicatrice se porte, chaque combat coûte durablement, et un membre de rechange est un trésor. *Bloodborne.*
>
> Les données ont déjà à moitié répondu le 2026-09-09 : *« un membre perdu ne repousse pas : c'est la prothèse qui le remplacera, pas le temps »* — c'est-à-dire **définitif pour la chair, remplaçable par autre chose**. Le corps ne guérit pas, il se **recompose**. C'est exactement l'endroit où les deux registres se touchent, et c'est probablement la bonne réponse.

## Si l'on décide de le faire, dans cet ordre

1. **`donne` sur une partie**, symétrique de `perdu` : ce qu'un organe apporte tant qu'il est là. Le résolveur de modificateurs existe, `perdu` prouve le motif — c'est de la donnée et quelques fonctions.
2. **Les besoins sortent du plan de corps** : un robot ne mange pas, il se décharge ; un nautique se dessèche. Ça réutilise les compteurs existants et se sent immédiatement en jeu.
3. **La greffe** : un organe prélevé devient un objet à stats. C'est là que le système d'objets et le système de corps doivent se rencontrer — le vrai morceau.
4. **Les blessures en objets** (couche, face, tick), santé déduite. Fondation du §4 et du §5 ; tout le reste est du contenu par-dessus.
5. **Les motifs d'attaque**, puis les interactions (qui viennent presque gratuitement).
6. **La bourse locale** : un terme de lieu dans le prix, déduit des stocks.

Ce qui n'est **pas** dans cette liste et qui reste le plus cher : **changer le nombre de membres** (quatre bras à l'insectoïde, une queue au nautique, des ailes au daemon). Les points d'attache ont rendu la moitié du chemin facile — un torse dit désormais où pendent ses bras — mais l'autre moitié est du temps de dessin, et c'est lui le goulet.

## Liens
- **Dépend de** : [[Squelette modulaire et points d'attache]], [[Schéma unifié créature-PNJ]], [[Blocs de l'être]]
- **Alimente** : [[Ordre de travail]], [[Décisions en attente]], [[Commerce et boutiques]], [[Matériaux — 13 stats]]
- **Voir aussi** : [[Émergence — les champs partagés]], [[Villes — population, quartiers et économie]], [[Zones de coup par dénivelé]]
