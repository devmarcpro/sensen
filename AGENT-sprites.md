# Prompt — pipeline de sprites pré-rendus de Sensen

> À coller dans une session d'agent dédiée. Complément de `AGENT.md`, qui reste la référence pour les conventions du dépôt : lis-le d'abord, il prime sur ce fichier partout où les deux se croisent.

---

Tu construis le **pipeline de génération des sprites** de Sensen. Pas les sprites à la main : l'outil qui les rend, en lot, de façon rejouable. C'est un `tools/gen_sprites.py` de plus, dans la lignée exacte de `gen_rigs.py` et `gen_palette.py` — un script Python qui lit les données du dépôt et écrit un résultat déterministe.

La règle 6 d'`AGENT.md` (« aucun asset : tout se dessine par code ») ne saute pas, elle se déplace : les sprites ne sont pas des assets dessinés à la main et commités à l'aveugle, ce sont des **sorties générées** dont la source est du code versionné. Un `git checkout` d'il y a trois mois plus une relance du script doit redonner les mêmes PNG au pixel près.

## Ce que tu construis

1. **`tools/scene_sprites.blend`** — la scène gabarit : caméra orthographique de face, l'éclairage, le matériau de base, rien d'autre. Un seul fichier, lié par tous les rendus. C'est lui qui garantit que 246 pièces partagent la même lumière.
2. **`tools/gen_sprites.py`** — lit le manifeste, construit la géométrie de chaque pièce en `bpy`, place les Empties d'ancrage, rend, écrit le PNG et son JSON d'ancrages.
3. **`godot/data/sprites/manifeste.json`** — une entrée par pièce : identifiant, rig ou composant, dimensions cibles, ancrages attendus. Généré lui aussi, depuis `data/rigs/`, `data/components/` et `data/items/` — **jamais recopié à la main**, sinon il dérivera des rigs au premier changement.
4. **La substitution dans `paperdoll.gd`** — le sprite remplace le rectangle procédural, sans toucher au rig, aux facings ni aux poses.

Blender tourne en headless : `blender --background tools/scene_sprites.blend --python tools/gen_sprites.py`. Aucune étape du pipeline ne demande d'ouvrir une interface.

## La direction visuelle

**Image de synthèse pré-rendue, années 90.** Pas de la pâte à modeler, pas du pixel art, pas du rendu moderne.

- **Géométrie basse et primitive** : 200 à 800 triangles par pièce. Des cylindres, des cubes biseautés, des sphères aplaties, assemblés. L'esthétique vient de l'assemblage de primitives et du biseau, pas du sculpt.
- **Ombrage d'époque** : diffus plus un spéculaire dur et net. **Pas de PBR, pas d'illumination globale, pas d'occlusion ambiante, pas de bloom.** Un terme ambiant constant remplace le rebond de lumière. Rends en EEVEE, pas en Cycles — Cycles te donnerait une justesse physique qui n'existait pas à l'époque et qui trahit le style.
- **Gestion des couleurs sur `Standard`**, jamais AgX : AgX écrase les hautes valeurs, et c'est la valeur qui porte tout le modelé.
- **Le grain vient du rendu en 4× réduit** à la taille cible, pas d'un filtre. Un léger banding des valeurs est juste, pas un défaut.
- **Une seule lumière pour toute la bibliothèque** : clé en haut à gauche à 45°, ambiant faible, rien d'autre. Dans une collection liée, pas dupliquée par fichier.
- **Tout en gris neutre**, saturation 0, valeurs entre 20 % et 90 %. La teinte arrive après, par remapping de palette dans le shader. Le matériau ne se lit donc pas à la couleur mais au **spéculaire** : étroit et fort pour le métal, large et faible pour le bois, mat pour le cuir et l'étoffe.
- **Vue de face uniquement**, orthographique. Le paperdoll n'a qu'une orientation dessinée depuis la décision du 2026-09-01.

## Le contrat technique

