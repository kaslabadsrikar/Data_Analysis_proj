--Creates the OLYMPICS_HISTORY table if it doesn't already exist.

CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY
(
    id          INT,
    name        VARCHAR,
    sex         VARCHAR,
    age         VARCHAR,
    height      VARCHAR,
    weight      VARCHAR,
    team        VARCHAR,
    noc         VARCHAR,
    games       VARCHAR,
    year        INT,
    season      VARCHAR,
    city        VARCHAR,
    sport       VARCHAR,
    event       VARCHAR,
    medal       VARCHAR
);

CREATE TABLE IF NOT EXISTS OLYMPICS_HISTORY_NOC_REGIONS
(
    noc         VARCHAR,
    region      VARCHAR,
    notes       VARCHAR
);

--queries to select all records from the OLYMPICS_HISTORY and OLYMPICS_HISTORY_NOC_REGIONS tables

select * from OLYMPICS_HISTORY;
select * from OLYMPICS_HISTORY_NOC_REGIONS;

--1)HOW MANY OLYMPICS GAMES HAVE BEEN HELD?

select count(distinct games) as total_olympic_games from olympics_history;

--2)LIST DOWN ALL OLYMPICS GAMES HELD SO FAR.

select distinct oh.year,oh.season,oh.city from olympics_history oh
order by year;

--3)MENTION THE TOTAL NO OF NATIONS WHO PARTICIPATED IN EACH OLYMPICS GAME?

SELECT games, COUNT(DISTINCT region) AS total_countries
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
GROUP BY games
ORDER BY games;

--4)WHICH YEAR SAW THE HIGHEST AND LOWEST NO OF COUNTRIES PARTICIPATING IN OLYMPICS?

SELECT 
    MIN(CONCAT(games, ' - ', total_countries)) AS Lowest_Countries,
    MAX(CONCAT(games, ' - ', total_countries)) AS Highest_Countries
FROM (
    SELECT games,COUNT(DISTINCT region) AS total_countries
    FROM olympics_history oh
    JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
    GROUP BY games
) AS country_counts;

--5)WHICH NATION HAS PARTICIPATED IN ALL OF THE OLYMPIC GAMES
      
SELECT nr.region AS country
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
GROUP BY nr.region
HAVING COUNT(DISTINCT oh.games) = (
    SELECT COUNT(DISTINCT games)
    FROM olympics_history);

--6)IDENTIFY THE SPORT WHICH WAS PLAYED IN ALL SUMMER OLYMPICS.
      
SELECT sport, COUNT(DISTINCT games) AS no_of_games FROM olympics_history
WHERE season = 'Summer'
GROUP BY sport
HAVING COUNT(DISTINCT games) = 
	(SELECT COUNT(DISTINCT games) FROM olympics_history
    WHERE season = 'Summer');

--7)WHICH SPORTS WERE JUST PLAYED ONLY ONCE IN THE OLYMPICS.

SELECT DISTINCT o.sport, o.games
FROM olympics_history o
JOIN (
    SELECT sport
    FROM olympics_history
    GROUP BY sport
    HAVING COUNT(DISTINCT games) = 1
) AS subquery
ON o.sport = subquery.sport
ORDER BY o.sport;

--8)FETCH THE TOTAL NO OF SPORTS PLAYED IN EACH OLYMPIC GAMES.

SELECT games, COUNT(DISTINCT sport) AS no_of_sports
FROM olympics_history
GROUP BY games
ORDER BY no_of_sports DESC;

--9)FETCH OLDEST ATHLETES TO WIN A GOLD MEDAL

SELECT name, sex, 
       CAST(CASE WHEN age = 'NA' THEN '0' ELSE age END AS int) AS age,
       team, games, city, sport, event, medal
FROM olympics_history
WHERE medal = 'Gold'
ORDER BY age DESC NULLS LAST
LIMIT 1;

--10)FIND THE RATIO OF MALE AND FEMALE ATHLETES PARTICIPATED IN ALL OLYMPIC GAMES.

SELECT CONCAT('1 : ', ROUND(MAX(cnt)::decimal / MIN(cnt), 2)) AS ratio
FROM (
    SELECT sex, COUNT(1) AS cnt FROM olympics_history
    GROUP BY sex
) AS subquery;

--11)Fetch the top 5 athletes who have won the most gold medals.

SELECT name, team, COUNT(*) AS total_gold_medals
FROM olympics_history
WHERE medal = 'Gold'
GROUP BY name, team
ORDER BY total_gold_medals DESC
LIMIT 10;

--12)Fetch the top 5 athletes who have won the most medals (gold/silver/bronze).

SELECT name, team, COUNT(*) AS total_medals
FROM olympics_history
WHERE medal IN ('Gold', 'Silver', 'Bronze')
GROUP BY name, team
ORDER BY total_medals DESC
LIMIT 5;

--13)Fetch the top 5 most successful countries in olympics. Success is defined by no of medals won.

SELECT nr.region AS country, COUNT(*) AS total_medals
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
WHERE medal <> 'NA'
GROUP BY nr.region
ORDER BY total_medals DESC
LIMIT 5;

--14)List down total gold, silver and bronze medals won by each country.

SELECT 
    nr.region AS country,
    COUNT(CASE WHEN oh.medal = 'Gold' THEN 1 END) AS gold,
    COUNT(CASE WHEN oh.medal = 'Silver' THEN 1 END) AS silver,
    COUNT(CASE WHEN oh.medal = 'Bronze' THEN 1 END) AS bronze
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
WHERE oh.medal <> 'NA'
GROUP BY nr.region
ORDER BY gold DESC, silver DESC, bronze DESC;

