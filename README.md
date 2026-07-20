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
  R/read_sheets.R    Lectors de les pestanyes dels Excel de l'OAU
  R/build_series.R   Construcció de les sèries temporals
  R/plots.R          Figures (ggplot2)
  report.qmd         Informe (Quarto)
  run_analysis.R     Pipeline complet
  tests/             Proves (testthat) amb xifres de referència
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

[oau]: https://universitats.gencat.cat/ca/altres_pagines/informe_i_estadistiques/informes_i_estad_pre/index.html

## Com reproduir-ho

Cal **R** (≥ 4.4) i, per a l'informe, **Quarto**. Paquets: `readxl`, `dplyr`, `tidyr`,
`stringr`, `purrr`, `ggplot2`, `scales`, `knitr`, `testthat`.

```bash
# 1. Sèries + figures -> 04-output/
Rscript 02-code/run_analysis.R

# 2. Informe -> 04-output/report.html
quarto render 02-code/report.qmd --output-dir ../04-output

# 3. Proves (xifres de referència comprovades sobre els Excel)
Rscript 02-code/tests/testthat.R
```

## Notes metodològiques

- **Abast**: les 7 universitats públiques catalanes i els seus centres adscrits. **S'exclou
  la UVic-UCC**, que participa a la preinscripció però és de titularitat privada, i tampoc
  s'hi inclouen la resta d'universitats privades ni la UOC. L'exclusió afecta els estudis on
  la UVic-UCC és l'única universitat; els graus compartits amb una pública (UAB/UVic) es
  mantenen. Les dades d'origen sí que inclouen la UVic-UCC: el filtre s'aplica en construir
  les sèries (`is_uvic_only()` a [`02-code/R/build_series.R`](02-code/R/build_series.R)).
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
