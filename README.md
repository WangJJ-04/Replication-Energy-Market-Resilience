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
│   └── markov_scale_data_166.csv # Standardized macro-financial variables (166 months)
└── Energy Economics Code/
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
```

---

## 3. Software Requirements

- **MATLAB (R2021a or newer recommended):**
  - Statistics and Machine Learning Toolbox
  - Spreadsheet I/O support
- **Python (>= 3.9):**
  - Packages: `jupyter`, `numpy`, `pandas`, `scipy`, `statsmodels`, `openpyxl`, `matplotlib`, `requests`
- **R (>= 4.0):**
  - Packages: `readxl`, `tseries`, `e1071`, `ggplot2`, `sysfonts`, `showtext`, `grid`

---

## 4. Replication Steps

### Step 1: Estimate TVP-VAR-SV & Generate GIRFs (MATLAB)
1. Open MATLAB and set the Current Folder to `Energy Economics Code/matlab code/`.
2. Run `tvpvar_main.m`.
   - Reads `Energy Economics Data/VAR_100data.xlsx`.
   - Settings: Lag order $p = 1$, time-varying intercept, random seed `2025`, 10,000 retained MCMC draws after burn-in, evaluation horizon $H = 8$.
   - Exports GIRFs to `tvpvar_imp.xlsx` and convergence diagnostics to `tvpvar_pdf_figures/`.

### Step 2: Compute Resilience Metrics (MATLAB)
1. In the same MATLAB folder, run `resilience.m`.
   - Reads `tvpvar_imp.xlsx`.
   - Computes Resilience Intensity (RI) and Resilience Duration (RD).
   - Generates `resilience_metrics.xlsx` (166 months $\times$ 64 shock-market pairs).
   *(Note: A pre-computed `resilience_metrics.xlsx` is already included to allow skipping Step 1 if desired).*

### Step 3: Estimate Markov Regime-Switching Models (Python)
1. Start Jupyter Notebook in `Energy Economics Code/python code/`.
2. Open and run all cells in `Markov.ipynb` sequentially.
   - Fits 30 two-state Markov-switching models across uncertainty sources, resilience dimensions, and markets.
   - Conducts cross-state Wald equality tests with Benjamini–Hochberg (BH) false discovery rate adjustments.
   - Exports smoothed state probabilities and test summaries to `python code/output/`.

### Step 4: Summary Tables and Figures (R)
1. Open R and set the working directory to `<project root>`.
2. Run `ee_descriptive_statistics.r` in `Energy Economics Code/r code/`:
   - Generates summary statistics, rank frequency counts, and correlation matrices.
   - Exports `variable_summary_statistics.tex`.
3. Run `ee_plot_for_resilience.r`:
   - **Block 1:** Conceptual resilience schematic plot.
   - **Block 2:** Baseline time-varying RI and RD figures for GPR, CPU, and OPU shocks.
   - **Block 3:** Robustness comparisons across evaluation horizons ($H = 6, 8, 10$).
   - **Block 4:** Smoothed regime probabilities from Python outputs.
   - Visualizations are saved under `r code/output/figures/` and `python code/output/figures/`.

---

## 5. Contact

All data and replication code are publicly available in this repository. For further inquiries, please contact the corresponding author.
