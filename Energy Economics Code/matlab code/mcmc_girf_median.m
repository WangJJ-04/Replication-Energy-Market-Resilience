function mcmc_girf_median(nsim, datetime, timeformat)
% ========================================================
% TVP-VAR package
% MCMC estimation for TVP-VAR model
%
% Modified features:
% 1) With fastimp = 0, compute pointwise posterior medians of draw-specific GIRFs.
% 2) Automatically export the five figure groups to PDF.
% 3) Use print -dpdf -painters to avoid invalid-handle issues with exportgraphics.
% ========================================================

global m_my m_asvar m_nl m_ns m_nk m_fli m_flSb m_flSa m_flSh ...
       m_nimp m_flfi m_iseed m_dvb0 m_dVb0 m_dva0 m_dVa0 ...
       m_dvh0 m_dVh0 m_k

tic;

% ========================================================
% 0) Output directory
% ========================================================
project_dir = fileparts(fileparts(fileparts(mfilename('fullpath'))));
outdir = fullfile(project_dir, 'Fig');
if ~exist(outdir, 'dir')
    mkdir(outdir);
end

%% -------------------------------------------------------
%% set default options
%% -------------------------------------------------------
if isempty(m_fli) == 1
    m_fli = 0;
end
if isempty(m_flSb) == 1
    m_flSb = 0;
end
if isempty(m_flSa) == 1
    m_flSa = 0;
end
if isempty(m_flSh) == 1
    m_flSh = 0;
end
if isempty(m_nimp) == 1
    m_nimp = 12 + 1;
end
if isempty(m_flfi) == 1
    m_flfi = 1;
end
if isempty(m_iseed) == 1
    m_iseed = 1;
end

rand('state', m_iseed);
randn('state', m_iseed);

%% -------------------------------------------------------
%% set variables
%% -------------------------------------------------------
ns = m_ns;  % # of time periods
nk = m_nk;  % # of series
nl = m_nl;  % # of lags
nb = nk * (nk * nl + m_fli);  % # of coefficients in beta
na = nk * (nk - 1) / 2;       % # of parameters in a

if m_fli == 1
    vym = zeros(1, nk);
else
    vym = mean(m_my);
end
m_my = m_my - ones(ns, 1) * vym;

myh  = zeros(ns, nk);
mya  = zeros(ns, nk);
amX  = zeros(nk, nb, ns);
amXh = zeros(nk, na, ns);
amG2 = zeros(nk, nk, ns);
mai  = zeros(ns, na);

for i = nl + 1 : ns
    amX(:, :, i) = fXt(m_my(i - nl:i - 1, :), m_fli);
end

disp(['m_flfi = ', num2str(m_flfi)])

mb = zeros(ns, nb);
ma = zeros(ns, na);
mh = zeros(ns, nk);

mSigb = eye(nb) * 0.01;
mSiga = eye(na) * 0.01;
mSigh = eye(nk) * 0.01;

vidb = 1:nb;
if m_fli == 1
    vidi = (0:nk-1) * (nk * nl + 1) + 1;
    vidb(vidi) = [];
