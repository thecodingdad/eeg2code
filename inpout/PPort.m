classdef PPort < handle
%PPORT Helper class to write/read parallel port (LPT)
%   Yet it supports only windows (32/64 bits) using matlab (32/64bit).
%   If you run mac or linux, you have to add the required functions.
%
%   Usage: p=PPort(address) - address of the LPT port (can be HEX or DEC)
%          write value: p.outp(value) - value must be DEC
%          read value : value = p.inp()
    
    properties(SetAccess = private, Hidden = false)
        address;        % address of the LPT port
        matlab_arch;    % matlab architecture (32 or 64)
        cpu_arch;       % CPU architecture (32 or 64)
        os;             % OS type ('win', 'mac', or 'linux')
    end
    
    methods
        function this = PPort(address)
        %PPORT - constructor
            p = inputParser;
            addRequired(p,'address',@(x) isnumeric(x) || all(isstrprop(address,'xdigit')));
            parse(p,address);
            
            if ischar(address)
                this.address = hex2dec(address);
            else
                this.address = address;
            end
            
            this.init();
        end
        
        function outp(this,value)
        %OUTP(value) - write DEC value to parallel port
            outp(this.address,value);
        end
        
        function value = inp(this)
        %INP() - returns the value of the parallel port
            value = inp(this.address);
        end
    end
    
    methods(Access = private)
        
        function init(this)
        %INIT - initializes the parallel port
            this.initArchAndOs();
            % path to function
            path = fileparts(mfilename('fullpath'));
            % remove subfolders from searchpath
            warning('off','MATLAB:rmpath:DirNotFound')
            rmpath(genpath(path));
            addpath(path);
            % string representation of the system/matlab architecture
            archstr = [this.os mat2str(this.cpu_arch) '_mat' mat2str(this.matlab_arch)];
            % path to libs of the architecture
            archpath = [path filesep archstr];
            % add path if exists
            if exist(archpath,'dir') == 7, addpath(archpath); end
            
            switch (archstr)
                case 'win32_mat32'
                    systempath = 'C:\windows\system32';
                    dllname = 'inpout32.dll';
                    this.copyLibToSystem(archpath,systempath,dllname);
                    config_io;
                case 'win64_mat32'
                    systempath = 'C:\windows\sysWOW64';
                    dllname = 'inpout32a.dll';
                    this.copyLibToSystem(archpath,systempath,dllname);
                    config_io;
                case 'win64_mat64'
                    systempath = 'C:\windows\system32';
                    dllname = 'inpoutx64.dll';
                    this.copyLibToSystem(archpath,systempath,dllname);
                    config_io;
                otherwise
                    error('Parallel port: platform %s not supported',this.os);
            end
        end
        
        function initArchAndOs(this)
        %INITARCHANDOS - identifies both the matlab and cpu architecture as
        %   well as the OS type
            switch (getenv('PROCESSOR_ARCHITECTURE'));
                case 'x86'
                    this.matlab_arch = 32;
                    switch (getenv('PROCESSOR_ARCHITEW6432'))
                        case 'AMD64', this.cpu_arch = 64;
                        otherwise, this.cpu_arch = 32;
                    end
                case 'AMD64'
                    this.matlab_arch = 64;
                    this.cpu_arch = 64;
            end
            if ismac
                this.os = 'mac';
            elseif isunix
                this.os = 'linux';
            elseif ispc
                this.os = 'win';
            else
                this.os = 'unknown';
            end
        end
        
        function copyLibToSystem(~, sourcefolder, destinationfolder, filename)
        %COPYLIBTOSYSTEM - copies the requiered FILENAME from
        %   SOURCEFOLDER to DESTINATIONFOLDER
            try
                if exist([destinationfolder filesep filename],'file') ~= 2
                    copyfile([sourcefolder filesep filename],[destinationfolder filesep filename],'f');
                end
            catch
                error('Error: Can''t copy %s to system. It''s required to run MATLAB once with admin rights',filename);
            end
        end
    end
    
end

