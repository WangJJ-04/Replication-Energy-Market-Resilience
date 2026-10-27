ENERGY ECONOMICS PYTHON CODE
===========================

1. NOTEBOOK AND REFACTOR
------------------------
Markov.ipynb is the only notebook. It estimates two-state Markov-switching
regressions for resilience intensity (RI) and duration (RD), exports state
probabilities for R, and performs cross-state Wald tests.

The six code cells and their running order are retained. Twelve identical
model utilities from the two estimation cells now share definitions in Cell 1.
Repeated console headings and compact-table column lists use small helpers.
Separator comments, commented-out access examples, and excessive wrapping have
been reduced. No additional helper file or data input is required.

Both estimation passes, their separate settings, parameter precision, state
labeling, calculations, error messages, printed text/order, and export formats
are retained. The shared utilities keep their existing function names and
arguments. Imports remain in the estimation cells, so either estimation stage
can still run after setup without executing the other estimation stage.

2. PATHS AND INPUTS
-------------------
Keep the Code and Data folders under one parent directory:

  <project root>/
    Energy Economics Data/
      markov_scale_data_166.csv
    Energy Economics Code/
      matlab code/
        resilience_metrics.xlsx
      python code/
        Markov.ipynb
        readme.txt
        output/
      r code/
        ee_plot_for_resilience.r
        ee_descriptive_statistics.r

Run tvpvar_main.m and resilience.m as described in the MATLAB README to generate
the resilience workbook, or use the supplied baseline workbook.

Cell 1 finds PROJECT_ROOT from the kernel working directory and its parents.
It also recognizes a my paper/ subfolder. Start the kernel inside the project
tree, preferably in python code/. Keep the two package folder names unchanged.

Resolved inputs:
  RESILIENCE_FILE = <project root>/Energy Economics Code/matlab code/
                    resilience_metrics.xlsx
  MACRO_DATA_FILE = <project root>/Energy Economics Data/
                    markov_scale_data_166.csv

The resilience workbook supplies t, Variable, RP, and RD. RP is the MATLAB
column name for RI. Each baseline shock-response series has 166 observations,
with t = 2,...,167. Market mappings, in the fixed order, are:

  Shock   OIL     NG      COAL    ERIX    EUA
  GPR     Var6    Var7    Var8    Var9    Var10
  CPU     Var14   Var15   Var16   Var17   Var18
  OPU     Var22   Var23   Var24   Var25   Var26

The conditioning CSV supplies date, DXY, GSCPI, CPI, Industrial, covering
February 2010-November 2023. Its four numerical columns are already standardized
on the 166-month sample. They are used in DXY/GSCPI/CPI/Industrial order.

Both estimation cells align inputs by row order, truncate to their shortest
length, and remove missing y and X jointly within each model. Cell 4 also
carries dates through the selection and sorting. No date merge is performed;
preserve the common chronological order of the supplied inputs.

3. SOFTWARE
-----------
Use JupyterLab or Jupyter Notebook with a Python kernel. Required packages are
numpy, pandas, scipy, statsmodels, openpyxl, matplotlib, requests, and IPython.
pathlib, datetime, and io belong to the standard library. Cell 2 retains the
existing %matplotlib inline magic and notebook imports.

Example installation:
  python -m pip install numpy pandas scipy statsmodels openpyxl matplotlib requests jupyterlab ipykernel

Previously recorded analysis environment (not rechecked for this refactor):
  Python 3.9.7       numpy 2.0.2        pandas 2.3.3
  scipy 1.13.1       statsmodels 0.14.5 openpyxl 3.1.5
  matplotlib 3.9.4   requests 2.32.5    IPython 8.18.1

The parameter helpers retain support for both DXY[0]/GSCPI[1] and x1[0]/x2[1]
naming. Keep package versions consistent when comparing numerical estimates.

4. RUNNING THE SIX CELLS
------------------------
Open Markov.ipynb, restart the kernel, and run from top to bottom:

  Cell 1: find paths, verify both input files, and define shared model helpers.
          These definitions do not execute numerical calculations.
  Cell 2: initialize the existing notebook imports and plotting magic.
  Cell 3: fit and print the RI/RD Markov tables.
  Cell 4: fit the same specification and export probability workbooks.
  Cell 5: test individual cross-state slope equality and export the results.
  Cell 6: test levels, individual slopes, and joint slopes; apply the existing
          pooled individual-test BH correction and export comprehensive tests.

Cells 3 and 4 both estimate models. ALL specifies 30 models per estimation cell:
three shocks, two measures, and five markets. The later Wald cells use results
left by Cell 4. The original two-pass workflow is retained.

To select one shock, set SELECTED_UNCERTAINTY to "GPR", "CPU", or "OPU" in BOTH
estimation cells; the default is "ALL". Run Cell 1 before either estimation
cell to define the shared utilities. Re-run the intended estimation stage
before a test cell when changing its sample or settings.

5. MODEL, LABELS, AND CONTROLS
------------------------------
Each model centers the dependent variable by subtracting its sample mean:

  y_t - mean(y) = alpha[s_t] + beta[s_t]' X_t + error_t

The retained statsmodels MarkovRegression settings are:
  k_regimes=2, trend="c", switching_trend=True,
  switching_exog=True, switching_variance=True
  fit(method="nm", maxiter=10000, disp=False)

