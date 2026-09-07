---
aliases: ["Pools de noms des cultures", "Pools de noms", "F.14"]
tags: [contenu, société, catalogue, décidé]
domaine: contenu
statut: décidé
etape: 9
---

> [!success] Rédigé le 2026-08-26
> Les pools des 6 cultures restantes, produits sur délégation — transcription directe en `data/name_cultures/` ([[Culture de nommage — schéma]]). Premier jet phonétique, enrichissable sans code (ajouter des entrées aux pools).

> [!warning] Corrigé le 2026-08-26 — les pools sont **genrés**
> Le premier jet ne séparait pas les terminaisons masculines des féminines, ce qui produisait des « Tariq » femmes et des « Freydis » hommes. `prenom_b` devient **`prenom_b_m` / `prenom_b_f`**, et `famille_b` est genré là où la langue l'exige : nordique **-sson ⟋ -sdottir**, slave **-ov ⟋ -ova**, **-sky ⟋ -ska**. Ailleurs les deux listes sont identiques. Découvert en générant des PNJ ([[Exemples — dix PNJ générés]]).

Les pools A+B des 7 cultures ([[Cultures de nommage]]) — la Sino est déjà écrite en [[Culture de nommage — schéma]]. *(Sylvestre, Ignée et Résonance sont retirées avec les races inventées — [[Races]].)* Concaténation directe ([[Génération de noms]]) ; titres au format m ⟋ f.

## Latine/romane (Humain)
- `prenom_a` : Mar, Luc, Aur, Val, Cass, Jul, Oct, Fla, Tib, Sev · `prenom_b_m` : ius, ianus, io, us · `prenom_b_f` : ia, illa, ine, a
- `famille_a` : Val, Corn, Aem, Claud, Flav, Jul, Marc, Cass · `famille_b_m` : erius, ianus, ius, inus · `famille_b_f` : elia, ella, ia
- `ville_a` : Alta, Nova, Porta, Villa, Aqua, Castra, Monte, Terra · `ville_b` : rium, lia, num, ona, ensis, ura
- `titres` : monarchie Roi ⟋ Reine · république Consul ⟋ Consule · théocratie Grand Pontife ⟋ Grande Pontife · ploutocratie Magnat ⟋ Magnate · dictature Imperator ⟋ Imperatrix · guilde Grand Maître ⟋ Grande Maîtresse

## Nordique/germanique (Nain, Humain)
- `prenom_a` : Bjor, Sig, Thor, Ast, Ing, Rag, Eir, Gun, Hal, Frey · `prenom_b_m` : n, vald, nar, mund · `prenom_b_f` : rid, a, hild, dis
- `famille_a` : Sten, Ulf, Harald, Grim, Dal, Eken, Bryn, Kol · `famille_b_m` : **sson**, gard, strand, berg, vik · `famille_b_f` : **sdottir**, gard, strand, berg, vik *(patronyme genré)*
- `ville_a` : Nord, Frost, Jarn, Hav, Skog, Sten, Ulfs, Vind · `ville_b` : heim, vik, borg, fjord, dal, gard
- `titres` : monarchie Haut-Roi ⟋ Haute-Reine · république Premier Jarl ⟋ Première Jarl · théocratie Godi ⟋ Gydja · ploutocratie Maître des Guildes ⟋ Maîtresse des Guildes · dictature Seigneur de Guerre ⟋ Dame de Guerre · guilde Grand Maître ⟋ Grande Maîtresse

## Nipponne (Humain) — `name_order: nom_prenom`
- `prenom_a` : Hana, Kei, Aki, Yori, Masa, Tomo, Hiro, Kazu, Rin, Sato · `prenom_b_m` : to, shi, ki, o · `prenom_b_f` : ko, mi, ra, e
- `famille_a` : Yama, Kawa, Fuji, Naka, Taka, Mori, Ishi, Hoshi · `famille_b` : moto, mura, shima, da, no, saki
- `ville_a` : Naga, Yoko, Kane, Aki, Fuku, Matsu, Kuro, Shiro · `ville_b` : saki, hama, zawa, oka, yama, kawa
- `titres` : monarchie Empereur ⟋ Impératrice · république Chancelier ⟋ Chancelière · théocratie Grand Kannushi ⟋ Grande Miko · ploutocratie Marchand Suprême ⟋ Marchande Suprême · dictature Shōgun ⟋ Shōgun · guilde Grand Maître ⟋ Grande Maîtresse

