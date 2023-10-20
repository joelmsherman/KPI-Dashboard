/*
The purpose of this logic is to extract source data for the SW Forecast Monitoring dashboard.  
This logic is to materialize a table nightly to the storage layer, so that it can be consumed
and further refined inside a Power BI dataset.  

The schema is as follows:
Type: string | ex. AC, FC
Date: datetime | ex. yyyy-mm-01
SeriesID: string | ex. A1a, see below
Account: string | ex. Reg. Generation, see below
Group: string | ex. Wet, see below
Series: string | ex. Central, see below
Value: float | tons or loads

The logic is organized by account (A), group (1) and series (a), as follows:

A. Reg. Generation
    1. Wet
        a. Central
        b. South
        c. Private
    2. Dry
        a. Central
        b. South
        c. Private
B. RSF/ET
    1. Central
        a. MSW
    2. South
        a. MSW
    3. Private
        a. MSW
        b. Special
C. Metro Tonnage
    1. Central
        a. MSW
        b. Res. Organics
        c. Com. Organics
        d. Clean wood
        e. Yard debris
    2. South
        a. MSW
        b. Res. Organics
        c. Com. Organics
        d. Clean wood
        e. Yard debris
D. Metro Loads
    1. Central
        a. Staffed
        b. Automated
        c. Minimum
    2. South
        a. Staffed
        b. Automated
        c. Minimum
E. Wet Allocation
    1. Metro
        a. Central
        b. South
    2. Private
        a. Total
F. CEF
    1. Metro
        a. Central
        b. South
    2. Private
        a. COR
        b. Forest Grove
        c. Gresham
        d. Pride
        e. Suttle
        f. Troutdale
*/

WITH FCLookup AS --CTE for storing mutually exclusive lookups to forecast values
(
    SELECT
        VintageID,
        DATEFROMPARTS(YEAR(VintageStartDate) + 1, 7, 1) AS ValueStart,
        DATEFROMPARTS(YEAR(VintageStartDate) + 2, 6, 1) AS ValueEnd

        FROM 
        [SWForecast].[dbo].[Vintage]

        WHERE 
        VintageName LIKE '%Annual%' OR VintageName LIKE '%Fall%'
),
Series AS --CTE for consolidating all the data for later date manipulation
(
/************************************  A. Waste Generation  *************************************/
    SELECT -- Actuals
        'AC' AS [Type],
        DATEFROMPARTS(ac.Year, ac.Month, 1) AS [Date],
        CASE
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity = 'Metro Central' THEN 'A1a'
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity = 'Metro South' THEN 'A1b'
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity NOT IN ('Metro Central', 'Metro South') THEN 'A1c'
            WHEN ac.OldMaterial IN('Dry MSW','Dry residual') AND ac.ReportingEntity = 'Metro Central' THEN 'A2a'
            WHEN ac.OldMaterial IN('Dry MSW','Dry residual') AND ac.ReportingEntity = 'Metro South' THEN 'A2b'      
            ELSE 'A2c'
        END AS SeriesID,
        'Waste Generation' AS Account,
        CASE 
            WHEN ac.OldMaterial = 'Wet MSW' THEN 'Wet'
            ELSE 'Dry'
        END AS [Group],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Private'
        END AS Series,
        SUM(ac.Tons) AS [Value]
        
        FROM
        [SWIS].[dbo].[M_DeliveryTonnage] ac
        
        WHERE
        ac.OldMaterial IN ('Wet MSW', 'Dry MSW', 'Dry residual') AND
        DATEFROMPARTS(ac.Year, ac.Month, 1) >= '2015-07-01'

        GROUP BY
        DATEFROMPARTS(ac.Year, ac.Month, 1),
        CASE
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity = 'Metro Central' THEN 'A1a'
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity = 'Metro South' THEN 'A1b'
            WHEN ac.OldMaterial = 'Wet MSW' AND ac.ReportingEntity NOT IN ('Metro Central', 'Metro South') THEN 'A1c'
            WHEN ac.OldMaterial IN('Dry MSW','Dry residual') AND ac.ReportingEntity = 'Metro Central' THEN 'A2a'
            WHEN ac.OldMaterial IN('Dry MSW','Dry residual') AND ac.ReportingEntity = 'Metro South' THEN 'A2b'      
            ELSE 'A2c'
        END,
        CASE 
            WHEN ac.OldMaterial = 'Wet MSW' THEN 'Wet'
            ELSE 'Dry'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Private'
        END
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID = 1 THEN 'A1a'
            WHEN fc.SeriesID = 15 THEN 'A1b'
            WHEN fc.SeriesID = 29 THEN 'A1c'
            WHEN fc.SeriesID = 2 THEN 'A2a'
            WHEN fc.SeriesID = 16 THEN 'A2b'
            ELSE 'A2c'
        END AS SeriesID,
        'Waste Generation' AS Account,
        CASE 
            WHEN fc.SeriesID IN (1, 15, 29) THEN 'Wet'
            ELSE 'Dry'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID IN (1, 2) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16) THEN 'South'
            ELSE 'Private'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        

        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (1, 2, 15, 16, 29, 30)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID = 1 THEN 'A1a'
            WHEN fc.SeriesID = 15 THEN 'A1b'
            WHEN fc.SeriesID = 29 THEN 'A1c'
            WHEN fc.SeriesID = 2 THEN 'A2a'
            WHEN fc.SeriesID = 16 THEN 'A2b'
            ELSE 'A2c'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 15, 29) THEN 'Wet'
            ELSE 'Dry'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 2) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16) THEN 'South'
            ELSE 'Private'
        END    
