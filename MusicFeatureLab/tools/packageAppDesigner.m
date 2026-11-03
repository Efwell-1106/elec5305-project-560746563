function report = packageAppDesigner(sourceFile, targetFile)
%PACKAGEAPPDESIGNER Build an editable MLAPP from a marked AppBase class.
% The source class must accept 'DesignMode' to build an empty UI. All UI
% components should be public properties. Mark custom properties and helper
% methods with BEGIN APP LOGIC / END APP LOGIC. Place UI callbacks in a
% distinct BEGIN APP CALLBACKS / END APP CALLBACKS block. A startupFcn(app)
% callback is recognized and saved as the App Designer startup function.
%
% This build utility uses the installed App Designer serializer; it is not
% needed to run the delivered app. Both file names must have the same stem.

sourceFile = char(sourceFile);
targetFile = char(targetFile);
[sourceDir, className] = fileparts(sourceFile);
[targetDir, targetName, targetExt] = fileparts(targetFile);
assert(strcmp(className, targetName), 'Source and target class names must match.');
assert(strcmpi(targetExt, '.mlapp'), 'Target extension must be .mlapp.');
assert(isfolder(targetDir), 'Target folder does not exist.');
codeText = fileread(sourceFile);
logicText = markedSection(codeText, 'APP LOGIC');
callbackText = markedSection(codeText, 'APP CALLBACKS');
assert(~isempty(logicText), 'The APP LOGIC marked section is empty or absent.');
assert(~isempty(callbackText), 'The APP CALLBACKS marked section is empty or absent.');

oldPath = path;
cleanupPath = onCleanup(@()path(oldPath));
addpath(sourceDir, '-begin');
rehash;
app = feval(className, 'DesignMode');
cleanupApp = onCleanup(@()delete(app));
fig = app.UIFigure;
fig.Visible = 'off';

% The blank design-time instance contains exactly the components created by
% createComponents. Its custom callbacks are converted to names, so it does
% not serialize live closures that capture the application object.
componentNames = {};
componentTypes = {};
callbackNames = {};
adapterMap = appdesigner.internal.application.getComponentAdapterMap();
appProps = properties(app);
for idx = 1:numel(appProps)
    name = appProps{idx};
    value = app.(name);
    if ~isUIComponent(value, adapterMap)
        continue;
    end
    if ~isequal(value, fig) && ~isequal(ancestor(value, 'figure'), fig)
        continue;
    end
    if isprop(value, 'DesignTimeProperties') && ...
            isfield(value.DesignTimeProperties, 'CodeName') && ...
            ~isempty(value.DesignTimeProperties.CodeName)
        assert(strcmp(value.DesignTimeProperties.CodeName, name), ...
            'The UI component %s has more than one public property alias.', name);
    end
    setDesignMetadata(value, name);
    componentNames{end+1,1} = name; %#ok<AGROW>
    componentTypes{end+1,1} = class(value); %#ok<AGROW>
end

% A component created as a local variable is still made available in Design
% View. App Designer generates its public property on the next save.
tree = findall(fig);
for idx = 1:numel(tree)
    component = tree(idx);
    if ~isUIComponent(component, adapterMap)
        continue;
    end
    if ~isprop(component, 'DesignTimeProperties')
        typeName = regexp(class(component), '[^.]+$', 'match', 'once');
        name = matlab.lang.makeUniqueStrings(typeName, componentNames);
        setDesignMetadata(component, name);
        componentNames{end+1,1} = name; %#ok<AGROW>
        componentTypes{end+1,1} = class(component); %#ok<AGROW>
    end
    propNames = properties(component);
    for pidx = 1:numel(propNames)
        propName = propNames{pidx};
        if ~endsWith(propName, 'Fcn')
            continue;
        end
        callback = component.(propName);
        if isempty(callback)
            continue;
        end
        if isa(callback, 'function_handle')
            callbackName = getCallbackName(callback, callbackText);
            component.(propName) = callbackName;
            callbackNames{end+1} = callbackName; %#ok<AGROW>
        elseif ischar(callback) || isstring(callback)
            % Leave a harmless MATLAB default callback alone. User callbacks
            % must be named methods in the dedicated marked block.
            if strcmp(callback, 'closereq')
                component.(propName) = [];
            elseif ~isempty(regexp(callbackText, ...
                    ['function\s+' regexptranslate('escape', char(callback)) '\s*\('], 'once'))
                callbackNames{end+1} = char(callback); %#ok<AGROW>
            else
                error('packageAppDesigner:Callback', 'Unrecognized callback %s.%s.', ...
                    component.DesignTimeProperties.CodeName, propName);
            end
        else
            error('packageAppDesigner:Callback', 'Unsupported callback value for %s.%s.', ...
                component.DesignTimeProperties.CodeName, propName);
        end
    end
end

% Use MATLAB's own syntax tree parser for callback bodies. It handles
% nested loops, conditionals, comments, and multiline function bodies.
parser = appdesigner.internal.serialization.PlainTextCodeParser(string(codeText));
% Preserve unassigned/orphaned callbacks as well as callbacks currently
% attached to controls. All methods in this marked block are event methods.
declaredCallbacks = regexp(callbackText, '(?m)^\s*function\s+(\w+)\s*\(', 'tokens');
callbackNames = [callbackNames, cellfun(@(x)x{1}, declaredCallbacks, 'UniformOutput', false)];
callbackNames = unique(callbackNames, 'stable');
callbacks = struct('Name', {}, 'Code', {});
for idx = 1:numel(callbackNames)
    callbackName = callbackNames{idx};
    callbackCode = parser.getCallbackCode(callbackName);
    callbacks(end+1) = struct('Name', callbackName, 'Code', {callbackCode}); %#ok<AGROW>
