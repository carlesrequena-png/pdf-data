WITH
    transactions AS (        
        select 
            m.event_date as date,
            m.event_type,
            m.subscription_id,
            m.event_subtype,
            m.recurrence_cycle, 
            case 
                when coalesce(amplitude.ip_country, m.card_address_country, 'UNKNOWN') = 'UK' then 'GB'
                else coalesce(amplitude.ip_country, m.card_address_country, 'UNKNOWN')
            end as ip_country,
            m.gross_amount,
            m.payment_method_type,
            case 
                when m.merchant_id in ('acct_1TYnL9Ir47dcqvAx', 'acct_1TiU6PEdo9L76pmz') then 'Cosmic' 
                when m.merchant_id in ('acct_1SD2VNCVUJnyBfx6', 'acct_1TQoWFClqJv8asWw', 'acct_1QSfJrEeDNlVSPsk') then 'Merged'
                when m.merchant_id in ('acct_1TN7CJCpi1ShflFN', 'acct_1TQoq8CbB8Drwc9S') then 'Pdfhint' 
                else 'NULL'
            end as site
        from gold.dm_web.money_movements m
        inner join bronze.stripe.customers c
            on c.id = m.customer_id and c.email not like '%leadtech%'
        --Country aquisition using Amplitude
        left join (    
            with
                country_mapping AS (
                    select 
                        LOWER(TRIM(c.country_name)) as c_name, 
                        CASE 
                            WHEN MAX(c.country_iso_2) = 'UK' OR MIN(c.country_iso_2) = 'UK' THEN 'GB'
                            ELSE MAX(c.country_iso_2)
                        END as iso
                    from silver.dicts.countries c
                    GROUP by 1
                ),
                amplitude_adquisition as (
                select 
                        event_properties:balance_transaction_source_id::string AS balance_transaction_source_id,
                        case 
                            when coalesce(upper(trim(coalesce(m.iso, a.country))), 'UNKNOWN') = 'UK' then 'GB'
                            else coalesce(upper(trim(coalesce(m.iso, a.country))), 'UNKNOWN')
                        end as ip_country
                    from silver.amplitude.events a
                    left join country_mapping m 
                        on lower(trim(a.country)) = m.c_name
                    where 
                        a.project_id in ('pdf-web', 'pdf_editor','pdf_cosmic-web') 
                        and a.environment = 'prod'
                        and event_time::date >= '2026-01-01' 
                        and event_type = 'initial_purchase_event'
                )
                    select 
                            ip_country,
                            balance_transaction_source_id
                        from amplitude_adquisition e
                ) amplitude
                on m.charge_id = amplitude.balance_transaction_source_id
        where m.merchant_id in ('acct_1SD2VNCVUJnyBfx6','acct_1TQoWFClqJv8asWw','acct_1QSfJrEeDNlVSPsk','acct_1TN7CJCpi1ShflFN','acct_1TQoq8CbB8Drwc9S','acct_1TYnL9Ir47dcqvAx','acct_1TiU6PEdo9L76pmz')
        and m.status = 'succeeded'
        and m.event_date >= '2026-01-01'
    ),
    ltv_projections AS (
        SELECT 'US' AS Country, 29.95 AS Price, 3.57 AS LT_36m
        UNION ALL
        SELECT 'US' AS Country, 39.95 AS Price, 3.46 AS LT_36m
        UNION ALL
        SELECT 'US' AS Country, 49.95 AS Price, 2.92 AS LT_36m
        UNION ALL
        SELECT 'AU' AS Country, 29.95 AS Price, 4.33 AS LT_36m
        UNION ALL
        SELECT 'AU' AS Country, 39.95 AS Price, 3.94 AS LT_36m
        UNION ALL
        SELECT 'AU' AS Country, 49.95 AS Price, 3.37 AS LT_36m
        UNION ALL
        SELECT 'FR' AS Country, 29.95 AS Price, 3.00 AS LT_36m
        UNION ALL
        SELECT 'FR' AS Country, 39.95 AS Price, 3.23 AS LT_36m
        UNION ALL
        SELECT 'FR' AS Country, 49.95 AS Price, 3.45 AS LT_36m
        UNION ALL
        SELECT 'GB' AS Country, 29.95 AS Price, 2.57 AS LT_36m
        UNION ALL
        SELECT 'GB' AS Country, 39.95 AS Price, 2.64 AS LT_36m
        UNION ALL
        SELECT 'GB' AS Country, 49.95 AS Price, 2.05 AS LT_36m
        UNION ALL
        SELECT 'CA' AS Country, 29.95 AS Price, 3.74 AS LT_36m
        UNION ALL
        SELECT 'CA' AS Country, 39.95 AS Price, 3.54 AS LT_36m
        UNION ALL
        SELECT 'CA' AS Country, 49.95 AS Price, 3.59 AS LT_36m
    ),
    sales as (
        select
            SUM(case when t.event_subtype = 'initial_purchase' then 1 else 0 end) as sales,
            from_utc_timestamp(date, 'Europe/Madrid')::date as date,
            site,
            coalesce(upper(trim(ip_country)), 'UNKNOWN') as ip_country,
            CASE
                -- US
                WHEN ip_country = 'US' AND date BETWEEN '2025-10-01' AND '2025-11-30' THEN 82.78
                WHEN ip_country = 'US' AND date BETWEEN '2026-01-08' AND '2026-03-24' THEN 100.90
                WHEN ip_country = 'US' AND date > '2026-03-26' THEN 85.94 --updated 24-07-2026
                -- GB
                WHEN ip_country = 'GB' AND date BETWEEN '2025-10-01' AND '2025-11-30' THEN 80.47
                WHEN ip_country = 'GB' AND date BETWEEN '2026-01-08' AND '2026-03-24' THEN 89.82
                WHEN ip_country = 'GB' AND date > '2026-03-26' THEN 63.70 --updated 24-07-2026
                -- FR
                WHEN ip_country = 'FR' AND date BETWEEN '2026-01-08' AND '2026-03-24' THEN 68.33
                WHEN ip_country = 'FR' AND date > '2026-03-26' THEN 124.33 --updated 24-07-2026
                -- CA
                WHEN ip_country = 'CA' AND date BETWEEN '2026-01-08' AND '2026-03-24' THEN 84.65
                WHEN ip_country = 'CA' AND date > '2026-03-26' THEN 82.55 --updated 24-07-2026
                -- AU
                WHEN ip_country = 'AU' AND date BETWEEN '2026-01-08' AND '2026-03-24' THEN 90.06
                WHEN ip_country = 'AU' AND date > '2026-03-26'  THEN 74.43 --updated 24-07-2026
                -- Others
                WHEN ip_country = 'ES' THEN 101.60
                WHEN ip_country = 'DE' THEN 115.02
                WHEN ip_country = 'MX' THEN 97.45
                WHEN ip_country = 'IT' THEN 88.83
                WHEN ip_country = 'NL' THEN 76.70
                WHEN ip_country = 'BR' THEN 64.88
                WHEN ip_country = 'PL' THEN 108.31
                WHEN ip_country = 'SA' THEN 89.47
                WHEN ip_country = 'PH' THEN 45.72
                WHEN ip_country = 'IN' THEN 19.22
                ELSE 92.24
            END as ltv,
                sum(t.gross_amount) as user_revenue,
                SUM(case when t.event_type = 'refund' then 1 else 0 end) as refunds,
                COALESCE(SUM(CASE WHEN t.event_type = 'refund' THEN t.gross_amount ELSE 0 END), 0)*-1.00 AS amount_refunds
        from transactions t
        group by 2, 3, 4, 5    
    ),
    sem_spend as (
		select 
			date,
			coalesce(upper(trim(case when geo = 'UK' then 'GB' else geo end)), 'UNKNOWN') as ip_country, 
            'Merged' as site, 
			round(sum(costs), 2) as spend 
        from silver.pdf.marketing_spends
        where date >= '2026-01-01' 
        group by 1, 2, 3
    UNION
        select
           ms.date,
           coalesce(case when geo = 'UK' then 'GB' else geo end, 'UNKNOWN') as ip_country,
           'Cosmic' as site,
           sum(ms.costs) as spend
         from silver.web.marketing_spends ms
         where
           project_id = 'cosmic-pdf-web'
         group by
           1, 2, 3
    ),
    country_mapping AS (
		select 
			LOWER(TRIM(c.country_name)) as c_name, 
			CASE 
                WHEN MAX(c.country_iso_2) = 'UK' OR MIN(c.country_iso_2) = 'UK' THEN 'GB'
                ELSE MAX(c.country_iso_2)
            END as iso
		from silver.dicts.countries c
        group by 1
	),
    amplitude_merged as (
    select 
			count(distinct if(event_type = 'landing_page_viewed', amplitude_id, null)) as landing_page_viewers,
			count(distinct if(event_type = 'upload_document', amplitude_id, null)) as upload_document_users,
			count(distinct if(event_type = 'sign_up', amplitude_id, null)) as usign_ups,
			count(distinct if(event_type = 'payment_page_viewed', amplitude_id, null)) as payment_page_viewers,
			event_time::date as date,
            'Merged' as site,
			coalesce(upper(trim(coalesce(m.iso, a.country))), 'UNKNOWN') as ip_country
		from silver.amplitude.events a
		left join country_mapping m 
            on lower(trim(a.country)) = m.c_name
		where 
			a.project_id in ('pdf-web', 'pdf_editor') 
			and a.environment = 'prod'
			and event_time::date >= '2026-01-01' 
		group by date, ip_country
    ),
    amplitude_cosmic as (
        with
            events as (
                select 
	            	event_time::date as date,
	            	event_properties:page_name::string AS page_name, 
	            	amplitude_id, 
	            	event_type,
	            	coalesce(upper(trim(coalesce(m.iso, a.country))), 'UNKNOWN') as ip_country
	            from silver.amplitude.events a
	            left join country_mapping m 
                    on lower(trim(a.country)) = m.c_name
	            where 
	            	a.project_id = ('pdf_cosmic-web') 
	            	and a.environment = 'prod'
	            	and event_time::date >= '2026-01-01' 
	            	and event_type in ('view_page', 'begin_checkout','click','view')
            )
        select 
		    	count(distinct if(event_type = 'view_page' and page_name ='tool_page', amplitude_id, null)) as landing_page_viewers,
		    	date,
		    	ip_country,
                'Cosmic' as site
		    from events e
		    group by date, ip_country
    ),
    amplitude as (
        select 
            landing_page_viewers,
            date,
            ip_country,
            site
        from amplitude_merged
        UNION
        select 
            landing_page_viewers,
            date,
            ip_country,
            site
        from amplitude_cosmic
    ),
	master_dim as (
		select 
			date, 
			ip_country,
            site
		from sem_spend
			union 
		select 
			date, 
			ip_country,
            site 
		from sales
			union 
		select 
			date, 
			ip_country,
            site 
		from amplitude
    ),
    payback as (
        WITH
            sales_cohort as (
                select 
                    t.subscription_id,
                    t.date as cohort_date,
                    t.ip_country,
                    site
                from transactions t
                where event_subtype = 'initial_purchase'
            ),
            transactions_ranked as (
                select
					sc.subscription_id,
                    sc.cohort_date,
                    sc.ip_country,
                    sc.site,
                    t.event_subtype,
                    t.event_type,
                    t.gross_amount,
                    t.date,
                    row_number() over (
                        partition by sc.subscription_id, t.event_type 
                        order by t.date
                    ) as tx_rank,
					sum(case when t.event_type in ('charge') then 1 else 0 end) over (partition by sc.subscription_id) as sub_charges,
                    sum(case when t.event_type in ('refund') then 1 else 0 end) over (partition by sc.subscription_id) as sub_refunds
                from sales_cohort sc
                left join transactions t
                    ON sc.subscription_id = t.subscription_id
				)
            select
        			cohort_date,
        			ip_country,
                    site,
        			sum(sub_charges) as charges, 
        			sum(sub_refunds) as refunds,
                    SUM(gross_amount) AS real_revenue,
        			SUM(CASE WHEN  tx_rank <= 3 THEN gross_amount ELSE 0 END) AS real_revenue_37d,
        			count(distinct case when (sub_charges - sub_refunds) > 1 then subscription_id end) as first_renewals
        	from transactions_ranked
        	group by 1, 2, 3
		)
