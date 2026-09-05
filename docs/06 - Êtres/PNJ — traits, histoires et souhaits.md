---
aliases: ["PNJ distincts", "Traits des PNJ", "Histoires des PNJ", "Souhaits des PNJ", "Programme C"]
tags: [êtres, société, simulation, décidé, designer]
domaine: êtres
statut: décidé
etape: 11
---

Le designer (2026-09-05, 14 h 20) : « idem pour les PNJ : chaque PNJ doit donner l'impression d'être vivant et réel et se différencier des autres ». Le programme C de [[Un monde réel — villes, PNJ, royaumes et calendrier]].

## Ce qu'un PNJ a déjà

Un nom de sa culture ([[Génération de noms]]), une apparence tirée des loci de sa race ([[Apparence — données et équipement]]), un âge, une espérance de vie, un signe et un anniversaire ([[Âge des PNJ]], [[Un monde réel — villes, PNJ, royaumes et calendrier]]), une famille ([[Familles et succession]] via `_former_familles`), une humeur, une fonction et une classe ([[Les trois axes — race, classe, fonction]]), un potentiel, une relation avec le joueur ([[Réputation et relations]]), des répliques par gabarits à conditions ([[Dialogue PNJ]]), un poste, un lit, un coin de place, un territoire ([[Villes — population, quartiers et économie]]). Ce qui manque : ce qui le distingue *de l'intérieur* — un caractère, une histoire, une envie — et un écran qui le montre au fur et à mesure qu'on le connaît ([[L'information comme récompense]]).

## Les décisions

> [!success] Décidé le 2026-09-05, 19 h 30 — C, les traits, l'histoire, le souhait, la fiche (codé à la suite de B)
> - **Deux traits par PNJ** (`data/traits/*.json`, catalogue validé par schéma ; tirés à l'instanciation par la graine du PNJ, jamais deux traits qui s'excluent : `exclut`). Chaque trait porte ses **effets** en données, lus là où ils comptent : `prix_mult` (l'avare vend plus cher, le généreux moins — `prix_suggere`), `relation_mult` (le méfiant se lie lentement, le jovial vite — le gain de relation de *Parler* et des cadeaux), `horaires_decalage` (le lève-tôt et le couche-tard décalent leurs plages — `_plage_routine`), `productivite` (le paresseux, l'ambitieux — `production_de`), `courage` (le peureux fuit plus tôt, le courageux plus tard — le seuil de fuite), `humeur` (le grincheux part plus bas, le jovial plus haut), `cadeaux` (les tags d'objets qu'il aime). Quinze traits au départ : bavard, taciturne, avare, généreux, méfiant, jovial, curieux, pieux, ambitieux, paresseux, courageux, peureux, grincheux, gourmand, coquet.
> - **Les répliques savent les traits** : un gabarit de dialogue peut exiger un `trait` ; deux ou trois répliques par trait (le taciturne répond en trois mots, le bavard raconte sa journée, l'avare parle prix). Le tirage pondéré existant fait le reste.
> - **Une histoire courte** (`data/histoires/*.json` : des gabarits à conditions — fonction, trait, palier de ville, culture — et à paramètres : ville natale (une agglomération à trente cellules, ou la sienne), l'âge, le métier, un parent) : une phrase par PNJ, tirée une fois, gardée (`histoire`). Elle se lit dans la fiche à partir de 50 de relation, et le PNJ la dit lui-même à 75 (réplique `histoire`).
> - **Un souhait** (`data/souhaits/*.json` : un objet d'une catégorie ou d'un tag, un cadeau précis ; conditions par trait et fonction) : le PNJ veut quelque chose. **Offrir un cadeau** entre au menu du dialogue ([[Dialogue PNJ]] le prévoyait) : un objet du sac → relation selon sa valeur et ses `cadeaux` de trait ; **le souhait réalisé** vaut un grand bond de relation (`souhait.relation`, +25) et une réplique de gratitude, une fois. Le souhait se devine par les cadeaux avant 75 de relation, se lit dans la fiche après.
> - **Les opinions** : à la formation des familles, chaque PNJ reçoit une relation avec un ou deux voisins de son quartier (l'époux +60 ; un voisin ±20 selon la compatibilité des signes — [[Astrologie — cycle sexagésimal]] — et les traits qui s'accordent ou non). Les répliques `opinion` en parlent (« mon voisin X est un brave homme », « je n'aime pas Y ») à partir de 75 ; c'est la matière des rumeurs et des brouilles de D.
> - **La fiche du PNJ à l'écran** ([[Écrans d'interface]], écran Dialogue) : sous la réplique, ce qu'on sait de lui **par palier de relation** ([[L'information comme récompense]]) : nom, métier, royaume et ville (toujours) ; âge, signe, humeur (20) ; traits et famille (50) ; souhait et cadeaux aimés (75) ; histoire et opinions (90). Une ligne par chose, rien de plus.
> - **L'âge se voit** : au-delà de `age.age` (60 ans), le grisonnement passe à gris ou blanc, la carrure à mince ; un enfant (né au village) est petit — trois lectures des loci existants, à l'instanciation et au passage de l'âge.
> - **Vérifié par** `sonde_pnj.tscn` (une ville : la distribution des traits, des souhaits, des histoires, des opinions ; deux PNJ de même fiche ne se ressemblent jamais) et `test_pnj_distincts` (traits sans exclusion, effets lus, cadeau et souhait, fiche par palier, répliques par trait).
> **Revers** : chaque trait, histoire ou souhait est un fichier ; un effet à zéro est un trait sans effet ; les paliers de la fiche sont ceux de la note de l'information.

## Liens
- **Dépend de** : [[Un monde réel — villes, PNJ, royaumes et calendrier]], [[Dialogue PNJ]], [[L'information comme récompense]], [[Réputation et relations]], [[Âge des PNJ]], [[Apparence — données et équipement]], [[Astrologie — cycle sexagésimal]]
- **Alimente** : [[Écrans d'interface]], [[Villes — population, quartiers et économie]], [[Gouvernance, lois et diplomatie]]
- **Voir aussi** : [[À juger — parcours de jeu]], [[Génération de noms]], [[Familles et succession]]
