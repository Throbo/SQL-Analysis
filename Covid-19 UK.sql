--UK gov datasets

SELECT *
FROM PortfolioProject..[Covid-19 gov new cases by day nations]

SELECT *
FROM PortfolioProject..[Covid-19 gov death date nation]

SELECT *
FROM PortfolioProject..[Covid-19 gov vaccine by day nation]

SELECT *
FROM PortfolioProject..[Covid-19 gov adm by day nation]

SELECT *
FROM PortfolioProject..[Covid-19 gov adm by day nhs region]

SELECT *
FROM PortfolioProject.dbo.[UK population]

-- Analysis in UK nations

-- 1 UK National Total Cases, Total Deaths, Total Deaths & Death Rate by Date

SELECT 
    c.Date,
    SUM(c.Cases) AS National_new_cases,
    SUM(d.Deaths) AS National_deaths,
    SUM(SUM(c.Cases)) OVER (ORDER BY c.Date) AS National_total_cases,
    SUM(SUM(d.Deaths)) OVER (ORDER BY c.Date) AS National_total_deaths
FROM PortfolioProject.dbo.[Covid-19 gov new cases by day nations] c
JOIN PortfolioProject.dbo.[Covid-19 gov death date nation] d
    ON c.Nation = d.Nation
   AND c.Date = d.Date
GROUP BY c.Date
ORDER BY c.Date;

-- 2 Total Cases & Deaths by Nation

SELECT 
    c.Nation,
    c.Date,
    SUM(c.Cases) AS Daily_new_cases,
    SUM(d.Deaths) AS Daily_deaths,
    SUM(SUM(c.Cases)) OVER (PARTITION BY c.Nation ORDER BY c.Date) AS Total_cases_to_date,
    SUM(SUM(d.Deaths)) OVER (PARTITION BY c.Nation ORDER BY c.Date) AS Total_deaths_to_date
FROM PortfolioProject..[Covid-19 gov new cases by day nations] c
JOIN PortfolioProject..[Covid-19 gov death date nation] d
    ON c.Nation = d.Nation
   AND c.Date = d.Date
GROUP BY c.Nation, c.Date
ORDER BY c.Nation, c.Date;

-- 3 Death% (Deaths/Cases) by Nation

SELECT 
    c.Nation AS nation,
    SUM(c.Cases) AS total_cases,
    SUM(d.Deaths) AS total_deaths,
    (SUM(CAST(d.Deaths AS FLOAT)) / NULLIF(SUM(c.Cases), 0)) * 100 AS death_percentage
FROM PortfolioProject..[Covid-19 gov new cases by day nations] c
JOIN PortfolioProject..[Covid-19 gov death date nation] d
    ON c.Nation = d.Nation
   AND c.Date = d.Date
GROUP BY c.Nation
ORDER BY death_percentage DESC;

-- 4 Infection rate relative to population

