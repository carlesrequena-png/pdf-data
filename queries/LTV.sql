SELECT				
	s.id AS subscription_id,				
	SUM(CASE WHEN t.transaction_type = 0 THEN 1 ELSE 0 END) - coalesce((SUM(CASE WHEN t.transaction_type = 1 THEN 1 ELSE 0 END)),0) AS tenure,				
	SUM(CASE WHEN t.transaction_type = 0 THEN t.amount ELSE 0 END) - coalesce((SUM(CASE WHEN t.transaction_type = 1 THEN t.amount ELSE 0 END)),0) AS user_revenue,				
	MIN(t.payment_date) AS initial_payment_date,				
	TO_CHAR(MIN(t.payment_date),'YYYY-MM') AS cohort,				
	MAX(t.payment_date) AS latest_payment_date,				
	CASE WHEN (s.unsubscribed_date IS not null or s.subscription_status = 'Unsuscribed') THEN 'churned' ELSE 'active' END AS status,
	CASE WHEN utm_term like '%free%' then 'free' else 'other' end as keyword
FROM subscriptions s				
LEFT JOIN subscription_types st				
    ON st.id = s.subscription_type_id				
LEFT JOIN prices p				
    ON p.id = st.price_id				
LEFT JOIN transactions t				
    ON t.subscription_id = s.id				
AND t.transaction_status = 1
left join utms u 
    on u.id = t.utms_id 
JOIN customers c				
    ON c.id = s.customer_id_np				
    and c.email not like '%leadtech%'				
where s.subscription_status != 'Registered'		
    and s.created_at::date > '2025-01-01'
    and u.utm_term is not null
GROUP BY				
    s.id,				
    s.unsubscribed_date,
    keyword
having				
    SUM(CASE WHEN t.transaction_type = 0 THEN 1 ELSE 0 END) - coalesce((SUM(CASE WHEN t.transaction_type = 1 THEN 1 ELSE 0 END)),0) > 0				
    and s.id not in ('25', '26','27','28')		