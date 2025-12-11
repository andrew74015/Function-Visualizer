% startup.m
% Seteaza calea proiectului si optiuni utile

% detecteaza folderul curent al fisierului startup.m
projRoot = fileparts(mfilename('fullpath'));

% adauga folderele relevante la path
addpath(fullfile(projRoot,'src'));
addpath(fullfile(projRoot,'src','utils')); % daca ai utilitare
addpath(fullfile(projRoot,'data'));

% seteaza folderul de lucru la radacina proiectului
cd(projRoot);

% optiuni vizuale si warnings
warning('on','all');
format compact;

% afiseaza un mesaj scurt
fprintf('Project initialized: %s\n', projRoot);