SELECT 
    c.Nation AS nation,
    p.Population,
    SUM(c.Cases) AS total_cases,
    (SUM(CAST(c.Cases AS FLOAT)) / NULLIF(p.Population, 0)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..[Covid-19 gov new cases by day nations] c
JOIN PortfolioProject..[UK population] p
    ON c.Nation = p.Nation
GROUP BY c.Nation, p.Population
ORDER BY PercentPopulationInfected DESC;

-- 5 Rolling Total of Vaccinations Per Country

SELECT 
    v.Nation,
    v.Date,
    v.Vaccine,
    SUM(CONVERT(bigint, v.Vaccine)) OVER (
        PARTITION BY v.Nation 
        ORDER BY v.Nation, v.Date
    ) AS RollingPeopleVaccinated
FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
ORDER BY v.Nation, v.Date;

-- 6 Countries With the Highest Infection Rate vs Population

SELECT
    c.Nation AS nation,
    p.Population,
    SUM(c.Cases) AS total_cases,
    (SUM(CAST(c.Cases AS FLOAT)) / NULLIF(p.Population, 0)) * 100 AS PercentPopulationInfected
FROM PortfolioProject..[Covid-19 gov new cases by day nations] c
JOIN PortfolioProject..[UK population] p
    ON c.Nation = p.Nation
GROUP BY c.Nation, p.Population
ORDER BY PercentPopulationInfected DESC;

-- 7 % of Population Vaccinated Over time

WITH PopVsVaccination AS (
    SELECT 
        v.Nation AS Nation,
        v.Date,
        p.Population,
        v.Vaccine AS new_vaccinations,
        SUM(CONVERT(bigint, v.Vaccine)) OVER (
            PARTITION BY v.Nation 
            ORDER BY v.Nation, v.Date
        ) AS RollingPeopleVaccinated
    FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
    JOIN PortfolioProject..[UK population] p
        ON v.Nation = p.Nation
)
SELECT 
    Nation,
    Date,
    Population,
    RollingPeopleVaccinated,
    (RollingPeopleVaccinated * 1.0 / NULLIF(Population, 0)) * 100 AS PercentPopulationVaccinated
FROM PopVsVaccination
ORDER BY Nation, Date;

-- 8.1 Create Temp Table

IF OBJECT_ID('tempdb..#PopVsVaccination') IS NOT NULL
    DROP TABLE #PopVsVaccination;

-- 8.2 Create and Populate the Temporary Table

SELECT 
    v.Nation AS Nation,
    v.Date,
    p.Population,
    v.Vaccine AS new_vaccinations,
    SUM(CONVERT(bigint, v.Vaccine)) OVER (
        PARTITION BY v.Nation 
        ORDER BY v.Nation, v.Date
    ) AS RollingPeopleVaccinated
INTO #PopVsVaccination
FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
JOIN PortfolioProject..[UK population] p
    ON v.Nation = p.Nation;

-- 8.3 Query the Temporary Table

SELECT 
    Nation,
    Date,
    Population,
    RollingPeopleVaccinated,
    (RollingPeopleVaccinated * 1.0 / NULLIF(Population, 0)) * 100 AS PercentPopulationVaccinated
FROM #PopVsVaccination
ORDER BY Nation, Date;

-- 9 Create View to Store Data for Visulisation

--CREATE VIEW PercentPopulationVaccinated AS
--SELECT 
--    v.Nation AS location,
--    v.Date,
--    p.Population,
--    v.Vaccine AS new_vaccinations,
--    SUM(CONVERT(bigint, v.Vaccine)) OVER (
--        PARTITION BY v.Nation 
--        ORDER BY v.Nation, v.Date
--    ) AS RollingPeopleVaccinated
-- FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
-- JOIN PortfolioProject..[UK population] p
--    ON v.Nation = p.Nation;

-- 10.1 Which Nation had the Fastest Fully Vaccinated Rollout (Max Daily Rate Per Capita)

SELECT TOP 1
    v.Nation,
    v.Date,
    v.Vaccine AS DailyVaccinations,
    p.Population,
    (v.Vaccine * 1.0 / NULLIF(p.Population, 0)) * 100 AS DailyVaccinationRatePercentage
FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
JOIN PortfolioProject..[UK population] p
    ON v.Nation = p.Nation
WHERE v.Metric = 'FullyVaccByDate' -- Filters specifically for fully vaccinated metric seen in your sample data
ORDER BY DailyVaccinationRatePercentage DESC;

-- 10.2 Fastest Nation to Reach 50% Fully Vaccinated Threshold

WITH RunningTotals AS (
    SELECT 
        v.Nation,
        v.Date,
        p.Population,
        SUM(CONVERT(bigint, v.Vaccine)) OVER (
            PARTITION BY v.Nation 
            ORDER BY v.Date
        ) AS RollingVaccinated
    FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
    JOIN PortfolioProject..[UK population] p
        ON v.Nation = p.Nation
    WHERE v.Metric = 'FullyVaccByDate'
),
Milestones AS (
    SELECT 
        Nation,
        MIN(Date) AS StartDate,
        MIN(CASE WHEN (RollingVaccinated * 1.0 / Population) * 100 >= 50 THEN Date END) AS Reached50PercentDate
    FROM RunningTotals
    GROUP BY Nation
)
SELECT 
    Nation,
    StartDate,
    Reached50PercentDate,
    DATEDIFF(day, StartDate, Reached50PercentDate) AS DaysToReach50Percent
FROM Milestones
WHERE Reached50PercentDate IS NOT NULL
ORDER BY DaysToReach50Percent ASC;

-- 11 Did Nations Vaccination Rates Peak at Diffrent times

WITH RankedVaccinations AS (
    SELECT 
        v.Nation,
        v.Date,
        v.Vaccine AS PeakDailyVaccinations,
        p.Population,
        (v.Vaccine * 1.0 / NULLIF(p.Population, 0)) * 100 AS PeakDailyVaccinationRate,
        ROW_NUMBER() OVER (
            PARTITION BY v.Nation 
            ORDER BY v.Vaccine DESC, v.Date ASC
        ) AS RowNum
    FROM PortfolioProject..[Covid-19 gov vaccine by day nation] v
    JOIN PortfolioProject..[UK population] p
        ON v.Nation = p.Nation
    WHERE v.Metric = 'FullyVaccByDate' -- Optional filter if table contains multiple metrics
)
SELECT 
    Nation,
    Date AS PeakDate,
    PeakDailyVaccinations,
    PeakDailyVaccinationRate
FROM RankedVaccinations
WHERE RowNum = 1
ORDER BY PeakDate ASC;

-- 12 Did Lockdown Timing Differneces Correlate with Case Trajectory Changes

WITH LockdownDates AS (
    -- Define key lockdown announcement/start dates for comparison
    SELECT 'England' AS Nation, 'Lockdown 1' AS LockdownName, CAST('2020-03-23' AS DATE) AS LockdownDate UNION ALL
    SELECT 'Scotland', 'Lockdown 1', '2020-03-23' UNION ALL
    SELECT 'Wales', 'Lockdown 1', '2020-03-23' UNION ALL
    SELECT 'Northern Ireland', 'Lockdown 1', '2020-03-23' UNION ALL
    
    -- Autumn 2020 Firebreak / Lockdowns (Noted for start date differences across nations)
    SELECT 'Wales', 'Autumn Firebreak', '2020-10-23' UNION ALL
    SELECT 'Northern Ireland', 'Autumn Circuit Breaker', '2020-10-16' UNION ALL
    SELECT 'England', 'Lockdown 2', '2020-11-05' UNION ALL
    SELECT 'Scotland', 'Tier System Launch', '2020-11-02'
),
CasesWith7DayAvg AS (
    SELECT 
        Nation,
        Date,
        Cases,
        AVG(CAST(Cases AS FLOAT)) OVER (
            PARTITION BY Nation 
            ORDER BY Date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS Cases_7Day_Avg
    FROM PortfolioProject..[Covid-19 gov new cases by day nations]
)
SELECT 
    ld.Nation,
    ld.LockdownName,
    ld.LockdownDate,
    
    -- 7-Day average daily cases on Lockdown Day
    ROUND(c_on.Cases_7Day_Avg, 0) AS AvgCases_On_LockdownDay,
    
    -- 7-Day average daily cases 14 days after Lockdown
    ROUND(c_14.Cases_7Day_Avg, 0) AS AvgCases_14Days_Post,
    
    -- 7-Day average daily cases 28 days after Lockdown
    ROUND(c_28.Cases_7Day_Avg, 0) AS AvgCases_28Days_Post,
    
    -- Percentage change in 7-day average from day 0 to day 28
    ROUND(
        ((c_28.Cases_7Day_Avg - c_on.Cases_7Day_Avg) / NULLIF(c_on.Cases_7Day_Avg, 0)) * 100, 
        2
    ) AS Percent_Change_In_28Days

FROM LockdownDates ld
LEFT JOIN CasesWith7DayAvg c_on 
    ON ld.Nation = c_on.Nation AND ld.LockdownDate = c_on.Date
LEFT JOIN CasesWith7DayAvg c_14 
    ON ld.Nation = c_14.Nation AND DATEADD(day, 14, ld.LockdownDate) = c_14.Date
LEFT JOIN CasesWith7DayAvg c_28 
    ON ld.Nation = c_28.Nation AND DATEADD(day, 28, ld.LockdownDate) = c_28.Date
ORDER BY ld.LockdownName, ld.Nation;

-- 13 Hospitalisation Rates by Nation Relative to Case Rates


SELECT 
    c.Nation,
    YEAR(c.Date) AS [Year],
    MONTH(c.Date) AS [Month],
    SUM(CONVERT(bigint, c.Cases)) AS MonthlyCases,
    SUM(CONVERT(bigint, h.Admissions)) AS MonthlyHospitalisations,
    
    -- Ratio of hospitalisations to cases for that month
    ROUND(
        (SUM(CONVERT(bigint, h.Admissions)) * 1.0 / NULLIF(SUM(CONVERT(bigint, c.Cases)), 0)) * 100, 
        2
    ) AS MonthlyHospitalisationRatePct

FROM PortfolioProject..[Covid-19 gov new cases by day nations] c
LEFT JOIN PortfolioProject..[Covid-19 gov adm by day nation] h
    ON c.Nation = h.Nation 
    AND c.Date = h.Date
GROUP BY c.Nation, YEAR(c.Date), MONTH(c.Date)
ORDER BY c.Nation, [Year], [Month];

-- 14 Regional Breakdown within England vs Other Three Nations

-- 14.1 Total New Admissions by Region

SELECT NHS_region, SUM(Admissions) AS Total_Admissions
FROM PortfolioProject..[Covid-19 gov adm by day nhs region]
WHERE Metric = 'NewAdmissions'
GROUP BY NHS_region
ORDER BY Total_Admissions DESC;

-- 14.2 Daily Total Admissions Across all Regions

SELECT Date,SUM(Admissions) AS Daily_Total_Admissions
FROM PortfolioProject..[Covid-19 gov adm by day nhs region]
WHERE Metric = 'NewAdmissions'
GROUP BY Date
ORDER BY Date ASC;

-- 14.3 Pivoted View

SELECT 
    Date,
    SUM(CASE WHEN NHS_region = 'London' THEN Admissions ELSE 0 END) AS London,
    SUM(CASE WHEN NHS_region = 'Midlands' THEN Admissions ELSE 0 END) AS Midlands,
    SUM(CASE WHEN NHS_region = 'East of England' THEN Admissions ELSE 0 END) AS East_of_England,
    SUM(CASE WHEN NHS_region = 'North West' THEN Admissions ELSE 0 END) AS North_West,
    SUM(CASE WHEN NHS_region = 'South West' THEN Admissions ELSE 0 END) AS South_West,
    SUM(CASE WHEN NHS_region = 'South East' THEN Admissions ELSE 0 END) AS South_East,
    SUM(CASE WHEN NHS_region = 'North East and Yorkshire' THEN Admissions ELSE 0 END) AS North_East_and_Yorkshire
FROM PortfolioProject..[Covid-19 gov adm by day nhs region]
WHERE Metric = 'NewAdmissions'
GROUP BY Date
ORDER BY Date ASC;

-- 14.4 Peak Admissions Day by Region

WITH RankedAdmissions AS (
    SELECT 
        Date,
        NHS_region,
        Admissions,
        ROW_NUMBER() OVER(PARTITION BY NHS_region ORDER BY Admissions DESC) AS rnk
    FROM PortfolioProject..[Covid-19 gov adm by day nhs region]
    WHERE Metric = 'NewAdmissions'
)
SELECT NHS_region, Date AS Peak_Date, Admissions AS Max_Admissions
FROM RankedAdmissions
WHERE rnk = 1;

-- 14.5 All together

WITH CombinedAdmissions AS (
    -- English Regions
    SELECT 
        CASE 
            WHEN NHS_region IN ('North East', 'Yorkshire and the Humber', 'North East and Yorkshire') THEN 'North East & Yorkshire'
            WHEN NHS_region IN ('East Midlands', 'West Midlands', 'Midlands') THEN 'Midlands'
            WHEN NHS_region IN ('East of England', 'London', 'North West', 'South East', 'South West') THEN NHS_region
            ELSE 'Other/Unknown'
        END AS custom_10_region,
        Admissions
    FROM PortfolioProject..[Covid-19 gov adm by day nhs region]
    UNION ALL

    -- Get Devolved Nations (Excluding England)
    SELECT 
        Nation AS custom_10_region,
        Admissions
    FROM PortfolioProject..[Covid-19 gov adm by day nation]
    WHERE Nation IN ('Scotland', 'Wales', 'Northern Ireland')
)
SELECT custom_10_region, SUM(Admissions) AS total_Admissions
FROM CombinedAdmissions
GROUP BY custom_10_region
ORDER BY total_Admissions DESC;

-- END