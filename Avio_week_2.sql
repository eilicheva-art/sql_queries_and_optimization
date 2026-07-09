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

-- Задачи Неделя 2
/*1. Вывести уникальный список аэропортов. В таблице routes (маршруты) есть коды аэропортов вылета (departure_airport) 
 * и прилета (arrival_airport). Напиши запрос, который вернет единый столбец (airport_code) с уникальными кодами всех аэропортов, 
 * которые задействованы в маршрутах (то есть являются либо пунктом отправления, либо пунктом назначения). 
 * Атрибут назови airport_code, отсортируй по алфавиту.*/
select distinct departure_airport as airport_code from prod.routes
union
select distinct arrival_airport as airport_code from prod.routes
order by airport_code;

/*2. Сформировать полный лог событий. Аналитикам понадобился единый хронологический список всех плановых взлетов и посадок для табло. 
 * Сформируй таблицу из трех колонок: номер рейса (flight_id), тип события (строка 'Departure' или 'Arrival') 
 * и плановое время события (event_time). Данные нужно взять из таблицы flights. Отсортируй результат по времени.*/
-- select * from prod.flights f limit 10;
select flight_id,
       scheduled_departure as scheduled_time,
       'Departure' as event_type
from prod.flights
union all
select flight_id,
       scheduled_arrival  as scheduled_time,
       'Arrival' as event_type
from prod.flights
order by scheduled_time;

/*3. Самолеты с бизнес- и комфорт-классом. У разных самолетов (airplane_code) 
 * разная компоновка мест (seats). Напиши запрос, который выведет коды только тех самолетов, 
 * у которых есть и места класса 'Business', и места класса 'Comfort'.*/
-- select * from prod.seats s limit 10;
select distinct airplane_code from prod.seats
where fare_conditions = 'Business'
intersect 
select distinct airplane_code from prod.seats
where fare_conditions = 'Comfort';

/*4. Напиши запрос, который выведет все свободные места (seat_no) для рейса flight_id = 1275.*/
-- select * from prod.seats s limit 10; -- сколько мест для каждого airplane_code = E70 
-- select * from prod.routes r limit 10; -- связь между airplane_code = E70 и route_no = PG0004 (3 дубликата с разным days_of_week)
-- select * from prod.flights f limit 10; -- связь между route_no = PG0004 и flight_id = 1275
-- select * from prod.boarding_passes where flight_id = 1275; -- сколько мест забронировано по flight_id

-- select * from prod.seats where airplane_code = 'E70;
-- select * from prod.routes where route_no = 'PG0004'; --(3 дубликата с разным days_of_week)
-- select * from prod.flights where flight_id = 1275;
-- select * from prod.boarding_passes where flight_id = 1275;

-- Вариант 1
select distinct s.seat_no -- distinct нужен из-за 3 дубликатов в prod.routes с разным validity и days_of_week
from prod.flights f join prod.routes r on f.route_no = r.route_no
                    join prod.seats s on r.airplane_code = s.airplane_code
                    left join prod.boarding_passes bp on s.seat_no = bp.seat_no and bp.flight_id = 1275
where f.flight_id = 1275 and bp.boarding_no is null

-- Вариант 2
select s.seat_no 
from prod.flights f join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure
                    join prod.seats s on r.airplane_code = s.airplane_code
                    left join prod.boarding_passes bp on s.seat_no = bp.seat_no and bp.flight_id = 1275
where f.flight_id = 1275 and bp.boarding_no is null
 and r.validity @> f.scheduled_departure 

/*5. В таблице билетов есть логическое (boolean) поле outbound, которое определяет направление: true для билета «туда» и false для билета «обратно». 
 * Выведи номера билетов, имена пассажиров и добавь новый столбец direction, в котором вместо true/false будет написано 'Туда' или 'Обратно'.*/
-- select * from prod.tickets t limit 10;

select ticket_no, -- outbound,
       passenger_name,
       case
           WHEN outbound = True THEN 'туда'
           WHEN outbound = False THEN 'обратно'
           ELSE 'unknown'
       end as direction 
from prod.tickets limit 10;

