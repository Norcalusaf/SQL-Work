/**************************************************************************
Description: Line of Balance Data Set
***************************************************************************/
CURSOR result FOR
(
			SELECT DISTINCT
            z_DATE
   			 FROM SCHEMA.LOB 
   			 Where z_DATE > CURRENT_DATE
   			 ORDER BY z_DATE ASC
);     
BEGIN

UPDATE SCHEMA.LOB A
SET A.END_ACTUAL = 
(
	(A.START_ACTUAL + A.IN_TRANSIT + A.FORECASTED) 
  - (A.REQUIREMENT_A + A.REQUIREMENT_B)
)WHERE z_DATE = CURRENT_DATE;

UPDATE SCHEMA.LOB A
SET A.END_SCHEDULE = 
(
	(A.START_SCHEDULE + A.FORECASTED) 
  - (A.REQUIREMENT_A + A.REQUIREMENT_B)
)WHERE z_DATE = CURRENT_DATE;

UPDATE SCHEMA.LOB A
SET A.NO_FORECAST_END = 
(
	(A.NO_FORECAST_START) - (A.REQUIREMENT_A + A.REQUIREMENT_B)
)WHERE z_DATE = CURRENT_DATE;

UPDATE SCHEMA.LOB A
SET A.NO_FORECAST_END_V2 = 
(
	(A.NO_FORECAST_START_V2) - (A.REQUIREMENTS_V2)
)WHERE z_DATE = CURRENT_DATE;



FOR group_row as result DO  --Cursor starts here

    last_result = SELECT DISTINCT ADD_DAYS(z_DATE, 1) as z_DATE, MATERIAL, LOCATION, END_ACTUAL, END_SCHEDULE, NO_FORECAST_END, NO_FORECAST_END_V2 FROM SCHEMA.LOB WHERE z_DATE = ADD_DAYS(:group_row.z_DATE, -1);

        UPDATE SCHEMA.LOB A
        SET A.START_ACTUAL =
        (
            SELECT B.END_ACTUAL from :last_result B WHERE B.z_DATE = A.z_DATE AND B.MATERIAL = A.MATERIAL and B.LOCATION = A.LOCATION
        )
        WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.START_SCHEDULE =
        (
            SELECT B.END_SCHEDULE from :last_result B WHERE B.z_DATE = A.z_DATE AND B.MATERIAL = A.MATERIAL and B.LOCATION = A.LOCATION
        )
        WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.NO_FORECAST_START =
        (
            SELECT B.NO_FORECAST_END from :last_result B WHERE B.z_DATE = A.z_DATE AND B.MATERIAL = A.MATERIAL and B.LOCATION = A.LOCATION
        )
        WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.NO_FORECAST_START_V2 =
        (
            SELECT B.NO_FORECAST_END_V2 from :last_result B WHERE B.z_DATE = A.z_DATE AND B.MATERIAL = A.MATERIAL and B.LOCATION = A.LOCATION
        )
        WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.END_ACTUAL =
        (
            (A.START_ACTUAL + A.IN_TRANSIT + A.FORECASTED)
          - (A.REQUIREMENT_A + A.REQUIREMENT_B)
        )WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.END_SCHEDULE =
        (
            (A.START_SCHEDULE + A.FORECASTED)
          - (A.REQUIREMENT_A + A.REQUIREMENT_B)
        )WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.NO_FORECAST_END =
        ((A.NO_FORECAST_START) - (A.REQUIREMENT_A + A.REQUIREMENT_B)
        )WHERE A.z_DATE = :group_row.z_DATE;

        UPDATE SCHEMA.LOB A
        SET A.NO_FORECAST_END_V2 =
        ((A.NO_FORECAST_START_V2) - A.REQUIREMENTS_V2
        )WHERE A.z_DATE = :group_row.z_DATE;


END FOR;
 
 END;