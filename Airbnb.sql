CREATE DATABASE Airbnb_db;

-- We will insert tables (which are in csv format) here by table data import wizard method, not using infile method.

-- 1. How many records are there in the dataset?
SELECT Count(*) AS Total_records
FROM fact_data; 

-- 2. How many unique cities are in the European dataset?
SELECT Count(DISTINCT city) AS Total_unique_cities
FROM dim_city; 

-- 3. What are the names of the cities in the dataset?
SELECT DISTINCT city
FROM dim_city; 

-- 4. How many bookings are there in each city?
	-- First we should change the name of ï»¿CityID and ï»¿ID columns into CityID and ID 
	-- and change the datatype of CityID, ID, DayTypeID and roomtypeID columns from INT to TEXT.
		ALTER TABLE dim_city 
		CHANGE COLUMN `ï»¿CityID` `CityID` TEXT;
		ALTER TABLE fact_data 
		CHANGE COLUMN `ï»¿ID` `ID` TEXT;
		ALTER TABLE fact_data
		MODIFY COLUMN DayTypeID TEXT;
		ALTER TABLE fact_data
		MODIFY COLUMN roomtypeID TEXT;

SELECT dc.city, Count(*) AS total_bookings_in_each_cities
FROM fact_data fd
JOIN dim_city dc
ON fd.id = dc.cityid
GROUP BY dc.city
ORDER BY total_bookings_in_each_cities DESC; 

-- 5. What is the total booking revenue for each city?
SELECT dc.city, Round(Sum(fd.price)) AS total_revenue
FROM fact_data fd
JOIN dim_city dc
ON fd.id = dc.cityid
GROUP BY dc.city
ORDER BY total_revenue DESC;

-- 6. What is the average guest satisfaction score for each city?
SELECT dc.city, Round(Avg(fd.`guest satisfaction`)) AS average_score
FROM fact_data fd
JOIN dim_city dc
ON fd.id = dc.cityid
GROUP BY dc.city
ORDER BY average_score DESC;

-- 7. What are the minimum, maximum, average, and median booking prices?
WITH cte AS (SELECT price, Ntile(2) OVER (ORDER BY price) AS Tile
			FROM fact_data)
SELECT Round(Min(price)) AS MinPrice,
       Round(Max(price)) AS MaxPrice,
       Round(Avg(price)) AS AvgPrice,
       Round(( Max(CASE WHEN tile = 1 THEN price END) + Min(CASE WHEN tile = 2 THEN price END) ) / 2.0) AS MedianPrice
FROM cte;

-- 8. How many outliers are there in the price field?
WITH cte1 AS (SELECT price, Ntile(4) OVER (ORDER BY price) AS Quartile
			 FROM fact_data),
     cte2 AS (SELECT Min(CASE WHEN quartile = 1 THEN price END) AS Q1, Max(CASE WHEN quartile = 3 THEN price END) AS Q3
			 FROM cte1),
     cte3 AS (SELECT q1, q3, ( q3 - q1 ) AS IQR, q1 - 1.5 * ( q3 - q1 ) AS LowerBound, q3 + 1.5 * ( q3 - q1 ) AS UpperBound
			 FROM cte2)
SELECT Count(*) AS OutlierCount
FROM fact_data
CROSS JOIN cte3
WHERE price < lowerbound OR price > upperbound;

-- 9. What are the characteristics of the outliers in terms of room type, number of bookings, and price?
	-- First we should change the name of Room Type and ï»¿roomtypeID columns of dim_roomtype table into RoomType and RoomTypeID.
		ALTER TABLE dim_roomtype 
		CHANGE COLUMN `Room Type` `RoomType` TEXT;
		ALTER TABLE dim_roomtype 
		CHANGE COLUMN `ï»¿roomtypeID` `RoomTypeID` TEXT;
        
WITH cte1 AS (SELECT price, RoomTypeID, ntile(4) over (ORDER BY price) AS quartile
			 FROM fact_data),
	 cte2 AS (SELECT min(CASE WHEN quartile = 1 THEN price end) AS q1, max(CASE WHEN quartile = 3 THEN price end) AS q3
			 FROM cte1),
	 cte3 AS (SELECT q1, q3, (q3 - q1) AS iqr, (q1 - 1.5 * (q3 - q1)) AS lower_bound, (q3 + 1.5 * (q3 - q1)) AS upper_bound
			 FROM cte2),
	 cte_outliers AS (SELECT fd.RoomTypeID, fd.price
             FROM fact_data AS fd
             CROSS JOIN cte3
             WHERE fd.price < cte3.lower_bound
             OR fd.price > cte3.upper_bound)
  SELECT   drt.RoomType AS room_type, 
		   count(co.RoomTypeID) AS booking_count, 
	       round(min(co.price), 2) AS minimum_price,
		   round(max(co.price), 2) AS maximum_price,
           round(avg(co.price), 2) AS average_price
  FROM cte_outliers AS co
  JOIN dim_roomtype AS drt
  ON co.RoomTypeID = drt.RoomTypeID
  GROUP BY room_type;