/*6. Выведи код самолета, модель и новый столбец range_category со следующей логикой:
    До 4000 км — 'Ближнемагистральный'
    От 4000 до 8000 км (включительно) — 'Среднемагистральный'
    Более 8000 км — 'Дальнемагистральный'
Отсортируй в порядке возрастания дальности.*/
select * from prod.airplanes_data ad limit 10;

select airplane_code, range,
       model ->> 'ru',
       case
           when range < 4000 then 'Ближнемагистральный'
           when range <= 8000 then 'Среднемагистральный'
           when range > 8000 then 'Дальнемагистральный'
           else 'unknown'
       end as range_category 
from prod.airplanes_data limit 10;

-- Проверка
with t as (
select airplane_code, range,
       model ->> 'ru',
       case
           when range < 4000 then 'Ближнемагистральный'
           when range <= 8000 then 'Среднемагистральный'
           when range > 8000 then 'Дальнемагистральный'
           else 'unknown'
       end as range_category 
from prod.airplanes_data
)
select range_category, min(range) as min_range, max(range) as max_range
from t 
group by range_category
order by min_range

/*7. У рейса целых 6 возможных статусов. Для табло на главной странице сайта нужны более простые категории. 
 * Выведи flight_id, оригинальный status, новый столбец simple_status и scheduled_departure. При этом столбец simple_status - это:
    Если статус Scheduled, On Time или Delayed — пишем 'Ожидается'
    Если Boarding или Departed — пишем 'В процессе'
    Если Arrived — пишем 'Завершен'
    Если Cancelled — пишем 'Отменен'.
Оставь только рейсы, чей scheduled_departure был не раньше, чем 3 дня назад от текущего момента.
Подсказка: Для текущего времени используй системную функцию bookings.now(), а не стандартную NOW(). 
Чтобы вычесть 3 дня можно от текущей даты отнять 3 (-3). Или использовать синтаксис - INTERVAL.
Отсортировать в порядке убывания времени прибытия.*/
-- select * from prod.flights f limit 10;
-- select distinct status from prod.flights;

select flight_id, 
       scheduled_departure,
       case
           when status in ('Scheduled', 'On Time', 'Delayed') then 'Ожидается'
           when status in ('Boarding', 'Departed') then 'В процессе'
           when status = 'Arrived' then 'Завершен'
           when status = 'Cancelled' then 'Отменен'
           else 'unknown'
       end as simple_status
from prod.flights
where scheduled_departure <= bookings.now() - interval '3 day';

/*8.Служба безопасности просит подсветить потенциально ошибочные цены на перелеты (price). 
 * Выведи номер билета, рейс, класс обслуживания (fare_conditions), цену и столбец price_alert:
    Если класс 'Economy', а цена больше 50000 — 'Подозрительно дорогой эконом'
    Если класс 'Business', а цена меньше 15000 — 'Подозрительно дешевый бизнес'
    В остальных случаях — 'Норма'*/
--select * from prod.segments se limit 10;
--select * from prod.tickets t limit 10;

select t.ticket_no, 
       se.flight_id,
       se.fare_conditions,
       se.price,
       case 
       	when se.fare_conditions = 'Economy' and se.price > 50000 then 'Подозрительно дорогой эконом'
       	when se.fare_conditions = 'Business' and se.price < 15000 then 'Подозрительно дешевый бизнес'
       	else 'Норма'
       end as price_alert
from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no

/*9. Определить, в какое время суток вылетают рейсы, используя местное время вылета (scheduled_departure_local), 
 * которое нам любезно считает представление timetable. Используя функцию EXTRACT(hour FROM ...), выведи flight_id, scheduled_departure_local и столбец time_of_day:
    С 6 до 11 часов — 'Утро'
    С 12 до 17 часов — 'День'
    С 18 до 23 часов — 'Вечер'
    Остальное (с 0 до 5) — 'Ночь'*/

-- select * from prod.flights f limit 10;
-- select * from prod.timetable limit 10;

select f.flight_id,
       t.scheduled_departure_local,
       extract(hour from t.scheduled_departure_local) as h,
       case 
       	when extract(hour from t.scheduled_departure_local) between 6 and 11 then 'Утро'
       	when extract(hour from t.scheduled_departure_local) between 12 and 17 then 'День'
       	when extract(hour from t.scheduled_departure_local) between 18 and 23 then 'Вечер'
       	else 'Ночь'
       end as time_of_day     
       from prod.flights f join prod.timetable t on f.flight_id = t.flight_id;

