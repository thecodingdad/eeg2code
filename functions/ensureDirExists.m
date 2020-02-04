function ensureDirExists(parentdir, newdir)
%ENSUREDIREXISTS. Creates directory if it does not exist yet.
%       ensureDirExists(parentdir, newdir)
% or    ensureDirExists(dir)
% 8.03.07 - initial version (bensch)
%16.07.08 - added option to call ensureDirExists(dir) (spueler)

if exist('newdir') % to keep compability with old scripts
    if ~exist([parentdir newdir], 'dir')
        [success, message, messageid] = mkdir(parentdir, newdir);
        if success ~= 1, error(message), end
    end
else
    if ~exist(parentdir, 'dir')
        [success, message, messageid] = mkdir(parentdir);
        if success ~= 1, error(message), end
    end
end