end
startup = struct.empty();
if ~isempty(regexp(callbackText, 'function\s+startupFcn\s*\(', 'once'))
    startupCode = parser.getCallbackCode('startupFcn');
    startup = struct('Name', 'startupFcn', 'Code', {startupCode});
    callbacks(strcmp({callbacks.Name}, 'startupFcn')) = [];
end

serializer = appdesigner.internal.serialization.MLAPPSerializer(targetFile, fig);
serializer.OverwriteTargetFile = true;
serializer.ClassName = className;
serializer.MatlabCodeText = codeText;
serializer.EditableSectionCode = cellstr(splitlines(string(logicText)));
serializer.Callbacks = callbacks;
serializer.StartupCallback = startup;
serializer.RunConfigurations = {''};
serializer.Metadata.Name = 'Music Feature Lab';
serializer.Metadata.Summary = 'Integrated ELEC5305 audio analysis and brightness experiments';
serializer.Metadata.Description = ['Audio analysis, symmetric FFT brightness processing, ' ...
    'DSP calibration, music-library batch analysis, and exports in one app.'];
serializer.Metadata.MinimumSupportedMATLABRelease = 'R2026a';
serializer.Metadata.ScreenshotMode = 'none';
serializer.save();

% Reopen the data with the installed MLAPP reader to verify the archive and
% its code metadata rather than merely checking that a file was written.
reader = appdesigner.internal.serialization.FileReader(targetFile);
savedCode = reader.readMATLABCodeText();
assert(contains(savedCode, ['classdef ' className]), 'Saved class code did not round-trip.');
savedMeta = reader.readAppMetadata();
[savedAppData, ~] = reader.readAppDesignerData();
savedFigure = savedAppData.components.UIFigure;
cleanupSavedFigure = onCleanup(@()delete(savedFigure));
savedComponents = findall(savedFigure, '-property', 'DesignTimeProperties');
assert(numel(savedComponents) == numel(componentNames), ...
    'The saved component hierarchy did not round-trip completely.');
assert(strcmp(savedAppData.code.ClassName, className), ...
    'The saved code metadata contains the wrong class name.');
assert(isfield(savedAppData.code, 'EditableSectionCode') && ...
    ~isempty(savedAppData.code.EditableSectionCode), ...
    'The saved editable application code is missing.');
report = struct('TargetFile', targetFile, 'ComponentCount', numel(componentNames), ...
    'CallbackCount', numel(callbacks), 'HasStartupFcn', ~isempty(startup), ...
    'ComponentNames', {componentNames}, 'ComponentTypes', {componentTypes}, ...
    'Metadata', savedMeta);
disp(report);
end

function text = markedSection(codeText, label)
expression = ['(?ms)^\s*%\s*BEGIN ' label '\s*\r?\n(.*?)^\s*%\s*END ' label '\s*$'];
parts = regexp(codeText, expression, 'tokens', 'once');
if isempty(parts)
    text = '';
else
    text = parts{1};
end
end

function yes = isUIComponent(value, adapterMap)
yes = isobject(value) && isscalar(value) && startsWith(class(value), 'matlab.ui.') ...
    && isprop(value, 'Parent') && isvalid(value) && isKey(adapterMap, class(value));
% UIAxes contain internal toolbars and interaction objects that also have
% matlab.ui.* class names. Only named App Designer component types belong
% in its component hierarchy; plots, labels belonging to axes, and internal
% graphics helpers must not receive DesignTimeProperties.
end

function setDesignMetadata(component, codeName)
if ~isprop(component, 'DesignTimeProperties')
    addprop(component, 'DesignTimeProperties');
end
component.DesignTimeProperties = struct('CodeName', codeName, 'GroupId', '', ...
    'ComponentCode', {{}}, 'ImageRelativePath', '', 'DirtyProps', struct());
end

function name = getCallbackName(callback, callbackText)
info = functions(callback);
name = regexp(info.function, 'app\.(\w+)\s*\(', 'tokens', 'once');
if ~isempty(name)
    name = name{1};
else
    % createCallbackFcn wraps a named method in executeCallback. Locate the
    % wrapped callback handle in its captured workspace if that form is used.
    name = '';
    if isfield(info, 'workspace')
        for idx = 1:numel(info.workspace)
            workspace = info.workspace{idx};
            if isfield(workspace, 'callback') && isa(workspace.callback, 'function_handle')
                wrappedInfo = functions(workspace.callback);
                candidate = regexp(wrappedInfo.function, '(\w+)$', 'match', 'once');
                if ~isempty(candidate)
                    name = candidate;
                    break;
                end
            end
        end
    end
end
assert(~isempty(name) && ~isempty(regexp(callbackText, ...
    ['function\s+' regexptranslate('escape', name) '\s*\('], 'once')), ...
    'Could not map UI callback "%s" to a method in APP CALLBACKS.', info.function);
end
