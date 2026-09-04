---
aliases: ["10.1", "10.1 Localisation", "Localisation", "tr()", "i18n", "name_key"]
tags: [technique, architecture, décidé]
domaine: technique
statut: décidé
etape: 0
---

Une contrainte d'architecture posée dès le jour 1 : aucun texte affiché ne vit dans le code ni dans les champs de données de gameplay.

Le jeu doit permettre de **changer de langue d'affichage** dans les réglages, à chaud (sans redémarrage). C'est une contrainte d'architecture posée dès le départ — trivial au jour 1, cauchemar à retrofit.

**Règle absolue :** aucun texte affiché ne vit dans le code ni dans les champs de données de gameplay — tout texte visible passe par une **clé de traduction**.

- **Système :** la localisation intégrée de Godot (`tr()`, fichiers CSV ou gettext .po, changement de locale à chaud).
- **Données de contenu :** les champs texte deviennent des clés — `"name_key": "material.chene.name"` au lieu de `"name": "Chêne"` — et les textes vivent dans `locale/fr.csv`, `locale/en.csv`, etc. GameData valide au boot que chaque clé référencée existe (clé manquante = warning console + affichage de la clé brute, jamais de crash).
- **Textes générés** (gabarits de quêtes [[Gabarit de quête]], rapports d'abstraction [[Abstraction hors-site]], noms de paliers de qualité [[Qualité d'artisanat]], effets d'objets) : une clé de gabarit **par langue avec placeholders** (`quest.chasse_prime.text = "Éliminez {count} {target} près de {location}."`) — jamais de concaténation de morceaux de phrases (l'ordre des mots varie selon les langues).
- **Hors localisation :** les noms propres saisis par le joueur (modèles sculptés, PNJ renommés) et les ids internes.
- **Changement à chaud :** signal EventBus `locale_changed` → toute l'UI se rafraîchit.
- **Langues de lancement : français, anglais, japonais, chinois.** Implication CJK à prévoir dès le choix des polices : la police d'UI doit couvrir les glyphes japonais et chinois (police à large couverture type Noto Sans CJK en fallback), tailles/retours à la ligne testés dans les 4 langues (le CJK est plus compact, l'allemand-like plus long — l'UI doit tolérer les deux). L'interdiction de concaténation (ci-dessus) est doublement critique en CJK où l'ordre grammatical diffère fortement.

**Contrainte permanente ([[Contraintes permanentes]]) :** *une seule langue au départ, mais toutes les chaînes affichables passent par `tr()` dès le premier écran.*

**Dès l'étape 1 du développement ([[Ordre de construction]]) :** *pipeline de localisation en place (clés `name_key`, `locale/fr.csv` + `locale/en.csv`, validation des clés au boot) — aucune string affichable en dur, jamais.*

**Risque ([[Risques majeurs]]) :** discipline permanente — coût quasi nul si respecté d'emblée, refonte massive sinon.

**Textes localisés ailleurs :** épithètes de monstres rares ([[Monstres rares]]), gabarits de dialogue ([[Dialogue PNJ]]), noms de royaumes ([[Génération des royaumes PNJ]]), tooltips ([[Tooltips contextuels]]).

