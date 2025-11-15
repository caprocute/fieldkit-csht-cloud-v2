UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'pH')))::jsonb
WHERE id = 1;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Conductividad')))::jsonb
WHERE id = 2;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'DO')))::jsonb
WHERE id = 3;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Presión')))::jsonb
WHERE id = 4;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura')))::jsonb
WHERE id = 5;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura')))::jsonb
WHERE id = 6;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'ORP')))::jsonb
WHERE id = 7;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'pH')))::jsonb
WHERE id = 8;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Conductividad')))::jsonb
WHERE id = 9;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'TDS')))::jsonb
WHERE id = 10;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Salinidad')))::jsonb
WHERE id = 11;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'DO')))::jsonb
WHERE id = 12;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'DO')))::jsonb
WHERE id = 12;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura')))::jsonb
WHERE id = 14;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'ORP')))::jsonb
WHERE id = 15;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Humedad')))::jsonb
WHERE id = 16;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura 1')))::jsonb
WHERE id = 17;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Presión')))::jsonb
WHERE id = 18;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura 2')))::jsonb
WHERE id = 19;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Lluvia')))::jsonb
WHERE id = 20;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Velocidad del Viento')))::jsonb
WHERE id = 21;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Dirección del Viento')))::jsonb
WHERE id = 22;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Viento ADC Crudo Dirección')))::jsonb
WHERE id = 23;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Velocidad Máx. del Viento (1 hora)')))::jsonb
WHERE id = 24;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Dirección Máx. del Viento (1 hora)')))::jsonb
WHERE id = 25;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Velocidad Máx. del Viento (10 min)')))::jsonb
WHERE id = 26;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Dirección Máx. del Viento (10 min)')))::jsonb
WHERE id = 27;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Velocidad Prom. del Viento (2 min)')))::jsonb
WHERE id = 28;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Dirección Prom. del Viento (2 min)')))::jsonb
WHERE id = 29;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Lluvia Esta Hora')))::jsonb
WHERE id = 30;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Lluvia Hora Anterior')))::jsonb
WHERE id = 31;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Humedad')))::jsonb
WHERE id = 32;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura 1')))::jsonb
WHERE id = 33;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Presión')))::jsonb
WHERE id = 34;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura 2')))::jsonb
WHERE id = 35;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Lluvia')))::jsonb
WHERE id = 36;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Viento')))::jsonb
WHERE id = 37;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Dirección del Viento')))::jsonb
WHERE id = 38;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Viento ADC Crudo')))::jsonb
WHERE id = 39;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Distancia')))::jsonb
WHERE id = 40;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Distancia 0')))::jsonb
WHERE id = 41;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Distancia 1')))::jsonb
WHERE id = 42;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Distancia 2')))::jsonb
WHERE id = 43;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Calibración')))::jsonb
WHERE id = 44;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Carga de Batería')))::jsonb
WHERE id = 45;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Voltaje de Batería')))::jsonb
WHERE id = 46;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Voltaje Bus Batería')))::jsonb
WHERE id = 47;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Voltaje Derivación Batería')))::jsonb
WHERE id = 48;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Corriente de Batería')))::jsonb
WHERE id = 49;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Potencia de Batería')))::jsonb
WHERE id = 50;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Memoria Libre')))::jsonb
WHERE id = 55;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Tiempo de Actividad')))::jsonb
WHERE id = 56;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura')))::jsonb
WHERE id = 57;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 0')))::jsonb
WHERE id = 58;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 1')))::jsonb
WHERE id = 59;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 2')))::jsonb
WHERE id = 60;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 3')))::jsonb
WHERE id = 61;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 4')))::jsonb
WHERE id = 62;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 5')))::jsonb
WHERE id = 63;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 6')))::jsonb
WHERE id = 64;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 7')))::jsonb
WHERE id = 65;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 8')))::jsonb
WHERE id = 66;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Aleatorio 9')))::jsonb
WHERE id = 67;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Sen(x)')))::jsonb
WHERE id = 68;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Sierra(x)')))::jsonb
WHERE id = 69;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Profundidad')))::jsonb
WHERE id = 70;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Profundidad (No Filtrada)')))::jsonb
WHERE id = 71;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Distancia')))::jsonb
WHERE id = 72;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Batería')))::jsonb
WHERE id = 73;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Nivel de Marea')))::jsonb
WHERE id = 74;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Humedad')))::jsonb
WHERE id = 75;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Presión')))::jsonb
WHERE id = 76;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Altitud')))::jsonb
WHERE id = 77;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura')))::jsonb
WHERE id = 78;


UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Error de SD')))::jsonb
WHERE id = 79;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Precipitación')))::jsonb
WHERE id = 80;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Temperatura del Agua')))::jsonb
WHERE id = 81;

UPDATE sensor_meta
SET strings = (strings::jsonb || jsonb_build_object('es-ES', jsonb_build_object('label', 'Profundidad')))::jsonb
WHERE id = 82;
