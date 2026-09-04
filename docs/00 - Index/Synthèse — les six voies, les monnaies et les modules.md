---
aliases: ["Synthèse six voies", "Les six voies et les monnaies"]
tags: [index, production, mesure, ouvert]
domaine: index
statut: ouvert
etape: 10
---

# Synthèse — les six voies, les monnaies et les modules

> [!important] Ce que le designer a demandé
> « Renvoie-moi tout ce qu'on disait par rapport au mana, l'endurance, l'utilisation des 6 stats, la refonte des modules. »

Le fil de la journée du **2026-09-03**, remis dans l'ordre. Ce qui est **fait** est marqué comme tel ;
ce qui est **ouvert** attend une décision. Les chiffres sont relus dans les données, pas de mémoire.

---

## 1. Le point de départ : une seule stat portait tout

`degats_sort` lisait **une seule stat pour tous les sorts** : `volonte`. Un cri de ralliement, une
frappe d'épaule, un tir précis — tout montait sur la volonté. Le système venait pourtant d'acquérir
six voies (une classe, une famille d'armes, une construction d'armure par stat) : **les modules
étaient la seule pièce qui n'y entrait pas, et c'est la plus importante.**

✅ **Fait.** `degats_sort` prend maintenant la stat du noyau (`stat_noyau`). Chaque noyau monte sur
la sienne.

---

## 2. Les six identités (décidées par le designer)

| stat | l'archétype | le critère d'une arme |
|---|---|---|
| force | le guerrier | contact, lourde ou d'impact |
| dextérité | la lame rapide | contact, légère — la vitesse prime |
| endurance | la ligne | contact, **allonge ≥ 2** |
| volonté | le mage | focus de mana |
| perception | le tireur | **projectile, à distance** |
| charisme | le barde | instrument, il soutient les siens |

✅ **Fait.** C'est la décision qui a débloqué tout le reste — et elle est venue dans le bon ordre :
l'identité d'abord, le rangement ensuite.

---

## 3. Les armes : 36, six par voie

✅ **Fait.** Avant, le catalogue ne suivait pas les identités : la dextérité tenait **tout le tir du
jeu**, la lance était sous la force malgré son allonge de 2,5, et la perception avait un stylet
d'allonge 1.

```
force       épée, sabre, hache d'armes, masse, marteau de guerre, mains nues
dextérité   dague, stylet, rapière, couteau de jet, hachette de jet, javelot
endurance   lance, bâton, hallebarde, pavois, fléau, fouet
volonté     bâton magique, baguette, orbe, sceptre, talisman, grimoire de main
perception  arc, arc long, arbalète, fronde, pistolet, sarbacane
charisme    flûte, cor, cymbales, luth, tambour, vielle
```

Les six instruments du charisme se lisent sur **une seule échelle** — plus un instrument s'engage
dans l'endurance, moins il sert au mana : flûte 1,05/1,20 · cor 0,90/1,25 · cymbales 0,75/1,35 ·
luth 0,85/1,45 · tambour 0,70/1,65 · vielle 0,55/1,85.

---

## 4. Les modules : le tri est fait, le déséquilibre reste

✅ **Fait — le tri du charisme.** Les sorts de buff, débuff et invocation **existaient déjà** : ils
étaient tous rangés sous la volonté. Il n'y avait rien à écrire, il y avait à trier. Le critère :
*le charisme agit sur l'esprit d'autrui ou rallie les siens ; la volonté agit sur la matière et
l'énergie.* Un effroi fait fuir — charisme. Une entrave immobilise avec des racines — volonté.

Quinze noyaux déplacés : effroi, torpeur, silence, épuisement, marque (on brise le moral) · célérité,
égide, communion, transfert, réserve (on soutient les siens) · convocation, rappel à la vie,
renaissance (on appelle) · pari, offrande (déjà là).

⚠️ **Ouvert — la répartition reste très inégale :**

| stat | noyaux | monnaie |
|---|---|---|
| volonté | **57** | 52 mana, 5 gratuits |
| charisme | 15 | 14 mana, 1 gratuit |
| force | 8 | 8 endurance |
| dextérité | 6 | 6 endurance |
| endurance | 4 | 4 endurance |
| perception | **2** | 2 mana |

La sonde signale désormais toute voie de moins de trois noyaux — un seuil bas, qui dénonce une voie
**vide**, pas une voie moins fournie : l'écart entre les six est une question d'équilibrage, pas de
sonde. **La perception et l'endurance sont les deux voies à écrire.** Elles n'ont pas d'équivalent
naturel dans un catalogue rédigé avant que les six voies existent.

⚠️ **Ouvert — l'élément comme module.** Mesuré : 15 des 16 noyaux de dégâts sont un produit croisé
5 éléments × 3 puissances. `transmutation` convertit déjà l'élément d'un noyau, mais codé en dur sur
le feu. 14 des 19 classes nomment un noyau élémentaire, 28 références à réécrire. Le designer a dit
« il faut qu'on en discute » — rien n'est engagé.

---

## 5. Le mana et l'endurance : ce que la mesure dit

C'est le cœur de la question ouverte. Deux faits que personne n'avait mis côte à côte :

> [!warning] Les réserves n'appartiennent qu'à une stat et demie
> `mana_max = 20 + volonté × 3` · `santé_max = 20 + endurance × 4` — mais l'endurance-**la-monnaie**
> a un `max: 100` **fixe**. Investir dans la stat endurance n'agrandit pas la barre d'endurance : ça
> agrandit les PV. **Quatre stats sur six n'agrandissent aucune réserve.**