-- 10. How does the average price differ between the main dataset and the dataset with outliers removed?
CREATE VIEW cleaned_data AS
  WITH cte1 AS (SELECT price, roomtypeid, Ntile(4) OVER (ORDER BY price) AS Quartile
			   FROM fact_data),
       cte2 AS (SELECT Min(CASE WHEN quartile = 1 THEN price END) AS Q1, Max(CASE WHEN quartile = 3 THEN price END) AS Q3
			   FROM cte1),
       cte3 AS (SELECT q1, q3, (q3 - q1) AS IQR, (q1 - 1.5 * (q3 - q1)) AS Lower_Bound, (q3 + 1.5 * (q3 - q1)) AS Upper_Bound
               FROM cte2)
  SELECT *
  FROM fact_data
  WHERE price BETWEEN (SELECT lower_bound FROM cte3) AND (SELECT upper_bound FROM cte3);

WITH mainaverage AS (SELECT Round(Avg(price), 2) AS main_average_price
					FROM fact_data),
     cleanedaverage AS (SELECT Round(Avg(price), 2) AS cleaned_average_price
				       FROM cleaned_data)
SELECT mainaverage.main_average_price,
       cleanedaverage.cleaned_average_price,
       Round(mainaverage.main_average_price - cleanedaverage.cleaned_average_price, 2) AS average_price_difference
FROM mainaverage, cleanedaverage;

-- 11. What is the average price for each room type?
SELECT drt.RoomType, Round(Avg(price), 2) AS avg_price
FROM fact_data AS fd
JOIN dim_roomtype AS drt
ON fd.roomtypeid = drt.RoomTypeID
GROUP BY drt.RoomType;

-- 12. How do weekend and weekday bookings compare in terms of average price and number of bookings?
	-- First we should change the name of ï»¿DayTypeID column of dim_daytype table into DayTypeID.
		ALTER TABLE dim_daytype 
		CHANGE COLUMN `ï»¿DayTypeID` `DayTypeID` TEXT;
        
SELECT ddt.DayType, Round(Avg(fd.price), 2) AS avg_price, Count(fd.id) AS number_of_bookings
FROM fact_data AS fd
JOIN dim_daytype AS ddt
ON fd.DayTypeID = ddt.DayTypeID
GROUP BY ddt.DayType;

-- 13. What is the average distance from metro and city center for each city?
SELECT dc.city, Round(Avg(`metro distance (km)`), 2) AS AvgMetroDistance_Km, Round(Avg(`city center (km)`), 2) AS AvgCityCenterDistance_Km
FROM fact_data fd
JOIN dim_city dc
ON fd.id = dc.cityid
GROUP BY dc.city;

-- 14. How many bookings are there for each room type on weekdays vs weekends?
SELECT ddt.DayType, CASE WHEN fd.roomtypeID = 1 THEN 'Private Room'
						 WHEN fd.roomtypeID = 2 THEN 'Entire home/apt'
						 WHEN fd.roomtypeID = 3 THEN 'Shared Room' end AS Room_Type, Count(fd.ID) AS BookingCount
FROM fact_data fd
JOIN dim_daytype ddt
ON fd.DayTypeID = ddt.DayTypeID
JOIN dim_roomtype drt
ON fd.roomtypeID = drt.RoomTypeID
GROUP BY ddt.DayType, Room_Type;

-- 15. What is the booking revenue for each room type on weekdays vs weekends?
SELECT ddt.DayType, CASE WHEN fd.roomtypeID = 1 THEN 'Private Room'
						 WHEN fd.roomtypeID = 2 THEN 'Entire home/apt'
						 WHEN fd.roomtypeID = 3 THEN 'Shared Room' end AS Room_Type, Round(Sum(fd.Price)) AS booking_revenue
FROM fact_data fd
JOIN dim_daytype ddt
ON fd.DayTypeID = ddt.DayTypeID
JOIN dim_roomtype drt
ON fd.roomtypeID = drt.RoomTypeID
GROUP BY ddt.DayType, Room_Type;

-- 16. What is the overall average, minimum, and maximum guest satisfaction score?
SELECT Round(Avg(`Guest Satisfaction`)) AvgGuestSatisfactionScore,
       Round(Min(`Guest Satisfaction`)) MinGuestSatisfactionScore,
       Round(Max(`Guest Satisfaction`)) MaxGuestSatisfactionScore
FROM fact_data;

-- 17. How does guest satisfaction score vary by city?
SELECT dc.City, Round(Avg(`Guest Satisfaction`)) AvgGuestSatisfactionScore,
				Round(Min(`Guest Satisfaction`)) MinGuestSatisfactionScore,
				Round(Max(`Guest Satisfaction`)) MaxGuestSatisfactionScore
FROM fact_data fd
JOIN dim_city dc
ON fd.ID = dc.CityID
GROUP BY dc.City;

-- 18. What is the average booking value across all cleaned data?
SELECT Round(Avg(price)) AvgBookingValue
FROM cleaned_data;

-- 19. What is the average cleanliness score across all cleaned data?
SELECT Round(Avg(`cleanliness rating`)) AvgCleanlinessScore
FROM cleaned_data;

-- 20. How do cities rank in terms of total revenue?
SELECT Row_number() OVER(ORDER BY Round(Sum(fd.Price)) DESC) CityRank, dc.City, Round(Sum(fd.Price)) total_revenue
FROM fact_data fd
JOIN dim_city dc
ON fd.ID = dc.CityID
GROUP BY dc.City;