function saveAsPDF(f,path)
    set(f,'Units','Inches');
    pos = get(f,'Position');
    set(f,'PaperPositionMode','Auto','PaperUnits','Inches','PaperSize',[pos(3), pos(4)])
    print(f, path,'-dpdf','-r0')
    system(['pdfcrop.exe ' path ' ' path]);
end

