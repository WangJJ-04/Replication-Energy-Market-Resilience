ENERGY ECONOMICS CODE: REPLICATION GUIDE
=======================================

1. PACKAGE STRUCTURE
---------------------
Keep these two folders together under the same parent directory:

  <project root>/
    Energy Economics Code/
      readme.txt
      matlab code/
      python code/
      r code/
    Energy Economics Data/
      readme.txt
      VAR_100data.xlsx
      VAR_data.csv
      markov_100data_167.csv
      markov_scale_data_166.csv
      horizon_resilience/
    Fig/                         (all MATLAB and R PDF figures)

Energy Economics Data contains the prepared monthly estimation inputs.
Energy Economics Code contains the programs and generated analysis workbooks.
All PDF figures are saved together in <project root>/Fig/, created as needed.
The parent directory can have any name; retain the two package folder names.

Detailed instructions and parameter definitions are provided in:

  matlab code/readme.txt
  python code/readme.txt
  r code/readme.txt

The Python folder contains one notebook: Markov.ipynb.

2. OVERALL WORKFLOW
-------------------
  Energy Economics Data/VAR_100data.xlsx
    -> matlab code/tvpvar_main.m: TVP-VAR-SV MCMC and median GIRFs
    -> matlab code/tvpvar_imp.xlsx
    -> matlab code/resilience.m
    -> matlab code/resilience_metrics.xlsx
       -> python code/Markov.ipynb, together with the standardized macro data
          -> state-probability and Wald-test workbooks in python code/output/
       -> R resilience summaries and baseline resilience figures

The R variable-summary table additionally uses VAR_100data.xlsx and the
unstandardized markov_100data_167.csv from Energy Economics Data.

The full input sample has 167 months, January 2010-November 2023. The one-lag
baseline produces 166 valid resilience observations, February 2010-November
2023. The standardized 166-row macrofinancial file matches these dates.

3. SOFTWARE
------------
MATLAB:
  Spreadsheet I/O functions and Statistics and Machine Learning Toolbox.
  Keep all supplied .m helper functions in the matlab code folder.

Python:
  Jupyter/IPython, numpy, pandas, scipy, statsmodels, openpyxl, matplotlib,
  and requests. The Python README lists the checked package versions.

R:
  readxl, tseries, e1071, ggplot2, sysfonts, showtext, and grid.
  grid is supplied with R. Font paths in the plotting script use macOS
  Times New Roman defaults; configure those paths for another platform.

4. STEP 1: ESTIMATE THE TVP-VAR-SV AND EXPORT GIRFs
-------------------------------------------------
Set MATLAB's Current Folder to Energy Economics Code/matlab code. Open
and run tvpvar_main.m. The input workbook is
resolved from the script's location in the sibling Energy Economics Data folder.

The baseline uses eight series in this order:
  GPR, CPU, OPU, OIL, NG, COAL, ERIX, EUA.

Key settings are one VAR lag, a time-varying intercept, random seed 2025,
10000 retained posterior draws, and maximum GIRF horizon H = 8. Input series
are standardized within MATLAB. With fastimp = 0, GIRFs are summarized by
their pointwise posterior medians across retained draws.

This stage exports tvpvar_imp.xlsx, parameter/volatility workbooks, and five
diagnostic/parameter PDF groups in <project root>/Fig/. The MATLAB README
explains the priors, preliminary iterations, memory use, and all settings.

tvpvar_main.m ends after MCMC estimation and export. Run resilience.m separately
as described below.

5. STEP 2: COMPUTE THE RESILIENCE MEASURES
----------------------------------------
After MCMC export, keep the same MATLAB Current Folder and run:

  resilience

resilience.m reads tvpvar_imp.xlsx and writes resilience_metrics.xlsx.
H = 8 exports horizons 0:8, so the calculation uses N = 9 response points.
The first valid worksheet row is 13: three header rows are followed by nine
undefined response rows for the initial lagged period. data(13:end,:) therefore
skips 12 rows and keeps row 13 onward.

The output contains 10624 data rows: 166 sample months times 64 shock-response
combinations. Its columns are t, Variable, RP, and RD. RP is the retained column
name for resilience intensity (RI). The existing RD implementation uses
one-based weights 1:9 on the exported horizons 0:8. Both formulas and their
indexing conventions are explained in matlab code/readme.txt.

