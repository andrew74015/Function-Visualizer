function runVisualizer()
% RUNVISUALIZER  Porneste o aplicatie simpla pentru vizualizarea functiilor
%   ruleaza: runVisualizer

% --- Default settings (personalizabile) ---
cfg.expr      = '(x.^2 - y.^2)./(x.^2 + y.^2)'; % expresie initiala (foloseste .^ ./ .* )
cfg.xrange    = [-2 2];
cfg.yrange    = [-2 2];
cfg.zrange    = [];            % [] -> auto
cfg.baseN     = 200;           % rezolutie initiala
cfg.Nmax      = 1200;          % rezolutie maxima la zoom
cfg.plotType  = 'surf';        % 'surf' | 'mesh' | 'contour3' | 'scatter3'
cfg.colormap  = 'parula';
cfg.showGrid  = true;
cfg.maskInfNaN = true;         % daca true, inlocuieste Inf cu NaN

% --- Build UI ---
fig = uifigure('Name','Function Visualizer','Position',[100 100 1100 700]);
% Left panel: controls
ctrlPanel = uipanel(fig,'Title','Controls','Position',[10 10 300 680]);

% Expression
lblExpr = uilabel(ctrlPanel,'Position',[10 620 280 20],'Text','Expression f(x,y) or f(x,y,z):');
txtExpr = uitextarea(ctrlPanel,'Position',[10 520 280 100],'Value',cfg.expr);

% Domain
uilabel(ctrlPanel,'Position',[10 490 200 20],'Text','X range [xmin xmax] (space separated):');
edtX = uieditfield(ctrlPanel,'text','Position',[10 465 280 22],'Value',sprintf('%g %g',cfg.xrange));
uilabel(ctrlPanel,'Position',[10 435 200 20],'Text','Y range [ymin ymax] (space separated):');
edtY = uieditfield(ctrlPanel,'text','Position',[10 410 280 22],'Value',sprintf('%g %g',cfg.yrange));

% Resolution
uilabel(ctrlPanel,'Position',[10 380 200 20],'Text','Base resolution (N):');
sldN = uislider(ctrlPanel,'Position',[10 360 260 3],'Limits',[50 800],'Value',cfg.baseN);
lblN = uilabel(ctrlPanel,'Position',[10 340 200 20],'Text',sprintf('N = %d',round(cfg.baseN)));

% Plot type
uilabel(ctrlPanel,'Position',[10 310 200 20],'Text','Plot type:');
ddPlot = uidropdown(ctrlPanel,'Items',{'surf','mesh','contour3','scatter3'},'Position',[10 285 150 22],'Value',cfg.plotType);

% Colormap
uilabel(ctrlPanel,'Position',[10 255 200 20],'Text','Colormap:');
ddMap = uidropdown(ctrlPanel,'Items',{'parula','jet','hot','viridis','turbo','gray'},'Position',[10 230 150 22],'Value',cfg.colormap);

% Buttons
btnUpdate = uibutton(ctrlPanel,'push','Text','Update Plot','Position',[10 190 120 30]);
btnReset  = uibutton(ctrlPanel,'push','Text','Reset View','Position',[150 190 120 30]);
btnExport = uibutton(ctrlPanel,'push','Text','Export Image','Position',[10 150 120 30]);

% Options
chkMask = uicheckbox(ctrlPanel,'Text','Mask Inf/NaN','Position',[10 120 150 20],'Value',cfg.maskInfNaN);
chkGrid = uicheckbox(ctrlPanel,'Text','Show grid','Position',[10 95 150 20],'Value',cfg.showGrid);

% Right panel: axes
axPanel = uipanel(fig,'Title','Plot','Position',[320 10 760 680]);
ax = uiaxes(axPanel,'Position',[10 10 740 640]);
colormap(ax,cfg.colormap);
view(ax,3);
axis(ax,'tight');

% store handles in appdata
app.ax = ax;
app.txtExpr = txtExpr;
app.edtX = edtX;
app.edtY = edtY;
app.sldN = sldN;
app.lblN = lblN;
app.ddPlot = ddPlot;
app.ddMap = ddMap;
app.chkMask = chkMask;
app.chkGrid = chkGrid;
app.cfg = cfg;
guidata(fig,app);

% initial plot
updatePlot();

% --- Callbacks ---
sldN.ValueChangedFcn = @(s,e) onNChanged(s,e,fig);
btnUpdate.ButtonPushedFcn = @(s,e) updatePlot();
btnReset.ButtonPushedFcn  = @(s,e) resetView();
btnExport.ButtonPushedFcn = @(s,e) exportImage();
ddMap.ValueChangedFcn = @(s,e) colormap(ax,ddMap.Value);
ddPlot.ValueChangedFcn = @(s,e) updatePlot();

% enable zoom/pan/rotate with automatic re-sampling on zoom end
hZoom = zoom(fig);
hZoom.ActionPostCallback = @(obj,ev) zoomResample();
hPan = pan(fig);
hPan.ActionPostCallback = @(obj,ev) zoomResample();

