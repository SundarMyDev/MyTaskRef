CREATE OR ALTER PROCEDURE dbo.sp_GetOracleStats
    @FixtureID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH fx AS (
        /* Step 1: fixture basics (handle Team1ID vs TeamID naming gracefully) */
        SELECT
            f.Id                                            AS FixtureID,
            COALESCE(f.Team1ID, f.TeamID)                  AS Team1TeamID,
            f.Team2ID                                      AS Team2TeamID,
            f.LeagueCode
        FROM dbo.fixture AS f
        WHERE f.Id = @FixtureID
    ),
    teams AS (
        /* Step 2: map team IDs -> player IDs + display names */
        SELECT
            fx.FixtureID,
            fx.LeagueCode,
            t1.NBAPlayerTeamID     AS Team1TeamID,
            t1.BasketballPlayerID  AS Player1ID,
            t1.TeamDescription     AS Team1Name,
            t2.NBAPlayerTeamID     AS Team2TeamID,
            t2.BasketballPlayerID  AS Player2ID,
            t2.TeamDescription     AS Team2Name
        FROM fx
        JOIN [TraderInput].[dbo].[eBasketball_PlayerTeams] AS t1
              ON t1.NBAPlayerTeamID = fx.Team1TeamID
        JOIN [TraderInput].[dbo].[eBasketball_PlayerTeams] AS t2
              ON t2.NBAPlayerTeamID = fx.Team2TeamID
    ),
    last_h2h AS (
        /* Step 4: latest H2H date for this pair in this league */
        SELECT
            MAX(r.FixtureDateTime) AS LastH2HDate
        FROM teams tm
        JOIN dbo.Basketball_FixtureResults AS r
              ON r.LeagueCode = tm.LeagueCode
             AND (
                    (r.Player1ID = tm.Player1ID AND r.Player2ID = tm.Player2ID)
                 OR (r.Player1ID = tm.Player2ID AND r.Player2ID = tm.Player1ID)
                 )
        /* If your results table doesn’t have Player1ID/Player2ID, replace the join with:
           FROM fx
           JOIN dbo.Basketball_FixtureResults r ON r.FixtureID = fx.FixtureID
        */
    )
    SELECT
        tm.Team1Name,
        tm.Team2Name,

        /* Step 3A: player ELO + matches (joined twice for clarity & perf) */
        ISNULL(p1.ELORating, 0)               AS Team1Elo,
        ISNULL(p2.ELORating, 0)               AS Team2Elo,
        ISNULL(p1.FixtureCount, 0)            AS Team1Matches,
        ISNULL(p2.FixtureCount, 0)            AS Team2Matches,

        /* Step 3: matchup metrics (order-agnostic, latest by UpdatedDateTime) */
        ISNULL(mu.H2HCount, 0)                AS H2HCount,
        lh.LastH2HDate                        AS LastH2HDate,
        ISNULL(mu.MatchUpAvgTotalPtsLong, 0)  AS Past30H2HAvg,
        ISNULL(mu.MatchUpAvgTotalPtsShort, 0) AS Past5H2HAvg,

        /* optional diagnostics */
        tm.LeagueCode,
        tm.Player1ID,
        tm.Player2ID
    FROM teams tm
    /* Ratings (player-level), joined twice instead of pivoting */
    LEFT JOIN dbo.Basketball_Ratings_Player AS p1
           ON p1.LeagueCode = tm.LeagueCode
          AND p1.RatingID   = tm.Player1ID
    LEFT JOIN dbo.Basketball_Ratings_Player AS p2
           ON p2.LeagueCode = tm.LeagueCode
          AND p2.RatingID   = tm.Player2ID

    /* Latest matchup row via CROSS APPLY (order-agnostic P1/P2) */
    OUTER APPLY (
        SELECT TOP (1)
            m.MatchUpAvgTotalPtsLong,
            m.MatchUpAvgTotalPtsShort,
            m.FixtureCount AS H2HCount,
            m.UpdatedDateTime
        FROM dbo.Basketball_Ratings_Player_MatchUp m
        WHERE m.LeagueCode = tm.LeagueCode
          AND (
                (m.Player1ID = tm.Player1ID AND m.Player2ID = tm.Player2ID)
             OR (m.Player1ID = tm.Player2ID AND m.Player2ID = tm.Player1ID)
              )
        ORDER BY m.UpdatedDateTime DESC
    ) AS mu

    /* Latest H2H date (single value CTE) */
    LEFT JOIN last_h2h AS lh ON 1 = 1;
END
GO
