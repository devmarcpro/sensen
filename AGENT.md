# Prompt — développement autonome de Sensen

> Copier tout ce qui suit dans une nouvelle session d'agent. Ce fichier est versionné : le mettre à jour quand les règles ou l'état du jeu changent.
>
> **Revu le 2026-09-03.** La version précédente datait du 2026-08-26 et envoyait un agent neuf construire l'étape 0, terminée depuis longtemps. Un fichier d'amorçage périmé fait perdre une session entière avant que quiconque s'en aperçoive : le relire fait partie du travail.

---

Tu travailles sur **Sensen** (森森), un roguelike tactique en monde-planète continu, vue isométrique sur grille, combat en **action-time à ticks**. Dépôt : `c:\Sensen`, remote `https://github.com/devmarcpro/sensen`. Moteur : **Godot 4.6.3**, binaire local : `C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe`.

## Où en est le jeu

**Les étapes 0 à 10 sont codées et jouables.** On entre dans un donjon, on combat, on loote, on progresse, on ressort ; il y a un monde continu avec des biomes, des royaumes, des villages, des claims, de l'agriculture et de l'élevage. L'étape 11 (coop) attend un jugement humain sur la qualité du solo — elle ne commence pas sans instruction.

Ordres de grandeur au soir du 2026-09-03 : **279 notes** dans le coffre, **216 modules**, **245 matériaux**, **85 créatures**, **36 armes** (six par voie), une suite de tests d'environ sept minutes, **vingt-cinq sondes** headless et cinq bancs de mesure. Dernière pré-version : `v0.4.3-alpha`.

**Le squelette du jeu a changé le 2026-09-03, et il faut le connaître avant de toucher au combat :**

- **Six voies, une par stat** — force le guerrier, dextérité la lame rapide, endurance la ligne, volonté le mage, perception le tireur, charisme le barde. Chaque voie a six armes, une construction d'armure, ses noyaux (`stat` sur chaque noyau, lue par `degats_sort`). Lis `docs/03 - Combat/Structure compétences-modules-slots.md` (callouts du 2026-09-03) et `docs/00 - Index/Synthèse — les six voies, les monnaies et les modules.md`.
- **Trois monnaies** — `mana` (volonté, invité charisme), `vigueur` (force, invitée endurance ; c'est l'ancienne « endurance », renommée : **la stat s'appelle `endurance`, la monnaie `vigueur`**), `sang_froid` (dextérité, invitée perception ; elle ne monte qu'immobile). Chaque monnaie a un propriétaire dont tout le combat en dépend et un invité qui s'en sert en bonus.
- **La grille de composition** — un sort se compose en emboîtant les silhouettes de ses modules dans la silhouette de l'arme tenue (`GrilleSort`, `combat_rules.grille`) ; le composeur est un Tetris en glisser-déposer, et **l'ordre de lecture est l'ordre du sort**. C'est la seule borne structurelle de l'assemblage — le « no-limit » reste vrai pour l'assembleur lui-même.

**Tu ne pars donc jamais d'une page blanche.** Le travail est : combler les écarts entre le coffre et le code, répondre à la file du designer, et regarder le jeu avec un œil neuf.

## La source de vérité

Le design vit dans `docs/`, un coffre Obsidian de notes atomiques. **Le callout daté le plus récent gagne** sur tout le reste de la note. Points d'entrée :

- `docs/00 - Index/Sensen — Index général.md` — la carte du coffre
- `docs/00 - Index/Vers la production.md` — **la file du designer**, elle prime sur tout
- `docs/00 - Index/À juger — parcours de jeu.md` — ce qui attend un œil humain
- `docs/00 - Index/Audit d'équilibrage — 2026-09-03.md` — l'état chiffré du réglage
- `docs/00 - Index/Prompt de la boucle.md` — la consigne de travail autonome, dont ce fichier est le complément
- `docs/08 - Technique/Ordre de vérification.md` — **tout ce qu'il faut passer avant de pousser**

## Où chercher du travail, dans cet ordre

1. **La file du designer** dans `Vers la production`. Elle prime sur tout.
2. **Un écart entre le coffre et le code** : une note décrit un comportement que le jeu n'a pas, ou le code fait ce qu'aucune note ne dit. `python tools/verif_doc_code.py` en trouve une partie mécaniquement.
3. **Le jeu regardé sous un angle neuf** : joue une scène, prends une capture, **lis-la vraiment**. Les défauts d'affichage ne se voient qu'à l'écran — une sonde prouve qu'un système obéit à ses règles, elle ne voit pas qu'il raconte la mauvaise histoire.

## Trois natures de contraintes, à ne jamais mélanger

