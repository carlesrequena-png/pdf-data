select  
	    count(t.*) as sales,
	    t.created_at::date as date,
	    c.ip_country, 
	    concat(extract(year FROM t.created_at),'-W',extract(week FROM t.created_at)) as week,
	    CASE
		    WHEN ip_country = 'AU' THEN '98,88'
		    WHEN ip_country = 'ES' THEN '101,60'
		    WHEN ip_country = 'DE' THEN '115,02'
		    WHEN ip_country = 'CA' THEN '86,52'
		    WHEN ip_country = 'MX' THEN '97,45'
		    WHEN ip_country = 'US' THEN '101,60'
		    WHEN ip_country = 'IT' THEN '88,83'
		    WHEN ip_country = 'GB' THEN '86,98'
		    WHEN ip_country = 'FR' THEN '77,02'
		    WHEN ip_country = 'NL' THEN '76,70'
		    WHEN ip_country = 'BR' THEN '64,88'
		    WHEN ip_country = 'PL' THEN '108,31'
		    WHEN ip_country = 'SA' THEN '89,47'
		    WHEN ip_country = 'PH' THEN '45,72'
		    WHEN ip_country = 'IN' THEN '19,22'
		    ELSE '101,60'
		END AS ltv
	from customers c
	left join transactions t 
	on t.customer_id = c.id
	left join http_user_agents hua 
	on hua.id = t.user_agent_id 
	left join invoices_sii is2 
	on is2.transaction_id = t.id
	left join subscriptions s 
	on s.id = t.subscription_id 
	left join subscription_types st
	on st.id = s.subscription_type_id 
	where 
	t.created_at::date >= '2026-02-01'
	and email not like '%leadtech%'
	and t.transaction_status = 1
	and t.transaction_type = 0
	and t.amount <5
	and is2.invoice_number is not null
	group by 2,3,4,5