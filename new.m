
crop_adjust_gui_drag('C:\Users\cvm-gritton-lab\Downloads', 'Rachael_animal1')


function crop_adjust_gui_drag(openDir, animal_name)
    adjustedCopy = [];  % this will store the latest unfiltered adjusted image
    filteredCopy = []; 
    channelActive = [true true true];  % [R, G, B] initially all ON
    removeMode = false;  % Initially OFF
    rectHandle = [];
    modeButtons = struct();  % 🛠 now officially exists
    currentShape = 'rectangle'; % Add shape state variable
    roi = []; % ROI object


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
    % --- Save current view (zoom/pan position) ---
    xlimCurrent = xlim(axCropped);
    ylimCurrent = ylim(axCropped);

    % Get cropping region based on shape type
    switch currentShape
        case 'rectangle'
            pos = round(roi.Position);
            pos(1:2) = max(pos(1:2), [1,1]);
            pos(3:4) = min(pos(3:4), [imgW, imgH] - pos(1:2));
            cropped = imcrop(original_rgb, pos);
            
            % Update coordinate display
            x1 = pos(1); y2 = imgH - pos(2);
            x2 = pos(1) + pos(3); y1 = imgH - (pos(2) + pos(4));
            coord_vals = [x1, y1, x2, y2];
            
        case 'polygon'  % Modified for arbitrary polygon
            % Get polygon vertices
            vertices = roi.Position;
            
            % Create polygon mask
            mask = poly2mask(vertices(:,1), vertices(:,2), size(original_rgb,1), size(original_rgb,2));
            
            % Calculate bounding box (for cropping)
            minX = min(vertices(:,1));
            maxX = max(vertices(:,1));
            minY = min(vertices(:,2));
            maxY = max(vertices(:,2));
            width = maxX - minX;
            height = maxY - minY;
            
            % Crop bounding box region
            bbox = [minX, minY, width, height];
            bbox = round(bbox);
            bbox(1:2) = max(bbox(1:2), [1,1]);
            bbox(3:4) = min(bbox(3:4), [imgW, imgH] - bbox(1:2));
            
            % Apply mask to bounding box region
            cropped = zeros(bbox(4), bbox(3), 3);
            for c = 1:3
                channel = original_rgb(bbox(2):bbox(2)+bbox(4)-1, bbox(1):bbox(1)+bbox(3)-1, c);
                mask_roi = mask(bbox(2):bbox(2)+bbox(4)-1, bbox(1):bbox(1)+bbox(3)-1);
                channel(~mask_roi) = 0;
                cropped(:,:,c) = channel;
            end
            
            % Update coordinate display (display bounding box coordinates)
            x1 = bbox(1); y2 = imgH - bbox(2);
            x2 = bbox(1) + bbox(3); y1 = imgH - (bbox(2) + bbox(4));
            coord_vals = [x1, y1, x2, y2];
    end

    % Update coordinate boxes
    for i = 1:4
        coord_boxes(i).String = num2str(coord_vals(i));
    end

    % Adjust image brightness and contrast
    adjusted = zeros(size(cropped));
    for c = 1:3
        contrast = sliders(c,1).Value;
        brightness = sliders(c,2).Value;
        val_labels(c,1).String = sprintf('%.2f', contrast);
        val_labels(c,2).String = sprintf('%.2f', brightness);
        adjusted(:,:,c) = contrast * cropped(:,:,c) + brightness;
    end
    adjusted = min(max(adjusted, 0), 1);
    adjustedCopy = adjusted;  % Save clean copy
    filteredCopy = adjusted;  % Reset filtered copy

    % --- Update the image display ---
    hCroppedRGB.CData = adjusted;
   
    % --- Restore previous zoom and pan ---
    xlim(axCropped, xlimCurrent);
    ylim(axCropped, ylimCurrent);

    % --- Update split RGB channels ---
    hR.CData = cat(3, adjusted(:,:,1), zeros(size(adjusted,1), size(adjusted,2), 2));
    hG.CData = cat(3, zeros(size(adjusted,1), size(adjusted,2)), adjusted(:,:,2), zeros(size(adjusted,1), size(adjusted,2)));
    hB.CData = cat(3, zeros(size(adjusted,1), size(adjusted,2), 2), adjusted(:,:,3));
    
    axis(axCropped, 'image');

    % --- Keep ButtonDownFcn for manual labeling ---
    set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
