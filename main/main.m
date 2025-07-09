function main(openDir, animal_name)
    adjustedCopy = [];  % this will store the latest unfiltered adjusted image
    filteredCopy = []; 
    channelActive = [true true true];  % [R, G, B] initially all ON
    removeMode = false;  % Initially OFF
    rectHandle = [];
    modeButtons = struct();  % 🛠 now officially exists
    currentShape = 'rectangle'; % Add shape state variable
    roi = []; % ROI object
    rulerLine = [];
    rulerPoints = [];

    % Handle missing animal_name argument
    if nargin < 2 || isempty(animal_name)
        animal_name = 'sample';  % Default animal name
    end

    % Optional directory to start in
    if nargin < 1 || ~isfolder(openDir)
        [file, path] = uigetfile({'*.tif;*.png;*.jpg'}, 'Select Original Image');
    else
        [file, path] = uigetfile({'*.tif;*.png;*.jpg'}, 'Select Original Image', openDir);
    end
    if isequal(file, 0), return; end
    original_rgb = im2double(imread(fullfile(path, file)));

    answer = inputdlg({'Crop Width (pixels):','Crop Height (pixels):'}, ...
                      'Crop Window Size', [1 40], {'1061','1061'});
    if isempty(answer), return; end
    cropSize = [str2double(answer{1}), str2double(answer{2})];

    [imgH, imgW, ~] = size(original_rgb);
    defaultRectPos = [round((imgW-cropSize(1))/2), round((imgH-cropSize(2))/2), cropSize];
    rectPos = defaultRectPos;

    fig = figure('Name','Interactive Crop Adjuster','NumberTitle','off', ...
        'Units','normalized','Position',[0 0 1 1]);

    %% Add shape selection buttons
    shapePanel = uipanel(fig, 'Title', 'ROI Shape', 'Position', [0.175 0.55 0.15 0.04]);
    rectButton = uicontrol(shapePanel, 'Style', 'pushbutton', 'String', 'Rectangle', ...
        'Units','normalized', 'Position', [0 0 0.5 1], ...
        'FontWeight', 'bold', 'Callback', @(~,~) setShape('rectangle'));
    polyButton = uicontrol(shapePanel, 'Style', 'pushbutton', 'String', 'Polygon', ...
        'Units','normalized', 'Position', [0.5 0 0.5 1], ...
        'FontWeight', 'normal', 'Callback', @(~,~) setShape('polygon'));

%% Create ROI function
function createROI()
    if ~isempty(roi) && isvalid(roi)
        delete(roi);
    end
    
    switch currentShape
        case 'rectangle'
            roi = drawrectangle(axOriginal, 'Position', rectPos, 'Color', 'r', 'InteractionsAllowed', 'all');
        case 'polygon'
            % Prompt user to click on image to place polygon vertices
            title(axOriginal, 'Click on the image to place the polygon vertices', 'Color', 'r');
            
            % Use drawpolygon to let user freely draw polygon
            roi = drawpolygon(axOriginal, 'Color', 'r', 'InteractionsAllowed', 'all', 'DrawingArea', 'unlimited');
            
            % Remove prompt
            title(axOriginal, '');
    end
    addlistener(roi, 'ROIMoved', @(src, evt) moveROIAction());
end

%% Shape operation functions (simplified)
function moveROIAction()
    updateImage();
    clearAllLabels(); 
end

function setShape(shape)
    currentShape = shape;
    
    % Update button style: selected is bold, unselected is normal
    if strcmp(shape, 'rectangle')
        set(rectButton, 'FontWeight', 'bold');
        set(polyButton, 'FontWeight', 'normal');
    else
        set(rectButton, 'FontWeight', 'normal');
        set(polyButton, 'FontWeight', 'bold');
    end
    
    createROI();
    updateImage();
end

uicontrol(fig, 'Style', 'text', 'String', 'Distance (px):', ...
    'Units', 'normalized', 'Position', [0.46, 0.76, 0.05, 0.025], ...
    'FontSize', 10);