% --- Nested helper functions (access shared variables) ---
    function onNChanged(s,e,figHandle)
        app = guidata(figHandle);
        app.cfg.baseN = round(s.Value);
        app.lblN.Text = sprintf('N = %d',app.cfg.baseN);
        guidata(figHandle,app);
    end

    function fh = makeHandle(exprStr)
        % evaluateFunction helper (safe wrapper)
        try
            fh = evaluateFunction(exprStr);
        catch ME
            uialert(fig, ['Expresie invalida: ' ME.message],'Error');
            fh = [];
        end
    end

    function updatePlot()
        app = guidata(fig);
        exprStr = strtrim(app.txtExpr.Value);
        % parse ranges
        xr = sscanf(app.edtX.Value,'%f')';
        yr = sscanf(app.edtY.Value,'%f')';
        if numel(xr)~=2 || numel(yr)~=2
            uialert(fig,'Range-urile trebuie sa fie doua numere separate prin spatiu','Input error');
            return;
        end
        app.cfg.xrange = xr;
        app.cfg.yrange = yr;
        app.cfg.baseN = round(app.sldN.Value);
        app.cfg.plotType = app.ddPlot.Value;
        app.cfg.colormap = app.ddMap.Value;
        app.cfg.maskInfNaN = app.chkMask.Value;
        app.cfg.showGrid = app.chkGrid.Value;
        guidata(fig,app);

        fh = makeHandle(exprStr);
        if isempty(fh), return; end

        % sample grid
        N = app.cfg.baseN;
        x = linspace(app.cfg.xrange(1),app.cfg.xrange(2),N);
        y = linspace(app.cfg.yrange(1),app.cfg.yrange(2),N);
        [X,Y] = meshgrid(x,y);

        % try evaluate; support f(x,y) or f(x,y,z) where z can be ignored
        try
            Z = fh(X,Y);
        catch ME
            uialert(fig,['Eroare la evaluare: ' ME.message],'Eval error');
            return;
        end
        if app.cfg.maskInfNaN
            Z(~isfinite(Z)) = NaN;
        end

        % clear axes and plot according to type
        cla(app.ax);
        switch app.cfg.plotType
            case 'surf'
                s = surf(app.ax,X,Y,Z,'EdgeColor','none');
                shading(app.ax,'interp');
            case 'mesh'
                mesh(app.ax,X,Y,Z);
            case 'contour3'
                contour3(app.ax,X,Y,Z,40);
            case 'scatter3'
                % scatter with downsampling if too many points
                pts = numel(X);
                maxPts = 200000;
                if pts>maxPts
                    idx = round(linspace(1,pts,maxPts));
                    Xs = X(idx); Ys = Y(idx); Zs = Z(idx);
                else
                    Xs = X(:); Ys = Y(:); Zs = Z(:);
                end
                scatter3(app.ax,Xs,Ys,Zs,6,Zs,'filled');
            otherwise
                surf(app.ax,X,Y,Z,'EdgeColor','none');
        end
        colormap(app.ax,app.cfg.colormap);
        if app.cfg.showGrid, grid(app.ax,'on'); else grid(app.ax,'off'); end
        xlabel(app.ax,'x'); ylabel(app.ax,'y'); zlabel(app.ax,'z');
        title(app.ax,exprStr,'Interpreter','none');
        view(app.ax,3);
        camlight(app.ax,'headlight'); lighting(app.ax,'gouraud');
        drawnow;
    end

    function zoomResample()
        % la finalul unui zoom/pan, regenereaza cu N mai mare in zona vizualizata
        app = guidata(fig);
        xl = xlim(app.ax); yl = ylim(app.ax);
        span = max(diff(xl),diff(yl));
        % formula adaptiva: cand span scade, N creste
        N = min(app.cfg.Nmax, max(100, round(app.cfg.baseN * (4/(span+eps)))));
        % update slider visually but do not change baseN permanently
        app.sldN.Value = N;
        app.lblN.Text = sprintf('N = %d',round(N));
        guidata(fig,app);

        % resample and update plot using new N
        exprStr = strtrim(app.txtExpr.Value);
        fh = makeHandle(exprStr);
        if isempty(fh), return; end
        x = linspace(xl(1),xl(2),round(N));
        y = linspace(yl(1),yl(2),round(N));
        [X,Y] = meshgrid(x,y);
        try
            Z = fh(X,Y);
        catch
            return;
        end
        if app.cfg.maskInfNaN, Z(~isfinite(Z)) = NaN; end

        % update existing plot data if possible
        ch = app.ax.Children;
        if ~isempty(ch) && isprop(ch(1),'XData')
            set(ch(1),'XData',X,'YData',Y,'ZData',Z);
        else
            % fallback: redraw
            updatePlot();
        end
        drawnow;
    end

    function resetView()
        app = guidata(fig);
        xlim(app.ax,app.cfg.xrange);
        ylim(app.ax,app.cfg.yrange);
        zlim(app.ax,'auto');
        app.sldN.Value = app.cfg.baseN;
        app.lblN.Text = sprintf('N = %d',app.cfg.baseN);
        guidata(fig,app);
        updatePlot();
    end

    function exportImage()
        % export current axes to PNG
        [file,path] = uiputfile({'*.png';'*.jpg';'*.tif'},'Save image as');
        if isequal(file,0), return; end
        fname = fullfile(path,file);
        % use exportgraphics for uiaxes
        try
            exportgraphics(app.ax,fname,'Resolution',300);
            uialert(fig,['Saved to ' fname],'Export');
        catch ME
            uialert(fig,['Export failed: ' ME.message],'Error');
        end
    end

end