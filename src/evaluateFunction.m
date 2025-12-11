function fh = evaluateFunction(exprStr)
% EVALUATEFUNCTION  Returneaza un function handle @(x,y) sau @(x,y,z) dintr-un string
%   exprStr trebuie sa foloseasca variabilele x si y (si optional z) si operatori elementwise
%   ex: '(x.^2 - y.^2)./(x.^2 + y.^2)'

% accept string array or cell array by converting to single char
if iscell(exprStr)
    exprStr = strjoin(exprStr, newline);
elseif isstring(exprStr)
    exprStr = char(strjoin(exprStr, newline));
else
    exprStr = char(exprStr);
end
exprStr = strtrim(exprStr);

% sanitize basic things
if ~ischar(exprStr) && ~isstring(exprStr)
    error('Expression must be a string.');
end
exprStr = char(exprStr);

% simple blacklist check (best-effort)
badTokens = {'system','!','dos','unix','java','pyenv','delete','rmdir','movefile','evalc','evalin','feval','!','curl','wget'};
for k = 1:numel(badTokens)
    if contains(exprStr, badTokens{k}, 'IgnoreCase', true)
        warning('evaluateFunction:SuspiciousToken', ...
            'Expression contains token "%s". Be careful executing arbitrary code.', badTokens{k});
    end
end

% ensure elementwise operators are used (best-effort warning)
if contains(exprStr,'^') && ~contains(exprStr,'.^')
    warning('Consider using .^ for elementwise power.');
end
if contains(exprStr,'/') && ~contains(exprStr,'./')
    % avoid false positives for './' already present
    if ~contains(exprStr,'./')
        warning('Consider using ./ for elementwise division.');
    end
end
if contains(exprStr,'*') && ~contains(exprStr,'.*')
    if ~contains(exprStr,'.*')
        warning('Consider using .* for elementwise multiplication.');
    end
end

% build handle
fh = str2func(['@(x,y) ' exprStr]); %#ok<NASGU>

% quick test on small arrays to catch syntax errors early
xt = [0 1; 1 0];
yt = [0 1; 1 0];

% try to detect if user wrote a 3-arg function @(x,y,z)
% create a tentative handle and inspect nargin
try
    % try as 2-arg first
    fh2 = str2func(['@(x,y) ' exprStr]);
    n2 = nargin(fh2);
catch
    n2 = -1;
end
try
    fh3 = str2func(['@(x,y,z) ' exprStr]);
    n3 = nargin(fh3);
catch
    n3 = -1;
end

% prefer the handle that parses without error and has sensible nargin
tested = false;
errMsg = '';
if n2 >= 0
    try
        zt = fh2(xt,yt); %#ok<NASGU>
        fh = fh2;
        tested = true;
    catch ME
        errMsg = ME.message;
    end
end
if ~tested && n3 >= 0
    try
        zt = fh3(xt,yt,zeros(size(xt))); %#ok<NASGU>
        fh = fh3;
        tested = true;
    catch ME
        errMsg = ME.message;
    end
end

% fallback: try calling the 2-arg handle and let error propagate if any
if ~tested
    try
        fh = str2func(['@(x,y) ' exprStr]);
        zt = fh(xt,yt); %#ok<NASGU>
    catch ME
        error('Invalid expression or evaluation error: %s', ME.message);
    end
end

end