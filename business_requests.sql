USE trips_db;

/* Business Request - 1: City-Level Fare and Trip Summary Report 
Generate a report that displays the total trips, average fare per km, average fare per trip, and 
the percentage contribution of each city’s trips to the overall trips. */

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
   
    
/* Business Request - 2: Monthly City-Level Trips Target Performance Report 
Generate a report that evaluates the target performance for trips at the monthly and city 
level.*/ 

 WITH CTE1 AS (
	SELECT 
		ft.city_id,
		dc.city_name,
		MONTH(ft.date) AS trip_month_num,
		MONTHNAME(ft.date) AS month_name, 
		ft.trip_id
	FROM 
		fact_trips ft
	JOIN 
		dim_city dc ON ft.city_id = dc.city_id
)
SELECT 
	c.city_name,
	c.month_name,
	COUNT(c.trip_id) AS actual_trips,
	mtt.total_target_trips AS target_trips,
	CASE
		WHEN COUNT(c.trip_id) >= mtt.total_target_trips THEN 'Above Target'
		ELSE 'Below Target'
	END AS Performance_Status,
	CASE 
		WHEN mtt.total_target_trips = 0 THEN 'N/A'
		ELSE CONCAT(ROUND(((COUNT(c.trip_id) - mtt.total_target_trips) / mtt.total_target_trips) * 100, 2), '%')
	END AS percentage_difference
FROM 
	CTE1 c
JOIN 
	targets_db.monthly_target_trips mtt
	ON c.city_id = mtt.city_id
	AND c.trip_month_num = MONTH(mtt.month) 
GROUP BY 
	c.city_name,
	c.month_name,
	c.trip_month_num,
	mtt.total_target_trips
ORDER BY 
	c.city_name,
	c.trip_month_num;
   
/* Business Request - 3: City-Level Repeat Passenger Trip Frequency Report 
Generate a report that shows the percentage distribution of repeat passengers by the 
number of trips they have taken in each city. Calculate the percentage of repeat passengers 
who took 2 trips, 3 trips, and so on, up to 10 trips. */      
   
WITH CTE1 AS (
	select
		city_id, 
		trip_count, 
		sum(repeat_passenger_count) as Total_RP
	from  
		dim_repeat_trip_distribution
	group by 
		city_id, 
		trip_count
),
	CTE2 AS(
	select 
		city_id, 
		trip_count, 
		Total_RP, 
		sum(Total_RP) over (partition by city_id) as City_total_RP,
		concat(Cast((Total_RP/sum(Total_RP) over (partition by city_id)) * 100 as decimal(6,2)),'%') AS `%_Contribution`
	from CTE1
	group by city_id, trip_count)
SELECT 
	city_name,
    MAX(CASE WHEN trip_count = '2-trips'  THEN `%_Contribution` ELSE 0 END) AS '2-trips',
    MAX(CASE WHEN trip_count = '3-trips'  THEN `%_Contribution` ELSE 0 END) AS '3-trips',
    MAX(CASE WHEN trip_count = '4-trips'  THEN `%_Contribution` ELSE 0 END) AS '4-trips',
    MAX(CASE WHEN trip_count = '5-trips'  THEN `%_Contribution` ELSE 0 END) AS '5-trips',
    MAX(CASE WHEN trip_count = '6-trips'  THEN `%_Contribution` ELSE 0 END) AS '6-trips',
    MAX(CASE WHEN trip_count = '7-trips'  THEN `%_Contribution` ELSE 0 END) AS '7-trips',
    MAX(CASE WHEN trip_count = '8-trips'  THEN `%_Contribution` ELSE 0 END) AS '8-trips',
    MAX(CASE WHEN trip_count = '9-trips'  THEN `%_Contribution` ELSE 0 END) AS '9-trips',
    MAX(CASE WHEN trip_count = '10-trips' THEN `%_Contribution` ELSE 0 END) AS '10-trips'
FROM 
    CTE2
join dim_city on CTE2.city_id=dim_city.city_id
GROUP BY 
	city_name
ORDER BY 
	city_name;
   
/* Business Request - 4: Identify Cities with Highest and Lowest Total New Passengers 
Generate a report that calculates the total new passengers for each city and ranks them 
based on this value. */

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
     
 
/* Business Request - 5: Identify Month with Highest Revenue for Each City 
Generate a report that identifies the month with the highest revenue for each city. For each 
city, display the month_name, the revenue amount for that month, and the percentage 
contribution of that month’s revenue to the city’s total revenue. */

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
    

/* Business Request - 6: Repeat Passenger Rate Analysis 
Generate a report that calculates two metrics: 

1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city 
and month by comparing the number of repeat passengers to the total passengers.
2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for 
each city, considering all passengers across months.
 
These metrics will provide insights into monthly repeat trends as well as the overall repeat 
behaviour for each city.*/

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
      