select 
    m.date,
    m.ip_country,
    m.site,
    coalesce(s.spend, 0) as spend,
    coalesce(sa.sales, 0) as sales,
	coalesce(sa.ltv, 0) as ltv,
    coalesce(sa.user_revenue, 0) as user_revenue,    
    --coalesce(db.refunds, 0) as refunds,
    coalesce(sa.amount_refunds, 0) as amount_refunds,
    coalesce(a.landing_page_viewers, 0) as landing_page_viewers,
	coalesce(pb.real_revenue, 0) as real_revenue,
	coalesce(pb.real_revenue_37d, 0) as real_revenue_37d,
	coalesce(pb.charges, 0) as charges,
	coalesce(pb.refunds, 0) as refunds,
	coalesce(pb.first_renewals, 0) as first_renewals
from master_dim m
left join sem_spend s on m.date = s.date and m.ip_country = s.ip_country and m.site = s.site
left join sales sa on m.date = sa.date and m.ip_country = sa.ip_country and m.site = sa.site
left join amplitude a on m.date = a.date and m.ip_country = a.ip_country and m.site = a.site
left join payback pb on m.date = pb.cohort_date and m.ip_country = pb.ip_country and m.site = pb.site
where m.site in ('Merged','Cosmic') and m.date <= current_date() - INTERVAL 1 DAY