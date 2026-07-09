-- Справачная инфо https://postgrespro.ru/docs/postgresql/14/functions
--                 https://sql-academy.org/ru/handbook/postgresql/split_part

-- Ознакомление с БД
select count(*) from prod.airplanes_data ad;
select * from prod.airplanes_data ad limit 10;

select count(*) from prod.airports_data ad;
select * from prod.airports_data ad limit 10;

select count(*) from prod.boarding_passes bp;
select * from prod.boarding_passes bp limit 10;

select count(*) from prod.bookings b;
select * from prod.bookings b limit 10;

select count(*) from prod.flights f;
select * from prod.flights f limit 10;

select count(*) from prod.routes r;
select * from prod.routes r limit 10;

select count(*) from prod.seats s;
select * from prod.seats s limit 10;

select count(*) from prod.segments se;
select * from prod.segments se limit 10;

select count(*) from prod.tickets t ;
select * from prod.tickets t limit 10;

-- Задачи Неделя 6
/*
1. По номеру клиента (passenger_id) нужно узнать уровень клиента (Standard, Silver, Gold, Platinum) на основе потраченных им денег за всю историю.
Грейды:
Standard: от 0 до 50.000
Silver: от 50.000 до 150.000
Gold: от 150.000 до 300.000
Platinum: более 300.000
Вернуть:
1) US 2976063125423
2) SE 6854068682151
 */
--select * from prod.tickets t 
--where t.passenger_id = 'US 2976063125423';
--
--select t.ticket_no, 
--       se.price 
--from prod.segments se join prod.tickets t on se.ticket_no = t.ticket_no
--where t.passenger_id = 'US 2976063125423'
--
--select * from prod.segments where ticket_no = '0005448746787'


-- Для ускорения работы создадим временную таблицу из таблицы prod.tickets и для этой временной таблицы создадим индекс на колонку ticket_no
create or replace function sandbox.eilicheva_client_type(p_passenger_id text)
returns table(
passenger_id text,
revenue numeric,
client_type text) as $$
begin 
	
    create temp table temp_tickets AS
	select t.ticket_no, t.passenger_id
	from prod.tickets t
	where t.passenger_id = p_passenger_id; 
	
    create index idx_temp_tickets_ticket_no on temp_tickets (ticket_no);

	return query
	with t1 as (
	select t.passenger_id,
	       t.ticket_no, 
	       se.price,
	       coalesce(sum(se.price) over(partition by t.passenger_id), 0) as revenue
	       from temp_tickets t join prod.segments as se on t.ticket_no = se.ticket_no
	                             --join prod.flights f on se.flight_id = f.flight_id
	                             --join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity;
	)
	select t1.passenger_id,
	       t1.revenue,
	       case 
	       	when t1.revenue < 50000 then 'Standard'
	       	when t1.revenue < 150000 then 'Silver'
	       	when t1.revenue < 300000 then 'Gold'
	       	when t1.revenue >= 300000 then 'Platinum'
	       	else 'Unknown'
	       end as client_type
	from t1
	limit 1;
	drop table temp_tickets;
end;
$$ language plpgsql;

drop function if exists sandbox.eilicheva_client_type(text);

select * from sandbox.eilicheva_client_type('US 2976063125423');
select * from sandbox.eilicheva_client_type('SE 6854068682151');
                             
/*
2. Пассажир хочет сдать билет. Чем ближе дата вылета, тем больше штраф. Функция принимает номер билета и возвращает сумму к возврату.
Если вылет сегодня, суммы к возврату нет
Если от 1 (включительно) до 3 дней (не включительно), штраф 70%
Если от 3 (включительно) до 14 (не включительно), штраф 30%
Если до рейса более 14 дней (включительно), полная сумма к возврату.
Билеты:
0005453191978
0005452344109
0005451639590
0005451677213
 */
--select  date_trunc('day', now()::timestamp);
--select date_trunc('day', (now() + interval '1 day')::timestamp)
--
--with t1 as (
--select t.ticket_no,
--       sum(se.price) as price,
--       date_trunc('day', min(f.scheduled_departure)::timestamp) as min_scheduled_departure
--       from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no
--                             join prod.flights f on se.flight_id = f.flight_id
--                             join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
--where t.ticket_no = '0005448746787'
--group by t.ticket_no
--)
--
--select 
--case 
--	when t1.min_scheduled_departure = date_trunc('day', now()::timestamp) then 0
--	when t1.min_scheduled_departure <= date_trunc('day', (now() + interval '3 day')::timestamp) then price*0.3
--	when t1.min_scheduled_departure <= date_trunc('day', (now() + interval '14 day')::timestamp) then price*0.7
--	when t1.min_scheduled_departure > date_trunc('day', (now() + interval '14 day')::timestamp) then price
--	--else 'Unknown'
--end as return_sum
--from t1

