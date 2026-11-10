function txt = h5text(value)
%H5TEXT Normalise a text attribute returned by h5readatt to a char row.
%   h5readatt returns variable-length strings as a cell, a string or a char
%   array depending on the release and on how the file was written.

    if iscell(value)
        value = value{1};
    end
    txt = char(string(value));
    txt = txt(:).';
    txt(txt == 0) = [];
end
