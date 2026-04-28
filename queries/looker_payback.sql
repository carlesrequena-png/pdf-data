with 
	initials as (
		select     		
		    s.id,
		    t.created_at::date as date,
		    concat(extract(year FROM t.created_at),'-W',extract(week FROM t.created_at)) as week,
		   	c.ip_country,
		   	p.amount,
		   	p.amount_trial,
		   	st.subscription_trial_days,
		   	st.subscription_frequency
		from pdfeditor.customers c
		left join pdfeditor.transactions t 
			on t.customer_id = c.id
		left join pdfeditor.invoices_sii is2 
			on is2.transaction_id = t.id
		left join pdfeditor.subscriptions s 
			on s.id = t.subscription_id 
		left join pdfeditor.subscription_types st
			on  st.id = s.subscription_type_id
		left join pdfeditor.prices p
			on p.id = st.price_id
		where 
			t.created_at::date > '2026-01-01'
			and email not like '%leadtech%'
			and t.transaction_status = 1
			and t.transaction_type = 0
			and t.amount <5
			and is2.invoice_number is not null
			and t.created_at <= CURRENT_DATE - INTERVAL '60 days'
	),
	recurrences as (
		select     		
		    i.id,
		    i.date,
		    i.ip_country,
		    i.amount, 
		    i.amount_trial,
		    i.subscription_trial_days,
		    i.subscription_frequency,
		    min(t.created_at::date) as initial_transaction_date, 
			ROUND((SUM(CASE WHEN t.transaction_type = 0 THEN t.amount ELSE 0 END) - COALESCE(SUM(CASE WHEN t.transaction_type = 1 THEN t.amount ELSE 0 END), 0))::NUMERIC, 2) AS user_revenue,
		    SUM(CASE WHEN t.transaction_type = 0 and t.amount = i.amount then 1 else 0 end) - coalesce((SUM(CASE WHEN t.transaction_type = 1 and t.amount >5 then 1 else 0 end)),0) AS recurrences,
		    SUM(CASE WHEN t.transaction_type = 1 then 1 else 0 end) AS refunds
		from initials i
		left join pdfeditor.transactions t 
		on t.subscription_id = i.id
		left join pdfeditor.invoices_sii is2 
		on is2.transaction_id = t.id
		left join pdfeditor.subscriptions s 
		on s.id = t.subscription_id 
		where 
			t.transaction_status = 1
			and is2.invoice_number is not null
		group by 1,2,3,4,5,6,7),
	historical_ratios as (
		-- BENCHMARK by country
		-- Data with more than 60 days, to be more accurate with the real ratios
		-- Country filter with more than 50 sales
		select 
			r.ip_country,
			count(r.id) as sample_size,
			-- Ratio de supervivencia real
			SUM(CASE WHEN r.recurrences > 0 THEN 1 ELSE 0 END) * 1.0 / count(r.id)as r1,
			SUM(CASE WHEN r.recurrences > 1 THEN 1 ELSE 0 END) * 1.0 / count(r.id) as r2,
			SUM(CASE WHEN r.recurrences > 2 THEN 1 ELSE 0 END) * 1.0 / count(r.id) as r3
		from recurrences r
		--left join pdfeditor.transactions t 
		--on t.subscription_id = r.id
		--left join pdfeditor.invoices_sii is2 
		--on is2.transaction_id = t.id
		--left join pdfeditor.subscriptions s 
		--on s.id = t.subscription_id 
		where initial_transaction_date <= CURRENT_DATE - INTERVAL '60 days'
		group by 1
		having count(r.id) > 50 )
select 
	count(r.id) as sales,
	r.date,
	r.ip_country, 
	r.amount, 
	r.amount_trial,
	hs.sample_size,
	round(hs.r1,1) as historical_r1,
	round(hs.r2,1) as historical_r2,
	round(hs.r3,1) as historical_r3,
	round(sum(r.user_revenue),1) as total_user_revenue,
	round((SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0)::numeric,1) as arpu_day_7,
	round((SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0 + SUM(CASE WHEN r.recurrences > 1 then 1*amount ELSE 0 END) * 1.0)::numeric,1) as arpu_day_35,
	round((SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0 + SUM(CASE WHEN r.recurrences > 1 then 1*amount ELSE 0 END) * 1.0 + SUM(CASE WHEN r.recurrences > 2 then 1*amount ELSE 0 END) * 1.0)::numeric,1) as arpu_day_63,
	round((SUM(CASE WHEN r.recurrences > 0 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0))::numeric,1) as r1,
	round((SUM(CASE WHEN r.recurrences > 1 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0))::numeric,1) as r2,
	round((SUM(CASE WHEN r.recurrences > 2 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0))::numeric,1) as r3,
	round((SUM(CASE WHEN r.recurrences > 3 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0))::numeric,1) as r4,
	round(((count(r.id)*r.amount_trial)+(count(r.id)*r.amount*round(hs.r1,1)))::numeric,1) as r1_pred,
	round(((count(r.id)*r.amount_trial)+(count(r.id)*r.amount*round(hs.r1,1))+(count(r.id)*r.amount*round(hs.r2,1)))::numeric,1) as r2_pred
from recurrences r
left join historical_ratios hs
on hs.ip_country = r.ip_country
where sample_size is not null
group by 2,3,4,5,6,7,8,9
