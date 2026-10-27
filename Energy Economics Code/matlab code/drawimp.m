%%--------------------------------------------------------%%
%%                    TVP-VAR package                     %%
%%--------------------------------------------------------%%
%%
%%  [] = drawimp(fldraw, vt, interval, datetime, formatOut, formataxis)
%%
%%  "drawimp" draws time-varying impulse response
%%
%%  [input]
%%   (fldraw = 1)
%%     vt:   m*1 vector of horizons to draw impulse
%%   (fldraw = 2)
%%     vt:   m*1 vector of time points to draw impulse
%%

function [] = drawimp(fldraw,vt,interval,datetime,formatOut,formataxis) %Use the time interval input in plot legends.

global m_ns m_nk m_nl m_asvar;

ns = m_ns;  %Number of sample periods.
nk = m_nk;  %Number of variables.
nl = m_nl;  %VAR lag order.

mimpr = xlsread('tvpvar_imp.xlsx'); %Read the exported impulse-response matrix.
mimpm = mimpr(:, 3:end); %Select the response columns.

nimp = size(mimpm, 1) / m_ns; %Number of response points per sample period.
mline = [0 .5 0; 0 0 1; 1 0 0; 0 .7 .7]; %Colors for up to four plotted lines.
vline = {':', '--', '-', '-.'}; %Dotted, dashed, solid, and dash-dot line styles.
nline = size(vt, 2); %Number of selected horizons or sample periods.

if fldraw==1 %Plot responses over time for up to four selected horizons.
    
    figure
    for i = 1 : nk %Loop over shock variables.
        for j = 1 : nk %Loop over response variables for the current shock.
            id = (i-1)*nk + j; %Index of the shock-response pair.
            mimp = reshape(mimpm(:, id), nimp, ns)'; %Reshape this response series to ns rows and nimp horizons.
            subplot(nk,nk,id); %Position of this shock-response pair in the subplot grid.    
            for k = 1 : nline %Plot each selected horizon.
                plot(datetime,mimp(:, vt(k)+1), char(vline(k)),'Color', mline(k, :),'LineWidth',1) %Plot the response against time with the selected line style and color.
                datetick('x',formataxis);
                hold on
            end
            yl=ylim;
            tstart = datetime(nl+1,1);
            tend = datetime(ns,1)+calmonths(1);
            xlim([tstart tend]);
            if yl(1) * yl(2) < 0 %Add a zero reference line when the y-axis spans zero.
                line([tstart, tend], [0, 0], 'Color', ones(1,3)*0.6) %Draw the zero line over the displayed time range.
            end
            if id == 1
                timelabel=[interval ' after shock'];  
                vlege = timelabel; %Initialize the legend text.
                for l = 2 : nline
                    timelabel=[interval ' after shock'];
                    vlege = [vlege; timelabel]; %Append legend text for the remaining lines.
                end
                legend([num2str(vt') vlege])
            end
            hold off
            title(['$\varepsilon_{', char(m_asvar(i)),'}\uparrow\ \rightarrow\ ',char(m_asvar(j)), '$'], 'interpreter', 'latex')
        end
    end
    
elseif fldraw==2 %Plot response paths for up to four selected sample periods.
    
    figure
    for i = 1 : nk %Loop over shock variables.
        for j = 1 : nk %Loop over response variables for the current shock.
            id = (i-1)*nk + j; %Index of the shock-response pair.
            mimp = reshape(mimpm(:, id), nimp, ns)'; %Reshape this response series to ns rows and nimp horizons.
            subplot(nk, nk, id); %Position of this shock-response pair in the subplot grid.
            for k = 1 : nline
                plot(0:nimp-1, mimp(vt(k), :), char(vline(k)),'Color', mline(k, :),'LineWidth',1) %Plot horizons 0 to nimp-1 for the selected sample period.
                hold on
            end
            vax = axis;
            axis([0 nimp-1 vax(3:4)]) %Keep the full response-horizon range on the x-axis.
            if vax(3) * vax(4) < 0
                line([0, nimp-1], [0, 0], 'Color', ones(1,3)*0.6) %Draw the zero line over the response-horizon range.
            end
            Timelabel=[];
            for l=1:size(vt,2)
                Timelabel=[Timelabel;datetime(vt(1,l),1)];
            end
            if id == 1
                vlege = ['Shock at '];
                for l = 2 : nline
                    vlege = [vlege; 'Shock at '];
                end
                legend([vlege datestr(Timelabel,formatOut)])
            end
            hold off
            title(['$\varepsilon_{', char(m_asvar(i)),'}\uparrow\ \rightarrow\ ',char(m_asvar(j)), '$'], 'interpreter', 'latex')
        end
    end
    
else %Draw a separate three-dimensional response surface for each pair.
    
    for i = 1 : nk %Loop over shock variables.
        for j = 1 : nk %Loop over response variables for the current shock.
            figure
            id = (i-1)*nk + j; %Index of the shock-response pair.
            mimp = reshape(mimpm(:, id), nimp, ns)'; %Reshape this response series to ns rows and nimp horizons.
            x=datetime(nl+1:end,1);
            y=0:nimp-1;
            Z=mimp(nl+1:end,:)';
            [X,Y] = meshgrid(x,y);
            mesh(Y,X,Z)
            datetick('y', formataxis);
            set(gca,'YDir','reverse');
            set(gca,'XDir','reverse');
            title(['$\varepsilon_{', char(m_asvar(i)),'}\uparrow\ \rightarrow\ ',char(m_asvar(j)), '$'], 'interpreter', 'latex')
        end
    end
end
