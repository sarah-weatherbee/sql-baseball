-- 1. What range of years does the provided database cover?
select min(birthyear)
from people;

select max(deathyear)
from people;
--1820 - 2017

/*or*/
select min(yearid) as min_year,
max(yearid) as max_year,
max(yearid) - min(yearid) as total_years
from batting;

/*Find the name and height of the shortest player in the database. 
How many games did he play in? What is the name of the team for which he played?*/
with shortest_player as (
	select p.namefirst || ' ' || p.namelast as full_name, p.height, p.playerid
	from people as p
	order by p.height
	limit 1
	)
select a.teamid, a.playerid, s.height, s.full_name, t.name, t.g 
from appearances as a
inner join shortest_player as s 
on a.playerid = s.playerid
inner join teams as t
on a.teamid = t.teamid AND a.yearid = t.yearid;
--Edward Gaedel, 43" height, Team: St. Louis Browns, num of games= 154

/*Find all players in the database who played at Vanderbilt University. 
Create a list showing each player’s first and last names as well as the total salary 
they earned in the major leagues. Sort this list in descending order by the total salary earned. 
Which Vanderbilt player earned the most money in the majors?*/
select p.namefirst, p.namelast, sum(s.salary) as total_salary
from people as p
join salaries as s
on s.playerid = p.playerid
where p.playerid in(
select distinct (playerid)
from collegeplaying
where schoolid = 'vandy')
group by p.namefirst, p.namelast
order by total_salary desc;
--David Price earned the most money: 81,851,296

/*or*/

with vandy_players as (
select distinct playerid
from collegeplaying
where schoolid = 'vandy')

select vp.playerid, p.namefirst, p.namelast, sum(salary) as total_sal
from vandy_players vp
inner join people p using(playerid)
inner join salaries s on vp.playerid = s.playerid
group by vp.playerid, p.namefirst, p.namelast
order by total_sal desc;

/*Using the fielding table, group players into three groups based on their position: 
label players with position OF as "Outfield", those with position "SS", "1B", "2B", 
and "3B" as "Infield", and those with position "P" or "C" as "Battery". 
Determine the number of putouts made by each of these three groups in 2016.*/
SELECT yearid, SUM(po) AS total_putouts,
	CASE 
		WHEN pos = 'OF' THEN 'Outfield'
		WHEN pos = 'SS' OR pos = '1B' OR pos = '2B' OR pos = '3B' THEN 'Infield'
		WHEN pos = 'P' OR pos = 'C' THEN 'Battery'
	END AS field_group
FROM fielding
WHERE yearid = 2016
GROUP BY yearid, field_group
ORDER BY total_putouts DESC;

--Infield: 58,934, Battery: 41,424, Outfield: 29560


/*Find the average number of strikeouts per game by decade since 1920. 
Round the numbers you report to 2 decimal places. Do the same for home runs per game. 
Do you see any trends?*/
SELECT TRUNC(yearid, -1) AS decade, ROUND(AVG(so), 2) AS avg_strikeouts,
ROUND(AVG(hr), 2) AS avg_homeruns
FROM battingpost
WHERE TRUNC(yearid, -1) >= 1920
GROUP BY decade
ORDER BY decade;

--There appears to be a positive correlation between average strikeouts and average homeruns.

/*or*/
select date_part('decade', to_date(yearid::varchar, 'YYYY')) as decade,
sum(so) as total_so,
sum(hr) as total_hr,
sum(g) /2 as game_count
round(sum(so) / (sum(g)::numeric/2),2) as avg_so_per_game,
round(sum(hr) / (sum(g)::numeric/2),2) as avg_hr_per_game

from teams
where yearid >= 1920
group by decade
order by decade
;

/*Find the player who had the most success stealing bases in 2016, 
where success is measured as the percentage of stolen base attempts which are successful. 
(A stolen base attempt results either in a stolen base or being caught stealing.) 
Consider only players who attempted at least 20 stolen bases.*/

Select yearid, namefirst, namelast, stolen_bases, steal_attempts, 
100 * (stolen_bases/steal_attempts) as stolen_percent
From
(Select b.yearid, p.namefirst, p.namelast, cast(b.sb as float) as stolen_bases, 
 cast(sum(b.sb + b.cs) as float) as steal_attempts
From batting as b
Inner Join people as p
on b.playerid = p.playerid
group by p.namefirst, p.namelast, b.sb, b.yearid) as subquery
where stolen_bases is not null and steal_attempts is not null and steal_attempts >= 20
and yearid = 2016
order by stolen_percent desc;
--Chris Owings at 91.3% had the most success stealing bases in 2016.

/*or*/

select p.playerid, p.namefirst, p.namelast, sb as stolen_bases, cs as caught_stealing, sb + cs as attempts, round(sb / (sb + cs)::numeric * 100,3) as success_rate
from batting
inner join people p on batting.playerid = p.playerid
where yearid = 2016
and sb + cs >= 20
order by success_rate desc
limit 5;


