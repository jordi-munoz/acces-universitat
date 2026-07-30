# =============================================================================
# plots.R
# Funcions ggplot2 per a l'informe. Estil divulgatiu comú, etiquetes en català.
# Cada funció rep la llista de sèries de build_all() i retorna un objecte ggplot.
# =============================================================================

suppressPackageStartupMessages({
  library(ggplot2)
  library(dplyr)
  library(tidyr)
  library(scales)
})

# Paleta i tema comuns -------------------------------------------------------
COL_DEMANDA   <- "#C0392B"  # vermell: demanda (sol·licitants)
COL_OFERTA    <- "#2C3E50"  # blau fosc: oferta (places)
COL_MATRICULA <- "#7F8C8D"  # gris: matrícula
COL_NOTA      <- "#1F6F54"  # verd: notes de tall
COL_ACCENT    <- "#E67E22"  # taronja: accents / infrademanda
COL_EXPEDIENT <- "#6C3483"  # lila: mitjana d'expedient de batxillerat
COL_PAU       <- "#2E86C1"  # blau clar: mitjana de les proves
COL_ACCES     <- "#CA6F1E"  # ocre: nota d'accés (combinació 60/40)

tema_divulgatiu <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title    = element_text(face = "bold", size = rel(1.15)),
      plot.subtitle = element_text(color = "grey30", margin = margin(b = 8)),
      plot.caption  = element_text(color = "grey45", size = rel(0.8), hjust = 0),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      axis.title   = element_text(color = "grey30"),
      legend.position = "top",
      legend.title = element_blank()
    )
}

fmt_mil <- scales::label_number(big.mark = ".", decimal.mark = ",")

# 1. Tisora demanda-oferta ---------------------------------------------------
plot_tisora <- function(s) {
  df <- bind_rows(
    transmute(s$demanda,   year, serie = "Sol·licitants (1a preferència)", value = solicitants, prov = provisional),
    transmute(s$oferta,    year, serie = "Places ofertes",                  value = places,      prov = provisional),
    transmute(s$matricula, year, serie = "Matrícula de nou accés",          value = matricula,   prov = FALSE)
  ) |>
    filter(year >= min(s$demanda$year))  # finestra comuna 2020-2025(+2026 prov.)

  cols <- c("Sol·licitants (1a preferència)" = COL_DEMANDA,
            "Places ofertes"                 = COL_OFERTA,
            "Matrícula de nou accés"         = COL_MATRICULA)
  firm <- filter(df, !prov)
  # tram provisional: de l'últim any ferm al 2026, només per a les sèries que hi arriben
  bridge <- df |> group_by(serie) |> filter(any(prov)) |>
    filter(year >= max(year[!prov])) |> ungroup()

  ggplot(mapping = aes(year, value, color = serie)) +
    geom_line(data = firm, linewidth = 1.1) +
    geom_line(data = bridge, linewidth = 1.1, linetype = "22") +
    geom_point(data = firm, size = 2.2) +
    geom_point(data = filter(df, prov), size = 2.4, shape = 21, fill = "white", stroke = 1.1) +
    scale_color_manual(values = cols) +
    scale_x_continuous(breaks = unique(df$year)) +
    scale_y_continuous(labels = fmt_mil, limits = c(0, NA)) +
    labs(
      title = "La demanda creix; l'oferta de places, gairebé congelada",
      subtitle = "Sistema públic de preinscripció de Catalunya",
      x = NULL, y = "Nombre d'estudiants",
      caption = paste0("Font: Oficina d'Accés a la Universitat. Sol·licitants i places: pestanyes 1.1.6 i 1.1.5.\n",
                       "2026 (punt buit): provisional, del Dossier de preinscripció; enllaçat sobre el nivell de 2025.")
    ) +
    tema_divulgatiu()
}

