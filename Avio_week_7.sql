-- Справачная инфо https://postgrespro.ru/docs/postgresql/14/functions
--                 https://sql-academy.org/ru/handbook/postgresql/split_part
--                 визуализация плана запроса https://explain.tensor.ru/archive/explain/9cd38d11-fc44-be54-717d-1e176d9ee97a:0:2026-06-28#explain

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

-- Задачи Неделя 7
/*1. Новый аналитик жалуется на долгий запрос. Да еще и документации по нему нет :(
Задание состоит из двух пунктов:
1) Написать документацию по отчету
2) Предложить идеи по оптимизации скрипта формирования отчета.
Документации нет (как обычно на проектах). Разберите скрипт, напишите документацию, постарайтесь сформулировать бизнес смысл данного отчета.
Разберите и опишите каждую строчку плана выполнения запроса.
Предложите решение по оптимизации без его фактической реализации. */

explain analyze
--explain 
WITH flight_metrics AS (
-- запрос агрегирует по рейсу, маршруту, дате вылета и коду самолета количество билетов и суммарную выручку по маршрутам со статусом 'Departed', 'Arrived'
    SELECT 
        f.flight_id,
        r.route_no,
        DATE(f.scheduled_departure) AS flight_date,
        r.airplane_code,
        COUNT(s.ticket_no) AS sold_tickets,
        SUM(s.price) AS total_revenue
    FROM prod.flights f
    JOIN prod.routes r ON f.route_no = r.route_no AND r.validity @> f.scheduled_departure  -- проверка дата scheduled_departure входит в диапазон validity
    JOIN prod.segments s ON f.flight_id = s.flight_id
    WHERE f.status IN ('Departed', 'Arrived')
    GROUP BY 
        f.flight_id, 
        r.route_no, 
        DATE(f.scheduled_departure), 
        r.airplane_code
),
advanced_metrics AS (
    SELECT 
-- запос берет таблицу, сформированную на предыдущем шаге и рассчитывает для каждого маршрута среднюю выручку, а также для каждого самолета (кода самолет) количество мест в самолете
        fm.flight_id,
        fm.route_no,
        fm.flight_date,
        fm.sold_tickets,
        fm.total_revenue,
        AVG(fm.total_revenue) OVER (PARTITION BY fm.route_no) AS avg_route_revenue,
        (SELECT COUNT(*) FROM prod.seats st WHERE st.airplane_code = fm.airplane_code) AS max_seats
    FROM flight_metrics fm
)

SELECT 
-- запрос берет таблицу, сформированную на предыдущем шаге и рассчитывает среднюю заполняемость самолета (количество проданных мест на общее количество мест)
-- отфильтровываются только рейсы где продано меньше половины мест и выручка больше, чем в среднем по этому маршруту
-- происходит сортировка по убыванию total_revenue
    flight_id,
    route_no,
    flight_date,
    sold_tickets,
    max_seats,
    ROUND((sold_tickets::numeric / max_seats) * 100, 1) AS load_factor_percent, -- загрузка в %
    total_revenue,
    ROUND(avg_route_revenue, 2) AS avg_route_revenue
FROM advanced_metrics
WHERE 
    -- (продано меньше половины мест)
    sold_tickets < (max_seats / 2)
    -- (выручка больше, чем в среднем по этому маршруту)
    AND total_revenue > avg_route_revenue
ORDER BY 
    total_revenue DESC;

