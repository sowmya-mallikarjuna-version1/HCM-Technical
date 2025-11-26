SELECT 
	 "EmployeeNumber"
	,"CategoryKey"
	,"ItemExternalID"
	,"ItemName"
	,"Type"
	,TO_CHAR(ROUND(SUM("amount"),2)) "EmployeeCost"
FROM(
	SELECT 
		papf.person_number "EmployeeNumber"
	    ,flv.DESCRIPTION "CategoryKey"
		,flv.lookup_code "ItemExternalID"
		,flv.MEANING  "ItemName"
		,bogtl.DESCRIPTION "Type"
		,prrv.result_value "amount"
FROM  
	    per_all_people_f                 papf
	   ,per_all_assignments_m            paaf
	   ,per_periods_of_service           ppos
	   ,pay_payroll_assignments 		 ppact
	   ,pay_time_periods 				 ptp
       ,pay_payroll_actions			     ppa
	   ,pay_all_payrolls_f 			     paf
	   ,pay_payroll_rel_actions 		 ppra
	   ,pay_run_results 				 prr
	   ,pay_run_result_values 			 prrv
	   ,pay_input_values_f 			     pivf
	   ,pay_input_values_tl			     pivt
	   ,PAY_ELEMENT_ENTRIES_F            peef
	   ,pay_element_types_f 			 petf
       ,pay_element_types_tl 			 pett
	   ,pay_ele_classifications_vl 	     pecv
	   ,PAY_OBJECT_GROUP_AMENDS          pga
	   ,PAY_OBJECT_GROUPS                bogn
	   ,PAY_OBJECT_GROUPS_TL             bogtl
	   ,fnd_lookup_values                flv

    WHERE  1=1
		AND papf.person_id = paaf.person_id
		AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(paaf.effective_start_date) AND TRUNC(paaf.effective_end_date)
		AND paaf.primary_flag = 'Y'
		AND paaf.EFFECTIVE_LATEST_CHANGE = 'Y'
		AND paaf.assignment_id = ppact.hr_assignment_id
		AND papf.PERSON_ID = ppos.PERSON_ID
		AND paaf.PERIOD_OF_SERVICE_ID = ppos.PERIOD_OF_SERVICE_ID
		and TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(ppact.start_date) AND TRUNC(ppact.end_date)
		AND ptp.payroll_id = ppa.payroll_id
        AND ptp.time_period_id = ppa.earn_time_period_id
		AND ptp.period_category = 'E'
		AND paf.payroll_id = ppa.payroll_id
		AND ppa.payroll_action_id = ppra.payroll_action_id
		AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(paf.effective_start_date) AND TRUNC(paf.effective_end_date)
		AND ppra.payroll_relationship_id = ppact.payroll_relationship_id
		AND Nvl(prr.payroll_assignment_id, ppact.payroll_assignment_id) = ppact.payroll_assignment_id
        AND Nvl(prr.payroll_term_id, ppact.payroll_term_id) = ppact.payroll_term_id
		AND prr.payroll_rel_action_id = ppra.payroll_rel_action_id
		AND prrv.run_result_id = prr.run_result_id(+)
		AND pivf.input_value_id = prrv.input_value_id
		AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(pivf.effective_start_date) AND TRUNC(pivf.effective_end_date)
		AND pivf.input_value_id = pivt.input_value_id
		AND pivt.LANGUAGE = Userenv('LANG')
        AND pivt.source_lang = Userenv('LANG')
		AND pivt.name IN ('Pay Value')
		AND papf.person_id = peef.person_id
		AND peef.element_type_id = petf.element_type_id
		AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(peef.effective_start_date) AND TRUNC(peef.effective_end_date)
		AND pivf.element_type_id = petf.element_type_id
		AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(petf.effective_start_date) AND TRUNC(petf.effective_end_date)
		AND pett.element_type_id = petf.element_type_id
		AND pett.LANGUAGE = Userenv('LANG')
        AND pett.source_lang = Userenv('LANG')
        AND prr.element_type_id = pett.element_type_id
        AND petf.classification_id = pecv.classification_id
		AND petf.element_type_id = pga.OBJECT_ID
		and pga.OBJECT_GROUP_ID = bogn.OBJECT_GROUP_ID
		AND TRUNC(ptp.PROCESS_SUB_DATE) Between TRUNC(SYSDATE, 'MM') AND LAST_DAY(SYSDATE)
		-- and ptp.PERIOD_NAME = '8 2025 Calendar Month'
		-- AND TRUNC(ptp.PROCESS_SUB_DATE) BETWEEN TRUNC(bogn.start_date) AND TRUNC(bogn.end_date)
		and bogn.OBJECT_GROUP_ID = bogtl.OBJECT_GROUP_ID
		AND REPLACE (bogn.BASE_OBJECT_GROUP_NAME, 'Benifex_') = flv.lookup_code
		-- AND flv.lookup_code != bogn.BASE_OBJECT_GROUP_NAME(+)
	    and flv.lookup_type = 'BENIFEX_ ITEM_EXTERNAL_ID'
		AND (
        -- Rule 1: ACTIVE EMPLOYEES
        -- Always fetch current month data for active employees
        ppos.ACTUAL_TERMINATION_DATE IS NULL
        OR
        -- Rule 2: TERMINATED IN CURRENT PROCESSING MONTH
        -- If terminated this month, fetch current month data
        (ppos.ACTUAL_TERMINATION_DATE IS NOT NULL
         AND TRUNC(ppos.ACTUAL_TERMINATION_DATE, 'MM') = TRUNC(ptp.START_DATE, 'MM'))
        -- OR
        -- Rule 3: TERMINATED IN PREVIOUS MONTHS
        -- If terminated earlier, only fetch if element started on or before 
        -- one month from termination date
        -- (ppos.ACTUAL_TERMINATION_DATE IS NOT NULL
         -- AND TRUNC(ppos.ACTUAL_TERMINATION_DATE, 'MM') < TRUNC(ptp.START_DATE, 'MM')
         -- AND peef.effective_start_date <= ADD_MONTHS(TRUNC(ppos.ACTUAL_TERMINATION_DATE), 1))
    )
		-- and papf.person_number = '328'
		
UNION ALL

SELECT 
    papf.person_number "EmployeeNumber",
    flv.DESCRIPTION "CategoryKey",
    flv.lookup_code "ItemExternalID",
    flv.MEANING "ItemName",
    bogtl.DESCRIPTION "Type",
    '0' "amount"
FROM  
    per_all_people_f papf,
    per_all_assignments_m paaf,
    fnd_lookup_values flv,
    PAY_OBJECT_GROUPS bogn,
    PAY_OBJECT_GROUPS_TL bogtl
WHERE 1=1
    AND papf.person_id = paaf.person_id
    AND TRUNC(SYSDATE) BETWEEN TRUNC(paaf.effective_start_date) AND TRUNC(paaf.effective_end_date)
    AND paaf.primary_flag = 'Y'
    AND paaf.EFFECTIVE_LATEST_CHANGE = 'Y'
    AND flv.lookup_type = 'BENIFEX_ ITEM_EXTERNAL_ID'
    AND flv.LANGUAGE = USERENV('LANG')
    AND flv.source_lang = USERENV('LANG')
    -- Join to get the Type for all possible lookup codes
    AND flv.lookup_code = REPLACE(bogn.BASE_OBJECT_GROUP_NAME, 'Benifex_')
    AND bogn.OBJECT_GROUP_ID = bogtl.OBJECT_GROUP_ID
    AND bogtl.LANGUAGE = USERENV('LANG')
    AND bogtl.source_lang = USERENV('LANG')
    -- AND papf.person_number = '328'
    -- Exclude lookup codes that match any element group for this employee IN THE CURRENT PERIOD
    AND NOT EXISTS (
        SELECT 1
        FROM pay_payroll_assignments ppact2,
             pay_payroll_rel_actions ppra2,
             pay_payroll_actions ppa2,
             pay_time_periods ptp2,
             pay_all_payrolls_f paf2,
             pay_run_results prr2,
             pay_element_types_f petf2,
             PAY_OBJECT_GROUP_AMENDS pga2,
             PAY_OBJECT_GROUPS bogn2
        WHERE 1=1
            -- Link to same assignment
            AND paaf.assignment_id = ppact2.hr_assignment_id
            AND TRUNC(ptp2.PROCESS_SUB_DATE) BETWEEN TRUNC(SYSDATE, 'MM') AND LAST_DAY(SYSDATE)
            AND TRUNC(ptp2.PROCESS_SUB_DATE) BETWEEN TRUNC(ppact2.start_date) AND TRUNC(ppact2.end_date)
            AND ppact2.payroll_relationship_id = ppra2.payroll_relationship_id
            AND ppra2.payroll_action_id = ppa2.payroll_action_id
            AND ptp2.payroll_id = ppa2.payroll_id
            AND ptp2.time_period_id = ppa2.earn_time_period_id
            AND ptp2.period_category = 'E'
            AND paf2.payroll_id = ppa2.payroll_id
            AND TRUNC(ptp2.PROCESS_SUB_DATE) BETWEEN TRUNC(paf2.effective_start_date) AND TRUNC(paf2.effective_end_date)
            AND NVL(prr2.payroll_assignment_id, ppact2.payroll_assignment_id) = ppact2.payroll_assignment_id
            AND NVL(prr2.payroll_term_id, ppact2.payroll_term_id) = ppact2.payroll_term_id
            AND prr2.payroll_rel_action_id = ppra2.payroll_rel_action_id
            AND prr2.element_type_id = petf2.element_type_id
            AND TRUNC(ptp2.PROCESS_SUB_DATE) BETWEEN TRUNC(petf2.effective_start_date) AND TRUNC(petf2.effective_end_date)
            AND petf2.element_type_id = pga2.OBJECT_ID
            AND pga2.OBJECT_GROUP_ID = bogn2.OBJECT_GROUP_ID
            -- THIS IS THE KEY: Match the outer bogn with inner bogn2 to exclude matched groups
            AND bogn.OBJECT_GROUP_ID = bogn2.OBJECT_GROUP_ID
    )
	)
WHERE 1=1
GROUP BY "EmployeeNumber", "CategoryKey", "ItemExternalID", "ItemName", "Type"
order by "EmployeeNumber"