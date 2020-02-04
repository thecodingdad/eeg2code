function [ ma ] = creatememmappedfile(varargin)
% CREATEMEMMAPPEDFILE
% varargin = any variables (double) to store in memfile
    
    format = cell(length(varargin),3);
    fileSize = 0;
    for ii=1:length(varargin)
        if ~isa(varargin{ii},'double'), error('only doubles are allowed'); end
        if isempty(inputname(ii)), varName = ['var' num2str(ii)];
        else varName = inputname(ii); end
        format(ii,:) = {class(varargin{ii}) size(varargin{ii}) varName};
        fileSize = fileSize + numel(varargin{ii});
    end
    
    filename = fullfile(tempdir,['matab_memfile_' num2str(fileSize) '.mmf']); %strjoin(format(:,3),'_') '_' 

    if (~exist(filename,'file'))
        [f,~] = fopen(filename, 'wb');
        if f ~= -1 
            fwrite(f, zeros(1,fileSize),'double');
            fclose(f);
        else
            error('cannot open file %s : %s', filename, msg);
        end
    end

    ma = memmapfile(filename,'Writable',true,'Format',format(:,1:3));

    for ii=1:size(format,1)
        ma.data.(format{ii,3}) = varargin{ii};
    end
end