The supplied baseline resilience workbook can be used to reproduce downstream
analyses without re-running MCMC.

6. STEP 3: ESTIMATE THE MARKOV MODELS AND RUN WALD TESTS
------------------------------------------------------
Open python code/Markov.ipynb in Jupyter. Start the kernel inside the project
tree, preferably in python code/, restart it, and run all six cells in order.
The first cell discovers the two sibling package folders and validates:

  Energy Economics Code/matlab code/resilience_metrics.xlsx
  Energy Economics Data/markov_scale_data_166.csv

The default ALL selection fits the three uncertainty sources, two resilience
measures, and five markets: 30 two-state models per estimation cell. The
intercept, four macrofinancial slopes, and error variance switch across states.
State labels are ordered economically: State 1 has higher RI or lower RD.

Outputs in python code/output/ are:

  gpr_ms_state_probabilities_state1.xlsx
  cpu_ms_state_probabilities_state1.xlsx
  opu_ms_state_probabilities_state1.xlsx
  cross_state_equality_tests.xlsx
  cross_state_comprehensive_tests.xlsx

The first three contain probabilities_long and state_mapping worksheets for R.
The tests cover individual slopes, regime levels, and joint slope equality.
The comprehensive notebook preserves the existing BH correction across the
combined individual level-and-slope family; joint tests retain raw p-values.
See python code/readme.txt for hypotheses, correction scope, and output columns.

7. STEP 4: RUN THE R SUMMARIES AND FIGURES
----------------------------------------
The R scripts search upward from PROJECT_DIR, if supplied, and then the current
working directory for the parent containing both package folders. R can start
at the project root or inside a package subdirectory, including r code/.
A supplied subdirectory is resolved to the root; an explicit valid root takes
priority. If no root is found, set PROJECT_DIR to the package root.

For example, from the project root in R:

  PROJECT_DIR <- normalizePath(getwd())
  source(file.path(PROJECT_DIR, "Energy Economics Code", "r code",
                   "ee_descriptive_statistics.r"))

From Energy Economics Code/r code/, use source("ee_descriptive_statistics.r")
instead. The script initializes PROJECT_DIR and all input paths. Rerun the
path-setup section after moving the package or changing PROJECT_DIR.

The descriptive script reads the percentage-scale VAR workbook, the 167-row
unstandardized macrofinancial file, and the generated resilience workbook.
It prints summary/correlation/ranking results and saves the variable-summary
LaTeX fragment as r code/variable_summary_statistics.tex.

For plotting, initialize the full date vector and load the plotting packages:

  library(readxl)
  library(ggplot2)
  library(grid)
  library(sysfonts)
  library(showtext)
  date_source <- read_xlsx(file.path(PROJECT_DIR, "Energy Economics Data",
                                    "VAR_100data.xlsx"))
  index_GPR_m1_data <- data.frame(Date = as.Date(date_source$date))

Open r code/ee_plot_for_resilience.r and run the required complete blocks:

  Block 1: resilience schematic.
  Block 2: combined GPR, CPU, and OPU baseline resilience figures.
  Block 3: optional comparison of H = 6, 8, and 10.
  Block 4: Markov probability/metric figures from the Python exports.

All four R plotting blocks write their PDFs to <project root>/Fig/, together
with the MATLAB diagnostic figures. The Markov block still reads its input
workbooks from python code/output/; SHOCK_LABEL and STATE_TO_PLOT select them.

Block 3 reads the three supplied H = 6, 8, and 10 workbooks from
Energy Economics Data/horizon_resilience/. These archived comparison inputs
preserve the existing figure data. See the Data and MATLAB READMEs for their
layout and the settings needed to regenerate alternative horizons.

8. INPUT UNITS AND REPRODUCTION NOTES
-------------------------------------
Use VAR_100data.xlsx for the default VAR input and variable-summary table.
Its five energy returns are in percent; its three uncertainty indices are in
levels. VAR_data.csv contains decimal energy returns and is a reference copy
in a different return unit. No further multiplication by 100 is required for
the workbook. See the Data README for transformations and standardization.

Keep the original variable order, dates, and shock-response mappings when
passing data between languages. Generated workbooks are outputs rather than
replacements for the prepared source inputs. Running a stage again writes
the same configured output filenames.
