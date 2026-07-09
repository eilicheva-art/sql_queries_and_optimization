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

-- Задачи Неделя 5
/*Создать представление для сотрудников аэропорта, которое показывает расписание рейсов на сегодня (номер рейса, время вылета, аэропорт назначения), 
но скрывает персональные данные пассажиров и стоимость билетов.
1) Маскируем имя: оставляем только первую букву фамилии/имени и добавляем звездочки. Пример: M***
2) Маскируем JSONB контакты: заменяем реальный JSON на "пустышку", сохраняя тип данных. Пример: {"phone": "***", "email": "***"}
3) Маскируем цену, оставляем 0. */
--select now();
--select now() + interval '1 day';
--select date_trunc('day', now()::timestamp);

create or replace view sandbox.eilicheva_flights_today as (
select f.flight_id,
       f.scheduled_departure,
       r.arrival_airport,
       concat(substring(t.passenger_name from 1 for 1), '***') as passenger_name,
       '"phone": "***", "email": "***"' as contacts,
       se.price*0 as price
from prod.flights f join prod.segments se on  f.flight_id = se.flight_id
                    join prod.tickets t on se.ticket_no = t.ticket_no
                    join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
where f.scheduled_departure between  date_trunc('day', now()::timestamp) and date_trunc('day', (now() + interval '1 day')::timestamp)
);

select * from sandbox.eilicheva_flights_today;

/* View «Финансовый отчет по маршрутам»
Отображает среднюю стоимость проданного билета и общую выручку для каждого уникального маршрута (например, Москва — Санкт-Петербург). */
--select * from prod.routes r limit 10;
--select * from prod.airports_data ad limit 10;

create or replace view sandbox.eilicheva_financial_report as (
select r.route_no,
       --ad.city ->> 'ru' as departure_city,
       --ad2.city ->> 'ru' as arrival_city
       round(avg(se.price),2) as avg_ticket_price,
       round(sum(se.price),2) as sum_revenue
from prod.routes r join prod.flights f on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
                   join prod.segments se on  f.flight_id = se.flight_id
                   join prod.airports_data ad on r.departure_airport = ad.airport_code 
                   join prod.airports_data ad2 on r.arrival_airport = ad2.airport_code 
group by r.route_no--, ad.city ->> 'ru', ad2.city ->> 'ru'
)

select * from sandbox.eilicheva_financial_report;

/*View «История цен одного места»
Представление, которое показывает минимальную, максимальную и среднюю цену билета на конкретное место (например, 1A) на самолет модели 7M7. */
--select * from prod.airports_data ad limit 10;
--select * from prod.flights f limit 10;
--select * from prod.routes r limit 10;
--select * from prod.segments se limit 10;
--select * from prod.tickets t limit 10;

create or replace view sandbox.tickets_price as (
select bp.seat_no,
       min(se.price) as min_ticket_price,
       max(se.price) as max_ticket_price,
       avg(se.price) as avg_ticket_price
from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no
                    join prod.flights f on se.flight_id = f.flight_id
                    join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
                    join prod.boarding_passes bp on t.ticket_no = bp.ticket_no
where r.airplane_code = '7M7' 
group by bp.seat_no
);

select * from sandbox.tickets_price;