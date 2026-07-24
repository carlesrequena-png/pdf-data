with 
    sales_cohort as (
        select
            s.id,
            t.created_at::date as cohort_date,
            coalesce(c.ip_country,hua.ip_country_iso_code) as ip_country,
            CASE WHEN u.utm_term ilike ('%free%') or u.utm_term ilike ('%gratis%') or u.utm_term ilike ('%gratuit%')  then 'free' else 'other' end as keyword,
            hua.device,
            m.internal_mid_name,
            coalesce(t.apm_type, 'Null') as apm_type,
            er.rate
        FROM bronze.pdf.customers c
        LEFT JOIN bronze.pdf.transactions t
            ON t.customer_id = c.id
            and t.transaction_status = 1
            and t.transaction_type = 0
            and t.created_at::DATE >= '2026-01-01'
        LEFT JOIN bronze.pdf.utms u
            on u.id = t.utms_id
        LEFT JOIN silver.currencies.eur_exchange_rates er 
            on er.date = t.created_at::date and er.code = t.currency
        LEFT JOIN bronze.pdf.mids m
            on m.id = t.mid_id
        LEFT JOIN bronze.pdf.http_user_agents hua
            ON hua.id = t.user_agent_id
        INNER JOIN bronze.pdf.invoices_sii is2
            ON is2.transaction_id = t.id
        LEFT JOIN bronze.pdf.subscriptions s
            ON s.id = t.subscription_id
        LEFT JOIN bronze.pdf.subscription_types st
            ON st.id = s.subscription_type_id
        LEFT JOIN bronze.pdf.prices p
            ON p.id = st.price_id
        where
            c.email not like '%leadtech%'
            and p.amount_trial = t.amount
        ),
    transactions_ranked as (
        select
            sc.id as subscription_id,
            sc.cohort_date,
            sc.ip_country,
            sc.rate,
            sc.keyword,
            sc.internal_mid_name,
            sc.apm_type,
            sc.device,
            t.transaction_type,
            t.amount,
            t.created_at,
            row_number() over (
                partition by sc.id, t.transaction_type 
                order by t.created_at
            ) as tx_rank,
            -- Estas se quedan SOLO para usarse en el COUNT DISTINCT de abajo
            sum(case when t.transaction_type = 0 then 1 else 0 end) over (partition by sc.id) as sub_charges,
            sum(case when t.transaction_type = 1 then 1 else 0 end) over (partition by sc.id) as sub_refunds
        from sales_cohort sc
        left join bronze.pdf.transactions t
            ON sc.id = t.subscription_id
            and t.transaction_status = 1
        )
select
    cohort_date as date,
    ip_country,
    internal_mid_name,
    apm_type,
    device,
    keyword,
    count(distinct subscription_id) as sales, 
    sum(case when transaction_type = 0 then 1 else 0 end) as charges, 
    sum(case when transaction_type = 1 then 1 else 0 end) as refunds,
    (
        SUM(CASE WHEN transaction_type = 0 THEN amount ELSE 0 END / NULLIF(rate, 0)) 
        - COALESCE(SUM(CASE WHEN transaction_type = 1 THEN amount ELSE 0 END / NULLIF(rate, 0)), 0)
    )::NUMERIC(10, 2) AS real_revenue,
    (
        SUM(CASE WHEN transaction_type = 0 AND tx_rank <= 3 THEN amount ELSE 0 END / NULLIF(rate, 0)) 
        - COALESCE(SUM(CASE WHEN transaction_type = 1 AND created_at::date <= cohort_date + 37 THEN amount ELSE 0 END / NULLIF(rate, 0)), 0)
    )::NUMERIC(10, 2) AS real_revenue_37d,
    count(distinct case when (sub_charges - sub_refunds) > 1 then subscription_id end) as first_renewals
from transactions_ranked
group by 1, 2, 3, 4, 5, 6