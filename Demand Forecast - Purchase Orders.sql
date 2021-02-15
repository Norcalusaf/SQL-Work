CREATE PROCEDURE SCHEMA.ZPR_PO_FORECAST_18MONTH LANGUAGE SQLSCRIPT AS
BEGIN
/**************************************************************************
Description: Inserts the base data for the PO demand for the next 18 months
this is broken up by inventory type.

Created: 1/11/2021
Author: Chris Wilson

***************************************************************************/

--Truncates source table
TRUNCATE TABLE SCHEMA.ZTB_PO_FORECAST_18MONTH;
TRUNCATE TABLE SCHEMA.ZTB_PO_PRICE_FORECAST_18MONTH;

--inserts the rec source, plant, part, and rec type
INSERT INTO SCHEMA.ZTB_PO_FORECAST_18MONTH(
	SELECT DISTINCT 
	"Inventory_Type",
	"Plant", 
	"Part", 
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
		CASE
			WHEN B.PSTYP = 2
			THEN 'VOI'
			ELSE 'SOI'
		END as "Inventory_Type",
	    A."Plant", 
		A."Part"
		FROM SCHEMA.ZTB_PURCHASE_ORDERS A
		JOIN SCHEMA.EKPO B ON A.MANDT = B.MANDT AND A."PO_Number" = B.EBELN AND A."PO_Item" = B.EBELP
		WHERE "Delivery_Date" >= CURRENT_DATE AND "Delivery_Date" <= ADD_MONTHS(CURRENT_DATE, 18)
		AND "QTY_Open" > 0
		AND "Part" != ''
	)
);

INSERT INTO SCHEMA.ZTB_PO_PRICE_FORECAST_18MONTH(
	SELECT DISTINCT 
	"Inventory_Type",
	"Plant", 
	"Part", 
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
	FROM SCHEMA.ZTB_PO_FORECAST_18MONTH
);


UPDATE SCHEMA.ZTB_PO_FORECAST_18MONTH A
SET A."Current_Month" = 
(

	SELECT SUM("QTY_Open") 
	FROM
	(
		SELECT DISTINCT
		"Part" as Z_PART,
		"Plant" as Z_PLANT,
		"QTY_Open", 
		CASE
			WHEN C.PSTYP = 2
			THEN 'VOI'
			ELSE 'SOI'
		END as Z_TYPE
		FROM SCHEMA.ZTB_PURCHASE_ORDERS B
		JOIN SCHEMA.EKPO C ON B.MANDT = C.MANDT AND B."PO_Number" = C.EBELN AND B."PO_Item" = C.EBELP
		WHERE (YEAR("Delivery_Date") = YEAR(CURRENT_DATE) AND MONTH("Delivery_Date") <= MONTH(CURRENT_DATE)) 
		AND "Delivery_Completed" = '' AND "QTY_Open" > 0
		AND "Part" IS NOT NULL
	)WHERE A."Part" = Z_PART AND A."Plant" = Z_PLANT AND A."Inventory_Type" = Z_TYPE
);

UPDATE SCHEMA.ZTB_PO_FORECAST_18MONTH A
SET A."Current_Month" = 0
WHERE A."Current_Month" IS NULL;


UPDATE SCHEMA.ZTB_PO_PRICE_FORECAST_18MONTH A
SET A."Current_Month" = 
(
	SELECT AVG(Z_PRICE)
	FROM
	(
		SELECT
		Z_PO,
		Z_PLANT,
		CASE
			WHEN Z_CON_PRICE = 0
			THEN
			CASE
				WHEN Z_PO_PRICE = 0
				THEN Z_MAT_PRICE
				ELSE Z_PO_PRICE 
			END
			ELSE Z_CON_PRICE
		END AS Z_PRICE
		FROM
		(	
			SELECT
			PO.Z_PO,
			PO.Z_PART,
			PO.Z_PLANT,
			PO.Z_OPEN,
			PO.Z_TYPE,
			PO.Z_PO_PRICE,
			PO.Z_MAT_PRICE,
			CASE
				WHEN (PO.Z_CON_PEINH IN (0, NULL) OR PO.Z_CON_NETPR IN(0, NULL))
				THEN 0
				ELSE (PO.Z_CON_NETPR/PO.Z_CON_PEINH)
			END AS Z_CON_PRICE
			FROM
			(
				SELECT 
				PO_BASE.Z_PO,
				PO_BASE.Z_PART,
				PO_BASE.Z_PLANT,
				PO_BASE.Z_OPEN,
				PO_BASE.Z_TYPE,
				CON_BASE.NETPR as Z_CON_NETPR,
				CON_BASE.PEINH as Z_CON_PEINH,
				CASE
					WHEN PO_BASE.Z_PEINH IN (0, NULL) OR PO_BASE.Z_NETPR IN (0, NULL)
					THEN 0
					ELSE (PO_BASE.Z_NETPR/PO_BASE.Z_PEINH)
				END AS Z_PO_PRICE,
				CASE
					WHEN (MAT_PRICE.ZPLP1 IN (0, NULL))
					THEN MAT_PRICE.STPRS
					ELSE MAT_PRICE.ZPLP1
				END AS Z_MAT_PRICE
				FROM
				(
					SELECT DISTINCT 
					CONCAT("PO_Number", CONCAT("PO_Item", "PO_Line")) as Z_PO,
					C.NETPR as Z_NETPR,
					C.PEINH as Z_PEINH,
					"Part" as Z_PART, 
					"Plant" as Z_PLANT, 
					"QTY_Open" as Z_OPEN, 
					KONNR as Z_CONTRACT,
					KTPNR as Z_CON_ITEM,
					CASE 
						WHEN C.PSTYP = '2' 
						THEN 'VOI' 
						ELSE 'SOI'
				    END as Z_TYPE 
				    FROM SCHEMA.ZTB_PURCHASE_ORDERS B 
				    JOIN SCHEMA.EKPO C ON B.MANDT = C.MANDT AND B."PO_Number" = C.EBELN  AND B."PO_Item" = C.EBELP 
				    WHERE "QTY_Open" > 0 AND B."Part" = A."Part" AND B."Plant" = A."Plant"
				    AND "Delivery_Completed" = ''
				    AND (YEAR("Delivery_Date") = YEAR(CURRENT_DATE) AND MONTH("Delivery_Date") <= MONTH(CURRENT_DATE))
				) PO_BASE
				LEFT OUTER JOIN SCHEMA.EKPO CON_BASE ON PO_BASE.Z_CONTRACT = CON_BASE.EBELN AND PO_BASE.Z_CON_ITEM = CON_BASE.EBELP
				LEFT OUTER JOIN SCHEMA.MBEW MAT_PRICE ON PO_BASE.Z_PART = MAT_PRICE.MATNR AND PO_BASE.Z_PLANT = MAT_PRICE.BWKEY
				WHERE PO_BASE.Z_TYPE = A."Inventory_Type"
			) PO
		)
	)
);

UPDATE SCHEMA.ZTB_PO_PRICE_FORECAST_18MONTH A
SET A."Current_Month" = 0
WHERE A."Current_Month" IS NULL;



END;