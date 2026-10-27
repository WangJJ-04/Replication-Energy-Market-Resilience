clc; clear; close all;

% Read the GIRF workbook exported by the MCMC estimation.
filename = 'tvpvar_imp.xlsx';
data = readtable(filename, 'ReadVariableNames', false);

% Keep rows 13 onward; skip 3 header rows and 9 undefined GIRF rows for t = 1.
% With H = 8, N = H + 1 = 9 response points (horizons 0:8); nlag = 1.
data = data(13:end, :);

% Read the automatically generated table column names.
var_names = data.Properties.VariableNames;

% Forward-fill t in the first column within each response block.
current_t = NaN;
for i = 1:height(data)
    if ~isnan(data{i, 1})
        current_t = data{i, 1};
    else
        data{i, 1} = current_t;
    end
end

% Get the sample-period indices in their original order.
t_values = unique(data.Var1, 'stable');
t_values(isnan(t_values)) = []; % Remove missing indices.

% Get the identifiers for all shock-response combinations.
response_vars = var_names(3:end); % Excel columns C:BN contain all 64 response series.
num_vars = length(response_vars);

% Initialize the output table.
results = table();

% Compute RP (the exported RI measure) and RD for each sample period.
for t_idx = 1:length(t_values)
    t = t_values(t_idx);
    
    % Locate all response-horizon rows for this sample period.
    t_rows = find(data.Var1 == t);
    
    % Compute RP and RD for each shock-response combination.
    for var_idx = 1:num_vars
        % Extract the current GIRF path (baseline horizons 0:8).
        responses = table2array(data(t_rows, var_idx+2));
        
        % Take absolute values of all exported response points, including horizon 0.
        abs_responses = abs(responses(1:end)); 
        
        % Set the number of response points and their peak absolute response.
        N = 9; % N = H + 1; keep this consistent with the exported GIRF horizon.
        h_bar = max(abs_responses); % Peak absolute response within this period-specific GIRF path.
        
        % Compute resilience intensity; retain RP as the output column name.
        sum_abs = sum(abs_responses);
        RP = (N * h_bar - sum_abs) / (N * h_bar);
        
        % Compute RD using the existing one-based weights 1:N (that is, horizon + 1).
        weighted_sum = sum((1:N)' .* abs_responses);
        RD = weighted_sum / sum_abs;
        
        % Store the result.
        row_idx = (t_idx-1)*num_vars + var_idx;
        results.t(row_idx) = t;
        results.Variable{row_idx} = response_vars{var_idx};
        results.RP(row_idx) = RP;
        results.RD(row_idx) = RD;
    end
end

% Write the resilience metrics to Excel.
writetable(results, 'resilience_metrics.xlsx');
disp('Calculation completed. Results saved to resilience_metrics.xlsx.');

% Display a preview of the output.
disp('First 10 rows of the results:');
disp(results(1:min(10, height(results)), :));