create or replace function sandbox.eilicheva_p_return_sum(p_ticket_no text)
returns table(
p_return_sum numeric) as $$
begin 
    return query
	with t1 as (
	select t.ticket_no,
	       sum(se.price) as price,
	       date_trunc('day', min(f.scheduled_departure)::timestamp) as min_scheduled_departure
	       from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no
	                             join prod.flights f on se.flight_id = f.flight_id
	                             join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
	where t.ticket_no = p_ticket_no
	group by t.ticket_no
	)
	
	select 
	case 
		when t1.min_scheduled_departure <= date_trunc('day', now()::timestamp) then 0
		when t1.min_scheduled_departure < date_trunc('day', (now() + interval '3 day')::timestamp) then t1.price*0.3
		when t1.min_scheduled_departure < date_trunc('day', (now() + interval '14 day')::timestamp) then t1.price*0.7
		when t1.min_scheduled_departure >= date_trunc('day', (now() + interval '14 day')::timestamp) then t1.price
		--else 'Unknown'
	end as return_sum
	from t1;

end;
$$ language plpgsql;

--drop function if exists sandbox.eilicheva_p_return_sum(text)

select * from sandbox.eilicheva_p_return_sum('0005453191978');
--select * from prod.segments where ticket_no = '0005453191978'
select * from sandbox.eilicheva_p_return_sum('0005452344109');
--select * from prod.segments where ticket_no = '0005452344109'
select * from sandbox.eilicheva_p_return_sum('0005451639590');
--select * from prod.segments where ticket_no = '0005451639590'
select * from sandbox.eilicheva_p_return_sum('0005451677213');
--select * from prod.segments where ticket_no = '0005451677213'


/*
3. При покупке билета сайт делает API-запрос к базе: «Сколько свободных мест класса 'Economy' осталось на рейс 123? Должна быть возможность передать в функцию номер рейса и тип класса.
Рейсы:
124968, Business
124977, Economy
125244, Business
 */

create or replace function sandbox.eilicheva_count_free_seats(p_flight_id int4, p_fare_conditions text)
returns table(
p_return_sum bigint) as $$
begin 
    return query
	with t1 as(
	select f.flight_id,
	       f.scheduled_arrival,
	       s.seat_no,
	       s.fare_conditions 
	from prod.flights f join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure
	                    join prod.seats s on r.airplane_code = s.airplane_code
	where f.flight_id = p_flight_id
	),
	    t2 as(
	select bp.flight_id,
	       bp.seat_no
	from prod.boarding_passes bp 
	where bp.flight_id = p_flight_id
	)
	
	select count(*)
	from t1 full join t2 on t1.flight_id = t2.flight_id and t1.seat_no = t2.seat_no
	where t2.seat_no is null and t1.fare_conditions = p_fare_conditions;

end;
$$ language plpgsql;

-- drop function if exists sandbox.eilicheva_count_free_seats(p_flight_id int4, p_fare_conditions text);

select * from sandbox.eilicheva_count_free_seats(124968, 'Business');
select * from sandbox.eilicheva_count_free_seats(124977, 'Economy');
select * from sandbox.eilicheva_count_free_seats(125244, 'Business');

/*
4. Стюардессам на планшет нужен список всех пассажиров конкретного рейса с их местами в виде таблицы.
Полеты:
1663
854
 */

create or replace function sandbox.eilicheva_passengers(p_flight_id int4)
returns table(
seat_no text, 
passenger_name text) as $$
begin 
    return query
	with t1 as(
	select f.flight_id,
	       f.scheduled_arrival,
	       s.seat_no,
	       s.fare_conditions 
	from prod.flights f join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure
	                    join prod.seats s on r.airplane_code = s.airplane_code
	where f.flight_id = p_flight_id
	),
	    t2 as(
	select bp.flight_id,
	       bp.seat_no,
	       t.passenger_name 
	from prod.boarding_passes bp join prod.tickets t on bp.ticket_no = t.ticket_no 
	where bp.flight_id = p_flight_id
	)
	
	select t1.seat_no,
	       t2.passenger_name
	from t1 full join t2 on t1.flight_id = t2.flight_id and t1.seat_no = t2.seat_no
	where t2.passenger_name is not null;

end;
$$ language plpgsql;

--drop function if exists sandbox.eilicheva_passengers(int4);

select * from sandbox.eilicheva_passengers(1663);
select * from sandbox.eilicheva_passengers(854);

