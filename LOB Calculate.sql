/**************************************************************************
Description: Line of Balance Data Set
***************************************************************************/

--cursor over the date, the LOB data set has to process day over day
CURSOR result FOR
(
			SELECT DISTINCT
            z_DATE
   			 FROM SCHEMA.LOB 
   			 Where z_DATE > CURRENT_DATE
   			 ORDER BY z_DATE ASC
);     
BEGIN

--updates the starting dates records the starting date
UPDATE SCHEMA.LOB A
SET A.Z_END = 
(
	(A.START_ACTUAL + A.IN_TRANSIT + A.FORECASTED) 
  - (A.REQUIREMENT_A + A.REQUIREMENT_B)
)WHERE z_DATE = CURRENT_DATE;



FOR group_row as result DO  --Cursor starts here, it goes from today + 1 and continue until it reaches the end of the dataset.

--gets the last days results, this is used to get the ending balance from the day prior
    last_result = SELECT DISTINCT ADD_DAYS(z_DATE, 1) as z_DATE, MATERIAL, LOCATION, Z_END FROM SCHEMA.LOB WHERE z_DATE = ADD_DAYS(:group_row.z_DATE, -1);

--updates the starting balance by using the ending balance form the day prior
        UPDATE SCHEMA.LOB A
        SET A.z_START =
        (
            SELECT B.z_END from :last_result B WHERE B.z_DATE = A.z_DATE AND B.MATERIAL = A.MATERIAL and B.LOCATION = A.LOCATION
        )
        WHERE A.z_DATE = :group_row.z_DATE;

--updates the ending balance
        UPDATE SCHEMA.LOB A
        SET A.z_END =
        (
            (A.z_START + A.IN_TRANSIT + A.FORECASTED)
          - (A.REQUIREMENT_A + A.REQUIREMENT_B)
        )WHERE A.z_DATE = :group_row.z_DATE;

END FOR;
 
END;