## Slave (Humain)
- `prenom_a` : Mir, Bog, Vlad, Svet, Rad, Stan, Dra, Lud, Yar, Zor · `prenom_b_m` : oslav, omir, imir, ek, an · `prenom_b_f` : ana, oslava, ka
- `famille_a` : Nov, Volk, Kov, Petr, Sokol, Bel, Cern, Zeman · `famille_b_m` : **ov**, ic, ek, **sky** · `famille_b_f` : **ova**, ic, **ska** *(accord genré)*
- `ville_a` : Novo, Belo, Staro, Volko, Zlato, Cerno, Vyso, Mokro · `ville_b` : grad, gorod, pol, slav, vice, dol
- `titres` : monarchie Tsar ⟋ Tsarine · république Starosta ⟋ Starosta · théocratie Patriarche ⟋ Matriarche · ploutocratie Boyard des Marchés ⟋ Boyarde des Marchés · dictature Voïvode ⟋ Voïvode · guilde Grand Maître ⟋ Grande Maîtresse

## Arabo-berbère (Humain)
- `prenom_a` : Am, Yas, Kar, Nad, Sal, Tar, Zah, Far, Ras, Lay · `prenom_b_m` : ir, im, iq, id · `prenom_b_f` : mine, ia, ah, ra
- `famille_a` : al-Rash, Ben, Aït, al-Mans, Bou, al-Fas, Tazi, Idris · `famille_b` : id, ani, oui, our, si, *(vide)*
- `ville_a` : Al-Qas, Marra, Tam, Ouar, Beni, Sidi, Aza, Tin · `ville_b` : bah, kech, azert, zazate, mellal, ghir
- `titres` : monarchie Sultan ⟋ Sultane · république Cheikh du Conseil ⟋ Cheikha du Conseil · théocratie Calife ⟋ Califa · ploutocratie Grand Vizir des Marchés ⟋ Grande Vizir des Marchés · dictature Émir de Guerre ⟋ Émira de Guerre · guilde Grand Maître ⟋ Grande Maîtresse

## Celte (Elfe, Humain)
- `prenom_a` : Bran, Aoif, Cael, Deir, Fionn, Gwen, Mael, Rhi, Tal, Eil · `prenom_b_m` : an, ys, iesin, in · `prenom_b_f` : wen, e, dre, annon
- `famille_a` : Mac, O', Pen, Caer, Ap, Dun, Kil, Glen · `famille_b` : Bran, Cormac, Gwyn, Dara, Owen, more
- `ville_a` : Dun, Caer, Inver, Bally, Glen, Kil, Aber, Llan · `ville_b` : more, keld, wyn, dara, loch, brae
- `titres` : monarchie Haut-Roi ⟋ Haute-Reine · république Brehon ⟋ Brehon · théocratie Archidruide ⟋ Archidruidesse · ploutocratie Prince des Foires ⟋ Princesse des Foires · dictature Champion-Régent ⟋ Championne-Régente · guilde Grand Maître ⟋ Grande Maîtresse

*(L'anarchie n'a pas de titre — pas de leadership_role, [[Gouvernance, lois et diplomatie]]. Les titres sont des text_keys localisées, [[Localisation]].)*

> [!success] Codé — trace ajoutée le 2026-09-04
> Les pools sont transcrits dans `data/name_cultures/` (générés par `tools/gen_name_cultures.py`), séparés par genre — voir [[Cultures de nommage]].

