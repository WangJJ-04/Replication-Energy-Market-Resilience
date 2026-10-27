# Replication Package: Energy Market Resilience to Uncertainty Shocks

This repository contains the replication data and code for the article:

> **Energy Market Resilience to Uncertainty Shocks: An Absorption and Recovery Perspective**  
> **Authors:** Jingjie Wang, Shoukun Jiao (Corresponding Author), Jinting Yang, and Wuyi Ye  
> **Journal:** *Energy Economics*  


---

## 1. Overview

This study investigates energy market resilience to geopolitical risk (GPR), climate policy uncertainty (CPU), and oil price uncertainty (OPU) across five benchmarks:
- **Fossil fuels:** Brent crude oil futures (OIL), Henry Hub natural gas futures (NG), Newcastle thermal coal futures (COAL)
- **Low-carbon assets:** European Renewable Energy Total Return Index (ERIX), EU ETS carbon allowance futures (EUA)

We measure resilience along two complementary dimensions:
1. **Resilience Intensity (RI):** Captures relative shock absorption capacity by comparing the cumulative absolute response against a benchmark holding the peak response.
2. **Resilience Duration (RD):** Quantifies effective recovery speed as the temporal centroid (center of mass) of the absolute response area.

The empirical workflow consists of:
- A **Time-Varying Parameter Vector Autoregression with Stochastic Volatility (TVP-VAR-SV)** to generate date-specific Generalized Impulse Response Functions (GIRFs) and time-varying RI and RD series.
- **Two-state Markov regime-switching regressions** conditioning on four macro-financial variables (GSCPI, DXY, CPI, and Industrial Production) to assess state persistence and cross-state parameter differences.

---

## 2. Directory Structure

Please keep both `Energy Economics Code` and `Energy Economics Data` folders under the same root directory:

```text
<project root>/
├── README.md
├── Energy Economics Data/
│   ├── readme.txt
│   ├── VAR_100data.xlsx          # 8-variable VAR input in percentage returns & index levels (167 months)
│   ├── VAR_data.csv              # Decimal-scale reference returns
│   ├── markov_100data_167.csv    # Unstandardized macro-financial conditioning variables
│   ├── markov_scale_data_166.csv # Standardized macro-financial variables (166 months)
│   └── horizon_resilience/      # Existing H = 6, 8, 10 comparison workbooks
├── Energy Economics Code/
    ├── readme.txt
    ├── matlab code/              # TVP-VAR-SV MCMC estimation & RI/RD metric calculation
    │   ├── tvpvar_main.m
    │   ├── resilience.m
    │   └── ...
    ├── python code/              # Markov regime-switching models & Wald hypothesis tests
    │   ├── Markov.ipynb
    │   └── ...
    └── r code/                   # Descriptive statistics tables & figure rendering
        ├── ee_descriptive_statistics.r
        ├── ee_plot_for_resilience.r
        └── ...
└── Fig/                        # All MATLAB and R PDF figures
```

Detailed instructions: [Code workflow](Energy%20Economics%20Code/readme.txt),
[Data](Energy%20Economics%20Data/readme.txt),
[MATLAB](Energy%20Economics%20Code/matlab%20code/readme.txt),
[Python](Energy%20Economics%20Code/python%20code/readme.txt), and
[R](Energy%20Economics%20Code/r%20code/readme.txt).

---

## 3. Software Requirements

- **MATLAB (R2021a or newer recommended):**
  - Statistics and Machine Learning Toolbox
  - Spreadsheet I/O support
- **Python (>= 3.9):**
  - Packages: `jupyter`, `numpy`, `pandas`, `scipy`, `statsmodels`, `openpyxl`, `matplotlib`, `requests`
- **R (>= 4.0):**
  - Packages: `readxl`, `tseries`, `e1071`, `ggplot2`, `sysfonts`, `showtext`, `grid`

The R font paths use macOS Times New Roman files. On another platform, configure
the font paths in each plotting block before running it. Block 1 requires the
four configured fonts; Blocks 2-4 use a sans-serif fallback when those files are
absent. See the R README for the exact font settings.

