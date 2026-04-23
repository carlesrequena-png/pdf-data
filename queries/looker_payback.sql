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
			--and t.created_at < current_timestamp - interval '8 days'
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
		group by 1,2,3,4,5,6,7)
select 
	count(r.id) as sales,
	r.date,
	r.ip_country, 
	sum(r.user_revenue) as total_user_revenue,
	SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0 as arpu_day_7,
	SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0 + SUM(CASE WHEN r.recurrences > 1 then 1*amount ELSE 0 END) * 1.0 as arpu_day_35,
	SUM(CASE WHEN r.recurrences > 0 then amount_trial + 1*amount ELSE amount_trial END) * 1.0 + SUM(CASE WHEN r.recurrences > 1 then 1*amount ELSE 0 END) * 1.0 + SUM(CASE WHEN r.recurrences > 2 then 1*amount ELSE 0 END) * 1.0 as arpu_day_63,
	SUM(CASE WHEN r.recurrences > 0 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0) as r1,
	SUM(CASE WHEN r.recurrences > 1 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0) as r2,
	SUM(CASE WHEN r.recurrences > 2 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0) as r3,
	SUM(CASE WHEN r.recurrences > 3 THEN 1 ELSE 0 END) * 1.0 / NULLIF(count(r.id), 0) as r4
	--SUM(r.user_revenue) / NULLIF(COUNT(r.id), 0) AS actual_arpu_collected,
from recurrences r
group by 2,3




with 
	initials as (
		-- Mantenemos tu lógica de ventas iniciales
		select     		
		    s.id,
		    t.created_at::date as date,
		    c.ip_country,
		    p.amount as recurring_amount,
		    p.amount_trial as initial_amount
		from pdfeditor.customers c
		left join pdfeditor.transactions t on t.customer_id = c.id
		left join pdfeditor.invoices_sii is2 on is2.transaction_id = t.id
		left join pdfeditor.subscriptions s on s.id = t.subscription_id 
		left join pdfeditor.subscription_types st on st.id = s.subscription_type_id
		left join pdfeditor.prices p on p.id = st.price_id
		where t.created_at::date > '2025-01-01'
			and email not like '%leadtech%'
			and t.transaction_status = 1
			and t.transaction_type = 0
			and t.amount < 5
			and is2.invoice_number is not null
	),
	historical_ratios as (
		-- CALCULAMOS EL BENCHMARK (Lo que suele pasar por país)
		-- Usamos datos de hace más de 60 días para tener ratios reales
		select 
			ip_country,
			avg(initial_amount) as avg_trial,
			avg(recurring_amount) as avg_recurrence,
			count(i.id) as sample_size,
			-- Ratio de supervivencia real
			sum(case when (select count(*) from pdfeditor.transactions t2 where t2.subscription_id = i.id and t2.transaction_type = 0 and t2.amount > 5 and t2.transaction_status = 1) >= 1 then 1 else 0 end) * 1.0 / count(i.id) as h_r1,
			sum(case when (select count(*) from pdfeditor.transactions t2 where t2.subscription_id = i.id and t2.transaction_type = 0 and t2.amount > 5 and t2.transaction_status = 1) >= 2 then 1 else 0 end) * 1.0 / count(i.id) as h_r2,
			sum(case when (select count(*) from pdfeditor.transactions t2 where t2.subscription_id = i.id and t2.transaction_type = 0 and t2.amount > 5 and t2.transaction_status = 1) >= 3 then 1 else 0 end) * 1.0 / count(i.id) as h_r3
		from initials i
		where date <= CURRENT_DATE - INTERVAL '60 days'
		group by 1
		having count(i.id) > 5 -- Filtramos ruido de países con 1 sola venta
	),
	current_performance as (
		-- VENTAS RECIENTES (Las que queremos predecir)
		select 
			date,
			ip_country,
			count(id) as sales,
			sum(initial_amount) as revenue_real_d0
		from initials
		where date > CURRENT_DATE - INTERVAL '60 days'
		group by 1, 2
	)
select 
	cp.date,
	cp.ip_country,
	cp.sales,
	cp.revenue_real_d0,
	-- PREDICCIÓN BASADA EN HISTÓRICO
	cp.revenue_real_d0 + (cp.sales * hr.h_r1 * hr.avg_recurrence) as forecast_rev_d7,
	cp.revenue_real_d0 + (cp.sales * hr.h_r1 * hr.avg_recurrence) + (cp.sales * hr.h_r2 * hr.avg_recurrence) as forecast_rev_d35,
	-- ARPU PROYECTADO (Métrica clave para Looker)
	(cp.revenue_real_d0 + (cp.sales * hr.h_r1 * hr.avg_recurrence) + (cp.sales * hr.h_r2 * hr.avg_recurrence)) / cp.sales as projected_arpu_35d,
	hr.h_r1 as expected_r1,
	hr.h_r2 as expected_r2
from current_performance cp
left join historical_ratios hr on cp.ip_country = hr.ip_country
order by cp.date desc, cp.sales desc;