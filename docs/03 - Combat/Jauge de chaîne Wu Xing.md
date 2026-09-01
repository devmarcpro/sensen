---
aliases: ["A.4.6 jauge", "Jauge de chaîne", "Chaîne Wu Xing", "Jauge"]
tags: [combat, wuxing, formule, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le cœur du combat : une barre de 5 segments dont le dernier acte résout et reçoit tout le bonus accumulé.

Extrait intégral de [[Domination et multiplicateurs]] (A.4.6) :

```
JAUGE DE CHAÎNE — 5 SEGMENTS DE BASE, EXTENSIBLE JUSQU'À 10 :
  Barre visible en permanence (pastilles colorées sous le réticule).
  Capacité +1 par : affixe rare (loot only) · maîtrise dédiée
  (tous les 25 niveaux) · amulette exceptionnelle.
  UNIVERSELLE — remplissent un segment : tout module lancé, et tout
  COUP D'ARME QUI TOUCHE (jamais un swing dans le vide).
  Le 5e (ou Ne) acte RÉSOUT : il reçoit tout le bonus accumulé,
  puis la barre retombe à 0.
  BONUS PAR TRANSITION (accumulés, appliqués au résolveur) :
    même élément que le précédent        : +0.10
    élément différent, hors ordre        : +0.20
    élément différent suivant l'engendrement : +0.35
  Répéter est permis mais CONSOMME UNE PLACE : faire plus d'un coup
  d'un même élément rend la chaîne complète mathématiquement
  impossible. Contrainte STRUCTURELLE, aucune interdiction écrite.
  DEUX VOIES ÉQUIVALENTES :
    rotation parfaite  : 4 × 0.35 = +1.40 → résolveur x2.40
    construction/détonation : 4 coups rapides d'un élément puis une
      frappe lourde engendrée = +0.65 → x1.65 sur une base bien
      supérieure. Placer sa plus grosse frappe en dernier est la
      stratégie centrale du système.
  GAIN INTERMÉDIAIRE : +5 % de dégâts élémentaires par segment
    présent dans la barre — remplir n'est jamais inerte.
  DÉCROISSANCE : un segment se vide tous les 30 TICKS écoulés (le
    dernier posé en premier) — mesurée en ticks, elle est
    DÉTERMINISTE et CALCULABLE par le joueur, ce qui est tout
    l'intérêt du tactique. C'est une cadence, pas un stock.
  RÉSOLVEUR NON OFFENSIF : un buff/soin en position finale résout et
    reçoit le bonus sur sa DURÉE ET SA MAGNITUDE, à 0.7× (compense
    l'absence de risque : un buff se lance à distance). Les builds
    de soutien ont un accès plein au système central.
  RISQUE PROPORTIONNEL : une chaîne longue coûte plus de ticks à
    charger et s'expose davantage à la décroissance. Étendre sa
    jauge est un pari, pas un bonus gratuit.
  ARBITRAGE CENTRAL DU COMBAT : enchaîner avec la même arme (0 tick
    de swap, +0.10) ou payer 4 ticks pour changer d'élément (+0.35).
    Le swap doit être rentable DANS CERTAINS CAS SEULEMENT — si la
    réponse est toujours la même, les chiffres sont à revoir.
```

**Règle d'application ([[Six types de modules et assemblage]]) :** *une capacité qui touche pose **UN** segment de chaîne, quel que soit le nombre de cibles.*

**Multi-ennemis ([[Trous connus du combat]]) :** la jauge se remplit d'**un segment par ATTAQUE, jamais par cible touchée** (sinon les groupes deviennent des générateurs de chaîne triviaux — l'XP, elle, se somme par cible). Voir [[Décision — Multi-ennemis et jauge]].

**Glyphes positionnels ([[Familles de capacités de la grille]]) :** un glyphe élémentaire **pose un segment de chaîne** en se déclenchant — le Wu Xing devient positionnel.

**Extension de capacité :** affixe rare « +1 segment de chaîne » ([[Loot — affixes, gemmes et rareté]]).

**Formule complète de dégâts (avec le bonus de chaîne) :** [[Domination et multiplicateurs]].

