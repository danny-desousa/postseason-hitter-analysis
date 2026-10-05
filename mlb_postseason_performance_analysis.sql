/*
College Project: MLB Postseason Performance Analysis
Purpose: Build the dataset used to analyze changes in hitter performance
         between the regular season and postseason.

Primary outcome variable:
    Delta OPS = Postseason OPS - Regular Season OPS

Database: MsSQL
Source: Lahman Baseball Database
*/

-- Batting table
SELECT TOP 10 * FROM Batting;

-- Batting Postseason table
SELECT TOP 10 * FROM BattingPost;

-- People table
SELECT TOP 10 * FROM People;

-- Teams table
SELECT TOP 10 * FROM Teams;

-- Calculate regular season and postseason OPS, relative difference vs league average
-- plus walk rate (BB_rate) and power metric (ISO) for each player

WITH player_postseason_years AS ( -- Get all years where each player appeared in postseason
    SELECT DISTINCT playerID, yearID
    FROM BattingPost
    WHERE AB > 0
),
postseason_year_counts AS ( -- Get how many total years each player appeared in postseason
    SELECT 
        playerID,
        COUNT(DISTINCT yearID) AS postseason_years
    FROM BattingPost
    GROUP BY playerID
),
regular_season AS (
    SELECT 
        b.playerID,
        SUM(b.AB) AS AB,
        SUM(b.H) AS H,
        SUM(b.[2B]) AS "2B",
        SUM(b.[3B]) AS "3B",
        SUM(b.HR) AS HR,
        SUM(b.BB) AS BB,
        SUM(b.SO) AS SO,
        SUM(b.HBP) AS HBP,
        SUM(b.SF) AS SF,

        -- Plate Appearances (PA)
        SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF) AS PA,

        -- Batting Average
        SUM(b.H) * 1.0 / NULLIF(SUM(b.AB), 0) AS BA,

        -- On-Base Percentage (OBP)
        (SUM(b.H) + SUM(b.BB) + SUM(b.HBP)) * 1.0 /
        NULLIF(SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF), 0) AS OBP,

        -- Slugging Percentage (SLG)
        ((SUM(b.H) - SUM(b.[2B]) - SUM(b.[3B]) - SUM(b.HR))
         + 2 * SUM(b.[2B]) + 3 * SUM(b.[3B]) + 4 * SUM(b.HR)) * 1.0 / NULLIF(SUM(b.AB), 0) AS SLG,

        -- OPS
        ((SUM(b.H) + SUM(b.BB) + SUM(b.HBP)) * 1.0 /
            NULLIF(SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF), 0))
        +
        (((SUM(b.H) - SUM(b.[2B]) - SUM(b.[3B]) - SUM(b.HR))
         + 2 * SUM(b.[2B]) + 3 * SUM(b.[3B]) + 4 * SUM(b.HR)) * 1.0 / NULLIF(SUM(b.AB), 0)) AS OPS,

        -- BB and SO Rates
        SUM(b.BB) * 1.0 / NULLIF((SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF)), 0) AS BB_rate,
        SUM(b.SO) * 1.0 / NULLIF((SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF)), 0) AS SO_rate,

        -- Batting Average on Balls in Play
        (SUM(b.H) - SUM(b.HR)) * 1.0 / 
        NULLIF(SUM(b.AB) - SUM(b.SO) - SUM(b.HR) + SUM(b.SF), 0) AS BABIP,

        -- Isolated Power (ISO)
        ((2 * SUM(b.[2B]) + 3 * SUM(b.[3B]) + 4 * SUM(b.HR)) * 1.0 / NULLIF(SUM(b.AB),0))
         - (SUM(b.H) * 1.0 / NULLIF(SUM(b.AB),0)) AS ISO,

        -- Homerun Rate
        SUM(b.HR) * 1.0 / NULLIF(SUM(b.AB) + SUM(b.BB) + SUM(b.HBP) + SUM(b.SF), 0) AS HR_rate,

        -- Extra-base Hit Rate
        ((2 * SUM(b.[2B]) + 3 * SUM(b.[3B]) + 4 * SUM(b.HR)) * 1.0 / NULLIF(SUM(b.AB),0)) AS XB_hits_rate
    FROM Batting b
    INNER JOIN player_postseason_years ppy 
        ON b.playerID = ppy.playerID 
        AND b.yearID = ppy.yearID  -- Only regular season from years the player appeared in the postseason
    JOIN People p ON b.playerID = p.playerID
    WHERE b.AB > 50
      AND p.debut > '1995-01-01'
    GROUP BY b.playerID
),
post_season AS (
    SELECT
        bp.playerID,
        SUM(bp.AB) AS AB_post,
        SUM(bp.H) AS H_post,
        SUM(bp.[2B]) AS "2B_post",
        SUM(bp.[3B]) AS "3B_post",
        SUM(bp.HR) AS HR_post,
        SUM(bp.BB) AS BB_post,
        SUM(bp.SO) AS SO_post,
        SUM(bp.HBP) AS HBP_post,
        SUM(bp.SF) AS SF_post,

        -- Plate Appearances (PA)
        SUM(bp.AB) + SUM(bp.BB) + SUM(bp.HBP) + SUM(bp.SF) AS PA_post,

        -- Postseason OPS
        ((SUM(bp.H) + SUM(bp.BB) + SUM(bp.HBP)) * 1.0 /
            NULLIF(SUM(bp.AB) + SUM(bp.BB) + SUM(bp.HBP) + SUM(bp.SF), 0))
        +
        (((SUM(bp.H) - SUM(bp.[2B]) - SUM(bp.[3B]) - SUM(bp.HR))
         + 2 * SUM(bp.[2B]) + 3 * SUM(bp.[3B]) + 4 * SUM(bp.HR)) * 1.0 / NULLIF(SUM(bp.AB), 0)) AS OPS_post
    FROM BattingPost bp 
    GROUP BY bp.playerID
),
league_averages_by_year AS ( -- Calculate true MLB league averages for each year
    SELECT 
        yearID,
        ((SUM(H) + SUM(BB) + SUM(HBP)) * 1.0 / 
            NULLIF(SUM(AB) + SUM(BB) + SUM(HBP) + SUM(SF), 0))
        +
        (((SUM(H) - SUM([2B]) - SUM([3B]) - SUM(HR))
         + 2 * SUM([2B]) + 3 * SUM([3B]) + 4 * SUM(HR)) * 1.0 / NULLIF(SUM(AB), 0)) AS league_ops_reg
    FROM Batting
    WHERE yearID >= 1995
    GROUP BY yearID
),
league_post_averages_by_year AS ( -- Calculate true MLB postseason league averages for each year
    SELECT 
        yearID,
        ((SUM(H) + SUM(BB) + SUM(HBP)) * 1.0 / 
            NULLIF(SUM(AB) + SUM(BB) + SUM(HBP) + SUM(SF), 0))
        +
        (((SUM(H) - SUM([2B]) - SUM([3B]) - SUM(HR))
         + 2 * SUM([2B]) + 3 * SUM([3B]) + 4 * SUM(HR)) * 1.0 / NULLIF(SUM(AB), 0)) AS league_ops_post
    FROM BattingPost
    WHERE yearID >= 1995
    GROUP BY yearID
),
league_averages AS ( -- Average league OPS across all years (weighted by time period player was active)
    SELECT AVG(league_ops_reg) AS league_ops_reg FROM league_averages_by_year
), 
league_post_averages AS ( -- Average postseason league OPS across all years
    SELECT AVG(league_ops_post) AS league_ops_post FROM league_post_averages_by_year
)
SELECT
    p.nameFirst,
    p.nameLast,
    r.playerID,
    r.AB AS reg_season_AB,
    ps.AB_post AS post_season_AB,
    r.PA AS reg_season_PA,
    ps.PA_post AS post_season_PA,
    pyc.postseason_years,
    r.BA,
    r.OBP,
    r.SLG,
    r.OPS AS OPS_reg,
    (SELECT league_ops_reg FROM league_averages) AS league_avg_ops_reg, -- Regular season league OPS context
    ps.OPS_post AS OPS_post,
    (SELECT league_ops_post FROM league_post_averages) AS league_avg_ops_post, -- Postseason league OPS context
    (ps.OPS_post - r.OPS) AS OPS_diff,
    (ps.OPS_post - r.OPS) - ((SELECT league_ops_post FROM league_post_averages) - (SELECT league_ops_reg FROM league_averages)) 
    AS relative_ops_diff, -- Relative OPS difference accounting for regular to postseason regression
    r.BB_rate,
    r.SO_rate,
    r.ISO,
    r.HR_rate,
    r.XB_hits_rate,
    r.BABIP
FROM regular_season r
JOIN post_season ps ON r.playerID = ps.playerID
JOIN People p ON r.playerID = p.playerID
LEFT JOIN postseason_year_counts pyc ON r.playerID = pyc.playerID -- Number of postseason years for each player
WHERE ps.AB_post >= 40  -- Minimum postseason sample size
ORDER BY relative_ops_diff DESC;
