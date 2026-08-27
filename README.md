# 森森 Sensen

Un **roguelike tactique** en monde infini, généré procéduralement et totalement continu, en vue isométrique sur grille — combat en **action-time à ticks** structuré par les cinq éléments du **Wu Xing** et sa jauge de chaîne, progression par l'usage à la Elona/Elin, endgame de construction de royaume.

> **L'identité du jeu tient en une phrase :** un jeu de **décisions**, pas de dextérité.

**Moteur : Godot 4.x** · GDScript (GDExtension/Rust au profilage uniquement) · PC (Steam), solo et coop 4-8 en host-and-join.

## Juger le jeu

Les questions qui attendent un œil humain, dans l'ordre d'une session : `docs/00 - Index/À juger — parcours de jeu.md`.

## Structure du dépôt

| Chemin | Ce que c'est |
|---|---|
| [`godot/`](godot/) | Le projet Godot — prototype de combat (étape 0) en cours, arborescence conforme au design (D.1) |
| [`docs/`](docs/) | Le design complet : un **coffre Obsidian** de 272 notes atomiques, reliées et navigables |
| [`archive/`](archive/) | Le GDD source monolithique (v2.0) — archive de référence, les notes de `docs/` font foi |
| [`tools/`](tools/) | Outillage du dépôt — `check_vault.py` valide liens, frontmatter et comptages du coffre |
| [`AGENT.md`](AGENT.md) | Le prompt de développement autonome — règles de travail, boucle de validation, ordre |

## État du projet — pré-production

Le design est complet et nettoyé : le pivot **voxel → tactique isométrique** (2026-08-09, irrévocable) est intégralement répercuté dans les notes. **Aucune question de design ne reste bloquante** : tout ce qui était ouvert a reçu une décision ou un défaut chiffré implémentable — le code n'a rien à inventer. Le code de l'**étape 0** (prototype de combat) est en cours — l'état exact est dans **`docs/00 - Index/Vers la production.md`**.

### Ordre de construction (le donjon avant le monde)

Chaque étape produit quelque chose de **jouable et jugeable**, jamais une brique invisible.

| # | Étape | Ce qu'on obtient |
|---|---|---|
| 0 | **Prototype de combat isolé** | *Le combat est-il bon ?* Rien ne démarre avant un oui. |
| 1 | Combat rapatrié + pipeline paperdoll minimal | un combat propre dans le vrai projet |
| 2 | Génération de donjon | un espace clos à explorer |
| 3 | Loot (affixes, gemmes, rareté par profondeur) | une raison de descendre |
| 4 | Progression (usage, potentiel) | une raison de recommencer |
| 5 | ⭐ **Jalon — roguelike jouable de bout en bout** | entrer, combattre, looter, progresser, ressortir |
| 6 | Matériaux + craft compositionnel | fabriquer ce qu'on n'a pas looté |
| 7 | Camp de base | un point d'ancrage entre deux expéditions |
| 8 | Génération du monde | un monde à parcourir entre les donjons |
| 9 | PNJ et villages | un monde habité |
| 10 | Royaumes, lois, économie, claims | l'endgame de territoire |
| 11 | Coop | dernier chantier, jamais avant un solo bon |

### Contraintes permanentes (dès la première ligne de code)

1. **Une partie solo EST une partie multijoueur hébergée** dont la porte est fermée — serveur autoritaire même en solo, intentions côté client, déterminisme par ticks.
2. **Une brique à la fois**, avec un critère de sortie formulé avant de commencer.
3. **`tr()` dès le premier écran** — aucune string affichable en dur, jamais (fr/en/ja/zh au lancement).
4. **Tout le contenu est de la donnée** — JSON validé au boot, hot-reload, zéro valeur de gameplay en dur.

## Lire le design

Ouvrir [`docs/`](docs/) comme coffre dans **Obsidian**. Point d'entrée : `00 - Index/Sensen — Index général.md`.

- Chaque note porte en **alias** les références du GDD (`A.4.6`, `E.3`, `B.13`…) — tous les renvois résolvent.
- Frontmatter filtrable : `statut` (décidé / à-trancher / playtest / contenu-à-produire), `etape` (0-11), `domaine`.
- `docs/99 - Ouvert/` archive les questions *tranchées depuis* : chaque note y porte sa décision et sa date.
- **Vérifier le coffre :** `python tools/check_vault.py` — liens morts, frontmatter incomplet, comptages périmés. Sortie non nulle si erreur.

## Développement

Le projet `godot/` s'ouvre avec **Godot 4.6** et se lance directement (F5) : la scène principale est le **prototype de combat** (étape 0) — trois arènes chargées depuis `godot/data/prototype_arenas/`, grille isométrique 32×32 avec relief, action-time à ticks (une horloge par combat), mêlée avec zones par dénivelé, garde, attaque lourde télégraphée, endurance, et une IA utility en données. Aucun asset : tout est dessiné en polygones.