---

## 4. Replication Steps

### Step 1: Estimate TVP-VAR-SV & Generate GIRFs (MATLAB)
1. Open MATLAB and set the Current Folder to `Energy Economics Code/matlab code/`.
2. Run `tvpvar_main.m`.
   - Reads `Energy Economics Data/VAR_100data.xlsx`.
   - Settings: Lag order $p = 1$, time-varying intercept, random seed `2025`, 10,000 retained MCMC draws after burn-in, evaluation horizon $H = 8$.
   - Exports GIRFs to `tvpvar_imp.xlsx` in the MATLAB folder and five diagnostic/parameter PDF groups to `<project root>/Fig/`.

### Step 2: Compute Resilience Metrics (MATLAB)
1. In the same MATLAB folder, run `resilience.m`.
   - Reads `tvpvar_imp.xlsx`.
   - Computes Resilience Intensity (RI) and Resilience Duration (RD).
   - Generates `resilience_metrics.xlsx` (166 months $\times$ 64 shock-response combinations).
   - A precomputed `resilience_metrics.xlsx` is included, so downstream Python/R analyses can start from that workbook without rerunning Steps 1-2.

### Step 3: Estimate Markov Regime-Switching Models (Python)
1. Start Jupyter Notebook in `Energy Economics Code/python code/`.
2. Open and run all cells in `Markov.ipynb` sequentially.
   - Cells 3 and 4 each fit 30 two-state models across uncertainty sources, resilience dimensions, and markets. Both estimation passes are retained; the Wald cells use the results from Cell 4.
   - Conducts cross-state Wald equality tests. Benjamini–Hochberg (BH) adjustment is applied to the combined individual level-and-slope family; the separate slope-equality workbook and joint-slope tests retain raw p-values.
   - Exports smoothed state probabilities and test summaries to `python code/output/`.

### Step 4: Summary Tables and Figures (R)
Set the R working directory to `<project root>`, then initialize the project
path and the full monthly date vector:

```r
PROJECT_DIR <- normalizePath(getwd())
date_source <- readxl::read_xlsx(file.path(
  PROJECT_DIR, "Energy Economics Data", "VAR_100data.xlsx"
))
index_GPR_m1_data <- data.frame(Date = as.Date(date_source$date))

source(file.path(
  PROJECT_DIR, "Energy Economics Code", "r code", "ee_descriptive_statistics.r"
))
source(file.path(
  PROJECT_DIR, "Energy Economics Code", "r code", "ee_plot_for_resilience.r"
))
```

The descriptive script prints summary statistics, rank counts, and correlation
matrices, and writes `variable_summary_statistics.tex` in `r code/`.

The plotting file contains four complete blocks:

- **Block 1:** Conceptual resilience schematic.
- **Block 2:** Baseline RI/RD figures for GPR, CPU, and OPU.
- **Block 3:** Comparison across $H = 6, 8, 10$, using the three supplied
  workbooks in `Energy Economics Data/horizon_resilience/`.
- **Block 4:** Smoothed regime probabilities from the Python outputs.

All PDFs are saved in `<project root>/Fig/`, which is created automatically.
Individual complete blocks can also be selected after loading the plotting
packages and initializing the project/date objects above.

The comparison workbooks preserve the existing analysis inputs. To regenerate
alternative horizons, synchronize the MATLAB horizon, response-point count,
and first retained worksheet row as documented in the MATLAB README.

### Output locations

- **All PDF figures:** `<project root>/Fig/`, including the schematic, baseline
  resilience figures, horizon comparison, Markov plots, and MATLAB diagnostics.
- **MATLAB analysis workbooks:** `Energy Economics Code/matlab code/`.
- **Markov probability and test workbooks:** `Energy Economics Code/python code/output/`.
- **Variable-summary LaTeX table:** `Energy Economics Code/r code/variable_summary_statistics.tex`.

---

## 5. Contact

All data and replication code are publicly available in this repository. For further inquiries, please contact the corresponding author.
