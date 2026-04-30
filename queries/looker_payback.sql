with
	initials as (
		select     		
		    s.id,
		    t.created_at::date as cohort_date,
		   	c.ip_country,
		   	p.amount as amount_recurrence,
		   	p.amount_trial
		FROM pdfeditor.customers c
        LEFT JOIN pdfeditor.transactions t ON t.customer_id = c.id
        LEFT JOIN pdfeditor.invoices_sii is2 ON is2.transaction_id = t.id
        LEFT JOIN pdfeditor.subscriptions s ON s.id = t.subscription_id 
        LEFT JOIN pdfeditor.subscription_types st ON st.id = s.subscription_type_id
        LEFT JOIN pdfeditor.prices p ON p.id = st.price_id
		where 
		 	t.created_at::DATE >= '2026-01-01' --cohort dates start 
			and email not like '%leadtech%'
			and t.transaction_status = 1
			and t.transaction_type = 0
			and t.amount <5
			and is2.invoice_number is not null
		),
		user_activity as (
		select 
			i.id,
			i.cohort_date,
			i.ip_country,
            i.amount_trial,
            i.amount_recurrence,
            --net revenue today
            (SUM(CASE WHEN t.transaction_type = 0 THEN t.amount ELSE 0 END) - COALESCE(SUM(CASE WHEN t.transaction_type = 1 THEN t.amount ELSE 0 END), 0))::NUMERIC(10,2) AS real_user_revenue,
            --net recurrences today
            SUM(CASE WHEN t.transaction_type = 0 AND t.amount > 5 THEN 1 ELSE 0 END) - COALESCE(SUM(CASE WHEN t.transaction_type = 1 AND t.amount > 5 THEN 1 ELSE 0 END), 0) AS recurrences
		from initials i
		LEFT JOIN pdfeditor.transactions t ON t.subscription_id = i.id
        LEFT JOIN pdfeditor.invoices_sii is2 ON is2.transaction_id = t.id
        LEFT JOIN pdfeditor.subscriptions s ON s.id = t.subscription_id 
        WHERE 
            t.transaction_status = 1
            AND is2.invoice_number IS NOT NULL
        GROUP BY 1, 2, 3, 4, 5
		),
		historical_ratios AS (
	        SELECT 
	            ip_country,
	            COUNT(id) AS sample_size,
	            (SUM(CASE WHEN recurrences > 0 THEN 1 ELSE 0 END) * 1.0 / COUNT(id)) AS r1, -- Probability to arrive to D7
	            (SUM(CASE WHEN recurrences > 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(id)) AS r2  -- Probability to arrive to D35
	        FROM user_activity
	        WHERE cohort_date <= CURRENT_DATE - INTERVAL '45 days'
	        GROUP BY 1
	        HAVING COUNT(id) > 50	
		)
		SELECT 
		    ua.cohort_date,
		    ua.ip_country,
		    COUNT(ua.id) AS new_sales,
		    -- Metric: Predictive revenue (Theorical)
		    ROUND(SUM(
		        ua.amount_trial + 
		        (ua.amount_recurrence * COALESCE(hr.r1, 0)) + 
		        (ua.amount_recurrence * COALESCE(hr.r2, 0))
		    )::NUMERIC, 2) AS predicted_d35_revenue,
		    -- Metric: Real Revenue D35
		    ROUND(SUM(
		        CASE WHEN ua.recurrences = 0 THEN ua.amount_trial
		             WHEN ua.recurrences = 1 THEN ua.amount_trial + ua.amount_recurrence
		             WHEN ua.recurrences >= 2 THEN ua.amount_trial + (2 * ua.amount_recurrence)
		             ELSE 0 END
		    )::NUMERIC, 2) AS real_d35_revenue,
		    -- ⭐ Hybrid Revenue (Amart D35 Revenue) ⭐
		    ROUND(SUM(
		        CASE 
		            WHEN CURRENT_DATE - ua.cohort_date > 37 THEN 
		                -- If is major than 37 days, we user real revenue
		                CASE WHEN ua.recurrences = 0 THEN ua.amount_trial
		                     WHEN ua.recurrences = 1 THEN ua.amount_trial + ua.amount_recurrence
		                     WHEN ua.recurrences >= 2 THEN ua.amount_trial + (2 * ua.amount_recurrence)
		                END
		            ELSE 
		                -- If not, we use predictive
		                ua.amount_trial + (ua.amount_recurrence * COALESCE(hr.r1, 0)) + (ua.amount_recurrence * COALESCE(hr.r2, 0))
		        END
		    )::NUMERIC, 2) AS smart_d35_revenue
		FROM user_activity ua
		LEFT JOIN historical_ratios hr ON hr.ip_country = ua.ip_country
		where ua.ip_country is not null
		GROUP BY 1, 2