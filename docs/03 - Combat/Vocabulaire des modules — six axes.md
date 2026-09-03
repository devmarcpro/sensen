---
aliases: ["B.4", "Annexe B.4", "Module de compétence", "Six axes", "data/modules"]
tags: [combat, données, schéma, décidé]
domaine: combat
statut: décidé
etape: 0
---

Le schéma de données d'un module et les six axes du vocabulaire commun — la clé du volume de contenu.

**Le vocabulaire commun est la clé du volume** : des centaines de modules ne sont lisibles et produisibles que s'ils s'expriment tous dans le même petit ensemble de concepts. Un module ne « code » jamais un comportement particulier — il **compose** ces briques. Leçon de ToME : profondeur maximale, opacité nulle.

`data/modules/*.json` :

```json
{
  "id": "flamme",
  "name_key": "module.flamme.name",
  "elements": { "feu": 1.0 },
  "module_type": "noyau",
  "cout_ticks": 8,
  "cout_mana": 8,
  "cout_endurance": 0,
  "power_base": "2d6",
  "effets": ["degats"],
  "tags": ["noyau", "degats", "feu"],
  "grimoire_domains": ["feu", "destruction"],
  "book_type": "grimoire"
}
```

**Les six axes du vocabulaire :**

**1. FORME** — la géométrie de l'effet sur la grille :
`cible_unique` · `ligne` (droite, N tuiles) · `cone` (largeur croissante) · `croix` · `carre` (rayon N) · `anneau` (touche autour d'une tuile mais pas elle) · `diagonale` · `chemin` (suit le trajet du lanceur) · `soi` · `tuile` (au sol, pour les glyphes et zones persistantes)

**2. PORTÉE** — `[min, max]` en tuiles. Un `min` supérieur à 1 crée une zone morte (un arc long est mauvais au contact — la contrepartie naturelle de la distance). `taille` donne le rayon ou la longueur de la forme.

**3. CIBLE** — `ennemi` · `allie` · `soi` · `tuile` · `toute_entite`. Combiné à la forme, cela suffit à exprimer un soin de zone, un piège au sol ou une frappe unique.

**4. COÛTS** — `cout_ticks` (le tempo : un module lent et dévastateur contre un rapide et faible pour construire sa chaîne — les modules entrent dans la même économie que les armes), `cout_mana`, éventuellement `cout_endurance`. Les trois économies coexistent et définissent des archétypes.

**5. CONDITIONS** — prédicats positionnels et d'état, évalués avant application ; chacun peut être un prérequis ou un bonus :
`hauteur_relative` (plus haut / plus bas que la cible) · `cible_isolee` (aucun allié adjacent) · `cible_adjacente_a_allie` · `dos_ou_flanc` · `ligne_de_vue_degagee` · `pv_porteur < X %` · `pv_cible < X %` · `element_cible` · `segment_chaine_present` · `vecteur_de_lieu`

**6. EFFETS** — ce que le module produit, cumulables :
`degats` · `soin` · `statut` (avec durée en ticks) · `deplacement` (poussée, attraction, échange, téléportation) · `terrain` (élever/abaisser une tuile, créer un obstacle) · `invocation` (occupe une tuile — mur, bloqueur de vue, menace de flanc) · `glyphe` (effet persistant sur une tuile, déclenché à l'entrée) · **`tempo`** · **`saisie`**

**Les deux effets ajoutés le 2026-08-26** ([[Talents de classe]]) :

- **`tempo`** — agit sur les **compteurs d'action** de [[Boucle de tick]] : retarder (`compteur += N`), avancer (`compteur -= N`), voler (transfert d'un compteur à l'autre). C'est l'effet le plus puissant du vocabulaire, parce que le combat *est* une horloge.
  > ⚠️ **Garde-fou obligatoire :** un retard est un contrôle dur déguisé. Le tempo subi entre dans le **budget anti-stunlock** ([[Statuts de contrôle et anti-stunlock]]) — jamais plus de **20 ticks cumulés** sur une entité, pas de réapplication dans les **50 ticks** suivant la fin. Sans cette règle, une classe à tempo verrouille un adversaire indéfiniment.
- **`saisie`** — l'attaquant prend le contrôle du **déplacement** d'une entité adjacente. La cible **libère sa tuile** (elle est portée), ne peut plus agir (statut **Saisi**), et devient **projetable** : la lancer est un `deplacement` qui applique les dégâts de chute de [[Hauteur de terrain ±10]] — `(hauteur − 2) × 5`. La cible se débat par un jet de Force ([[Jet de compétence universel]]).

*Les deux respectent la règle du vocabulaire : ce sont des **briques génériques**, utilisables par n'importe quel module ou action de créature ([[Actions des créatures]]), pas des exceptions de classe.*

**Les MODIFICATEURS (façon Noita) opèrent sur ces axes**, pas sur des chiffres seulement : `étend la forme d'une tuile` · `transforme la ligne en cône` · `double la portée, divise la puissance` · `ajoute une condition en échange d'un bonus` · `répète l'effet sur une tuile adjacente` · `convertit l'élément`. C'est ce qui rend l'assemblage réellement combinatoire.

- **`module_type` — six valeurs, corrigé le 2026-08-26.** Le champ n'en acceptait que trois (`effet`, `modificateur`, `declencheur`), ce qui obligeait chaque module d'effet à embarquer sa propre géométrie — l'exact contraire de la décision fondatrice de [[Six types de modules et assemblage]]. Les six types y sont désormais tous représentables :

| Valeur | Rôle | Champs propres |
|---|---|---|
| `noyau` | la charge utile *(remplace `effet`)* | `power_base`, `cout_ticks`, `cout_mana` **ou** `cout_endurance`, `effets` |
| `forme` | la géométrie seule | `geometrie`, `portee_base`, `taille_base`, `cibles_valides`, `ligne_de_vue` |
| `modificateur` | altère le noyau suivant | `surcout_ticks`, `surcout_ressource` |
| `condition` | verrou qui accorde un bonus | `predicat`, `bonus`, `echec` |
| `declencheur` | diffère la charge qui suit | `surcout_ticks` |
| `liaison` | répète, disperse, propage | `surcout_ticks` |

**Un noyau n'a jamais de `forme` ni de `portee`** — ces champs appartiennent aux modules de forme.

**Et un seul type porte une monnaie.** `cout_mana` et `cout_endurance` n'existent **que** sur les noyaux. Les formes, conditions, déclencheurs et liaisons ne coûtent que des **ticks** ; le modificateur ajoute en plus un `surcout_ressource` **sans monnaie propre**, réglé dans celle du noyau qu'il sert. C'est ce qui permet à un seul *Concentration* de servir un mage et un guerrier. Détail et exemple chiffré : [[Modules]].
- `book_type` : `"grimoire"` (sorts) ou `"manuel"` (armes).
- **Aucun arbre de talents, aucun point à dépenser** : les modules s'obtiennent par le **loot et l'apprentissage** ([[Grimoires et manuels]]), montent de niveau **par l'usage** ([[Potentiel]]), et le build **émerge** de ce qu'on possède et de ce qu'on utilise.
- **Infobulle exhaustive obligatoire** : chaque module affiche ses valeurs **calculées pour le personnage courant** — forme, portée, coûts, conditions, dégâts attendus avec le détail. Aucune information cachée, aucun « environ ».

> [!success] Corrigé le 2026-08-29 — deux prédicats de condition que le code ne connaissait pas
> Dernier reste de la même famille : **Affinité** (`element_cible`) et **Pied ferme** (`porteur_immobile_depuis`) portaient un prédicat bien écrit… que `_evaluer_conditions` ne gérait pas. Or une condition inconnue tombe dans le défaut « faux », et une condition fausse **empêche la capacité de partir** : ces deux modules rendaient un sort **injouable**, pas simplement plus faible. *Affinité* compare l'élément dominant de la cible à celui désigné (`"X"` = celui du noyau) ; *Pied ferme* lit l'immobilité du lanceur (`immobile_depuis`, remis à zéro à chaque pas, posé pour Canalisation). `tools/audit_donnees.py` tient désormais la **liste des prédicats gérés** en miroir du code et refuse tout prédicat qu'il ne connaît pas — c'est le même contrôle que pour les effets de noyau, appliqué aux conditions.

> [!success] Codé le 2026-08-29 — l'infobulle exhaustive, enfin exhaustive
> La note l'exige (« chaque module affiche ses **valeurs calculées pour le personnage courant** — forme, portée, coûts, conditions, dégâts attendus avec le détail ») ; l'aperçu de l'écran *Composer* se contentait de la géométrie, de la portée, des ticks, du coût et du nom brut des effets. Il donne désormais, ligne par ligne : la **fourchette de dégâts attendue** avec son détail (dé de base + dés de bonus × multiplicateur), le **vecteur élémentaire** en pourcentages, chaque **condition** avec ce qu'elle exige et ce qu'elle rend, les **modificateurs** actifs (les drapeaux du plan, en clair), les **liaisons**, et les avertissements de ce qui n'est pas résolu. Tout est traduit — géométries, effets, drapeaux, prédicats et types de bonus ont leurs clés (fr et en). **Décision** : l'aperçu lit le **plan assemblé**, pas les fiches de modules — ce qu'il montre est donc exactement ce que la simulation exécutera, y compris les bonus de niveau du personnage courant.

> [!success] Renommé le 2026-09-03 — `cout_endurance` s'appelle `cout_vigueur`, et il existe `cout_sang_froid`
> Le designer a séparé la stat de la monnaie : la monnaie que les noyaux martiaux paient s'appelle **vigueur** (`cout_vigueur`, sur 92 modules et actions de créature), et une **troisième** monnaie est née le même jour, le **sang-froid** (`cout_sang_froid`, sur les noyaux de dextérité et de perception). L'axe 4 compte donc **quatre économies** — les ticks, et trois monnaies — mais la règle du dessus tient telle quelle : **un seul type porte une monnaie**, le noyau ; un noyau n'en porte jamais deux ; les modificateurs paient dans celle du noyau qu'ils servent. L'exemple JSON ci-dessus garde l'ancien nom de clé : il date de la transcription. Les trois monnaies sont décrites dans [[Mana]], [[Endurance]] (la vigueur) et [[Sang-froid]].

> [!success] Constaté le 2026-09-03 — `book_type` et `cibles_valides` n'ont pas été codés sous ces noms
> Un livre est un **objet** dont le type et le dossier disent la nature (`items/grimoire/`, `items/manuel/`, `livre_module`), et ses domaines sont dans `loot_rules.livres.domaines_grimoire` et `domaines_manuel` — pas de champ `book_type`. Une forme n'a pas de `cibles_valides` : depuis que la portée est un module (2026-09-01), c'est la **portée** et sa ligne de vue qui décident où l'on peut poser le sort, et la forme ne connaît que sa géométrie et sa taille.

## Liens
- **Dépend de** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Data-driven design]], [[Wu Xing — cycles et vecteurs]]
- **Alimente** : [[Six types de modules et assemblage]], [[Modules]], [[Familles de capacités de la grille]]
- **Voir aussi** : [[Structure compétences-modules-slots]], [[Mana]], [[Endurance]], [[Wu Xing hors combat]], [[Domaines de grimoires et manuels]], [[Localisation]]
