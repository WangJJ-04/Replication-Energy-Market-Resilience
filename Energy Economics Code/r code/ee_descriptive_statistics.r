# Energy Economics: variable and resilience descriptive statistics

# Required packages
# Install missing packages once, if needed:
# install.packages(c("tseries", "e1071", "readxl"))
library(tseries)
library(e1071)
library(readxl)

{
  # A. Variable summary statistics: energy, uncertainty, and macrofinancial data

  # Both input files contain 167 months, from January 2010 to November 2023.
  if (!exists("PROJECT_DIR", inherits = TRUE)) {
    PROJECT_DIR <- normalizePath(getwd(), mustWork = TRUE)
  }
  VAR_DATA_FILE <- file.path(PROJECT_DIR, "Energy Economics Data", "VAR_100data.xlsx")
  MACRO_DATA_FILE <- file.path(PROJECT_DIR, "Energy Economics Data", "markov_100data_167.csv")

  # The baseline resilience summaries use 166 months and horizon H = 8.
  RESILIENCE_FILE <- file.path(PROJECT_DIR, "Energy Economics Code", "matlab code",
    "resilience_metrics.xlsx")
  VARIABLE_SUMMARY_FILE <- file.path(PROJECT_DIR, "Energy Economics Code", "r code",
    "variable_summary_statistics.tex")

  # Join by date, preserving the VAR sample order and the original source values.
  read_variable_summary_data <- function(var_file, macro_file) {
    if (tolower(tools::file_ext(var_file)) %in% c("xlsx", "xls")) {
      var_data <- as.data.frame(read_xlsx(var_file), stringsAsFactors = FALSE)
    } else {
      var_data <- read.csv(var_file, stringsAsFactors = FALSE, check.names = FALSE)
    }
    macro_data <- read.csv(macro_file, stringsAsFactors = FALSE, check.names = FALSE)
    required_var <- c("date", "OIL", "NG", "COAL", "ERIX", "EUA", "GPR", "CPU", "OPU")
    required_macro <- c("date", "GSCPI", "DXY", "CPI", "Industrial")

    if (!all(required_var %in% names(var_data))) {
      stop("The VAR input is missing required date, market, or uncertainty columns.")
    }
    if (!all(required_macro %in% names(macro_data))) {
      stop("The macrofinancial input is missing required columns.")
    }

    var_data$date <- as.Date(var_data$date)
    macro_data$date <- as.Date(macro_data$date)
    if (anyNA(var_data$date) || anyNA(macro_data$date) ||
      anyDuplicated(var_data$date) || anyDuplicated(macro_data$date)) {
      stop("Input dates must be valid and unique within each file.")
    }

    macro_index <- match(var_data$date, macro_data$date)
    if (anyNA(macro_index)) {
      stop("Every date in the VAR input must have a matching macrofinancial observation.")
    }

    cbind(var_data, macro_data[macro_index, required_macro[-1], drop = FALSE])
  }

  # Print a LaTeX table and invisibly return the unrounded numeric statistics.
  # data: data frame containing the numeric variables to summarize.
  # var_groups: named list of variable vectors; names provide panel titles.
  # digits: displayed decimal places; ADF statistics retain two decimal places.
  generate_descriptive_table <- function(data, var_groups, digits = 2) {
    format_num <- function(x, digits) {
      if (is.na(x) || !is.finite(x)) return("--")
      number <- formatC(round(x, digits), format = "f", digits = digits)
      if (x >= 0) {
        paste0("$\\phantom{-}", number, "$")
      } else {
        paste0("$", number, "$")
      }
    }

    adf_result <- function(x) {
      if (length(x) < 10) {
        return(list(statistic = NA_real_, p_value = NA_real_, stars = ""))
      }
      test <- tryCatch(suppressWarnings(tseries::adf.test(x, alternative = "stationary")),
        error = function(e) NULL)
      if (is.null(test)) {
        return(list(statistic = NA_real_, p_value = NA_real_, stars = ""))
      }
      p <- test$p.value
      # tseries reports 0.01 when its interpolated p-value is at/below that bound.
      stars <- if (p <= 0.01) "***" else if (p < 0.05) "**" else if (p < 0.1) "*" else ""
      list(statistic = unname(test$statistic), p_value = p, stars = stars)
    }

    rows <- list()
    for (group_name in names(var_groups)) {
      for (variable in var_groups[[group_name]]) {
        if (!variable %in% names(data)) {
          warning("Variable ", variable, " is not present in the data; skipping it.")
          next
        }
        x <- data[[variable]]
        if (!is.numeric(x)) {
          stop("Variable ", variable, " must be numeric.")
        }
        x <- x[!is.na(x)]
        if (length(x) == 0) next
        if (any(!is.finite(x))) {
          stop("Variable ", variable, " contains non-finite values.")
        }
        adf <- adf_result(x)

        # Use type-3 skewness and excess kurtosis (normal reference = 0).
        rows[[length(rows) + 1L]] <- data.frame(Group = group_name, Variable = variable,
          n = length(x), Mean = mean(x), SD = sd(x), Median = median(x), Min = min(x), Max = max(x),
          Skewness = e1071::skewness(x, type = 3), Kurtosis = e1071::kurtosis(x, type = 3),
          ADF = adf$statistic, ADF_p = adf$p_value, ADF_stars = adf$stars, stringsAsFactors = FALSE)
      }
    }
    if (length(rows) == 0) stop("No numeric observations are available for the requested variables.")
    statistics <- do.call(rbind, rows)
    rownames(statistics) <- NULL

    row_end <- paste0(" ", strrep("\\", 2), "\n")
    cat("\\begin{table}[H]\n")
    cat("\\centering\n")
    cat("\\caption{Summary statistics.}\n")
    cat("\\label{tab:descriptive_statistics}\n")
    cat("\\begin{threeparttable}\n")
    cat("\\footnotesize\n")
    cat("\\setlength{\\tabcolsep}{5pt}\n")
    cat("\\renewcommand{\\arraystretch}{1.15}\n")
    cat("\\begin{tabular}{lrrrrrrrrr}\n")
    cat("\\toprule\n")
    cat("Variable & $n$ & Mean & SD & Median & Min & Max & Skewness & Kurtosis & ADF", row_end, sep = "")
    cat("\\midrule\n")

    panel_number <- 0L
    for (group_name in names(var_groups)) {
      group_rows <- statistics[statistics$Group == group_name, , drop = FALSE]
      if (nrow(group_rows) == 0) next
      panel_number <- panel_number + 1L
      if (panel_number > 1L) cat("\\midrule\n")
      cat("\\multicolumn{10}{l}{\\textit{Panel ", LETTERS[panel_number],
        ": ", group_name, "}} ", strrep("\\", 2), "[2pt]\n", sep = "")

      for (i in seq_len(nrow(group_rows))) {
        row <- group_rows[i,]
        numeric_cells <- vapply(c("Mean", "SD", "Median", "Min", "Max", "Skewness", "Kurtosis"),
          function(column) format_num(row[[column]], digits), character(1))
        adf_cell <- if (is.na(row$ADF)) {
          "--"
        } else {
          stars <- if (nzchar(row$ADF_stars)) paste0("^{", row$ADF_stars, "}") else ""
          paste0("$", formatC(round(row$ADF, 2), format = "f", digits = 2), stars, "$")
        }
        cat(paste(c(row$Variable, as.character(row$n), numeric_cells, adf_cell), collapse = " & "), row_end, sep = "")
      }
    }

    cat("\\bottomrule\n")
    cat("\\end{tabular}\n")
    cat("\\begin{tablenotes}[flushleft]\n")
    cat("\\footnotesize\n")
    cat("\\item \\textit{Notes:} $n$ denotes the number of monthly observations. SD is the sample standard deviation. Skewness and excess kurtosis use the type-3 definitions in the e1071 package. ADF is the Augmented Dickey--Fuller test statistic for the null hypothesis of a unit root, computed using tseries::adf.test with its default lag rule. $^{***}$, $^{**}$, and $^{*}$ denote rejection at the 1\\%, 5\\%, and 10\\% significance levels. The tseries lower-bound p-value of 0.01 is shown with three stars.\n")
    cat("\\end{tablenotes}\n")
    cat("\\end{threeparttable}\n")
    cat("\\end{table}\n")

    invisible(statistics)
  }

  VAR_data <- read_variable_summary_data(VAR_DATA_FILE, MACRO_DATA_FILE)
  var_groups <- list("Energy markets" = c("OIL", "NG", "COAL", "ERIX", "EUA"),
    "Uncertainty indicators" = c("GPR", "CPU", "OPU"),
    "Macrofinancial conditioning variables" = c("GSCPI", "DXY", "CPI", "Industrial"))

  variable_summary_latex <- capture.output(
    variable_descriptive_statistics <- generate_descriptive_table(VAR_data, var_groups, digits = 2))
  cat(paste(variable_summary_latex, collapse = "\n"), "\n", sep = "")
  writeLines(variable_summary_latex, VARIABLE_SUMMARY_FILE, useBytes = TRUE)
  cat("Variable summary table saved to:", VARIABLE_SUMMARY_FILE, "\n")
} # Variable descriptive statistics