> [!warning] La volonté se suffit à elle-même
> 52 des 68 noyaux à mana sont des noyaux de volonté. Elle **remplit** la barre et elle la **vide** :
> c'est la seule stat du jeu qui n'a besoin de personne. Le vrai déséquilibre n'est pas le nombre de
> modules — c'est celui-là.

Et les deux monnaies ne sont pas deux seaux, ce sont **deux comportements** :

| | ce que ça limite | l'horizon | régénération |
|---|---|---|---|
| endurance | ton **rythme** dans un échange | quelques ticks | 2 / tick |
| mana | ton **budget** de coups forts | un étage entier | ~0,0125 / tick — **160× plus lent** |

Dépenser à vide n'est pas refusé : c'est la **surchauffe** (déficit × 2 en PV) pour le mana, et
l'**épuisement** (× 1) pour l'endurance.

---

## 6. Les trois solutions posées sur la table

### A — Trois monnaies, deux stats chacune

Une monnaie n'appartient pas à une stat, elle en **lie deux** : l'une la **remplit** (taille de la
barre), l'autre la **dépense bien** (puissance).

| monnaie | remplit | dépense | le style |
|---|---|---|---|
| vigueur | endurance | force | le corps |
| mana | volonté | perception | l'esprit |
| **élan** (nouveau) | dextérité | charisme | la présence |

L'élan **part à zéro** à chaque combat et ne se régénère pas : il se **gagne en agissant** et retombe
hors combat. Il ne dit pas *combien*, il dit **quand** — un joueur charisme doit mériter son
ouverture. Formules proposées : `vigueur_max = 60 + endurance × 4` (contre 100 fixe aujourd'hui),
`elan_max = 20 + dextérité × 2`.

*Pour :* une boucle active, un vrai troisième comportement. *Contre :* une quatrième barre à l'écran,
et tout le monde est forcé de monter deux stats.

### B — Aucune monnaie nouvelle : chaque stat desserre une rareté qui existe déjà

Le postulat de A est peut-être faux. Ce qui définit un style, ce n'est pas ce qu'on dépense, c'est
**la contrainte contre laquelle on joue** — et le jeu en simule déjà six.

| stat | la rareté | l'état du code |
|---|---|---|
| endurance | les PV | `sante_max_par_endurance: 4` ✅ |
| volonté | le mana | `mana_max_par_volonte: 3` ✅ |
| force | le poids porté | `poids.par_force: 5` ✅ **existe déjà** |
| charisme | le nombre (escorte, invocations) | `compagnons.par_charisme: 5` ✅ **existe déjà** |
| dextérité | le temps (ticks par action) | partiel, via `vitesse_base` |
| perception | la portée et l'information | `vision` quasi vide — **à écrire** |

**Quatre des six étaient déjà écrites.** Personne ne les avait mises côte à côte.

*Pour :* aucune barre de plus, personne n'est forcé de s'appairer, et le travail restant est du
contenu, pas de la plomberie. *Contre :* la force et la perception restent **passives** — elles
élargissent ce qu'on peut faire, elles ne donnent pas un rythme à jouer.

### C — Une seule monnaie (le qi)

Mana et endurance fusionnent ; les six stats diffèrent par leur **taux de change** (la force convertit
en dégâts, la dextérité en actions, la perception en fiabilité…). Très propre, très 森森, et ça
supprime l'absurdité actuelle du mage qui ne se bat pas. Mais ça détruit les **deux horizons** — le
rythme et le budget — et c'est la refonte la plus chère des trois.

### La recommandation

**B, avec un morceau de A greffé dessus.** B comme squelette ; puis l'élan **uniquement pour le
charisme** — c'est la seule voie dont la rareté (« combien de corps alliés ») n'a aucun rythme de
combat, et c'est aussi celle qui vient d'hériter des 15 noyaux de buff/débuff/invocation. La jauge
n'apparaît que si des noyaux de charisme sont équipés. Six terrains distincts pour presque rien, et
**une** mécanique neuve là où elle manque vraiment.

---

## 7. Ce qui attend une décision

1. **Quelle solution** — A, B, C, ou B+élan.
2. **Dans le couple mana : qui remplit, qui dépense ?** Rien n'oblige la volonté à être la réserve.
   La perception peut se lire comme celle qui a les réserves (elle voit le flux) et la volonté comme
   celle qui impose. Le tableau de A est le choix conservateur : il ne touche pas `mana_max`.
3. **Que deviennent les PV ?** Si l'endurance remplit la vigueur, lui laisse-t-on *encore*
   `santé_max` ? Lui laisser les deux la rend très forte ; la lui retirer laisse les PV orphelins ;
   une troisième voie les donne à la force.
4. **Les 52 noyaux de volonté.** *(Codé depuis 2026-09-04 : vingt noyaux martiaux de plus — force 13, dextérité 12, endurance 11, perception 12 ; voir « Douze façons de jouer par voie » dans Structure compétences-modules-slots.)* Aucune monnaie ne rééquilibre quoi que ce soit tant que les trois
   quarts du catalogue tiennent sur une voie. C'est le vrai travail ; la monnaie n'est que le cadre
   qui dit où ranger.
5. **L'élément comme module** (§4).
6. **Le coût caché chiffré tard :** les six instruments du charisme sont des focus de la monnaie
   **endurance**. Si l'élan passe, leurs six `affinite_sorts` doivent basculer d'un bloc — sinon le
   charisme paie dans la barre de l'endurance et les deux voies se marchent dessus.

## Liens

- [[Structure compétences-modules-slots]] — les callouts datés du tri et du rangement des armes
- [[À juger — parcours de jeu]] — les questions ouvertes, dont les monnaies
- [[Audit d'équilibrage — 2026-09-03]] — l'état mesuré du jeu
- [[Mana]] · [[Endurance]] — les deux monnaies telles qu'elles existent aujourd'hui
