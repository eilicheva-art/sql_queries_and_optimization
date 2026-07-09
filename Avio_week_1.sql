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

-- Задачи Неделя 1
/*1. Найти модели самолетов (на английском), способные на перелеты свыше 5000 км. 
Отсортировать в порядке убывания дальности. Учитывать, что модели хранятся в формате JSON (на русском и английском). 
Чтобы вывести именно английское название использовать синтаксис model->>'en'*/
select model->>'en' as airplane_model --, range
from prod.airplanes_data
where range > 5000
order by range desc;

/*2. Вывести количество самолетов, чья дальность перелетов меньше 4000.*/
select count(*) as airplane_quantity
from prod.airplanes_data
where range < 4000;

/*3. Получить список рейсов, которые не состоялись. 
 * Вывести id_перелета, номер рейса. 
 * Отсортировать по возрастанию id_перелета. Вывести 10 значений.*/
-- select * from prod.flights f limit 10;
-- select distinct status from prod.flights f;
select flight_id,
       route_no 
from prod.flights
where status = 'Cancelled'
order by flight_id
limit 10;

/*4. Узнать коды и названия всех аэропортов Москвы. 
 * Вывести код аэропорта, название аэропорта на русском, название аэропорта на английском. 
 * Отсортировать в алфавитном порядке кода аэропорта. 
 * Представить столбцы с названиями: airport_code, ru_airport_name, en_airport_name*/
-- select * from prod.airports_data ad limit 10;
select airport_code,
       airport_name ->> 'ru' as ru_airport_name,
       airport_name ->> 'en' as en_airport_name
from prod.airports_data
where city ->> 'en' like 'Moscow'
order by airport_code

/*5. Подсчитать количество мест в бизнес-классе самолета '32N'. 
 * Использовать нейминг для поля business_seats_count.*/
-- select * from prod.seats s limit 10;
select count(seat_no) as seats_num 
from prod.seats
where airplane_code = '32N' and fare_conditions = 'Business'

/*6. Вывести 5 самых недорогих покупок в системе. 
 * Поля для вывода: book_ref, total_amount, book_date.*/
-- select * from prod.bookings b limit 10;
select book_ref, 
       total_amount, 
       book_date 
from prod.bookings
order by total_amount
limit 5;

/*7. Найти все самолеты модели Боинг. Вывести код самолета, его модель на русском.*/
-- select distinct model ->> 'en' from prod.airplanes_data;
select airplane_code,
       model ->> 'ru'
from prod.airplanes_data
where model ->> 'en' like '%Boeing%';

/*8. Вывести дату самого первого бронирования и дату самого последнего бронирования. 
 * Назвать столбцы first_booking, last_booking*/
-- select * from prod.bookings b limit 10;
select min(book_date) as first_booking,
       max(book_date) as last_booking
from prod.bookings;

/*9. Вывести количество аэропортов в каждом часовом поясе в порядке убывания количества. 
 * Вывести часовой пояс и количество. Количество назвать airport_count.*/
-- select * from prod.airports_data ad limit 10;
select timezone,
       count(distinct airport_code) as airport_count
from prod.airports_data
group by timezone
order by airport_count desc;

/*10. Найти 10 пассажиров с самыми короткими именами (имя меньше 3 символов). 
Учитывать, что в колонке записано имя, пробел, фамилия. Вывести имя пассажира и его id.*/
-- select * from prod.tickets t limit 10;
select split_part(passenger_name, ' ', 1) as passenger_first_name,
       passenger_id 
from prod.tickets
order by length(split_part(passenger_name, ' ', 1))
limit 10;

/*11. Рассчитать среднюю стоимость билета (без учетов классов). 
 * Округлить значение до 2 знаков после запятой. Формат вывода: атрибут с неймингом average_ticket_price*/
-- select * from prod.segments se limit 10;
select round(avg(price), 2) as average_ticket_price
from prod.segments;