# B. Resilience summaries, correlations, and monthly ranking counts

# Optional single-path GIRF preview; the summary tables do not use this plot.
RUN_IMPULSE_DIAGNOSTIC <- FALSE
if (RUN_IMPULSE_DIAGNOSTIC) {
  imp <- read_xlsx(file.path(PROJECT_DIR, "Energy Economics Code", "matlab code", "tvpvar_imp.xlsx"
  ))
  plot(as.numeric(imp[[6]][12:20]), type = "l")
}

# 1. Read data

r_data <- read_xlsx(RESILIENCE_FILE)

# Check that the required columns are present
stopifnot(all(c("Variable", "RP", "RD") %in% names(r_data)))

# RP = Resilience Intensity (RI)
# RD = Resilience Duration (RD)

# 2. Define markets and variable mapping

markets <- c("OIL", "NG", "COAL", "ERIX", "EUA")

var_map <- list(
  GPR = c(OIL = "Var6", NG = "Var7", COAL = "Var8", ERIX = "Var9", EUA = "Var10"),
  CPU = c(OIL = "Var14", NG = "Var15", COAL = "Var16", ERIX = "Var17", EUA = "Var18"),
  OPU = c(OIL = "Var22", NG = "Var23", COAL = "Var24", ERIX = "Var25", EUA = "Var26"))

