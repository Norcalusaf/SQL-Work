CREATE PROCEDURE SCHEMA.ZPR_SPH_LINE_OF_BALANCE_BASE_DATA_CALCULATE LANGUAGE SQLSCRIPT AS 
CURSOR result FOR
(
			SELECT DISTINCT
            "Date"
   			 FROM "SCHEMA"."ZTB_SPH_LINE_OF_BALANCE_BASE" 
   			 Where "Date" > CURRENT_DATE
   			 ORDER BY "Date" ASC
);     

BEGIN

/*************************************************************
Job: This builds out the balance of the Line of Balance

Description: 
This procedure calculates the running totals. It uses a cursor
on the date to loop over each date ASC until it has calculated
the entire running total. This calculates the actual ending 
balance and the scheduled ending balance

Author: Chris Wilson
Date: 12/6/19
*************************************************************/


--End of Day Actual for first date
UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
SET A."On_Hand_End_Actual" = 
(
	(A."On_Hand_Start_Actual" + A."ASN_Incoming" + A."Forecast_Incoming") 
  - (A."Production_Requirements" + A."Sales_Requirements")
)WHERE "Date" = CURRENT_DATE;


--Schedule End of Date for First date
UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
SET A."On_Hand_End_Sch" = 
(
	(A."On_Hand_Start_Sch" + A."PO_Incoming_Discrete" + A."PO_Incoming_MinMax") 
  - (A."Production_Requirements" + A."Sales_Requirements")
)WHERE "Date" = CURRENT_DATE;

--No ASN, Actual running LOB from Today forward
UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
SET A."No_ASN_End" = 
(
	(A."No_ASN_Start") - (A."Production_Requirements" + A."Sales_Requirements")
)WHERE "Date" = CURRENT_DATE;

--No ASN, Actual running LOB from Today forward for QA orders
UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
SET A."No_ASN_End_QA" = 
(
	(A."No_ASN_Start_QA") - (A."Production_Requirements_QA")
)WHERE "Date" = CURRENT_DATE;



FOR group_row as result DO  --Cursor starts here


last_result = SELECT DISTINCT ADD_DAYS("Date", 1) as "Date", "Part", "Plant","On_Hand_End_Actual", "On_Hand_End_Sch", "No_ASN_End", "No_ASN_End_QA" FROM SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE WHERE "Date" = ADD_DAYS(:group_row."Date", -1);
--Actual Starts
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."On_Hand_Start_Actual" = 
	(
		SELECT B."On_Hand_End_Actual" from :last_result B WHERE B."Date" = A."Date" AND B."Part" = A."Part" and B."Plant" = A."Plant"
	) 
	WHERE A."Date" = :group_row."Date";
	
--Schedule Starts
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."On_Hand_Start_Sch" = 
	(
		SELECT B."On_Hand_End_Sch" from :last_result B WHERE B."Date" = A."Date" AND B."Part" = A."Part" and B."Plant" = A."Plant"
	) 
	WHERE A."Date" = :group_row."Date";

--No ASN Start
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."No_ASN_Start" = 
	(
		SELECT B."No_ASN_End" from :last_result B WHERE B."Date" = A."Date" AND B."Part" = A."Part" and B."Plant" = A."Plant"
	) 
	WHERE A."Date" = :group_row."Date";
	
--No ASN Start QA
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."No_ASN_Start_QA" = 
	(
		SELECT B."No_ASN_End_QA" from :last_result B WHERE B."Date" = A."Date" AND B."Part" = A."Part" and B."Plant" = A."Plant"
	) 
	WHERE A."Date" = :group_row."Date";
	
--Actual Ends
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."On_Hand_End_Actual" = 
	(
		(A."On_Hand_Start_Actual" + A."ASN_Incoming" + A."Forecast_Incoming")
	  - (A."Production_Requirements" + A."Sales_Requirements")
	)WHERE A."Date" = :group_row."Date";
	
--Schedule Ends
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."On_Hand_End_Sch" = 
	(
		(A."On_Hand_Start_Sch" + A."PO_Incoming_Discrete" + A."PO_Incoming_MinMax")
	  - (A."Production_Requirements" + A."Sales_Requirements")
	)WHERE A."Date" = :group_row."Date";

--No ASN End
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."No_ASN_End" = 
	((A."No_ASN_Start") - (A."Production_Requirements" + A."Sales_Requirements")
	)WHERE A."Date" = :group_row."Date";
	
	
--No ASN End QA
	UPDATE SCHEMA.ZTB_SPH_LINE_OF_BALANCE_BASE A
	SET A."No_ASN_End_QA" = 
	((A."No_ASN_Start_QA") - A."Production_Requirements_QA"
	)WHERE A."Date" = :group_row."Date";
	
 
 END FOR;
 
 END;