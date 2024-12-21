USE trips_db;

-- Business Request - 1: City-Level Fare and Trip Summary Report 
SELECT 
    dc.city_name,
    COUNT(ft.trip_id) AS total_trips,
    ROUND(SUM(ft.fare_amount) / SUM(ft.distance_travelled_km), 2) AS avg_fare_per_km,
    ROUND(SUM(ft.fare_amount) / COUNT(ft.trip_id), 2) AS avg_fare_per_trip,
    ROUND((COUNT(ft.trip_id) * 100.0) / (SELECT COUNT(*) FROM fact_trips), 2) AS "%_contribution_to_total_trips"
FROM 
    fact_trips ft
JOIN 
    dim_city dc
ON 
    ft.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    total_trips DESC;

----------------------------------------------------------------------------------------------------------------------
-- Business Request - 2: Monthly City-Level Trips Target Performance Report
SELECT 
    dc.city_name,
    dd.month_name,
    trips_per_city_month.actual_trips,
    mt.total_target_trips AS target_trips,
    CASE 
        WHEN trips_per_city_month.actual_trips > mt.total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,
    ROUND((trips_per_city_month.actual_trips - mt.total_target_trips) * 100.0 / mt.total_target_trips, 2) AS "%_difference"
FROM 
    (
		SELECT 
			ft.city_id,
			dd.start_of_month AS month,
			MONTH(dd.start_of_month) as month_num,
			COUNT(ft.trip_id) AS actual_trips
		FROM 
			trips_db.fact_trips ft
		JOIN 
			trips_db.dim_date dd 
		ON 
			ft.date = dd.date
		GROUP BY 
			ft.city_id, dd.start_of_month, MONTH(dd.start_of_month)
    ) trips_per_city_month
JOIN 
    trips_db.dim_city dc 
ON 
    trips_per_city_month.city_id = dc.city_id
JOIN 
    targets_db.monthly_target_trips mt 
ON 
    trips_per_city_month.city_id = mt.city_id 
    AND trips_per_city_month.month = mt.month
JOIN 
    trips_db.dim_date dd
ON 
    trips_per_city_month.month = dd.start_of_month
GROUP BY 
    dc.city_name, dd.month_name, trips_per_city_month.month_num, trips_per_city_month.actual_trips, mt.total_target_trips
ORDER BY 
    dc.city_name, trips_per_city_month.month_num;

----------------------------------------------------------------------------------------------------------------------
-- Business Request - 3: City-Level Repeat Passenger Trip Frequency Report
SELECT 
    dc.city_name,
    ROUND(SUM(CASE WHEN drt.trip_count = '2-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "2-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '3-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "3-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '4-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "4-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '5-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "5-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '6-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "6-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '7-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "7-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '8-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "8-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '9-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "9-Trips",
    ROUND(SUM(CASE WHEN drt.trip_count = '10-Trips' THEN drt.repeat_passenger_count ELSE 0 END) * 100.0 
          / SUM(drt.repeat_passenger_count), 2) AS "10-Trips"
FROM 
    trips_db.dim_repeat_trip_distribution drt
JOIN 
    trips_db.dim_city dc
ON 
    drt.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    dc.city_name;
    
----------------------------------------------------------------------------------------------------------------------    
-- Business Request - 4: Identify Cities with Highest and Lowest Total New
WITH CityTotals AS (
    SELECT 
        dc.city_name,
        SUM(fps.new_passengers) AS total_new_passengers
    FROM 
        trips_db.fact_passenger_summary fps
    JOIN 
        trips_db.dim_city dc
    ON 
        fps.city_id = dc.city_id
    GROUP BY 
        dc.city_name
),
RankedCities AS (
    SELECT 
        city_name,
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers DESC) AS rank_high,
        RANK() OVER (ORDER BY total_new_passengers ASC) AS rank_low
    FROM 
        CityTotals
)
SELECT 
    city_name,
    total_new_passengers,
    CASE 
        WHEN rank_high <= 3 THEN 'Top 3'
        WHEN rank_low <= 3 THEN 'Bottom 3'
        ELSE NULL
    END AS city_category
FROM 
    RankedCities
WHERE 
    rank_high <= 3 OR rank_low <= 3
ORDER BY 
    city_category DESC, 
    total_new_passengers DESC;
    
----------------------------------------------------------------------------------------------------------------------    
-- Business Request - 5: Identify Month with Highest Revenue for Each City
WITH CityMonthlyRevenue AS (
    SELECT 
        dc.city_name,
        dd.month_name,
        SUM(ft.fare_amount) AS monthly_revenue
    FROM 
        trips_db.fact_trips ft
    JOIN 
        trips_db.dim_city dc
    ON 
        ft.city_id = dc.city_id
    JOIN 
        trips_db.dim_date dd
    ON 
        ft.date = dd.date
    GROUP BY 
        dc.city_name, dd.month_name
),
CityTotalRevenue AS (
    SELECT 
        city_name,
        SUM(monthly_revenue) AS total_revenue
    FROM 
        CityMonthlyRevenue
    GROUP BY 
        city_name
),
CityHighestRevenue AS (
    SELECT 
        cmr.city_name,
        cmr.month_name AS highest_revenue_month,
        cmr.monthly_revenue AS revenue,
        ctr.total_revenue,
        ROUND((cmr.monthly_revenue * 100.0 / ctr.total_revenue), 2) AS percentage_contribution
    FROM 
        CityMonthlyRevenue cmr
    JOIN 
        CityTotalRevenue ctr
    ON 
        cmr.city_name = ctr.city_name
    WHERE 
        cmr.monthly_revenue = (
            SELECT MAX(monthly_revenue)
            FROM CityMonthlyRevenue
            WHERE city_name = cmr.city_name
        )
)
SELECT 
    city_name,
    highest_revenue_month,
    revenue,
    percentage_contribution
FROM 
    CityHighestRevenue
ORDER BY 
    city_name;
    
----------------------------------------------------------------------------------------------------------------------    
-- Business Request - 6: Repeat Passenger Rate Analysis
WITH MonthlyRepeatRate AS (
    SELECT
        dc.city_name,
        dd.month_name,
        MONTH(fps.month) as month_num,
        fps.total_passengers,
        fps.repeat_passengers,
        ROUND((fps.repeat_passengers * 100.0 / fps.total_passengers), 2) AS monthly_repeat_passenger_rate
    FROM
        trips_db.fact_passenger_summary fps
    JOIN
        trips_db.dim_city dc
    ON
        fps.city_id = dc.city_id
	JOIN
		trips_db.dim_date dd
	ON
		fps.month = dd.date
),
CityWideRepeatRate AS (
    SELECT
        dc.city_name,
        SUM(fps.total_passengers) AS total_city_passengers,
        SUM(fps.repeat_passengers) AS total_city_repeat_passengers,
        ROUND((SUM(fps.repeat_passengers) * 100.0 / SUM(fps.total_passengers)), 2) AS city_repeat_passenger_rate
    FROM
        trips_db.fact_passenger_summary fps
    JOIN
        trips_db.dim_city dc
    ON
        fps.city_id = dc.city_id
    GROUP BY
        dc.city_name
)
SELECT
    mrr.city_name,
    mrr.month_name as month,
    mrr.total_passengers,
    mrr.repeat_passengers,
    mrr.monthly_repeat_passenger_rate,
    cwr.city_repeat_passenger_rate
FROM
    MonthlyRepeatRate mrr
JOIN
    CityWideRepeatRate cwr
ON
    mrr.city_name = cwr.city_name
ORDER BY
    mrr.city_name, mrr.month_num;
 