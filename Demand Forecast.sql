CREATE PROCEDURE SCHEMA.ZPR_DEMAND_FORECAST_18MONTH LANGUAGE SQLSCRIPT AS
/**************************************************************************
Description: Builds out the next 18 months of demand broken out by Requirement
Source, Plant, Part, Requirement Type and then current month up to current month + 18
Created: 8/26/2020
Author: Chris Wilson

***************************************************************************/
BEGIN 

DECLARE _statement_sales nvarchar(3000);
DECLARE _statement_prod nvarchar(3000);
DECLARE _statement_normalize nvarchar(3000);
DECLARE _monthcounter integer; 
DECLARE _column NVARCHAR(100);


--Truncates source table
TRUNCATE TABLE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH;

--inserts the rec source, plant, part, and rec type
INSERT INTO SCHEMA.ZTB_DEMAND_FORECAST_18MONTH(
SELECT DISTINCT 
"Requirement_Source",
"Plant", 
"Part", 
"Requirement_Type",
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
CURRENT_TIMESTAMP as "Data_Loaded_Date"
FROM
(
	SELECT DISTINCT 
	'Production' as "Requirement_Source",
	WERKS AS "Plant", 
	MATNR as "Part", 
	BDART as "Requirement_Type" 
	FROM DATA_SLT_CERP.RESB 
	WHERE MATNR != '' 
	AND (ENMNG != BDMNG)
	AND BDMNG != 0
	AND SUBSTR(LGORT,0,1) NOT IN ('Q')
	AND (AUFNR != '' OR PLNUM != '') AND XLOEK NOT IN ('X') AND KZEAR NOT IN ('X')
	AND (BDTER >= ADD_YEARS(CURRENT_DATE,-1) AND BDTER <= ADD_MONTHS(CURRENT_DATE, 18))
	UNION
         SELECT DISTINCT 
    "Requirement_Source", 
    "Plant", 
    "Part", 
    "Requirement_Type" 
    FROM 
    (SELECT DISTINCT 
		'Sales' as "Requirement_Source",
		VP.WERKS as "Plant", 
		VP.MATNR as "Part", 
		VP.BEDAE as "Requirement_Type",
		VP.VBELN,
		VP.POSNR,
		SUM(VE.BMENG) as "Requirement_QTY",
		(SELECT COALESCE(SUM("LFIMG"),0)
 	     FROM "DATA_SLT_CERP"."LIPS" L 
 		 JOIN "DATA_SLT_CERP"."LIKP" LP ON L."VBELN" = LP."VBELN" 
 		 WHERE L."VGBEL" = VP."VBELN" AND L."VGPOS" = VP."POSNR"
 		) as "QTY_Withdrawn"
		FROM DATA_SLT_CERP.VBAK VA 
		JOIN DATA_SLT_CERP.VBAP VP ON VA.VBELN = VP.VBELN
		JOIN DATA_SLT_CERP.VBUP VU ON VA.VBELN = VU.VBELN AND VP.POSNR = VU.POSNR
		JOIN DATA_SLT_CERP.VBEP VE ON VA.VBELN = VE.VBELN AND VP.POSNR = VE.POSNR
		WHERE VP.MATNR != '' 
		AND VP."ABGRU" IN ('',' ',NULL)
		AND VU.GBSTA IN ('A', 'B')
		AND (VE.MBDAT >= ADD_YEARS(CURRENT_DATE,-1) AND VE.MBDAT <= ADD_MONTHS(CURRENT_DATE, 18))
		GROUP BY VP.WERKS, VP.MATNR, VP.BEDAE, VP.VBELN, VP.POSNR
		) WHERE "Requirement_QTY" != "QTY_Withdrawn"
  )
);

_monthcounter := 0;  --sets the counter @ 0 to start the loop

while _monthcounter < 19 do  -- loops over this block until counter reaches 19 and then it exits

_column := 'Current_Month+'||to_char(:_monthcounter);

IF _monthcounter = 0 --checks for the current_month because the statement is different
THEN

