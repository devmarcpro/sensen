---
aliases: ["F.2", "Annexe F.2", "Modules", "Catalogue des modules", "70 modules", "Noyaux", "Formes", "Liaisons", "61 modules"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

> [!success] Refonte en composants — 2026-08-26
> L'ancien catalogue était une liste de **sorts finis** déguisée en système compositionnel : 47 modules sur 47 embarquaient leur propre géométrie, et `forme`, `condition` et `liaison` n'existaient que comme *champs*. Il est remplacé par **70 composants** répartis sur les **six types réels** de [[Six types de modules et assemblage]]. Aucun module n'est un sort. Audit du défaut : [[Décision — Transcription du catalogue de modules]].

Les **70 modules composants** — la charge, la géométrie, l'altération, le verrou, le report et la répétition, chacun séparé des autres.

## Ce qui change, en une ligne

> **Aucun noyau ne porte de forme, aucune forme ne porte de charge.** *Flamme* ne sait pas où elle va ; *Ligne* ne sait pas ce qu'elle transporte. C'est en les mettant côte à côte qu'on obtient un jet de flammes — et la même *Ligne* transporte aussi bien un soin, une poussée ou une invocation.

| | Avant | Maintenant |
|---|---|---|
| Modules | 61 | **70** |
| Types réellement employés | 3 / 6 | **6 / 6** |
| Noyaux embarquant leur géométrie | **47 / 47** | **0 / 24** |
| Capacités de base (noyau × forme) | — | **240**, avant le moindre modificateur |

## Les six types

| Type | Combien | Ce qu'il apporte | Ce qu'il ne fait jamais |
|---|---|---|---|
| **Noyau** | 24 | la charge utile — dégâts, soin, contrôle, déplacement, terrain | choisir où ça tombe |
| **Forme** | 10 | la géométrie sur la grille | décider de la charge |
| **Modificateur** | 14 | altère les paramètres du noyau suivant | agir seul |
| **Condition** | 10 | verrou qui accorde un bonus | agir seul |
| **Déclencheur** | 6 | diffère la charge qui suit | agir seul |
| **Liaison** | 6 | répète, disperse, propage | agir seul |

## Les règles de coût

> **Le noyau porte le coût de base. Tout le reste est un surcoût.**

```
cout_ticks    = cout_ticks(noyau) + Σ surcout_ticks(autres modules)
cout_ressource= cout(noyau) modifié par les surcoûts, dans LA MONNAIE DU NOYAU
```

**La monnaie vient du noyau, pas du contenant** : un noyau élémentaire ou arcane coûte du **mana** ([[Mana]]), un noyau physique (Frappe, Poussée, Empoigne, Élan, Rupture, Désarmement) coûte de l'**endurance** ([[Endurance]]). Les formes, modificateurs, conditions, déclencheurs et liaisons sont **neutres** : leur surcoût s'applique dans la monnaie du noyau qu'ils servent. Une seule règle, aucun doublon de catalogue.

**La séquence entière est UNE action** ([[Six types de modules et assemblage]]) : elle se résout d'un bloc, elle pose **un seul segment de chaîne** ([[Jauge de chaîne Wu Xing]]), et elle coûte une seule fois. Les slots viennent de [[Structure compétences-modules-slots]].

**L'élément** de la capacité dérive du vecteur de ses noyaux ([[Wu Xing — cycles et vecteurs]]). Un *Trait nu* ne pose **aucun** segment : c'est sa contrepartie.

---

## Noyaux — la charge utile (24)

Ils ne portent **ni forme ni portée**. Sans une forme à côté, un noyau vise la case adjacente par défaut.

**Dégâts**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Flamme** | Feu | 2d6 | 8 | 8 | — | `degats` | la charge de Feu |
| **Gel** | Eau | 2d4 | 6 | 6 | — | `degats` | la charge d'Eau — la moins chère, la plus rapide |
| **Ronce** | Bois | 2d6 | 8 | 8 | — | `degats` | la charge de Bois |
| **Éclat** | Métal | 2d8 | 10 | 10 | — | `degats` | la charge de Métal — la plus lourde |
| **Roche** | Terre | 3d4 | 9 | 8 | — | `degats` | la charge de Terre — forte moyenne, faible variance |
| **Trait nu** | Neutre | 1d8 | 5 | 4 | — | `degats` | sans élément : bon marché, mais **ne pose aucun segment de chaîne** |
| **Frappe** | Arme | arme | arme | — | 6 | `degats` | les dégâts de l'arme équipée, à son élément et à son coût en ticks — c'est le noyau de toute capacité de manuel |

**Soin**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Baume** | Neutre | 2d6 | 8 | 10 | — | `soin` | soin instantané |
| **Sève** | Bois | 1d4 | 10 | 14 | — | `soin` · `statut` | 1d4 par tranche de 10 ticks pendant 50 ticks |
| **Purge** | Neutre | — | 7 | 10 | — | `statut` | retire un statut négatif |

**Contrôle**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Entrave** | Neutre | — | 12 | 14 | — | `statut` | immobilise 20 ticks — jet de Force pour briser · budget anti-stunlock |
| **Effroi** | Neutre | — | 11 | 14 | — | `statut` | jet de Volonté ou la cible fuit 20 ticks · budget anti-stunlock |
| **Torpeur** | Neutre | — | 10 | 16 | — | `tempo` | repousse le compteur d'action de 10 ticks · budget anti-stunlock |
| **Empoigne** | Neutre | — | 8 | — | 12 | `saisie` | saisit la cible adjacente : elle libère sa tuile et devient projetable |

**Déplacement**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Poussée** | Neutre | — | 6 | — | 8 | `deplacement` | repousse de 2 tuiles — chute si le vide suit |
| **Attraction** | Neutre | — | 6 | 10 | — | `deplacement` | attire de 2 tuiles |
| **Permutation** | Neutre | — | 8 | 14 | — | `deplacement` | échange sa position avec la cible |
| **Élan** | Neutre | — | 4 | — | 8 | `deplacement` | **le lanceur** se déplace de 3 tuiles |

**Terrain**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Exhaussement** | Terre | — | 12 | 10 | — | `terrain` | élève ou abaisse la tuile d'un niveau ([[Hauteur de terrain ±10]]) |
| **Barrière** | Neutre | — | 14 | 14 | — | `invocation` | occupe la tuile et bloque le passage, 50 ticks |
| **Sol vif** | Neutre | 2d4 | 12 | 12 | — | `terrain` | la tuile blesse ce qui la traverse, 50 ticks |
| **Écho de chair** | Neutre | — | 25 | 28 | — | `invocation` | invoque une créature alliée temporaire — occupe une tuile |

**Technique**

| Noyau | Élément | Dés | Ticks | Mana | Endurance | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Rupture** | Neutre | — | 10 | — | 14 | `statut` | la cible perd 50 % de sa réduction d'armure de zone, 20 ticks |
| **Désarmement** | Neutre | — | 10 | — | 16 | `statut` | jet opposé — l'arme de la cible tombe sur sa tuile |

## Formes — la géométrie (10)

Elles ne portent **aucune charge**. `surcoût` en ticks, `portée` et `taille` de base (modifiables).

| Forme | Surcoût | Portée | Taille | Cibles valides | Ligne de vue | Ce que ça fait |
|---|---|---|---|---|---|---|
| **Point** | 0 t | 1–6 | 1 | ennemi · allié · toute entité | oui | une seule cible — la forme par défaut, gratuite en ticks |
| **Ligne** | +2 t | 1–4 | 4 | tuile · traverse | oui | traverse tout sur 4 tuiles en ligne droite |
| **Cône** | +3 t | 1–3 | 3 | tuile · s'élargit | oui | s'élargit avec la distance, 3 tuiles de profondeur |
| **Croix** | +3 t | 0–5 | 1 | tuile | — | les quatre axes depuis une tuile — ignore la ligne de vue |
| **Carré** | +4 t | 0–5 | 1 | tuile | — | zone pleine de rayon 1, centre compris — **friendly fire intégral** |
| **Anneau** | +3 t | 0–5 | 1 | tuile | — | tout autour d'une tuile, **sans toucher le centre** |
| **Diagonale** | +2 t | 1–4 | 4 | tuile · traverse | oui | les quatre obliques — le complément de la Croix |
| **Chemin** | +2 t | 1–5 | 5 | tuile · trajet | — | suit le trajet du lanceur : tout ce qu'il longe est touché |
| **Soi** | -2 t | soi | — | soi | — | sur soi-même — **rend 2 ticks** |
| **Tuile** | +1 t | 1–5 | 1 | tuile | — | au sol, sans cible vivante — la forme des glyphes et des zones |

## Modificateurs — l'altération (14)

Ils s'accumulent sur le **prochain noyau**. `surcoût ressource` : `+N` est un ajout plat, `×N` un facteur.

| Modificateur | Surcoût ticks | Surcoût ressource | Ce que ça fait |
|---|---|---|---|
| **Allonge** | +1 t | +2 | portée du noyau +2 tuiles |
| **Longue vue** | +2 t | +4 | portée ×2, mais **−1 dé** |
| **Ampleur** | +3 t | ×1.4 | taille de la forme +1 |
| **Focale** | +0 t | 0 | taille de la forme −1, mais **+1 dé** |
| **Concentration** | +2 t | +4 | +1 dé |
| **Surcharge** | +3 t | ×1.5 | +2 dés |
| **Vivacité** | -3 t | ×1.3 | **−3 ticks** — le module du burst |
| **Patience** | +5 t | ×0.6 | **+5 ticks**, coût de ressource réduit de 40 % — le module de l'attrition |
| **Transmutation** | +2 t | +6 | convertit l'élément du noyau vers un élément au choix ([[Wu Xing — cycles et vecteurs]]) |
| **Vampirique** | +2 t | +6 | le lanceur récupère 50 % des dégâts infligés |
| **Perforant** | +2 t | +5 | ignore intégralement la réduction d'armure de zone |
| **Persistance** | +2 t | +6 | toutes les durées du noyau ×2 |
| **Évasement** | +1 t | +3 | transforme une Ligne en Cône, ou un Anneau en Carré |
| **Silencieux** | +2 t | +4 | aucun bruit : ne rompt pas Dissimulé, n'alerte pas les voisins |

## Conditions — les verrous qui paient (10)

> **Une condition n'est pas un bonus gratuit : c'est un pari.** Si le prédicat est vrai, la capacité gagne le bonus. **S'il est faux, elle ne part pas et rend 50 % de ses ticks.** C'est ce qui fait de la position une décision au lieu d'un détail.

| Condition | Prédicat | Bonus si vrai | Ce que ça veut dire |
|---|---|---|---|
| **Surplomb** | `hauteur_relative > 0` | +2 dés | le lanceur est plus haut que la cible |
| **Isolement** | `cible_isolee` | +2 dés | aucun allié adjacent à la cible |
| **Escorte** | `cible_adjacente_a_allie` | +1 dé, +1 taille | la cible touche un de tes alliés |
| **Angle mort** | `dos_ou_flanc` | +3 dés | frappe de dos ou de flanc — le plus gros bonus du jeu |
| **Champ libre** | `ligne_de_vue_degagee` | −2 ticks | rien entre le lanceur et la cible |
| **Dernier souffle** | `pv_porteur < 40 %` | +3 dés | le lanceur est bas |
| **Achèvement** | `pv_cible < 30 %` | +3 dés | la cible est basse |
| **Affinité** | `element_cible = X` | ×1.2 dégâts | la cible porte l'élément désigné |
| **Résonance** | `segment_chaine_present` | +2 dés | le segment désigné est déjà posé dans la jauge ([[Jauge de chaîne Wu Xing]]) |
| **Terroir** | `vecteur_de_lieu = X` | −25 % de ressource | le lieu porte l'élément du noyau ([[Wu Xing hors combat]]) |

## Déclencheurs — le report (6)

Un déclencheur **encapsule tout ce qui le suit** comme charge utile. C'est ce qui permet l'imbrication façon Noita.

| Déclencheur | Surcoût | Ce que ça fait |
|---|---|---|
| **À l'impact** | +1 t | la charge qui suit part quand le noyau précédent touche |
| **Sceau** | +3 t | pose la charge au sol : elle part quand une entité **entre** sur la tuile, jusqu'à 100 ticks |
| **Mèche** | +0 t | la charge part après **N ticks** (10 à 50, réglable à l'assemblage) |
| **Curée** | +2 t | la charge part **à la mise à mort** |
| **Riposte** | +2 t | la charge part **quand le porteur est touché** |
| **Parade** | +2 t | la charge part **quand le porteur pare** ([[Garde en posture]]) |

## Liaisons — la répétition (6)

| Liaison | Surcoût | Ce que ça fait |
|---|---|---|
| **Répétition** | +4 t | rejoue la charge 2 fois, chacune à **−1 dé** |
| **Ricochet** | +3 t | la charge saute à **1d3 cibles proches**, −1 dé par saut |
| **Dispersion** | +3 t | répartit la charge sur **toutes** les cibles de la forme, divisée par leur nombre |
| **Propagation** | +5 t | la charge se propage **de proche en proche** tant qu'elle touche, −1 dé par pas |
| **Alternance** | +2 t | alterne entre les **deux noyaux suivants** à chaque emploi |
| **Écho** | +3 t | rejoue la charge à **50 %** après 20 ticks |

---

## Preuve de couverture — les anciens sorts, reconstruits

Chaque sort fini de l'ancien catalogue se **réécrit** comme une séquence. Aucun contenu perdu, et chaque brique resservira ailleurs.

| Ancien sort fini | Séquence de composants |
|---|---|
| Projectile de feu | `[Ligne]` + `[Flamme]` |
| Nova ardente | `[Carré]` + `[Ampleur]` + `[Flamme]` |
| Mains brûlantes | `[Cône]` + `[Flamme]` |
| Trait de givre | `[Point]` + `[Gel]` + `[Entrave]` |
| Prison de glace | `[Point]` + `[Entrave]` + `[Persistance]` |
| Éclair | `[Point]` + `[Ronce]` + `[Longue vue]` |
| Chaîne | `[Ricochet]` — c'était déjà un composant, il est resté |
| Orage local | `[Carré]` + `[Sol vif]` + `[Persistance]` |
| Pique de pierre | `[Tuile]` + `[Roche]` + `[Perforant]` |
| Peau de pierre | `[Soi]` + `[Baume]`… ou plus juste : `[Soi]` + `[Rupture]` inversée — voir la note ci-dessous |
| Séisme mineur | `[Carré]` + `[Roche]` + `[Poussée]` |
| Soin des eaux | `[Point]` + `[Baume]` |
| Régénération | `[Point]` + `[Sève]` |
| Lien vital | `[Point]` + `[Baume]` + `[Vampirique]` inversé |
| Drain | `[Point]` + `[Flamme]` + `[Vampirique]` |
| Terreur | `[Point]` + `[Effroi]` |
| Contagion | `[Propagation]` |
| Appel corrompu | `[Tuile]` + `[Écho de chair]` |
| Lame spectrale | `[Ligne]` + `[Éclat]` |
| Perforation | `[Point]` + `[Éclat]` + `[Perforant]` |
| Pluie d'aiguilles | `[Carré]` + `[Ampleur]` + `[Éclat]` |
| Mur de lames | `[Tuile]` + `[Barrière]` + `[Sol vif]` |
| Pas éclipsé | `[Soi]` + `[Élan]` + `[Longue vue]` |
| Échange | `[Point]` + `[Permutation]` |
| Marque | `[À l'impact]` |
| Double incantation | `[Répétition]` |
| Balayage | `[Anneau]` + `[Frappe]` |
| Frappe lourde | `[Point]` + `[Frappe]` + `[Concentration]` |
| Fente | `[Point]` + `[Frappe]` + `[Élan]` |
| Exécution | `[Achèvement]` + `[Point]` + `[Frappe]` + `[Surcharge]` |
| Brise-garde | `[Point]` + `[Rupture]` |
| Charge | `[Chemin]` + `[Élan]` + `[Frappe]` + `[Poussée]` |
| Contre | `[Riposte]` + `[Point]` + `[Frappe]` |
| Coups jumeaux | `[Répétition]` |
| Allonge | `[Allonge]` |
| Économie de geste | `[Vivacité]` |
| Impact | `[Point]` + `[Frappe]` + `[Poussée]` |

> [!warning] Trois anciens sorts n'ont **pas** de traduction directe, et c'est voulu
> **Peau de pierre**, **Garde de fer** et **Bouclier arcanique** étaient des *buffs défensifs sur soi*. Il n'existe **aucun noyau défensif** dans ce catalogue — c'est un manque assumé à combler : il faut un noyau `Égide` (réduction plate temporaire) et un noyau `Absorption` (bouclier de PV). **Posés dans [[Ouvert — Noyaux défensifs]].** Les postures, elles, ne sont pas des modules : ce sont des états ([[Garde en posture]]).

## Ce que ça débloque

- **240 capacités de base** avant le moindre modificateur — contre 61 sorts figés.
- **Les formes inutilisées reviennent** : `croix` et `diagonale` n'apparaissaient dans aucun sort de l'ancien catalogue ; elles sont maintenant des modules qu'on trouve et qu'on slotte.
- **Les effets orphelins ont un porteur** : `glyphe` devient le déclencheur *Sceau*, `saisie` devient le noyau *Empoigne*.
- **Les 10 conditions deviennent jouables** : elles n'étaient portées que par un seul sort (Exécution).
- **Le loot redevient intéressant** : trouver `[Angle mort]` change toutes tes capacités d'un coup, au lieu d'ajouter un sort de plus à la liste.

**Schéma :** [[Vocabulaire des modules — six axes]]. **Grammaire d'assemblage :** [[Six types de modules et assemblage]]. **Acquisition :** [[Grimoires et manuels]]. **Slots :** [[Structure compétences-modules-slots]]. **JSON :** `godot/data/modules/*.json`.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Six types de modules et assemblage]], [[Wu Xing — cycles et vecteurs]]
- **Alimente** : [[Structure compétences-modules-slots]], [[Familles de capacités de la grille]], [[Statuts]], [[Prototype de combat — spécification]], [[Grimoires et manuels]]
- **Voir aussi** : [[Décision — Transcription du catalogue de modules]], [[Ouvert — Noyaux défensifs]], [[Mana]], [[Endurance]], [[Boucle de tick]], [[Jauge de chaîne Wu Xing]], [[Armure par zone et constructions]], [[Domaines de grimoires et manuels]]