- **Origine au centre du bord bas** de l'image, segment orienté vers le haut. Hauteur de l'image = `longueur` du rig, largeur = `largeur`. C'est ce qui permet au sprite de se substituer au rectangle sans toucher au rig.
- **Échelle : 8 px par unité de rig.** Un humain fait 35 unités, donc 280 px.
- **Les ancrages sortent en JSON, pas en pixels colorés.** Tu nommes un Empty `cou`, `epaule_G`, `prise`, et tu exportes sa projection caméra en coordonnées pixel dans un `.json` à côté du PNG. C'est mieux que les couleurs réservées : les fichiers restent 100 % gris et l'import n'a pas à scanner l'image.
  **Attention** : les couleurs réservées d'ancrage sont déjà codées en dur dans `tools/gen_gabarit_sprites.py`, et la note `Squelette modulaire et points d'attache` les déclare dans `palette_materiaux.json → anchors` — section qui n'existe pas dans le fichier généré. Ne crée pas une troisième copie. Soit tu factorises la table dans un module partagé, soit tu écris un callout disant que le JSON d'ancrages remplace la convention par pixels et pourquoi.
- **PNG RGBA, fond transparent**, pas de halo clair sur les bords, pas d'ombre portée dans l'alpha.
- **Un composant = un matériau = un fichier.** Une arme qui porte une lame de métal et un manche de bois est deux fichiers teintés séparément, jamais un seul.

## Ce qu'il faut savoir du modèle de données

- Les **rigs** sont dans `godot/data/rigs/*.json` : six squelettes (humanoïde, quadrupède, volant, arachnide, amorphe, serpentin), chacun une liste de segments avec `longueur`, `largeur`, `angle`, `ancrages`. Les dimensions des sprites se **calculent** depuis ces fichiers, on ne les écrit pas.
- Les **armes ne sont pas des formes** : les 36 armes de `data/items/arme/` (plus boucliers, outils et instruments, 43 assemblages en tout) déclarent 1 à 3 slots remplis par un composant de `data/components/`. On rend les **16 composants**, pas les 43 armes. Une arme est un assemblage, comme un corps.
- Seul un côté est rendu (gauche) : le droit est un miroir horizontal en jeu.

## L'ordre de travail — impératif

**Tu produis d'abord une seule pièce, et tu t'arrêtes.**

Le `manche_court` en bois : simple, cylindrique, utilisé par douze armes. Rends-le, écris son JSON d'ancrages, substitue-le au rectangle dans `paperdoll.gd`, prends une capture en jeu **à la taille réelle** et regarde-la.

Puis **arrête-toi et rends la main**. Le style pré-rendu tient-il à 40 px ? Le contrat origine-au-bord-bas suffit-il ? Ces deux questions relèvent du jugement du designer, pas du tien — et les 245 autres pièces ne valent rien tant qu'elles ne sont pas tranchées. Ne lance jamais un lot complet avant cette validation.

Ensuite seulement, dans cet ordre : les 16 composants d'arme, les 7 segments du corps humanoïde, les 40 pièces d'armure, les 5 autres rigs, les végétaux.

## Ce qui n'est pas à toi

- **Les visages.** Les 5 formes de visage, les traits et les 7 coiffures ne sortiront pas bien d'un script. Prépare le canevas 64 × 64, l'ancrage `cou` et l'empilement des calques ; laisse les volumes eux-mêmes vides et signale-les dans `À juger`.
- **Le jugement esthétique.** Tu rends l'image ; savoir si elle est bonne appartient au designer. Applique la règle d'`AGENT.md` : consigne dans `À juger` **et continue**, ne bloque jamais.
- **L'équilibrage et le design.** Rien de ce pipeline ne touche aux données de jeu.

## Méthode

Les règles d'`AGENT.md` s'appliquent telles quelles. Les trois qui mordent le plus ici :

1. **Le callout daté s'écrit AVANT le code.** La direction pré-rendue années 90 et l'abandon des pixels-marqueurs au profit du JSON sont deux décisions à écrire dans `docs/01 - Vision/Direction artistique.md` et `docs/06 - Êtres/Squelette modulaire et points d'attache.md` avant de toucher à `tools/`.
2. **Tout en données.** Aucune dimension de sprite en dur dans le script : elles se lisent dans les rigs. Si tu écris `48` quelque part, tu t'es trompé.
3. **Commentaires en français, sobres, dans le style existant.**

## Avant de pousser

Passe `docs/08 - Technique/Ordre de vérification.md` comme pour tout le reste, plus deux contrôles propres à ce pipeline :

- **Le test de la lumière** : rends dix fois la même pièce, monte-les côte à côte, vérifie que rien ne bouge. Si la lumière dérive, le pipeline est faux, quel que soit le rendu individuel.
- **Le test du raccord** : assemble un bras complet (épaule, coude, poignet, main) depuis les JSON d'ancrages et vérifie qu'aucune articulation ne montre de trou ni de recouvrement.

---

*Document du designer, 2026-09-05. Relevé du dépôt à cette date : dix-sept composants (la sertissure des bijoux s'ajoute aux seize), 85 créatures sur six rigs, Blender absent de la machine de développement ; voir le callout du 5 septembre (9 h) dans `docs/01 - Vision/Direction artistique.md`.*
