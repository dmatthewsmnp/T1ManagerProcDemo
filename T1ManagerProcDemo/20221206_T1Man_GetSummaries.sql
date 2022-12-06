USE [MNP_T1_Manager]
GO
/* POTENTIAL INDEXES:
- dbo.T1_Return Year/System_ID/Is_Deleted
- dbo.T1_Client File_ID
- dbo.Return_States (currently a heap, but tiny table?)
- dbo.Return_States_Mapping WorkflowGUID, System_ID, Year
- dbo.Workflow (very small so maybe not worth the bother, but could do Workflow_GUID)
- Batch.Print_Job_Items Taxpayer_ID
*/
GO
CREATE TYPE dbo.udt_TaxpayerIDs AS TABLE (
	Taxpayer_ID bigint NOT NULL PRIMARY KEY CLUSTERED
);
GO
GRANT EXECUTE ON TYPE::dbo.udt_TaxpayerIDs TO public;
GO
GRANT VIEW DEFINITION ON TYPE::dbo.udt_TaxpayerIDs TO public;
GO
CREATE PROCEDURE dbo.Get_Taxpayer_Summaries
	@System_ID int,
	@Year smallint,
	-- Taxpayer filters:
	@tbl_TaxpayerIDs dbo.udt_TaxpayerIDs READONLY, -- Filter list of Taxpayer_ID values in structured UDT
	@ShowAllTaxpayers bit = 0, -- Can be enabled to ignore TaxpayerID filtering and return all matches
	-- Filter parameters:
	@FilterType int = 0, -- Default 0 (Filter.All; see Enum FilterType)
	@FilterCriteria int = NULL,
	@FilterLocationType varchar(20) = NULL -- Only applies for @FilterType = 3 (Dept_PU), one of 'PracticeUnit' or 'Department' (string representation of Enum ClientLocationType)
AS
SET NOCOUNT ON;

SELECT
	tc.Taxpayer_ID [TaxpayerId],
	comment.Comment [MostRecentComment],
	tr.[File_ID] [FileId],
	tr.File_GUID [FileGuid],
	tc.Client_GUID [ClientGuid],
	tr.File_Path [T1FilePath],
	tr.[File_Name] [T1FileName],
	dox.File_Path [DoxCycleFullPath],
	wflow.ClientStatus,
	efile.Rank_Efile_Status [EfileStatus],
	mined.First_Name [FirstName],
	mined.Last_Name [LastName],
	mined.SIN [SIN],
	tr.Do_Not_CarryForward [DoNotCarryForward],
	rstypes.State_Order [ReturnState], -- Note: May impact DoNotCarryForward value if NotFiling/NotStarted and system settings are enabled (DM20221206: see CommonT1ManagerQueries lines 142-144)
	nonmined.Admin_No [AdminNo],
	adminpers.First_Name [AdminFirstName],
	adminpers.Last_Name [AdminLastName],
	nonmined.Preparer_No [PreparerNo],
	preppers.First_Name [PreparerFirstName],
	preppers.Last_Name [PreparerLastName],
	ISNULL(nonmined.Preparer_Level, 0) [PreparerComplexityType], -- Note: converted to Enum
	nonmined.Reviewer_No [ReviewerNo],
	revpers.First_Name [ReviewerFirstName],
	revpers.Last_Name [ReviewerLastName],
	ISNULL(nonmined.Reviewer_Level, 0) [ReviewerComplexityType], -- Note: converted to Enum
	mined.Client_No [MPMClientNo],
	client.[Name] [MPMClientName],
	dept.Dept_Name [Department],
	dept.Practice_Unit_Name [MPMPracticeUnitName],
	dept.Business_Unit_Name [MPMBusinessUnitName],
	dept.Region_Name [MPMRegionName],
	mined.Title,
	mined.Salutation,
	mined.Care_Of [CareOf],
	mined.[Address],
	mined.Apartment,
	mined.PO_Box [POBox],
	mined.City,
	mined.Province,
	mined.Postal_Code [PostalCode],
	mined.Phone_No [PhoneNo],
	mined.Tax_Return_Email [Email],
	mined.CRA_Balance [CRABalance],
	ISNULL(mined.Return_Type, 0) [ReturnType],
	mined.TP1_Status [TP1Status],
	tp1s.TP1_Status [TP1StatusDesc],
	mined.Client_Delivery_Status [ClientDeliveryStatus],
	cds.Client_Delivery_Status [ClientDeliveryStatusDesc],
	mined.Client_Delivery_Method [ClientDeliveryMethod],
	otcs.opi_state [OpiStatus],
	ddate.DueDate,
	CASE nonmined.EFILE_Release_Option_Type WHEN 1 THEN nonmined.EFILE_After_Specific_Date END [EFILEFutureDate],
	wflow.ReturnStatusDate,
	wflow.RecordsInDate,
	rstypes.Return_State [ReturnStatus],
	rstypes.State_Hex_Color [ReturnStatusColor],
	ISNULL(mined.Client_OnHold, 0) [IsWaitingForClient],
	ISNULL(lett.Print_Type, 0) [OfferLetterPrintMethod], -- Note: converted to Enum
	CASE
		WHEN lastprint.Is_PDF = 1 AND lastprint.Is_Paper = 1 THEN 3
		WHEN lastprint.Is_PDF = 1 THEN 2
		WHEN lastprint.Is_Paper = 1 THEN 1
		ELSE 0
	END [ClientPackagePrintMethod] -- Note: converted to Enum
