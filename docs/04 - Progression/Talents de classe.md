---
aliases: ["Talents de classe", "Talent de classe", "Classes cachées", "Passeur", "Capacité de classe", "Jauge de classe"]
tags: [progression, combat, décidé]
domaine: progression
statut: décidé
etape: 4
---

> [!warning] Amende une décision écrite
> Le GDD disait : *« Classe : détermine **uniquement** des bonus de stats/équipement de départ »* ([[Création de personnage]]). **Amendé le 2026-08-26** : chaque classe porte un talent qui définit une façon de jouer — justifié par **ToME** ([[Piliers d'inspiration]]), où les classes ont une mécanique définissante dès le début et où le build émerge *à l'intérieur* de cette identité.

Un talent de classe est **actif** : une capacité qu'on emploie. **15 classes** — 6 visibles, 9 cachées.

## Le mécanisme

**Un talent de classe est une capacité hors slots** : un module ([[Vocabulaire des modules — six axes]]) qui n'occupe **aucun emplacement** de [[Structure compétences-modules-slots]] et n'a pas besoin d'être trouvé. Il monte par l'usage ([[Progression par l'usage]]).

> **Le talent est un plancher, pas une cage.** Tous les slots restent libres pour ce qu'on ramasse — le build émerge par-dessus une identité, au lieu d'émerger de rien.

**Certains talents portent une jauge de classe** — une barre propre à la classe, lue et remplie par ses propres règles, calquée sur la [[Jauge de chaîne Wu Xing]] (même objet de code, autres conditions de remplissage). C'est le mécanisme générique qui évite d'écrire une exception par classe.

## Les six visibles

| Classe | Talent | Ce que ça change |
|---|---|---|
| **Le Sabre** | *Râtelier vivant* — une fois par chaîne, **changer d'arme coûte 0 tick** | mord sur l'arbitrage central du combat ([[Jauge de chaîne Wu Xing]] : +0.10 en restant, +0.35 en payant 4 ticks). Le Sabre s'offre la rotation parfaite que les autres ne peuvent pas |
| **Le Souffle** | *Communion des cinq* — possède le module d'office, hors slot : **l'élément de son arme tourne seul** dans le cycle ([[Cinq accès au cycle]]) | accès permanent au cycle sans arsenal ni or |
| **La Braise** | *Main du métal* — **reforge** un objet looté : remplacer un composant ([[Craft compositionnel]]) **sans perdre ses affixes** | l'atelier n'invente toujours pas d'affixes ([[Loot — affixes, gemmes et rareté]] : *loot-only*), mais il en change le support. Le loot mort disparaît |
| **La Trace** | *Meute* — **son compagnon partage sa jauge de chaîne** : les coups du compagnon posent des segments ([[Compagnons]]) | deux corps, une chaîne — le seul build qui construit sa rotation à deux |
| **La Balance** | *Œil du prix* — voit le **portefeuille réel** et le prix d'acceptation de chaque PNJ ([[Barèmes économiques]]) ; +1 place d'escorte | le commerce devient de l'information au lieu du tâtonnement |
| **Le Vent** | *Sans maître* — commence **sans talent**, mais peut en apprendre un auprès de n'importe quel maître — **et en changer** | le seul qui goûte à tout, jamais le meilleur nulle part |

## Les neuf cachées

**Elles ne sont pas au menu : elles s'apprennent d'un PNJ qui les porte.** Puisque chaque PNJ a une classe ([[Les trois axes — race, classe, fonction]]), un Passeur existe quelque part — le trouver *est* le déblocage. Mécanisme existant : **enseignement à relation ≥ 75** ([[L'information comme récompense]]).

| Classe | Talent | Contrepartie | Source |
|---|---|---|---|
| **Le Passeur** | **deux tuiles appairées permanentes** — portails hors slot, sans mana d'entretien, repositionnables ([[Familles de capacités de la grille]]) | mana max **−30 %** : le corps paie la brèche en permanence | *Éliotrope* |
| **Le Sablier** | effet **`tempo`** ([[Vocabulaire des modules — six axes]]) : retarde le compteur d'un ennemi, avance le sien, vole du tempo | chaque emploi coûte **de la santé** (le temps se paie en soi) ; plafonné par l'anti-stunlock | *Xelor* |
| **Le Sceau** | grave des **glyphes** persistants, plusieurs simultanés, qu'il déclenche à distance | ses glyphes coûtent 2× en mana ; **immobile pendant la gravure** (canalisation visible) | *Feca* |
| **Le Masque** | change de **posture** instantanément (0 tick) en changeant de masque — cumule les bonus de deux postures | ne peut pas prendre la garde ([[Garde en posture]]) : le masque occupe la main secondaire | *Zobal* |
| **Le Porteur** | effet **`saisie`** : saisit une entité adjacente et la **lance** — alliés compris | pendant la saisie, ne peut ni attaquer ni se garder ; la cible saisie peut se débattre (jet de Force) | *Pandawa* |
| **L'Ombre** | statut **Dissimulé** hors combat et après chaque mise à mort ; ses pièges ne sont pas visibles | dégâts **−25 %** en attaque frontale : il ne vaut que par le dos et le flanc | *Sram* |
| **L'Écarlate** | **jauge de sang** : les dégâts subis la remplissent, elle multiplie les dégâts infligés (jusqu'à ×1.8 pleine) | la jauge se vide en **soignant** — il doit choisir entre survivre et frapper | *Sacrieur* |
| **Le Rieur** | **relance** un jet de dés par combat ([[Pipeline de résolution du combat]]) ; ses critiques s'étendent (19-20) | les échecs critiques s'étendent aussi (1-2) — il joue sur les deux queues | *Ecaflip* |
| **Le Fossoyeur** | relève les cadavres du champ de bataille en **invocations temporaires** (occupent une tuile) | réputation en chute continue dans toute zone civilisée ([[Réputation et relations]]) | — |

*(Le **Meneur** — invocateur permanent à la Osamodas — est écarté : il chevauchait *Meute* de La Trace.)*

## Ce que ça demande aux systèmes

Trois ajouts, tous génériques — **aucune exception par classe** :

1. **Effet `tempo`** ([[Vocabulaire des modules — six axes]]) — agit sur les compteurs d'action de [[Boucle de tick]]. **Garde-fou obligatoire :** un retard est un contrôle dur déguisé ; il compte dans le budget de [[Statuts de contrôle et anti-stunlock]] (jamais plus de 20 ticks cumulés, pas de réapplication dans les 50 ticks suivants).
2. **Effet `saisie`** — l'attaquant contrôle le déplacement d'une entité adjacente, qui libère sa tuile et devient projetable ([[Hauteur de terrain ±10]] : les chutes font (hauteur−2)×5).
3. **Jauge de classe** — barre propre à une classe, même objet de code que la [[Jauge de chaîne Wu Xing]].

Et trois statuts nouveaux ([[Statuts]]) : **Dissimulé**, **Saisi**, **Retardé**.

## Les PNJ ont des classes — avec une règle

- La classe d'un PNJ est tirée dans un **pool restreint par fonction** ([[Fonctions]], champ `classes_possibles`).
- Les **classes cachées sont rares** (≈ 2 % des PNJ à fonction compatible) : le bandit-Passeur est un événement, pas un tirage.
- **C'est ce qui rend l'apprentissage possible** — sans porteurs, aucune classe cachée ne serait trouvable.

## Liens
- **Dépend de** : [[Les trois axes — race, classe, fonction]], [[Classes]], [[Structure compétences-modules-slots]], [[Vocabulaire des modules — six axes]]
- **Alimente** : [[Fonctions]], [[Création de personnage]], [[Schéma créature]], [[Statuts]]
- **Voir aussi** : [[Talents de race]], [[Jauge de chaîne Wu Xing]], [[Boucle de tick]], [[Familles de capacités de la grille]], [[L'information comme récompense]], [[Piliers d'inspiration]]
