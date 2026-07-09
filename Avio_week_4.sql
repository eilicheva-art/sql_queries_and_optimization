-- Справачная инфо https://postgrespro.ru/docs/postgresql/14/functions
--                 https://sql-academy.org/ru/handbook/postgresql/split_part
--                 https://metanit.com/sql/postgresql/4.7.php

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

select count(*) from prod.tickets t;
select * from prod.tickets t limit 10;

/*1. Посчитай накопительный итог (running total) суммы бронирований (total_amount) по дням. 
  Выведи дату и сумму, которая накопилась с начала продаж до этого дня включительно. Выведи первые 10 значений
  (сначала сгруппируй выручку по дням в CTE, а затем примени оконную функцию к результату)*/
-- select * from prod.bookings b limit 10;

with t as(
select date_trunc('day', book_date) as day_of_book_date,
       sum(total_amount) as total_amount
from prod.bookings
group by date_trunc('day', book_date)
)
select t.day_of_book_date,
       sum(t.total_amount) over(order by t.day_of_book_date) as running_total_amount
from t
limit 10;


/*2. Выведи flight_id, ticket_no и цену (price). Для каждого рейса найди три самых дорогих проданных билета. Если цены одинаковые, они должны делить одно место*/
-- select * from prod.segments se limit 10;

with t as(
select flight_id, 
       ticket_no,
       price,
       dense_rank() over(partition by flight_id order by price desc) as rank
from prod.segments
)

select flight_id, 
       ticket_no,
       price
from t 
where rank <= 3;

/*3. Для каждого перелета в таблице segments выведи цену билета и среднюю цену билета в этом же классе обслуживания (fare_conditions). 
 * Добавь столбец с разницей: насколько этот конкретный билет дороже или дешевле среднего по классу. 
 * Цену округлить до 2 знаков после запятой. Дубликаты убрать с помощью оконной функции. Вывести строки flight_id, fare_conditions, price, avg_class_price, diff_from_avg. 
 * Отсортировать по номеру перелета, классу билета и цене (все по возрастанию)
 * Вывести первые 50 строк*/
--select * from prod.segments se limit 10;
with t as(
select flight_id,
       fare_conditions,
       price,
       round(avg(price) over(partition by fare_conditions), 2) as avg_class_price,
       price - round(avg(price) over(partition by fare_conditions), 2) as diff_from_avg,
       row_number() over(partition by flight_id, fare_conditions, price order by flight_id, fare_conditions, price) as rank
from prod.segments
--order by flight_id, fare_conditions, price
--limit 50
)

select flight_id,
       fare_conditions,
       price,
       avg_class_price,
       diff_from_avg
from t 
where rank = 1
order by flight_id, fare_conditions, price
limit 50;


/*4. Для пассажира 'Franklin Meyer' рассчитай, сколько времени прошло между его предыдущим и текущим вылетом. 
 * Выведи имя, номер рейса, время вылета и новый столбец time_since_last_flight
 * (Используй функцию LAG, чтобы «заглянуть» в предыдущую строку)*/
-- select * from prod.airports_data ad limit 10;
-- select * from prod.flights f limit 10;
-- select * from prod.routes r limit 10;
-- select * from prod.segments se limit 10;
-- select * from prod.tickets t limit 10;

-- explain
select t.passenger_name,
       f.flight_id,
       f.actual_departure,
       -- lag(f.actual_departure) over(partition by t.passenger_name order by f.actual_departure) as time_last_flight,
       f.actual_departure - lag(f.actual_departure) over(partition by t.passenger_name order by f.actual_departure) as time_since_last_flight
       from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no
                           join prod.flights f on se.flight_id = f.flight_id
                           join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
where t.passenger_name = 'Franklin Meyer';


/*5. Выведи номер бронирования, дату бронирования, сумму чека и процент, который эта сумма составляет от всей выручки за 2025-10-12 (по всем бронированиям в эту дату). 
 * Вывести 50 строк*/
-- select * from prod.bookings b limit 10;
with t as(
select book_ref,
       book_date,
       date_trunc('day', book_date) as day_of_book_date,
       total_amount
from prod.bookings
where date_trunc('day', book_date) = '2025-10-12'
)

select book_ref,
       book_date,
       total_amount,
       total_amount / (sum(total_amount) over(partition by day_of_book_date))*100 as percent_of_total_amount
from t
limit 50;

/*6. В таблице boarding_passes есть поле boarding_no, но давай представим, что его нет, 
 * и нам нужно раздать номера самостоятельно в порядке времени прохождения регистрации (boarding_time). Пронумеруй пассажиров внутри рейса 15*/
-- select * from prod.boarding_passes bp limit 10;
-- select * from prod.tickets t limit 10;

select t.passenger_id, 
       bp.boarding_time,
       row_number() over(order by bp.boarding_time) as count
from prod.boarding_passes bp join prod.tickets t on bp.ticket_no = t.ticket_no
where bp.flight_id = 15

/*7. Найди самые первые утренние рейсы для аэропорта отправления AER на каждый день. 
 * Выведи дату dep_date, код аэропорта, flight_id, время отправления. Сортировка по dep_date.*/
--select * from prod.airports_data ad limit 10;
--select * from prod.flights f limit 10;
--select * from prod.routes r limit 10;

with t1 as(
select date_trunc('day', f.actual_departure) as dep_date,
       f.actual_departure,
       f.flight_id,
       ad.airport_code
from prod.airports_data ad join prod.routes r on ad.airport_code = r.departure_airport
                           join prod.flights f on r.route_no = f.route_no and r.validity @> f.scheduled_departure
where ad.airport_code = 'AER'
),

    t2 as(
select dep_date,
       flight_id,
       actual_departure,
       airport_code,
       row_number() over(partition by dep_date order by actual_departure) as rank
from t1
)

select dep_date,
       flight_id,
       airport_code,
       actual_departure
from t2 
where rank = 1

/*8. Посчитай скользящее среднее выручки (total_amount из bookings) за текущий и два предыдущих дня */
-- select * from prod.bookings b limit 10;

with t as(
select date_trunc('day', book_date) as day_of_book_date,
       sum(total_amount) as sum_total_amount
from prod.bookings 
group by date_trunc('day', book_date)
)

select day_of_book_date,
       --sum_total_amount,
       avg(sum_total_amount) over(order by day_of_book_date rows between 2 preceding and current row) as running_avg_total_amount
from t
