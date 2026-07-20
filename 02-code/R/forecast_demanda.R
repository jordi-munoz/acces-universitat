# =============================================================================
# forecast_demanda.R
# Projecció de la demanda futura d'accés a les universitats públiques a partir
# de les cohorts que avui són a primària, ESO i batxillerat.
#
# Idea de fons: qui sol·licitarà plaça d'aquí a 12 anys ja és escolaritzat avui.
# La mida de les cohorts no s'ha de predir, es pot comptar. El que sí que cal
# estimar és la part del trajecte que encara no han fet:
#
#   nivell actual --(ratios de progressió)--> batxillerat 2n --(yield)--> sol·licitants
#
# Model triat (vegeu README, "Projecció de la demanda"): es projecta fins a
# batxillerat 2n i s'hi aplica la ràtio històrica sol·licitants/batxillerat 2n.
# L'alternativa —projectar des d'ESO 4t i saltar-se el batxillerat— es va
# descartar perquè el seu yield té una deriva a la baixa estadísticament
# apreciable (absorbeix la caiguda del pes del batxillerat), mentre que el del
# batxillerat 2n és pla. En proves walk-forward, l'error mitjà és del 3,2% amb
# aquest model i del 4,6% amb l'altre.
#
# Defineix les funcions; no executa res en ser carregat.
# Per generar la sortida: 02-code/build_forecast.R
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
})

# Etapes que segueix una cohort, numerades de forma contínua ("pas") perquè la
# progressió sigui una simple suma: 1-6 primària, 7-10 ESO, 11-12 batxillerat.
ETAPES <- c("EDUCACIÓ PRIMÀRIA", "EDUCACIÓ SECUNDÀRIA OBLIGATÒRIA", "BATXILLERAT")
PAS_ESO4  <- 10L
PAS_BATX2 <- 12L

# Converteix la sèrie d'alumnes en la taula de cohorts (any, pas, alumnes).
# S'exclouen les files sense nivell (1-3% del total): sense nivell no es poden
# situar en el trajecte. L'educació d'adults i l'especial queden fora perquè
# tenen categoria d'estudis pròpia i no formen part del flux ordinari.
cohort_table <- function(serie) {
  serie |>
    filter(nom_estudis %in% ETAPES,
           !is.na(nivell),
           nivell %in% as.character(1:6)) |>
    mutate(pas = case_when(
      nom_estudis == "EDUCACIÓ PRIMÀRIA"               ~ as.integer(nivell),
      nom_estudis == "EDUCACIÓ SECUNDÀRIA OBLIGATÒRIA" ~ 6L + as.integer(nivell),
      TRUE                                             ~ 10L + as.integer(nivell)
    )) |>
    group_by(any, pas) |>
    summarise(alumnes = sum(alumnes), .groups = "drop")
}

# Ràtio de progressió de cohort: alumnes al pas+1 l'any següent / alumnes al pas.
# Recull alhora repetició, abandonament i migració neta, que és exactament el
# que interessa: com es transforma una cohort real en passar de curs.
progression_ratios <- function(coh) {
  coh |>
    mutate(any_next = any + 1L, pas_next = pas + 1L) |>
    inner_join(coh, by = c("any_next" = "any", "pas_next" = "pas"),
               suffix = c("", "_next")) |>
    mutate(r = alumnes_next / alumnes) |>
    select(any, pas, r)
}

# Ràtios a aplicar en la projecció.
#
# Per als passos 1-9 (dins de primària i ESO) s'agafa la mitjana dels 5 anys
# més recents: són molt estables (desviació 0,007-0,023).
#
# El pas 10 (ESO 4t -> batxillerat 1r) és l'excepció: cau de forma sostinguda
# (0,704 el 2015 -> 0,596 el 2024) perquè cada cop més alumnes trien FP. S'hi
# fixa el darrer valor observat, no la mitjana, que ja quedaria antiquada.
# Extrapolar-ne la caiguda 12 anys enllà seria arriscat i, a més, part dels qui
# van a FP tornen al sistema universitari per la via dels CFGS.
ratios_projeccio <- function(cpr, n_recent = 5) {
  r <- cpr |>
    arrange(pas, any) |>
    group_by(pas) |>
    summarise(r_recent = mean(tail(r, n_recent)),
              r_darrer = dplyr::last(r), .groups = "drop") |>
    mutate(r = if_else(pas == PAS_ESO4, r_darrer, r_recent))
  setNames(r$r, as.character(r$pas))
}

# Alumnes al nivell `pas` l'any `any_target`: observat si el curs ja hi és, i si
# no, projectat encadenant ràtios des del darrer curs observat.
# `ratios_cap_1` limita a 1 les ràtios de creixement de cohort (passos 1-9) per
# a l'escenari sense guany migratori.
projected_level <- function(coh, ratios, any_target, pas_target,
                            base_any = max(coh$any), ratios_cap_1 = FALSE) {
  obs <- coh$alumnes[coh$any == any_target & coh$pas == pas_target]
  if (length(obs) == 1) return(list(alumnes = obs, base = "observat"))

  pas0 <- pas_target - (any_target - base_any)
  if (pas0 < 1) return(NULL)                       # encara no escolaritzats
  v <- coh$alumnes[coh$any == base_any & coh$pas == pas0]
  if (!length(v)) return(NULL)

  for (p in seq(pas0, pas_target - 1L)) {
    rp <- ratios[[as.character(p)]]
    if (ratios_cap_1 && p < PAS_ESO4) rp <- min(rp, 1)
    v <- v * rp
  }
  list(alumnes = v, base = "projectat")
}

# Yield: sol·licitants d'un any / alumnes de batxillerat 2n del curs anterior.
# És > 1 perquè als sol·licitants s'hi sumen les altres vies d'accés (sobretot
# CFGS) i qui repeteix convocatòria.
yield_batx2 <- function(demanda, coh) {
  b2 <- coh |> filter(pas == PAS_BATX2) |> transmute(year = any + 1L, batx2 = alumnes)
  demanda |>
    transmute(year, solicitants) |>
    inner_join(b2, by = "year") |>
    mutate(yield = solicitants / batx2)
}

# Projecció de sol·licitants. La banda no és un interval de confiança: és el
# recorregut històric observat del yield (6 anys), que és la incertesa que
# domina un cop les cohorts ja estan comptades.
forecast_demanda <- function(coh, demanda, fins = 2037L) {
  ratios <- ratios_projeccio(progression_ratios(coh))
  y  <- yield_batx2(demanda, coh)
  base_any <- max(coh$any)
  primer <- max(demanda$year) + 1L

  files <- lapply(primer:fins, function(T) {
    b <- projected_level(coh, ratios, T - 1L, PAS_BATX2, base_any)
    if (is.null(b)) return(NULL)
    sense_mig <- projected_level(coh, ratios, T - 1L, PAS_BATX2, base_any,
                                 ratios_cap_1 = TRUE)
    tibble(
      year          = T,
      batx2         = b$alumnes,
      base          = b$base,
      central       = mean(y$yield)  * b$alumnes,
      baix          = min(y$yield)   * b$alumnes,
      alt           = max(y$yield)   * b$alumnes,
      sense_creixement_cohort = mean(y$yield) * sense_mig$alumnes
    )
  })
  bind_rows(files) |>
    mutate(across(c(batx2, central, baix, alt, sense_creixement_cohort), round))
}