_statement_prod :=
'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH
SET "Current_Month" = 
		 (
			 SELECT COALESCE((SUM(BDMNG) - SUM(ENMNG)),0)
			 FROM DATA_SLT_CERP.RESB  
			 WHERE ("Plant" = WERKS AND "Part" = MATNR AND "Requirement_Type" = BDART) 
			 AND BDTER <= (ADD_DAYS(ADD_MONTHS(ADD_DAYS(CURRENT_DATE,-EXTRACT(DAY FROM CURRENT_DATE) + 1),1),-1))
			 AND SUBSTR(LGORT,0,1) NOT IN (''Q'')
			 AND (AUFNR != '''' OR PLNUM != '''') AND XLOEK NOT IN (''X'') AND KZEAR NOT IN (''X'')
			 AND (ENMNG != BDMNG)
		 )
WHERE "Requirement_Source" = ''Production'' ';

_statement_sales :=
'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH
SET "Current_Month" = 
(
		
			SELECT COALESCE(SUM("Open"),0) FROM(SELECT (SUM(WMENG) - "Withdrawn") as "Open" 
			FROM
			(
				SELECT VE.WMENG,
				(
						SELECT COALESCE(SUM("LFIMG"),0)
						FROM "DATA_SLT_CERP"."LIPS" L 
						JOIN "DATA_SLT_CERP"."LIKP" LP ON L."VBELN" = LP."VBELN" 
						WHERE L."VGBEL" = VP."VBELN" AND L."VGPOS" = VP."POSNR"
				)as "Withdrawn"
				FROM DATA_SLT_CERP.VBAK VA 
				JOIN DATA_SLT_CERP.VBAP VP ON VA.VBELN = VP.VBELN
				JOIN DATA_SLT_CERP.VBUP VU ON VA.VBELN = VU.VBELN AND VP.POSNR = VU.POSNR
				JOIN DATA_SLT_CERP.VBEP VE ON VA.VBELN = VE.VBELN AND VP.POSNR = VE.POSNR
				WHERE (VP.WERKS = "Plant" AND VP.MATNR = "Part" AND VP.BEDAE = "Requirement_Type")
				AND VE.MBDAT <= (ADD_DAYS(ADD_MONTHS(ADD_DAYS(CURRENT_DATE,-EXTRACT(DAY FROM CURRENT_DATE) + 1),1),-1))   
				AND VU.GBSTA IN (''A'', ''B'')
				GROUP BY VP.VBELN, VP.POSNR, VE.WMENG)GROUP BY "Withdrawn")
		)
WHERE "Requirement_Source" = ''Sales'' ';

_statement_normalize := 'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH SET "Current_Month" = 0 WHERE "Current_Month" < 0';

ELSE  -- the rest of the months

_statement_prod :=
'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH
SET "Current_Month+'||to_char(:_monthcounter)||'" = 
		 (
			 SELECT COALESCE((SUM(BDMNG) - SUM(ENMNG)),0)
			 FROM DATA_SLT_CERP.RESB  
			 WHERE ("Plant" = WERKS AND "Part" = MATNR AND "Requirement_Type" = BDART) 
			 AND (YEAR(BDTER) = YEAR(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')) AND MONTH(BDTER) = MONTH(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||'))) 
			 AND SUBSTR(LGORT,0,1) NOT IN (''Q'')
			 AND (AUFNR != '''' OR PLNUM != '''') AND XLOEK NOT IN (''X'') AND KZEAR NOT IN (''X'')
			 AND (ENMNG != BDMNG)
		 )
WHERE "Requirement_Source" = ''Production'' ';

_statement_sales :=
'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH
SET "Current_Month+'||to_char(:_monthcounter)||'" = 
		(
		
			SELECT COALESCE(SUM("Open"),0) FROM(SELECT (SUM(WMENG) - "Withdrawn") as "Open" 
			FROM
			(
				SELECT VE.WMENG,
				(
						SELECT COALESCE(SUM("LFIMG"),0)
						FROM "DATA_SLT_CERP"."LIPS" L 
						JOIN "DATA_SLT_CERP"."LIKP" LP ON L."VBELN" = LP."VBELN" 
						WHERE L."VGBEL" = VP."VBELN" AND L."VGPOS" = VP."POSNR"
				)as "Withdrawn"
				FROM DATA_SLT_CERP.VBAK VA 
				JOIN DATA_SLT_CERP.VBAP VP ON VA.VBELN = VP.VBELN
				JOIN DATA_SLT_CERP.VBUP VU ON VA.VBELN = VU.VBELN AND VP.POSNR = VU.POSNR
				JOIN DATA_SLT_CERP.VBEP VE ON VA.VBELN = VE.VBELN AND VP.POSNR = VE.POSNR
				WHERE (VP.WERKS = "Plant" AND VP.MATNR = "Part" AND VP.BEDAE = "Requirement_Type")
				AND (YEAR(VE.MBDAT) = YEAR(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')) AND MONTH(VE.MBDAT) = MONTH(ADD_MONTHS(CURRENT_DATE,'||to_char(:_monthcounter)||')))
				AND VU.GBSTA IN (''A'', ''B'')
				GROUP BY VP.VBELN, VP.POSNR, VE.WMENG)GROUP BY "Withdrawn")
		)
WHERE "Requirement_Source" = ''Sales'' ';
_statement_normalize := 'UPDATE SCHEMA.ZTB_DEMAND_FORECAST_18MONTH SET "Current_Month+'||:_monthcounter||'" = 0 WHERE "Current_Month+'||:_monthcounter||'" < 0';

END IF;


EXECUTE IMMEDIATE(:_statement_prod);
EXECUTE IMMEDIATE(:_statement_sales);
EXECUTE IMMEDIATE(:_statement_normalize);

_monthcounter := :_monthcounter+1;
end while;
end;