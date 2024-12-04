% use your TITA's serial number to replace serial number 
serial_number = '' ; 
unique_id = strrep(serial_number, char(0), ''); 
unique_id = unique_id(7:end);
tita_namespace = ['tita', unique_id];
disp(tita_namespace);