shocks <- names(var_map)

# 3. Function for extracting one series

get_series <- function(variable_id, measure) {
  x <- r_data[[measure]][r_data$Variable == variable_id]

  x <- as.numeric(x)

  return(x)
}

# 4. Construct RI and RD matrices

make_matrix <- function(shock, measure) {
  temp <- lapply(var_map[[shock]], function(v) get_series(v, measure))

  # Check that all five markets have the same number of observations
  lens <- lengths(temp)

  if (length(unique(lens)) != 1) {
    stop(paste("Unequal sample lengths detected for", shock, measure))
  }

  temp <- as.data.frame(temp)

  names(temp) <- markets

  return(temp)
}

# Resilience intensity
RI <- list(GPR = make_matrix("GPR", "RP"), CPU = make_matrix("CPU", "RP"),
  OPU = make_matrix("OPU", "RP"))

# Resilience duration
RD <- list(GPR = make_matrix("GPR", "RD"), CPU = make_matrix("CPU", "RD"),
  OPU = make_matrix("OPU", "RD"))

# 5. Check sample size

sample_sizes <- c(sapply(RI, nrow), sapply(RD, nrow))

print(sample_sizes)

if (length(unique(sample_sizes)) != 1) {
  stop("RI and RD series do not have identical sample sizes.")
}

N <- unique(sample_sizes)

cat("Number of monthly observations =", N, "\n")

if (N != 166) {
  warning(paste("Your LaTeX table reports 166 months,", "but the current dataset contains", N,
    "observations."))
}

# 6. Correlation matrices of resilience intensity

RI_corr <- lapply(RI, function(x) {
  cor(x, use = "pairwise.complete.obs", method = "pearson")
})

RI_corr_GPR <- RI_corr$GPR
RI_corr_CPU <- RI_corr$CPU
RI_corr_OPU <- RI_corr$OPU

# Preserve the original console headings and printing order.
print_section <- function(title) {
  cat("\n====================================\n")
  cat(title)
  cat("====================================\n")
}

print_section("RI correlation matrix: GPR\n")
print(round(RI_corr_GPR, 2))

print_section("RI correlation matrix: CPU\n")
print(round(RI_corr_CPU, 2))

print_section("RI correlation matrix: OPU\n")
print(round(RI_corr_OPU, 2))

# 7. Correlation matrices of resilience duration

RD_corr <- lapply(RD, function(x) {
  cor(x, use = "pairwise.complete.obs", method = "pearson")
})

RD_corr_GPR <- RD_corr$GPR
RD_corr_CPU <- RD_corr$CPU
RD_corr_OPU <- RD_corr$OPU

print_section("RD correlation matrix: GPR\n")
print(round(RD_corr_GPR, 2))

print_section("RD correlation matrix: CPU\n")
print(round(RD_corr_CPU, 2))

print_section("RD correlation matrix: OPU\n")
print(round(RD_corr_OPU, 2))

# 8. Correlation between RI and RD

RI_RD_corr <- sapply(shocks, function(shock) {
  sapply(markets, function(market) {
    cor(RI[[shock]][[market]], RD[[shock]][[market]], use = "pairwise.complete.obs",
      method = "pearson")
  })
})

rownames(RI_RD_corr) <- markets
colnames(RI_RD_corr) <- shocks

print_section("Correlation between RI and RD\n")

print(round(RI_RD_corr, 4))

# 9. Descriptive statistics