# 2. Pressió d'accés (ràtio sol·licitants/plaça) -----------------------------
plot_pressio <- function(s) {
  df <- dplyr::mutate(s$pressio,
                      etiqueta = paste0(scales::number(ratio, accuracy = 0.01, decimal.mark = ","),
                                        ifelse(provisional, "*", "")))
  ggplot(df, aes(year, ratio)) +
    geom_col(aes(alpha = provisional), fill = COL_ACCENT, width = 0.65) +
    geom_text(aes(label = etiqueta), vjust = -0.5, size = 3.4, color = "grey20") +
    scale_alpha_manual(values = c(`FALSE` = 1, `TRUE` = 0.5), guide = "none") +
    scale_x_continuous(breaks = df$year) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    labs(
      title = "Cada cop més sol·licitants per plaça",
      subtitle = "Ràtio de sol·licitants en 1a preferència per plaça oferta",
      x = NULL, y = "Sol·licitants / plaça",
      caption = paste0("Font: Oficina d'Accés a la Universitat. Elaboració pròpia (1.1.6 / 1.1.5).\n",
                       "* 2026: provisional, del Dossier de preinscripció; enllaçat sobre el nivell de 2025.")
    ) +
    tema_divulgatiu()
}

# 3. Notes de tall: centre que puja + infrademanda que baixa -----------------
plot_notes <- function(s) {
  df <- s$notes
  ggplot(df, aes(year)) +
    geom_ribbon(aes(ymin = q25, ymax = q75), fill = COL_NOTA, alpha = 0.15) +
    geom_line(aes(y = mediana), color = COL_NOTA, linewidth = 1.1) +
    geom_point(aes(y = mediana), color = COL_NOTA, size = 2.2) +
    scale_x_continuous(breaks = df$year) +
    scale_y_continuous(limits = c(5, NA)) +
    labs(
      title = "Les notes de tall pugen",
      subtitle = "Mediana de la nota de tall (banda: 1r-3r quartil). Escala 5-14",
      x = NULL, y = "Nota de tall",
      caption = "Font: Oficina d'Accés a la Universitat (pestanya 5.3). Valors < 5 tractats com a terra 5,0."
    ) +
    tema_divulgatiu()
}

# 3a-bis. % d'estudis per damunt de cada llindar de nota de tall -------------
# Els llindars són una magnitud ordenada -> rampa seqüencial d'un sol to
# (clar = llindar baix, fosc = llindar alt). Passos adjacents de la rampa són
# per força semblants: cada línia porta etiqueta directa perquè la identitat
# no depengui mai del color.
LLINDARS_PLOT <- c(6, 8, 10, 12)
RAMPA_LLINDAR <- c("6" = "#3E9E76", "8" = "#2A7F5C", "10" = "#1B6046", "12" = "#0B3F2D")

plot_llindars <- function(s, llindars = LLINDARS_PLOT) {
  df <- s$llindars |>
    filter(llindar %in% llindars) |>
    mutate(serie = factor(paste0("≥ ", llindar),
                          levels = paste0("≥ ", sort(llindars))))
  cols <- setNames(RAMPA_LLINDAR[as.character(sort(llindars))],
                   paste0("≥ ", sort(llindars)))
  y1 <- max(df$year)

  ggplot(df, aes(year, pct, color = serie)) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    geom_text(
      data = filter(df, year == y1),
      aes(label = paste0("≥ ", llindar)),
      hjust = -0.3, size = 3.4, fontface = "bold", show.legend = FALSE
    ) +
    scale_color_manual(values = cols) +
    scale_x_continuous(breaks = unique(df$year),
                       expand = expansion(mult = c(0.02, 0.10))) +
    scale_y_continuous(labels = scales::label_percent(scale = 1),
                       limits = c(0, NA)) +
    labs(
      title = "La pujada arrossega tota la distribució, no només els graus d'elit",
      subtitle = "% d'estudis amb la nota de tall igual o superior a cada llindar (escala 5-14)",
      x = NULL, y = "% d'estudis",
      caption = "Font: Oficina d'Accés a la Universitat (pestanya 5.3). Elaboració pròpia."
    ) +
    tema_divulgatiu()
}

# 3b. Estudis infrademandats (nota de tall al terra) -------------------------
plot_infrademanda <- function(s) {
  df <- s$notes
  ggplot(df, aes(year, pct_infrademandats)) +
    geom_col(fill = COL_OFERTA, width = 0.65) +
    geom_text(aes(label = scales::number(pct_infrademandats, accuracy = 1, suffix = "%")),
              vjust = -0.5, size = 3.2, color = "grey20") +
    scale_x_continuous(breaks = df$year) +
    scale_y_continuous(labels = scales::label_percent(scale = 1),
                       expand = expansion(mult = c(0, 0.12))) +
    labs(
      title = "Cada cop menys estudis queden per sota de la competència",
      subtitle = "% d'estudis amb nota de tall al mínim (5,0), és a dir, sense excés de demanda",
      x = NULL, y = "% d'estudis",
      caption = "Font: Oficina d'Accés a la Universitat (pestanya 5.3)."
    ) +
    tema_divulgatiu()
}