-- Проверка
with t as (
select f.flight_id,
       t.scheduled_departure_local,
       extract(hour from t.scheduled_departure_local) as h,
       case 
       	when extract(hour from t.scheduled_departure_local) between 6 and 11 then 'Утро'
       	when extract(hour from t.scheduled_departure_local) between 12 and 17 then 'День'
       	when extract(hour from t.scheduled_departure_local) between 18 and 23 then 'Вечер'
       	else 'Ночь'
       end as time_of_day     
       from prod.flights f join prod.timetable t on f.flight_id = t.flight_id
       )
select time_of_day, min(t.scheduled_departure_local), max(t.scheduled_departure_local)
from t
group by time_of_day 
order by min(t.scheduled_departure_local) 

/*10. Продолжение задания 9: Посчитай, сколько всего рейсов запланировано на утро, день, вечер и ночь. Используй представление timetable и местное время вылета (scheduled_departure_local). 
Выведи два столбца: time_of_day и flights_count (количество рейсов).
Логика для времени суток осталась прежней:
    6–11 часов → 'Утро'
    12–17 часов → 'День'
    18–23 часов → 'Вечер'
    Остальное (0–5) → 'Ночь'
Отсортируй результат по количеству рейсов по убыванию.*/

with t as (
select f.flight_id,
       t.scheduled_departure_local,
       extract(hour from t.scheduled_departure_local) as h,
       case 
       	when extract(hour from t.scheduled_departure_local) between 6 and 11 then 'Утро'
       	when extract(hour from t.scheduled_departure_local) between 12 and 17 then 'День'
       	when extract(hour from t.scheduled_departure_local) between 18 and 23 then 'Вечер'
       	else 'Ночь'
       end as time_of_day     
       from prod.flights f join prod.timetable t on f.flight_id = t.flight_id
       )
select time_of_day, 
       count(*) as flights_num
from t
group by time_of_day 
order by flights_num desc

/*11. Выведи список всех самолетов (код и модель) и количество мест в них. Таблицы: airplanes и seats. Отсортируй в порядке убывания кол-ва мест.*/
-- select * from prod.airplanes_data ad limit 10;
-- select * from prod.seats s limit 10;

select ad.airplane_code,
       ad.model ->> 'en' as en_model,
       count(s.seat_no) as seats_count
from prod.airplanes_data ad join prod.seats s on ad.airplane_code = s.airplane_code
group by ad.airplane_code, ad.model ->> 'en'
order by seats_count desc

/*12. Покажи номера бронирований, даты покупки, общую сумму чека (total_amount) и имена всех пассажиров в этих бронированиях.
Ограничения:
1. Оставь только те бронирования, сумма которых превышает 900 000.
2. Отсортируй результат по убыванию суммы.
3. Выведи только Топ-10 строк*/
-- select * from prod.bookings b limit 10;
-- select * from prod.tickets t limit 10;
-- select * from prod.bookings where book_ref = 'LVHKYQ';
-- select * from prod.tickets where book_ref = 'LVHKYQ';

select distinct b.book_ref,
       b.book_date,
       b.total_amount,
       t.passenger_name 
from prod.bookings b join prod.tickets t on b.book_ref = t.book_ref
where b.total_amount > 900000
order by b.total_amount desc
limit 10


/*13. Выведи номер маршрута (route_no), название города вылета и города прилета. 
 * Для этого таблицу routes нужно соединить со справочником airports дважды (для departure_airport и для arrival_airport).*/
-- select * from prod.routes r limit 10;
-- select * from prod.airports_data ad limit 10;

select r.route_no,
       ad.city ->> 'ru' as departure_city,
       ad2.city ->> 'ru' as arrival_city
from prod.routes r join prod.airports_data ad on r.departure_airport = ad.airport_code 
                   join prod.airports_data ad2 on r.arrival_airport  = ad2.airport_code 


