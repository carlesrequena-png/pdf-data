with 
	country_mapping AS (
		select 
			c.country_name as c_name, 
			c.country_iso_2 as iso
		from silver.dicts.countries c
	),
	sem_spend as (
		select 
			date,
			geo as ip_country,  
			round(sum(costs), 2) as spend -- Sumamos todo el gasto de ese día/país
    from silver.pdf.marketing_spends
    where date >= '2026-01-01' 
    group by 1, 2),
	db as (
		select  
				SUM(case when t.transaction_type = 0 and p.amount_trial = t.amount then 1 else 0 end) as sales,
				t.created_at::date as date,
				c.ip_country,
				concat(extract(year FROM t.created_at),'-W',extract(week FROM t.created_at)) as week,
				(SUM(CASE WHEN t.transaction_type = 0 THEN t.amount ELSE 0 END) - COALESCE(SUM(CASE WHEN t.transaction_type = 1 THEN t.amount ELSE 0 END), 0))::BIGINT AS user_revenue,
				sum(case when t.transaction_type = 1 then 1 else 0 end) as refunds,
				COALESCE(SUM(CASE WHEN t.transaction_type = 1 THEN t.amount ELSE 0 END), 0)::BIGINT AS amount_refunds
			from bronze.pdf.customers c
			left join bronze.pdf.transactions t 
				on t.customer_id = c.id
			left join bronze.pdf.http_user_agents hua 
				on hua.id = t.user_agent_id 
			left join bronze.pdf.invoices_sii is2 
				on is2.transaction_id = t.id
			left join bronze.pdf.subscriptions s 
				on s.id = t.subscription_id 
			left join bronze.pdf.subscription_types st
				on st.id = s.subscription_type_id 
			left join bronze.pdf.prices p
				on p.id = st.price_id
			where 
				t.created_at::date >= '2026-01-01'
				and email not like '%leadtech%'
				and t.transaction_status = 1
				and is2.invoice_number is not null
			group by 2,3,4),
	amplitude as (
		select 
			count(distinct if(event_type = 'landing_page_viewed', amplitude_id, null)) as landing_page_viewers,
			count(distinct if(event_type = 'upload_document', amplitude_id, null)) as upload_document_users,
			count(distinct if(event_type = 'sign_up', amplitude_id, null)) as usign_ups,
			count(distinct if(event_type = 'payment_page_viewed', amplitude_id, null)) as payment_page_viewers,
			event_time::date as date,
			coalesce(m.iso, a.country) as ip_country
		from silver.amplitude.events a
		left join country_mapping m 
            on lower(trim(a.country)) = lower(trim(m.c_name))
		where a.project_id in ('pdf-web', 'pdf_editor') and a.environment = 'prod'
		group by date, ip_country
		),
	master_dim as (
    select date, ip_country from sem_spend
    union 
    select date, ip_country from db
    union 
    select date, ip_country from amplitude
)
select 
    m.date,
    m.ip_country,
    coalesce(s.spend, 0) as spend,
    coalesce(db.sales, 0) as sales,
    coalesce(db.user_revenue, 0) as user_revenue,    
    coalesce(db.refunds, 0) as refunds,
    coalesce(db.amount_refunds, 0) as amount_refunds,
    coalesce(a.landing_page_viewers, 0) as landing_page_viewers,
    coalesce(a.payment_page_viewers, 0) as payment_page_viewers,
    coalesce(a.upload_document_users, 0) as upload_document_users, 
    coalesce(a.usign_ups, 0) as usign_ups
from master_dim m
left join sem_spend s on m.date = s.date and m.ip_country = s.ip_country
left join db on m.date = db.date and m.ip_country = db.ip_country
left join amplitude a on m.date = a.date and m.ip_country = a.ip_country
order by spend DESC