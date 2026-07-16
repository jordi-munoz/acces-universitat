# Contingut dels fitxers de dades de preinscripció (2020-2025)

Aquest document descriu el contingut de cadascuna de les pestanyes dels fitxers `Dades_20XX.xlsx` de la carpeta [01-dades](../01-dades/), elaborat a partir de les notes metodològiques oficials (`03-documentacio/Nota_metodologica_20XX.pdf`) i de la inspecció directa de les capçaleres de cada pestanya dels sis fitxers Excel.

## 1. Origen i abast de les dades

Els fitxers contenen les dades de preinscripció universitària publicades per l'**Oficina d'Accés a la Universitat** del **Consell Interuniversitari de Catalunya** (Generalitat de Catalunya). Corresponen a l'accés als estudis de **grau** de:

- Les set universitats públiques de Catalunya (UB, UAB, UPC, UPF, UdG, UdL, URV).
- La Universitat de Vic – Universitat Central de Catalunya (UVic-UCC).
- Els centres adscrits a aquestes universitats.
- En alguns apartats concrets (ja indicat explícitament a la pestanya corresponent), també universitats privades i la UOC.

També s'hi inclouen dades del **Màster de formació del professorat** d'ESO/batxillerat, FP i ensenyaments d'idiomes (bloc 7.6/7.7).

## 2. Estructura dels fitxers