/* 
=============================================================
QUERY DOCUMENT
=============================================================
В запросе есть 2 табличных выражения: flight_metrics и advanced_metrics. 

------------------------flight_metrics-----------------------
Бизнес-смысл: В flight_metrics происходит рассчет количества билетов и суммарной выручки по маршрутам со статусом 'Departed', 'Arrived' для уникальных сочетаний рейсов, маршрутов, 
дат вылета и кодов самолета.
Комментарий по коду: В запросе есть 2 джоина (объединяются таблицы flights, routes, segments), фильрация (по полю status) и группировка.

Таблица flights (135 571 записей) джоинится с таблицей routes (7 242 записей) по route_no (text) и условию r.validity (tstzrange) @> f.scheduled_departure (timestamptz).
В таблице flights есть индекс на (route_no, scheduled_departure), в таблице routes создан индекс на (route_no, validity).

Таблица flights (135 571 записей) джоинится с таблицей segments (27 580 257) по flight_id (int4). 
В таблице flights есть PRIMARY KEY и индекс на (flight_id), в таблице segments создан внешний ключ и индекс segments_flight_id_idx на (flight_id).

На поле flights.status (text), по которому происходит фильтрация, нет индекса.

-----------------------advanced_metrics-----------------------
Бизнес-смысл: Запрос берет таблицу, сформированную на предыдущем шаге (flight_metrics) и рассчитывает для каждого маршрута среднюю выручку, 
а также для каждого самолета (кода самолет) количество мест в самолете.
Комментарий по коду: В запросе есть обращение к CTE flight_metrics, оконная функция и корреллированный подзапрос.

Для каждой строки flight_metrics выполняется оконная функция, рассчитывающая среднюю выручку по маршруту.

Также выполняется корреллированный подзапрос, рассчитывающий для каждой модели самолета число мест в самолете. Выполняется обращение к таблице seats, содержащей 1741 строку.
При этом обращение к seats происходит 124071 раз, судя по данным расширенного плана запроса ниже.

-----------------------Итоговый select------------------------
Бизнес-смысл: Запрос берет таблицу, сформированную на предыдущем шаге и рассчитывает среднюю заполняемость самолета (количество проданных мест на общее количество мест).
Отфильтровываются только рейсы где продано меньше половины мест и выручка больше, чем в среднем по этому маршруту. Происходит сортировка по убыванию total_revenue.
Комментарий по коду: В запросе есть фильтрация и сортировка.

Фильтрация происходит по полю sold_tickets, которое создано в CTE flight_metrics.

В фильтре sold_tickets < (max_seats / 2) целочисленное деление (отсекает дробную часть). Более правильно sold_tickets < (max_seats / 2.0).

Сортировка идет по полю total_revenue, которое создано в CTE flight_metrics.

Получается, фильруем и сортируем по количественным переменным, на которых нет индекса, что может быть очень дорогими оперциями по времени выполнения.

Т.к. мы находимся в postgre sql, основными возможностями по оптимизации запроса является либо перестройка запроса, либо добавление индексов и партиционирование.
Предложения по ускорению запроса:
1) Избавиться от коррелированного подзапроса.
2) Увеличить work_mem для сессии (например, до 256 МБ).
3) Подумать над тем, возможно ли уменьшить число строк при джоине flights (135 571 записей) с таблицей segments (27 580 257) по flight_id, т.к. в результате получем таблицу с rows=26 269 408
4) Cохранить advanced_metrics во временную таблицу и сделать на поле sold_tickets и total_revenue индекс, в итоговом select обращаться к временной таблице.
   В таком случае дорогие судя по плану запроса ниже сортировка и фильтрация:
   - ORDER BY total_revenue DESC;
   - WHERE  sold_tickets < (max_seats / 2) AND total_revenue > avg_route_revenue (если фильтр селективный, т.е. выбирает небольшую долю всех строк таблицы)
   будут проходить по индексам, что должно ускорить запрос.
5) Судя по плану запроса ниже, также дорогой является выполнение оконной функции AVG(fm.total_revenue) OVER (PARTITION BY fm.route_no) AS avg_route_revenue. 
   Можно порекомендовать попробовать использовать временную таблицу и индекс на route_no во временной таблице, что может быть ускорит выполнение оконной функции.
6) Джоины на числовые колонки работают быстрее, чем на текстовые. Мы видим, что в запросе есть джоины по текстовым полям (flights и routes по route_no (text)), 
   что тоже может замедлять запрос. 

Выведим план запроса в двух вариантах:
- с использованием explain analize - расширенный план запроса;
- с использованием explain - план запроса в стандартном виде (строится без выполнения запроса).
=============================================================
REPORT (QUERY PLAN)
=============================================================
explain:
-------------------------------------------------------------
Sort  (cost=2307040.65..2307112.19 rows=28617 width=127)
  Sort Key: advanced_metrics.total_revenue DESC
  ->  Subquery Scan on advanced_metrics  (cost=10327.05..2303063.83 rows=28617 width=127)
        Filter: ((advanced_metrics.total_revenue > advanced_metrics.avg_route_revenue) AND (advanced_metrics.sold_tickets < (advanced_metrics.max_seats / 2)))
        ->  WindowAgg  (cost=10327.05..2298127.42 rows=257552 width=95)
              Window: w1 AS (PARTITION BY fm.route_no)
              ->  Subquery Scan on fm  (cost=10022.62..67083.22 rows=257552 width=59)
                    ->  GroupAggregate  (cost=10022.62..64507.70 rows=257552 width=59)
                          Group Key: r.route_no, f.flight_id, (date(f.scheduled_departure)), r.airplane_code
                          ->  Incremental Sort  (cost=10022.62..56781.14 rows=257552 width=38)
                                Sort Key: r.route_no, f.flight_id, (date(f.scheduled_departure)), r.airplane_code
                                Presorted Key: r.route_no
                                ->  Nested Loop  (cost=9994.03..43999.53 rows=257552 width=38)  -- сравнивает каждую строку первой таблицы с каждой строкой второй таблицы, 
                                                                                                   выводит строки, которые удовлетворяют условию объединения, медленный тип объединения.
                                      ->  Gather Merge  (cost=9993.59..23535.15 rows=1266 width=23)
                                            Workers Planned: 1
                                            ->  Merge Join  (cost=8993.58..22392.71 rows=745 width=23) -- используется, если объединяемые наборы данных отсортированы 
                                                                                                          (есть индекс или могут быть отсортированы с небольшими затратами) по ключам объединения
                                                                                                          Быстрее, чем Nested Loop, но медленнее Hash Join
                                                  Merge Cond: (f.route_no = r.route_no)
                                                  Join Filter: (r.validity @> f.scheduled_departure)
                                                  ->  Sort  (cost=8334.61..8517.14 rows=73011 width=19)
                                                        Sort Key: f.route_no
                                                        ->  Parallel Seq Scan on flights f  (cost=0.00..2436.85 rows=73011 width=19) -- (параллельное последовательное сканирование) – используется несколько ядер процессора
                                                              Filter: (status = ANY ('{Departed,Arrived}'::text[]))
                                                  ->  Sort  (cost=658.71..676.82 rows=7242 width=33)
                                                        Sort Key: r.route_no
                                                        ->  Seq Scan on routes r  (cost=0.00..194.42 rows=7242 width=33)
                                      ->  Index Scan using segments_flight_id_idx on segments s  (cost=0.44..12.82 rows=284 width=23)   -- индексное сканирование, возвращает значения TID (tuple id – идентификатор строки) по одному, до тех пор, пока подходящие строки не закончатся
                                                                                                                                        -- 0.44 - приблизительная стоимость запуска. Это время, которое проходит, прежде 
                                                                                                                                                чем начнётся этап вывода данных, например для сортирующего узла это время сортировки;
                                                                                                                                         12.82 - приблизительная общая стоимость для извлечения всех строк;
                                                                                                                                         rows = 284 – ожидаемое количество строк, которое запрос способен вернуть (он может 
                                                                                                                                                     вернуть меньше, например, в случае использования LIMIT);
                                                                                                                                         width = 23 – ожидаемый средний размер возвращаемых строк в байтах.
                                            Index Cond: (flight_id = f.flight_id)
              SubPlan 1
                ->  Aggregate  (cost=8.64..8.65 rows=1 width=8)
                      ->  Index Only Scan using seats_pkey on seats st  (cost=0.28..8.09 rows=218 width=0)
                            Index Cond: (airplane_code = fm.airplane_code)
JIT:
  Functions: 36
  Options: Inlining true, Optimization true, Expressions true, Deforming true

-------------------------------------------------------------
explain analyse:
-------------------------------------------------------------
Sort  (cost=2307040.65..2307112.19 rows=28617 width=127) (actual time=108774.852..108775.032 rows=1557.00 loops=1) -- сортировка в итоговом select (очень дорогая, т.к. не по индексу) 
  Sort Key: advanced_metrics.total_revenue DESC
  Sort Method: quicksort  Memory: 158kB
  Buffers: shared hit=3079740 read=14091398, temp read=109612 written=109896 -- сортировка на диске из-за нехватки work_mem
  ->  Subquery Scan on advanced_metrics  (cost=10327.05..2303063.83 rows=28617 width=127) (actual time=1746.008..108772.904 rows=1557.00 loops=1) -- фильтр в итоговом select (очень дорогой, т.к. не по индексу)
        Filter: ((advanced_metrics.total_revenue > advanced_metrics.avg_route_revenue) AND (advanced_metrics.sold_tickets < (advanced_metrics.max_seats / 2)))
        Rows Removed by Filter: 122514  -- число строк, удалённых условием фильтра
        Buffers: shared hit=3079737 read=14091398, temp read=109612 written=109896
        ->  WindowAgg  (cost=10327.05..2298127.42 rows=257552 width=95) (actual time=1745.877..108751.693 rows=124071.00 loops=1) -- оконная функция итоговом select (очень дорогая) 
              Window: w1 AS (PARTITION BY fm.route_no)
              Storage: Memory  Maximum Storage: 60kB
              Buffers: shared hit=3079737 read=14091398, temp read=109612 written=109896
              ->  Subquery Scan on fm  (cost=10022.62..67083.22 rows=257552 width=59) (actual time=1167.961..103139.117 rows=124071.00 loops=1)
                    Buffers: shared hit=2756399 read=14090767, temp read=109612 written=109896
                    ->  GroupAggregate  (cost=10022.62..64507.70 rows=257552 width=59) (actual time=1167.956..103125.491 rows=124071.00 loops=1)
                          Group Key: r.route_no, f.flight_id, (date(f.scheduled_departure)), r.airplane_code
                          Buffers: shared hit=2756399 read=14090767, temp read=109612 written=109896
                          ->  Incremental Sort  (cost=10022.62..56781.14 rows=257552 width=38) (actual time=1167.799..97931.544 rows=26269408.00 loops=1)
                                Sort Key: r.route_no, f.flight_id, (date(f.scheduled_departure)), r.airplane_code
                                Presorted Key: r.route_no
                                Full-sort Groups: 1718  Sort Method: quicksort  Average Memory: 28kB  Peak Memory: 28kB
                                Pre-sorted Groups: 1707  Sort Method: external merge  Average Disk: 13301kB  Peak Disk: 13560kB
                                Buffers: shared hit=2756399 read=14090767, temp read=109612 written=109896
                                ->  Nested Loop  (cost=9994.03..43999.53 rows=257552 width=38) (actual time=898.006..81677.339 rows=26269408.00 loops=1) -- сравнивает каждую строку первой таблицы с каждой строкой второй таблицы, 
                                                                                                                                                            выводит строки, которые удовлетворяют условию объединения, медленный тип объединения.
                                                                                                                                                            В итоге получаем огромное число строк rows=26269408.
                                      Buffers: shared hit=2756390 read=14090767, temp read=498 written=499
                                      ->  Gather Merge  (cost=9993.59..23535.15 rows=1266 width=23) (actual time=897.896..1000.709 rows=124116.00 loops=1)
                                            Workers Planned: 1
                                            Workers Launched: 1
                                            Buffers: shared hit=149 read=1566, temp read=498 written=499
                                            ->  Merge Join  (cost=8993.58..22392.71 rows=745 width=23) (actual time=811.053..1038.076 rows=62058.00 loops=2) -- используется, если объединяемые наборы данных отсортированы 
                                                                                                                                                                (есть индекс или могут быть отсортированы с небольшими затратами) по ключам объединения
                                                  Merge Cond: (f.route_no = r.route_no)
                                                  Join Filter: (r.validity @> f.scheduled_departure)
                                                  Rows Removed by Join Filter: 783166
                                                  Buffers: shared hit=149 read=1566, temp read=498 written=499
                                                  ->  Sort  (cost=8334.61..8517.14 rows=73011 width=19) (actual time=768.904..780.157 rows=62058.00 loops=2)
                                                        Sort Key: f.route_no
                                                        Sort Method: quicksort  Memory: 62kB
                                                        Buffers: shared hit=6 read=1440, temp read=498 written=499
                                                        Worker 0:  Sort Method: external merge  Disk: 3984kB
                                                        ->  Parallel Seq Scan on flights f  (cost=0.00..2436.85 rows=73011 width=19) (actual time=448.222..721.756 rows=62058.00 loops=2) -- (параллельное последовательное сканирование) – используется несколько ядер процессора
                                                              Filter: (status = ANY ('{Departed,Arrived}'::text[]))
                                                              Rows Removed by Filter: 5728
                                                              Buffers: shared read=1440
                                                  ->  Sort  (cost=658.71..676.82 rows=7242 width=33) (actual time=41.796..84.445 rows=846629.00 loops=2)
                                                        Sort Key: r.route_no
                                                        Sort Method: quicksort  Memory: 589kB -- для узла Sort показывается использованный метод сортировки (Sort Method) и задействованный объём памяти (Memory)
                                                        Buffers: shared hit=122 read=122
                                                        Worker 0:  Sort Method: quicksort  Memory: 589kB
                                                        ->  Seq Scan on routes r  (cost=0.00..194.42 rows=7242 width=33) (actual time=0.079..35.980 rows=7242.00 loops=2) - loops=2 - количество проходов по выборке данных или сколько раз Postgres отсканировал таблицу
                                                              Buffers: shared hit=122 read=122
                                      ->  Index Scan using segments_flight_id_idx on segments s  (cost=0.44..12.82 rows=284 width=23) (actual time=0.015..0.602 rows=211.65 loops=124116) -- индексное сканирование, возвращает значения TID (tuple id – идентификатор строки) по одному, до тех пор, 
                                                                                                                                                                                             пока подходящие строки не закончатся
                                            Index Cond: (flight_id = f.flight_id)
                                            Index Searches: 124116
                                            Buffers: shared hit=2756241 read=14089201
              SubPlan 1
                ->  Aggregate  (cost=8.64..8.65 rows=1 width=8) (actual time=0.044..0.044 rows=1.00 loops=124071) -- общее реальное время, затраченное на этот узел = actual time * loops (0.044 мс * 124 071 = 5 459 мс)
                                                                                                                  -- cost не умножают на loops
                      Buffers: shared hit=323338 read=631
                      ->  Index Only Scan using seats_pkey on seats st  (cost=0.28..8.09 rows=218 width=0) (actual time=0.012..0.031 rows=256.77 loops=124071)   -- (исключительно индексное сканирование) – используется, когда индекс уже содержит все необходимые для запроса данные;
                                                                                                                                                                 -- 0.28 - приблизительная стоимость запуска. Это время, которое проходит, прежде 
                                                                                                                                                                         чем начнётся этап вывода данных, например для сортирующего узла это время сортировки;
                                                                                                                                                                  8.09 - приблизительная общая стоимость для извлечения всех строк;
                                                                                                                                                                  rows = 218 – ожидаемое количество строк, которое запрос способен вернуть (он может 
                                                                                                                                                                               вернуть меньше, например, в случае использования LIMIT);
                                                                                                                                                                  width = 0 – ожидаемый средний размер возвращаемых строк в байтах.
                            Index Cond: (airplane_code = fm.airplane_code)
                            Heap Fetches: 0
                            Index Searches: 124071
                            Buffers: shared hit=323338 read=631
Planning:
  Buffers: shared hit=404 read=32
Planning Time: 84.517 ms --время, затраченное на построение плана запроса и его оптимизацию.
JIT:
  Functions: 54
  Options: Inlining true, Optimization true, Expressions true, Deforming true
  Timing: Generation 3.290 ms (Deform 1.550 ms), Inlining 176.683 ms, Optimization 303.215 ms, Emission 391.158 ms, Total 874.345 ms
Execution Time: 108777.987 ms -- включает продолжительность запуска и остановки исполнителя запроса, а также время выполнения всех сработавших триггеров.
*/

