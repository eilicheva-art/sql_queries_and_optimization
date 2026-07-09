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

-- Задачи Неделя 3
/*1. Вывести самолеты с дальностью выше среднего: код самолета, модель на русском и дальность полета.*/
-- select * from prod.airplanes_data ad limit 10;

select airplane_code, 
       model ->> 'ru',
       range 
from prod.airplanes_data 
where range > (select avg(range) from prod.airplanes_data);

/*2. Найти бронирование конкретного пассажира. Мистер 'Franklin Meyer' обратился в поддержку, но забыл номера своих бронирований. 
 * Найти все бронирования (book_ref и total_amount из таблицы bookings), в которых есть хотя бы один билет, оформленный на имя 'Franklin Meyer'.*/
-- select * from prod.tickets where passenger_name = 'Franklin Meyer';
select book_ref, 
       total_amount from prod.bookings 
where book_ref in (select distinct book_ref from prod.tickets where passenger_name = 'Franklin Meyer');

/*3. Найти и вывести только одно значение — вторую по величине максимальную цену перелета из таблицы segments. Решить с использованием подзапроса.*/
-- select * from prod.segments order by price desc;
select distinct price from prod.segments
where price < (select max(price) from prod.segments)
order by price desc
limit 1;

/*4. Подзапросы можно писать прямо в списке вывода SELECT. Выведи номер бронирования (book_ref), его общую стоимость (total_amount) и количество билетов внутри этого бронирования. 
 * Сортировка по кол-ву билетов внутри бронирования в порядке убывания. Ограничение в выборке 10 строк.
Подсказка: В секции SELECT напиши подзапрос, который делает COUNT(*) из таблицы tickets, где book_ref равен book_ref из внешнего запроса*/
-- select * from prod.bookings b limit 10;
-- select * from prod.tickets t limit 10;
select book_ref, 
       total_amount,
       (select count(*) from prod.tickets where prod.tickets.book_ref = prod.bookings.book_ref) as tickets_count
from prod.bookings
order by tickets_count desc
limit 10;

/*5. Выведи идентификатор рейса, время вылета и общую сумму выручки, но только для тех рейсов, где выручка превысила 15 000 000.*/
-- select * from prod.flights f limit 10;
-- select * from prod.segments se limit 10;
select f.flight_id, 
       f.actual_departure,
       sum(se.price) as revenue
from prod.flights f join prod.segments se on f.flight_id = se.flight_id 
group by f.flight_id, f.actual_departure
having sum(se.price) > 15000000;

/*6. Выведи список уже вылетевших или прибывших рейсов (status 'Departed' или 'Arrived') и количество фактически посаженных на них пассажиров.*/
/*select * from prod.flights f limit 10;
select flight_id, count(*) as c from prod.flights f group by flight_id order by c desc;
select * from prod.segments se limit 10;
select flight_id, count(*) as c1 from prod.segments group by flight_id;
select * from prod.boarding_passes bp limit 10;
select * from prod.boarding_passes bp where flight_id in (124778, 124780);
select flight_id, count(*) as c2 from prod.boarding_passes group by flight_id;
select t1.flight_id,
       t1.c1,
       t2.c2
from (select flight_id, count(*) as c1 from prod.segments group by flight_id) t1 join (select flight_id, count(*) as c2 from prod.boarding_passes group by flight_id) t2 on t1.flight_id = t2.flight_id
where t1.c1 <> t2.c2*/
       
/*select flight_id, 
       (select count(*) from prod.segments where prod.segments.flight_id = prod.flights.flight_id) as passengers_count
from prod.flights where status in ('Departed', 'Arrived') --and flight_id = 123*/

select f.flight_id, 
       count(bp.ticket_no) as passengers_count
from prod.flights f join prod.segments se on f.flight_id = se.flight_id
                    left join prod.boarding_passes bp on se.ticket_no = bp.ticket_no 
where f.status in ('Departed', 'Arrived') -- and f.flight_id in (124778, 124780)
group by f.flight_id

/*7. Найди Топ-5 рейсов с максимальной задержкой вылета*/
-- select * from prod.flights f limit 10;
select flight_id,
       actual_departure - scheduled_departure as delay
