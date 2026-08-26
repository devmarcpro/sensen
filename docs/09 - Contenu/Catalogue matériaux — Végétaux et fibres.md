---
aliases: ["F.1 Végétaux", "Fibres", "Végétaux et fibres", "Catalogue fibres"]
tags: [contenu, matériaux, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 6
---

Les 8 fibres et peaux — la matière des constructions Matelassé et Cuir.

**Végétaux & fibres (8) — outil : faucille, compétence Herboristerie**

| Matériau | Dur | Den | Val | CMa | Fla | Iso | CÉl | Flo | Lum | Fer | Tra | Éla | Fri |
|---|--|--|--|--|--|--|--|--|--|--|--|--|--|
| Lin | 2 | 1 | 3 | 8 | 80 | 45 | 3 | 88 | 0 | 0 | 0 | 55 | 55 |
| Coton | 2 | 1 | 4 | 5 | 85 | 55 | 2 | 90 | 0 | 0 | 0 | 60 | 55 |
| Paille | 1 | 1 | 1 | 3 | 95 | 50 | 2 | 92 | 0 | 0 | 0 | 70 | 60 |
| Chanvre | 3 | 2 | 3 | 10 | 75 | 40 | 3 | 86 | 0 | 0 | 0 | 65 | 55 |
| Laine | 2 | 2 | 6 | 8 | 70 | 75 | 2 | 85 | 0 | 0 | 0 | 70 | 60 |
| Soie | 4 | 1 | 18 | 30 | 55 | 45 | 5 | 90 | 0 | 0 | 10 | 90 | 35 |
| Cuir | 8 | 4 | 5 | 5 | 40 | 50 | 15 | 60 | 0 | 0 | 0 | 55 | 55 |
| Fourrure | 3 | 2 | 7 | 5 | 60 | 85 | 5 | 80 | 0 | 0 | 0 | 65 | 65 |

**Constructions d'armure ([[Armure par zone et constructions]]) :** Matelassé (tissus, fibres — fort contre contondant, faible contre perforant) · Cuir (peaux paramétriques — fort contre tranchant léger, faible contre perforant).

**Isolation décisive ([[Application des stats de matériau]]) :** *la laine/fourrure en toundra* — `degats_subis *= (1 - isolation_armure / 125)`. La **Fourrure** (Iso 85) et la **Laine** (75) sont les matériaux de la toundra ([[Météo]] : la toundra exige la fourrure).

**Fragilité en tempête ([[Météo]]) :** arrachage des blocs très fragiles exposés (`durete <= 3` ET non-abrités) — **paille**, chaume.

**Peaux paramétriques ([[Catalogue matériaux — Paramétriques]]) :** *Peau de [créature]* → cuir par tannage, dureté/isolation ∝ Endurance de la source. Le **Châtaignier** est riche en tanin ([[Catalogue matériaux — Bois]]).

**Transformations ([[Stations de transformation]]) :** Atelier de tissage — fibres → tissu, paille → chaume, tissu → sangles/rembourrages ([[Composants]]).

## Liens
- **Dépend de** : [[Matériaux — 13 stats]], [[Catégories de matériaux]]
- **Alimente** : [[Armure par zone et constructions]], [[Composants]], [[Stations de transformation]]
- **Voir aussi** : [[Application des stats de matériau]], [[Météo]], [[Catalogue matériaux — Paramétriques]], [[Palette de couleurs des matériaux]], [[Plantes]]
