SELECT 
	PAPF.PERSON_NUMBER "EmployeeNumber",
	PPNF.TITLE "Title",
	PPNF.FIRST_NAME "FirstName",   
	PPNF.LAST_NAME  "Surname",
	PPNF.NAM_INFORMATION15 	   "PreferredName",
	PEA.EMAIL_ADDRESS "Email",
	(select FLV.MEANING 
		   from fnd_lookup_values flv
		   where  FLV.LOOKUP_TYPE = 'ORA_PER_SEX'      
                  AND FLV.LOOKUP_CODE = PPLF.SEX 
	              AND FLV.ENABLED_FLAG = 'Y'
		      ) "Gender",
	TO_CHAR(PP.DATE_OF_BIRTH,'DD/MM/YYYY') "Birthdate",
	TO_CHAR(PPOS.DATE_START,'DD/MM/YYYY') "GroupStartDate",
	TO_CHAR(PAAM.EFFECTIVE_START_DATE,'DD/MM/YYYY') "StartDate",
	pposition.name  "JobTitle",
	PD.NAME "Company",
	PLOC.LOCATION_NAME "Location",
	PAAM.ASS_ATTRIBUTE1 "Department",
	CASE 
        WHEN PAAM.FULL_PART_TIME IS NOT NULL 
               THEN INITCAP(REPLACE(PAAM.FULL_PART_TIME, '_', ' '))
               ELSE NULL
         END AS "EmploymentType",
	CASE 
         WHEN PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE' THEN 'Active'
            ELSE 'Inactive'
         END AS "EmployeeStatus",
    CS.Salary_Amount as "SalaryAmount",
	ROUND(PAAM.NORMAL_HOURS, 1) AS "ContractualHours",
CASE 
    WHEN PAAM.FULL_PART_TIME = 'PART_TIME' 
         THEN PAAM.ASS_ATTRIBUTE_NUMBER1
    ELSE NULL
END AS  "DaysPerWeek",
CASE 
    WHEN PAAM.FULL_PART_TIME = 'PART_TIME' THEN 
        TRUNC(
            CAST(
                NVL(PAAM.NORMAL_HOURS, 0) / NULLIF(PAAM.ASS_ATTRIBUTE_NUMBER1, 0)
                AS NUMBER(10,4)
            ), 
            2
        )
    ELSE 
        NULL
END AS "AverageHoursPerDay",
CASE
    WHEN PAAM.FULL_PART_TIME = 'PART_TIME' THEN
        CASE 
            WHEN MOD(TRUNC(
                        (CS.SALARY_AMOUNT / 52 / ROUND(PAAM.NORMAL_HOURS, 1)) * 
                        TRUNC(NVL(PAAM.NORMAL_HOURS, 0) / NULLIF(PAAM.ASS_ATTRIBUTE_NUMBER1, 0), 2),
                        3
                     ) * 1000, 10) >= 5
            THEN TRUNC(
                     (CS.SALARY_AMOUNT / 52 / ROUND(PAAM.NORMAL_HOURS, 1)) * 
                     TRUNC(NVL(PAAM.NORMAL_HOURS, 0) / NULLIF(PAAM.ASS_ATTRIBUTE_NUMBER1, 0), 2),
                     2
                 ) + 0.01
            ELSE TRUNC(
                     (CS.SALARY_AMOUNT / 52 / ROUND(PAAM.NORMAL_HOURS, 1)) * 
                     TRUNC(NVL(PAAM.NORMAL_HOURS, 0) / NULLIF(PAAM.ASS_ATTRIBUTE_NUMBER1, 0), 2),
                     2
                 )
        END
    ELSE 
        NULL
END AS "HolidayCostPerDay",

-- CASE
    -- WHEN PAAM.FULL_PART_TIME = 'PART_TIME' THEN
        -- TRUNC(
            -- (CS.SALARY_AMOUNT / 52 / ROUND(PAAM.NORMAL_HOURS, 1)) * 
            -- TRUNC(
                -- NVL(PAAM.NORMAL_HOURS, 0) / NULLIF(PAAM.ASS_ATTRIBUTE_NUMBER1, 0),
                -- 2
            -- ),
        -- 2)
    -- ELSE 
        -- NULL
-- END AS "HolidayCostPerDay",


ROUND(
  (37.5 / NULLIF(ROUND(PAAM.NORMAL_HOURS,1), 0)) * CS.SALARY_AMOUNT,
  2
) AS "FTESalary",
PA.ADDRESS_LINE_1"Address1",
PA.ADDRESS_LINE_2 "Address2",
PA.TOWN_OR_CITY "City",
PA.REGION_2 "County",
(select FLV.MEANING 
		   from fnd_lookup_values flv
		   where  FLV.LOOKUP_TYPE = 'ORA_HRX_FR_COUNTRIES'      
                  AND FLV.LOOKUP_CODE = PA.COUNTRY 
	              AND FLV.ENABLED_FLAG = 'Y'
		      ) "Country",
--PA.COUNTRY "Country",
PA.POSTAL_CODE "Postcode",
CASE 
     WHEN PLOC.LOCATION_NAME IS NULL THEN NULL
     WHEN PLOC.LOCATION_NAME= 'Dublin'  THEN 'IRL' 
     ELSE 'GBR'
END AS "CountryIdentifier",
CASE 
    WHEN PAAM.ASS_ATTRIBUTE5 = 'Y' THEN 'TRUE'
    WHEN PAAM.ASS_ATTRIBUTE5 = 'N' THEN 'FALSE'
    ELSE NULL
END AS "PMIBenefitsDay1",
CASE 
    WHEN PAAM.ASS_ATTRIBUTE6 = 'Y' THEN 'TRUE'
    WHEN PAAM.ASS_ATTRIBUTE6 = 'N' THEN 'FALSE'
    ELSE NULL