/*From 1970 – 2016, what is the largest number of wins for a team that did not win 
the world series?*/
select yearid, name as team_name, max(w) as wins, g as games
from teams
where yearid >= 1970 and yearid <= 2016
and wswin = 'N'
group by name, yearid, g
order by wins desc;
--For a team that did not win the world series, Seattle had the most wins at 116 in 2001.--

/*What is the smallest number of wins for a team that did win the 
world series? Doing this will probably result in an unusually small number of wins 
for a world series champion – determine why this is the case. Then redo your query, 
excluding the problem year.*/ 

select name, yearid, min(w) as wins, g as games
from teams
where yearid >= 1970 and yearid <= 2016
and wswin = 'Y'
group by yearid, name, g
order by wins;
/*The LA Dodgers won the World Series in 1981. They won 63 out of 110 games played that year; 
a players strike in 1981 shortened the season, which likely explains the unusually small number of wins for a world series champion*/
select name, yearid, min(w) as wins, g as games
from teams
where yearid >= 1970 and yearid <= 2016 and yearid != 1981
and wswin = 'Y'
group by yearid, name, g
order by wins;
/*Redoing the query to exclude 1981, the St. Louis Cardinals won the World Series in 2006.
That year, they had 83 wins out of 161 games played.*/

/*or*/
with yearly_rank as (
select teamid, yearid, wswin, w, row_number() over (partition by yearid, wswin order by w desc) as rank
from teams
where yearid between 1970 and 2016)
select *
from
(
	select *, 'max_wins_no_ws' as category 
	from yearly_rank 
where rank = 1 and wswin = 'N'
order by w desc
limit = 1
	
	)
	Union all
(
	select *, 'max_wins_no_ws' as category 
	from yearly_rank 
where rank = 1 and wswin = 'Y'and yearid != 1981
order by w 
limit = 1;

) as sub



/*How often from 1970 – 2016 was it the case that a team with 
the most wins also won the world series? What percentage of the time?*/
with most_wins_by_year as (
    with win_ranks as (
        select
               yearid,
               teamid,
               w,
               wswin,
               row_number() over (partition by yearid order by w desc, wswin desc) as rank
        from teams
        where yearid between 1970 and 2016
    )
    select yearid, teamid
    from win_ranks
    where rank = 1
),
ws_wins_by_year as (
    select yearid, teamid
    from teams
    where wswin = 'Y'
        and yearid between 1970 and 2016
    group by yearid, teamid
)
select count(distinct mwby.yearid),
       2017 - 1970 - 1 as total_years,
       round(count(distinct mwby.yearid) / (2017 - 1970 - 1)::numeric, 2) * 100 as pct_did_win
from most_wins_by_year mwby
inner join ws_wins_by_year wwby
    on mwby.yearid = wwby.yearid
           AND mwby.teamid = wwby.teamid;
/*From 1970 – 2016, it the case that a team with 
the most wins also won the world series 26% of the years.*/

/*Using the attendance figures from the homegames table, 
find the teams and parks which had the top 5 average attendance per game in 2016 
(where average attendance is defined as total attendance divided by number of games). 
Only consider parks where there were at least 10 games played. Report the park name, team name, 
and average attendance. Repeat for the lowest 5 average attendance.*/

select  p.park_name,  
t.name,
sum(h.attendance) as total_attendance, 
sum(games) as total_games, 
sum(h.attendance)/sum(games) as avg_attendance_per_game
from homegames h
inner join parks p on h.park = p.park
inner join teams t on h.year = t.yearid and h.team = t.teamid
where year = 2016
group by p.park_name, t.name
having sum(games) >= 10
order by avg_attendance_per_game desc
limit 5;

select  p.park_name,  
t.name,
sum(h.attendance) as total_attendance, 
sum(games) as total_games, 
sum(h.attendance)/sum(games) as avg_attendance_per_game
from homegames h
inner join parks p on h.park = p.park
inner join teams t on h.year = t.yearid and h.team = t.teamid
where year = 2016
group by p.park_name, t.name
having sum(games) >= 10
order by avg_attendance_per_game
limit 5;

/*Which managers have won the TSN Manager of the Year award in both the National League (NL) 
and the American League (AL)? Give their full name and the teams that they were managing when 
they won the award.*/

with nl_managers as (
select playerid, yearid
from awardsmanagers
where lgid = 'NL' and awardid = 'TSN Manager of the Year'
group by playerid, yearid
),
al_managers as (
select playerid, yearid
from awardsmanagers
where lgid = 'AL' and awardid = 'TSN Manager of the Year'
group by playerid, yearid
	)
	select al_m.playerid, p.namefirst || '' || p.namelast as full_name, m.yearid, m.teamid
	from nl_managers nl_m
	inner join al_managers al_m using(playerid)
	inner join people p using(playerid)
	left join managers m on p.playerid = m.playerid and (m.yearid = al_m.yearid or m.yearid = nl_m.yearid)
	group by al_m.playerid, full_name, m.yearid, teamid
	order by al_m.playerid, yearid;
	
/* Davey Johnson in 1997 with team BAL
   Davey Johnson in 2012 with team WAS
   Jim Leyland in 1988 with team PIT
   Jim Leyland in 1990 with team PIT
   Jim Leyland in 2006 with team DET*/