Cada fitxer `Dades_20XX.xlsx` correspon a l'edició d'un any de la preinscripció (convocatòries de febrer, més grans de 40/45 anys i juny, entre d'altres) i conté entre **43 i 44 pestanyes**. El nom de cada pestanya és un codi numèric (`1.1.1`, `2.3`, `7.5`...) que es correspon amb l'índex de la nota metodològica de l'any respectiu. El primer dígit identifica el bloc temàtic:

| Bloc | Contingut general |
|---|---|
| 1 | Resultats de la preinscripció al tancament (sol·licitants, assignats, matriculats) |
| 2 | Estudiants de fora de Catalunya |
| 3 | Procedència geogràfica (comarca/província/país) dels sol·licitants i assignats |
| 4 | Comparatives interanuals |
| 5 | Notes de tall |
| 6 | Reconeixement/convalidació de crèdits |
| 7 | Informe de matrícula |

**Advertència tècnica**: la pestanya `1.4.1` es diu literalment `"1.4.1."` (amb punt final) als sis fitxers — cal tenir-ho en compte si es referencia per codi en un script. Alguns fitxers també reporten un `max_column` artificialment enorme (milers de columnes) en pestanyes com `1.1.1` o `2.1.1`; és fruit de cel·les formatades sense dades i no de contingut real (les dades útils es concentren sempre dins les primeres ~10-90 columnes descrites més avall).

## 3. Contingut detallat per pestanya

### Bloc 1 — Resultats de la Preinscripció al tancament

**1.1 Sol·licitants**

| Pestanya | Contingut | Columnes/estructura observada |
|---|---|---|
| `1.1.1` | Sol·licitants en 1a preferència per via d'accés i gènere. Totes les convocatòries (febrer, més grans de 40 anys, juny). | Files = vies d'accés (0, 2, 4, 7, 8, 9, 10, 11...); columnes agrupades per convocatòria, cada una amb Dones/Homes/Total. |
| `1.1.2` | Sol·licitants per preferència (1a, 2a, 3a...) i gènere, per centre d'estudi. Convocatòria de juny. | Codi, Nom del centre, Població + blocs Dones/Homes/Total per cada ordre de preferència. |
| `1.1.3` | Sol·licitants en 1a preferència per centre d'estudi, gènere i via d'accés (Via 0 PAU, Via 2 titulats, Via 4 CFGS...). Juny. | Codi, Nom del centre, Població + blocs per via d'accés. |
| `1.1.4` | Sol·licitants en 1a preferència per edat, gènere i via d'accés. Juny. | Files = trams d'edat; columnes per via d'accés (Dones/Homes/Total). |
| `1.1.5` | Sol·licitants en 1a preferència per via PAU/CFGS amb percentatges respecte a les places ofertes. Juny, al tancament. | Codi, centre, població, places de preinscripció, total assignats, sol·licitants PAU/CFGS i percentatges. |
| `1.1.6` | Rànquing dels centres d'estudi més sol·licitats en 1a preferència (tots els estudis agregats per centre). Juny. | Ordre, Codi, Nom del centre, Població, Sigles universitat, Sol·licitants (Dones/Homes/Total). |
| `1.1.7` | Igual que `1.1.6` però agrupat/desglossat per universitat. Juny. | Ordre, Codi, Nom del centre, Població, Sol·licitants (Dones/Homes/Total), agrupat per universitat. |
| `1.1.8` | Resultats de l'enquesta socioeducativa als sol·licitants en 1a preferència: estudis i ocupació dels pares, coneixement d'idiomes i d'eines informàtiques. Juny. | Taules creuades (Nombre / %) per cada variable (estudis mare/pare, ocupació, idiomes...). |

**1.2 Assignats** (mateixa estructura que el bloc 1.1, aplicada als assignats en lloc dels sol·licitants; no hi ha equivalent a `1.1.6`-`1.1.8`)

| Pestanya | Contingut |
|---|---|
| `1.2.1` | Assignats totals per via d'accés i gènere. Totes les convocatòries. |
| `1.2.2` | Assignats totals per preferència i gènere, per centre d'estudi. Juny. |
| `1.2.3` | Assignats totals per centre d'estudi, gènere i via d'accés. Juny. |
| `1.2.4` | Assignats totals per edat, gènere i via d'accés. Juny. |
| `1.2.5` | Assignats totals per via PAU/CFGS amb percentatges. Juny, al tancament. |

**1.3 Matriculats de nou accés**

| Pestanya | Contingut |
|---|---|
| `1.3.1` | Matriculats totals per via d'accés. Totes les convocatòries, amb comparativa dels 2 anys anteriors (columnes "Total general 20XX/20XX-1/20XX-2"). |
| `1.3.2` | Matriculats totals per via PAU/CFGS amb percentatges, per centre d'estudi. Juny, al tancament. |

**1.4 Anàlisi estadístic (universitats públiques catalanes + UVic-UCC)**, comparant sempre l'any en curs amb l'anterior

| Pestanya | Contingut |
|---|---|
| `1.4.1.` *(punt final al nom)* | Sol·licitants en 1a preferència, total d'assignats i total de matriculats de nou accés — dades generals agregades. Conté diverses sub-taules en una mateixa pestanya (per això té centenars de columnes). |
| `1.4.2` | El mateix desglossat per universitat, tipologia de centre, branca/àmbit de coneixement i gènere. |
| `1.4.3` | El mateix desglossat per universitat, tipologia de centre i gènere. |

### Bloc 2 — Estudiants de fora de Catalunya

| Pestanya | Contingut |
|---|---|
| `2.1.1` | Sol·licitants en 1a preferència, assignats i matriculats de fora de Catalunya, a les universitats públiques catalanes i la UVic-UCC. Comparativa juny any actual vs. anterior, per centre. |
| `2.1.2` | El mateix per a universitats que **no** participen en el procés de preinscripció. |
| `2.2` | Sol·licitants, assignats i matriculats de fora de Catalunya per Comunitat Autònoma de residència i gènere. Comparativa 2 anys. |
| `2.3` | Sol·licitants, assignats i matriculats de fora de Catalunya per nacionalitat (llistat de països) i gènere. Tancament de l'any. |

### Bloc 3 — Procedència dels sol·licitants i assignats

| Pestanya | Contingut |
|---|---|
| `3.1.1` | Llistat detallat de sol·licitants totals per preferència, centre d'estudi, població, comarca i gènere. Juny (taula molt extensa: 17.700-19.000 files, una fila per combinació centre/comarca). |
| `3.1.2` | El mateix per als assignats totals (9.000-10.300 files). |
| `3.1.3` | Gràfic resum: sol·licitants en 1a preferència, assignats totals i matriculats de nou accés per comarca i gènere, amb el % de matriculats respecte als assignats. |
| `3.2` | Matriu de mobilitat: assignats totals a les universitats públiques catalanes i la UVic-UCC per província d'origen/destí. Comparativa dels 3 darrers anys, en percentatges. |
| `3.3` | Sol·licitants, assignats i matriculats de fora de l'Estat espanyol, per nacionalitat i gènere. Comparativa dels 3 darrers anys (totes les convocatòries excepte febrer). |

### Bloc 4 — Comparatives interanuals

| Pestanya | Contingut |
|---|---|
| `4.1.1` | Sol·licitants i assignats en 1a preferència i assignats totals, per branca de coneixement i universitat. Comparativa 1a assignació de juny, 2 anys. |
| `4.1.2` | Sol·licitants i assignats per tipologia de centre. Comparativa 1a assignació de juny, 2 anys. |
| `4.1.3` | Sol·licitants i assignats per preferència i gènere. Comparativa juny, 2 anys. |
| `4.2` | Rànquing dels estudis més sol·licitats en 1a preferència. Comparativa dels 3 darrers anys. |
| `4.3` | Taula històrica **fixa** (no s'actualitza any rere any): evolució de les places per universitat, tipologia de centre i àmbit d'estudi, període 2007-2010. |
| `4.4` | Evolució de les places per universitat, tipologia de centre i branca de coneixement, finestra mòbil dels 5 darrers anys. |

### Bloc 5 — Notes de tall

| Pestanya | Contingut |
|---|---|
| `5.1` | Comparativa de la nota de tall de la 1a assignació amb la de l'última assignació, per centre d'estudi i població. Convocatòria de juny, ordre alfabètic. |
| `5.2` | Taula històrica **fixa**: evolució 2000-2009 de les notes de tall. |
| `5.3` | Evolució de les notes de tall dels graus i títols propis superiors (PAU/CFGS i FP, vies 0-7/4-8), 1a assignació de juny, per universitat. Finestra mòbil d'~10 anys (p. ex. 2016-2025 al fitxer de 2025). |

### Bloc 6 — Reconeixement/convalidació de crèdits

| Pestanya | Contingut |
|---|---|
| `6` | Estudiants de nou accés que han sol·licitat el reconeixement de crèdits de CFGS en estudis de grau, per centre i titulació d'origen/destí i nombre d'estudiants. Anomenada "Convalidació de crèdits" fins al 2023 i "Reconeixement de crèdits" des del 2024 (vegeu §4). |

### Bloc 7 — Informe de matrícula

| Pestanya | Contingut |
|---|---|
| `7.1` | Total d'estudiants matriculats de nou accés a universitats públiques i privades que participen en la preinscripció, per via d'accés, oferta de places i centre. |
| `7.2` | Percentatge d'estudiants matriculats de nou accés (unificant vies 0-7 i 4-8), per via d'accés i centre. |
| `7.3` | Total d'estudiants matriculats de nou accés a universitats que **no** participen en la preinscripció, per via d'accés. |
| `7.4` | El mateix, per procedència (Catalunya / resta de l'Estat / estrangers UE / estrangers fora UE). |
| `7.5` | Total d'estudiants matriculats de nou accés a les universitats catalanes, per universitat. Quadre comparatiu de finestra mòbil de 10 anys. |
| `7.6` | Total d'estudiants matriculats al Màster de Formació de Professorat (ESO/batxillerat, FP i idiomes), any en curs, per especialitat i centre. |
| `7.7` | Quadre comparatiu històric (10 anys) del mateix Màster de Formació de Professorat, per universitat. **Només present des del fitxer de 2022 en endavant** (vegeu §4). |

## 4. Diferències detectades entre els fitxers anuals

- **Nombre de pestanyes**: els fitxers 2020 i 2021 tenen **43 pestanyes** (fins a `7.6`); a partir de 2022 en tenen **44**, ja que s'hi afegeix la pestanya `7.7` (comparativa històrica del Màster de formació de professorat).
- **Canvi de nom del bloc 6**: la nota metodològica anomena aquest bloc *"Convalidació de crèdits"* als anys 2020-2023 i *"Reconeixement de crèdits"* als anys 2024-2025. El codi de pestanya (`6`) i el seu contingut es mantenen equivalents.
- **Entrada `1.4.4.` a l'índex**: les notes metodològiques de 2020, 2021 i 2022 llisten un punt `1.4.4.` buit (sense títol) a l'índex, que **no correspon a cap pestanya real** del fitxer Excel (el bloc 1.4 només arriba fins a `1.4.3`). Als índexs de 2023-2025 aquesta entrada buida ja no apareix.
- **Creixement del volum de dades**: pestanyes com `3.1.1`/`3.1.2` (desglossament per comarca) creixen en nombre de files any rere any (p. ex. `3.1.1` passa d'unes 17.700 files el 2020 a unes 19.000 el 2025), reflectint l'augment del nombre de sol·licitants.
- **Taules històriques fixes**: `4.3` (places 2007-2010) i `5.2` (notes de tall 2000-2009) es repeteixen amb el mateix contingut als sis fitxers; no s'actualitzen. Els quadres comparatius amb finestra mòbil (`4.4`, `5.3`, `7.5`, `7.7`) sí que avancen any rere any.

## 5. Fonts

- Fitxers de dades: [01-dades/Dades_2020.xlsx](../01-dades/Dades_2020.xlsx) … [01-dades/Dades_2025.xlsx](../01-dades/Dades_2025.xlsx)
- Notes metodològiques oficials: `Nota_metodologica_2020.pdf` a `Nota_metodologica_2025.pdf`, en aquesta mateixa carpeta.
- Estructura de pestanyes i capçaleres verificades directament sobre els fitxers Excel (Python/openpyxl).