end

function saveAll()
    % Get stored region area data (single channel)
    if isappdata(gcf, 'rAreas')
        rAreas = getappdata(gcf, 'rAreas');
    else
        rAreas = [];
    end
    
    if isappdata(gcf, 'gAreas')
        gAreas = getappdata(gcf, 'gAreas');
    else
        gAreas = [];
    end
    
    if isappdata(gcf, 'bAreas')
        bAreas = getappdata(gcf, 'bAreas');
    else
        bAreas = [];
    end

    % Get stored overlap area data (combined channels)
    if isappdata(gcf, 'rgOverlapAreas')
        rgOverlapAreas = getappdata(gcf, 'rgOverlapAreas');
    else
        rgOverlapAreas = [];
    end
    
    if isappdata(gcf, 'gbOverlapAreas')
        gbOverlapAreas = getappdata(gcf, 'gbOverlapAreas');
    else
        gbOverlapAreas = [];
    end
    
    if isappdata(gcf, 'rbOverlapAreas')
        rbOverlapAreas = getappdata(gcf, 'rbOverlapAreas');
    else
        rbOverlapAreas = [];
    end

    if isappdata(gcf, 'rgbOverlapAreas')
        rgbOverlapAreas = getappdata(gcf, 'rgbOverlapAreas');
    else
        rgbOverlapAreas = [];
    end


    % --- Select save directory ---
    folderPath = uigetdir('', 'Select Save Directory');
    if folderPath == 0, return; end
    
    % --- Get ROI vertex coordinates and area ---
    if strcmp(currentShape, 'rectangle')
        % Rectangle mode [x,y,w,h] → convert to 4 vertices
        pos = roi.Position;
        vertices = [...
            pos(1), pos(2);               % Top-left
            pos(1)+pos(3), pos(2);        % Top-right
            pos(1)+pos(3), pos(2)+pos(4); % Bottom-right
            pos(1), pos(2)+pos(4)];       % Bottom-left
        area_pixels = pos(3) * pos(4);    % Rectangle area
    else
        % Polygon mode - directly get all vertices
        vertices = roi.Position; % N×2 matrix
        area_pixels = polyarea(vertices(:,1), vertices(:,2)); % Polygon area
    end

    % --- Create merged ROI information table (including vertex coordinates) ---
    % Basic information
    roiInfoCell = {
        'ROI_Type', currentShape;
        'Area_pixels', area_pixels;
        'Vertex_Count', size(vertices,1);
        ' ', ' ';
        'Vertex_Coordinates', 'X | Y | X_Norm | Y_Norm'; % Header
        };
    
    % Add vertex data (one vertex per row)
    for i = 1:size(vertices,1)
        roiInfoCell = [roiInfoCell; {
            sprintf('Vertex%d', i), ...
            sprintf('%.1f | %.1f | %.4f | %.4f', ...
                vertices(i,1), vertices(i,2), ...
                vertices(i,1)/imgW, vertices(i,2)/imgH)
            }];
    end
    
    % Convert to table and save
    roiInfoTable = cell2table(roiInfoCell(2:end,:), ...
        'VariableNames', {'Property', 'Value'});
    excelFile = fullfile(folderPath, strcat(animal_name, ' adjustment_parameters.xlsx'));

    % Save adjusted images
    adjusted = hCroppedRGB.CData;
    rgb_out = uint8(adjusted * 255);
    imwrite(rgb_out, fullfile(folderPath, strcat(animal_name,32,'adjusted_RGB.tif')));
    rColor = cat(3, adjusted(:,:,1), zeros(size(adjusted,1), size(adjusted,2), 2));
    gColor = cat(3, zeros(size(adjusted,1), size(adjusted,2)), adjusted(:,:,2), zeros(size(adjusted,1), size(adjusted,2)));
    bColor = cat(3, zeros(size(adjusted,1), size(adjusted,2), 2), adjusted(:,:,3));
    imwrite(uint8(rColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_R.tif')));
    imwrite(uint8(gColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_G.tif')));
    imwrite(uint8(bColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_B.tif')));

    % Get other parameters
    contrast = [sliders(1,1).Value, sliders(2,1).Value, sliders(3,1).Value];
    brightness = [sliders(1,2).Value, sliders(2,2).Value, sliders(3,2).Value];

    % Calculate binary region areas
    areaThreshR = str2double(rAreaBox.String)^2;
    bwR = imbinarize(adjusted(:,:,1));
    cleanR = bwareaopen(bwR, areaThreshR);
    totalR = sum(cleanR(:));
    
    areaThreshG = str2double(gAreaBox.String)^2;
    bwG = imbinarize(adjusted(:,:,2));
    cleanG = bwareaopen(bwG, areaThreshG);
    totalG = sum(cleanG(:));
    
    areaThreshB = str2double(bAreaBox.String)^2;
    bwB = imbinarize(adjusted(:,:,3));
    cleanB = bwareaopen(bwB, areaThreshB);
    totalB = sum(cleanB(:));

    area = [totalR, totalG, totalB];
    filter_size = [str2double(rAreaBox.String), str2double(gAreaBox.String), str2double(bAreaBox.String)];

    % Create corner table (get from coord_boxes)
    x1 = str2double(coord_boxes(1).String);
    y1 = str2double(coord_boxes(2).String);
    x2 = str2double(coord_boxes(3).String);
    y2 = str2double(coord_boxes(4).String);
    T2 = table({'X1';'Y1';'X2';'Y2'}, [x1; y1; x2; y2], ...
              'VariableNames', {'Corner','PixelCoordinate'});

    % Save to Excel file
    excelFile = fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx'));
    
    % Save corner table first
    writetable(T2, excelFile);
    
    % Create and save parameters Excel file
    createParametersFile(folderPath, animal_name, contrast, brightness);

    % Save R label positions with explanatory note
    if ~isempty(rPositions)
        rNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        rHeader = {'Label', 'X', 'Y', 'Area'};
        
        % Ensure rAreas and rPositions have consistent length
        if length(rAreas) ~= size(rPositions, 1)
            rAreas = zeros(size(rPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rData = num2cell([(1:size(rPositions,1))', rPositions, rAreas(:)]);
        rCombined = [rNote; rHeader; rData];
        writecell(rCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'R_Labels');
    end

    % Save G label positions with explanatory note
    if ~isempty(gPositions)
        gNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        gHeader = {'Label', 'X', 'Y', 'Area'};
        
        % Ensure gAreas and gPositions have consistent length
        if length(gAreas) ~= size(gPositions, 1)
            gAreas = zeros(size(gPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        gData = num2cell([(1:size(gPositions,1))', gPositions, gAreas(:)]);
        gCombined = [gNote; gHeader; gData];
        writecell(gCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'G_Labels');
    end

    % Save B label positions with explanatory note
    if ~isempty(bPositions)
        bNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        bHeader = {'Label', 'X', 'Y', 'Area'};
        
        % Ensure bAreas and bPositions have consistent length
        if length(bAreas) ~= size(bPositions, 1)
            bAreas = zeros(size(bPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        bData = num2cell([(1:size(bPositions,1))', bPositions, bAreas(:)]);
        bCombined = [bNote; bHeader; bData];
        writecell(bCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'B_Labels');
    end

    % Save RG overlap label positions with explanatory note
    if ~isempty(rgPositions)
        rgNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        rgHeader = {'Label', 'X', 'Y', 'Overlap Area'};
        
        % Ensure rgOverlapAreas and rgPositions have consistent length
        if length(rgOverlapAreas) ~= size(rgPositions, 1)
            rgOverlapAreas = zeros(size(rgPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rgData = num2cell([(1:size(rgPositions,1))', rgPositions, rgOverlapAreas(:)]);
        rgCombined = [rgNote; rgHeader; rgData];
        writecell(rgCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'RG_Labels');
    end

    % Save GB overlap label positions with explanatory note
    if ~isempty(gbPositions)
        gbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        gbHeader = {'Label', 'X', 'Y', 'Overlap Area'};
        
        % Ensure gbOverlapAreas and gbPositions have consistent length
        if length(gbOverlapAreas) ~= size(gbPositions, 1)
            gbOverlapAreas = zeros(size(gbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        gbData = num2cell([(1:size(gbPositions,1))', gbPositions, gbOverlapAreas(:)]);
        gbCombined = [gbNote; gbHeader; gbData];
        writecell(gbCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'GB_Labels');
    end

    % Save RB overlap label positions with explanatory note
    if ~isempty(rbPositions)
        rbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        rbHeader = {'Label', 'X', 'Y', 'Overlap Area'};
        
        % Ensure rbOverlapAreas and rbPositions have consistent length
        if length(rbOverlapAreas) ~= size(rbPositions, 1)
            rbOverlapAreas = zeros(size(rbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rbData = num2cell([(1:size(rbPositions,1))', rbPositions, rbOverlapAreas(:)]);
        rbCombined = [rbNote; rbHeader; rbData];
        writecell(rbCombined, excelFile, 'Sheet', 'RB_Labels');
    end

    % Save RGB overlap label positions with explanatory note
    if ~isempty(rgbPositions)
        rgbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        rgbHeader = {'Label', 'X', 'Y', 'Overlap Area'};
        
        % Ensure rgbOverlapAreas and rgbPositions have consistent length
        if length(rgbOverlapAreas) ~= size(rgbPositions, 1)
            rgbOverlapAreas = zeros(size(rgbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rgbData = num2cell([(1:size(rgbPositions,1))', rgbPositions, rgbOverlapAreas(:)]);
        rgbCombined = [rgbNote; rgbHeader; rgbData];
        writecell(rgbCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'RGB_Labels');
    end

    % Save count statistics information
    countsTable = table({'R'; 'G'; 'B'; 'RG'; 'GB'; 'RB'; 'RGB'}, ...
                       [length(rPositions); length(gPositions); length(bPositions); ...
                        length(rgPositions); length(gbPositions); length(rbPositions); length(rgbPositions)], ...
                       'VariableNames', {'Channel', 'Count'});
    writetable(countsTable, excelFile, 'WriteMode', 'Append', 'WriteVariableNames', true);
    writetable(roiInfoTable, excelFile, 'Sheet', 'ROI_Info', 'WriteMode', 'overwritesheet');


    % Display save completion information
    msgbox(sprintf('All data saved successfully to:\n%s', folderPath), 'Save Complete', 'help');
    
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
    adjusted = adjustedCopy;
    fontSize = str2double(fontSizeBox.String);
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    fontColor = colors{colorMenu.Value};
    
    % Clear existing markers for current channel
    switch channel
        case 'R'
            arrayfun(@delete, rHandles);
            rHandles = []; rPositions = zeros(0,2); rCounter = 0;
            % Clear region information
            rAreas = [];
        case 'G'
            arrayfun(@delete, gHandles);
            gHandles = []; gPositions = zeros(0,2); gCounter = 0;
            % Clear region information
            gAreas = [];
        case 'B'
            arrayfun(@delete, bHandles);
            bHandles = []; bPositions = zeros(0,2); bCounter = 0;
            % Clear region information
            bAreas = [];
        case 'RG'
            arrayfun(@delete, rgHandles);
            rgHandles = []; rgPositions = zeros(0,2); rgCounter = 0;
            % Clear overlap region information
            rgOverlapAreas = [];
        case 'GB'
            arrayfun(@delete, gbHandles);
            gbHandles = []; gbPositions = zeros(0,2); gbCounter = 0;
            % Clear overlap region information
            gbOverlapAreas = [];
        case 'RB'
            arrayfun(@delete, rbHandles);
            rbHandles = []; rbPositions = zeros(0,2); rbCounter = 0;
            % Clear overlap region information
            rbOverlapAreas = [];
        case 'RGB'
            arrayfun(@delete, rgbHandles);
            rgbHandles = []; rgbPositions = zeros(0,2); rgbCounter = 0;
            % Clear overlap region information
            rgbOverlapAreas = [];
    end

    % Get edge length thresholds
    switch channel
        case 'R'
            areaThresh = str2double(rAreaBox.String);
            maxareaThresh = str2double(maxrAreaBox.String);
        case 'G'
            areaThresh = str2double(gAreaBox.String);
            maxareaThresh = str2double(maxgAreaBox.String);
        case 'B'
            areaThresh = str2double(bAreaBox.String);
            maxareaThresh = str2double(maxbAreaBox.String);
        case 'RG'
            areaThresh = min(str2double(rAreaBox.String), str2double(gAreaBox.String));
            maxareaThresh = max(str2double(maxrAreaBox.String), str2double(maxgAreaBox.String));
        case 'GB'
            areaThresh = min(str2double(gAreaBox.String), str2double(bAreaBox.String));
            maxareaThresh = max(str2double(maxgAreaBox.String), str2double(maxbAreaBox.String));
        case 'RB'
            areaThresh = min(str2double(rAreaBox.String), str2double(bAreaBox.String));
            maxareaThresh = max(str2double(maxrAreaBox.String), str2double(maxbAreaBox.String));
        case 'RGB'
            areaThresh = min([str2double(rAreaBox.String), str2double(gAreaBox.String), str2double(bAreaBox.String)]);
            maxareaThresh = max([str2double(maxrAreaBox.String), str2double(maxgAreaBox.String), str2double(maxbAreaBox.String)]);
    end

    %% Single channel processing (based on Bounding Box edge length)
    if length(channel) == 1
        cIndex = find('RGB' == channel);
        bw = imbinarize(adjusted(:,:,cIndex));
        stats = regionprops(bw, 'BoundingBox', 'Centroid', 'Area');
        
        % Mark regions that meet the conditions
        for k = 1:numel(stats)
            bb = stats(k).BoundingBox; % [x, y, width, height]
            width = bb(3);
            height = bb(4);
            area = stats(k).Area; % Get region area
            
            % Modified judgment condition: check if both width and height are within min and max threshold range
            if (width >= areaThresh && height >= areaThresh) && ...
               (width <= maxareaThresh && height <= maxareaThresh)
                pos = stats(k).Centroid;
                switch channel
                    case 'R'
                        rCounter = rCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(rCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        rHandles(end+1) = h;
                        rPositions(end+1,:) = pos;
                        rAreas(end+1) = area;
                    case 'G'
                        gCounter = gCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(gCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        gHandles(end+1) = h;
                        gPositions(end+1,:) = pos;
                        gAreas(end+1) = area;
                    case 'B'
                        bCounter = bCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(bCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        bHandles(end+1) = h;
                        bPositions(end+1,:) = pos;
                        bAreas(end+1) = area;
                end
            end
        end

    %% Combined channel processing (synchronized modification to edge length filtering)
    else
        % Determine channel combination
        switch channel
            case 'RG', ch1 = 1; ch2 = 2;
            case 'GB', ch1 = 2; ch2 = 3;
            case 'RB', ch1 = 1; ch2 = 3;
            case 'RGB', ch1 = 1; ch2 = 2; ch3 = 3;
        end
    
        % Binarize and filter (based on edge length)
        bw1 = imbinarize(adjusted(:,:,ch1));
        stats1 = regionprops(bw1, 'BoundingBox', 'Centroid');
        % Modified to correct array access method
        widths1 = arrayfun(@(x) x.BoundingBox(3), stats1);
        heights1 = arrayfun(@(x) x.BoundingBox(4), stats1);
        validIdx1 = (widths1 >= areaThresh & heights1 >= areaThresh) & ...
                (widths1 <= maxareaThresh & heights1 <= maxareaThresh);
        stats1 = stats1(validIdx1);
    
        bw2 = imbinarize(adjusted(:,:,ch2));
        stats2 = regionprops(bw2, 'BoundingBox', 'Centroid');
        widths2 = arrayfun(@(x) x.BoundingBox(3), stats2);
        heights2 = arrayfun(@(x) x.BoundingBox(4), stats2);
        validIdx2 = (widths2 >= areaThresh & heights2 >= areaThresh) & ...
                (widths2 <= maxareaThresh & heights2 <= maxareaThresh);
        stats2 = stats2(validIdx2);
    
        if strcmp(channel, 'RGB')
            bw3 = imbinarize(adjusted(:,:,ch3));
            stats3 = regionprops(bw3, 'BoundingBox', 'Centroid');
            widths3 = arrayfun(@(x) x.BoundingBox(3), stats3);
            heights3 = arrayfun(@(x) x.BoundingBox(4), stats3);
            validIdx3 = (widths3 >= areaThresh & heights3 >= areaThresh) & ...
                    (widths3 <= maxareaThresh & heights3 <= maxareaThresh);
            stats3 = stats3(validIdx3);
        end
        
        % Detect overlap (rest of logic remains unchanged)
        maxOverlapArea = str2double(overlapThreshBox.String)^2;    
    
        if strcmp(channel, 'RGB')
            % Initialize overlap region array
            rgbOverlapAreas = [];
            
            % Three-channel overlap detection
            for i = 1:numel(stats1)
                bb1 = stats1(i).BoundingBox;
                r1 = [bb1(1), bb1(2), bb1(1)+bb1(3), bb1(2)+bb1(4)];
                c1 = stats1(i).Centroid;
                for j = 1:numel(stats2)
                    bb2 = stats2(j).BoundingBox;
                    r2 = [bb2(1), bb2(2), bb2(1)+bb2(3), bb2(2)+bb2(4)];
                    c2 = stats2(j).Centroid;
                
                    % Check R and G overlap
                    in1 = c1(1)>=r2(1) && c1(1)<=r2(3) && c1(2)>=r2(2) && c1(2)<=r2(4);
                    in2 = c2(1)>=r1(1) && c2(1)<=r1(3) && c2(2)>=r1(2) && c2(2)<=r1(4);
                
                    if (in1 || in2)
                        xL = max(r1(1), r2(1));
                        yT = max(r1(2), r2(2));
                        xR = min(r1(3), r2(3));
                        yB = min(r1(4), r2(4));
                    
                        if (xR > xL) && (yB > yT)
                            ovAreaRG = (xR - xL) * (yB - yT);
                            area1 = bb1(3)*bb1(4);
                            area2 = bb2(3)*bb2(4);
                            ratio1 = ovAreaRG / area1;
                            ratio2 = ovAreaRG / area2;
                        
                            % Apply maxOverlapArea filtering
                            if (ratio1 >= 0.5 || ratio2 >= 0.5) && ovAreaRG <= maxOverlapArea
                                % Check R+G and B overlap
                                for k = 1:numel(stats3)
                                    bb3 = stats3(k).BoundingBox;
                                    r3 = [bb3(1), bb3(2), bb3(1)+bb3(3), bb3(2)+bb3(4)];
                                    c3 = stats3(k).Centroid;
                                    area3 = bb3(3)*bb3(4);
                                
                                    % Check R+G and B overlap
                                    inRG_B = (c3(1)>=xL && c3(1)<=xR && c3(2)>=yT && c3(2)<=yB) || ...
                                            ((c1(1)+c2(1))/2 >= r3(1) && (c1(1)+c2(1))/2 <= r3(3) && ...
                                            (c1(2)+c2(2))/2 >= r3(2) && (c1(2)+c2(2))/2 <= r3(4));
                                
                                    if inRG_B
                                        xL_final = max(xL, r3(1));
                                        yT_final = max(yT, r3(2));
                                        xR_final = min(xR, r3(3));
                                        yB_final = min(yB, r3(4));
                                    
                                        if (xR_final > xL_final) && (yB_final > yT_final)
                                            ovAreaRGB = (xR_final - xL_final) * (yB_final - yT_final);
                                            ratio3 = ovAreaRGB / area3;
                                        
                                            % Apply maxOverlapArea filtering again
                                            if ratio3 >= 0.5 && ovAreaRGB <= maxOverlapArea
                                                cx = (xL_final + xR_final)/2;
                                                cy = (yT_final + yB_final)/2;
                                            
                                                rgbCounter = rgbCounter + 1;
                                                h = text(axCropped, cx, cy, num2str(rgbCounter), ...
                                                    'Color', fontColor, 'FontSize', fontSize, ...
                                                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                                rgbHandles(end+1) = h;
                                                rgbPositions(end+1,:) = [cx, cy];
                                                rgbOverlapAreas(end+1) = ovAreaRGB;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            % Save RGB overlap region data to figure application data
            setappdata(gcf, 'rgbOverlapAreas', rgbOverlapAreas);

        else
            % Initialize corresponding channel overlap region arrays
            if strcmp(channel, 'RG')
                rgOverlapAreas = [];
            elseif strcmp(channel, 'GB')
                gbOverlapAreas = [];
            elseif strcmp(channel, 'RB')
                rbOverlapAreas = [];
            end
            
            % Two-channel overlap detection
            for i = 1:numel(stats1)
                bb1 = stats1(i).BoundingBox;
                r1 = [bb1(1), bb1(2), bb1(1)+bb1(3), bb1(2)+bb1(4)];
                c1 = stats1(i).Centroid;
                area1 = bb1(3)*bb1(4);
                
                for j = 1:numel(stats2)
                    bb2 = stats2(j).BoundingBox;
                    r2 = [bb2(1), bb2(2), bb2(1)+bb2(3), bb2(2)+bb2(4)];
                    c2 = stats2(j).Centroid;
                    area2 = bb2(3)*bb2(4);
                
                    % Overlap detection
                    in1 = c1(1)>=r2(1) && c1(1)<=r2(3) && c1(2)>=r2(2) && c1(2)<=r2(4);
                    in2 = c2(1)>=r1(1) && c2(1)<=r1(3) && c2(2)>=r1(2) && c2(2)<=r1(4);
                
                    if (in1 || in2)
                        xL = max(r1(1), r2(1));
                        yT = max(r1(2), r2(2));
                        xR = min(r1(3), r2(3));
                        yB = min(r1(4), r2(4));
                    
                        if (xR > xL) && (yB > yT)
                            ovArea = (xR - xL) * (yB - yT);
                            ratio1 = ovArea / area1;
                            ratio2 = ovArea / area2;
                        
                            % Apply maxOverlapArea filtering
                            if (ratio1 >= 0.5 || ratio2 >= 0.5) && ovArea <= maxOverlapArea
                                cx = (xL + xR)/2;
                                cy = (yT + yB)/2;
                            
                                switch channel
                                    case 'RG'
                                        rgCounter = rgCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(rgCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        rgHandles(end+1) = h;
                                        rgPositions(end+1,:) = [cx, cy];
                                        rgOverlapAreas(end+1) = ovArea;
                                    case 'GB'
                                        gbCounter = gbCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(gbCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        gbHandles(end+1) = h;
                                        gbPositions(end+1,:) = [cx, cy];
                                        gbOverlapAreas(end+1) = ovArea;
                                    case 'RB'
                                        rbCounter = rbCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(rbCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        rbHandles(end+1) = h;
                                        rbPositions(end+1,:) = [cx, cy];
                                        rbOverlapAreas(end+1) = ovArea;
                                end
                            end
                        end
                    end
                end
            end
            
            % Save overlap region data to figure application data
            if strcmp(channel, 'RG')
                setappdata(gcf, 'rgOverlapAreas', rgOverlapAreas);
            elseif strcmp(channel, 'GB')
                setappdata(gcf, 'gbOverlapAreas', gbOverlapAreas);
            elseif strcmp(channel, 'RB')
                setappdata(gcf, 'rbOverlapAreas', rbOverlapAreas);
            end
        end
    end
    
    % Save single channel region area data
    if strcmp(channel, 'R')
        setappdata(gcf, 'rAreas', rAreas);
    elseif strcmp(channel, 'G')
        setappdata(gcf, 'gAreas', gAreas); 
    elseif strcmp(channel, 'B')
        setappdata(gcf, 'bAreas', bAreas);
    end
    
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

    createROI();
    updateImage();
end