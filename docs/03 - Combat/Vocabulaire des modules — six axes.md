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

**Un noyau n'a jamais de `forme` ni de `portee`** — ces champs appartiennent aux modules de forme. Catalogue : [[Modules]].
- `book_type` : `"grimoire"` (sorts) ou `"manuel"` (armes).
- **Aucun arbre de talents, aucun point à dépenser** : les modules s'obtiennent par le **loot et l'apprentissage** ([[Grimoires et manuels]]), montent de niveau **par l'usage** ([[Potentiel]]), et le build **émerge** de ce qu'on possède et de ce qu'on utilise.
- **Infobulle exhaustive obligatoire** : chaque module affiche ses valeurs **calculées pour le personnage courant** — forme, portée, coûts, conditions, dégâts attendus avec le détail. Aucune information cachée, aucun « environ ».

## Liens
- **Dépend de** : [[Le vocabulaire des modules et l'absence d'arbre de talents]], [[Data-driven design]], [[Wu Xing — cycles et vecteurs]]
- **Alimente** : [[Six types de modules et assemblage]], [[Modules]], [[Familles de capacités de la grille]]
- **Voir aussi** : [[Structure compétences-modules-slots]], [[Mana]], [[Endurance]], [[Wu Xing hors combat]], [[Domaines de grimoires et manuels]], [[Localisation]]