FROM dbo.T1_Client tc
INNER JOIN dbo.T1_Return tr ON tr.[File_ID] = tc.[File_ID]
	AND tr.System_ID = @System_ID
	AND tr.[Year] = @Year
	AND tr.Is_Deleted = 0
LEFT JOIN @tbl_TaxpayerIDs ttids ON ttids.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN (
	SELECT inwf.Taxpayer_ID,
		-- Extract values from MAX'd strings in inner query:
		CONVERT(smallint, SUBSTRING(inwf.ClientWorkflowTopState, 7, 6)) [State_Order], -- CASE WHEN efile.Last_Efile_Status_ID IN (11,101) THEN 7 ELSE 
		RTRIM(SUBSTRING(inwf.ClientWorkflowTopState, 13, 50)) [Return_State], -- CASE WHEN efile.Last_Efile_Status_ID IN (11,101) THEN 'Efile Accepted' ELSE 
		CONVERT(datetime, SUBSTRING(inwf.ClientWorkflowTopState, 63, 23), 126) [ReturnStatusDate],
		CONVERT(datetime, inwf.ClientWorkflowRecordsIn, 126) [RecordsInDate],
		SUBSTRING(inwf.WorkflowTopRank, 7, 255) [ClientStatus]
	FROM (
		SELECT
			tcwf.Taxpayer_ID,
			MAX( -- Order/completed date, ranked by return state order (using mapping value, if available)
				RIGHT('000000' + CONVERT(varchar(6), ISNULL(rsm.State_Order, rs.State_Order)), 6)
				+ RIGHT('000000' + CONVERT(varchar(6), rs.State_Order), 6)
				+ CONVERT(char(50), rs.Return_State)
				+ ISNULL(CONVERT(char(23), tcwf.Completed_Date, 126), '')
			) [ClientWorkflowTopState],
			NULLIF(MAX( -- Completed date specifically for "records in" status:
				ISNULL(CASE ISNULL(rsm.State_Order, rs.State_Order) WHEN 2 THEN CONVERT(char(23), tcwf.Completed_Date, 126) END, '')
			), '') [ClientWorkflowRecordsIn],
			MAX( -- Workflow title, ranked by Workflow rank
				RIGHT('000000' + CONVERT(varchar(6), wf.[Rank]), 6)
				+ wf.Title
			) [WorkflowTopRank]
		FROM dbo.T1_ClientWorkflow tcwf
		INNER JOIN dbo.Workflow wf ON wf.Workflow_ID = tcwf.Workflow_ID
		INNER JOIN dbo.Return_States rs ON rs.WorkflowGUID = wf.Workflow_GUID
		LEFT JOIN dbo.Return_States_Mapping rsm ON rsm.WorkflowGUID = wf.Workflow_GUID
			AND rsm.System_Id = @System_ID
			AND rsm.[Year] = @Year
		WHERE tcwf.Is_Completed = 1
		GROUP BY tcwf.Taxpayer_ID
	) inwf
) wflow ON wflow.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN (
	SELECT tcwfdd.Taxpayer_ID,
		-- Most-recent non-null due-date value for this taxpayer/Workflow_GUID combination:
		MAX(tcwfdd.Due_Date) [DueDate]
	FROM dbo.T1_ClientWorkflow tcwfdd
	INNER JOIN dbo.Workflow wfdd ON wfdd.Workflow_ID = tcwfdd.Workflow_ID
		AND wfdd.Workflow_GUID = 'B1CB1BB8-19CB-4F72-ADFD-F02E54AE16B7'
	WHERE tcwfdd.Due_Date IS NOT NULL
	GROUP BY tcwfdd.Taxpayer_ID
) ddate ON ddate.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN (
	SELECT efd.Taxpayer_ID,
		-- Most recent Efile_Status_ID (ranked by date):
		CONVERT(tinyint, SUBSTRING(MAX(CONVERT(char(23), efd.[Date], 126) + CONVERT(varchar(3), efd.Efile_Status_ID)), 24, 3)) [Last_Efile_Status_ID],
		-- Most recent Efile_Status (ranked by ID):
		SUBSTRING(MAX(RIGHT(REPLICATE('0', 20) + efd.T1_EfileDetail_ID, 20) + efs.Efile_Status), 20, 50) [Rank_Efile_Status]
	FROM dbo.T1_EfileDetails efd
	INNER JOIN dbo.Efile_Status efs ON efs.Efile_Status_ID = efd.Efile_Status_ID
	GROUP BY efd.Taxpayer_ID
) efile ON efile.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.Return_State_Types rstypes ON rstypes.State_Order = CASE WHEN efile.Last_Efile_Status_ID IN (11,101) THEN 7 ELSE wflow.State_Order END
LEFT JOIN (
	SELECT lf.Taxpayer_ID,
		MAX(lf.ID) [Max_ID] -- Highest matching value (emit ID value for 2nd clustered seek join below, since File_Path is varchar(max)):
	FROM dbo.T1_ClientLinkedFiles lf
	WHERE Is_Doxcycle = 1
	GROUP BY lf.Taxpayer_ID
) maxdox ON maxdox.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.T1_ClientLinkedFiles dox ON dox.ID = maxdox.Max_ID
	AND dox.Taxpayer_ID = maxdox.Taxpayer_ID -- Not strictly required for join, but part of clustered index
