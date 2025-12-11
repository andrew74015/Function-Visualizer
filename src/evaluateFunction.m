function fh = evaluateFunction(exprStr)
% EVALUATEFUNCTION  Returneaza un function handle @(x,y) dintr-un string
%   exprStr trebuie sa foloseasca variabilele x si y si operatori elementwise
%   ex: '(x.^2 - y.^2)./(x.^2 + y.^2)'

% sanitize basic things
if ~ischar(exprStr) && ~isstring(exprStr)
    error('Expression must be a string.');
end
exprStr = char(exprStr);

% ensure elementwise operators are used (best-effort warning)
if contains(exprStr,'^') && ~contains(exprStr,'.^')
    warning('Consider using .^ for elementwise power.');
end

% build handle
fh = str2func(['@(x,y) ' exprStr]);

% quick test on small arrays to catch syntax errors early
try
    xt = [0 1; 1 0];
    yt = [0 1; 1 0];
    zt = fh(xt,yt); %#ok<NASGU>
catch ME
    error('Invalid expression or evaluation error: %s',ME.message);
end
end