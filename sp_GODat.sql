CREATE OR ALTER PROCEDURE dbo.sp_GetOracleStats
    @FixtureID BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- Step 1: Fixture basics
    -------------------------------------------------------------------------
    ;WITH fx AS (
        SELECT
            tbl1.Id            AS FixtureID,
            tbl1.TeamID        AS Team1TeamID,
            tbl1.Team2ID       AS Team2TeamID,
            tbl1.LeagueCode
        FROM tbl1 AS f
        WHERE f.Id = @FixtureID
    ),
    -------------------------------------------------------------------------
    -- Step 2: Map TeamIDs -> PlayerIDs + TeamDescriptions (names)
    -------------------------------------------------------------------------
    team_map AS (
        SELECT
            fx.FixtureID,
            fx.LeagueCode,
            tbl2.NBAPlayerTeamID     AS Team1TeamID,
            tbl2.BasketballPlayerID  AS Player1ID,
            tbl2.TeamDescription     AS Team1Name,
            tbl2b.NBAPlayerTeamID    AS Team2TeamID,
            tbl2b.BasketballPlayerID AS Player2ID,
            tbl2b.TeamDescription    AS Team2Name
        FROM fx
        JOIN tbl2 AS t1  ON t1.NBAPlayerTeamID = fx.Team1TeamID
        JOIN tbl2 AS t2b ON t2b.NBAPlayerTeamID = fx.Team2TeamID
    ),
    -------------------------------------------------------------------------
    -- Step 3: Get the MatchUp row for the pair (order-agnostic)
    -------------------------------------------------------------------------
    mu AS (
        SELECT TOP (1)
            tbl3.LeagueCode,
            tbl3.Player1ID,
            tbl3.Player2ID,
            tbl3.MatchUpAvgTotalPtsLong,
            tbl3.MatchUpAvgTotalPtsShort,
            tbl3.MatchUpHomeWinProb,
            tbl3.MatchUpAwayWinProb,
            tbl3.FixtureCount           AS H2HCount,
            tbl3.UpdatedDateTime
        FROM team_map tm
        JOIN tbl3 AS m
             ON m.LeagueCode = tm.LeagueCode
            AND (
                    (m.Player1ID = tm.Player1ID AND m.Player2ID = tm.Player2ID)
                 OR (m.Player1ID = tm.Player2ID AND m.Player2ID = tm.Player1ID)
                )
        ORDER BY m.UpdatedDateTime DESC
    ),
    -------------------------------------------------------------------------
    -- Step 3A: Player ratings for the two players (per-league)
    -------------------------------------------------------------------------
    pr AS (
        SELECT
            tbl4.RatingID,
            tbl4.[Name],
            tbl4.LeagueCode,
            tbl4.UpdatedDateTime,
            tbl4.ELORating,
            tbl4.AvgPtsForLong,
            tbl4.AvgPtsAgainstLong,
            tbl4.AvgPtsForShort,
            tbl4.AvgPtsAgainstShort,
            tbl4.FixtureCount AS PlayerFixtureCount
        FROM team_map tm
        JOIN tbl4 AS p
             ON p.LeagueCode = tm.LeagueCode
            AND p.RatingID IN (tm.Player1ID, tm.Player2ID)
    ),
    pr_pivot AS (
        SELECT
            tm.FixtureID,
            tm.LeagueCode,
            tm.Player1ID,
            tm.Player2ID,
            MAX(CASE WHEN pr.RatingID = tm.Player1ID THEN pr.ELORating END)          AS Team1Elo,
            MAX(CASE WHEN pr.RatingID = tm.Player2ID THEN pr.ELORating END)          AS Team2Elo,
            MAX(CASE WHEN pr.RatingID = tm.Player1ID THEN pr.PlayerFixtureCount END) AS Team1Matches,
            MAX(CASE WHEN pr.RatingID = tm.Player2ID THEN pr.PlayerFixtureCount END) AS Team2Matches
        FROM team_map tm
        LEFT JOIN pr ON 1=1
        GROUP BY tm.FixtureID, tm.LeagueCode, tm.Player1ID, tm.Player2ID
    ),
    -------------------------------------------------------------------------
    -- Step 4: Last H2H Date
    -------------------------------------------------------------------------
    last_h2h AS (
        SELECT
            MAX(tbl5.FixtureDateTime) AS LastH2HDate
        FROM team_map tm
        JOIN tbl5 AS r
             ON r.LeagueCode = tm.LeagueCode
            AND (
                  (r.Player1ID = tm.Player1ID AND r.Player2ID = tm.Player2ID)
               OR (r.Player1ID = tm.Player2ID AND r.Player2ID = tm.Player1ID)
                )
    )

    -------------------------------------------------------------------------
    -- Final result
    -------------------------------------------------------------------------
    SELECT
        tm.Team1Name,
        tm.Team2Name,
        ISNULL(pp.Team1Elo, 0)              AS Team1Elo,
        ISNULL(pp.Team2Elo, 0)              AS Team2Elo,
        ISNULL(pp.Team1Matches, 0)          AS Team1Matches,
        ISNULL(pp.Team2Matches, 0)          AS Team2Matches,
        ISNULL(mu.H2HCount, 0)              AS H2HCount,
        (SELECT LastH2HDate FROM last_h2h)  AS LastH2HDate,
        ISNULL(mu.MatchUpAvgTotalPtsLong, 0)  AS Past30H2HAvg,
        ISNULL(mu.MatchUpAvgTotalPtsShort, 0) AS Past5H2HAvg,
        tm.LeagueCode,
        tm.Player1ID,
        tm.Player2ID
    FROM team_map tm
    LEFT JOIN pr_pivot pp ON pp.FixtureID = tm.FixtureID
    LEFT JOIN mu         ON 1=1;
END
GO