rulerDistanceBox = uicontrol(fig, 'Style', 'edit', ...
    'String', '', 'Enable', 'inactive', ...
    'Units', 'normalized', 'Position', [0.46, 0.72, 0.06, 0.025], ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Ruler', ...
    'Units', 'normalized', 'Position', [0.46, 0.84, 0.041, 0.025], ...
    'BackgroundColor', [0.9 0.9 1], ...
    'Callback', @(~,~) startRulerMode());

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Ruler', ...
    'Units', 'normalized', 'Position', [0.46, 0.80, 0.041, 0.025], ...
    'BackgroundColor', [1 0.9 0.9], ...
    'Callback', @(~,~) clearRuler());

    %% Axes
    % Leave axOriginal alone, so ROI dragging works
    axOriginal = axes('Parent', fig, 'Position', [0.05 0.6 0.4 0.35]);
    imshow(original_rgb, 'Parent', axOriginal);
    title('Original Image');
    
    % Enable zoom/pan only in axCropped for navigation and labeling
    axCropped = axes('Parent', fig, 'Position', [0.5 0.6 0.25 0.35]);
    hCroppedRGB = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axCropped, 'InitialMagnification', 'fit');
    title('Adjusted RGB Crop');


    axR = axes('Parent', fig, 'Position', [0.05 0.25 0.25 0.25]);
    hR = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axR, 'InitialMagnification', 'fit'); title(axR, 'Red');
    axis(axR, 'image');
    axG = axes('Parent', fig, 'Position', [0.375 0.25 0.25 0.25]);
    hG = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axG, 'InitialMagnification', 'fit'); title(axG, 'Green');
    axis(axG, 'image');
    axB = axes('Parent', fig, 'Position', [0.7 0.25 0.25 0.25]);
    hB = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axB, 'InitialMagnification', 'fit'); title(axB, 'Blue');
    axis(axB, 'image');

    %% Draggable ROI
    roi = drawrectangle(axOriginal, 'Position', rectPos, 'Color', 'r', 'InteractionsAllowed', 'all');
    addlistener(roi, 'ROIMoved', @(src, evt) moveROIAction());

    %% Sliders and labels
    labels = {'Red','Green','Blue'};
    sliders = gobjects(3,2);
    val_labels = gobjects(3,2);
    initVals = [1, 0; 1, 0; 1, 0];

    for i = 1:3
        baseX = 0.05 + (i-1)*0.325;
        sliders(i,1) = uicontrol(fig, 'Style', 'slider', 'Min', 0.1, 'Max', 3, 'Value', initVals(i,1), ...
            'SliderStep', [0.01 0.1], 'Units','normalized', 'Position', [baseX, 0.18, 0.25, 0.025], 'Callback', @(src,~) updateImage());
        uicontrol(fig, 'Style', 'text', 'String', [labels{i} ' Contrast'], 'Units','normalized', ...
            'Position', [baseX, 0.21, 0.25, 0.02]);
        val_labels(i,1) = uicontrol(fig, 'Style', 'text', 'String', '1.00', 'Units','normalized', ...
            'Position', [baseX+0.23, 0.2, 0.05, 0.025]);

        sliders(i,2) = uicontrol(fig, 'Style', 'slider', 'Min', -0.5, 'Max', 0.5, 'Value', initVals(i,2), ...
            'SliderStep', [0.01 0.1], 'Units','normalized', 'Position', [baseX, 0.13, 0.25, 0.025], 'Callback', @(src,~) updateImage());
        uicontrol(fig, 'Style', 'text', 'String', [labels{i} ' Brightness'], 'Units','normalized', ...
            'Position', [baseX, 0.1, 0.25, 0.02]);
        val_labels(i,2) = uicontrol(fig, 'Style', 'text', 'String', '0.00', 'Units','normalized', ...
            'Position', [baseX+0.23, 0.12, 0.05, 0.025]);
    end

    %% Coordinate display boxes near original image corners
    coord_labels = {'X1','Y1','X2','Y2'};
    coord_boxes = gobjects(1,4);
    % X1, Y1 at bottom-left of original image
    coord_boxes(1) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.01, 0.58, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'X1', 'Units','normalized', 'Position', [0.01, 0.595, 0.05, 0.02]);
    coord_boxes(2) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.06, 0.58, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'Y1', 'Units','normalized', 'Position', [0.06, 0.595, 0.05, 0.02]);
    % X2, Y2 at top-right of original image
    coord_boxes(3) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.4, 0.93, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'X2', 'Units','normalized', 'Position', [0.4, 0.945, 0.05, 0.02]);
    coord_boxes(4) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.45, 0.93, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'Y2', 'Units','normalized', 'Position', [0.45, 0.945, 0.05, 0.02]);

    %% Save and Reset buttons
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset', ...
        'Units','normalized', 'Position', [0.85, 0.93, 0.12, 0.05], ...
        'FontSize', 12, 'BackgroundColor', [1 0.9 0.9], 'Callback', @(src,~) resetAll());

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save All', ...
        'Units','normalized', 'Position', [0.85, 0.87, 0.12, 0.05], ...
        'FontSize', 12, 'BackgroundColor', [0.8 1 0.8], 'Callback', @(src,~) saveAll());

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear', ...
        'Units','normalized', 'Position', [0.93, 0.78, 0.05, 0.025], ...
        'BackgroundColor', [1 0.8 0.8], 'Callback', @(~,~) clearAllLabels());

    labelVisible = true;  % initial global state

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Show/Hide', ...
        'Units','normalized', 'Position', [0.90, 0.62, 0.05, 0.025], ...
        'BackgroundColor', [0.9 0.9 1], 'Callback', @(~,~) toggleVisibility());

    %% Undo button
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Undo Label', 'Units','normalized', ...
        'Position', [0.93, 0.75, 0.05, 0.025], 'BackgroundColor', [1 0.95 0.8], ...
        'Callback', @undoClick);

    removeButton = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Remove Labels (Off)', ...
        'Units','normalized', 'Position', [0.76, 0.55, 0.1, 0.03], ...
        'BackgroundColor', [1 0.9 0.8], 'Callback', @(~,~) toggleRemoveMode());

    %% Add Import parameters button
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Import parameters', ...
        'Units','normalized', 'Position', [0.85, 0.81, 0.12, 0.05], ...
        'FontSize', 12, ...
        'BackgroundColor', [0.9 0.9 1], ...
        'Callback', @importParametersCallback);

    %% connected pixel filter
    % Red channel filter (to the right of R plot)
    rAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.26, 0.34, 0.03, 0.025]);
    maxrAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.30, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter R', ...
        'Units','normalized', 'Position', [0.28, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('R'));

    % Green channel filter (to the right of G plot)
    gAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.59, 0.34, 0.03, 0.025]);
    maxgAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.63, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter G', ...
        'Units','normalized', 'Position', [0.61, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('G'));

    % Blue channel filter (to the right of B plot)
    bAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.91, 0.34, 0.03, 0.025]);
    maxbAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.95, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter B', ...
        'Units','normalized', 'Position', [0.93, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('B'));
    %% auto count cells
    % Below existing filter R/G/B buttons (example positions)
    %% Single channel auto-labeling buttons (keep existing)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label R', ...
        'Units','normalized', 'Position', [0.27, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('R'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label G', ...
        'Units','normalized', 'Position', [0.6, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('G'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label B', ...
        'Units','normalized', 'Position', [0.92, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('B'));

    %% Add combined channel auto-labeling buttons (placed below single channel buttons)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+G', ...
        'Units','normalized', 'Position', [0.27, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [1 1 0.5], ... % Yellow background
        'Callback', @(~,~) autoLabelChannel('RG'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto G+B', ...
        'Units','normalized', 'Position', [0.6, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [0.5 1 1], ... % Cyan background
        'Callback', @(~,~) autoLabelChannel('GB'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+B', ...
        'Units','normalized', 'Position', [0.92, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [1 0.5 1], ... % Magenta background
        'Callback', @(~,~) autoLabelChannel('RB'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+G+B', ...
        'Units','normalized', 'Position', [0.47, 0.06, 0.06, 0.025], ...
        'BackgroundColor', [1 0.5 1], ... % Magenta background
        'Callback', @(~,~) autoLabelChannel('RGB'));

    %% Overlap Area Threshold input box (set maximum area for extreme overlap)
    uicontrol(fig, 'Style', 'text', 'String', 'Max Overlap Threshold', ...
        'Units', 'normalized', 'Position', [0.55 0.55 0.1 0.025]);
    overlapThreshBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units', 'normalized', 'Position', [0.64 0.55 0.05 0.025], ...
        'BackgroundColor', [1 1 1]);

    %% on/off channel
    rToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.68, 0.041, 0.025], 'BackgroundColor', [1 0.5 0.5], ...
        'Callback',@(~,~) toggleChannel(1));

    gToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.64, 0.041, 0.025],'BackgroundColor', [0.5 1 0.5], ...
        'Callback',  @(~,~) toggleChannel(2));

    bToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.6, 0.041, 0.025], 'BackgroundColor', [0.6 0.6 1], ...
        'Callback',  @(~,~) toggleChannel(3));

    %% Run first update
    updateImage();
    % === Labeling mode and state ===
    currentMode = 'R';  % can be 'R', 'G', or 'B'
    
    rCounter = 0; rHandles = []; rPositions = zeros(0,2);
    gCounter = 0; gHandles = []; gPositions = zeros(0,2);
    bCounter = 0; bHandles = []; bPositions = zeros(0,2);
    rgCounter = 0; rgHandles = []; rgPositions = zeros(0,2);
    gbCounter = 0; gbHandles = []; gbPositions = zeros(0,2);
    rbCounter = 0; rbHandles = []; rbPositions = zeros(0,2);
    rgbCounter = 0; rgbHandles = []; rgbPositions = zeros(0,2);

    counter = 0;
    labelHandles = []; 
    labelPositions = [];


    modeButtons.R = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R', ...
        'Units','normalized', 'Position', [0.76, 0.68, 0.02, 0.025], ...
        'BackgroundColor', [1 0.8 0.8], 'Callback', @(~,~) setMode('R'));

    modeButtons.G = uicontrol(fig, 'Style', 'pushbutton', 'String', 'G', ...
        'Units','normalized', 'Position', [0.76, 0.64, 0.02, 0.025], ...
        'BackgroundColor', [0.8 1 0.8], 'Callback', @(~,~) setMode('G'));

    modeButtons.B = uicontrol(fig, 'Style', 'pushbutton', 'String', 'B', ...
        'Units','normalized', 'Position', [0.76, 0.6, 0.02, 0.025], ...
        'BackgroundColor', [0.8 0.8 1], 'Callback', @(~,~) setMode('B'));

    modeButtons.RG = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+G', ...
        'Units','normalized', 'Position', [0.82, 0.68, 0.04, 0.025], ...
        'BackgroundColor', [1 1 0.8], 'Callback', @(~,~) setMode('RG'));

    modeButtons.GB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'G+B', ...
        'Units','normalized', 'Position', [0.82, 0.64, 0.04, 0.025], ...
        'BackgroundColor', [0.9 1 1], 'Callback', @(~,~) setMode('GB'));

    modeButtons.RB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+B', ...
        'Units','normalized', 'Position', [0.82, 0.6, 0.04, 0.025], ...
        'BackgroundColor', [1 0.9 1], 'Callback', @(~,~) setMode('RB'));

    modeButtons.RGB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+G+B', ...
        'Units','normalized', 'Position', [0.90, 0.66, 0.04, 0.025], ...
        'BackgroundColor', [1 0.9 1], 'Callback', @(~,~) setMode('RGB'));



    rCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.68, 0.02, 0.025]);
    gCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.64, 0.02, 0.025]);
    bCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.6, 0.02, 0.025]);

    rgCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.68, 0.02, 0.025]);
    gbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.64, 0.02, 0.025]);
    rbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.6, 0.02, 0.025]);
    rgbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.95, 0.66, 0.02, 0.025]);


    % Font size input
    uicontrol(fig, 'Style', 'text', 'String', 'Font Size', 'Units', 'normalized', ...
        'Position', [0.76, 0.75, 0.04, 0.025]);
    fontSizeBox = uicontrol(fig, 'Style', 'edit', 'String', '6', 'Units', 'normalized', ...
        'Position', [0.8, 0.75, 0.02, 0.025], 'Callback', @updateFontSize);

    % Font color dropdown
    uicontrol(fig, 'Style', 'text', 'String', 'Font Color', 'Units', 'normalized', ...
        'Position', [0.83, 0.75, 0.04, 0.025]);
    colorMenu = uicontrol(fig, 'Style', 'popupmenu', ...
    'String', {'red','green','blue','yellow','cyan','magenta','black','white'}, ...
    'Units','normalized', 'Position', [0.87, 0.75, 0.06, 0.025]);