/* 2. Разработайте 3 предложения по оптимизации хранения данных в БД Авиаперелетов.
Для решения приложить обоснования необходимости. Например, если предлагаете добавление индекса - замерьте статистику выполнения, проанализируйте план выполнения.*/
/* Т.к. мы находимся в postgre sql, то можно рекомендовать следующие приемы оптимизации:
1. Использовать материализованные представления для часто выполняемых отчётов с обновлением по расписанию.
2. Партиционирование (например, boarding_passes по диапазону boarding_time (по месяцам, квартилам)).
3. Сделать индексы на даты, т.к. по датам обычно часто происходит фильтрация.
Однако, при добавлении индексов, материализованных представлений увеличивается объем занимаемой памяти. 
Поэтому добавление большого количества индексов, мат. представлений тоже может быть не очень хорошо.
*/

-- Оценка и расчет "3. Сделать индексы на даты, т.к. по датам обычно часто происходит фильтрация"
create temp table temp_flights as
select f.*
from prod.flights f 
-- select * from temp_flights limit 10;
explain analyze
select f.flight_id,
       f.scheduled_departure
from temp_flights f 
where f.scheduled_departure between  date_trunc('day', now()::timestamp) and date_trunc('day', (now() + interval '1 day')::timestamp);
/*
-------------------------------------------------------------
explain analyse:
-------------------------------------------------------------
Seq Scan on temp_flights f  (cost=0.00..4290.88 rows=444 width=12) (actual time=14.508..68.937 rows=183.00 loops=1)
  Filter: ((scheduled_departure >= date_trunc('day'::text, (now())::timestamp without time zone)) AND (scheduled_departure <= date_trunc('day'::text, ((now() + '1 day'::interval))::timestamp without time zone)))
  Rows Removed by Filter: 135388
  Buffers: local hit=338 read=1070 dirtied=1041 written=1041
Planning:
  Buffers: shared hit=16
Planning Time: 0.215 ms
Execution Time: 68.967 ms
*/
create index idx_temp_flights_scheduled_departure on temp_flights (scheduled_departure);

