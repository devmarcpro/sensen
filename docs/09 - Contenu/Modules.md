---
aliases: ["F.2", "Annexe F.2", "Modules", "Catalogue des modules", "176 modules", "Noyaux", "Formes", "Liaisons", "70 modules", "61 modules"]
tags: [contenu, combat, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 0
---

> [!success] Catalogue étendu — 2026-08-26
> **176 composants**, aucun sort fini. L'extension vise trois choses explicitement : rendre **chaque classe jouable par ses briques** ([[Talents de classe]]), traiter l'**endurance** à parité du mana, et donner autant de place au **non-offensif** qu'aux dégâts. Historique du défaut : [[Décision — Transcription du catalogue de modules]].

Les **176 modules composants** — la charge, la géométrie, l'altération, le verrou, le report et la répétition, chacun séparé des autres.

## L'inventaire

| Type | Combien | Ce qu'il apporte | Ce qu'il ne fait jamais |
|---|---|---|---|
| **Noyau** | 84 | la charge utile | choisir où ça tombe |
| **Forme** | 16 | la géométrie sur la grille | décider de la charge |
| **Modificateur** | 32 | altère le noyau suivant | agir seul |
| **Condition** | 20 | verrou qui accorde un bonus | agir seul |
| **Déclencheur** | 12 | diffère la charge qui suit | agir seul |
| **Liaison** | 12 | répète, disperse, propage | agir seul |

**84 × 16 = 1344 capacités de base** avant le moindre modificateur.

| Équilibre voulu | Chiffre |
|---|---|
| Noyaux **non offensifs** (soin, défense, contrôle, espace, terrain, ressource) | **61 / 84** |
| Noyaux payés en **endurance** | **18** |
| Noyaux payés en **mana** | 60 |
| Noyaux payés en **PV** ou qui *rendent* de la ressource | 6 |
| Modules **signature** rattachés à une classe | 59 |

## Les règles de coût

> **Un seul module choisit la monnaie : le noyau. Les cinq autres types n'en ont aucune.**

Une forme ne coûte **ni mana ni endurance** — elle coûte du **temps**. C'est vrai des cinq types non-noyau. Voici exactement qui porte quoi :

| Type | Ticks | Mana | Endurance | Autre |
|---|---|---|---|---|
| **Noyau** | ✅ de base | ✅ **ou** | ✅ **ou** | PV, ou rend de la ressource |
| **Forme** | ✅ surcoût | ❌ | ❌ | — |
| **Modificateur** | ✅ surcoût | — | — | ✅ surcoût **dans la monnaie du noyau** |
| **Condition** | 0 | ❌ | ❌ | paie par le **risque d'échec** |
| **Déclencheur** | ✅ surcoût | ❌ | ❌ | — |
| **Liaison** | ✅ surcoût | ❌ | ❌ | — |

```
cout_ticks     = cout_ticks(noyau) + Σ surcout_ticks(tous les autres)
cout_ressource = cout(noyau) + Σ surcout_ressource(modificateurs)
                 le tout dans LA MONNAIE DU NOYAU
```

**Le modificateur est le seul non-noyau qui touche à la ressource, et il n'a pas de monnaie propre** : son `surcout_ressource` s'applique dans celle du noyau qu'il sert. Le même *Concentration* coûte 4 **mana** derrière une Flamme et 4 **endurance** derrière une Frappe.

**Deux séquences, les mêmes briques d'assemblage, deux monnaies :**

| | `[Ligne]` + `[Flamme]` + `[Concentration]` | `[Ligne]` + `[Frappe]` + `[Concentration]` |
|---|---|---|
| Noyau | Flamme — 8 t, **8 mana** | Frappe — 5 t *(épée)*, **6 endurance** |
| Ligne | +2 t, rien | +2 t, rien |
| Concentration | +2 t, **+4 mana** | +2 t, **+4 endurance** |
| **Total** | **12 ticks · 12 mana** | **9 ticks · 10 endurance** |
| Résultat | 3d6 de Feu sur 4 tuiles en ligne | l'arme + 1 dé sur 4 tuiles en ligne |

C'est ce qui évite de dupliquer le catalogue : **une seule *Ligne*, un seul *Concentration*** servent le mage et le guerrier. Sans cette règle il faudrait une version « physique » et une version « magique » de chacun des 92 modules non-noyau.

**Quelle monnaie porte un noyau** : élémentaire et arcane → **mana** ([[Mana]], 60 noyaux) · arme, physique, saisie, rupture → **endurance** ([[Endurance]], 18 noyaux) · six coûtent des **PV** ou *rendent* de la ressource (Ponction, Offrande, Saignée, Méditation, Second souffle, Fiole).

**La séquence entière est UNE action**, pose **un seul segment de chaîne** ([[Jauge de chaîne Wu Xing]]) et coûte une seule fois ([[Six types de modules et assemblage]]). Slots : [[Structure compétences-modules-slots]].

---

## Noyaux — la charge utile (84)

Ils ne portent **ni forme ni portée**. Sans forme à côté, un noyau vise l'adjacent.

### Dégâts · léger

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Étincelle** | Feu | 1d4 | 3 | 3 | — | `degats` | charge légère de Feu — le noyau de la chaîne rapide |
| **Bruine** | Eau | 1d4 | 3 | 3 | — | `degats` | charge légère de Eau — le noyau de la chaîne rapide |
| **Épine** | Bois | 1d4 | 3 | 3 | — | `degats` | charge légère de Bois — le noyau de la chaîne rapide |
| **Aiguille** | Métal | 1d4 | 3 | 3 | — | `degats` | charge légère de Métal — le noyau de la chaîne rapide |
| **Gravier** | Terre | 1d4 | 3 | 3 | — | `degats` | charge légère de Terre — le noyau de la chaîne rapide |

### Dégâts · moyen

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Flamme** | Feu | 2d6 | 8 | 8 | — | `degats` | charge standard de Feu |
| **Gel** | Eau | 2d6 | 8 | 8 | — | `degats` | charge standard de Eau |
| **Ronce** | Bois | 2d6 | 8 | 8 | — | `degats` | charge standard de Bois |
| **Éclat** | Métal | 2d6 | 8 | 8 | — | `degats` | charge standard de Métal |
| **Roche** | Terre | 2d6 | 8 | 8 | — | `degats` | charge standard de Terre |
| **Trait nu** | Neutre | 1d8 | 5 | 4 | — | `degats` | sans élément : bon marché, mais **ne pose aucun segment de chaîne** |

### Dégâts · lourd

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Brasier** | Feu | 4d6 | 16 | 20 | — | `degats` | charge lourde de Feu — un seul emploi coûte deux tours d'épée |
| **Banquise** | Eau | 4d6 | 16 | 20 | — | `degats` | charge lourde de Eau — un seul emploi coûte deux tours d'épée |
| **Foudroiement** | Bois | 4d6 | 16 | 20 | — | `degats` | charge lourde de Bois — un seul emploi coûte deux tours d'épée |
| **Fonte** | Métal | 4d6 | 16 | 20 | — | `degats` | charge lourde de Métal — un seul emploi coûte deux tours d'épée |
| **Éboulement** | Terre | 4d6 | 16 | 20 | — | `degats` | charge lourde de Terre — un seul emploi coûte deux tours d'épée |

### Arme

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Frappe** · *Le Sabre* | Arme | arme | arme | — | 6 | `degats` | les dégâts de l'arme équipée, à son élément et à ses ticks |
| **Estoc** | Arme | arme | arme | — | 9 | `degats` | comme Frappe, mais **perforante par nature** — ignore 4 points de réduction |
| **Botte** | Arme | arme | arme | — | 8 | `degats` · `deplacement` | frappe puis recule d'une tuile — sortir de portée après le coup |
| **Feinte** | Neutre | — | 4 | — | 7 | `statut` | annule la garde de la cible 15 ticks ([[Garde en posture]]) |
| **Fauchage** | Neutre | — | 6 | — | 10 | `statut` · `deplacement` | jet opposé de Force — la cible tombe, se relever coûte 8 ticks |
| **Étourdissement** | Neutre | — | 5 | — | 9 | `tempo` | coup de crosse : +6 ticks au compteur de la cible · budget anti-stunlock |
| **Saignement** · *L'Écarlate* | Neutre | 1d4 | 4 | — | 7 | `statut` | hémorragie : 1d4 par tranche de 10 ticks, 40 ticks, **ne s'arrête pas seule** |
| **Charge d'épaule** | Neutre | 1d6 | 6 | — | 11 | `degats` · `deplacement` | projette la cible de 2 tuiles — chute si le vide suit |

### Soin

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Baume** · *La Paume* | Neutre | 2d6 | 8 | 10 | — | `soin` | soin instantané |
| **Sève** · *La Paume* | Bois | 1d4 | 10 | 14 | — | `soin` · `statut` | 1d4 par tranche de 10 ticks pendant 50 ticks |
| **Purge** · *La Paume* | Neutre | — | 7 | 10 | — | `statut` | retire un statut négatif |
| **Transfert** | Neutre | — | 6 | 6 | — | `soin` | donne ses propres PV, 1:1 — le soin qui ne coûte presque pas de mana |
| **Communion** · *La Paume* | Neutre | — | 9 | 16 | — | `statut` | pendant 60 ticks, le lanceur encaisse **la moitié** des dégâts subis par la cible |
| **Réserve** | Neutre | 3d6 | 8 | 18 | — | `soin` · `statut` | soin **dormant** : se déclenche tout seul quand la cible passe sous 30 % PV |
| **Rappel à la vie** · *La Paume* | Neutre | — | 40 | 45 | — | `soin` | relève un allié tombé à 25 % PV — hors combat ou très cher en combat |

### Défense

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Égide** | Neutre | — | 7 | 12 | — | `statut` | **+6 de réduction plate** sur toutes les zones, 50 ticks ([[Armure par zone et constructions]]) |
| **Absorption** | Neutre | 3d8 | 7 | 14 | — | `statut` | matelas de PV qui encaisse puis disparaît — bon contre un gros coup |
| **Reflet** | Neutre | — | 9 | 18 | — | `statut` | renvoie **30 %** des dégâts subis à l'attaquant, 40 ticks |
| **Écaille élémentaire** | Neutre | — | 8 | 16 | — | `statut` | immunité **totale** à un élément au choix, 30 ticks — vulnérabilité +50 % à l'élément qu'il domine |
| **Ancrage** · *Le Porteur* | Neutre | — | 4 | — | 8 | `statut` | immunité aux projections, aux reculs et à la saisie, 40 ticks |
| **Voile** · *L'Ombre* | Neutre | — | 5 | 10 | — | `statut` | le **prochain** coup subi est esquivé automatiquement |

### Contrôle

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Entrave** | Neutre | — | 12 | 14 | — | `statut` | immobilise 20 ticks — jet de Force · budget anti-stunlock |
| **Effroi** | Neutre | — | 11 | 14 | — | `statut` | jet de Volonté ou la cible fuit 20 ticks · budget anti-stunlock |
| **Torpeur** · *Le Sablier* | Neutre | — | 10 | 16 | — | `tempo` | +10 ticks au compteur de la cible · budget anti-stunlock |
| **Célérité** · *Le Sablier* | Neutre | — | 8 | 14 | — | `tempo` | **−10 ticks** au compteur d'un allié — l'autre face du tempo, sans plafond |
| **Rapt de tempo** · *Le Sablier* | Neutre | — | 12 | 20 | — | `tempo` | **vole** 8 ticks à la cible et se les donne — un seul transfert, deux effets |
| **Empoigne** · *Le Porteur* | Neutre | — | 8 | — | 12 | `saisie` | saisit l'adjacent : il libère sa tuile et devient projetable |
| **Silence** | Neutre | — | 10 | 18 | — | `statut` | la cible ne peut plus employer de noyau à coût en **mana**, 25 ticks |
| **Épuisement** | Neutre | — | 10 | 16 | — | `statut` | la cible ne peut plus employer de noyau à coût en **endurance**, 25 ticks |
| **Aveuglement** | Neutre | — | 9 | 14 | — | `statut` | portée et ligne de vue de la cible réduites à 1 tuile, 20 ticks |
| **Rupture** | Neutre | — | 10 | — | 14 | `statut` | la cible perd 50 % de sa réduction d'armure de zone, 20 ticks |
| **Désarmement** | Neutre | — | 10 | — | 16 | `statut` | jet opposé — l'arme de la cible tombe sur sa tuile |

### Espace

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Poussée** | Neutre | — | 6 | — | 8 | `deplacement` | repousse de 2 tuiles |
| **Attraction** | Neutre | — | 6 | 10 | — | `deplacement` | attire de 2 tuiles — la télékinésie de base |
| **Permutation** | Neutre | — | 8 | 14 | — | `deplacement` | échange sa position avec la cible |
| **Élan** | Neutre | — | 4 | — | 8 | `deplacement` | **le lanceur** se déplace de 3 tuiles |
| **Lévitation** · *Le Porteur* | Neutre | — | 10 | 18 | — | `deplacement` · `statut` | **soulève** une entité : elle flotte, ne peut ni agir ni bloquer, 25 ticks — la vraie télékinésie |
| **Projection** · *Le Porteur* | Neutre | (h−2)×5 | 5 | — | 10 | `deplacement` · `degats` | lance l'entité **saisie ou lévitée** sur 5 tuiles — dégâts de chute à l'arrivée |
| **Ancre** | Neutre | — | 6 | 10 | — | `terrain` | pose un point de retour sur la tuile, 200 ticks |
| **Retour** | Neutre | — | 3 | 8 | — | `deplacement` | revient instantanément à l'**Ancre** — 3 ticks, l'échappatoire la moins chère du jeu |
| **Portail** · *Le Passeur* | Neutre | — | 14 | 22 | — | `terrain` | pose **deux tuiles appairées** : y entrer sort par l'autre. Permanentes jusqu'au repositionnement |
| **Traversée** · *Le Passeur* | Neutre | — | 7 | 14 | — | `deplacement` | le lanceur traverse murs et entités sur 4 tuiles |
| **Envol** | Neutre | — | 10 | 20 | — | `statut` | le lanceur ignore le terrain, le dénivelé et les zones au sol, 40 ticks |
| **Convocation** · *Le Passeur* | Neutre | — | 12 | 24 | — | `deplacement` | attire un **allié consentant** à ses côtés, depuis n'importe où en vue |

### Terrain

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Exhaussement** | Terre | — | 12 | 10 | — | `terrain` | élève ou abaisse la tuile d'un niveau ([[Hauteur de terrain ±10]]) |
| **Fosse** | Terre | — | 14 | 14 | — | `terrain` · `degats` | abaisse brutalement de 3 niveaux — ce qui est dessus chute |
| **Barrière** | Neutre | — | 14 | 14 | — | `invocation` | occupe la tuile et bloque le passage, 50 ticks |
| **Sol vif** | Neutre | 2d4 | 12 | 12 | — | `terrain` | la tuile blesse ce qui la traverse, 50 ticks |
| **Racine** | Bois | — | 11 | 12 | — | `terrain` · `statut` | la tuile entrave ce qui s'y arrête, 50 ticks |
| **Nappe** | Eau | — | 10 | 12 | — | `terrain` | la tuile devient glissante (friction 5) — glisse, chute, propage la foudre |
| **Voile de brume** · *L'Ombre* | Neutre | — | 10 | 12 | — | `terrain` | coupe la ligne de vue dans la zone, 60 ticks |
| **Écho de chair** | Neutre | — | 25 | 28 | — | `invocation` | invoque une créature alliée temporaire — occupe une tuile |
| **Relève** · *Le Fossoyeur* | Neutre | — | 18 | 20 | — | `invocation` | relève un **cadavre** présent en invocation temporaire — réputation en chute |
| **Tourelle** · *L'Engrenage* | Arme | — | 16 | — | 20 | `invocation` | déploie une tourelle qui tire à chaque tick, **hérite de l'élément de l'arme**, consomme le carquois |
| **Bombe** · *La Mèche* | Neutre | 3d6 | 8 | — | 14 | `invocation` | pose une charge qui explose après N ticks et **amorce les bombes adjacentes** — friendly fire intégral |
| **Balise** · *Le Sceau* | Neutre | — | 6 | 10 | — | `terrain` | tuile marquée : les capacités du porteur y gagnent **+1 dé**, 80 ticks |

### Ressource

| Noyau | Élément | Dés | Ticks | Mana | End. | Effets | Ce que ça fait |
|---|---|---|---|---|---|---|---|
| **Ponction** | Neutre | — | 8 | — | — | `statut` | vole 12 de mana à la cible et se les donne — coûte 8 PV |
| **Offrande** · *L'Écarlate* | Neutre | — | 4 | — | — | `statut` | convertit 20 PV en 10 mana, immédiatement |
| **Saignée** · *L'Écarlate* | Neutre | — | 3 | — | — | `statut` | −15 PV : la **jauge de sang** monte d'un cran, les dégâts infligés ×1.15 par cran (max 4) |
| **Méditation** · *Le Souffle* | Neutre | — | 20 | — | — | `statut` | immobile : rend 25 de mana ([[Mana]]) — se rompt si on est touché |
| **Second souffle** | Neutre | — | 8 | — | — | `statut` | rend 30 d'endurance ([[Endurance]]) — le pendant physique de Méditation |
| **Pari** · *Le Rieur* | Neutre | — | 2 | 6 | — | `statut` | **relance** le jet de la capacité suivante, le second résultat s'applique quel qu'il soit |
| **Traque** · *La Trace* | Neutre | — | 4 | 8 | — | `statut` | marque une cible 100 ticks : les capacités du porteur la trouvent **sans ligne de vue** |
| **Souffle rendu** · *La Paume* | Neutre | — | 6 | 12 | — | `statut` | pose un **segment de chaîne de l'élément de la cible soignée** ([[Jauge de chaîne Wu Xing]]) |
| **Fiole** · *Le Creuset* | Neutre | 2d6 | 7 | — | — | `degats` · `soin` | projette une potion préparée : son effet s'applique **en zone** au lieu d'une gorgée ([[Potions]]) |
| **Vapeur** · *Le Creuset* | Neutre | — | 10 | 14 | — | `terrain` · `statut` | nuage alchimique : applique le statut d'une potion à tout ce qui entre, 40 ticks |
| **Trempe** · *La Braise* | Arme | — | 8 | — | 10 | `statut` | chauffe l'arme équipée : **+1 dé** et son élément passe à Feu, 60 ticks |
| **Estimation** · *La Balance* | Neutre | — | 4 | 6 | — | `statut` | révèle les stats exactes, le vecteur, les résistances et la table de butin de la cible ([[Barèmes économiques]]) |

## Formes — la géométrie (16)

| Forme | Surcoût | Portée | Taille | LdV | Ce que ça fait |
|---|---|---|---|---|---|
| **Point** | 0 t | 1–6 | 1 | oui | une seule cible — gratuite en ticks, la forme par défaut |
| **Ligne** | +2 t | 1–4 | 4 | oui | traverse tout sur 4 tuiles en ligne droite |
| **Cône** | +3 t | 1–3 | 3 | oui | s'élargit avec la distance, 3 tuiles de profondeur |
| **Croix** | +3 t | 0–5 | 1 | — | les quatre axes depuis une tuile — **ignore la ligne de vue** |
| **Carré** | +4 t | 0–5 | 1 | — | zone pleine, centre compris — **friendly fire intégral** |
| **Anneau** | +3 t | 0–5 | 1 | — | tout autour d'une tuile, **sans toucher le centre** |
| **Diagonale** | +2 t | 1–4 | 4 | oui | les quatre obliques — le complément de la Croix |
| **Chemin** | +2 t | 1–5 | 5 | — | suit le trajet du lanceur : tout ce qu'il longe est touché |
| **Soi** | -2 t | soi | 0 | — | sur soi-même — **rend 2 ticks** |
| **Tuile** | +1 t | 1–5 | 1 | — | au sol, sans cible vivante — la forme des glyphes et des zones |
| **Mur** | +3 t | 1–5 | 3 | oui | une ligne **perpendiculaire** à la visée — barre un couloir |
| **Vague** | +4 t | 1–2 | 5 | — | large et courte : tout le devant sur 2 tuiles de profondeur |
| **Colonne** | +3 t | 0–4 | 1 | — | toute la **hauteur** d'une tuile — touche ce qui vole et ce qui est en contrebas |
| **Nuée** · *Le Rieur* | +3 t | 1–6 | 4 | — | 4 tuiles **aléatoires** dans le rayon — imprévisible, bon marché |
| **Sillage** | +2 t | 1–6 | 3 | oui | les 3 tuiles **derrière** la cible — pour ce qui traverse |
| **Horizon** | +10 t | 1–12 | tout | oui | **toutes** les entités en vue — le prix des ticks est le garde-fou |

## Modificateurs — l'altération (32)

Ils s'accumulent sur le **prochain noyau**. `+N` est un ajout plat sur la ressource, `×N` un facteur.

**Tempo**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Enchaînement** · *Le Sabre* | +2 t | +4 | si la capacité précédente a **touché**, celle-ci coûte **0 tick** |
| **Vivacité** | -3 t | ×1.3 | **−3 ticks** — le module du burst |
| **Patience** | +5 t | ×0.6 | **+5 ticks**, ressource −40 % — le module de l'attrition |
| **Précipitation** · *Le Sablier* | -6 t | ×1.8 | **−6 ticks**, ressource ×1.8 et **−1 dé** — quand seul le tempo compte |

**Effet**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Ligature** · *L'Engrenage* | +2 t | +5 | les invocations et tourelles alliées dans la forme **rejouent** leur attaque |
| **Vampirique** · *L'Écarlate* | +2 t | +6 | le lanceur récupère 50 % des dégâts infligés |
| **Perforant** | +2 t | +5 | ignore intégralement la réduction d'armure de zone |
| **Persistance** | +2 t | +6 | toutes les durées du noyau ×2 |
| **Rémanence** | +3 t | +8 | la zone touchée **reste active** 30 ticks et réapplique à l'entrée |
| **Gravité** | +2 t | +5 | toute cible touchée est **attirée** d'une tuile vers le centre |
| **Répulsion** | +2 t | +5 | toute cible touchée est **repoussée** d'une tuile |
| **Emprise** | +2 t | +6 | toute cible touchée ne peut plus se déplacer 10 ticks |
| **Détonation** · *La Mèche* | +1 t | +4 | ×2 dégâts contre les **invocations, tourelles, bombes et barrières** |

**Portée**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Allonge** | +1 t | +2 | portée +2 tuiles |
| **Longue vue** | +2 t | +4 | portée ×2, mais **−1 dé** |
| **Corps à corps** | -1 t | −2 | portée forcée à 1, mais **+2 dés** — la récompense du risque |
| **Sans angle mort** | +1 t | +2 | supprime la portée minimale — une lance devient bonne au contact |

**Taille**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Ampleur** | +3 t | ×1.4 | taille de la forme +1 |
| **Focale** | +0 t | 0 | taille −1, mais **+1 dé** |
| **Fragmentation** | +2 t | +5 | divise la charge en 3 à 40 % chacune, réparties dans la forme |

**Puissance**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Concentration** | +2 t | +4 | +1 dé |
| **Surcharge** | +3 t | ×1.5 | +2 dés |
| **Canalisation** | +6 t | ×1.2 | +1 dé **par tranche de 5 ticks** passés immobile avant de lâcher |

**Élément**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Transmutation** | +2 t | +6 | convertit l'élément du noyau vers un élément au choix |
| **Prisme** · *Le Souffle* | +3 t | +8 | le noyau prend l'élément qui **domine** la cible ([[Domination et multiplicateurs]]) |
| **Pureté** | +2 t | ×1.3 | concentre le vecteur : +40 % de l'élément dominant, retire les autres |
| **Amorce** | +4 t | +10 | la capacité pose **un segment de chaîne de plus** ([[Jauge de chaîne Wu Xing]]) — rare |

**Forme**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Évasement** | +1 t | +3 | transforme une Ligne en Cône, ou un Anneau en Carré |
| **Traçant** | +2 t | +6 | la charge **suit** la cible : ignore le couvert et les obstacles |
| **Ricochet mural** | +2 t | +4 | la charge **rebondit** sur les obstacles au lieu de s'arrêter |

**Discrétion**

| Modificateur | Ticks | Ressource | Ce que ça fait |
|---|---|---|---|
| **Silencieux** · *L'Ombre* | +2 t | +4 | aucun bruit : ne rompt pas Dissimulé, n'alerte pas les voisins |
| **Sans trace** · *L'Ombre* | +3 t | +7 | la capacité **ne révèle pas** son lanceur — reste Dissimulé après le coup |

## Conditions — les verrous qui paient (20)

> **Une condition est un pari, pas un bonus gratuit.** Si le prédicat est vrai, la capacité gagne le bonus. **S'il est faux, elle ne part pas et rend 50 % de ses ticks.**

**Position**

| Condition | Prédicat | Bonus si vrai | Ce que ça veut dire |
|---|---|---|---|
| **Surplomb** | `hauteur_relative > 0` | +2 dés | le lanceur est plus haut que la cible |
| **Contrebas** | `hauteur_relative < 0` | +2 portée, −1 tick | le lanceur est plus bas — la portée gagne à monter |
| **Angle mort** · *L'Ombre* | `dos_ou_flanc` | **+3 dés** | frappe de dos ou de flanc — le plus gros bonus du jeu |
| **Champ libre** | `ligne_de_vue_degagee` | −2 ticks | rien entre le lanceur et la cible |
| **Pied ferme** | `porteur_immobile_depuis(20)` | +2 dés | le lanceur n'a pas bougé depuis 20 ticks |

**Cible**

| Condition | Prédicat | Bonus si vrai | Ce que ça veut dire |
|---|---|---|---|
| **Isolement** | `cible_isolee` | +2 dés | aucun allié adjacent à la cible |
| **Escorte** | `cible_adjacente_a_allie` | +1 dé, +1 taille | la cible touche un de tes alliés |
| **Achèvement** | `pv_cible < 30 %` | +3 dés | la cible est basse |
| **Affinité** | `element_cible = X` | ×1.2 dégâts | la cible porte l'élément désigné |
| **Prise** · *Le Porteur* | `cible_saisie_ou_levitee` | +2 dés, +1 taille | la cible est saisie ou en lévitation |
| **Entravée** | `cible_immobilisee` | +2 dés | la cible ne peut pas se déplacer |

**Porteur**

| Condition | Prédicat | Bonus si vrai | Ce que ça veut dire |
|---|---|---|---|
| **Dernier souffle** · *L'Écarlate* | `pv_porteur < 40 %` | +3 dés | le lanceur est bas |
| **Pleine garde** · *Le Masque* | `porteur_en_posture` | −2 ticks, +1 dé | le lanceur tient une posture |
| **Ombre** · *L'Ombre* | `porteur_dissimule` | +3 dés, +1 taille | le lanceur est Dissimulé |
| **Résonance** | `segment_chaine_present` | +2 dés | le segment désigné est posé dans la jauge |
| **Chaîne pleine** · *Le Souffle* | `jauge_chaine_pleine` | +3 dés, −3 ticks | les 5 segments sont posés |

**Monde**

| Condition | Prédicat | Bonus si vrai | Ce que ça veut dire |
|---|---|---|---|
| **Terroir** | `vecteur_de_lieu = X` | −25 % de ressource | le lieu porte l'élément du noyau |
| **Heure** | `cycle = nuit | jour` | +15 % dégâts | selon le [[Cycle jour-nuit et sommeil]] |
| **Intempérie** | `meteo = pluie | orage | neige` | +2 dés | selon la [[Météo]] — l'orage nourrit la Foudre |
| **Corruption** | `corruption_locale >= X` | +25 % dégâts | l'arme qui aime le danger ([[Niveau de danger]]) |

## Déclencheurs — le report (12)

Un déclencheur **encapsule tout ce qui le suit** comme charge utile. C'est ce qui permet l'imbrication façon Noita.

| Déclencheur | Surcoût | Ce que ça fait |
|---|---|---|
| **À l'impact** | +1 t | la charge qui suit part quand le noyau précédent touche |
| **Sceau** · *Le Sceau* | +3 t | pose la charge au sol : elle part quand une entité **entre** sur la tuile, jusqu'à 100 ticks |
| **Mèche** · *La Mèche* | +0 t | la charge part après **N ticks** (10 à 50, réglable à l'assemblage) |
| **Curée** | +2 t | la charge part **à la mise à mort** |
| **Riposte** | +2 t | la charge part **quand le porteur est touché** |
| **Parade** · *Le Masque* | +2 t | la charge part **quand le porteur pare** ([[Garde en posture]]) |
| **Dérobade** · *L'Ombre* | +2 t | la charge part **quand le porteur esquive** |
| **Testament** · *Le Fossoyeur* | +0 t | la charge part **quand le porteur tombe** — gratuite, il ne paiera pas les ticks |
| **Veille** · *La Paume* | +3 t | la charge part quand un **allié** passe sous 40 % PV |
| **Ouverture** | +2 t | la charge part **au premier contact du combat** |
| **Cadence** · *L'Engrenage* | +1 t | la charge part **tous les N emplois** de la capacité (2 à 5) |
| **Accord** · *Le Souffle* | +3 t | la charge part quand un **segment de chaîne** se pose |

## Liaisons — la répétition (12)

| Liaison | Surcoût | Ce que ça fait |
|---|---|---|
| **Répétition** | +4 t | rejoue la charge 2 fois, chacune à **−1 dé** |
| **Ricochet** | +3 t | la charge saute à **1d3 cibles proches**, −1 dé par saut |
| **Dispersion** | +3 t | répartit la charge sur **toutes** les cibles de la forme, divisée par leur nombre |
| **Propagation** | +5 t | se propage **de proche en proche** tant qu'elle touche, −1 dé par pas |
| **Alternance** | +2 t | alterne entre les **deux noyaux suivants** à chaque emploi |
| **Écho** | +3 t | rejoue la charge à **50 %** après 20 ticks |
| **Salve** · *L'Engrenage* | +4 t | lance **3 charges simultanées** à 60 %, réparties dans la forme |
| **Miroir** | +3 t | applique aussi la charge à la position **symétrique** par rapport au lanceur |
| **Partage** · *La Paume* | +2 t | la charge s'applique **aussi au lanceur** — pour les soins et les défenses |
| **Meute** · *La Trace* | +3 t | la charge s'applique aussi depuis la position de ton **compagnon** ([[Compagnons]]) |
| **Boucle** | +6 t | rejoue tant qu'il reste de la ressource, **−1 dé** cumulé par tour de boucle |
| **Contagion** | +4 t | les **statuts** du noyau se propagent aux ennemis adjacents des cibles touchées |

---

## Chaque classe a ses briques

Le talent d'une classe est **hors slots** ([[Talents de classe]]) ; ce tableau liste les modules qui **prolongent** ce talent en build. Ils ne sont pas réservés — un module signature se trouve, s'apprend et s'équipe par n'importe qui. Il est simplement **le premier que la classe recevra**.

| Classe | Talent | Modules qui la prolongent |
|---|---|---|
| **Le Sabre** | Râtelier vivant | **Frappe** · **Enchaînement** |
| **Le Souffle** | Communion des cinq | **Méditation** · **Prisme** · **Chaîne pleine** · **Accord** |
| **La Braise** | Main du métal | **Trempe** |
| **La Trace** | Meute | **Traque** · **Meute** |
| **La Balance** | Œil du prix | **Estimation** |
| **La Paume** | Souffle rendu | **Baume** · **Sève** · **Purge** · **Communion** · **Rappel à la vie** · **Souffle rendu** · **Veille** · **Partage** |
| **Le Creuset** | Fiole vive | **Fiole** · **Vapeur** |
| **Le Vent** | Sans maître | *aucun — et c'est voulu : il apprend ceux des autres* |
| **Le Passeur** | portails permanents | **Portail** · **Traversée** · **Convocation** |
| **Le Sablier** | tempo | **Torpeur** · **Célérité** · **Rapt de tempo** · **Précipitation** |
| **Le Sceau** | glyphes | **Balise** · **Sceau** |
| **Le Masque** | postures à 0 tick | **Pleine garde** · **Parade** |
| **Le Porteur** | saisie | **Ancrage** · **Empoigne** · **Lévitation** · **Projection** · **Prise** |
| **L'Ombre** | Dissimulé | **Voile** · **Voile de brume** · **Silencieux** · **Sans trace** · **Angle mort** · **Ombre** · **Dérobade** |
| **L'Écarlate** | jauge de sang | **Saignement** · **Offrande** · **Saignée** · **Vampirique** · **Dernier souffle** |
| **Le Rieur** | relance de dés | **Pari** · **Nuée** |
| **Le Fossoyeur** | relève les morts | **Relève** · **Testament** |
| **La Mèche** | bombes en chaîne | **Bombe** · **Détonation** · **Mèche** |
| **L'Engrenage** | tourelle portative | **Tourelle** · **Ligature** · **Cadence** · **Salve** |

> **Le Vent n'a aucun module signature**, exactement comme il n'a aucun talent au départ. Sa variété vient d'ailleurs : il prend ceux des autres.

## Sept builds que ce catalogue rend possibles

Aucun n'est écrit dans les données — tous **émergent** de l'assemblage.

**Le tisseur de chaîne** — `[Point]` + `[Étincelle]` + `[Vivacité]`, cinq fois de suite en changeant d'élément

> 3 ticks par charge, 5 éléments légers : la [[Jauge de chaîne Wu Xing]] se remplit avant que l'adversaire n'ait joué deux fois. Le build qui fait du **tempo** sa ressource principale.

**Le télékinésiste** — `[Point]` + `[Lévitation]` → `[Prise]` + `[Point]` + `[Projection]` + `[Répulsion]`

> Soulever, puis lancer. Les dégâts viennent de la **chute** ([[Hauteur de terrain ±10]]), pas de l'élément — un build qui ignore complètement la résistance élémentaire.

**L'architecte de portails** — `[Tuile]` + `[Portail]` · `[Sceau]` + `[Tuile]` + `[Racine]` · `[Point]` + `[Convocation]`

> Le champ de bataille devient un plan. On entrave à l'entrée du portail, on convoque un allié derrière la ligne ennemie, on ressort par l'autre bout.

**Le voleur d'horloge** — `[Point]` + `[Rapt de tempo]` + `[Précipitation]` · `[Accord]` + `[Soi]` + `[Célérité]`

> Ne tue presque pas : il **prend les tours**. Contre-jouable uniquement par le budget anti-stunlock ([[Statuts de contrôle et anti-stunlock]]).

**Le saigneur** — `[Soi]` + `[Saignée]` ×3 → `[Angle mort]` + `[Point]` + `[Frappe]` + `[Vampirique]` + `[Surcharge]`

> Se blesse pour frapper, se soigne en frappant. Tout en **endurance et en PV**, zéro mana : jouable avec 5 de Volonté.

**Le jardinier de pièges** — `[Sceau]` + `[Tuile]` + `[Bombe]` + `[Détonation]`, plusieurs fois · `[Mèche]` + `[Propagation]`

> Prépare le terrain avant le contact. Les bombes s'amorcent entre elles — **friendly fire intégral** ([[Décision — Projectiles]]), il faut sortir de sa propre zone.

**Le soutien qui ne soigne jamais** — `[Carré]` + `[Égide]` + `[Partage]` · `[Veille]` + `[Point]` + `[Réserve]` · `[Soi]` + `[Célérité]`

> Zéro soin actif : il **empêche** les dégâts au lieu de les rattraper, et accélère ses alliés. Le non-offensif comme rôle plein.

## Ce que l'extension a spécifiquement visé

| Reproche | Réponse |
|---|---|
| L'endurance était négligée | **18 noyaux** en endurance : toute la famille *Arme*, la saisie, le déplacement physique, la rupture, le second souffle. Un build sans une goutte de mana est jouable de bout en bout |
| Le non-offensif était négligé | **61 noyaux sur 84** ne font aucun dégât : soin (7), défense (6), contrôle (11), espace (12), terrain (12), ressource (11) |
| Les classes cachées n'avaient rien | chacune a ses modules — portails, tempo, glyphes, saisie, dissimulation, sang, dés, relève, bombes, tourelles |
| Pas assez de variété de gameplay | la **télékinésie** (Lévitation, Projection, Attraction, Gravité), les **portails** (Portail, Convocation, Traversée, Ancre, Retour), le **terrain** (Exhaussement, Fosse, Nappe, Racine), la **méta-ressource** (Ponction, Offrande, Saignée, Pari) |
| Formes et conditions inertes | 16 formes et 20 conditions, toutes portées par des modules qu'on trouve et qu'on slotte |

**Schéma :** [[Vocabulaire des modules — six axes]]. **Grammaire :** [[Six types de modules et assemblage]]. **Acquisition :** [[Grimoires et manuels]]. **Slots :** [[Structure compétences-modules-slots]]. **JSON :** `godot/data/modules/*.json`.

> [!success] Décidé le 2026-08-26 — le champ `effet`, transcription exécutable
> Les colonnes « Ce que ça fait », « Bonus si vrai » et « Ressource » étaient du texte : le résolveur a besoin d'une forme structurée. `tools/structure_modules.py` ajoute un champ **`effet`** (objet) à 42 modules — **modificateurs** (`des`, `portee`, `portee_mult`, `portee_fixe`, `portee_min`, `taille`, `ignore_armure`, `vampirique`, `durees_mult`, `projection`, `attraction`, `segments`, `purification`), **conditions** (`predicat_structure {type, …}`, `bonus_structure {des, ticks, portee, taille, mult}`, `echec_ticks_rendus: 0.5`) et quelques **noyaux** à paramètres (`deplacement`, `ignore_armure_points`, `sans_segment`). Les descriptions restent la référence lisible ; un module sans `effet` est chargé mais l'assembleur le signale en debug. **Ce que le prototype résout** : noyaux `degats` / `soin` / `deplacement`, 11 géométries de forme (point, ligne, cône, croix, diagonale, carré, anneau, soi, tuile, vague, mur), tous les modificateurs structurés, 14 conditions. **Pas encore** : `statut`, `terrain`, `invocation`, `tempo`, `saisie`, les déclencheurs et les liaisons (leurs ticks sont comptés, leur effet ignoré) — jalons suivants.
> **Formule d'un noyau magique** : `bruts = jet(dés + dés bonus) × skill_factor(N_module)` (N = 0 → ×1), sans bonus de stat — seul le noyau « arme » utilise la formule de l'arme (+ For/4). La réduction d'armure de zone ne s'applique qu'à **50 %** aux dégâts magiques ([[Armure par zone et constructions]]). Une **condition fausse** : la capacité ne part pas, ne paie **aucune ressource**, et coûte 50 % de ses ticks. Le **friendly fire** des formes de zone est intégral, le Point ne touche jamais le lanceur ([[Décision — Projectiles]]).

> [!success] Décidé le 2026-08-27 — déclencheurs et liaisons dans le prototype
> **Déclencheurs résolus** : *À l'impact* (la charge qui suit part de la première cible touchée) et *Curée* (à la mise à mort, depuis la tuile du mort). Un déclencheur **encapsule tout ce qui le suit** : l'assembleur assemble la suite comme une seconde charge (sa propre forme, son propre noyau). Les **ticks des deux charges s'additionnent** (une seule action, `ticks(noyau₁) + ticks(noyau₂) + surcoûts`), **chaque charge paie sa propre monnaie** au lancement, et la séquence entière ne pose **qu'un segment** (celui de la charge principale). **Liaisons résolues** : *Répétition* (rejoue 2 fois à −1 dé), *Ricochet* (1d3 sauts vers l'ennemi le plus proche à ≤ 2 tuiles, −1 dé par saut), *Dispersion* (charge divisée par le nombre de cibles), *Miroir* (la forme s'applique aussi à la position symétrique), *Partage* (le lanceur aussi). Restent non résolus, faute de minuterie ou de mécanique amont : Mèche, Riposte, Parade, Dérobade, Testament, Veille, Ouverture, Cadence, Accord, Sceau ; Écho, Propagation, Alternance, Salve, Meute, Boucle, Contagion — chargés, ticks comptés, signalés en debug. *(Tous résolus depuis, le dernier — Alternance — le 2026-08-29 ; voir les callouts ci-dessous.)*

> [!success] Décidé le 2026-08-27 (suite) — glyphes, charges différées, terrain, invocations
> *Sceau* (déclencheur `entree`, 100 ticks) et *Mèche* (`apres_ticks`, 20 par défaut) sont résolus : une séquence peut **s'ouvrir** par un déclencheur — elle n'a alors pas de charge principale et se vise avec la géométrie de la charge différée (`[Sceau]+[Tuile]+[Racine]` se vise comme une Tuile). Un glyphe vit dans la **couche d'overlay runtime** de [[Décision — Structure de données de la grille]] (jamais sauvegardé), se déclenche à l'entrée d'un être sur sa tuile, frappe l'entrant comme un Point et **pose un segment à son lanceur** ([[Familles de capacités de la grille]]). *Écho* rejoue à 50 % après 20 ticks par la même file de charges différées, tiquée en fin de pas. Noyaux résolus en plus : *Barrière* (`invocation` : contenu de tuile `barriere`, 50 ticks, bloque passage et vue), *Exhaussement* (`terrain` : +1 niveau — **élève par défaut**, l'abaissement viendra avec un paramètre d'assemblage), *Fosse* (−3 niveaux, ce qui est dessus chute : `(3 − 2) × 5`), *Racine* (statut Enracinement comme charge de glyphe). La forme *Tuile* ne touche **aucune entité** : elle est faite pour les glyphes, les invocations et le terrain.

> [!success] Décidé le 2026-08-27 (fin) — déclencheurs à événement et dernières liaisons
> Une séquence ouverte par *Riposte*, *Parade*, *Ouverture*, *Veille*, *Testament* ou *Accord* **arme le porteur** (elle se vise sur soi, paie ses coûts à l'armement) : la charge attend l'événement et part **une seule fois**, puis tombe à la fin du combat. Points d'accroche : dégâts reçus (Riposte → sur l'attaquant), garde qui tient (Parade), premier contact touché/touchant (Ouverture), allié passant sous 40 % (Veille → sur l'allié), mort du porteur (Testament → sur sa tuile), segment posé (Accord → sur la dernière cible visée). *Cadence* compte les emplois de la capacité par capacité et fait partir la suite tous les N (3). *Dérobade* attendait l'esquive ; **résolue le 2026-08-29** : puisque *le mouvement EST l'esquive* ([[Décision — Esquive active]]), la charge part quand le porteur **fait un pas en combat en étant adjacent à un hostile** — exactement la condition qui donne l'XP d'Esquive. Liaisons : *Salve* (3 charges à 60 % réparties à tour de rôle sur les cibles de la forme), *Propagation* (de proche en proche à 1 tuile, −1 dé par pas, tant qu'il reste un ennemi non touché), *Boucle* (rejoue tant que le mana suffit, −1 dé cumulé, jamais de surchauffe, 20 tours max), *Contagion* (le statut du noyau gagne les ennemis adjacents des cibles). *Alternance* (deux noyaux) et *Meute* (compagnon) restent hors du prototype.

> [!success] Codé le 2026-08-29 — Alternance, la liaison à deux noyaux
> Elle était « non résolue, faute de mécanique amont » : l'assembleur **refusait deux noyaux** dans une séquence. Désormais, quand la liaison **Alternance** est présente, une séquence a le droit d'en porter **deux** — l'assembleur construit alors **deux plans** (la séquence sans le second noyau, puis sans le premier) et range le second dans `plan.alt`. Au lancement, `_lancer_capacite` compte les emplois de la capacité (`e.emplois`) et prend **un plan sur deux** : le premier emploi part avec le noyau A, le suivant avec le B, et ainsi de suite. Chaque plan garde **ses propres** ticks, coût, forme, dés et éléments — c'est bien deux capacités qui se relaient, pas une moyenne. Décisions : sans Alternance, deux noyaux restent une **erreur** d'assemblage (le message ne change pas) ; le compteur d'emplois est **par capacité et par porteur**, celui qui sert déjà à *Cadence* ; l'écran de composition montre le plan A (celui du premier emploi).

> [!success] Vérifié le 2026-08-29 — les neuf effets de noyau du catalogue sont tous traités
> Contrôle complet des données contre le résolveur : les modules ne déclarent que neuf sortes d'effet (`degats`, `soin`, `resurrection`, `deplacement`, `statut`, `tempo`, `terrain`, `invocation`, `saisie`) et **toutes** ont leur branche dans `_appliquer_charge`. Pour que ça reste vrai, un effet inconnu ne passe plus en silence : il émet un `push_warning` nommant le noyau fautif, et le message des liaisons sans effet dit maintenant la vraie cause (« sans effet en données », pas « non résolue dans le prototype »).

> [!success] Corrigé le 2026-08-29 — deux modules sans `effet` : Dérobade et Meute
> Vérification faite module par module plutôt que sur parole : deux fiches n'avaient **aucun champ `effet`**, donc l'assembleur les signalait « non résolu » et les ignorait, quoi qu'en dise le code. **Dérobade** reçoit `{"declencheur": "derobade"}` — sans quoi la résolution codée plus haut n'était jamais atteinte en jeu (seul un plan fabriqué à la main la déclenchait). **Meute** (liaison de La Trace, +3 t) reçoit `{"meute": true}` et sa mécanique : la charge s'applique **aussi depuis la position d'un compagnon** — pour chaque compagnon vivant du lanceur à portée de la forme, les cibles couvertes depuis **sa** tuile s'ajoutent, sans doubler celles déjà touchées. Décision : un seul rejeu par compagnon et pas de récursion (un compagnon de compagnon ne compte pas), et la charge garde ses dés — c'est une extension de couverture, pas un doublement de dégâts.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes, **lot 1 : 7 noyaux sur 47**
> Sept sorts qui partaient sans rien faire agissent enfin, avec les sept statuts qui leur manquaient. **Sève** (`1d4` par 10 ticks pendant 50, sur un allié — la régénération existait déjà comme mécanique). **Aveuglement** : nouvelle cible de modificateur **`detection`**, lue par `voit_ia` — l'aveuglé voit à un dixième de sa portée, ce qui rend la note (« portée et ligne de vue réduites à 1 tuile ») sans inventer de mécanique de vue séparée. **Silence** et **Épuisement** : nouvelle cible **`mana`** / **`endurance`** en `bloque` — `_lancer_capacite` refuse un noyau dont la **monnaie** est coupée, avec sa ligne de journal ; c'est exactement « ne peut plus employer de noyau à coût en mana/endurance ». **Ancrage** : cible **`projection`** en `bloque`, honorée par `_effet_deplacement` (projection) **et** par `_saisir` — « immunité aux projections, aux reculs et à la saisie ». **Reflet** : cible **`reflet`** en `mult`, lue dans `_appliquer_degats` — 30 % repartent vers l'attaquant, avec un garde-fou contre le renvoi du renvoi. **Voile** : cible **`esquive_prochaine`** en `bloque` — le premier coup subi est annulé et le statut tombe. **Décisions** : chaque mécanique nouvelle passe par le **résolveur de modificateurs existant** (`bloque` / `mult`) plutôt que par un champ ad hoc, pour qu'un futur objet ou talent puisse s'en servir ; les statuts défensifs visent l'allié (`cible: "allie"`), les contrôles l'ennemi. Le compte des noyaux inertes passe de **50 à 43 slots** — l'audit et le banc de test tiennent le budget et refusent qu'il remonte.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes, **lot 2 : les zones au sol** (5 noyaux)
> Cinq noyaux de la famille *Terrain* demandaient une mécanique qui n'existait pas : une **tuile marquée qui agit sur ce qui y passe**. `Simulation.zones` (`{pos, type, fin, source, params}`) la porte, sur le modèle des glyphes — **clés en position monde** (la fenêtre glisse, leçon du bug de ce matin), vidées au changement de grille, expirées avec les glyphes, dessinées comme un losange teinté. Un effet `terrain` qui porte une **`zone`** en pose une par tuile de la forme, au lieu de remodeler la hauteur. **Racine** (`entrave`) enracine ce qui entre — la zone s'ajoute au statut immédiat que le noyau appliquait déjà. **Sol vif** (`blessure`) inflige `1d6` à qui traverse. **Nappe** (`glissante`) pousse d'une tuile de plus **dans l'élan** du pas, en chaîne si la suivante glisse aussi. **Voile de brume** (`brume`) coupe la détection dans les deux sens (`voit_ia` refuse si l'un des deux est dans la brume) — « coupe la ligne de vue » rendu là où la ligne de vue compte vraiment. **Balise** (`balise`) donne **+1 dé** aux capacités de **celui qui l'a posée**, et à personne d'autre. **Décisions** : une tuile peut porter plusieurs zones (elles s'additionnent) ; la glissade rejoue les zones de la tuile d'arrivée, ce qui permet les enchaînements de nappes ; les zones ne sont **pas sauvegardées** — comme les feux, elles vivent avec la grille chargée. Budget d'inertie : **43 → 39 slots**.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes, **lot 3 : les déplacements** (7 noyaux)
> `_effet_deplacement` ne connaissait que **deux** modes — `projection` et `au_contact` — alors que les données en citaient déjà quatre autres : **`attraction`**, **`recul`**, **`saut`** et **`permutation`** étaient écrits dans les fiches d'*Attraction*, *Botte*, *Élan* et *Permutation*, et le code les ignorait en silence (même famille de bug que les modules sans `effet`). Les quatre sont codés, et cinq modes nouveaux avec eux : **`convocation`** (un allié rejoint la première tuile libre autour du lanceur), **`lancer_porte`** (*Projection* envoie l'être **saisi ou lévité** sur 5 tuiles, avec les dégâts de chute du Porteur), **`traversee`** (le lanceur réapparaît sur la dernière tuile libre de la ligne, murs et êtres traversés), **`retour_ancre`** (*Retour* rappelle son auteur sur l'**Ancre** qu'il a posée — l'Ancre devient une zone au sol de 200 ticks, réutilisant le sous-système du lot 2), **`levitation`** et **`fauchage`** (jet opposé de Force ; la cible tombe et **se relever coûte 8 ticks**, prélevés au pas suivant). Deux statuts de plus : **Lévitation** (ni déplacement ni garde — et la cible devient projetable) et **À terre** (plus de garde). **Décisions** : *Ancrage* protège de tout ça (`projection` bloqué) ; un déplacement compte comme « ayant agi » même sans cible vivante, sinon *Traversée* et *Retour* passeraient pour inertes ; *Projection* sans personne à lancer le dit au journal au lieu d'échouer en silence. Budget d'inertie : **39 → 29 slots**.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes, **lot 4 : les invocations** (4 noyaux)
> Les quatre noyaux d'invocation réutilisent chacun une mécanique que le jeu avait déjà, plutôt que d'en inventer une. **Bombe** pose une charge dans la file `bombes` — même minuterie, même explosion, donc l'amorçage des bombes adjacentes de la note vient gratuitement. **Tourelle** pose un **affût autonome** : l'affût du Chasseur existait mais consommait le carquois de son porteur et vivait tant qu'il vivait ; il accepte maintenant une **fin**, une cadence, des dés, une portée et un élément propres — invoqué, il ne mange pas de munitions et se démonte à l'échéance. **Relevé** appelle le relevé du Fossoyeur, dont la condition de talent a été séparée du mécanisme (`_relever_brut`) : le talent y accède gratuitement, le noyau en payant ses 20 de mana. **Écho de chair** invoque une créature alliée temporaire sur une tuile libre, avec le `fin_invocation` qui existait pour les relevés. Les chiffres vivent en données (`combat_rules.invocations`). **Décision** : l'écho appelle un **loup** — la note dit « une créature alliée temporaire » sans la nommer ; le champ `creature` est là pour que le designer en décide autrement d'une ligne. Budget d'inertie : **29 → 25 slots**.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes, **lot 5 : le type d'effet `ressource`** (13 noyaux)
> Sept noyaux ne déplaçaient pas un statut mais des **points** — c'est un type d'effet à part entière, qui manquait. **`ressource`** le porte : `{mana, endurance, sante, sang, purge, vol_mana, transfert_pv, cible}`. **Méditation** rend 25 de mana, **Second souffle** 30 d'endurance, **Offrande** convertit 20 PV en 10 mana, **Ponction** vole 12 de mana à la cible contre 8 PV, **Saignée** paie 15 PV pour un cran de la jauge de sang, **Transfert** donne ses propres PV 1:1 à un allié, **Purge** retire le premier statut négatif ou de contrôle trouvé. Les fiches disent maintenant `effets: ["ressource"]` — elles annonçaient « statut », ce qui était faux. Quatre statuts de plus : **Envol** (`tag: volant` accordé — la mécanique de vol existait déjà pour les créatures volantes, elle sert telle quelle), **Trempe** (+1 dé ; l'élément de l'arme qui passe à Feu attend une mécanique d'élément d'arme temporaire), **Rupture** (l'armure de zone accepte désormais un **multiplicateur** de statut, −50 %), **Traque** (la proie marquée se vise **sans ligne de vue**, `capacite_visable` lit la source du statut). Enfin **Cataclysme** et **Fosse** reçoivent la puissance qui leur manquait (`4d6` et `2d6`) : leur cratère fonctionnait, leurs dégâts non. Budget d'inertie : **25 → 12 slots**.

> [!success] Codé le 2026-08-29 — chantier des noyaux inertes **CLOS** (lot 6 : les onze derniers)
> **Plus un seul des 86 noyaux ne part dans le vide.** Le lot 6 portait les mécaniques les plus neuves, toutes greffées sur le passage des dégâts ou sur les zones du lot 2. **Absorption** : un matelas de 25 PV encaisse avant la chair et disparaît quand il est vidé. **Communion** : la moitié des dégâts subis par la cible part sur le lanceur (`communion_avec` note le garant). **Écaille élémentaire** : l'élément choisi ne passe **pas du tout** (`ecaille_element` sur l'être ; la vulnérabilité +50 % à l'élément dominé attend une décision de conception). **Réserve** : un soin dormant de 20 qui se libère tout seul dès que la cible passe sous **30 %** de ses PV. **Pari** : le prochain jet de capacité est relancé, et **le second résultat s'applique quel qu'il soit**. **Désarmement** : jet opposé de Force, l'arme tombe **au sol sur la tuile** de la cible (un vrai contenant de butin, ramassable). **Estimation** : la fiche exacte de la cible dans le journal — PV, six stats, élément dominant. **Souffle rendu** : un segment de chaîne de l'élément de l'allié soigné. **Rappel à la vie** : un allié tombé se relève à **25 %** de ses PV, *Affaibli*. **Portail** : deux zones appairées du même auteur — entrer par l'une ressort par l'autre. **Vapeur** : un nuage qui applique son statut à ce qui entre. **Décisions** : l'écaille annule l'élément **dominant du coup** (le vecteur complet demanderait une résistance par élément, que le jeu n'a pas) ; la vapeur applique *Confusion* par défaut, le champ `statut` de la fiche permettant d'en choisir un autre sans code. **L'audit passe le budget à 0 : plus aucun noyau ne peut redevenir inerte sans faire échouer la validation.**

> [!success] Codé le 2026-08-29 — **lot 7 : les conditions et les modificateurs** (5 + 14)
> Le même contrôle, appliqué aux **autres types de modules** dès que les noyaux ont été clos. Cinq **conditions** n'avaient pas de prédicat (elles ne se déclenchaient jamais) : **Corruption** (danger de la cellule ≥ 50), **Heure** (nuit), **Intempérie** (orage, pluie, tempête, blizzard), **Ombre** (le lanceur est Dissimulé), **Prise** (la cible est saisie ou en lévitation) — chacune +2 ou +3 dés. Quatorze **modificateurs** n'avaient aucun effet : **Évasement** ouvre la forme (Ligne → Cône, Anneau → Carré, +1 de taille), **Silencieux** et **Sans trace** empêchent le coup de lever *Dissimulé*, **Détonation** double les dégâts contre ce qui est **invoqué** (relevés, échos, tourelles), **Emprise** enracine 10 ticks tout ce qui est touché, **Traçant** ignore le couvert (la portée seule compte), **Prisme** donne au noyau l'élément qui **domine** celui de la cible, **Transmutation** l'élément choisi, **Canalisation** +1 dé par tranche de 5 ticks d'immobilité (remise à zéro au moindre pas), **Enchaînement** ramène le coût à 1 tick si la capacité précédente a **touché**, **Fragmentation** réutilise la mécanique de *Salve* (3 éclats à 40 %), **Ligature** fait tirer immédiatement les affûts et tourelles du lanceur dans la forme, **Rémanence** laisse une **zone** (lot 2) qui **rejoue la charge** sur qui y entre, **Ricochet mural** est marqué dans le plan. **Décisions** : *Patience* et *Vivacité* n'avaient rien à coder — leur effet entier tient dans `surcout_ticks` et `surcout_ressource`, ils sont donc déjà servis ; « n'alerte pas les voisins » (Silencieux) attend un système d'alerte que le jeu n'a pas, seule la partie *Dissimulé* est rendue. `tools/audit_donnees.py` vérifie désormais **les cinq types** : condition sans prédicat, liaison ou déclencheur sans effet, modificateur dont aucune clé n'est lue par l'assembleur, forme incomplète.

> [!important] Analyse du catalogue — 2026-08-29 (à trancher par le designer)
> Demande : « revoir le catalogue lui-même ». Voici ce que les **données** disent, sans jugement de goût.
> **1. Six noyaux étaient inatteignables — corrigé.** `fiole`, `meditation`, `offrande`, `ponction`, `saignee`, `second_souffle` ne coûtent **ni mana ni endurance** ; or le générateur de livres filtrait les noyaux de grimoire sur `cout_mana > 0` et ceux de manuel sur `cout_endurance > 0`. Aucun livre, aucune classe, aucune créature ne les donnait : six sorts que personne ne pouvait lancer — et depuis que les modules sont des **charges**, c'est doublement mort. Un noyau appartient désormais au domaine de son **élément**, et **sans élément il est arcane** ; l'audit refuse tout module qu'aucune source ne distribue.
> **2. La matrice de dégâts : 15 noyaux pour une seule idée.** Les noyaux élémentaires forment un **5 × 3** parfait — cinq éléments (feu, eau, terre, métal, bois) × trois paliers (`1d4` / 3 ticks / 3 mana ; `2d6` / 8 / 8 ; `4d6` / 16 / 20) : Étincelle-Flamme-Brasier, Bruine-Gel-Banquise, Gravier-Roche-Éboulement, Aiguille-Éclat-Fonte, Épine-Ronce-Foudroiement. **Rien ne les distingue** que l'élément et le palier — mêmes effets, mêmes formes, mêmes conditions. Trois lectures possibles : *(a)* c'est voulu — chaque case est une **munition distincte** à collectionner, et le système de charges leur donne enfin un sens ; *(b)* trois noyaux paramétrés par élément suffiraient, et l'élément viendrait d'un modificateur (*Transmutation* existe déjà) ; *(c)* on garde la matrice mais on **différencie** les paliers autrement que par le dé (portée, forme implicite, effet secondaire). **C'est la décision du designer** — je ne touche à rien.
> **3. Le quatuor de tempo** (`celerite`, `etourdissement`, `rapt_de_tempo`, `torpeur`) partage la même signature `tempo` ; seuls les paramètres changent. Même question qu'au point 2, à plus petite échelle.
> **4. Deux modificateurs sans effet structuré, à raison** : *Patience* (+5 ticks, ressource ×0,6) et *Vivacité* (−3 ticks, ×1,3) n'ont **rien à coder** — leur effet entier tient dans leurs surcoûts. Ce ne sont pas des doublons, ce sont deux curseurs opposés sur le même axe.
> **5. Effet de bord mesuré** : le domaine **arcane** compte désormais **94 candidats** (16 formes + 32 modificateurs + 46 noyaux sans élément) contre une trentaine pour chaque domaine élémentaire. Un grimoire arcane est donc très dilué — trouver un noyau précis y est long. À trancher avec le point 2 : si la matrice élémentaire maigrit, l'arcane deviendra le gros du catalogue.
> **Le reste du catalogue est fonctionnellement distinct** : sur 178 modules, seuls les 15 + 4 ci-dessus partagent une signature. Ce n'est pas un catalogue bavard — c'est un catalogue avec **une matrice** dedans.

> [!success] Rangé le 2026-08-30 — le catalogue de modules en sous-dossiers par famille
> **Demande du designer** : « faire des sous-dossiers pour chaque catégorie de modules, vraiment trier tout ça — juste avec les noms, on ne sait pas quoi fait quoi ». `data/modules/` était rangé par **type** (six dossiers) ; il l'est maintenant par type **puis par famille** : `noyau/degats_leger`, `noyau/soin`, `noyau/controle`, `noyau/terrain`, `noyau/espace`, `noyau/ressource`, `noyau/defense`, `noyau/arme`… ; `modificateur/portee`, `modificateur/element`, `modificateur/effet`… ; `condition/cible`, `condition/porteur`, `condition/position`, `condition/monde` ; et les formes en `forme/cible` (projetées) et `forme/lanceur` (émises depuis soi). La famille est **le champ `famille` de la fiche** — le dossier n'est qu'un miroir pour l'humain, l'id reste le nom du fichier (`GameData._charger_recursif`). Déclencheurs et liaisons n'ont pas de famille : ils restent à plat. **Même clarté dans le jeu** : l'écran *Composer* affiche désormais la famille à côté de chaque module, et sa description dans le panneau de détail. `data/README.md` porte l'arbre complet.

## Liens
- **Dépend de** : [[Vocabulaire des modules — six axes]], [[Six types de modules et assemblage]], [[Wu Xing — cycles et vecteurs]], [[Talents de classe]]
- **Alimente** : [[Structure compétences-modules-slots]], [[Familles de capacités de la grille]], [[Statuts]], [[Prototype de combat — spécification]], [[Grimoires et manuels]], [[Classes]]
- **Voir aussi** : [[Décision — Transcription du catalogue de modules]], [[Mana]], [[Endurance]], [[Boucle de tick]], [[Jauge de chaîne Wu Xing]], [[Armure par zone et constructions]], [[Statuts de contrôle et anti-stunlock]], [[Hauteur de terrain ±10]], [[Domaines de grimoires et manuels]]