function labelClick(~, ~)
    pt = get(axCropped, 'CurrentPoint');
    x = pt(1,1); y = pt(1,2);
    fontSize = str2double(fontSizeBox.String);
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    fontColor = colors{colorMenu.Value};
    
    switch currentMode
    case 'R'
        rCounter = rCounter + 1;
        h = text(axCropped, x, y, num2str(rCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rHandles(end+1) = h;
        if size(rPositions, 2) ~= 2
            rPositions = reshape(rPositions, [], 2);
        end
        rPositions(end+1,:) = [x, y];
    case 'G'
        gCounter = gCounter + 1;
        h = text(axCropped, x, y, num2str(gCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        gHandles(end+1) = h;
        if size(gPositions, 2) ~= 2
            gPositions = reshape(gPositions, [], 2);
        end
        gPositions(end+1,:) = [x, y];
    case 'B'
        bCounter = bCounter + 1;
        h = text(axCropped, x, y, num2str(bCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        bHandles(end+1) = h;
        if size(bPositions, 2) ~= 2
            bPositions = reshape(bPositions, [], 2);
        end
        bPositions(end+1,:) = [x, y];
        
    case 'RG'
        rgCounter = rgCounter + 1;
        h = text(axCropped, x, y, num2str(rgCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rgHandles(end+1) = h;
        if size(rgPositions, 2) ~= 2
            rgPositions = reshape(rgPositions, [], 2);
        end
        rgPositions(end+1,:) = [x, y];
    case 'GB'
        gbCounter = gbCounter + 1;
        h = text(axCropped, x, y, num2str(gbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        gbHandles(end+1) = h;
        if size(gbPositions, 2) ~= 2
            gbPositions = reshape(gbPositions, [], 2);
        end
        gbPositions(end+1,:) = [x, y];
    case 'RB'
        rbCounter = rbCounter + 1;
        h = text(axCropped, x, y, num2str(rbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rbHandles(end+1) = h;
        if size(rbPositions, 2) ~= 2
            rbPositions = reshape(rbPositions, [], 2);
        end
        rbPositions(end+1,:) = [x, y];
    case 'RGB'
        rgbCounter = rgbCounter + 1;
        h = text(axCropped, x, y, num2str(rgbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rgbHandles(end+1) = h;
        if size(rgbPositions, 2) ~= 2
            rgbPositions = reshape(rgbPositions, [], 2);
        end
        rgbPositions(end+1,:) = [x, y];
    end
        
        updateCountDisplay();
end

function filterChannel(channel)
    switch channel
        case 'R', cIndex = 1; areaThresh = str2double(rAreaBox.String); maxareaThresh = str2double(maxrAreaBox.String);
        case 'G', cIndex = 2; areaThresh = str2double(gAreaBox.String); maxareaThresh = str2double(maxgAreaBox.String);
        case 'B', cIndex = 3; areaThresh = str2double(bAreaBox.String); maxareaThresh = str2double(maxbAreaBox.String);
    end

    bw = imbinarize(adjustedCopy(:,:,cIndex));  % use current filtered image
    
    % Get bounding box areas of all connected regions
    stats = regionprops(bw, 'BoundingBox', 'PixelIdxList');
    validCells = false(size(bw));

    for k = 1:numel(stats)
        bb = stats(k).BoundingBox;
        width = bb(3);
        height = bb(4);
        
        % Check if both width and height are within min and max threshold range
        % Keep cells with width and height >= min threshold and <= max threshold
        if (width >= areaThresh && height >= areaThresh) && ...
           (width <= maxareaThresh && height <= maxareaThresh)
            validCells(stats(k).PixelIdxList) = true;
        end
    end

    % Apply filtering
    filteredChannel = adjustedCopy(:,:,cIndex);
    filteredChannel(~validCells) = 0;
    filteredCopy(:,:,cIndex) = filteredChannel;

    % Update display
    hCroppedRGB.CData = filteredCopy;
    updateSplitChannels();  % Update single channel display (need to customize this function, see below)
end

function updateSplitChannels()
    hR.CData = cat(3, filteredCopy(:,:,1), zeros(size(filteredCopy,1), size(filteredCopy,2), 2));
    hG.CData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,2), zeros(size(filteredCopy,1), size(filteredCopy,2)));
    hB.CData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,3));
end

function toggleVisibility()
    labelVisible = ~labelVisible;
    switch currentMode
        case 'R', toggleSet(rHandles);
        case 'G', toggleSet(gHandles);
        case 'B', toggleSet(bHandles);
        case 'RG', toggleSet(rgHandles);
        case 'GB', toggleSet(gbHandles);
        case 'RB', toggleSet(rbHandles);
        case 'RGB', toggleSet(rgbHandles);
    end
end

function toggleSet(handles)
    for i = 1:numel(handles)
        if isgraphics(handles(i))
            if labelVisible
                set(handles(i), 'Visible', 'on');
            else
                set(handles(i), 'Visible', 'off');
            end
        end
    end
end

function toggleRemoveMode()
    removeMode = ~removeMode;
    if removeMode
        removeButton.String = 'Remove (On)';
        set(fig, 'Pointer', 'crosshair');
        enableRectangleDrawing();
    else
        removeButton.String = 'Remove (Off)';
        set(fig, 'Pointer', 'arrow');
        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);

        % 🔥 Cancel any unfinished rectangle
        if exist('rectHandle', 'var') && isgraphics(rectHandle)
            delete(rectHandle);
        end
    end
end

function enableRectangleDrawing()
    rectHandle = drawrectangle(axCropped, 'Color', 'm', 'LineWidth', 1.5);
    rectangleDone(rectHandle);
end

function rectangleDone(rect)
    % After rectangle is drawn, delete labels inside
    boxPos = rect.Position;
    delete(rect);  % 🔥 delete the rectangle right after finishing drawing

    % Get box corners
    boxX1 = boxPos(1); boxY1 = boxPos(2);
    boxX2 = boxX1 + boxPos(3);
    boxY2 = boxY1 + boxPos(4);

    % Remove based on current mode
    switch currentMode
        case 'R'
            [rHandles, rPositions, rCounter] = removeInRegion(rHandles, rPositions, boxX1, boxY1, boxX2, boxY2);
        case 'G'
            [gHandles, gPositions, gCounter] = removeInRegion(gHandles, gPositions, boxX1, boxY1, boxX2, boxY2);
        case 'B'
            [bHandles, bPositions, bCounter] = removeInRegion(bHandles, bPositions, boxX1, boxY1, boxX2, boxY2);
        case 'RG'
            [rgHandles, rgPositions, rgCounter] = removeInRegion(rgHandles, rgPositions, boxX1, boxY1, boxX2, boxY2);
        case 'GB'
            [gbHandles, gbPositions, gbCounter] = removeInRegion(gbHandles, gbPositions, boxX1, boxY1, boxX2, boxY2);
        case 'RB'
            [rbHandles, rbPositions, rbCounter] = removeInRegion(rbHandles, rbPositions, boxX1, boxY1, boxX2, boxY2);
        case 'RGB'
            [rgbHandles, rgbPositions, rgbCounter] = removeInRegion(rgbHandles, rgbPositions, boxX1, boxY1, boxX2, boxY2);

    end

    updateCountDisplay();

    if removeMode  % double-check it again AFTER drawing
        enableRectangleDrawing();  
    else
        set(fig, 'Pointer', 'arrow');  % Reset pointer too when finished
        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);  % Restore click for manual labeling
    end

end

function [H, P, counter] = removeInRegion(H, P, boxX1, boxY1, boxX2, boxY2)
    if isempty(H) || isempty(P)
        H = []; P = zeros(0,2); counter = 0;
        return;
    end

    toKeep = true(size(P,1),1);
    for i = 1:size(P,1)
        x = P(i,1); y = P(i,2);
        if x >= boxX1 && x <= boxX2 && y >= boxY1 && y <= boxY2
            if isgraphics(H(i))
                delete(H(i));  % 💥 delete the label
            end
            toKeep(i) = false;
        end
    end
    H = H(toKeep);
    P = P(toKeep,:);
    if isempty(P)
        P = zeros(0,2);
    end

    % Renumber remaining labels
    for i = 1:numel(H)
        if isgraphics(H(i))
            set(H(i), 'String', num2str(i));
        end
    end

    counter = numel(H);
end

function toggleChannel(channelIdx)
    channelActive(channelIdx) = ~channelActive(channelIdx);
    
    % Update button label correctly
    switch channelIdx
        case 1
            if channelActive(1)
                rToggle.String = 'On';
            else
                rToggle.String = 'Off';
            end
        case 2
            if channelActive(2)
                gToggle.String = 'On';
            else
                gToggle.String = 'Off';
            end
        case 3
            if channelActive(3)
                bToggle.String = 'On';
            else
                bToggle.String = 'Off';
            end
    end
    
    % Update displayed Adjusted RGB image
    newDisplay = filteredCopy;
    for c = 1:3
        if ~channelActive(c)
            newDisplay(:,:,c) = 0;
        end
    end
    hCroppedRGB.CData = newDisplay;
    
    % ALSO update the split R, G, B images
    if channelActive(1)
        rData = cat(3, filteredCopy(:,:,1), zeros(size(filteredCopy,1), size(filteredCopy,2), 2));
    else
        rData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hR.CData = rData;
    
    if channelActive(2)
        gData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,2), zeros(size(filteredCopy,1), size(filteredCopy,2)));
    else
        gData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hG.CData = gData;
    
    if channelActive(3)
        bData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2), 2), filteredCopy(:,:,3));
    else
        bData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hB.CData = bData;
end

function undoClick(~,~)
    switch currentMode
        case 'R'
            if rCounter > 0
                delete(rHandles(end)); 
                rHandles(end) = []; 
                rPositions(end, :) = [];  % <- Fix here
                rCounter = rCounter - 1;
            end
        case 'G'
            if gCounter > 0
                delete(gHandles(end)); 
                gHandles(end) = []; 
                gPositions(end, :) = [];  % <- Fix here
                gCounter = gCounter - 1;
            end
        case 'B'
            if bCounter > 0
                delete(bHandles(end)); 
                bHandles(end) = []; 
                bPositions(end, :) = [];  % <- Fix here
                bCounter = bCounter - 1;
            end
        case 'RG'
            if rgCounter > 0
                delete(rgHandles(end)); 
                rgHandles(end) = []; 
                rgPositions(end, :) = [];  % <- Fix here
                rgCounter = rgCounter - 1;
            end
        case 'GB'
            if gbCounter > 0
                delete(gbHandles(end)); 
                gbHandles(end) = []; 
                gbPositions(end, :) = [];  % <- Fix here
                gbCounter = gbCounter - 1;
            end
        case 'RB'
            if rbCounter > 0
                delete(rbHandles(end)); 
                rbHandles(end) = []; 
                rbPositions(end, :) = [];  % <- Fix here
                rbCounter = rbCounter - 1;
            end
        case 'RGB'
            if rgbCounter > 0
                delete(rgbHandles(end)); 
                rgbHandles(end) = []; 
                rgbPositions(end, :) = [];  % <- Fix here
                rgbCounter = rgbCounter - 1;
            end
    end

    updateCountDisplay();  % <- Ensure this stays to refresh UI
end

function updateImage()
    updateImage_function(axCropped, currentShape, roi, original_rgb, imgW, imgH, ...
        coord_boxes, sliders, val_labels, hCroppedRGB, hR, hG, hB);
    
    % Update local variables from workspace
    adjustedCopy = evalin('base', 'adjustedCopy');
    filteredCopy = evalin('base', 'filteredCopy');
    
    % --- Keep ButtonDownFcn for manual labeling ---
    set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
end

function saveAll()
    saveAll_function(animal_name, currentShape, roi, imgW, imgH, hCroppedRGB, ...
        sliders, rAreaBox, gAreaBox, bAreaBox, maxrAreaBox, maxgAreaBox, maxbAreaBox, ...
        coord_boxes, rPositions, gPositions, bPositions, rgPositions, gbPositions, ...
        rbPositions, rgbPositions, overlapThreshBox);
end

% Helper function: Create parameters Excel file
function createParametersFile(folderPath, animal_name, contrast, brightness)
    try
        % Create parameter file name
        parametersFile = fullfile(folderPath, strcat('saved_parameters.xlsx'));
        
        % Channel labels
        labels = {'Red'; 'Green'; 'Blue'};
        
        % Create Channel-Contrast-Brightness table
        channelTable = table(labels, contrast', brightness', ...
                           'VariableNames', {'Channel', 'Contrast', 'Brightness'});
        
        % Get threshold parameters
        thresholdValues = [
            str2double(rAreaBox.String);      % R_Min
            str2double(maxrAreaBox.String);   % R_Max
            str2double(gAreaBox.String);      % G_Min
            str2double(maxgAreaBox.String);   % G_Max
            str2double(bAreaBox.String);      % B_Min
            str2double(maxbAreaBox.String);   % B_Max
            str2double(overlapThreshBox.String) % Overlap_Max
        ];
        
        thresholdParams = {
            'R_Min'; 'R_Max'; 'G_Min'; 'G_Max'; 
            'B_Min'; 'B_Max'; 'Overlap_Max'
        };
        
        % Create Parameter-Value table
        parameterTable = table(thresholdParams, thresholdValues, ...
                             'VariableNames', {'Parameter', 'Value'});
        
        % Save first table to Sheet1
        writetable(channelTable, parametersFile, 'Sheet', 'Sheet1');
        
        % Append second table to same Sheet (using WriteMode append and explicitly set WriteVariableNames to true)
        writetable(parameterTable, parametersFile, 'Sheet', 'Sheet1', 'WriteMode', 'Append', 'WriteVariableNames', true);
        
    catch ME
        % If parameter file creation fails, show warning but don't interrupt main program
        warning(ME.identifier, '%s', ME.message);
    end

end

function saveLabelData(excelFile, prefix, positions, areas)
    if ~isempty(positions)
        note = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        header = {'Label', 'X', 'Y', 'Area'};
        
        % Ensure areas and positions have consistent length
        if length(areas) ~= size(positions, 1)
            areas = zeros(size(positions, 1), 1);
        end
        
        data = num2cell([(1:size(positions,1))', positions, areas(:)]);
        combined = [note; header; data];
        writecell(combined, excelFile, 'Sheet', [prefix '_Labels']);
    end
end

function resetAll()
    % Reset contrast and brightness sliders
    for i = 1:3
        sliders(i,1).Value = initVals(i,1); % Contrast
        sliders(i,2).Value = initVals(i,2); % Brightness
    end

    % Reset crop window to default position (adapted for rectangle/polygon)
    if strcmp(currentShape, 'rectangle')
        % Rectangle mode uses [x,y,w,h] format
        roi.Position = defaultRectPos;
    else
        % Polygon mode: convert default rectangle to vertex coordinates
        x = defaultRectPos(1);
        y = defaultRectPos(2);
        w = defaultRectPos(3);
        h = defaultRectPos(4);
        % Generate rectangle vertices (clockwise order)
        roi.Position = [x, y; x+w, y; x+w, y+h; x, y+h]; 
        % Note: For more complex default polygons, custom vertices can be defined here
    end

    % Reset filter size boxes
    rAreaBox.String = '10';
    gAreaBox.String = '10';
    bAreaBox.String = '10';
    maxrAreaBox.String = '40';
    maxgAreaBox.String = '40';
    maxbAreaBox.String = '40';

    % Reset display settings
    fontSizeBox.String = '6';
    colorMenu.Value = 1;  % Reset to red

    % Clear ALL labels (optimized deletion logic)
    labelGroups = {'rHandles', 'gHandles', 'bHandles', ...
                   'rgHandles', 'gbHandles', 'rbHandles', 'rgbHandles'};
    for k = 1:numel(labelGroups)
        handles = eval(labelGroups{k});
        validHandles = isgraphics(handles); % Batch check validity
        delete(handles(validHandles));
        eval([labelGroups{k} ' = [];']);    % Clear handle arrays
    end

    % Reset counters and positions (merged into single line code)
    vars = {'r', 'g', 'b', 'rg', 'gb', 'rb', 'rgb'};
    for m = 1:numel(vars)
        eval([vars{m} 'Positions = zeros(0,2);']);
        eval([vars{m} 'Counter = 0;']);
    end

    % Update display and image
    updateCountDisplay();
    updateImage(); % Will automatically handle ROI normalized coordinate updates

    % Display operation completion prompt (optional)
    disp('All parameters and labels have been reset.');
end

function importParametersCallback(~, ~)
    % Pop up file selection dialog
    [file, path] = uigetfile({'*.xlsx'}, 'Please select parameter Excel file');
    if isequal(file, 0)
        return;
    end
    filename = fullfile(path, file);
    try
        % Don't specify Sheet, directly read the first sheet content
        paramTable = readtable(filename);  % Default read first sheet
        if height(paramTable) < 3
            msgbox('Parameter file is incomplete','Error','error');
            return;
        end

        % Read contrast/brightness and assign to slider
        for c = 1:3
            sliders(c,1).Value = paramTable.Contrast(c);
            set(val_labels(c,1), 'String', num2str(paramTable.Contrast(c), '%.2f'));
            sliders(c,2).Value = paramTable.Brightness(c);
            set(val_labels(c,2), 'String', num2str(paramTable.Brightness(c), '%.2f'));
        end

        % xlsread same logic, don't specify Sheet, directly read all
        [~, ~, raw] = xlsread(filename);
        for k = 4:size(raw,1)
            param = string(raw{k,1});
            value = raw{k,2};
            switch param
                case "R_Min"
                    rAreaBox.String = num2str(value);
                case "R_Max"
                    maxrAreaBox.String = num2str(value);
                case "G_Min"
                    gAreaBox.String = num2str(value);
                case "G_Max"
                    maxgAreaBox.String = num2str(value);
                case "B_Min"
                    bAreaBox.String = num2str(value);
                case "B_Max"
                    maxbAreaBox.String = num2str(value);
                case "Overlap_Max"
                    overlapThreshBox.String = num2str(value);
            end
        end

        msgbox('Parameters are imported and auto-populated successfully!', 'Success');
        updateImage();  % Refresh interface
    catch ME
        warning(ME.identifier, '%s', ME.message);
        msgbox('Failed to import parameters, please check the file format!', 'Error', 'error');
    end
end


function setMode(mode)
    currentMode = mode;

    allFields = fieldnames(modeButtons);
    for i = 1:length(allFields)
        btn = modeButtons.(allFields{i});
        set(btn, 'FontWeight', 'normal', 'FontSize', 10);  % reset normal
    end

    % Highlight selected one
    activeBtn = modeButtons.(mode);
    set(activeBtn, 'FontWeight', 'bold', 'FontSize', 12);  % bigger + bold

    % Optional: Change background color darker too
    switch mode
        case 'R'
            set(activeBtn, 'BackgroundColor', [1 0.5 0.5]);
        case 'G'
            set(activeBtn, 'BackgroundColor', [0.5 1 0.5]);
        case 'B'
            set(activeBtn, 'BackgroundColor', [0.5 0.5 1]);
        case 'RG'
            set(activeBtn, 'BackgroundColor', [1 1 0.5]);
        case 'GB'
            set(activeBtn, 'BackgroundColor', [0.5 1 1]);
        case 'RB'
            set(activeBtn, 'BackgroundColor', [1 0.5 1]);
        case 'RGB'
            set(activeBtn, 'BackgroundColor', [1 0.5 1]);
    end

    % Reset others to their normal background color
    for i = 1:length(allFields)
        if ~strcmp(allFields{i}, mode)
            btn = modeButtons.(allFields{i});
            % set their color back to original
            switch allFields{i}
                case 'R'
                    set(btn, 'BackgroundColor', [1 0.8 0.8]);
                case 'G'
                    set(btn, 'BackgroundColor', [0.8 1 0.8]);
                case 'B'
                    set(btn, 'BackgroundColor', [0.8 0.8 1]);
                case 'RG'
                    set(btn, 'BackgroundColor', [1 1 0.8]);
                case 'GB'
                    set(btn, 'BackgroundColor', [0.9 1 1]);
                case 'RB'
                    set(btn, 'BackgroundColor', [1 0.9 1]);
                case 'RGB'
                    set(btn, 'BackgroundColor', [1 0.9 1]);
            end
        end
    end

end


function updateCountDisplay()
    rCountBox.String = num2str(rCounter);
    gCountBox.String = num2str(gCounter);
    bCountBox.String = num2str(bCounter);
    rgCountBox.String = num2str(rgCounter);
    gbCountBox.String = num2str(gbCounter);
    rbCountBox.String = num2str(rbCounter);
    rgbCountBox.String = num2str(rgbCounter);

end

function updateFontSize(~, ~)
    % Get new font size
    newFontSize = str2double(fontSizeBox.String);
    
    % Verify if input is valid
    if isnan(newFontSize) || newFontSize <= 0
        fontSizeBox.String = '6'; % Restore default value
        newFontSize = 6;
    end
    
    % Update font size for all existing labels
    allHandles = [rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles];
    
    for i = 1:length(allHandles)
        if isgraphics(allHandles(i))
            set(allHandles(i), 'FontSize', newFontSize);
        end
    end
end

function autoLabelChannel(channel)
    % Set current mode and get parameters
    setMode(channel); 
    
    [rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles, ...
     rPositions, gPositions, bPositions, rgPositions, gbPositions, rbPositions, rgbPositions, ...
     rCounter, gCounter, bCounter, rgCounter, gbCounter, rbCounter, rgbCounter] = ...
     autoLabelChannel_function(channel, adjustedCopy, fontSizeBox, colorMenu, axCropped, ...
     rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles, ...
     rPositions, gPositions, bPositions, rgPositions, gbPositions, rbPositions, rgbPositions, ...
     rCounter, gCounter, bCounter, rgCounter, gbCounter, rbCounter, rgbCounter, ...
     rAreaBox, gAreaBox, bAreaBox, maxrAreaBox, maxgAreaBox, maxbAreaBox, overlapThreshBox);
    
    updateCountDisplay();
end
    
function clearAllLabels()
    switch currentMode
        case 'R'
            for i = 1:length(rHandles), delete(rHandles(i)); end
            rHandles = []; rPositions = zeros(0,2); rCounter = 0;
        case 'G'
            for i = 1:length(gHandles), delete(gHandles(i)); end
            gHandles = []; gPositions = zeros(0,2); gCounter = 0;
        case 'B'
            for i = 1:length(bHandles), delete(bHandles(i)); end
            bHandles = []; bPositions = zeros(0,2); bCounter = 0;
        case 'RG'
            for i = 1:length(rgHandles), delete(rgHandles(i)); end
            rgHandles = []; rgPositions = zeros(0,2); rgCounter = 0;
        case 'GB'
            for i = 1:length(gbHandles), delete(gbHandles(i)); end
            gbHandles = []; gbPositions = zeros(0,2); gbCounter = 0;
        case 'RB'
            for i = 1:length(rbHandles), delete(rbHandles(i)); end
            rbHandles = []; rbPositions = zeros(0,2); rbCounter = 0;
        case 'RGB'
            for i = 1:length(rgbHandles), delete(rgbHandles(i)); end
            rgbHandles = []; rgbPositions = zeros(0,2); rgbCounter = 0;
    end
    updateCountDisplay();
end

function startRulerMode()
    rulerPoints = [];  % 清空上一次
    title(axCropped, 'Click two points to measure distance', 'Color', 'b');
    set(hCroppedRGB, 'ButtonDownFcn', @rulerClick);
end

function rulerClick(~,~)
    pt = get(axCropped, 'CurrentPoint');
    pt = pt(1, 1:2);  % [x, y]
    rulerPoints(end+1, :) = pt;

    if size(rulerPoints, 1) == 2
        % 画线
        if isgraphics(rulerLine), delete(rulerLine); end
        rulerLine = line(axCropped, rulerPoints(:,1), rulerPoints(:,2), ...
            'Color', 'yellow', 'LineWidth', 2);

        % 计算距离
        d = sqrt(sum(diff(rulerPoints).^2));

        % 显示在 GUI 框中
        rulerDistanceBox.String = sprintf('%.2f', d);

        % 恢复点击逻辑
        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
        title(axCropped, 'Adjusted RGB Crop');
    end
end

function clearRuler()
    if isgraphics(rulerLine), delete(rulerLine); end
    rulerLine = [];
    rulerPoints = [];
    rulerDistanceBox.String = '';
end

    createROI();
    updateImage();
end