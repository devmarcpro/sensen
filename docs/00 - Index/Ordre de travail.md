---
aliases: ["Ordre de travail", "File d'attente", "Ce qu'il reste à faire", "Priorités"]
tags: [index, production, décidé]
domaine: index
statut: décidé
etape: 12
---

Tout ce qui reste à faire, dans un seul ordre. Demandé par le designer le 2026-09-08 : « j'aimerais que tu organises
par ordre les choses à faire ». Les contenus viennent du balayage à douze angles de [[Vers la production]] et des
notes elles-mêmes — **rien ici n'est de mon invention**, et chaque ligne renvoie à ce qui la réclame.

## La règle de tri

Six paliers, et une seule question à chaque fois : **qu'est-ce qui, en restant tel quel, abîme tout ce qu'on
construira par-dessus ?**

1. **Ce qui perd du jeu maintenant, en silence.** Un défaut qui détruit la partie d'un joueur passe avant tout.
2. **Ce sans quoi ce n'est pas un jeu.** Pas de pause, pas de mort, pas de touches : la profondeur ne se voit pas.
3. **Le chantier décidé** — les champs, puis les modules. C'est la demande vivante du designer.
4. **Les règles qui mentent.** Le jeu tourne, mais il ne fait pas ce qu'il promet.
5. **Ce qui existe et qu'on ne verra jamais**, puis la performance, puis les tests et le coffre.
6. **Ce qui n'est pas à moi.**

**Deux endroits où le designer a déjà tranché contre cet ordre**, et sa décision l'emporte : le palier 3 est *en
cours* à sa demande (2026-09-08, 6 h 30), et l'ordre « les champs d'abord, la suppression ensuite » est le sien.
Le palier 1 reste ce que je ferais passer devant si l'on me le demandait — **il faut qu'il soit fait avant la
prochaine publication**, sinon on publie un jeu qui efface les parties.

---

## Palier 1 — la sauvegarde ment (six défauts vérifiés à la main)

C'est le seul palier dont chaque ligne a été **confirmée par deux juges adversariaux**. Il perd du jeu aujourd'hui,
sans rien dire.

1. **Le drapeau `mine` n'est pas sauvegardé** → recharger dans une mine régénère un donjon à salles. C'est la
   promesse de [[Mine sous une cellule]] qui disparaît au rechargement.
2. **La branche « sauvegarde en donjon » sort avant de relire** `mines_creusees`, `gouffres_vides` et `carte_cache`.
3. **`charger_donjon` écrase `sim.donjon`** et perd `gouffre`, `corrompu` et `niveau` — trois persistances mortes.
4. **`Monde.nettoyages` n'est jamais sauvegardé** → un donjon de corruption vaincu revient.
5. **`sauvegarder()` dissout le combat en cours** sans passer par la fin de combat.
6. **L'écriture dite « atomique » supprime la cible avant de renommer**, et les cinq fichiers ne forment pas une
   transaction : une coupure de courant au mauvais moment ne laisse rien.
7. *(rattaché)* La sauvegarde s'écrit **en entier sur le fil principal** alors que [[Sauvegarde]] exige un thread ;
   le test de sauvegarde en expédition ne couvre ni mine, ni gouffre, ni donjon de corruption.

## Palier 2 — ce sans quoi ce n'est pas un jeu

8. **Le menu de triche est sur `V`, sans garde de débogage, dans la version publiée.** Une ligne à écrire, et c'est
   ce qui gêne le plus quelqu'un qui télécharge la pre-release.
9. **Aucune pause** : le monde avance pendant qu'un écran est ouvert — et **ZQSD n'est pas bloqué**, taper une lettre
   d'option fait marcher le personnage.
10. **Aucun écran de mort** : la défaite est une ligne de journal, n'importe quelle touche fait renaître ; avant
    d'avoir dormi une fois, mourir ne coûte rien.
11. **Aucun `InputMap`** : les touches sont câblées en dur, le jeu n'est jouable qu'en AZERTY, rien ne se reconfigure.
12. **Aucun rappel des touches en jeu** — elles ne vivent que dans le README, et des chaînes d'aide décrivent encore
    des touches disparues.
13. **Aucune sortie propre** : fermer la fenêtre perd jusqu'à cinq minutes sans confirmation ; les options ne sont
    jamais enregistrées ; le menu Tab n'a ni Options ni Quitter ; pas de réglage de résolution ni de taille de texte.

## Palier 3 — le chantier décidé : les champs, puis les modules *(en cours)*

L'ordre à l'intérieur est celui du designer : **les champs d'abord, la suppression ensuite**, parce que 13 fichiers de
tests dépendent des modules et qu'on ne fait pas la partie risquée le filet baissé ([[Émergence — les champs partagés]]).

14. ~~**Le champ de chaleur**~~ — **fait le 2026-09-08**. Il remplace le jet de propagation du feu et l'ignition
    directe par la lave.
15. **Les cinq stats qui manquent aux matériaux** — `fusion`, `portance`, `absorption`, `permeabilite`, `alteration`
    ([[Matériaux — 13 stats]]). Chacune est la stat sans laquelle un champ décidé ne peut pas exister. **Bloqué par
    la ligne 16.**
16. **Remettre les catalogues en accord, et réparer `gen_materials.py`** — 94 matériaux sur 248 n'avaient plus de
    ligne de table, 150 chiffres divergeaient ; les tables ont été refaites le 2026-09-08 depuis les fiches, mais le
    générateur **détruirait encore** `stats_base` et les 94 s'il était relancé. À faire avant tout autre chantier
    matériaux.