summary_stats <- function(x) {
  c(Mean = mean(x, na.rm = TRUE), SD = sd(x, na.rm = TRUE), Min = min(x, na.rm = TRUE),
    Max = max(x, na.rm = TRUE))
}

make_desc_table <- function(data_list) {
  result <- data.frame(Market = markets, stringsAsFactors = FALSE)

  for (shock in shocks) {
    temp <- t(sapply(markets, function(market) {
      summary_stats(data_list[[shock]][[market]])
    }))

    temp <- as.data.frame(temp)

    names(temp) <- paste0(shock, "_", c("Mean", "SD", "Min", "Max"))

    result <- cbind(result, temp)
  }

  rownames(result) <- NULL

  return(result)
}

# Panel A: RI
desc_RI <- make_desc_table(RI)

# Panel B: RD
desc_RD <- make_desc_table(RD)

print_section("Panel A: Resilience Intensity\n")

print(data.frame(Market = desc_RI$Market, round(desc_RI[, -1], 4)), row.names = FALSE)

print_section("Panel B: Resilience Duration\n")

print(data.frame(Market = desc_RD$Market, round(desc_RD[, -1], 4)), row.names = FALSE)

# 10. Monthly ranking counts

rank_counts <- function(x, top = c("maximum", "minimum")) {
  top <- match.arg(top)

  x <- as.data.frame(x)

  # Ranking requires all five markets to be observed
  complete_rows <- complete.cases(x)

  if (!all(complete_rows)) {
    warning(paste(sum(!complete_rows),
      "months contain missing values and will be excluded from ranking."))
  }

  x <- x[complete_rows, , drop = FALSE]

  # Check ties

  tie_test <- apply(x, 1, function(z) {
    max_tie <- sum(z == max(z)) > 1
    min_tie <- sum(z == min(z)) > 1

    max_tie | min_tie
  })

  if (any(tie_test)) {
    warning(paste(sum(tie_test), "months contain ties.",
      "which.max/which.min will select the first tied market."))
  }

  # Determine monthly top and bottom market

  if (top == "maximum") {
    # RI:
    # higher RI = stronger absorption
    top_index <- apply(x, 1, which.max)
    bottom_index <- apply(x, 1, which.min)
  } else {
    # RD:
    # lower RD = faster recovery
    top_index <- apply(x, 1, which.min)
    bottom_index <- apply(x, 1, which.max)
  }

  # Count number of months

  top_count <- table(factor(top_index, levels = seq_along(markets)))

  bottom_count <- table(factor(bottom_index, levels = seq_along(markets)))

  result <- data.frame(Market = markets, Top_rank = as.integer(top_count),
    Bottom_rank = as.integer(bottom_count))

  return(result)
}
# 11. RI ranking counts

rank_RI_GPR <- rank_counts(RI$GPR, top = "maximum")

rank_RI_CPU <- rank_counts(RI$CPU, top = "maximum")

rank_RI_OPU <- rank_counts(RI$OPU, top = "maximum")

print_section("RI ranking counts: GPR\n")
print(rank_RI_GPR)

print_section("RI ranking counts: CPU\n")
print(rank_RI_CPU)

cat("\n====================================\n")
cat("RI ranking counts: OPU\n")

# 12. RD ranking counts

rank_RD_GPR <- rank_counts(RD$GPR, top = "minimum")

rank_RD_CPU <- rank_counts(RD$CPU, top = "minimum")

rank_RD_OPU <- rank_counts(RD$OPU, top = "minimum")

print_section("RD ranking counts: GPR\n")
print(rank_RD_GPR)

print_section("RD ranking counts: CPU\n")
print(rank_RD_CPU)

print_section("RD ranking counts: OPU\n")
print(rank_RD_OPU)
cat("====================================\n")
print(rank_RI_OPU)

# 13. Combine ranking results into wide tables

combine_rank_tables <- function(GPR, CPU, OPU) {
  data.frame(
    Market = markets,
    GPR_Top = GPR$Top_rank, GPR_Bottom = GPR$Bottom_rank,
    CPU_Top = CPU$Top_rank, CPU_Bottom = CPU$Bottom_rank,
    OPU_Top = OPU$Top_rank, OPU_Bottom = OPU$Bottom_rank
  )
}

rank_RI <- combine_rank_tables(rank_RI_GPR, rank_RI_CPU, rank_RI_OPU)

rank_RD <- combine_rank_tables(rank_RD_GPR, rank_RD_CPU, rank_RD_OPU)

print_section("Panel A: RI ranking counts\n")
print(rank_RI, row.names = FALSE)

print_section("Panel B: RD ranking counts\n")
print(rank_RD, row.names = FALSE)