/************************************ B. Fee and Tax  *************************************/   
    UNION ALL SELECT -- Actuals
        'AC' AS [Type],
        ac.SubmissionDate AS [Date],
        CASE 
            WHEN ReportingEntity = 'Metro Central' THEN 'B1a'
            WHEN ReportingEntity = 'Metro South' THEN 'B2a'
            WHEN ReportingEntity NOT IN ('Metro Central', 'Metro South') 
                AND RevenueType = 'Other Revenue Wastes' THEN 'B3b'
            ELSE 'B3a'
        END AS SeriesID,
        'Fee and Tax' AS Account,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Private'
        END AS [Group],
        CASE 
            WHEN ac.RevenueType = 'Other Revenue Wastes' THEN 'Special'
            ELSE 'MSW'
        END AS [Series],
        SUM(ac.Units) AS [Value]

        FROM 
        [SWIS].[dbo].[M_RevFeeTaxTonnage] ac

        WHERE
        ac.RateType = 'Full ET' AND
        ac.SubmissionDate >= '2015-07-01'

        GROUP BY
        ac.SubmissionDate,
        CASE 
            WHEN ReportingEntity = 'Metro Central' THEN 'B1a'
            WHEN ReportingEntity = 'Metro South' THEN 'B2a'
            WHEN ReportingEntity NOT IN ('Metro Central', 'Metro South') 
                AND RevenueType = 'Other Revenue Wastes' THEN 'B3b'
            ELSE 'B3a'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Private'
        END,
        CASE 
            WHEN ac.RevenueType = 'Other Revenue Wastes' THEN 'Special'
            ELSE 'MSW'
        END       
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID IN (1,2) THEN 'B1a'
            WHEN fc.SeriesID IN (15, 16) THEN 'B2a'
            WHEN fc.SeriesID = 31 THEN 'B3a'
            ELSE 'B3b'
        END AS SeriesID,
        'Fee and Tax' AS Account,
        CASE 
            WHEN fc.SeriesID IN (1, 2) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16) THEN 'South'
            ELSE 'Private'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID = 32 THEN 'Special'
            ELSE 'MSW'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        
        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (1, 2, 15, 16, 31, 32)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID IN (1,2) THEN 'B1a'
            WHEN fc.SeriesID IN (15, 16) THEN 'B2a'
            WHEN fc.SeriesID = 31 THEN 'B3a'
            ELSE 'B3b'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 2) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16) THEN 'South'
            ELSE 'Private'
        END,
        CASE 
            WHEN fc.SeriesID = 32 THEN 'Special'
            ELSE 'MSW'
        END      