17. **Le champ de support** (l'effondrement) — il a besoin de `portance`. C'est la seule chose qui sépare une mine
    d'un gouffre, et [[Mine sous une cellule]] la promet déjà.
18. **Le champ de bruit et d'odeur** — « le plus criant » selon le designer. Il a besoin d'`absorption`.
19. **Le champ de danger que l'IA lit** — sans lui, tout ce qu'on ajoute au terrain reste invisible aux créatures,
    ce qui est déjà vrai des gaz.
20. **Supprimer les 236 contenus de modules**, les branches d'effet en dur et les listes des 19 fiches de classe —
    **la grammaire reste** (portée, forme, noyau, modificateur, grille de composition, coûts, emplacements).
21. **Réécrire les contenus de modules sur les champs** : un noyau de feu dira `{chaleur: 400}` et le reste suivra.
22. Puis, dans l'ordre du designer : **la rumeur qui circule**, **le temps long** (usure, ruine, repousse), **les
    besoins au-delà de la faim**, **l'eau qui pèse** (pression, poids, érosion).

## Palier 4 — les règles qui mentent

23. **`chain_gauge` sert de « c'est le boss » au butin** : une brute de couloir donne un artefact garanti et marque le
    donjon nettoyé. Le même défaut sous trois angles.
24. **Un sort au contact ne coûte ni tick ni mana** et emprunte les dés de l'arme ; un sort à distance paie les trois.
25. **Vingt-trois sorts sur quatre-vingt-six ne produisent rien d'observable.** *(Se résout largement au palier 3.)*
26. **Le mana se régénère 160 fois plus lentement que la vigueur**, pour 55 % des noyaux du catalogue.
27. **Le même chef de bande garde les huit thèmes** — les douze créatures de folklore ne sont jamais boss.
28. **Incarner un compagnon fait perdre la jauge de chaîne Wu Xing, en silence.**
29. **L'audit d'équilibrage du 2026-09-03, resté lettre morte** : le palier de matière est plat après le niveau 14 ;
    « légendaire » et « mythique » sont mathématiquement inatteignables ; l'accélération d'XP du 2026-09-05.
30. **L'XP d'armure n'est vérifiée que par une tautologie**, et derrière elle les constructions `tissu` et `rituel`
    n'ont aucune compétence correspondante.

## Palier 5 — ce que le joueur ne voit pas, ce qu'on ne verra jamais, et ce qui coûte trop cher

31. **Le coût d'une capacité n'est écrit nulle part** au moment de la lancer, alors que le déficit se paie en PV.
32. **La réputation** (village, royaume, globale) est simulée, ferme des portes, et n'est affichée nulle part.
33. **Toute action refusée dans un écran est invisible** : le refus part au journal, que le panneau recouvre.
34. **Les bâtiments de village se posent au hasard** — la fonction qui les rangeait le long des rues n'a plus
    d'appelant.
35. **La bibliothèque de préfabs de donjon** (12 salles, 8 connecteurs) est chargée à chaque démarrage et jamais posée.
36. **30 des 40 bois du catalogue ne peuvent apparaître nulle part** dans le monde.
37. **Douze signaux de l'EventBus sont émis sans auditeur**, un treizième n'est jamais émis.
38. **Un pas qui franchit une cellule engendre jusqu'à trois cellules de 31 ms dans la même image**, contre un budget
    de 2 ms ([[Budgets de performance]]).
39. **`sim.objets` n'est jamais purgé** : 78 % des objets d'une vraie sauvegarde sont des fantômes consommés.
40. **Une seule tuile changée refait toute la carte de lumière** de la fenêtre — chaque porte de ville la déclenche.
41. **`Monde.cellules` n'est jamais déchargé** alors que sa docstring promet le contraire ; le passage hebdomadaire
    balaie toutes les cellules jamais explorées.
42. **Les tests qui ne prouvent rien** (huit) et **le coffre qui se contredit** (le mana de la Méditation, le
    portefeuille du roi, trois nombres pour le catalogue des statuts, le catalogue des modules).
43. **L'ancienne file, jamais revue par le balayage** : les saisonniers ; le chômage qui pousse à migrer ; les tombes
    qui vieillissent ; les événements en zone logique ; **une guerre qui ne fait rien** ; le nom de la vocation à
    l'écran ; l'irrigation construite ; les mauvaises récoltes ; la cuve et le moulin ; la clé de description absente des modules (236
    descriptions non traduisibles).

## Palier 6 — ce qui n'est pas à moi

44. **Le jeu est muet** : zéro fichier audio, zéro `AudioStreamPlayer`. Je peux poser l'architecture (bus, événements
    → sons, ambiance par biome et par heure) ; les sons sont un choix du designer.
45. **La difficulté de départ** : le robot meurt aux étages 1 et 2 avec le kit complet. Se tranche en regardant.
46. **Le sens de la vérité des catalogues** : la note redevient-elle la source (il faut alors valider 94 lignes neuves
    et 427 chiffres à la main), ou la donnée devient-elle la source et la note son reflet ?
47. **L'ordre des champs restants**, et s'il faut les faire **avant** de finir le jeu. Un monde profond dans un jeu
    qu'on ne peut pas mettre en pause reste une démo.

## Liens
- **Dépend de** : [[Vers la production]], [[Émergence — les champs partagés]], [[Ordre de construction]]
- **Alimente** : [[Ordre de vérification]], [[Risques majeurs]]
- **Voir aussi** : [[Sauvegarde]], [[Matériaux — 13 stats]], [[Mine sous une cellule]], [[Budgets de performance]]