> [!important] Décidé le 2026-09-07, 19 h — tout est syllabique, et le monde compte vingt-et-une cultures (designer : « fais du syllabique pour tout » ; « rajoute encore des cultures » ; « un nom de famille n'a pas de sexe »)
> Les listes de noms écrites une heure plus tôt ne sont pas jetées : elles servent de **mine**. Chaque nom est coupé à une frontière de syllabe et ses deux moitiés entrent dans les pools — la saveur d'une langue reste, le nombre de noms possibles n'a plus de limite. **49 549 prénoms possibles** dans le monde, contre 840 ce matin.
> - **Deux familles de coupe, jamais mélangées** : soit le début finit par une voyelle et la fin commence par une consonne (`Niko|laos`), soit l'inverse (`Astr|id`). Mélanger les deux fabrique des grappes de consonnes — la première version rendait « Rufn », « Olrstein », « Prech ». Pour chaque culture et chaque genre, on garde la famille qui rend le plus, et l'on s'y tient.
> - **Le début est genré autant que la fin** : un début d'homme ne sert jamais à une femme. Les désinences des deux genres sont disjointes. Deux cents tirages nordiques rendent 156 prénoms d'homme et 155 de femme, **aucun en commun**.
> - **Un nom de famille n'a pas de sexe** (designer). Le patronyme nordique lui-même prend « -sson » pour tous, comme la Suède moderne où une femme est Andersson.
> - **Ce qui ne se coupe pas garde sa forme** : un nom de famille moderne est atomique (Schmidt, Rossi, Martin) — le couper donnait « Svenssansson ». Il reste donc entier, avec une désinence vide. Deux cultures font exception parce que leur nom se **forme** : le patronyme nordique (souche + sson) et le nom celte (Mac, O', Fitz, Ap + souche), écrits à la main. Le chinois aussi : sa seconde syllabe porte le genre (wei, jun, hao pour lui ; mei, lan, hua pour elle).
> - **Trente-neuf cultures** (designer : « encore plus », trois fois) — les vingt-neuf plus **tibétaine, malaise, khmère, javanaise, arménienne, géorgienne, éthiopienne, lakota, inuite, nguni**. **74 560 prénoms possibles** dans le monde, et aucune culture sous le seuil (150 prénoms d'homme, 150 de femme, 40 noms de famille).
> - **Vingt-neuf cultures** (designer : « encore plus ») — les vingt-et-une ci-dessous plus **finnoise, balte, roumaine, néerlandaise, vietnamienne, polynésienne, quechua, yoruba**. Trois d'entre elles ont demandé des pools écrits à la main, parce que leur langue ne se coupe pas comme les autres : le **chinois** (la seconde syllabe porte le genre), le **vietnamien** (le nom du milieu porte le genre — Nguyen **Van** Minh, Tran **Thi** Lan) et le **quechua** (des prénoms de femme trop courts, qui reçoivent les seconds mots de la langue : Sisa la fleur, Killa la lune, Quri l'or). **59 089 prénoms possibles** dans le monde.
> - **Vingt-et-une cultures** : latine, nordique, slave, celte, nipponne, sino, arabo-berbère, hellénique, indienne, swahilie, persane, germanique, italienne, française, suédoise, ibérique, magyare, turque, coréenne, mongole, nilotique — chacune avec ses prénoms, ses noms, ses villes, ses six titres de gouvernement aux deux genres et ses six noms d'ère, en français et en anglais.

> [!important] Décidé le 2026-09-07, 18 h — de vraies listes, séparées homme et femme, et quatre cultures de plus (designer : « développe beaucoup plus les noms / prénoms / culture, fais la séparation homme et femme » ; « rajoute des cultures pour les noms »)
> Le nommage assemblait deux syllabes (`prenom_a` + `prenom_b_m`/`_f`) : **quarante prénoms d'homme et quarante de femme par culture**, et des assemblages parfois improbables. Dans une ville de deux cents habitants, on croisait trois fois le même nom.
> - **Des listes explicites** : chaque culture porte désormais `prenoms_m`, `prenoms_f` et `familles` — **soixante prénoms par genre et cinquante noms de famille**, écrits un par un, soit près de six mille noms complets possibles par culture au lieu de quarante. `Noms.prenom` et `Noms.famille` y puisent quand elles existent ; les pools syllabiques restent le **repli** d'une culture qui n'aurait pas de listes, et continuent de nommer les villes.
> - **La séparation est nette** : aucun prénom ne figure dans les deux listes. Le test l'a d'ailleurs prouvé nécessaire — sept prénoms sino (Zhen, Jing, Ping, Qing, Shan, Wen, Xin) étaient dans les deux, ce qui est juste dans la vraie vie mais brouille ce que le designer demande ; les hommes en ont reçu des équivalents sans ambiguïté (Zhenyu, Jingwei, Pingan…).
> - **Quatre cultures de plus** : hellénique, indienne, swahilie, persane — chacune avec ses prénoms, ses noms, ses pools de villes, ses six titres de gouvernement au masculin et au féminin, et ses six noms d'ère. Le monde compte **onze cultures**.
> Ce qui reste à faire : les patronymes vivants (une nordique devrait être « …sdóttir » du prénom de son père, une slave « …ova » — aujourd'hui les listes de familles sont neutres), et les titres des nouvelles cultures ne sont traduits qu'en français et en anglais.

## Liens
- **Dépend de** : [[Cultures de nommage]], [[Culture de nommage — schéma]], [[Génération de noms]]
- **Alimente** : [[Noms culturels]], [[Génération des royaumes PNJ]]
- **Voir aussi** : [[Races]], [[Localisation]], [[Identité visuelle chinoise]]
