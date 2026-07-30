# Més demanda, les mateixes places, notes de tall més altes

Anàlisi de l'accés als graus de les universitats públiques de Catalunya a partir de les
dades de preinscripció de l'**Oficina d'Accés a la Universitat** (OAU), 2016–2025.

📊 **[Llegeix l'informe](https://jordi-munoz.github.io/acces-universitat/)**

## Què hi trobareu

Entre 2020 i 2025 els sol·licitants en 1a preferència van créixer un 13% (de 55.815 a
63.038) mentre l'oferta de places només ho feia un 4% (de 40.213 a 41.801). La conseqüència
és que la mediana de la nota de tall ha passat de 5,92 (2016) a 8,20 (2025).

L'informe posa a prova l'explicació alternativa —que les notes de tall pugin perquè
l'alumnat arriba amb millors notes— i la descarta: en el mateix període, la nota d'accés
mitjana de qui es presenta a les PAU només va pujar 0,14 punts, davant dels 2,28 de la
mediana del tall. El curs 2025, amb el model nou de PAU, la nota d'accés mitjana fins i tot
va **baixar** mentre la nota de tall **pujava**.

## Estructura

```
01-dades/          Dades d'entrada (NO versionades, vegeu més avall)
02-code/
  R/read_sheets.R      Lectors de les pestanyes dels Excel de l'OAU
  R/build_series.R     Construcció de les sèries temporals
  R/plots.R            Figures (ggplot2)
  R/read_matriculats.R Lectura i agregació dels alumnes matriculats (dades obertes)
  R/forecast_demanda.R Model de projecció de la demanda a partir de les cohorts
  report.qmd           Informe (Quarto)
  run_analysis.R       Pipeline complet de l'informe
  build_matriculats.R  Sèrie d'alumnes per ensenyament i nivell
  build_forecast.R     Projecció de la demanda 2026-2037
  tests/               Proves (testthat) amb xifres de referència
03-documentacio/   Descripció de les pestanyes dels Excel + enllaços a les
                   notes metodològiques oficials
04-output/         Resultats: informe HTML, figures i sèries en CSV
```

## Dades d'entrada

**Els Excel de l'OAU no es versionen** (vegeu [`.gitignore`](.gitignore)): són fitxers de
tercers, d'uns 60 MB, i aquest repositori prefereix **enllaçar-ne la font original** en
comptes de redistribuir-los. Els resultats processats sí que es versionen, a
[`04-output/series_2016_2025.csv`](04-output/series_2016_2025.csv): es poden consultar les
sèries sense necessitat de descarregar res.

Per reproduir l'anàlisi des de zero només cal **descarregar els Excel**; l'altre fitxer de
dades ja és al repositori.

**1. `Dades_2020.xlsx` … `Dades_2025.xlsx`** *(cal descarregar-los)* — un fitxer per any, a
[Informes i estadístiques de la preinscripció universitària][oau] (OAU, Departament de
Recerca i Universitats). Cal desar-los a `01-dades/` amb aquests noms exactes: el codi
n'extreu l'any del nom del fitxer.

**2. [`01-dades/pau_cat_resultats_2010_2025.csv`](01-dades/pau_cat_resultats_2010_2025.csv)**
*(ja inclòs)* — resultats agregats de les PAU a Catalunya (convocatòria ordinària de juny).
És una compilació pròpia i no es pot descarregar d'una sola font, per això sí que es
versiona, tot i ser a la mateixa carpeta. El format és:

| Columna | Descripció |
|---|---|
| `Curs_academic` | Curs en format `2024/25` |
| `Presentats` | Estudiants presentats a la convocatòria de juny |
| `Aprovats` | Estudiants aprovats |
| `Mitjana_Expedient` | Mitjana de l'expedient de batxillerat (0–10) |
| `Mitjana_PAU` | Mitjana de les proves (0–10) |
| `Expedient_menys_PAU` | Diferència entre les dues anteriors |
| `Mitjana_Acces` | Nota d'accés = 0,6 × expedient + 0,4 × PAU |

> **Convenció d'anys**: el curs `2024/25` correspon a les proves de **juny de 2025**, que és
> l'any que casa amb la preinscripció d'aquell estiu. El codi data cada fila per l'any de
> les proves, de manera que la sèrie va de 2011 a 2026. Hi ha una prova que ho verifica.

**3. `01-dades/Alumnes_matriculats_per_ensenyament_i_unitats_dels_centres_docents_*.csv`**
*(cal descarregar-lo)* — dades obertes del Departament d'Educació i Formació Professional
([portal de dades obertes de la Generalitat][odg]), ~170 MB. **No es versiona**, però la
sèrie agregada que se'n deriva sí:
[`04-output/alumnes_per_ensenyament_nivell.csv`](04-output/alumnes_per_ensenyament_nivell.csv).
Alimenta una sèrie independent de l'informe de preinscripció.

[odg]: https://analisi.transparenciacatalunya.cat/

**4. `01-dades/Dossier Preinscripció 2026.pptx`** *(no cal per reproduir)* — dossier de premsa
del procés de preinscripció 2026 (Departament de Recerca i Universitats, 10/07/2026). **No
es versiona.** Serveix per afegir el **punt provisional de 2026** a les sèries de
sol·licitants, places i ràtio mentre no es publica el `Dades_2026.xlsx` definitiu. Els quatre
totals que en calen (làmines 2–4 per a sol·licitants, 3 per a places) ja estan **transcrits
com a constants** a `DOSSIER_2026` dins [`02-code/R/build_series.R`](02-code/R/build_series.R),
de manera que el pipeline **no llegeix el `.pptx`**: no cal tenir-lo per executar l'anàlisi.

> **Per què el 2026 és «provisional» i com s'incorpora.** El dossier és un resum de premsa i
> els seus totals de 2025 no casen del tot amb els de les pestanyes (l'única cosa que la resta
> de la sèrie fa servir):
>
> - **Places**: dossier 41.866 vs pestanya 1.1.5 41.801 (+0,2%). **No és una diferència
>   real**: comparant per universitat, 5 de 8 quadren a la plaça exacta; el desajust és només
>   com es reparteixen els graus compartits (p. ex. URV/UOC) i els centres mixtos.
> - **Sol·licitants**: dossier 62.238 vs pestanya 1.1.6 63.038 (−1,3%). És una diferència de
>   **moment de tall**, no d'abast: la 1.1.6 és el recompte «al tancament» (definitiu) i el
>   dossier n'és una instantània anterior; el recompte final surt ~1,3% per damunt.
>
> Per no introduir un salt artificial al 2025→2026, el punt de 2026 **no es copia tal qual**:
> s'**enllaça** la variació interanual del dossier (−4,2% en sol·licitants, places planes)
> sobre el nivell «al tancament» de 2025 de la sèrie pròpia. Així el 2026 estima el que dirà
> el fitxer definitiu (sol·licitants ≈ 60.420) en comptes de barrejar dues bases. Es marca
> com a `provisional`, es dibuixa a part (punt buit / barra clara) i **no entra en cap altre
> càlcul** (ni a la projecció de la demanda, que s'ajusta només amb 2020–2025).

### Alumnes matriculats per ensenyament i nivell

`build_matriculats.R` redueix el fitxer d'origen —una fila per centre × ensenyament ×
nivell × modalitat × període— a **alumnes per ensenyament i nivell, per curs** (11.416
files, cursos 2015/2016–2025/2026):

| Columna | Descripció |
|---|---|
| `curs` | Curs escolar (`2024/2025`) |
| `any` | Any d'inici del curs, tal com ve a l'origen |
| `nom_estudis` | Categoria àmplia (`EDUCACIÓ PRIMÀRIA`, `FORMACIÓ PROFESSIONAL`…) |
| `nom_ensenyament` | Ensenyament concret |
| `nivell` | Nivell dins l'ensenyament; **buit** si l'ensenyament no en té (adults, idiomes) |
| `alumnes` | Alumnes matriculats |
| `alumnes_dones`, `alumnes_homes` | Desglossament per sexe |
| `unitats` | Grups-classe |
| `n_centres` | Centres diferents que imparteixen aquell ensenyament i nivell |

La clau (`curs`, `nom_ensenyament`, `nivell`) és **única**, i cada ensenyament penja d'un
sol `nom_estudis`. Se suma sobre modalitat (presencial, lliure, a distància) i sobre
període de matrícula.

> ⚠️ **El curs 2025/2026 és provisional i NO és comparable amb els anteriors.** Al fitxer
> del 20/07/2026 hi falta gairebé tota la **formació professional** (2.907 alumnes davant de
> 173.298 el curs anterior: un 2%) i **vuit categories senceres** —educació d'adults
> (reglada i no reglada), música, dansa, ensenyaments esportius, art dramàtic, ensenyaments
> superiors de disseny i conservació i restauració. Per això el total del curs és d'1,19
> milions d'alumnes en comptes d'~1,5. Els ensenyaments obligatoris (infantil, primària,
> ESO, batxillerat) hi són al 95–97%. `build_matriculats.R` avisa d'aquest desajust en
> executar-se, i hi ha una prova que el detecta.

Dues coses més que el codi resol i que convé saber si es toca el fitxer d'origen:

- Els comptatges de 1.000 o més porten **coma de milers** (`"1,365"` = 1365). Amb
  `as.numeric()` directe es convertirien en `NA` —i es perdrien justament els centres més
  grans, com Ilerna—; amb una locale de coma decimal, en 1,365. Ho tracta `parse_num()`.
- Les files **sense `Nom ensenyament`** (unitats registrades sense ensenyament associat) es
  descarten: sumen 1 alumne en tot el fitxer i eren l'únic cas que trencava la unicitat de
  la clau.

[oau]: https://universitats.gencat.cat/ca/altres_pagines/informe_i_estadistiques/informes_i_estad_pre/index.html

## Com reproduir-ho

Cal **R** (≥ 4.4) i, per a l'informe, **Quarto**. Paquets: `readxl`, `readr`, `dplyr`,
`tidyr`, `stringr`, `purrr`, `ggplot2`, `scales`, `knitr`, `testthat`.

```bash
# 1. Sèries + figures -> 04-output/
Rscript 02-code/run_analysis.R

# 2. Informe -> 04-output/report.html
quarto render 02-code/report.qmd --output-dir ../04-output

# 3. Proves (xifres de referència comprovades sobre els Excel)
Rscript 02-code/tests/testthat.R

# 4. (Opcional, independent de l'informe) Alumnes per ensenyament i nivell
#    -> 04-output/alumnes_per_ensenyament_nivell.csv
Rscript 02-code/build_matriculats.R

# 5. Projecció de la demanda 2026-2037 (necessita el pas 4)
#    -> 04-output/projeccio_demanda.csv + figures/fig_projeccio.png
Rscript 02-code/build_forecast.R
```

## Projecció de la demanda (2026–2037)

`build_forecast.R` projecta els sol·licitants futurs a partir d'un fet senzill: **qui
sol·licitarà plaça d'aquí a dotze anys ja és a l'escola avui**. Les cohorts no cal
predir-les, es poden comptar; el que s'ha d'estimar és només la part del trajecte que
encara no han fet.

```
nivell actual --(ràtios de progressió)--> batxillerat 2n --(yield)--> sol·licitants
```

- **Ràtios de progressió de cohort**: alumnes al nivell següent l'any següent / alumnes al
  nivell actual. Recullen alhora repetició, abandonament i migració neta. Dins de primària
  i ESO són molt estables (desviació 0,007–0,023) i s'hi pren la mitjana dels 5 anys
  recents.
- **Yield**: sol·licitants de l'any *T* / alumnes de batxillerat 2n del curs *T−1*. És
  **1,21 de mitjana** (recorregut 1,18–1,26) i val més d'1 perquè als sol·licitants s'hi
  sumen les altres vies d'accés —sobretot CFGS— i qui repeteix convocatòria.

**Per què es projecta via batxillerat i no directament des d'ESO 4t.** Es van provar els
dos models. El yield del batxillerat 2n és pla (pendent no significatiu, p = 0,83); el
d'ESO 4t deriva a la baixa de forma apreciable (p = 0,07) perquè absorbeix la caiguda del
pes del batxillerat. En proves *walk-forward* —estimant el yield només amb anys anteriors
al que es prediu— l'error mitjà és del **3,2%** amb el model de batxillerat i del **4,6%**
amb el d'ESO 4t. La projecció de cohorts, per si sola, encerta entre −1,7% i +2,7% a
horitzons de 3 a 8 anys.

**La incertesa que domina no és demogràfica.** Els alumnes que sostenen la demanda fins al
2028 ja estan **comptats** al curs 2025/2026 (batxillerat 2n, batxillerat 1r i ESO 4t). Ara
bé, només el **2026** no depèn de cap ràtio: el 2027 hi passa la conversió batxillerat
1r → 2n, i el 2028 hi afegeix la d'ESO 4t → batxillerat 1r. A partir del 2029 hi entra
també la cadena de primària i ESO. Els dos supòsits que més hi pesen:

- **ESO 4t → batxillerat 1r cau de forma sostinguda** (0,704 el 2015 → 0,596 el 2024): cada
  cop més alumnes trien FP. Es fixa en el darrer valor observat en comptes d'extrapolar-ne
  la caiguda dotze anys, i perquè una part dels qui van a FP tornen al sistema universitari
  per la via dels CFGS —que el yield ja recull.
- **Les cohorts creixen en avançar** (una cohort guanya ~13% de primària 1r a ESO 4t), cosa
  que reflecteix sobretot migració neta. La columna `sense_creixement_cohort` en dóna
  l'escenari contrari, amb aquest guany anul·lat.

> La banda `baix`–`alt` és el **recorregut històric observat** del yield (6 anys), no un
> interval de confiança: amb sis observacions, posar-hi una probabilitat seria fingir una
> precisió que no hi és.

## Notes metodològiques

- **Abast**: les 7 universitats públiques catalanes, la UVic-UCC i els centres adscrits. No
  s'hi inclouen les universitats privades ni la UOC.
- Les **notes de tall** es resumeixen amb la mediana i el rang interquartílic per no
  distorsionar-se amb els canvis de composició de l'oferta. Els valors inferiors a 5,0
  d'alguns anys inicials són anòmals respecte a l'escala 5–14 i es tracten com a terra (5,0).
- La comparació entre **nota de tall** i **nota d'accés** és indicativa, no una descomposició
  exacta: són escales diferents (5–14 vs 0–10) i poblacions diferents (l'últim admès de cada
  estudi vs la mitjana de tot el col·lectiu de batxillerat). Per això es comparen com a
  canvis en punts respecte a l'any base.
- Hi ha més detall a l'apartat «Nota metodològica» de l'informe i a
  [`03-documentacio/`](03-documentacio/Contingut_dades_preinscripcio_2020-2025.md), que
  descriu pestanya per pestanya els Excel de l'OAU i enllaça la **nota metodològica oficial
  de cada any** (2020–2025). Els PDF no es versionen aquí: són de l'OAU i s'enllacen des del
  seu portal.

## Fonts

- Dades de preinscripció: [Oficina d'Accés a la Universitat][oau], Consell Interuniversitari
  de Catalunya (Generalitat de Catalunya).
- Resultats de les PAU a Catalunya (convocatòria de juny).

El codi d'aquest repositori es pot reutilitzar lliurement. Les dades i les notes
metodològiques són de l'OAU i estan subjectes a les seves condicions d'ús.