end
[v1, v2] = find(triu(reshape(1:nk^2, nk, nk)', 1));
vida = (v1 - 1) * nk + v2;

%% -------------------------------------------------------
%% prior
%% -------------------------------------------------------
if isempty(m_dvb0) == 1
    if m_flSb == 1
        m_dvb0 = 25;     % Sigma ~ IW(vb0, I*Vb0)
        m_dVb0 = 0.01;
    else
        m_dvb0 = 80;     % sigb_i^2 ~ IG(vb0/2, Vb0/2)
        m_dVb0 = 4 * 1e-2;
    end
elseif m_flSb == 0
    m_dvb0 = m_dvb0 * 2;
    m_dVb0 = m_dVb0 * 2;
end

if isempty(m_dva0) == 1
    m_dva0 = 8;          % siga_i^2 ~ IG(va0/2, Va0/2)
    m_dVa0 = 4 * 1e-2;
end
if isempty(m_dvh0) == 1
    m_dvh0 = 8;          % sigh_i^2 ~ IG(vh0/2, Vh0/2)
    m_dVh0 = 4 * 1e-2;
end

vb0 = zeros(nb, 1);      % b_1 ~ N(b0, Sb0)
mSb0 = eye(nb) * 10;

va0 = zeros(na, 1);      % a_1 ~ N(a0, Sa0)
if m_flSa == 1
    mSa0 = eye(na) * m_dVa0;
else
    mSa0 = eye(na) * 10;
end

vh0 = zeros(nk, 1);      % h_1 ~ N(h0, Sh0)
if m_flSh == 1
    mSh0 = eye(nk) * m_dVh0;
else
    mSh0 = eye(nk) * 50;
end

mS0  = eye(nb) * m_dVb0;
dnub = m_dvb0 + ns - nl - 1;
dnua = m_dva0 + ns - nl - 1;
dnuh = m_dvh0 + ns - nl - 1;

%% -------------------------------------------------------
%% sampling option
%% -------------------------------------------------------
nburn = round(0.1 * nsim);      % burn-in
npmt  = 6;                      % # of stored hyper-parameters

msamp    = zeros(nsim, npmt);
msamph   = zeros(ns, nk);
msamphs  = zeros(ns, nk);
msampa   = zeros(ns, na);
msampas  = zeros(ns, na);
msampai  = zeros(ns, na);
msampais = zeros(ns, na);

if m_fli == 1
    msampi  = zeros(ns, nk);
    msampis = zeros(ns, nk);
end

if m_flfi == 1
    % fastimp = 1: accumulate parameter paths for posterior means.
    msampb = zeros(ns, length(vidb));
else
    % fastimp = 0: store each draw-specific GIRF and take posterior medians.
    % Memory use increases with nsim.
    mgirf_draws = zeros(ns * m_nimp, nk^2, nsim, 'single');

    % Uncomment if posterior medians of conventional IRFs are also needed:
    % mimp_draws = zeros(ns * m_nimp, nk^2, nsim, 'single');
end

nK = floor(m_ns / 30) - 1;      % # of blocks for sampling h

%% -------------------------------------------------------
%% MCMC sampling
%% -------------------------------------------------------
fprintf('\nIteration:\n');

for m_k = -nburn : nsim

    %% --- sampling beta --- %%
    for i = nl + 1 : ns
        mAinv = finvm(fAt(ma(i, :), nk));
        amG2(:, :, i) = mAinv * diag(exp(mh(i, :))) * mAinv';
        mai(i, :) = mAinv(vida)';
    end

    mb(nl + 1:end, :) = ssmooth( ...
        m_my(nl + 1:end, :), ...
        amX(:, :, nl + 1:end), ...
        amG2(:, :, nl + 1:end), ...
        mSigb, vb0, mSb0 )';

    %% --- sampling a --- %%
    for i = nl + 1 : ns
        myh(i, :) = m_my(i, :) - mb(i, :) * amX(:, :, i)';
        amXh(:, :, i) = fXh(myh(i, :), nk, na);
        amG2(:, :, i) = diag(exp(mh(i, :)));
    end

    ma(nl + 1:end, :) = ssmooth( ...
        myh(nl + 1:end, :), ...
        amXh(:, :, nl + 1:end), ...
        amG2(:, :, nl + 1:end), ...
        mSiga, va0, mSa0 )';

    %% --- sampling h --- %%
    for i = nl + 1 : ns
        mya(i, :) = myh(i, :) * fAt(ma(i, :), nk)';
    end

    if m_flSh == 1
        mh(nl + 1:end, :) = svsamp_mv( ...
            mya(nl + 1:end, :), mh(nl + 1:end, :), ...
            mSigh, vh0, mSh0, nK);
    else
        for i = 1 : nk
            mh(nl + 1:end, i) = svsamp( ...
                mya(nl + 1:end, i), mh(nl + 1:end, i), ...
                mSigh(i, i), vh0(i), mSh0(i, i), nK);
        end
    end

    %% --- sampling Sigma --- %%
    mdif = diff(mb(nl + 1:end, :));
    if m_flSb == 1
        mSb = inv(mS0 + mdif' * mdif);
        mSb = (mSb + mSb') / 2;
        [~, p] = chol(mSb, 'lower');
        if p > 0
            mSb = diag(diag(mSb));
        end
        mSigb = inv(wishrnd(mSb, dnub));
        mSigb = (mSigb + mSigb') / 2;
    else
        vSb = m_dVb0 + sum(mdif .^ 2);
        mSigb = diag(1 ./ gamrnd(dnub / 2, 2 ./ vSb));
    end

    mdifa = diff(ma(nl + 1:end, :));
    if m_flSa == 1
        mSa = inv(mSa0 + mdifa' * mdifa);
        mSa = (mSa + mSa') / 2;
        [~, pa] = chol(mSa, 'lower');
        if pa > 0
            mSa = diag(diag(mSa));
        end
        mSiga = inv(wishrnd(mSa, dnua));
        mSiga = (mSiga + mSiga') / 2;
    else
        vSa = m_dVa0 + sum(mdifa .^ 2);
        mSiga = diag(1 ./ gamrnd(dnua / 2, 2 ./ vSa));
    end

    mdifh = diff(mh(nl + 1:end, :));
    if m_flSh == 1
        mSh = inv(mSh0 + mdifh' * mdifh);
        mSh = (mSh + mSh') / 2;
        [~, ph] = chol(mSh, 'lower');
        if ph > 0
            mSh = diag(diag(mSh));
        end
        mSigh = inv(wishrnd(mSh, dnuh));
        mSigh = (mSigh + mSigh') / 2;
    else
        vSh = m_dVh0 + sum(mdifh .^ 2);
        mSigh = diag(1 ./ gamrnd(dnuh / 2, 2 ./ vSh));
    end

    %% --- storing sample --- %%
    if m_k > 0
        msamp(m_k, :) = [ ...
            mSigb(1,1), mSigb(2,2), ...
            mSiga(1,1), mSiga(2,2), ...
            mSigh(1,1), mSigh(2,2)];

        msamph   = msamph   + mh;
        msamphs  = msamphs  + mh .^ 2;
        msampa   = msampa   + ma;
        msampas  = msampas  + ma .^ 2;
        msampai  = msampai  + mai;
        msampais = msampais + mai .^ 2;

        if m_fli == 1
            msampi  = msampi  + mb(:, vidi);
            msampis = msampis + mb(:, vidi) .^ 2;
        end

        if m_flfi == 1
            msampb = msampb + mb(:, vidb);
        else
            mgirf_draws(:, :, m_k) = single( ...
                impulse_girf(nl, m_nimp, mb(:, vidb), ma, mh) );

            % Uncomment if posterior medians of conventional IRFs are also needed:
            % mimp_draws(:, :, m_k) = single( ...
            %     impulse(nl, m_nimp, mb(:, vidb), ma, mh) );
        end
    end

    if mod(m_k, 100) == 0
        fprintf('%i \n', m_k);
    end
end

%% -------------------------------------------------------
%% output result
%% -------------------------------------------------------
iBm  = min([500, nsim / 2]);
iacf = iBm;

aspar  = char('sb1  ', 'sb2', 'sa1', 'sa2', 'sh1', 'sh2');
aspar2 = char('  s_{b1}', '  s_{b2}', '  s_{a1}', '  s_{a2}', ...
              '  s_{h1}', '  s_{h2}');

fprintf('\n\n                        [ESTIMATION RESULT]')
fprintf('\n----------------------------------')
fprintf('------------------------------------')
fprintf('\nParameter   Mean      Stdev       ')
fprintf('95%%U       95%%L    Geweke     Inef.')
fprintf('\n----------------------------------')
fprintf('------------------------------------\n')

msamp = sqrt(msamp);

for i = 1 : npmt
    vsamp   = msamp(:, i);
    vsamp_s = sort(vsamp);
    fprintf('%s %10.4f %10.4f %10.4f %10.4f %9.3f %9.2f\n', ...
        aspar(i, :), ...
        [mean(vsamp), std(vsamp), ...
        vsamp_s(floor(nsim * [0.025; 0.975]))'], ...
        fGeweke(vsamp, iBm), ...
        ftsvar(vsamp, iBm) / var(vsamp));
end

fprintf('-----------------------------------')
fprintf('-----------------------------------')
fprintf('\nTVP-VAR model (Lag = %i', nl)
fprintf(')\nIteration: %i', nsim)
if m_flSb == 0
    fprintf('\nSigma(b): Diagonal')
end

%% -------------------------------------------------------
%% output graphs metadata
%% -------------------------------------------------------
asl = cell(2, nk * 2 + 1);
asl{1,1} = 'Posterior:';
asl{2,1} = 'Variable:';
asl{1,2} = 'Mean';
asl{1,nk+2} = 'Standard deviation';

ii = 2;
for i = 1 : 2
    for j = 1 : nk
        asl{2, ii} = char(m_asvar(j));
        ii = ii + 1;
    end
end

asm = cell(2, na * 2 + 1);
asm{1,1} = 'Posterior:';
asm{2,1} = 'Variable:';
asm{1,2} = 'Mean';
asm{1,na+2} = 'Standard deviation';

ii = 2;
for i = 1 : 2
    for j = 1 : na
        asm{2, ii} = num2str(j);
        ii = ii + 1;
    end
end

%% =======================================================
%% 1) Parameter diagnostic plots
%% =======================================================
fig_diag = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters');
vacf = zeros(iacf, 1);

for i = 1 : npmt
    for j = 1 : iacf
        macf = corrcoef(msamp(j + 1:end, i), msamp(1:end - j, i));
        vacf(j) = macf(2, 1);
    end

    subplot(3, npmt, i)
    sysh = stem(vacf);
    set(sysh, 'Marker', 'none')
    axis([0 iacf -1 1])
    title(aspar2(i, :))

    subplot(3, npmt, npmt + i)
    plot(msamp(:, i))
    title(aspar2(i, :))
    vax = axis;
    axis([0 nsim vax(3:4)])

    subplot(3, npmt, npmt * 2 + i)
    hist(msamp(:, i), 15)
    title(aspar2(i, :))
end

export_pdf_figure(fig_diag, '01_parameter_diagnostics.pdf', outdir);

%% =======================================================
%% 2) draw h
%% =======================================================
msamph  = msamph / nsim;
msamphs = sqrt(msamphs / nsim - msamph .^ 2);

if m_fli == 1
    m_my = m_my + ones(ns, 1) * vym;
end

fig_h = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters');

for i = 1 : nk
    subplot(2, nk, i);
    plot(m_my(nl + 1:end, i))
    vax = axis;
    axis([0 ns - nl vax(3:4)])
    if vax(3) * vax(4) < 0
        line([0, ns], [0, 0], 'Color', ones(1,3) * 0.6)
    end
    title(char(m_asvar(i)), 'interpreter', 'latex')
end

for i = 1 : nk
    subplot(2, nk, i + nk);
    plot(exp(msamph(nl + 1:end, i)))
    hold on
    plot(exp(msamph(nl + 1:end, i) - msamphs(nl + 1:end, i)), 'r:')
    plot(exp(msamph(nl + 1:end, i) + msamphs(nl + 1:end, i)), 'r:')
    hold off
    vax = axis;
    axis([1 ns - nl vax(3:4)])
    title(char(m_asvar(i)), 'interpreter', 'latex')
end

mout = [msamph msamphs];
mout(1:nl, :) = NaN(nl, nk * 2);

if isequal(exist('tvpvar_vol.xlsx', 'file'), 2)
    delete('tvpvar_vol.xlsx');
end
writecell(asl, 'tvpvar_vol.xlsx', 'Sheet', 1, 'Range', 'A1');
writematrix([(1:ns)', mout], 'tvpvar_vol.xlsx', 'Sheet', 1, 'Range', 'A3');

export_pdf_figure(fig_h, '02_stochastic_volatility.pdf', outdir);

%% =======================================================
%% 3) draw a
%% =======================================================
msampa  = msampa / nsim;
msampas = sqrt(msampas / nsim - msampa .^ 2);

fig_a = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters');

for i = 1 : na
    subplot(ceil(na / 2), 2, i);
    plot(msampa(nl + 1:end, i))
    hold on
    plot(msampa(nl + 1:end, i) - msampas(nl + 1:end, i), 'r:')
    plot(msampa(nl + 1:end, i) + msampas(nl + 1:end, i), 'r:')
    hold off
    vax = axis;
    axis([0 ns - nl vax(3:4)])
    if vax(3) * vax(4) < 0
        line([nl - 1, ns + 1], [0, 0], 'Color', ones(1,3) * 0.6)
    end
    title(['$a_{', num2str(i), 't}$'], 'interpreter', 'latex')
    if i == 1
        legend('Posterior mean', '1SD bands')
    end
end

mout = [msampa msampas];
mout(1:nl, :) = NaN(nl, na * 2);

if isequal(exist('tvpvar_a.xlsx', 'file'), 2)
    delete('tvpvar_a.xlsx');
end
writecell(asm, 'tvpvar_a.xlsx', 'Sheet', 1, 'Range', 'A1');
writematrix([(1:ns)', mout], 'tvpvar_a.xlsx', 'Sheet', 1, 'Range', 'A3');

export_pdf_figure(fig_a, '03_time_varying_a.pdf', outdir);

%% =======================================================
%% 4) draw a-inverse
%% =======================================================
msampai  = msampai / nsim;
msampais = sqrt(msampais / nsim - msampai .^ 2);

fig_ai = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters');

for i = 1 : na
    subplot(ceil(na / 2), 2, i);
    plot(msampai(nl + 1:end, i))
    hold on
    plot(msampai(nl + 1:end, i) - msampais(nl + 1:end, i), 'r:')
    plot(msampai(nl + 1:end, i) + msampais(nl + 1:end, i), 'r:')
    hold off
    vax = axis;
    axis([0 ns - nl vax(3:4)])
    if vax(3) * vax(4) < 0
        line([nl - 1, ns + 1], [0, 0], 'Color', ones(1,3) * 0.6)
    end

    if i == 1
        title(['$\tilde{a}_{', num2str(i), ...
               't}$ ($A_t^{-1}$: ', ...
               char(m_asvar(fix((vida(i) - 1) / nk) + 1)), ...
               '$\to$', ...
               char(m_asvar(mod(vida(i) - 1, nk) + 1)), ')'], ...
               'interpreter', 'latex')
        legend('Posterior mean', '1SD bands')
    else
        title(['$\tilde{a}_{', num2str(i), 't}$ (', ...
               char(m_asvar(fix((vida(i) - 1) / nk) + 1)), ...
               '$\to$', ...
               char(m_asvar(mod(vida(i) - 1, nk) + 1)), ')'], ...
               'interpreter', 'latex')
    end
end

mout = [msampai msampais];
mout(1:nl, :) = NaN(nl, na * 2);

if isequal(exist('tvpvar_ai.xlsx', 'file'), 2)
    delete('tvpvar_ai.xlsx');
end
writecell(asm, 'tvpvar_ai.xlsx', 'Sheet', 1, 'Range', 'A1');
writematrix([(1:ns)', mout], 'tvpvar_ai.xlsx', 'Sheet', 1, 'Range', 'A3');

export_pdf_figure(fig_ai, '04_time_varying_a_inverse.pdf', outdir);

%% =======================================================
%% 5) draw intercept
%% =======================================================
if m_fli == 1
    msampi  = msampi / nsim;
    msampis = sqrt(msampis / nsim - msampi .^ 2);

    fig_int = figure('Visible', 'off', 'Color', 'w', 'Renderer', 'painters');

    for i = 1 : nk
        subplot(ceil(nk / 2), 2, i);
        plot(msampi(nl + 1:end, i))
        hold on
        plot(msampi(nl + 1:end, i) - msampis(nl + 1:end, i), 'r:')
        plot(msampi(nl + 1:end, i) + msampis(nl + 1:end, i), 'r:')
        hold off
        vax = axis;
        axis([0 ns - nl vax(3:4)])
        if vax(3) * vax(4) < 0
            line([nl - 1, ns + 1], [0, 0], 'Color', ones(1,3) * 0.6)
        end
        if i == 1
            title(['Intercept ($c_t$): ', char(m_asvar(i))], ...
                  'interpreter', 'latex')
            legend('Posterior mean', '1SD bands')
        else
            title(char(m_asvar(i)), 'interpreter', 'latex')
        end
    end

    mout = [msampi msampis];
    mout(1:nl, :) = NaN(nl, nk * 2);

    if isequal(exist('tvpvar_int.xlsx', 'file'), 2)
        delete('tvpvar_int.xlsx');
    end
    writecell(asl, 'tvpvar_int.xlsx', 'Sheet', 1, 'Range', 'A1');
    writematrix([(1:ns)', mout], 'tvpvar_int.xlsx', 'Sheet', 1, 'Range', 'A3');

    export_pdf_figure(fig_int, '05_time_varying_intercept.pdf', outdir);
end

%% -------------------------------------------------------
%% save impulse response
%% -------------------------------------------------------
if m_flfi == 1
    mimpm = impulse(nl, m_nimp, msampb / nsim, msampa, msamph);
    mgirfm = impulse_girf(nl, m_nimp, msampb / nsim, msampa, msamph);
else
    mgirfm = double(median(mgirf_draws, 3));

    % Uncomment if posterior medians of conventional IRFs are also needed:
    % mimpm = double(median(mimp_draws, 3));
end

if exist('mimpm', 'var')
    mimpm(1:m_nimp * nl, :) = NaN;
end
mgirfm(1:m_nimp * nl, :) = NaN;

mout = [NaN(ns * m_nimp, 1), kron(ones(ns, 1), (0:m_nimp - 1)')];
mout((0:ns - 1) * m_nimp + 1, 1) = (1:ns)';

asl = cell(3, nk^2 + 2);
asl{1,2} = 'Response:';
asl{2,2} = 'Shock:';
asl{3,1} = 't';
asl{3,2} = 'horizon';

ii = 3;
for i = 1 : nk
    for j = 1 : nk
        asl{1, ii} = char(m_asvar(j));
        asl{2, ii} = char(m_asvar(i));
        ii = ii + 1;
    end
end

if isequal(exist('tvpvar_imp.xlsx', 'file'), 2)
    delete('tvpvar_imp.xlsx');
end
writecell(asl, 'tvpvar_imp.xlsx', 'Sheet', 1, 'Range', 'A1');
writematrix([mout, mgirfm], 'tvpvar_imp.xlsx', 'Sheet', 1, 'Range', 'A4');

fprintf('\n\nRanseed: %i', m_iseed);
fprintf('\nTime: %.2f', toc);
fprintf('\nPDF figures saved to: %s', outdir);
fprintf('\n\n')

end


% ========================================================
% Local helper function: export figure to PDF
% ========================================================
function export_pdf_figure(fig, filename, outdir)

filepath = fullfile(outdir, filename);

if ~ishghandle(fig, 'figure')
    error('export_pdf_figure:InvalidFigure', ...
          'Figure handle is invalid before export: %s', filename);
end

set(fig, 'Color', 'w');
set(fig, 'Renderer', 'painters');
set(fig, 'InvertHardcopy', 'off');
set(fig, 'Units', 'inches');

pos = get(fig, 'Position');
if pos(3) < 11
    pos(3) = 11;
end
if pos(4) < 6.5
    pos(4) = 6.5;
end
set(fig, 'Position', pos);

set(fig, 'PaperUnits', 'inches');
set(fig, 'PaperPositionMode', 'manual');
set(fig, 'PaperPosition', [0 0 pos(3) pos(4)]);
set(fig, 'PaperSize', [pos(3) pos(4)]);

drawnow;

if ~ishghandle(fig, 'figure')
    error('export_pdf_figure:InvalidFigureAfterDrawnow', ...
          'Figure handle became invalid before print: %s', filename);
end

print(fig, filepath, '-dpdf', '-painters');

% Uncomment to close the figure automatically after export.
% close(fig);

end