- **REFUSÉ, ne jamais ajouter** : tacle, boss à mécaniques, PA/PM, initiative, relances, cases de départ.
- **DÉCIDÉ, à respecter et faire vivre sans y toucher** : horloge à ticks et action-time, résolution simultanée, no-limit des modules, loot et boutiques assemblés, temps à l'action en donjon, sauvegarde partout.
- **PAS À TOI DE TRANCHER** : équilibrage, game feel, réécriture de design. Consigne dans `À juger` **et continue** — ne bloque jamais sur une question. *(Le designer peut lever cette réserve ponctuellement en te demandant de traiter un point ; alors choisis l'option la plus conservatrice, écris pourquoi, et dis-lui comment revenir en arrière.)*

## Méthode, non négociable

1. **Le callout daté s'écrit AVANT le code.** Le code ne doit jamais être en avance sur les notes.
2. **Tout en données** : un JSON par entrée, schéma validé au démarrage, **aucun nombre de gameplay en dur**.
3. **Un bloc de configuration se FUSIONNE, il ne se réécrit pas.** Remplacer un bloc au lieu de l'étendre efface des réglages en silence — c'est arrivé deux fois sur le bloc `ia`.
4. **GDScript typé**, commentaires en français, sobres, dans le style existant. Pas de GDExtension.
5. **Le joueur n'est pas un type à part** : même schéma d'entité que tout être, le contrôle est un attribut. On teste la présence d'un bloc, jamais le type.
6. **Aucun asset** : tout se dessine par code. C'est une phase, pas un dogme.
7. **Ne touche jamais à `.obsidian/`.**

## Avant de pousser

```powershell
$godot = "C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe"
& $godot --headless --path godot res://scenes/tests/test_combat.tscn   # la suite (~7 min)
& $godot --headless --path godot res://scenes/demo/main.tscn --quit-after 60
python tools/check_vault.py ; python tools/audit_donnees.py
python tools/i18n_couverture.py ; python tools/verif_scripts.py ; python tools/verif_doc_code.py
```

Plus **les sondes concernées** (`godot/scenes/tests/sonde_*.tscn` : écrans, IA, faune, mine, butin, armes, jet, espèce, journal, monde, noyaux par stat, constructions, perf de génération…), `verif_classes.tscn` (les kits des classes tiennent-ils dans leur grille), `test_modules.tscn` (« essaye tout », dix mille plans) et **une capture d'écran réellement regardée** si un écran a changé.

**Un seul Godot à la fois.** Deux instances en parallèle faussent toute mesure de performance — le budget de génération d'étage a été déclaré cassé à tort pour cette raison.

**Un test ciblé** : `-- --seul <fragment>` — vingt secondes au lieu de sept minutes.

**`verif_scripts.py` n'est pas optionnel** : la suite ne charge jamais les scripts d'écran, donc une Parse Error dans `main.gd` la laisse verte et tue le jeu.

## Pièges déjà payés — les relire évite de les repayer

- **Un test qui compte est un test qui se trompe de sujet.** Sept tests à nombre figé (« 62 compétences », « 63 recettes », « 9 stations ») ont cassé sur des ajouts parfaitement corrects. Vérifie la **règle**, jamais le total : *chaque station se construit*, *chaque arme s'entraîne à une compétence qui existe*.
- **Une sonde qui invente son vocabulaire ment avec aplomb.** Une liste de raretés tapée à la main annonçait « 0 % de légendaires » — la rareté haute s'appelle *artefact*. Lis les listes dans les données.
- **Vérifie que ton outil a tort avant d'accuser le jeu.** Quatre fausses alertes en une journée, toutes de cette forme.
- **Une considération d'IA qu'aucun profil ne pondère est du code mort** : le moteur la calcule et l'ignore.
- **Le cache des classes Godot** : après avoir ajouté un `class_name`, lancer `--headless --path godot --import` avant que quoi que ce soit compile.
- **Un exit code 0 ne veut rien dire** : la suite peut finir par `TESTS : N échec(s)` avec un code 0. Lis la dernière ligne.
- **Ne lance jamais la suite pendant que tu édites un script de test.**
- **Un renommage qui traverse une frontière de sens ne peut pas être aveugle.** Remplacer `"endurance"` par `"vigueur"` partout a corrompu neuf littéraux de **stats** et laissé un statut bloquer un mot que plus personne n'employait. Liste les formes composées, les receveurs un par un, et mets les autres sens à l'abri d'abord.
- **Un budget de performance se mesure à chaud, et plusieurs fois.** Le test « étage < 100 ms » passait dans la suite et rougissait lancé seul : il mesurait le démarrage de Godot. Avant de crier à la régression, mesure sur le dépôt d'avant dans un worktree — c'est ce qui a montré que le budget n'avait jamais été tenu.
- **Une note « à faire » peut être en retard sur le code.** Deux points de la file du designer étaient livrés depuis des jours. Mesure avant de coder ce qu'une note réclame.

## Versions et pré-releases

**La numérotation avance d'un cran sur le DERNIER chiffre** : après `v0.4.1-alpha` vient `v0.4.2-alpha`. Le deuxième chiffre ne bouge **que** si le designer le dit — c'est lui qui juge si le jeu a franchi une marche, pas la taille du diff.

Une pré-version tous les ~10 commits, **avec son exécutable construit depuis le tag** :

```powershell
git tag -a v0.4.N-alpha -m "..." ; git push origin v0.4.N-alpha
& $godot --headless --path godot --export-release "Windows Desktop" ../build/Sensen.exe
gh release create v0.4.N-alpha build/Sensen-v0.4.N-alpha-win64.zip --prerelease --notes-file ...
```

Une release sans binaire n'est pas une release. Si `gh` n'est pas connecté, le jeton que `git push` utilise déjà se récupère par `git credential fill` et s'accepte via `GH_TOKEN` — sans jamais l'écrire sur le disque.

**Ne déplace jamais un tag déjà poussé** pour y glisser du travail en plus : c'est ce qui rend une version irreproductible.

## Ce que tu ne peux pas juger seul

Le **game feel** — lisibilité de l'iso, vitesse perçue, clarté des télégraphes — exige un œil humain. Termine l'incrément, écris précisément **quoi regarder et quelle question trancher** dans `À juger`, et passe à la suite.

## En fin de passe

Dis ce que tu as trouvé et changé, en une poignée de lignes. **Pas de plan, pas d'options : agis.** Et quand tu t'es trompé, dis-le simplement — la moitié de ce fichier vient d'erreurs écrites noir sur blanc au moment où elles ont été comprises.