> [!success] Codé le 2026-08-29 — la couverture de traduction est mesurée, l'anglais commence
> `tools/i18n_couverture.py` compare chaque `locale/*.csv` au **français, qui fait foi** (c'est la langue des notes) : nombre de clés traduites, manquantes par préfixe, et les clés **orphelines** (traduites mais disparues du français). État au 2026-08-29 : l'anglais couvrait **80 clés sur 1 983** (4 %) — le pipeline était en place depuis l'étape 1 mais le fichier n'avait jamais suivi le contenu. Première passe : **toutes les options du clic droit, les contenus de tuile, les statuts, les 58 compétences, les 19 classes et les 6 races** sont en anglais (+180 clés). Deuxième passe : **objets, meubles, plantes, créatures et espèces d'élevage** (+161 clés, 21 %). Troisième passe : les **163 matériaux** et les **84 titres de dirigeants** (les mots propres à une culture — Sultan, Jarl, Shōgun, Voïvode — restent tels quels, l'anglais n'anglicise que ce qui a un équivalent courant) — 34 %. Quatrième passe : le **premier bloc d'UI** (écrans, dialogue, création, carte, atelier, échange — 120 clés). Les raccourcis lettres suivent le mot anglais quand le code les lit ailleurs qu'en dur : **la touche affichée doit rester celle du clavier** (E équiper, K échanger…), donc la lettre entre parenthèses n'est pas traduite. Cinquième passe : **toute l'UI restante** (feuille, territoire, infobulles d'objet, quêtes, registre, HUD). L'anglais est de l'anglais **britannique** (armour, colour, defence) : c'est le registre du jeu. Sixième passe : les **178 modules** — le vocabulaire des capacités. Deux règles : un module garde son **nom propre** quand il en est un (Terroir, Riposte, Aegis), et les homonymes du français sont **désambiguïsés** par leur effet (*Curée* → *Quarry*, *Prise* → *Grapple*, *Botte* → *Lunge*, *Nappe* → *Slick*). Septième passe : les **68 recettes** et les **25 talents** (nom et description). Huitième passe : **tout le reste hors journal** — affixes, biomes, cultures, gouvernements, guildes, dialogue d'ambiance, quêtes, familles de composants, saisons, zones de coup, qualités, raretés. Une inversion de syntaxe au passage : le français nomme *« Épée en fer »*, l'anglais *« Iron sword »* — les gabarits `nom.*` sont réécrits dans l'ordre anglais. Neuvième et dernière passe : le **journal** (290 phrases d'événement). **L'anglais est complet** (1 983 clés sur 1 983, vérifié par `tools/i18n_couverture.py`) — le jeu se joue entièrement dans les deux langues. Le japonais et le chinois peuvent maintenant partir de l'anglais ou du français au choix ; ce sont des chantiers de traduction, plus des chantiers de code — un chantier de contenu, à faire par blocs. Le japonais et le chinois attendent qu'un anglais complet serve de source. L'outil ne fait **pas** échouer la validation (seuil à 100 %) : une traduction incomplète n'est pas une régression, mais elle se voit.

> [!success] Corrigé le 2026-08-31 — les virgules tronquaient treize traductions (et une clé était en double)
> Le lecteur de locales (`get_csv_line`, deux colonnes attendues) **coupait toute valeur à sa première virgule non protégée** : « +10,000 gold » s'affichait « +10 », le titre de la carte perdait la moitié de son aide, `journal.claim_refuse` ses trois derniers motifs, `famille.fibre` le chanvre et le coton… Attrapé en **regardant l'écran en anglais** (le menu Triche via `capture --langue en`) — la couverture i18n ne pouvait pas le voir, les clés existaient. Corrigé : les 13 valeurs à virgule (9 fr, 4 en) sont mises entre guillemets CSV, et le doublon `journal.reforge_refuse` retiré. Vérifié à l'écran (titre de la carte complet) ; couverture toujours 100 %.

> [!important] Constat du 2026-08-31 — les descriptions de modules échappent à la localisation
> Le détail du Composeur affiche `module.description` **lu tel quel depuis le JSON de données** (`data/modules/…`) : en anglais, l'écran mêle l'interface traduite et 178 descriptions restées en français (« Point — une seule cible… »). La couverture i18n ne le voit pas — ces textes ne passent pas par `locale/*.csv`. Deux voies quand la passe de traduction viendra (elle est planifiée « les textes peuvent suivre », § 4 de [[Vers la production]]) : donner aux modules un `description_key` sur le modèle de `name_key`, ou traduire les JSON par langue. Constat consigné, pas de correctif — c'est un lot de contenu, pas un bug ponctuel.

> [!success] Constaté le 2026-09-03 — `description_key` : **non codé**, les descriptions de modules restent en français
> Le callout ci-dessus le dit déjà : le composeur lit `description` tel quel depuis le JSON. Le champ `description_key` était la proposition pour les traduire ; elle n'a pas été faite, et c'est le seul texte joueur qui échappe encore à `i18n_couverture.py`. À faire le jour où l'anglais compte.

> [!success] Codé le 2026-09-04 — les descriptions des 236 modules passent par les CSV
> Une clé par module, `module.<id>.desc` : en français, le texte du JSON tel quel ; en anglais, sa traduction. Le composeur lit la clé (`Composeur.description_de`) et retombe sur `description` si elle manque — une nouvelle fiche s'affiche donc en français tant qu'on ne l'a pas traduite, plutôt que de montrer une clé nue. `description` reste dans le JSON, source d'écriture : `i18n_couverture.py` vérifie que `fr.csv` n'en dérive pas (une description changée dans les données sans son CSV est un échec). Plus aucun texte joueur n'échappe à la couverture. *(Même jour, vu sur la capture anglaise : les **familles** de noyaux — « Arme », « Contrôle »… — s'affichaient en français ; chaque module porte `famille_key`, trente et une clés `famille.<nom>.name`, le composeur les lit.)*

## Liens
- **Dépend de** : [[Data-driven design]], [[Contraintes permanentes]]
- **Alimente** : [[Arborescence du projet]], [[EventBus]], [[Écrans d'interface]], [[Gabarit de quête]], [[Dialogue PNJ]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Qualité d'artisanat]], [[Abstraction hors-site]], [[Monstres rares]], [[Risques majeurs]], [[Ordre de construction]]
