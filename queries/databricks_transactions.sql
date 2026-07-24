       
select 
            m.event_date as date,
            m.event_type,
            m.charge_id,
            m.customer_id as stripe_customer_id,
            m.subscription_id as stripe_subscription_id,
            m.event_subtype,
            m.recurrence_cycle, 
            t.id_transaction,
            t.customer_id as customer_id_table_transactions,
            t.amount as amount_table_transactions,
            t.currency as currency_table_transactions,
           -- t.id as id_table_subscriptions,
            c.email,
            case 
                when coalesce(amplitude.ip_country, m.card_address_country, 'UNKNOWN') = 'UK' then 'GB'
                else coalesce(amplitude.ip_country, m.card_address_country, 'UNKNOWN')
            end as ip_country,
            m.gross_amount,
            m.payment_method_type,
            is2.invoice_number,
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
              left join bronze.pdf.transactions t
              on t.id_transaction = m.charge_id
              left join bronze.pdf.invoices_sii is2
              on is2.transaction_id = t.id
        where m.merchant_id in ('acct_1SD2VNCVUJnyBfx6','acct_1TQoWFClqJv8asWw','acct_1QSfJrEeDNlVSPsk','acct_1TN7CJCpi1ShflFN','acct_1TQoq8CbB8Drwc9S','acct_1TYnL9Ir47dcqvAx','acct_1TiU6PEdo9L76pmz')
        and m.status = 'succeeded'
        and m.event_date >= '2026-01-01'