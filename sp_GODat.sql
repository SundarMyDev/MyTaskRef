CREATE OR ALTER PROCEDURE dbo.sp_GetOracleStats_Temp
    @FixtureID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        ---------------------------------------------------------------------
        -- Safety: drop any leftovers from a previous run in the same SPID
        ---------------------------------------------------------------------
        IF OBJECT_ID('tempdb..##fx')   IS NOT NULL DROP TABLE ##fx;
        IF OBJECT_ID('tempdb..##tm')   IS NOT NULL DROP TABLE ##tm;
        IF OBJECT_ID('tempdb..##mu')   IS NOT NULL DROP TABLE ##mu;
        IF OBJECT_ID('tempdb..##pr')   IS NOT NULL DROP TABLE ##pr;
        IF OBJECT_ID('tempdb..##pp')   IS NOT NULL DROP TABLE ##pp;
        IF OBJECT_ID('tempdb..##last') IS NOT NULL DROP TABLE ##last;

        ---------------------------------------------------------------------
        -- Step 1: fixture basics -> ##fx
        ---------------------------------------------------------------------
        SELECT
            f.Id      AS FixtureID,
            f.TeamID  AS Team1TeamID,
            f.Team2ID AS Team2TeamID,
            f.LeagueCode
        INTO ##fx
        FROM dbo.fixture AS f
        WHERE f.Id = @FixtureID;

        ---------------------------------------------------------------------
        -- Step 2: team mapping (TeamID -> PlayerID + TeamDescription) -> ##tm
        ---------------------------------------------------------------------
        SELECT
            fx.FixtureID,
            fx.LeagueCode,
            t1.NBAPlayerTeamID     AS Team1TeamID,
            t1.BasketballPlayerID  AS Player1ID,
            t1.TeamDescription     AS Team1Name,
            t2.NBAPlayerTeamID     AS Team2TeamID,
            t2.BasketballPlayerID  AS Player2ID,
            t2.TeamDescription     AS Team2Name
        INTO ##tm
        FROM ##fx AS fx
        JOIN [TraderInput].[dbo].[eBasketball_PlayerTeams] AS t1
              ON t1.NBAPlayerTeamID = fx.Team1TeamID
        JOIN [TraderInput].[dbo].[eBasketball_PlayerTeams] AS t2
              ON t2.NBAPlayerTeamID = fx.Team2TeamID;

        ---------------------------------------------------------------------
        -- Step 3: matchup row (order-agnostic) -> ##mu
        ---------------------------------------------------------------------
        SELECT TOP (1)
            m.LeagueCode,
            m.Player1ID,
            m.Player2ID,
            m.MatchUpAvgTotalPtsLong,
            m.MatchUpAvgTotalPtsShort,
            m.MatchUpHomeWinProb,
            m.MatchUpAwayWinProb,
            m.FixtureCount AS H2HCount,
            m.UpdatedDateTime
        INTO ##mu
        FROM ##tm AS tm
        JOIN dbo.Basketball_Ratings_Player_MatchUp AS m
              ON m.LeagueCode = tm.LeagueCode
             AND (
                    (m.Player1ID = tm.Player1ID AND m.Player2ID = tm.Player2ID)
                 OR (m.Player1ID = tm.Player2ID AND m.Player2ID = tm.Player1ID)
                 )
        ORDER BY m.UpdatedDateTime DESC;

        ---------------------------------------------------------------------
        -- Step 3A: player ratings for both players -> ##pr
        ---------------------------------------------------------------------
        SELECT
            p.RatingID,
            p.[Name],
            p.LeagueCode,
            p.UpdatedDateTime,
            p.ELORating,
            p.AvgPtsForLong,
            p.AvgPtsAgainstLong,
            p.AvgPtsForShort,
            p.AvgPtsAgainstShort,
            p.FixtureCount AS PlayerFixtureCount
        INTO ##pr
        FROM ##tm AS tm
        JOIN dbo.Basketball_Ratings_Player AS p
              ON p.LeagueCode = tm.LeagueCode
             AND p.RatingID IN (tm.Player1ID, tm.Player2ID);

        ---------------------------------------------------------------------
        -- Pivot player ratings into one row -> ##pp
        ---------------------------------------------------------------------
        SELECT
            tm.FixtureID,
            tm.LeagueCode,
            tm.Player1ID,
            tm.Player2ID,
            MAX(CASE WHEN pr.RatingID = tm.Player1ID THEN pr.ELORating           END) AS Team1Elo,
            MAX(CASE WHEN pr.RatingID = tm.Player2ID THEN pr.ELORating           END) AS Team2Elo,
            MAX(CASE WHEN pr.RatingID = tm.Player1ID THEN pr.PlayerFixtureCount END) AS Team1Matches,
            MAX(CASE WHEN pr.RatingID = tm.Player2ID THEN pr.PlayerFixtureCount END) AS Team2Matches
        INTO ##pp
        FROM ##tm AS tm
        LEFT JOIN ##pr AS pr
               ON 1 = 1
        GROUP BY tm.FixtureID, tm.LeagueCode, tm.Player1ID, tm.Player2ID;

        ---------------------------------------------------------------------
        -- Step 4: last H2H date for this pair in this league -> ##last
        -- (Adjust r.Player1ID/Player2ID columns if your schema differs)
        ---------------------------------------------------------------------
        SELECT
            MAX(r.FixtureDateTime) AS LastH2HDate
        INTO ##last
        FROM ##tm AS tm
        JOIN dbo.Basketball_FixtureResults AS r
              ON r.LeagueCode = tm.LeagueCode
             AND (
                    (r.Player1ID = tm.Player1ID AND r.Player2ID = tm.Player2ID)
                 OR (r.Player1ID = tm.Player2ID AND r.Player2ID = tm.Player1ID)
                 );

        ---------------------------------------------------------------------
        -- Final SELECT: one row shaped for the tooltip
        ---------------------------------------------------------------------
        SELECT
            tm.Team1Name,
            tm.Team2Name,
            ISNULL(pp.Team1Elo, 0)                 AS Team1Elo,
            ISNULL(pp.Team2Elo, 0)                 AS Team2Elo,
            ISNULL(pp.Team1Matches, 0)             AS Team1Matches,
            ISNULL(pp.Team2Matches, 0)             AS Team2Matches,
            ISNULL(mu.H2HCount, 0)                 AS H2HCount,
            (SELECT LastH2HDate FROM ##last)       AS LastH2HDate,
            ISNULL(mu.MatchUpAvgTotalPtsLong, 0)   AS Past30H2HAvg,
            ISNULL(mu.MatchUpAvgTotalPtsShort, 0)  AS Past5H2HAvg,
            -- diagnostics (optional)
            tm.LeagueCode,
            tm.Player1ID,
            tm.Player2ID
        FROM ##tm AS tm
        LEFT JOIN ##pp AS pp ON pp.FixtureID = tm.FixtureID
        LEFT JOIN ##mu AS mu ON 1 = 1;

    END TRY
    BEGIN FINALLY
        -- Always clean up global temp tables
        IF OBJECT_ID('tempdb..##fx')   IS NOT NULL DROP TABLE ##fx;
        IF OBJECT_ID('tempdb..##tm')   IS NOT NULL DROP TABLE ##tm;
        IF OBJECT_ID('tempdb..##mu')   IS NOT NULL DROP TABLE ##mu;
        IF OBJECT_ID('tempdb..##pr')   IS NOT NULL DROP TABLE ##pr;
        IF OBJECT_ID('tempdb..##pp')   IS NOT NULL DROP TABLE ##pp;
        IF OBJECT_ID('tempdb..##last') IS NOT NULL DROP TABLE ##last;
    END FINALLY
END
GO