# 4. PAU: quanta gent es presenta a les proves ------------------------------
plot_pau_presentats <- function(s) {
  df <- s$pau
  ggplot(df, aes(year, presentats)) +
    geom_line(linewidth = 1.1, color = COL_DEMANDA) +
    geom_point(size = 2.2, color = COL_DEMANDA) +
    scale_x_continuous(breaks = seq(min(df$year), max(df$year), by = 2)) +
    scale_y_continuous(labels = fmt_mil, limits = c(0, NA)) +
    labs(
      title = "Cada any més estudiants es presenten a les PAU",
      subtitle = "Estudiants presentats a la convocatòria ordinària (juny)",
      x = NULL, y = "Presentats",
      caption = "Font: resultats de les PAU a Catalunya. L'any és el de les proves (curs 2024/25 = juny de 2025)."
    ) +
    tema_divulgatiu()
}

# 5. PAU: expedient, prova i nota d'accés ------------------------------------
plot_pau_notes <- function(s) {
  df <- s$pau |>
    select(year, Expedient = expedient, PAU = nota_pau, Acces = nota_acces) |>
    pivot_longer(-year, names_to = "serie", values_to = "value") |>
    mutate(serie = recode(serie,
      Expedient = "Mitjana d'expedient (batxillerat)",
      PAU       = "Mitjana de les proves (PAU)",
      Acces     = "Nota d'accés (60% expedient + 40% PAU)"
    ))
  cols <- c(
    "Mitjana d'expedient (batxillerat)"     = COL_EXPEDIENT,
    "Mitjana de les proves (PAU)"           = COL_PAU,
    "Nota d'accés (60% expedient + 40% PAU)" = COL_ACCES
  )
  ggplot(df, aes(year, value, color = serie)) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    scale_color_manual(values = cols) +
    scale_x_continuous(breaks = seq(min(df$year), max(df$year), by = 2)) +
    labs(
      title = "L'expedient puja; la nota de les proves, no",
      subtitle = "Mitjanes de la convocatòria ordinària. Escala 0-10",
      x = NULL, y = "Nota mitjana",
      caption = "Font: resultats de les PAU a Catalunya. El model nou de PAU s'estrena el juny de 2025."
    ) +
    tema_divulgatiu() +
    guides(color = guide_legend(nrow = 2))
}

# 6. Comparació: nota de tall vs. nota de l'alumnat (mateixa base) -----------
# Dues escales diferents (tall 5-14, accés 0-10): s'indexen a punts de canvi
# respecte a l'any base per poder-les llegir en un sol eix.
plot_pau_vs_tall <- function(s) {
  y0 <- max(min(s$notes$year), min(s$pau$year))
  y1 <- min(max(s$notes$year), max(s$pau$year))
  base <- function(d, col) d[[col]][d$year == y0]

  df <- bind_rows(
    transmute(filter(s$notes, year >= y0, year <= y1),
              year, serie = "Nota de tall (mediana)",
              delta = mediana - base(s$notes, "mediana")),
    transmute(filter(s$pau, year >= y0, year <= y1),
              year, serie = "Nota d'accés de l'alumnat (mitjana)",
              delta = nota_acces - base(s$pau, "nota_acces"))
  )
  cols <- c("Nota de tall (mediana)" = COL_NOTA,
            "Nota d'accés de l'alumnat (mitjana)" = COL_ACCES)
  labs_end <- filter(df, year == y1)

  ggplot(df, aes(year, delta, color = serie)) +
    geom_hline(yintercept = 0, color = "grey70", linewidth = 0.4) +
    geom_line(linewidth = 1.1) +
    geom_point(size = 2) +
    geom_text(
      data = labs_end,
      aes(label = scales::number(delta, accuracy = 0.01, decimal.mark = ",",
                                 style_positive = "plus")),
      hjust = -0.25, size = 3.4, show.legend = FALSE
    ) +
    scale_color_manual(values = cols) +
    scale_x_continuous(breaks = seq(y0, y1, by = 1),
                       expand = expansion(mult = c(0.02, 0.12))) +
    labs(
      title = "Les notes de tall pugen molt més del que millora l'alumnat",
      subtitle = paste0("Canvi acumulat en punts respecte a ", y0,
                        " (dues escales diferents, mateixa base)"),
      x = NULL, y = paste0("Punts de canvi des de ", y0),
      caption = "Font: Oficina d'Accés a la Universitat (5.3) i resultats de les PAU. Elaboració pròpia."
    ) +
    tema_divulgatiu()
}