from prod.flights
where actual_departure is not null and scheduled_departure is not null
order by delay desc
limit 5

/*8. Рассчитай процент заполняемости для каждого рейса, на который уже выданы посадочные талоны.*/
--select * from prod.boarding_passes bp limit 10;
--select * from prod.flights f limit 10;
--select * from prod.routes r where r.route_no = 'PG0004';
--select * from prod.seats s limit 10;
--select * from prod.segments se limit 10;
--select * from prod.tickets t limit 10;                    


with t1 as(
select f.flight_id,
       f.scheduled_arrival,
       s.seat_no
from prod.flights f join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure
                    join prod.seats s on r.airplane_code = s.airplane_code
),
    t2 as(
select f.flight_id,
       f.scheduled_arrival,
       bp.seat_no 
from prod.boarding_passes bp join prod.segments se on bp.ticket_no = se.ticket_no
                             join prod.flights f on se.flight_id = f.flight_id
                             join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure
)

select t1.flight_id,
       t1.scheduled_arrival,
       count(t2.seat_no)/count(t1.seat_no)*100 as supply
from t1 left join t2 on t1.flight_id = t2.flight_id and t1.scheduled_arrival = t2.scheduled_arrival and t1.seat_no = t2.seat_no
group by t1.flight_id, t1.scheduled_arrival

/*9. Требуется определить среднюю стоимость перелета для каждого маршрута. Вывести номер маршрута, код аэропорта вылета, код аэропорта прилета и вычисленную среднюю цену.*/
-- select * from prod.flights f where f.flight_id = 1275;
-- select * from prod.routes r where r.route_no = 'PG0004';
-- select * from prod.segments se where se.flight_id = 1275;
with t as(
select r.route_no, 
       f.flight_id,
       r.departure_airport,
       r.arrival_airport,
       sum(se.price) as sum_price_by_flights
from prod.routes r join prod.flights f on r.route_no = f.route_no and r.validity @> f.scheduled_departure
                   join prod.segments se on f.flight_id =se.flight_id 
--where f.flight_id = 1275
group by r.route_no, f.flight_id, r.departure_airport, r.arrival_airport
)

select route_no,
       departure_airport,
       arrival_airport,
       avg(sum_price_by_flights) as avg_price_by_flights
from t
group by route_no, departure_airport, arrival_airport;

/*10.*/

/*11. Требуется вывести список аэропортов по количеству уникальных маршрутов, вылетающих из них. Вывести название аэропорта, город и количество маршрутов. Вывести только те а*/
 -- select * from prod.airports_data ad limit 10;
-- select * from prod.routes r limit 10;

select ad.airport_name -> 'en' as en_name,
       ad.city ->> 'en' as en_city,
       count(t.route_no) as route_count
from prod.airports_data ad join (select distinct departure_airport, route_no from prod.routes) as t on ad.airport_code = t.departure_airport 
group by ad.airport_name -> 'en', ad.city ->> 'en'


/*12. Требуется рассчитать, какой процент от общей выручки каждого рейса составляет выручка от продажи билетов класса 'Business'. Вывести flight_id, общую выручку, выручку бизнес-класса и рассчитанный процент*/
--select * from prod.flights f limit 10;
--select count(*) from prod.flights f;
--select count(distinct f.flight_id ) from prod.flights f;
--select * from prod.segments se limit 10;
with t as(
select f.flight_id,
       se.price,
       case 
       	when se.fare_conditions = 'Business' then se.price
       	else 0
       end as price_business
from prod.flights f join prod.segments se on f.flight_id = se.flight_id 
)
select flight_id,
       sum(price) as total_revenue,
       sum(price_business) as business_revenue,
       round(sum(price_business)/sum(price)*100, 2) as price_business_percent
from t
group by flight_id;

/*13. Требуется сравнить реальное время нахождения самолета в воздухе с плановой продолжительностью маршрута. Вывести flight_id, фактическое время и плановое время (duration).*/;
select flight_id,
       actual_arrival - actual_departure as actual_time,
       scheduled_arrival - scheduled_departure as scheduled_time
from prod.flights
where actual_departure is not null and scheduled_departure is not null;



