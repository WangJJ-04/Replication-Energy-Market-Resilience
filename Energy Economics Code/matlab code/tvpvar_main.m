%%--------------------------------------------------------%%
%%                     tvpvar_main.m                       %%
%%--------------------------------------------------------%%

%%
%%  MCMC estimation for Time-Varying Parameter VAR model
%%  with stochastic volatility

%% MCMC estimation
% Run resilience.m after this script to construct the resilience metrics.

clear all;
close all;

% Resolve the sibling data folder from this script's location.
script_dir = fileparts(which('tvpvar_main.m'));
project_dir = fileparts(fileparts(script_dir));
data_file = fullfile(project_dir, 'Energy Economics Data', 'VAR_100data.xlsx');
data = readmatrix(data_file);

ydata =  data(:, 2:9);
Time = (data(:,1));

asvar = {'GPR', 'CPU', 'OPU', 'OIL', 'NG', 'COAL', 'ERIX', 'EUA'};
nlag = 1;                   % VAR lag order

setvar('data', zscore(ydata), asvar, nlag); % Standardize each input series to mean zero and unit sample SD.

setvar_girf('fastimp', 0);       % Draw-specific GIRFs with pointwise posterior medians.
setvar_girf('ranseed', 2025);       % Seed for uniform and normal random-number generators.
setvar_girf('impulse', 8);      % Maximum GIRF horizon H = 8; exports horizons 0:8.
setvar_girf('intercept', 1);     % Include a time-varying intercept.

setvar_girf('SigB', 0);          % Diagonal covariance of coefficient innovations.
setvar_girf('SigA', 0);          % Diagonal covariance of contemporaneous-parameter innovations.
setvar_girf('SigH', 0);          % Diagonal covariance of log-volatility innovations.

setvar_girf('prior', 'b', 50, 2e-1);  % Diagonal variance prior: IG(shape = 50, scale = 0.2).
setvar_girf('prior', 'a', 8, 2e-2);   % Diagonal variance prior: IG(shape = 8, scale = 0.02).
setvar_girf('prior', 'h', 8, 2e-2);   % Diagonal variance prior: IG(shape = 8, scale = 0.02).

mcmc_girf_median(10000,Time,'yyyy'); % Retain 10,000 posterior draws after warm-up.