/**********************************   C. Metro Tonnage  *************************************/
    UNION ALL SELECT -- Actuals
        'AC' AS [Type],
        ac.SubmissionDate AS [Date],
        CASE 
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'MSW' THEN 'C1a'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Res Organics' THEN 'C1b'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Com Organics' THEN 'C1c'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Clean wood' THEN 'C1d'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Yard debris' THEN 'C1e'
            
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'MSW' THEN 'C2a'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Res Organics' THEN 'C2b'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Com Organics' THEN 'C2c'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Clean wood' THEN 'C2d'                       
            ELSE 'C2e'
        END AS SeriesID,
        'Metro Tonnage' AS Account,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            ELSE 'South'
        END AS [Group],
        ac.RevenueType AS [Series],
        SUM(ac.Units) AS [Value]

        FROM 
        [SWIS].[dbo].[M_RevFeeTaxTonnage] ac

        WHERE
        ac.RateType = 'Tonnage Fee' AND
        ac.SubmissionDate >= '2015-07-01'

        GROUP BY
        ac.SubmissionDate,
        CASE 
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'MSW' THEN 'C1a'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Res Organics' THEN 'C1b'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Com Organics' THEN 'C1c'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Clean wood' THEN 'C1d'
            WHEN ReportingEntity = 'Metro Central' AND RevenueType = 'Yard debris' THEN 'C1e'
            
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'MSW' THEN 'C2a'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Res Organics' THEN 'C2b'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Com Organics' THEN 'C2c'
            WHEN ReportingEntity = 'Metro South' AND RevenueType = 'Clean wood' THEN 'C2d'                       
            ELSE 'C2e'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            ELSE 'South'
        END,
        ac.RevenueType
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID IN (1, 2) THEN 'C1a'
            WHEN fc.SeriesID = 5 THEN 'C1b'
            WHEN fc.SeriesID = 6 THEN 'C1c'
            WHEN fc.SeriesID = 3 THEN 'C1d'
            WHEN fc.SeriesID = 4 THEN 'C1e'
            WHEN fc.SeriesID IN (15, 16) THEN 'C2a'
            WHEN fc.SeriesID = 19 THEN 'C2b'
            WHEN fc.SeriesID = 20 THEN 'C2c'
            WHEN fc.SeriesID = 17 THEN 'C2d'      
            ELSE 'C2e'
        END AS SeriesID,
        'Metro Tonnage' AS Account,
        CASE 
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'Central'
            ELSE 'South'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID IN (1, 2, 15, 16) THEN 'MSW'
            WHEN fc.SeriesID IN (5, 19) THEN 'Res Organics'
            WHEN fc.SeriesID IN (6, 20) THEN 'Com Organics'
            WHEN fc.SeriesID IN (3, 17) THEN 'Clean wood'     
            ELSE 'Yard debris'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        
        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (1, 2, 3, 4, 5, 6, 15, 16, 17, 18, 19, 20)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID IN (1, 2) THEN 'C1a'
            WHEN fc.SeriesID = 5 THEN 'C1b'
            WHEN fc.SeriesID = 6 THEN 'C1c'
            WHEN fc.SeriesID = 3 THEN 'C1d'
            WHEN fc.SeriesID = 4 THEN 'C1e'
            WHEN fc.SeriesID IN (15, 16) THEN 'C2a'
            WHEN fc.SeriesID = 19 THEN 'C2b'
            WHEN fc.SeriesID = 20 THEN 'C2c'
            WHEN fc.SeriesID = 17 THEN 'C2d'      
            ELSE 'C2e'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'Central'
            ELSE 'South'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 2, 15, 16) THEN 'MSW'
            WHEN fc.SeriesID IN (5, 19) THEN 'Res Organics'
            WHEN fc.SeriesID IN (6, 20) THEN 'Com Organics'
            WHEN fc.SeriesID IN (3, 17) THEN 'Clean wood'     
            ELSE 'Yard debris'
        END