# 5. Projecció de la demanda a partir de les cohorts escolars -----------------
# Rep la taula de build_forecast.R (històric + projecció en format llarg).
plot_projeccio <- function(taula) {
  hist <- filter(taula, tipus == "històric")
  proj <- filter(taula, tipus != "històric")
  # El darrer any observat s'afegeix a l'inici de la projecció perquè les línies
  # es toquin: si no, el salt entre trams sembla una discontinuïtat de la sèrie.
  pont <- transmute(slice_max(hist, year, n = 1),
                    year, solicitants, baix = solicitants, alt = solicitants,
                    sense_creixement_cohort = solicitants)
  proj_c <- bind_rows(pont, select(proj, year, solicitants, baix, alt,
                                   sense_creixement_cohort))
  tall <- max(hist$year)

  ggplot(mapping = aes(year)) +
    geom_ribbon(data = proj_c, aes(ymin = baix, ymax = alt),
                fill = COL_DEMANDA, alpha = 0.15) +
    geom_vline(xintercept = tall + 0.5, color = "grey75", linewidth = 0.4) +
    geom_line(data = proj_c, aes(y = sense_creixement_cohort,
                                 color = "Escenari sense creixement de cohort"),
              linewidth = 0.8, linetype = "dotted") +
    geom_line(data = proj_c, aes(y = solicitants, color = "Projecció central"),
              linewidth = 1.1, linetype = "22") +
    geom_line(data = hist, aes(y = solicitants, color = "Observat"), linewidth = 1.1) +
    geom_point(data = hist, aes(y = solicitants, color = "Observat"), size = 2.2) +
    annotate("text", x = tall + 0.7, y = 0, hjust = 0, vjust = -0.5,
             label = "projecció", size = 3.2, color = "grey45") +
    scale_color_manual(values = c(
      "Observat"                            = COL_DEMANDA,
      "Projecció central"                   = COL_DEMANDA,
      "Escenari sense creixement de cohort" = COL_OFERTA
    )) +
    scale_x_continuous(breaks = seq(2020, max(proj$year), 2)) +
    scale_y_continuous(labels = fmt_mil, limits = c(0, NA)) +
    labs(
      title = "La demanda universitària toca sostre: la davallada ja és a les aules",
      subtitle = paste0("Sol·licitants en 1a preferència a les universitats públiques.\n",
                        "Projecció a partir de les cohorts ja escolaritzades el curs 2025/2026"),
      x = NULL, y = "Sol·licitants",
      caption = paste0(
        "Font: Oficina d'Accés a la Universitat i dades obertes del Departament d'Educació. Elaboració pròpia.\n",
        "Banda: recorregut històric de la ràtio sol·licitants / batxillerat 2n (2020-2025), no és un interval de confiança.\n",
        "Abast: sistema públic de preinscripció de Catalunya (universitats públiques i UVic-UCC).")
    ) +
    tema_divulgatiu() +
    theme(legend.position = "top")
}

# Desa totes les figures com a PNG a out_dir/figures/ -------------------------
save_figures <- function(s, out_dir, width = 8, height = 4.8, dpi = 150) {
  fig_dir <- file.path(out_dir, "figures")
  dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)
  figs <- list(
    fig_tisora       = plot_tisora(s),
    fig_pressio      = plot_pressio(s),
    fig_notes        = plot_notes(s),
    fig_llindars     = plot_llindars(s),
    fig_infrademanda = plot_infrademanda(s),
    fig_pau_presentats = plot_pau_presentats(s),
    fig_pau_notes      = plot_pau_notes(s),
    fig_pau_vs_tall    = plot_pau_vs_tall(s)
  )
  for (nm in names(figs)) {
    ggsave(file.path(fig_dir, paste0(nm, ".png")), figs[[nm]],
           width = width, height = height, dpi = dpi, bg = "white")
  }
  invisible(fig_dir)
}
