---
aliases: ["G.8", "Annexe G.8", "Ordre de vérification", "Critères de perf par étape"]
tags: [technique, performance, décidé]
domaine: technique
statut: décidé
etape: 0
---

> [!note] Adapté au pivot tactique
> Les critères voxel d'origine (mutation de bloc, « façade 64 blocs 4px meshée < 4 ms ») et l'ancien ordre D.3 sont retirés — archivés dans le GDD source. Les critères ci-dessous suivent les 11 étapes tactiques ; chiffres décidés en [[Décision — Budgets et critères de performance tactiques]].

Un critère de performance à valider avant de passer à l'étape suivante. **Un critère raté = on optimise AVANT d'empiler le système suivant.**

**Le principe (conservé de G.8) :** chaque étape de [[Ordre de construction]] a son critère de perf AVANT de passer à la suivante, sur machine moyenne cible.

**Critères par étape ([[Décision — Budgets et critères de performance tactiques]]) :**

```
É0  Prototype de combat : grille 32×32 + 10 entités, 60 fps,
    prévisualisations et timeline sans latence perceptible.
É1  Paperdoll : 50 créatures en billboards composés < 4 ms de rendu.
É2  Donjon : étage généré < 100 ms, transition < 250 ms.
É3  Loot : génération d'un objet à affixes < 1 ms.
É4  Progression : recalcul complet des stats d'un personnage < 0.5 ms
    (le résolveur E.4 est appelé partout).
É8  Monde : streaming en déplacement rapide, aucune frame > 16 ms ;
    voyage rapide + chargement de cellule < 1 s.
É9  100 PNJ en niveau logique ≈ coût de 3 PNJ pleins (cf. E.18).
É11 2 joueurs LAN : mutation visible < 100 ms chez l'autre.
```

**Principe parallèle ([[Contraintes permanentes]]) :** *une brique à la fois, chacune avec un critère de sortie formulé AVANT de commencer.*

> [!success] Codé le 2026-08-31 — les critères mesurables sans écran ont un test
> `test_budgets` (suite) : É2 étage < 100 ms, É3 objet à affixes < 1 ms, É4 recalcul de stats < 0,5 ms, tick de simulation < 8 ms. Restent à l'œil ou au profil : les critères de rendu (fps, frames > 16 ms — `capture.tscn --disable-vsync` mesure déjà le coût moyen d'image) et le réseau (É11). La cellule de surface est mesurée dans `test_surface` (< 250 ms, budget de 32 ms différé).

> [!success] Codé le 2026-09-02 — le robot sait collecter sans mourir, et rend son sac
> Deux drapeaux de plus au parcours : **`--invincible`** (PV, endurance et mana rendus à chaque image) pour mesurer ce que le jeu **donne** plutôt que si l'on survit, et **`--inventaire <chemin>`** qui écrit le sac complet en JSON à la fin — une entrée par objet avec son nom rendu, son type, son matériau, son espèce, sa qualité, sa rareté, son poids, son vecteur Wu Xing, ses affixes et ses composants. Six étages, 97 objets : c'est ce qui a montré que 41 % du butin est une fiole non identifiée et que les boucliers ne sont pas assemblés.


> [!bug] Corrigé le 2026-09-02 — la v0.3.0-alpha ne se lançait pas, et la suite était verte
> Le designer : « le jeu ne se lance pas, même l'alpha 0.3.0 sur le repo » — puis « je crois que le problème est sur `main.gd` ». Exact. En ajoutant le parchemin à la hotbar, mon remplacement de texte a visé la **mauvaise occurrence** de `"objet":` : le cas s'est inséré au milieu du `match` de `hotbar_entrees` au lieu de celui de la sélection, et `main.gd` ne compilait plus. **Parse Error dès le chargement, jeu mort au lancement.**
> **Pourquoi rien ne l'a vu** : la suite de tests ne charge **jamais** `scenes/demo/*.gd`. Elle instancie la simulation, pas les écrans. Elle est donc restée verte sur un jeu qui ne démarrait pas, et j'ai publié une release à partir de là.
> **Le garde-fou** : `tools/verif_scripts.py` ouvre la scène principale dans Godot et **refuse** toute *Parse Error*, *Compilation failed* ou *SCRIPT ERROR*. Il tourne avec les autres outils avant chaque commit et chaque publication. Une suite verte ne prouvait pas que le jeu démarre ; maintenant si.


## Liens
- **Dépend de** : [[Optimisation — principes]], [[Budgets de performance]], [[Ordre de construction]]
- **Alimente** : [[Ordre de construction]]
- **Voir aussi** : [[Décision — Budgets et critères de performance tactiques]], [[Contraintes permanentes]], [[Génération procédurale — performance]], [[Entités et pathfinding — performance]], [[Réseau et sauvegarde — performance]], [[LOD de simulation]]