/*14. Для рейса с flight_id = 123 выведи номера билетов, имена пассажиров и их класс обслуживания (fare_conditions). 
 * Таблицы: flights, segments, tickets.*/
-- select * from prod.flights f limit 10;
-- select * from prod.segments se limit 10;
-- select * from prod.tickets t limit 10;
-- select * from prod.routes r limit 10;
-- select * from prod.seats s limit 10;

-- select * from prod.flights f where f.flight_id = 123;
-- select * from prod.routes r where r.route_no = 'PG0075' and r.validity = '["2025-10-01 03:00:00+03","2025-11-01 03:00:00+03")' -- airpline_code 77W 351
-- select * from prod.seats s where s.airplane_code  = '351';

-- select * from prod.segments se  where se.flight_id = 123;
-- select count(distinct se.ticket_no) from prod.segments se  where se.flight_id = 123;

select t.ticket_no,
       t.passenger_name,
       se.fare_conditions 
       from prod.flights f join prod.segments se on f.flight_id = se.flight_id 
                           join prod.tickets t on se.ticket_no = t.ticket_no
where f.flight_id = 123
order by t.passenger_name

/*15. Для рейса с flight_id = 123 выведи номера билетов, имена пассажиров и их класс обслуживания (fare_conditions). Таблицы: flights, segments, tickets.*/
select t.ticket_no,
       t.passenger_name,
       se.fare_conditions 
       from prod.flights f join prod.segments se on f.flight_id = se.flight_id 
                           join prod.tickets t on se.ticket_no = t.ticket_no
where f.flight_id = 123
order by t.passenger_name

/*16. Решим задачу поиска свободных мест через LEFT JOIN. Возьми все места модели самолета, 
выполняющей рейс flight_id = 23405 (через timetable и seats), 
и с помощью LEFT JOIN к boarding_passes найди те, где талона нет (boarding_no IS NULL).*/

см. задачу 4

/*17. Посчитай, сколько реальных рейсов (flights) было запланировано для каждой модели самолета (model). Таблицы: airplanes, routes, flights*/
-- select * from prod.airplanes_data ad limit 10;
-- select count(*) from prod.airplanes_data ad;
-- select * from prod.flights f limit 10;
-- select count(*) from prod.flights f;
-- select count(distinct f.flight_id ) from prod.flights f;
-- select count(distinct f.route_no) from prod.flights f;
-- select * from prod.routes r limit 10;
-- select r.validity, count(r.validity) from prod.routes r group by r.validity;
-- select * from prod.routes where route_no = 'PG0004'; --(3 с разным validity)

select model, count(*)
from  prod.airplanes_data ad join prod.routes r on ad.airplane_code  = r.airplane_code 
                             join prod.flights f on r.route_no  = f.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
group by model
                         
/*18. Решим задачу поиска свободных мест через LEFT JOIN. Возьми все места модели самолета, выполняющей рейс flight_id = 23405 
 * (через timetable и seats), и с помощью LEFT JOIN к boarding_passes найди те, где талона нет (boarding_no IS NULL).*/
см. задачу 4

/*19. Выведи полный маршрутный лист для билета с номером '0005432000987': имя пассажира, номер рейса, плановое время вылета, город отправления и город прибытия. 
 * Таблицы: tickets, segments, flights, routes, airports (дважды для городов).*/
-- select * from prod.airports_data ad limit 10;
-- select * from prod.flights f limit 10;
-- select * from prod.routes r limit 10;
-- select * from prod.segments se limit 10;
-- select * from prod.tickets t limit 10;

select t.passenger_name,
       f.flight_id,
       f.scheduled_departure, 
       ad.city ->> 'en' as departure_city,
       ad2.city ->> 'en' as arrival_city
       from prod.tickets t join prod.segments se on t.ticket_no = se.ticket_no
                             join prod.flights f on se.flight_id = f.flight_id
                             join prod.routes r on f.route_no = r.route_no and r.validity @> f.scheduled_departure -- проверка дата scheduled_departure входит в диапазон validity
                             join prod.airports_data ad on r.departure_airport = ad.airport_code
                             join prod.airports_data ad2 on r.arrival_airport = ad2.airport_code
where t.ticket_no = '0005432000987';