explain analyze
select f.flight_id,
       f.scheduled_departure
from temp_flights f 
where f.scheduled_departure between  date_trunc('day', now()::timestamp) and date_trunc('day', (now() + interval '1 day')::timestamp);
/*
-------------------------------------------------------------
explain analyse:
-------------------------------------------------------------
Bitmap Heap Scan on temp_flights f  (cost=15.39..1202.60 rows=678 width=12) (actual time=0.080..0.176 rows=183.00 loops=1)
  Recheck Cond: ((scheduled_departure >= date_trunc('day'::text, (now())::timestamp without time zone)) AND (scheduled_departure <= date_trunc('day'::text, ((now() + '1 day'::interval))::timestamp without time zone)))
  Heap Blocks: exact=28
  Buffers: local hit=13 read=18
  ->  Bitmap Index Scan on idx_temp_flights_scheduled_departure  (cost=0.00..15.22 rows=678 width=0) (actual time=0.051..0.051 rows=183.00 loops=1)
        Index Cond: ((scheduled_departure >= date_trunc('day'::text, (now())::timestamp without time zone)) AND (scheduled_departure <= date_trunc('day'::text, ((now() + '1 day'::interval))::timestamp without time zone)))
        Index Searches: 1
        Buffers: local read=3
Planning:
  Buffers: shared hit=15, local read=1
Planning Time: 0.263 ms
Execution Time: 0.225 ms
*/
drop index if exists idx_temp_flights_scheduled_departure;
drop table temp_flights;
/*
=============================================================
АНАЛИЗ QUERY PLAN, ВЫВОД
=============================================================
До создания индекса на поле scheduled_departure происходил Seq Scan (последовательное сканирование) – последовательно считывается 
каждая строка таблицы и проверяется на соответствие заданному условию. Наиболее медленный тип сканирования. Время выполнения запроса - Execution Time: 68.967 ms.
После добавления индекса на поле scheduled_departure в плане запроса появился Index Scan по созданному индексу. Время выполнения запроса - Execution Time: 0.225 ms. 
С использованием индекса и Index Scan время выполнения снизилось.
*/