**Question ouverte :** [[Décision — Chaîne côté ennemis]].

> [!success] Décidé le 2026-08-26 — ce que le code a fixé
> - **Qui porte une jauge** : tout être dont la fiche a `chain_gauge: true` — l'aventurier du prototype (`creatures/aventurier.json`) comme le chef de bande. Même objet, même règles, zéro test de contrôle ([[Décision — Chaîne côté ennemis]]).
> - **Décroissance déterministe** : la jauge mémorise le tick de la dernière pose ; à chaque lecture (attaque, prévisualisation) on retire un segment par tranche de 30 ticks écoulés, le dernier posé en premier. Aucun timer : c'est calculable par le joueur, et ça ne coûte rien par tick.
> - **Le résolveur** est le coup qui pose le segment n° `capacité` : il reçoit `× (1 + Σ bonus de transition)` **en comptant sa propre transition** (rotation parfaite = 4 transitions × 0.35 → ×2.40), et la barre retombe à 0 sans le stocker. Le **gain intermédiaire** (+5 % par segment présent *avant* le coup) s'applique à toute attaque qui porte un élément.
> - **Ce qui pose un segment** : un coup d'arme qui touche, une action de créature qui touche au moins une cible (une seule pose quel que soit le nombre de cibles), et — jalon 8 — tout module lancé. Un coup dans le vide (cible dérobée à l'échéance d'une lourde) ne pose rien.
> - **Prévisualisation** : au survol, l'UI montre l'élément contre l'alignement de la cible et son ×, le remplissage de la jauge, et pour le coup envisagé sa position, sa transition et le multiplicateur s'il résout.

> [!warning] Premier réglage le 2026-08-27 — « on ajustera plus tard »
> Balayage de 48 jeux de valeurs avec `test_criteres` (dégâts moyens, vraies données) : **aucun** jeu de bonus de transition ne ramène les deux voies à ±15 %, parce que l'écart ne vient pas des transitions mais des **bases** — la lourde ×2.2 sur une masse (construction lourde : +30 % au-dessus de la rotation) et la dague à 1d6 (construction légère : −40 % en dessous). La rotation se place entre les deux. Valeurs retenues en attendant le playtest : **engendrement +0.45** (au lieu de +0.35 ; rotation ×2.80), même élément +0.10 et hors ordre +0.20 inchangés, **swap d'arme 3 ticks** (au lieu de 4 — [[Boucle de tick]]) : avec 3 ticks le swap devient rentable pour dague→épée lourde et reste perdant pour épée→masse→épée, ce qui est exactement « dans certains cas seulement ». Le critère « ±15 % » devra préciser ce qu'est la *construction* de référence (arme légère → lourde de l'élément engendré, avec quelle arme) avant d'être rejugé — [[Vers la production]].

> [!success] Décidé et codé le 2026-09-01 — l'élément suivant clignote (designer, point 60)
> La jauge disait ce qui était **posé**, jamais ce qu'il fallait poser **ensuite** : le joueur devait connaître le cycle par cœur pour enchaîner. Le pentagramme du HUD fait maintenant **clignoter le sommet de l'élément engendré** par le dernier segment — un halo qui pulse, à la teinte de l'élément, doublé d'une flèche depuis le segment courant. Il ne clignote que si la chaîne est ouverte et non pleine : quand il n'y a plus rien à enchaîner, l'indication s'éteint d'elle-même.
>
> Deux chiffres en données (`wuxing.clignotement` : période et amplitude) ; aucune règle de combat ne change, c'est une aide de lecture.

## Liens
- **Dépend de** : [[Wu Xing — cycles et vecteurs]], [[Domination et multiplicateurs]], [[Action-time à ticks]]
- **Alimente** : [[XP de combat]], [[Cinq accès au cycle]], [[Attaque lourde et télégraphe]]
- **Voir aussi** : [[Modificateurs d'affinité]], [[Armes fantomatiques]], [[Loot — affixes, gemmes et rareté]], [[Familles de capacités de la grille]], [[Décision — Multi-ennemis et jauge]], [[Décision — Chaîne côté ennemis]]
