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

## Liens
- **Dépend de** : [[Data-driven design]], [[Contraintes permanentes]]
- **Alimente** : [[Arborescence du projet]], [[EventBus]], [[Écrans d'interface]], [[Gabarit de quête]], [[Dialogue PNJ]]
- **Voir aussi** : [[Identité visuelle chinoise]], [[Qualité d'artisanat]], [[Abstraction hors-site]], [[Monstres rares]], [[Risques majeurs]], [[Ordre de construction]]