LEFT JOIN (
	SELECT cm.Taxpayer_ID,
		-- Most recent Comment_ID (ranked by date; emit Comment_ID for 2nd clustered seek join below, since Comment is varchar(max)):
		CONVERT(bigint, SUBSTRING(MAX(CONVERT(char(23), cm.[Date], 126) + CONVERT(varchar(20), cm.Comment_ID)), 24, 20)) [Comment_ID]
	FROM dbo.T1_Comment cm
	WHERE cm.Date_Deleted IS NULL
	GROUP BY cm.Taxpayer_ID
) maxcm ON maxcm.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.T1_Comment comment ON comment.Comment_ID = maxcm.Comment_ID -- Retrieve details of max row selected by above query
LEFT JOIN (
	SELECT inlp.Taxpayer_ID,
		-- Extract values from MAX'd string in inner query:
		CONVERT(bit, SUBSTRING(inlp.LastPrintItems, 21, 1)) [Is_Paper],
		CONVERT(bit, SUBSTRING(inlp.LastPrintItems, 22, 1)) [Is_PDF]
	FROM (
		SELECT bpi.Taxpayer_ID,
			MAX( -- Is_Paper/Is_PDF of most recent (ID-ranked) record:
				RIGHT(REPLICATE('0', 20) + CONVERT(varchar(20), bpi.Batch_Item_ID), 20)
				+ CONVERT(char(1), bpi.Is_Paper)
				+ CONVERT(char(1), bpi.Is_PDF)
			) [LastPrintItems]
		FROM Batch.Print_Job_Items bpi
		GROUP BY bpi.Taxpayer_ID
	) inlp
) lastprint on lastprint.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.T1_ClientMinedDetails mined ON mined.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.T1_ClientNonMined nonmined ON nonmined.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.T1_ClientLetterDetails lett ON lett.Taxpayer_ID = tc.Taxpayer_ID
LEFT JOIN dbo.TP1_Status tp1s ON tp1s.TP1_Status_ID = mined.TP1_Status
LEFT JOIN dbo.Client_Delivery_Status cds ON cds.Client_Delivery_Status_ID = mined.Client_Delivery_Status
LEFT JOIN Opi.Transfer_Client_State otcs ON otcs.taxpayer_id = tc.Taxpayer_ID
LEFT JOIN dbo.MPM_Personnel adminpers ON adminpers.Personnel_No = nonmined.Admin_No
LEFT JOIN dbo.MPM_Personnel preppers ON preppers.Personnel_No = nonmined.Preparer_No
LEFT JOIN dbo.MPM_Personnel revpers ON revpers.Personnel_No = nonmined.Reviewer_No
LEFT JOIN dbo.MPM_Clients client ON client.Client_No = mined.Client_No
LEFT JOIN dbo.MPM_Dept_PU dept ON dept.Dept_No = client.Dept_No
WHERE  tc.Is_Deleted = 0
	AND (ttids.Taxpayer_ID IS NOT NULL OR @ShowAllTaxpayers = 1)
	AND (
		@FilterType = 0 -- All
		OR (
			@FilterType = 1  -- Preparer
			AND @FilterCriteria = nonmined.Preparer_No
		)
		OR (
			@FilterType = 2 -- Reviewer
			AND @FilterCriteria = nonmined.Reviewer_No
		)
		OR (
			@FilterType = 3 -- Dept/PU
			AND @FilterCriteria = CASE @FilterLocationType WHEN 'PracticeUnit' THEN dept.Practice_Unit_No WHEN 'Department' THEN dept.Dept_No END
		)
		OR (
			@FilterType = 4 -- GP
			AND @FilterCriteria IN (dept.[PU CEM], dept.[Dept CEM])
		)
		OR (
			@FilterType = 5 -- Return Type
			AND @FilterCriteria = mined.Return_Type
		)
		OR (
			@FilterType = 6 -- Preparer Complexity
			AND @FilterCriteria = nonmined.Preparer_Level
		)
		OR (
			@FilterType = 7 -- Reviewer Complexity
			AND @FilterCriteria = nonmined.Reviewer_Level
		)
		OR (
			@FilterType = 8 -- My Files
			AND @FilterCriteria IN (nonmined.Preparer_No, nonmined.Reviewer_No, dept.[PU CEM], dept.[Dept CEM])
		)
	)
;

RETURN @@ERROR;

GO
/*
EXEC dbo.Get_Taxpayer_Summaries
	@System_ID = 1,
	@Year = 2021,
	--@tbl_TaxpayerIDs = NULL,
	@ShowAllTaxpayers = 1,
	@FilterType = 0,
	@FilterCriteria = NULL,
	@FilterLocationType = NULL -- Only applies for @FilterType = 3 (Dept_PU), one of 'PracticeUnit' or 'Department' (string representation of Enum ClientLocationType)
;
*/