--15)List down total gold, silver and bronze medals won by each country corresponding to each olympic games.

SELECT oh.games,nr.region AS country,
    COUNT(CASE WHEN oh.medal = 'Gold' THEN 1 END) AS gold,
    COUNT(CASE WHEN oh.medal = 'Silver' THEN 1 END) AS silver,
    COUNT(CASE WHEN oh.medal = 'Bronze' THEN 1 END) AS bronze
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
WHERE oh.medal <> 'NA'
GROUP BY oh.games, nr.region
ORDER BY oh.games, nr.region;

--16)Identify which country won the most gold, most silver and most bronze medals in each olympic games.

WITH medal_counts AS (
    SELECT oh.games,nr.region AS country,
        SUM(CASE WHEN oh.medal = 'Gold' THEN 1 ELSE 0 END) AS gold,
        SUM(CASE WHEN oh.medal = 'Silver' THEN 1 ELSE 0 END) AS silver,
        SUM(CASE WHEN oh.medal = 'Bronze' THEN 1 ELSE 0 END) AS bronze
    FROM olympics_history oh
    JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
    WHERE oh.medal <> 'NA'
    GROUP BY oh.games, nr.region
),
ranked_medals AS (
    SELECT games,country,gold,silver,bronze,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY gold DESC) AS rnk_gold,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY silver DESC) AS rnk_silver,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY bronze DESC) AS rnk_bronze
    FROM medal_counts
)
SELECT games,
    MAX(CASE WHEN rnk_gold = 1 THEN CONCAT(country, ' - ', gold) END) AS Max_Gold,
    MAX(CASE WHEN rnk_silver = 1 THEN CONCAT(country, ' - ', silver) END) AS Max_Silver,
    MAX(CASE WHEN rnk_bronze = 1 THEN CONCAT(country, ' - ', bronze) END) AS Max_Bronze
FROM ranked_medals
GROUP BY games
ORDER BY games;

--17)Identify which country won the most gold, most silver, most bronze medals and the most medals in each olympic games.

WITH medal_counts AS (
    SELECT oh.games,nr.region AS country,
        SUM(CASE WHEN oh.medal = 'Gold' THEN 1 ELSE 0 END) AS gold,
        SUM(CASE WHEN oh.medal = 'Silver' THEN 1 ELSE 0 END) AS silver,
        SUM(CASE WHEN oh.medal = 'Bronze' THEN 1 ELSE 0 END) AS bronze,
        COUNT(1) AS total_medals
    FROM olympics_history oh
    JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
    WHERE oh.medal <> 'NA'
    GROUP BY oh.games, nr.region
),
ranked_medals AS (
    SELECT games,country,gold,silver,bronze,total_medals,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY gold DESC, silver DESC, bronze DESC) AS rnk_gold,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY silver DESC, gold DESC, bronze DESC) AS rnk_silver,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY bronze DESC, gold DESC, silver DESC) AS rnk_bronze,
        ROW_NUMBER() OVER (PARTITION BY games ORDER BY total_medals DESC) AS rnk_total
    FROM medal_counts
)
SELECT games,
    MAX(CASE WHEN rnk_gold = 1 THEN CONCAT(country, ' - ', gold) END) AS Max_Gold,
    MAX(CASE WHEN rnk_silver = 1 THEN CONCAT(country, ' - ', silver) END) AS Max_Silver,
    MAX(CASE WHEN rnk_bronze = 1 THEN CONCAT(country, ' - ', bronze) END) AS Max_Bronze,
    MAX(CASE WHEN rnk_total = 1 THEN CONCAT(country, ' - ', total_medals) END) AS Max_Medals
FROM ranked_medals
GROUP BY games
ORDER BY games;

--18)Which countries have never won gold medal but have won silver/bronze medals?

SELECT nr.region AS country,
    COALESCE(SUM(CASE WHEN oh.medal = 'Gold' THEN 1 ELSE 0 END), 0) AS gold,
    COALESCE(SUM(CASE WHEN oh.medal = 'Silver' THEN 1 ELSE 0 END), 0) AS silver,
    COALESCE(SUM(CASE WHEN oh.medal = 'Bronze' THEN 1 ELSE 0 END), 0) AS bronze
FROM olympics_history oh
JOIN olympics_history_noc_regions nr ON nr.noc = oh.noc
WHERE oh.medal <> 'NA'
GROUP BY nr.region
HAVING SUM(CASE WHEN oh.medal = 'Gold' THEN 1 ELSE 0 END) = 0
   AND (SUM(CASE WHEN oh.medal = 'Silver' THEN 1 ELSE 0 END) > 0 
   OR SUM(CASE WHEN oh.medal = 'Bronze' THEN 1 ELSE 0 END) > 0)
ORDER BY gold DESC NULLS LAST, silver DESC NULLS LAST, bronze DESC NULLS LAST;

--19)In which Sport/event, India has won highest medals.

SELECT sport, total_medals
FROM (
    SELECT sport, COUNT(1) AS total_medals
    FROM olympics_history
    WHERE medal <> 'NA'
    AND team = 'India'
    GROUP BY sport
) AS medal_counts
ORDER BY total_medals DESC
LIMIT 1;

--20)Break down all olympic games where India won medal for Hockey and how many medals in each olympic games

SELECT team, sport, games, total_medals
FROM (
    SELECT team, sport, games, COUNT(1) AS total_medals
    FROM olympics_history
    WHERE medal <> 'NA'
    AND team = 'India'
    AND sport = 'Hockey'
    GROUP BY team, sport, games
) AS medal_summary
ORDER BY total_medals DESC;