The intercept, four slopes, and error variance switch across states; transition
probabilities are time-invariant. Nelder-Mead uses the existing statsmodels
starting-value procedure. Original-scale conditional levels add mean(y) back
to each intercept and are evaluated at X=0. Slopes refer to standardized X.

Raw regimes are relabeled independently for each model:
  RI State 1: higher conditional level; stronger absorption.
  RI State 2: lower conditional level; weaker absorption.
  RD State 1: lower conditional level; faster relative recovery.
  RD State 2: higher conditional level; slower relative recovery.

p11 and p22 are staying probabilities after relabeling. Markov-state expected
persistence, 1/(1-p_ss), is distinct from the RD measure. The exported mapping
retains the raw-to-economic state correspondence.

Compact tables retain four decimal places for estimates and three for
z-statistics; fitted objects retain full precision. Within-state stars use
two-sided normal z-test p-values. Existing star thresholds, zero-rounding
handling, and the precision choices in the separate estimation cells are kept.

Cell 4 controls:
  STATE_TO_PLOT = 1                  Select State 1 for prob_selected.
  USE_SMOOTHED_PROBABILITIES = True  Use full-sample smoothed probabilities.
  EXPORT_PROBABILITY_XLSX = True     Write probability workbooks.
  PRINT_STATSMODELS_SUMMARY = False  Print compact tables.

STATE_TO_PLOT=2 selects State 2 and filenames ending in state2.xlsx. Both
states remain available in their own columns. The smoothing flag set to False
selects filtered probabilities. PRINT_STATSMODELS_SUMMARY is also configurable
in Cell 3. The two test cells retain their own export flags.

6. WALD TESTS AND FDR
---------------------
Tests use the full parameter covariance matrix, including cross-state terms:

  W = (R*theta)' * inverse(R*Cov(theta)*R') * (R*theta)

Cell 5 tests each slope difference with one restriction. With ALL and complete
fits, it reports 120 tests. p_value and stars are unadjusted. sign_opposite
records point-estimate signs; the Wald p-value tests their difference.

Cell 6 retains 30 level/intercept tests, 120 individual slope tests, and 30
joint slope tests under ALL. Adding the same mean(y) to both state intercepts
does not alter their difference. Its Wald helper uses a pseudoinverse and
rank(R) degrees of freedom; the joint test normally has four restrictions.

Benjamini-Hochberg is applied ONCE to the combined available individual level
AND slope family (150 tests under ALL). q_value_bh and stars_q are added while
raw p_value and stars_p remain. Levels and slopes are not separate correction
families. Joint tests retain raw p-values/stars and receive no BH q-values.
This rule remains separate from within-state z-tests and the Cell 5 workbook.

7. OUTPUTS AND R CONNECTION
---------------------------
NOTEBOOK_OUTPUT_DIR controls the common destination:
  <project root>/Energy Economics Code/python code/output/
Export creates the directory as needed and reuses the configured filenames.

Default probability files:
  gpr_ms_state_probabilities_state1.xlsx
  cpu_ms_state_probabilities_state1.xlsx
  opu_ms_state_probabilities_state1.xlsx

Each contains probabilities_long and state_mapping. The long sheet retains
date, shock, measure, market, metric_value, y_centered, probability_type,
prob_raw_regime0, prob_raw_regime1, prob_state1, prob_state2, state_to_plot,
selected_raw_regime, and prob_selected. Baseline: 1660 rows per shock.
state_mapping contains 10 records per shock, including conditional levels,
raw-state labels, nobs, and optimizer convergence. Market/measure/date row
order, date formatting, filters, frozen headers, and the active sheet are kept.

Test files:
  cross_state_equality_tests.xlsx
    equality_tests: 120 unadjusted individual slope tests under ALL.
  cross_state_comprehensive_tests.xlsx
    individual_tests: 30 level plus 120 slope tests, with raw p and pooled BH q.
    joint_slope_tests: 30 joint tests, with raw p-values.

Objects remain in results, paper_tables, probability_tables, state_mapping_tables,
and exported_probability_files. A model pickle is not automatically exported.
Examples of accessing the retained objects:

  results["GPR"]["RI"]["OIL"].summary()
  paper_tables["CPU"]["RD"][display_columns]
  probability_tables["GPR"].head()
  state_mapping_tables["GPR"]
  exported_probability_files["GPR"]

The R Markov block reads the probability workbooks from output/ and writes its
PDFs to <project root>/Fig/, shared with the other R and MATLAB figures.
Set R's SHOCK_LABEL and STATE_TO_PLOT to match the Python file.
Set PROJECT_DIR in R when moving the package. R baseline plots and descriptive
statistics continue to read matlab code/resilience_metrics.xlsx.

8. STATIC VERIFICATION
----------------------
All six cells passed Python parsing and compilation to code objects without
execution; the unchanged IPython magic is excluded from the Python parser.
The 12 shared definitions match both originals. After accounting for their
relocation and statically expanding the new heading/column helpers, each
cell's executable syntax tree matches the pre-refactor code.

No cell, model, statistical test, or export was executed for this refactor.
The six cells, cell IDs, execution counts, saved outputs, and notebook metadata
are preserved. Saved results are retained historical outputs, not a new run.