END AS "DentalBenefitsDay1",
TO_CHAR(PPOS.ACTUAL_TERMINATION_DATE,'DD/MM/YYYY') "LeaveDate",
PWM.VALUE "FTE"


From 
	PER_ALL_PEOPLE_F 				     PAPF,
	PER_PERSON_NAMES_F 				     PPNF,
	PER_PEOPLE_LEGISLATIVE_F             PPLF,
	PER_EMAIL_ADDRESSES                  PEA,
	PER_ALL_ASSIGNMENTS_M 			     PAAM,
	PER_PERSONS                          PP,
	PER_PERIODS_OF_SERVICE               PPOS,
	hr_all_positions     			     pposition,
	PER_DEPARTMENTS 				     PD,
	HR_LOCATIONS					     PLOC,
	CMP_SALARY                           CS,
	PER_PERSON_ADDRESSES_V               PA,
	HR_ORGANIZATION_UNITS_F_TL           HOU,
	PER_PERSON_TYPE_USAGES_M             PPT,
	PER_ASSIGN_WORK_MEASURES_F           PWM

	

WHERE
	PAPF.PERSON_ID = PPNF.PERSON_ID(+)
	AND PPNF.NAME_TYPE = 'GLOBAL'
	AND PAPF.PERSON_ID = PAAM.PERSON_ID(+)
	AND TRUNC(SYSDATE) BETWEEN PAAM.EFFECTIVE_START_DATE(+) AND PAAM.EFFECTIVE_END_DATE(+)
	AND TRUNC(SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE(+) AND PAPF.EFFECTIVE_END_DATE(+)
	AND TRUNC(SYSDATE) BETWEEN PPNF.EFFECTIVE_START_DATE(+) AND PPNF.EFFECTIVE_END_DATE(+)
	AND TRUNC(SYSDATE) BETWEEN PPLF.EFFECTIVE_START_DATE(+) AND PPLF.EFFECTIVE_END_DATE(+)
	AND TRUNC(SYSDATE) BETWEEN CS.DATE_FROM(+) AND CS.DATE_TO(+)
	AND PAAM.ASSIGNMENT_TYPE = 'E'
	AND PPT.SYSTEM_PERSON_TYPE IN ('EMP','EX_EMP')
	AND PAAM.EFFECTIVE_LATEST_CHANGE = 'Y'
	AND PEA.EMAIL_TYPE(+)='W1'
    AND PAAM.PRIMARY_ASSIGNMENT_FLAG = 'Y'
	AND (
       (PAAM.ASSIGNMENT_STATUS_TYPE = 'ACTIVE' 
        AND (PPOS.ACTUAL_TERMINATION_DATE IS NULL 
             OR TRUNC(PPOS.ACTUAL_TERMINATION_DATE) <= TRUNC(SYSDATE) + 180)
       )
    OR (
           PAAM.ASSIGNMENT_STATUS_TYPE <> 'ACTIVE'
       AND TRUNC(PPOS.ACTUAL_TERMINATION_DATE) 
             BETWEEN TRUNC(SYSDATE) - 30 
                 AND TRUNC(SYSDATE) + 180
       )
    )
	AND PPLF.PERSON_ID(+) =PAPF.PERSON_ID
	 AND PEA.PERSON_ID(+)=PAPF.PERSON_ID
	AND ppos.PERSON_ID(+) =PAPF.PERSON_ID
	AND PPOS.PERIOD_OF_SERVICE_ID(+) =PAAM.PERIOD_OF_SERVICE_ID 
	AND PAAM.ORGANIZATION_ID = PD.ORGANIZATION_ID(+)
	AND PAAM.EFFECTIVE_START_DATE BETWEEN PD.EFFECTIVE_START_DATE(+) AND PD.EFFECTIVE_END_DATE(+)
	AND PAPF.PERSON_ID = PP.PERSON_ID
    AND pposition.position_id(+)  = paam.position_id
    AND paam.effective_start_date Between pposition.effective_start_date(+) AND pposition.effective_end_date(+)
	AND paam.location_id =PLOC.LOCATION_ID(+)
    AND paam.effective_start_date Between PLOC.effective_start_date(+) AND PLOC.effective_end_date(+)
	AND CS.PERSON_ID(+)=PAPF.PERSON_ID
	AND PA.person_id (+) =PAPF.person_id
	AND TRUNC(SYSDATE) BETWEEN PA.EFFECTIVE_START_DATE(+) AND PA.EFFECTIVE_END_DATE(+)
	AND HOU.Name IN('Softcat UK PLC','Softcat Plc Ireland')
	AND HOU.organization_id(+)  = paam.LEGAL_ENTITY_ID
	AND TRUNC(SYSDATE) BETWEEN HOU.EFFECTIVE_START_DATE(+) AND HOU.EFFECTIVE_END_DATE(+)
	AND PAPF.PERSON_ID = PPT.PERSON_ID (+) 
	AND TRUNC(SYSDATE) BETWEEN PPT.EFFECTIVE_START_DATE(+) AND PPT.EFFECTIVE_END_DATE(+)
	AND PWM.UNIT ='FTE'
	AND PWM.ASSIGNMENT_ID(+) = PAAM.ASSIGNMENT_ID
	AND TRUNC(SYSDATE) BETWEEN PWM.EFFECTIVE_START_DATE(+) AND PWM.EFFECTIVE_END_DATE(+)
	--AND PAPF.PERSON_NUMBER IN('1000084')
	-- AND PAPF.PERSON_NUMBER IN ('1000084','18','46','48','51','201','1001366')