/**********************************   D. Metro Loads *************************************/
    UNION ALL SELECT -- Actuals
        'AC' AS [Type],
        ac.SubmissionDate AS [Date],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RevenueType LIKE '%Staff' THEN 'D1a'
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RevenueType LIKE '%Auto' THEN 'D1b'
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RateType = 'Minimum Fee' THEN 'D1c'
            WHEN ac.ReportingEntity = 'Metro South' AND ac.RevenueType LIKE '%Staff' THEN 'D2a'
            WHEN ac.ReportingEntity = 'Metro South' AND ac.RevenueType LIKE '%Auto' THEN 'D2b'
            ELSE 'D2c'
        END AS SeriesID,
        'Metro Loads' AS Account,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            ELSE 'South'
        END AS [Group],
        CASE 
            WHEN ac.RevenueType LIKE '%Staff' THEN 'Staffed'
            WHEN ac.RevenueType LIKE '%Auto' THeN 'Automated'
            ELSE 'Minimum'
        END AS [Series],
        SUM(ac.Units) AS [Value]

        FROM 
        [SWIS].[dbo].[M_RevFeeTaxTonnage] ac

        WHERE
        RateType IN ('Transaction Fee', 'Minimum Fee') AND
        ac.SubmissionDate >= '2015-07-01'

        GROUP BY
        ac.SubmissionDate,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RevenueType LIKE '%Staff' THEN 'D1a'
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RevenueType LIKE '%Auto' THEN 'D1b'
            WHEN ac.ReportingEntity = 'Metro Central' AND ac.RateType = 'Minimum Fee' THEN 'D1c'
            WHEN ac.ReportingEntity = 'Metro South' AND ac.RevenueType LIKE '%Staff' THEN 'D2a'
            WHEN ac.ReportingEntity = 'Metro South' AND ac.RevenueType LIKE '%Auto' THEN 'D2b'
            ELSE 'D2c'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            ELSE 'South'
        END,
        CASE 
            WHEN ac.RevenueType LIKE '%Staff' THEN 'Staffed'
            WHEN ac.RevenueType LIKE '%Auto' THeN 'Automated'
            ELSE 'Minimum'
        END
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID = 7 THEN 'D1a'
            WHEN fc.SeriesID = 8 THEN 'D1b'
            WHEN fc.SeriesID = 9 THEN 'D1c'
            WHEN fc.SeriesID = 21 THEN 'D2a'
            WHEN fc.SeriesID = 22 THEN 'D2b'      
            ELSE 'D2c'
        END AS SeriesID,
        'Metro Loads' AS Account,
        CASE 
            WHEN fc.SeriesID IN (7, 8, 9) THEN 'Central'
            ELSE 'South'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID IN (7, 21) THEN 'Staffed'
            WHEN fc.SeriesID IN (8, 22) THEN 'Automated' 
            ELSE 'Minimum'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        
        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (7, 8, 9, 21, 22, 23)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID = 7 THEN 'D1a'
            WHEN fc.SeriesID = 8 THEN 'D1b'
            WHEN fc.SeriesID = 9 THEN 'D1c'
            WHEN fc.SeriesID = 21 THEN 'D2a'
            WHEN fc.SeriesID = 22 THEN 'D2b'      
            ELSE 'D2c'
        END,
        CASE 
            WHEN fc.SeriesID IN (7, 8, 9) THEN 'Central'
            ELSE 'South'
        END,
        CASE 
            WHEN fc.SeriesID IN (7, 21) THEN 'Staffed'
            WHEN fc.SeriesID IN (8, 22) THEN 'Automated' 
            ELSE 'Minimum'
        END
/**********************************   E. Wet Allocation *************************************/
    UNION ALL SELECT -- Actuals
		'AC' AS [Type],
        DATEFROMPARTS(ac.Year, ac.Month, 1) AS [Date],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'E1a'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'E1b'
            ELSE 'E2a'
        END AS SeriesID,
        'Wet Allocation' AS [Account],
        CASE 
            WHEN ac.ReportingEntity IN ('Metro Central', 'Metro South') THEN 'Metro'
            ELSE 'Private'
        END AS [Group],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Total'
        END AS Series,
		SUM(ac.Tons) AS [Value]
		
		FROM
		dbo.M_DeliveryTonnage ac
		
		WHERE
		ac.OldMaterial = 'Wet MSW' AND
		ac.GenOrigin = 'In-district' AND
        DATEFROMPARTS(ac.Year, ac.Month, 1) >= '2015-07-01'

        GROUP BY
        DATEFROMPARTS(ac.Year, ac.Month, 1),
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'E1a'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'E1b'
            ELSE 'E2a'
        END,
        CASE 
            WHEN ac.ReportingEntity IN ('Metro Central', 'Metro South') THEN 'Metro'
            ELSE 'Private'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            ELSE 'Total'
        END
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID = 1 THEN 'E1a'
            WHEN fc.SeriesID = 15 THEN 'E1b'     
            ELSE 'E2a'
        END AS SeriesID,
        'Wet Allocation' AS Account,
        CASE 
            WHEN fc.SeriesID IN (1, 15) THEN 'Metro'
            ELSE 'Private'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID = 1 THEN 'Central'
            WHEN fc.SeriesID = 15 THEN 'South' 
            ELSE 'Total'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        
        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (1, 15, 45)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID = 1 THEN 'E1a'
            WHEN fc.SeriesID = 15 THEN 'E1b'     
            ELSE 'E2a'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 15) THEN 'Metro'
            ELSE 'Private'
        END,
        CASE 
            WHEN fc.SeriesID = 1 THEN 'Central'
            WHEN fc.SeriesID = 15 THEN 'South' 
            ELSE 'Total'
        END
