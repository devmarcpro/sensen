---
aliases: ["Carte — Êtres", "Carte Êtres"]
tags: [index, carte]
domaine: index
statut: décidé
etape: 9
---

**Un roi et un mouton sont la même fiche, avec des blocs différents remplis.** C'est de là que tout découle. 19 notes.

**Le socle, à lire en premier :**
- **[[Profils de PNJ]]** — un forgeron n'est pas une espèce, c'est `humain · La Braise · artisan · résident`. Les PNJ se **génèrent**, ils ne s'énumèrent pas.
- **[[Blocs de l'être]]** — le schéma unique en six blocs. *La différence n'est pas une branche dans le code, c'est un bloc vide dans la fiche.* Et sa conséquence : **rien n'est réservé** — le mouton ultime est une conséquence atteinte, pas une permission accordée.
- **[[Apparence — données et équipement]]** — ce qui définit l'apparence : la silhouette de l'espèce, le génome (héritable), l'équipement. Jamais le type.
- **[[Rôles de l'être]]** — sauvage → apprivoisé → résident → garde → bétail. Le prix, jamais l'interdiction. *(À ne pas confondre avec la [[Fonctions|fonction]], qui est le métier.)*

**Le socle**
- **[[Schéma unifié créature-PNJ]]** — pas de distinction technique entre monstre et villageois. *N'importe quelle créature peut devenir un compagnon.*
- **[[Squelette modulaire et points d'attache]]** — le pipeline paperdoll : des ancrages nommés, une couleur réservée par type d'attache. Réutilisé par les donjons, les objets, les véhicules.
- **[[Prompt de génération — bibliothèque de sprites]]** — le document du designer (2026-09-05) : image de synthèse pré-rendue années 90, gris neutre teinté par palette, les composants plutôt que les armes, le manifeste des 246 pièces et le gabarit d'une requête.
- **[[Schéma créature]]** — le format de données unique de tout être vivant.

**Le comportement**
- **[[IA des créatures]]** — Utility AI data-driven. *Créer ou modifier un comportement = éditer un JSON, zéro code.*
- **[[LOD de simulation]]** — trois niveaux, transitions invisibles. Le niveau logique est ce qui fait qu'un village paraît vivant.
- **[[Apprivoisement et recrutement]]** — une action dédiée d'abord, une relation ensuite.
- **[[Compagnons]]** — capacité d'escorte, deux statuts, mort réelle mais résurrection payante.

**La vie et la mort**
- **[[Âge des PNJ]]** — *la population du monde est un flux, pas un stock.* Les rois meurent aussi de vieillesse.
- **[[Familles et succession]]** — les liens familiaux pilotent la succession. Tous les royaumes n'ont pas de roi.
- **[[Monstres rares]]** — façon PSO, sans une seule nouvelle brique technique.

**L'identité**
- **[[Noms culturels]]** — préfixe + suffixe piloté par culture. Culture ≠ race, deux axes indépendants.
- **[[Génération de noms]]** · **[[Culture de nommage — schéma]]**
- **[[Dialogue PNJ]]** — menu contextuel façon Elona. *La profondeur vient des conditions, pas de la ramification.*

- **[[PNJ — traits, histoires et souhaits]]** — le programme C : deux traits, une histoire, un souhait, des opinions, la fiche par palier de relation.

## Liens
- **Voir aussi** : [[Sensen — Index général]], [[Carte — Société]], [[Carte — Contenu]], [[Carte des dépendances]]