/*12. Рассчитать среднюю стоимость билета (с учетом классов). Вывести класс и среднюю стоимость. 
 * Округлить значение до 2 знаков после запятой. Формат вывода: 
 * атрибуты с классом и неймингом average_price. Отсортировать в порядке убывания средней цены.*/
-- select * from prod.segments se limit 10;
select fare_conditions,
       round(avg(price), 2) as average_ticket_price
from prod.segments
group by fare_conditions
order by average_ticket_price desc;

/*13. Найти рейсы с самой большой выручкой (где выручка превышает 20.000.000). 
 * Формат вывода: id_рейса и revenue. Отсортировать в порядке убывания выручки.*/
-- select * from prod.segments se limit 10;
select flight_id,
       sum(price) as revenue
from prod.segments
group by flight_id
having sum(price) > 20000000
order by revenue desc;

/*14. Вывести список всех городов (без повторов), в которые летают самолеты. 
 * Учитывать, что города хранятся в формате JSON, вывести русское название →>'ru'. Отсортировать в алфавитном порядке*/
-- select * from prod.airports_data ad limit 10;
select distinct city ->> 'ru' as ru_city
from prod.airports_data
order by ru_city;

/*15. У рейсов есть статусы. Посчитать количество рейсов в каждом статусе. Отсортировать в порядке кол-ва рейсов по убыванию*/
-- select * from prod.flights f limit 10;
select status,
       count(distinct flight_id) as flights_count 
from prod.flights
group by status
order by flights_count desc;

/*16. Найти 5 самых быстрых самолетов в авиапарке. Вывести код самолета, модель самолета на русском языке и скорость. 
 * Представить вывод по убыванию скорости. Если у нескольких самолетов одинаковая скорость, отсортировать таких в алфавитном порядке модели. */
-- select * from prod.airplanes_data ad limit 10;
select airplane_code,
       model ->> 'ru' as airpline_model,
       speed
from prod.airplanes_data
order by speed desc, airpline_model
limit 5;

/*18. Найти общую стоимость всех проданных билетов. Использовать таблицу bookings. Назвать столбец total_revenue */
-- select * from prod.bookings b limit 10;
select sum(total_amount) as total_revenue
from prod.bookings;

/*19. Получить имя и данные документа конкретного пассажира по номеру билета, где номер билета = '0005432000284'*/
select passenger_name 
from prod.tickets
where ticket_no = '0005432000284';

/*20. Найти все аэропорты, работающие, по московскому времени. Вывести код аэропорта, название аэропорта на русском, город аэропорта на русском. 
 * Вывести столбцы с названиями: airport_code, name, city. Отсортировать в алфавитном порядке кода аэропорта.*/
select * from prod.airports_data ad limit 10;
-- select distinct timezone from prod.airports_data order by timezone; --Europe/Moscow
select airport_code, 
       airport_name ->> 'ru' as ru_airport_name, 
       city ->> 'ru' as ru_city
from prod.airports_data 
where timezone = 'Europe/Moscow'
order by airport_code;

/*21. Вывести все билеты и имена пассажиров в бронировании KOS1KJ*/
-- select * from prod.tickets t limit 10;
select ticket_no,
       passenger_name 
from prod.tickets 
where book_ref = 'KOS1KJ';

/*22. Вывести 5 маршрутов с наибольшей продолжительностью (duration). В выводе представить номер маршрута, аэропорт отправления, аэропорт прибытия, продолжительность по времени. 
 * Отсортировать в порядке убывания продолжительности. 
 * Если у нескольких маршрутов одинаковое время продолжительности, их отсортировать в обратном алфавитном порядке номера маршрута.*/
--select * from prod.routes r limit 10;
select route_no,
       departure_airport,
       arrival_airport,
       duration 
from prod.routes
order by duration desc, route_no desc
limit 5;

/*23. Найти 12 аэропортов с самым большим количеством уникальных исходящих маршрутов. Отсортировать в порядке убывания количества.*/
-- select * from prod.routes r limit 10;
select departure_airport,
       count(distinct route_no) as route_count
from prod.routes
group by departure_airport
order by route_count desc
limit 12;



