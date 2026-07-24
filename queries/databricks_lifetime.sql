WITH
    transactions AS (        
        select 
            m.event_date as date,
            m.event_type,
            m.subscription_id,
            m.event_subtype,
            m.recurrence_cycle, 
            m.card_funding,
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
        where merchant_id in ('acct_1SD2VNCVUJnyBfx6','acct_1TQoWFClqJv8asWw','acct_1QSfJrEeDNlVSPsk','acct_1TN7CJCpi1ShflFN','acct_1TQoq8CbB8Drwc9S','acct_1TYnL9Ir47dcqvAx','acct_1TiU6PEdo9L76pmz')
        and status = 'succeeded'
        and event_date >= '2026-01-01'
    ),
    sales_cohort as ( --subscription_id needs to be unique
        select 
            t.subscription_id,
            min(t.date) as cohort_date,
            max(t.ip_country) as ip_country,
            max(t.site) as site, 
            max(t.card_funding) as card_funding
        from transactions t
        where event_subtype = 'initial_purchase' and event_type = 'charge'
        group by t.subscription_id
    ),
    subscription_net as (
        select
            sc.subscription_id,
            sc.cohort_date,
            sc.ip_country,
            sc.site,
            sc.card_funding,
            sum(t.gross_amount) as net_revenue,
            (
                sum(case when t.event_type = 'charge' then 1 else 0 end) - 
                sum(case when t.event_type = 'refund' then 1 else 0 end) - 1
            ) as net_cycles
        from sales_cohort sc
        left join transactions t 
            on sc.subscription_id = t.subscription_id
        group by 
            sc.subscription_id, 
            sc.cohort_date, 
            sc.ip_country,
            sc.site, 
            sc.card_funding
    ),
    cohort_recurrences as (
        select
            cohort_date,
            date_trunc('month', cohort_date)::date as cohort_month,
            ip_country,
            card_funding,
            site,
            count(distinct subscription_id) as cohort_size,
            sum(case when net_cycles >= 0 then 1 else 0 end) as r0,
            sum(case when net_cycles >= 0 then net_revenue else 0 end) as r0_net_rev, 
            -- Recurrence 1
            sum(case when net_cycles >= 1 then 1 else 0 end) as r1,
            sum(case when net_cycles >= 1 then net_revenue else 0 end) as r1_net_rev,
            -- Recurrence 2
            sum(case when net_cycles >= 2 then 1 else 0 end) as r2,
            sum(case when net_cycles >= 2 then net_revenue else 0 end) as r2_net_rev,
            -- Recurrence 3
            sum(case when net_cycles >= 3 then 1 else 0 end) as r3,
            sum(case when net_cycles >= 3 then net_revenue else 0 end) as r3_net_rev,
            -- Recurrence 4
            sum(case when net_cycles >= 4 then 1 else 0 end) as r4,
            sum(case when net_cycles >= 4 then net_revenue else 0 end) as r4_net_rev,
            -- Recurrence 5
            sum(case when net_cycles >= 5 then 1 else 0 end) as r5,
            sum(case when net_cycles >= 5 then net_revenue else 0 end) as r5_net_rev,
            -- Recurrence 6
            sum(case when net_cycles >= 6 then 1 else 0 end) as r6,
            sum(case when net_cycles >= 6 then net_revenue else 0 end) as r6_net_rev,
            -- Recurrence 7
            sum(case when net_cycles >= 7 then 1 else 0 end) as r7,
            sum(case when net_cycles >= 7 then net_revenue else 0 end) as r7_net_rev,
            -- Recurrence 8
            sum(case when net_cycles >= 8 then 1 else 0 end) as r8,
            sum(case when net_cycles >= 8 then net_revenue else 0 end) as r8_net_rev,
            -- Recurrence 9
            sum(case when net_cycles >= 9 then 1 else 0 end) as r9,
            sum(case when net_cycles >= 9 then net_revenue else 0 end) as r9_net_rev,
            -- Recurrence 10
            sum(case when net_cycles >= 10 then 1 else 0 end) as r10,
            sum(case when net_cycles >= 10 then net_revenue else 0 end) as r10_net_rev,
            -- Recurrence 11
            sum(case when net_cycles >= 11 then 1 else 0 end) as r11,
            sum(case when net_cycles >= 11 then net_revenue else 0 end) as r11_net_rev, 
            -- Recurrence 12
            sum(case when net_cycles >= 12 then 1 else 0 end) as r12,
            sum(case when net_cycles >= 12 then net_revenue else 0 end) as r12_net_rev
        from subscription_net
        group by 1, 2, 3, 4, 5
    ),
    sem_spend_monthly as (
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
            date,
            coalesce(case when geo = 'UK' then 'GB' else geo end, 'UNKNOWN') as ip_country,
            'Cosmic' as site,
            sum(ms.costs) as spend
         from silver.web.marketing_spends ms
         where project_id = 'cosmic-pdf-web' and ms.date >= '2026-01-01'
         group by 1, 2, 3
    )
select 
    cr.cohort_month,
    cr.cohort_date,
    cr.ip_country,
    cr.site,
    cr.cohort_size as initial_sales,
    cr.card_funding,
    coalesce(s.spend, 0) as spend,
    -- Ingresos netos totales por recurrencia
    round(cr.r0_net_rev, 2) as rev_r0,
    round(cr.r0, 2) as r0,
    round(cr.r1_net_rev, 2) as rev_r1,
    round(cr.r1, 2) as r1,
    round(cr.r2_net_rev, 2) as rev_r2,
    round(cr.r2, 2) as r2,
    round(cr.r3_net_rev, 2) as rev_r3,
    round(cr.r3, 2) as r3,
    round(cr.r4_net_rev, 2) as rev_r4,
    round(cr.r4, 2) as r4,
    round(cr.r5_net_rev, 2) as rev_r5,
    round(cr.r5, 2) as r5,
    round(cr.r6_net_rev, 2) as rev_r6,
    round(cr.r6, 6) as r6,
    round(cr.r7_net_rev, 2) as rev_r7,
    round(cr.r7, 2) as r7,
    round(cr.r8_net_rev, 2) as rev_r8,
    round(cr.r8, 2) as r8,
    round(cr.r9_net_rev, 2) as rev_r9,
    round(cr.r9, 2) as r9,
    round(cr.r10_net_rev, 2) as rev_r10,
    round(cr.r10, 2) as r10,
    round(cr.r11_net_rev, 2) as rev_r11,
    round(cr.r11, 2) as r11,
    round(cr.r12_net_rev, 2) as rev_r12,
    round(cr.r12, 2) as r12,
    -- Real LTV
    round((cr.r0_net_rev) / nullif(cr.cohort_size, 0), 2) as ltv_r0,
    round((cr.r0_net_rev + cr.r1_net_rev) / nullif(cr.cohort_size, 0), 2) as ltv_r1,
    round((cr.r0_net_rev + cr.r1_net_rev + cr.r2_net_rev) / nullif(cr.cohort_size, 0), 2) as ltv_r2,
    round((cr.r0_net_rev + cr.r1_net_rev + cr.r2_net_rev + cr.r3_net_rev) / nullif(cr.cohort_size, 0), 2) as ltv_r3
from cohort_recurrences cr
left join sem_spend_monthly s 
    on cr.cohort_date = s.date 
    and cr.ip_country = s.ip_country 
    and cr.site = s.site
where cr.site in ('Merged','Cosmic') 
order by cr.cohort_date DESC