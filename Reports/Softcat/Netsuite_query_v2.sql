SELECT 
    "External_Id",
    "Subsidiary",
    "Date",
    "Currency",
    "Account",
    "Account_Internal_ID",
    "Sales_Organisation",
    "Item_Class",
    "Item_class_Internal_id",
    "Location",
    "Business_Line",
    TO_CHAR(SUM("Debit"), 'FM9999999990.00') AS "Debit",
    TO_CHAR(SUM("Credit"), 'FM9999999990.00') AS "Credit",
    "Header_Memo",
    "Line_Memo"
FROM (
    -------------------------------------------------------
    -- 1️⃣ BALANCE SECTION (Dynamic using FND_LOOKUP_VALUES)
    -------------------------------------------------------
    SELECT /*+ MATERIALIZE */
    ' ' AS "Sales_Organisation",
    ' ' AS "Item_Class",
    ' ' AS "Item_class_Internal_id",
    ' ' AS "Location",
    ' ' AS "Business_Line",
    TO_CHAR(ADD_MONTHS(ptp.end_date, -7), 'MMYYYY') || '99' AS "External_Id",
    '2' AS "Subsidiary",
    TO_CHAR(ptp.end_date, 'DD/MM/YYYY') AS "Date",
    'GBP' AS "Currency",
    SUBSTR(flv.description, 1, INSTR(flv.description, '|') - 1) AS "Account",
    SUBSTR(flv.description, INSTR(flv.description, '|') + 1) AS "Account_Internal_ID",
    flv.meaning AS "Header_Memo",
    TO_CHAR(ptp.end_date, 'Mon', 'NLS_DATE_LANGUAGE=ENGLISH') || ' ' ||
    TO_CHAR(ptp.end_date, 'YY') || ' UK Payroll' AS "Line_Memo",
    CASE 
        WHEN (SIGN(net_pay) = 1 AND flv.tag = '+')
          OR (SIGN(net_pay) = -1 AND flv.tag = '-')
        THEN ABS(net_pay)
    END AS "Debit",
    CASE 
        WHEN (SIGN(net_pay) = 1 AND flv.tag = '-')
          OR (SIGN(net_pay) = -1 AND flv.tag = '+')
        THEN ABS(net_pay)
    END AS "Credit"
FROM
(
    SELECT 
        pra.payroll_relationship_id,
        ptp.time_period_id,
        ptp.end_date,
        flv.meaning AS balance_name,
        (
            SELECT  
                TRIM(TO_CHAR(SUM(BAL.BALANCE_VALUE), '999999990.00'))
            FROM 
                PAY_BALANCE_TYPES_VL B,
                PAY_DIMENSION_USAGES_VL D,
                TABLE (
                    pay_balance_view_pkg.get_balance_dimensions
                    (
                        B.BALANCE_TYPE_ID,
                        pra.PAYROLL_REL_ACTION_ID,
                        NULL,
                        paam.assignment_id
                    )
                ) BAL
            WHERE 
                B.BALANCE_NAME = flv.meaning
                AND D.database_item_suffix IN ('_REL_PTD')
                AND D.balance_dimension_id = BAL.balance_dimension_id
                AND D.LEGISLATION_CODE = 'GB'
                AND BAL.BALANCE_VALUE <> 0
				
				
        ) AS net_pay
    FROM 
        fusion.pay_pay_relationships_dn rel,
        fusion.per_all_people_f per,
        fusion.pay_payroll_actions ppa,
        fusion.pay_payroll_rel_actions pra,
        pay_all_payrolls_f py,
        pay_time_periods ptp,
        per_all_assignments_m paam,
		 fnd_lookup_values flv
    WHERE 1=1
        AND PTP.PERIOD_CATEGORY = 'E'
        AND ptp.payroll_id = py.payroll_id 
        AND trunc(sysdate) BETWEEN per.effective_start_date AND per.effective_end_date
        AND trunc(sysdate) BETWEEN py.effective_start_date AND py.effective_end_date
        AND pra.payroll_relationship_id = rel.payroll_relationship_id
        AND rel.person_id = per.person_id
        AND ppa.payroll_action_id = pra.payroll_action_id
        AND ppa.earn_time_period_id = ptp.time_period_id
        AND paam.person_id = per.person_id
        AND paam.assignment_type IN ('E')
        AND paam.effective_latest_change = 'Y'
        AND paam.primary_flag = 'Y'
        AND paam.assignment_status_type = 'ACTIVE'
        AND paam.legislation_code = 'GB'
        -- AND trunc(ptp.start_date) BETWEEN paam.effective_start_date AND paam.effective_end_date
						AND (
    TRUNC(ptp.start_date) BETWEEN paam.effective_start_date AND paam.effective_end_date
    OR TRUNC(ptp.end_date) BETWEEN paam.effective_start_date AND paam.effective_end_date
)
        AND pra.action_status = 'C'
        -- AND ptp.period_name IN (:p_period_name)
		AND ptp.period_name IN (:p_period_name)
            AND flv.lookup_type = 'NETSUITE_INTEGRATION'
            AND flv.lookup_code LIKE 'BAL_%'
        AND EXISTS (
            SELECT 1
            FROM pay_element_types_f pet,
                 pay_element_types_tl petl,
                 pay_ele_classifications pec,
                 per_all_people_f ppf,
                 pay_input_values_f piv,
                 pay_pay_relationships_dn pprd,
                 pay_payroll_rel_actions ppra,
                 pay_payroll_actions ppa2,
                 pay_time_periods ptp_inner,
                 pay_all_payrolls_f papf,
                 pay_run_results prr,
                 pay_run_result_values prrv
            WHERE 
                pet.element_type_id = piv.element_type_id
                AND pprd.person_id = ppf.person_id
                AND ptp_inner.time_period_id = ptp.time_period_id
                AND ppra.payroll_relationship_id = pprd.payroll_relationship_id
                AND ppa2.payroll_action_id = ppra.payroll_action_id
                AND ptp_inner.time_period_id = ppa2.earn_time_period_id
                AND ppa2.payroll_id = ptp_inner.payroll_id
                AND ptp_inner.payroll_id = papf.payroll_id
                AND prr.payroll_rel_action_id = ppra.payroll_rel_action_id
                AND prr.payroll_rel_action_id = pra.payroll_rel_action_id
                AND prr.element_type_id = pet.element_type_id
                AND prr.run_result_id = prrv.run_result_id
                AND prrv.input_value_id = piv.input_value_id
                AND UPPER(piv.base_name) = 'AMOUNT'
                AND pet.classification_id = pec.classification_id
                AND pet.element_type_id = petl.element_type_id
                AND petl.language = 'US'
                AND TRUNC(ptp_inner.end_date) BETWEEN ppf.effective_start_date AND ppf.effective_end_date
				
        )
) net_data,
fnd_lookup_values flv,
pay_time_periods ptp
WHERE 1=1
    AND flv.lookup_type = 'NETSUITE_INTEGRATION'
    AND flv.lookup_code LIKE 'BAL_%'
    AND flv.meaning = net_data.balance_name
    AND ptp.time_period_id = net_data.time_period_id
	
	
	


    UNION ALL

    -------------------------------------------------------
    -- 2️⃣ ELEMENTS SECTION
    -------------------------------------------------------
    SELECT /*+ MATERIALIZE */
        ' ' AS "Sales_Organisation",
        ' ' AS "Item_Class",
        ' ' AS "Item_class_Internal_id",
        ' ' AS "Location",
        ' ' AS "Business_Line",
        TO_CHAR(ADD_MONTHS(ptp.end_date, -7), 'MMYYYY') || '99' AS "External_Id",
        '2' AS "Subsidiary",
        TO_CHAR(ptp.end_date, 'DD/MM/YYYY') AS "Date",
        'GBP' AS "Currency",
        SUBSTR(flv.description, 1, INSTR(flv.description, '|') - 1) AS "Account",
        SUBSTR(flv.description, INSTR(flv.description, '|') + 1) AS "Account_Internal_ID",
        flv.meaning AS "Header_Memo",
        TO_CHAR(ptp.end_date, 'Mon', 'NLS_DATE_LANGUAGE=ENGLISH') || ' ' ||
        TO_CHAR(ptp.end_date, 'YY') || ' UK Payroll' AS "Line_Memo",
        CASE 
            WHEN (SIGN(prrv.result_value) = 1 AND flv.tag = '+')
              OR (SIGN(prrv.result_value) = -1 AND flv.tag = '-')
            THEN ABS(prrv.result_value)
        END AS "Debit",
        CASE 
            WHEN (SIGN(prrv.result_value) = 1 AND flv.tag = '-')
              OR (SIGN(prrv.result_value) = -1 AND flv.tag = '+')
            THEN ABS(prrv.result_value)
        END AS "Credit"
    FROM  
        per_all_people_f papf,
        per_all_assignments_m paaf,
        pay_payroll_assignments ppact,
        pay_time_periods ptp,
        pay_payroll_actions ppa,
        pay_all_payrolls_f paf,
        pay_payroll_rel_actions ppra,
        pay_element_types_f petf,
        pay_element_types_tl pett,
        pay_input_values_tl pivt,
        pay_input_values_f pivf,
        pay_ele_classifications_vl pecv,
        pay_run_results prr,
        pay_run_result_values prrv,
        fnd_lookup_values flv
    WHERE 1=1
        AND papf.person_id = paaf.person_id
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(papf.effective_start_date) AND TRUNC(papf.effective_end_date)
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(paaf.effective_start_date) AND TRUNC(paaf.effective_end_date)
        AND paaf.primary_flag = 'Y'
        AND paaf.effective_latest_change = 'Y'
        AND paaf.assignment_id = ppact.hr_assignment_id
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(ppact.start_date) AND TRUNC(ppact.end_date)
        AND ptp.payroll_id = ppa.payroll_id
        AND ptp.time_period_id = ppa.earn_time_period_id
        AND ppa.payroll_action_id = ppra.payroll_action_id
        AND paf.payroll_id = ppa.payroll_id
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(paf.effective_start_date) AND TRUNC(paf.effective_end_date)
        AND ppra.payroll_relationship_id = ppact.payroll_relationship_id
        AND ppra.retro_component_id IS NULL
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(petf.effective_start_date) AND TRUNC(petf.effective_end_date)
        AND pett.element_type_id = petf.element_type_id
        AND pett.language = Userenv('LANG')
        AND pivf.input_value_id = pivt.input_value_id
        AND pivt.language = Userenv('LANG')
        AND pivt.name IN ('Pay Value','Contribution Amount','Amount Deducted','Net Pay')
        AND TRUNC(ptp.process_sub_date) BETWEEN TRUNC(pivf.effective_start_date) AND TRUNC(pivf.effective_end_date)
        AND pivf.element_type_id = petf.element_type_id
        AND prrv.run_result_id = prr.run_result_id
        AND pivf.input_value_id = prrv.input_value_id
        AND prr.element_type_id = pett.element_type_id
        AND prr.payroll_rel_action_id = ppra.payroll_rel_action_id
        AND NVL(prr.payroll_assignment_id, ppact.payroll_assignment_id) = ppact.payroll_assignment_id
        AND NVL(prr.payroll_term_id, ppact.payroll_term_id) = ppact.payroll_term_id
        AND ptp.period_category = 'E'
        AND petf.classification_id = pecv.classification_id
        AND ptp.period_name IN (:p_period_name)
        AND flv.meaning = pett.element_name
        AND flv.lookup_type = 'NETSUITE_INTEGRATION'
        AND flv.lookup_code NOT LIKE 'BAL_%'
)
GROUP BY 
    "External_Id", "Subsidiary", "Date", "Currency", 
    "Account", "Account_Internal_ID", "Sales_Organisation",
    "Item_Class", "Item_class_Internal_id", "Location",
    "Business_Line", "Header_Memo", "Line_Memo"
	
	ORDER BY "Header_Memo"