**Commandes :** clic — se déplacer / frapper · Maj+clic — attaque lourde · G — garde · Espace — attendre · 1-7 — changer d'arme · F1-F3 puis clic — lancer une capacité (Échap annule) · Tab — arène suivante (puis le camp de base, une cellule du monde généré — on peut en sortir à pied, la fenêtre de 3×3 cellules suit ; E sur l'entrée sombre lance une expédition, la sortie de l'étage 1 ramène au camp ; coffre de départ avec hache, pioche, faucille, lit de paille ; arbres et plantes en billboards, plantes récoltables à la faucille (clic) ; inventaire : P poser un meuble/une station, M mur, O porte, R ranger dans un coffre adjacent ; clic sur un lit : dormir ; clic sur un meuble/mur construit : démonter) · faim et poids porté dans l'en-tête ; G dans l'inventaire : manger ; la viande crue tombe des animaux, les plats se cuisinent à la Cuisine · E — descendre (escalier doré) / remonter et sortir (escalier vert) · clic sur un mur adjacent — creuser (10 ticks ; avec la pioche en main, récolter le matériau du mur ou du filon) · brouillard de guerre : on découvre l'étage avec sa vision (Perception, ligne de vue), les êtres hors de vue ne sont pas affichés · le donjon : une cellule de 128×128, 14-24 salles de tailles variées reliées en réseau maillé de couloirs sinueux, façon Elin / ToME · R — ramasser · ⇧chiffre — équiper depuis le sac · T — sertir une gemme · L — lire un livre · C — feuille de personnage · I — inventaire et équipement (E équiper/retirer, J jeter, L lire, T sertir) · F — atelier (Entrée : fabriquer ; le détail déplie l'obtention de chaque composant) · Échap ferme un écran · au lancement : création (R race, C classe, ↑↓ +− points, ←→ année, Entrée) · F5 — recharger les données · F6 — sauvegarder (en surface ; autosave 5 min et au retour d'expédition, `user://sauvegardes/monde/`) · F7 — charger · N — zoom de la minimap (⇧N : masquer) · M — carte du monde (clic sur une cellule explorée : voyage rapide ; à la création : choix de la case de départ) · les donjons de surface sont à 6 % des cellules (entrée scellée) · hameaux à 4 % des cellules (place, bâtiments, PNJ nommés) : clic sur un villageois — parler (relation, rumeurs, fiche révélée par paliers), commercer (or, prix suggéré détaillé), quêtes du garde (chasse, bêtes, donjon ; XP et rangs de guilde) ; Maj + clic pour frapper (réputation en chute, hostile à vue sous −50) · Recruter (R dans le dialogue, relation suffisante), ordres S/A · V — apprivoiser une bête adjacente (Dressage) · carte : clic sur une cellule voisine explorée — revendiquer (50 or × cellules) · K — territoire (rôles, résidents assignés, stocks, trésor, rapports) · dialogue d'un compagnon : Assigner (X) à une fonction · inventaire : H — planter une culture (cellule Champs) ; clic sur une parcelle mûre : récolter ; avec un engrais dans le sac : fertiliser · étal de vente : ranger des objets, clic — relever la caisse · K : G — changer de gouvernance (royaume : 8 cellules + 5 résidents) ; raids hebdomadaires selon corruption, valeur et réputation · royaumes PNJ sur la carte (territoires teintés), lois (témoins, amendes, confiscations, gardes), douanes chez les marchands, K : T — accords avec un royaume voisin · dialogue : Q apprendre le talent d'un PNJ (Le Vent, l'Humain, relation ≥ 75), U s'entraîner (maîtres de guilde, gardes), N ressusciter un compagnon chez un prêtre (chapelle), Z livrer la commande d'un collectionneur à un marchand · clic sur la place d'un village : conquérir (gardes affaiblis, jet de Leadership/Charisme) ; tuer un dirigeant ouvre une vacance de 4 semaines · saisons (120 jours, écart de température) · élevage : Y — capturer ce que le milieu voisin offre (carpe sur l'eau, tortue/ruche sur une plante, ver à soie sur un arbre, phalène la nuit, serpent avec une viande crue en appât), habitats à l'établi (vivarium, terrarium, clayette, rucher, enclos) où un couple donne une couvée par semaine, registre des variétés et paliers dans B · villes : capitales dimensionnées par la taille du royaume, boutiques typées (forgeron, armurier, alchimiste, épicier, tailleur, herboriste), halls de guilde tenus par un maître ; hall de guilde à bâtir chez soi au rang Adepte · alchimie : une partie de bête (œil, peau, griffe, dent, os) + une culture à l'Alambic → potion de stat (durée × qualité, forte à partir de 1,3) · un compagnon mort laisse son âme, un autel domestique le rappelle · jour/nuit (24 000 ticks, la nuit assombrit et réduit la vue ; dormir la nuit saute à l'aube) et météo (10 états, température ressentie dans l'en-tête) · molette — zoom · clic milieu — déplacer la vue.

```powershell
$godot = "C:\Users\ciryl\Documents\Godot_v4.6.3-stable_win64.exe"
& $godot --headless --path godot --import                                            # une fois après un clone (cache des classes)
& $godot --headless --path godot res://scenes/tests/test_combat.tscn --quit-after 3  # les tests (assert, headless)
& $godot --headless --path godot res://scenes/demo/main.tscn --quit-after 120        # la scène tourne sans erreur
python tools/check_vault.py                                                          # le coffre est intègre
& $godot --headless --path godot res://scenes/tests/test_criteres.tscn --quit-after 3 # rapport des critères mesurables (§ 5 de la spec)
& $godot --path godot res://scenes/tests/capture.tscn -- --sortie C:/tmp/c.png --arene 0 # capture d'écran (fenêtré)
```

L'arborescence (autoload, data, systems, scenes, locale) suit la note *Arborescence du projet*. `autoload/game_data.gd` charge et valide tout `data/` au boot (bloquant en debug) ; `systems/combat/simulation.gd` est l'autorité (le client `scenes/demo/main.gd` n'envoie que des intentions) ; `scenes/entities/creature.tscn` est la scène unique de tout être (rig en données, équipement visible, sans asset). État et prochaines étapes : `docs/00 - Index/Vers la production.md`.
