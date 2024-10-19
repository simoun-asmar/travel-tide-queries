/*
Question #1:
return users who have booked and completed at least 10 flights, ordered by user_id.

Expected column names: `user_id`
*/

-- q1 solution:

SELECT 
	  user_id
FROM 
		sessions 
WHERE 
		flight_booked = 'true'
		AND
    cancellation = 'false'			
GROUP BY 
		1
HAVING
		COUNT(trip_id) >= 10
ORDER
		BY 1
;


/*

Question #2: 
Write a solution to report the trip_id of sessions where:

1. session resulted in a booked flight
2. booking occurred in May, 2022
3. booking has the maximum flight discount on that respective day.

If in one day there are multiple such transactions, return all of them.

Expected column names: `trip_id`

*/

-- q2 solution:

WITH filtered_sessions AS ( --- Filtering the data, to include only the data we need. 
SELECT	*
FROM sessions
WHERE flight_booked = 'true'
			AND DATE_TRUNC('month', session_start) = '2022-05-01'
      AND flight_discount = 'true'
      AND flight_discount_amount IS NOT NULL
),     

ranked AS ( --- Rank the flights per day, ordering by the highest discount for each day (highest first).
SELECT
			trip_id,
      flight_discount_amount,
     DENSE_rank() OVER (PARTITION BY DATE_TRUNC('day', session_start) ORDER BY flight_discount_amount DESC) AS rank

FROM filtered_sessions
) 
SELECT      ----- Select the trip IDs where the flight discount is the highest for each day
			trip_id
FROM ranked
WHERE rank = 1
;
/*
Question #3: 
Write a solution that will, for each user_id of users with greater than 10 flights, 
find out the largest window of days between 
the departure time of a flight and the departure time 
of the next departing flight taken by the user.

Expected column names: `user_id`, `biggest_window`

*/

-- q3 solution:

WITH filtered_users AS   --- Filtering the data, to include only the data we need 
(SELECT              
			 user_id

FROM sessions 

WHERE flight_booked = 'true' 	
GROUP BY 1
HAVING COUNT(trip_id) > 10
ORDER BY 1
),
window_rang AS (  -- Calculate the difference in days between consecutive flights for each user
SELECT
         u.user_id,
         f.departure_time::DATE AS current_date, --- Current flight's departure date
         lag(f.departure_time,1) OVER (PARTITION BY u.user_id ORDER BY f.departure_time)::DATE AS previous_date, --- Previous flight's departure date for the same user
         f.departure_time::DATE - lag(f.departure_time,1) OVER (PARTITION BY u.user_id ORDER BY f.departure_time)::DATE AS date_diff -- Difference in days between current and previous flight
    FROM 
              
FROM filtered_users AS u  ---- Join filtered users from the first CTE
JOIN sessions AS s ON u.user_id = s.user_id
JOIN flights AS f ON f.trip_id = s.trip_id
ORDER BY 1,2
)     
SELECT                   ---Find the largest gap (in days) between flights for each user
			user_id,
      MAX(date_diff) AS biggest_window
      
FROM window_rang
GROUP BY 1
;

/*
Question #4: 
Find the user_id’s of people whose origin airport is Boston (BOS) 
and whose first and last flight were to the same destination. 
Only include people who have flown out of Boston at least twice.

Expected column names: user_id
*/

-- q4 solution:

WITH first_last_flight AS ( -- Filtering the Data and Calculate the first and last flight dates for each user
    SELECT
        s.user_id,
        MIN(f.departure_time) AS first_date,
        MAX(f.departure_time) AS last_date
    FROM 
        sessions AS s
    JOIN 
        flights AS f ON s.trip_id = f.trip_id 
    WHERE 
        f.origin_airport = 'BOS'
        AND s.cancellation = 'false'
        AND s.flight_booked = 'true'
    GROUP BY 
        s.user_id
    HAVING 
        COUNT(f.trip_id) >= 2
),
first_destination AS(     --Retrieve the destination of the FIRST flight for each user
    SELECT
        flf.user_id,
        f.destination_airport AS first_destination
    FROM 
        first_last_flight AS flf   --Join the Filtered first_last_flight CTE to find the FIRST flight's destination
    JOIN 
        sessions AS s ON s.user_id = flf.user_id
    JOIN 
        flights AS f ON f.trip_id = s.trip_id
    WHERE 
        f.departure_time = flf.first_date
),
last_destination AS (  -- Retrieve the destination of the Last flight for each user
    SELECT
        flf.user_id,
        f.destination_airport AS last_destination
    FROM 
        first_last_flight AS flf  ----Join the Filtered first_last_flight CTE to find the LAST flight's destination
    JOIN 
        sessions AS s ON s.user_id = flf.user_id
    JOIN 
        flights AS f ON f.trip_id = s.trip_id
    WHERE 
        f.departure_time = flf.last_date
)
SELECT                         ---Select users whose first and last destinations match
    DISTINCT ld.user_id
FROM 
    first_destination AS fd     --- Use the first_destination CTE
JOIN 
    last_destination AS ld ON fd.user_id = ld.user_id  --- Join with last_destination CTE on user ID

WHERE 
    fd.first_destination = ld.last_destination     ------ Only include users whose first and last destinations are the same
;
