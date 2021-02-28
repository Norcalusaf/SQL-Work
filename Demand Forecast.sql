/**************************************************************************
Description: Generates 18 months of demand and dumps it into a table
for processing. 
***************************************************************************/
BEGIN 

DECLARE _statement_sales nvarchar(3000);
DECLARE _statement_prod nvarchar(3000);
DECLARE _statement_normalize nvarchar(3000);
DECLARE _monthcounter integer; 
DECLARE _column NVARCHAR(100);


--Truncates source table
TRUNCATE TABLE SCHEMA.DEMAND_FORECAST;

--inserts the rec source, plant, part, and rec type
INSERT INTO SCHEMA.DEMAND_FORECAST(
SELECT DISTINCT
LOCATION, 
MATERIAL, 
DEMAND_TYPE,
NULL, --Current_Month
NULL, --Current_Month+1
NULL, --Current_Month+2
NULL, --Current_Month+3
NULL, --Current_Month+4
NULL, --Current_Month+5
NULL, --Current_Month+6
NULL, --Current_Month+7
NULL, --Current_Month+8
NULL, --Current_Month+9
NULL, --Current_Month+10
NULL, --Current_Month+11
NULL, --Current_Month+12
NULL, --Current_Month+13
NULL, --Current_Month+14
NULL, --Current_Month+15
NULL, --Current_Month+16
NULL, --Current_Month+17
NULL, --Current_Month+18
CURRENT_TIMESTAMP as TIMESTAMP
FROM
(
	SELECT DISTINCT
	WERKS AS LOCATION, 
	MATNR as MATERIAL, 
	BDART as DEMAND_TYPE 
	FROM SCHEMA.RESB 
	WHERE MATNR != '' 
	AND (ENMNG != BDMNG)
	AND BDMNG != 0
	AND SUBSTR(LGORT,0,1) NOT IN ('Q')
	AND (AUFNR != '' OR PLNUM != '') AND XLOEK NOT IN ('X') AND KZEAR NOT IN ('X')
	AND (BDTER >= ADD_YEARS(CURRENT_DATE,-1) AND BDTER <= ADD_MONTHS(CURRENT_DATE, 18))
);

_monthcounter := 0;  --sets the counter @ 0 to start the loop

while _monthcounter < 19 do  -- loops over this block until counter reaches 19 and then it exits

    _column := 'Current_Month+'||to_char(:_monthcounter);

    IF _monthcounter = 0 --checks for the current_month because the statement is different
    THEN

            _statement_prod :=
        'UPDATE SCHEMA.DEMAND_FORECAST
        SET "Current_Month" =
                 (
                     SELECT COALESCE((SUM(BDMNG) - SUM(ENMNG)),0)
                     FROM SCHEMA.RESB
                     WHERE (LOCATION = WERKS AND MATERIAL = MATNR AND DEMAND_TYPE = BDART)
                     AND BDTER <= (ADD_DAYS(ADD_MONTHS(ADD_DAYS(CURRENT_DATE,-EXTRACT(DAY FROM CURRENT_DATE) + 1),1),-1))
                     AND SUBSTR(LGORT,0,1) NOT IN (''Q'')
                     AND (AUFNR != '''' OR PLNUM != '''') AND XLOEK NOT IN (''X'') AND KZEAR NOT IN (''X'')
                     AND (ENMNG != BDMNG)
                 );

        _statement_sales :=
        'UPDATE SCHEMA.DEMAND_FORECAST
        SET "Current_Month" =
        (

                    SELECT COALESCE(SUM("Open"),0) FROM(SELECT (SUM(WMENG) - "Withdrawn") as "Open"
                    FROM
                    (
                        SELECT VE.WMENG,
                        (
                                SELECT COALESCE(SUM("LFIMG"),0)
                                FROM "SCHEMA"."LIPS" L
                                JOIN "SCHEMA"."LIKP" LP ON L."VBELN" = LP."VBELN"
                                WHERE L."VGBEL" = VP."VBELN" AND L."VGPOS" = VP."POSNR"
                        )as "Withdrawn"
                        FROM SCHEMA.VBAK VA
                        JOIN SCHEMA.VBAP VP ON VA.VBELN = VP.VBELN
                        JOIN SCHEMA.VBUP VU ON VA.VBELN = VU.VBELN AND VP.POSNR = VU.POSNR
                        JOIN SCHEMA.VBEP VE ON VA.VBELN = VE.VBELN AND VP.POSNR = VE.POSNR
                        WHERE (VP.WERKS = LOCATION AND VP.MATNR = MATERIAL AND VP.BEDAE = DEMAND_TYPE)
                        AND VE.MBDAT <= (ADD_DAYS(ADD_MONTHS(ADD_DAYS(CURRENT_DATE,-EXTRACT(DAY FROM CURRENT_DATE) + 1),1),-1))
                        AND VU.GBSTA IN (''A'', ''B'')
                        GROUP BY VP.VBELN, VP.POSNR, VE.WMENG)GROUP BY "Withdrawn")
                );

        _statement_normalize := 'UPDATE SCHEMA.DEMAND_FORECAST SET "Current_Month" = 0 WHERE "Current_Month" < 0';

    ELSE  -- the rest of the months

        _statement_prod :=
        'UPDATE SCHEMA.DEMAND_FORECAST
        SET "Current_Month+'||to_char(:_monthcounter)||'" =
                 (
                     SELECT COALESCE((SUM(BDMNG) - SUM(ENMNG)),0)
                     FROM SCHEMA.RESB
                     WHERE (LOCATION = WERKS AND MATERIAL = MATNR AND DEMAND_TYPE = BDART)
                     AND (YEAR(BDTER) = YEAR(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')) AND MONTH(BDTER) = MONTH(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')))
                     AND SUBSTR(LGORT,0,1) NOT IN (''Q'')
                     AND (AUFNR != '''' OR PLNUM != '''') AND XLOEK NOT IN (''X'') AND KZEAR NOT IN (''X'')
                     AND (ENMNG != BDMNG)
                 );

        _statement_sales :=
        'UPDATE SCHEMA.DEMAND_FORECAST
        SET "Current_Month+'||to_char(:_monthcounter)||'" =
                (

                    SELECT COALESCE(SUM("Open"),0) FROM(SELECT (SUM(WMENG) - "Withdrawn") as "Open"
                    FROM
                    (
                        SELECT VE.WMENG,
                        (
                                SELECT COALESCE(SUM("LFIMG"),0)
                                FROM "SCHEMA"."LIPS" L
                                JOIN "SCHEMA"."LIKP" LP ON L."VBELN" = LP."VBELN"
                                WHERE L."VGBEL" = VP."VBELN" AND L."VGPOS" = VP."POSNR"
                        )as "Withdrawn"
                        FROM SCHEMA.VBAK VA
                        JOIN SCHEMA.VBAP VP ON VA.VBELN = VP.VBELN
                        JOIN SCHEMA.VBUP VU ON VA.VBELN = VU.VBELN AND VP.POSNR = VU.POSNR
                        JOIN SCHEMA.VBEP VE ON VA.VBELN = VE.VBELN AND VP.POSNR = VE.POSNR
                        WHERE (VP.WERKS = LOCATION AND VP.MATNR = MATERIAL AND VP.BEDAE = DEMAND_TYPE)
                        AND (YEAR(VE.MBDAT) = YEAR(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')) AND MONTH(VE.MBDAT) = MONTH(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')))
                        AND VU.GBSTA IN (''A'', ''B'')
                        GROUP BY VP.VBELN, VP.POSNR, VE.WMENG)GROUP BY "Withdrawn")
                );

        _statement_normalize := 'UPDATE SCHEMA.DEMAND_FORECAST SET "Current_Month+'||:_monthcounter||'" = 0 WHERE "Current_Month+'||:_monthcounter||'" < 0';

    END IF;

    EXECUTE IMMEDIATE(:_statement_prod);
    EXECUTE IMMEDIATE(:_statement_sales);
    EXECUTE IMMEDIATE(:_statement_normalize);

    _monthcounter := :_monthcounter+1;

    end while;
end;