CREATE OR ALTER PROCEDURE dbo.usp_Update_AfterScore_To_AfterTime_ByPlbtId
    @PlbtId INT = NULL  -- if provided, only updates that plbtid; if NULL, updates all matching rows
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        -----------------------------------------------------------------------
        -- 1) Track changes for irt
        -----------------------------------------------------------------------
        DECLARE @IrtChanges TABLE
        (
            textid       INT         NOT NULL,
            plbtid       INT         NOT NULL,
            OriginalText NVARCHAR(MAX) NULL,
            UpdatedText  NVARCHAR(MAX) NULL
        );

        UPDATE i
            SET [text] = REPLACE(i.[text], 'After Score', 'After Time')
        OUTPUT
            inserted.textid,
            inserted.plbtid,
            deleted.[text]      AS OriginalText,
            inserted.[text]     AS UpdatedText
        INTO @IrtChanges(textid, plbtid, OriginalText, UpdatedText)
        FROM irt AS i
        WHERE (@PlbtId IS NULL OR i.plbtid = @PlbtId)
          AND i.[text] LIKE '%After Score%';

        -----------------------------------------------------------------------
        -- 2) Track changes for mlt (join rule: mlt.mltextid = irt.plbtid; language = 1)
        -----------------------------------------------------------------------
        DECLARE @MltChanges TABLE
        (
            mltextid     INT         NOT NULL,
            plbtid       INT         NOT NULL,
            OriginalText NVARCHAR(MAX) NULL,
            UpdatedText  NVARCHAR(MAX) NULL
        );

        UPDATE m
            SET m.mlpartcode = REPLACE(m.mlpartcode, 'After Score', 'After Time')
        OUTPUT
            inserted.mltextid,
            i.plbtid,
            deleted.mlpartcode  AS OriginalText,
            inserted.mlpartcode AS UpdatedText
        INTO @MltChanges(mltextid, plbtid, OriginalText, UpdatedText)
        FROM mlt AS m
        INNER JOIN irt AS i
            ON m.mltextid = i.plbtid
        WHERE m.mllanguageid = 1
          AND (@PlbtId IS NULL OR i.plbtid = @PlbtId)
          AND m.mlpartcode LIKE '%After Score%';

        COMMIT TRAN;

        -----------------------------------------------------------------------
        -- 3) FINAL RESULTSET:
        --    Distinct rows across BOTH updates with:
        --    plbtid, currenttext (before), newtext (after)
        -----------------------------------------------------------------------
        SELECT DISTINCT
            r.plbtid,
            r.CurrentText_Before AS currenttext,
            r.NewText_After      AS newtext
        FROM (
            SELECT plbtid,
                   OriginalText AS CurrentText_Before,
                   UpdatedText  AS NewText_After
            FROM @IrtChanges
            UNION ALL
            SELECT plbtid,
                   OriginalText,
                   UpdatedText
            FROM @MltChanges
        ) AS r
        ORDER BY r.plbtid, r.CurrentText_Before;

        -- If you also want to see what exactly changed per table, uncomment:
        -- SELECT * FROM @IrtChanges ORDER BY plbtid, textid;
        -- SELECT * FROM @MltChanges ORDER BY plbtid, mltextid;

    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
GO

------------------------------------------------------------
    
DECLARE @IrtChanges TABLE
(
    textid       INT           NOT NULL,
    plbtid       INT           NOT NULL,
    OriginalText NVARCHAR(MAX) NULL,
    UpdatedText  NVARCHAR(MAX) NULL
);

UPDATE i
SET [text] = REPLACE(CAST(i.[text] AS NVARCHAR(MAX)), 'After Score', 'After Time')
OUTPUT 
    inserted.textid,
    inserted.plbtid,
    CAST(deleted.[text] AS NVARCHAR(MAX)) AS OriginalText,
    CAST(inserted.[text] AS NVARCHAR(MAX)) AS UpdatedText
INTO @IrtChanges (textid, plbtid, OriginalText, UpdatedText)
FROM irt AS i
WHERE i.plbtid = 1
  AND CAST(i.[text] AS NVARCHAR(MAX)) LIKE '%After Score%';

SELECT * FROM @IrtChanges;

-------------------------------------------------------------------------


-- Track changes for MLT
DECLARE @MltChanges TABLE
(
    mltextid     INT           NOT NULL,
    plbtid       INT           NOT NULL,
    OriginalText NVARCHAR(MAX) NULL,
    UpdatedText  NVARCHAR(MAX) NULL
);

UPDATE m
SET m.mlpartcode = REPLACE(CAST(m.mlpartcode AS NVARCHAR(MAX)), 'After Score', 'After Time')
OUTPUT 
    inserted.mltextid,
    i.plbtid,
    CAST(deleted.mlpartcode AS NVARCHAR(MAX))  AS OriginalText,
    CAST(inserted.mlpartcode AS NVARCHAR(MAX)) AS UpdatedText
INTO @MltChanges (mltextid, plbtid, OriginalText, UpdatedText)
FROM mlt AS m
INNER JOIN irt AS i
    ON m.mltextid = i.plbtid
WHERE i.plbtid = 1                  -- your plbtid filter
  AND m.mllanguageid = 1            -- language filter
  AND CAST(m.mlpartcode AS NVARCHAR(MAX)) LIKE '%After Score%';

-- Distinct rows changed in MLT
SELECT DISTINCT
    plbtid,
    OriginalText,
    UpdatedText
FROM @MltChanges
ORDER BY plbtid, OriginalText;

