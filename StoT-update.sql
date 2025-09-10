CREATE OR ALTER PROCEDURE dbo.usp_Update_AfterScore_To_AfterTime
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        -----------------------------------------------------------------------
        -- 1) Capture the irt rows we’re going to change (by textid) into a table variable
        -----------------------------------------------------------------------
        DECLARE @AffectedIrt TABLE (textid INT PRIMARY KEY);

        -- Update irt.[text] only where:
        --   - it contains '/'
        --   - plbtid in (1,2,3)
        --   - and contains the phrase 'After Score'
        -- Also, record textid of the rows actually changed in @AffectedIrt
        UPDATE i
            SET [text] = REPLACE(i.[text], 'After Score', 'After Time')
        OUTPUT inserted.textid
            INTO @AffectedIrt(textid)
        FROM irt AS i
        WHERE i.plbtid IN (1,2,3)
          AND i.[text] LIKE '%/%'
          AND i.[text] LIKE '%After Score%';

        -----------------------------------------------------------------------
        -- 2) Update mlt for ONLY those textids affected above and mllanguageid = 1
        --    Replace 'After Score' -> 'After Time' in mlpartcode
        -----------------------------------------------------------------------
        UPDATE m
            SET m.mlpartcode = REPLACE(m.mlpartcode, 'After Score', 'After Time')
        FROM mlt AS m
        INNER JOIN @AffectedIrt AS a
            ON a.textid = m.mltextid
        WHERE m.mllanguageid = 1
          AND m.mlpartcode LIKE '%After Score%';

        COMMIT TRAN;

        -- Optional: return counts for visibility
        SELECT
            (SELECT COUNT(*) FROM @AffectedIrt) AS UpdatedIrtRowCount;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;

        -- Bubble the error
        THROW;
    END CATCH
END;
GO