/************************************ F. Com Enhancement  *************************************/   
    UNION ALL SELECT -- Actuals
        'AC' AS [Type],
        ac.SubmissionDate AS [Date],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'F1a'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'F1b'
            WHEN ac.ReportingEntity = 'City of Roses Disposal and Recycling' THEN 'F2a'
            WHEN ac.ReportingEntity = 'Forest Grove Transfer Station' THEN 'F2b'
            WHEN ac.ReportingEntity = 'GSS Transfer LLC' THEN 'F2c'
            WHEN ac.ReportingEntity = 'Pride Recycling' THEN 'F2d'
            WHEN ac.ReportingEntity = 'Recology Suttle Road' THEN 'F2e'
            WHEN ac.ReportingEntity = 'Troutdale Transfer Station' THEN 'F2f'
            WHEN ac.ReportingEntity = 'Willamette Resources (WRI)' THEN 'F2g'
        END AS SeriesID,
        'Com Enhancement' AS Account,
        CASE 
            WHEN ac.ReportingEntity IN ('Metro Central', 'Metro South') THEN 'Metro'
            ELSE 'Private'
        END AS [Group],
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            WHEN ac.ReportingEntity = 'City of Roses Disposal and Recycling' THEN 'COR'
            WHEN ac.ReportingEntity = 'Forest Grove Transfer Station' THEN 'Forest Grove'
            WHEN ac.ReportingEntity = 'GSS Transfer LLC' THEN 'Gresham'
            WHEN ac.ReportingEntity = 'Pride Recycling' THEN 'Pride'
            WHEN ac.ReportingEntity = 'Recology Suttle Road' THEN 'Suttle Rd'
            WHEN ac.ReportingEntity = 'Troutdale Transfer Station' THEN 'Troutdale'
            WHEN ac.ReportingEntity = 'Willamette Resources (WRI)' THEN 'WRI'
        END AS [Series],
        SUM(ac.Units) AS [Value]

        FROM 
        [SWIS].[dbo].[M_RevFeeTaxTonnage] ac

        WHERE
        ac.RateType = 'EF' AND
        ac.SubmissionDate >= '2015-07-01'

        GROUP BY
        ac.SubmissionDate,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'F1a'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'F1b'
            WHEN ac.ReportingEntity = 'City of Roses Disposal and Recycling' THEN 'F2a'
            WHEN ac.ReportingEntity = 'Forest Grove Transfer Station' THEN 'F2b'
            WHEN ac.ReportingEntity = 'GSS Transfer LLC' THEN 'F2c'
            WHEN ac.ReportingEntity = 'Pride Recycling' THEN 'F2d'
            WHEN ac.ReportingEntity = 'Recology Suttle Road' THEN 'F2e'
            WHEN ac.ReportingEntity = 'Troutdale Transfer Station' THEN 'F2f'
            WHEN ac.ReportingEntity = 'Willamette Resources (WRI)' THEN 'F2g'
        END,
        CASE 
            WHEN ac.ReportingEntity IN ('Metro Central', 'Metro South') THEN 'Metro'
            ELSE 'Private'
        END,
        CASE 
            WHEN ac.ReportingEntity = 'Metro Central' THEN 'Central'
            WHEN ac.ReportingEntity = 'Metro South' THEN 'South'
            WHEN ac.ReportingEntity = 'City of Roses Disposal and Recycling' THEN 'COR'
            WHEN ac.ReportingEntity = 'Forest Grove Transfer Station' THEN 'Forest Grove'
            WHEN ac.ReportingEntity = 'GSS Transfer LLC' THEN 'Gresham'
            WHEN ac.ReportingEntity = 'Pride Recycling' THEN 'Pride'
            WHEN ac.ReportingEntity = 'Recology Suttle Road' THEN 'Suttle Rd'
            WHEN ac.ReportingEntity = 'Troutdale Transfer Station' THEN 'Troutdale'
            WHEN ac.ReportingEntity = 'Willamette Resources (WRI)' THEN 'WRI'
        END       
    UNION ALL SELECT -- Forecasts
        'FC' AS [Type],
        fc.ForecastDate AS [Date],
        CASE
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'F1a'
            WHEN fc.SeriesID IN (15, 16, 17, 18, 19, 20) THEN 'F1b'     
            WHEN fc.SeriesID = 38 THEN 'F2a'
            WHEN fc.SeriesID = 36 THEN 'F2b'
            WHEN fc.SeriesID = 37 THEN 'F2c'
            WHEN fc.SeriesID = 39 THEN 'F2d'
            WHEN fc.SeriesID = 40 THEN 'F2e'
            WHEN fc.SeriesID = 41 THEN 'F2f'
            WHEN fc.SeriesID = 43 THEN 'F2g'
        END AS SeriesID,
        'Com Enhancement' AS Account,
        CASE 
            WHEN fc.SeriesID IN (38, 36, 37, 39, 40, 41, 43) THEN 'Private'
            ELSE 'Metro'
        END AS [Group],
        CASE 
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16, 17, 18, 19, 20) THEN 'South'     
            WHEN fc.SeriesID = 38 THEN 'COR'
            WHEN fc.SeriesID = 36 THEN 'Forest Grove'
            WHEN fc.SeriesID = 37 THEN 'Gresham'
            WHEN fc.SeriesID = 39 THEN 'Pride'
            WHEN fc.SeriesID = 40 THEN 'Suttle Rd'
            WHEN fc.SeriesID = 41 THEN 'Troutdale'
            WHEN fc.SeriesID = 43 THEN 'WRI'
        END AS Series,
        SUM(fc.SeriesValue) AS [Value]
        
        FROM
        [SWForecast].[dbo].[ForecastFact] fc
        INNER JOIN FCLookup l ON fc.VintageID = l.VintageID

        WHERE
        fc.ForecastDate BETWEEN l.ValueStart AND l.ValueEnd AND
        fc.SeriesID IN (1, 2, 3, 4, 5, 6, 15, 16, 17, 18, 19, 20, 38, 36, 37, 39, 40, 41, 43)

        GROUP BY
        fc.ForecastDate,
        CASE
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'F1a'
            WHEN fc.SeriesID IN (15, 16, 17, 18, 19, 20) THEN 'F1b'     
            WHEN fc.SeriesID = 38 THEN 'F2a'
            WHEN fc.SeriesID = 36 THEN 'F2b'
            WHEN fc.SeriesID = 37 THEN 'F2c'
            WHEN fc.SeriesID = 39 THEN 'F2d'
            WHEN fc.SeriesID = 40 THEN 'F2e'
            WHEN fc.SeriesID = 41 THEN 'F2f'
            WHEN fc.SeriesID = 43 THEN 'F2g'
        END,
        CASE 
            WHEN fc.SeriesID IN (38, 36, 37, 39, 40, 41, 43) THEN 'Private'
            ELSE 'Metro'
        END,
        CASE 
            WHEN fc.SeriesID IN (1, 2, 3, 4, 5, 6) THEN 'Central'
            WHEN fc.SeriesID IN (15, 16, 17, 18, 19, 20) THEN 'South'     
            WHEN fc.SeriesID = 38 THEN 'COR'
            WHEN fc.SeriesID = 36 THEN 'Forest Grove'
            WHEN fc.SeriesID = 37 THEN 'Gresham'
            WHEN fc.SeriesID = 39 THEN 'Pride'
            WHEN fc.SeriesID = 40 THEN 'Suttle Rd'
            WHEN fc.SeriesID = 41 THEN 'Troutdale'
            WHEN fc.SeriesID = 43 THEN 'WRI'
        END        
)
SELECT *
FROM Series
WHERE -- Filter out incomplete months of actuals only; allow all forecasts
    (
        [Type]= 'AC' 
        AND [Date] < DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)
    )
    OR [Type] != 'AC'
