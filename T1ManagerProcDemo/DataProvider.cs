using System.Data;
using Microsoft.Data.SqlClient.Server;
using MNP.Common.SqlDbUtils.Interfaces;
using MNP.Common.SqlDbUtils.Models;

namespace T1ManagerProcDemo;

public class DataProvider
{
	private readonly ISqlConnectionHandleFactory _sqlFactory;
	public DataProvider(ISqlConnectionHandleFactory sqlFactory) => _sqlFactory = sqlFactory;

	public async Task<IEnumerable<TaxpayerSummary>> GetTaxpayerSummaries(IEnumerable<long> taxpayers, int quickViewId, int systemId, int systemYear, Filter filter)
	{
		// Connect to DB:
		await using var cnn = _sqlFactory.CreateConnection("devsql");
		await cnn.OpenAsync();

		// Execute stored proc:
		var queryResponse = await cnn.ExecuteQuery(
			queryCommandName: "dbo.Get_Taxpayer_Summaries",
			parameters: new CommandParameters()
			{
				{ "@System_ID", systemId },
				{ "@Year", systemYear },
				{ "@tbl_TaxpayerIDs", taxpayers.Any() ? StreamDataTable(taxpayers) : null },
				{ "@ShowAllTaxpayers", quickViewId == 0 },
				{ "@FilterType", filter.FilterType },
				{ "@FilterCriteria", filter.FilterCriteria },
				{ "@FilterLocationId", filter.LocationType.ToString() },
			});

		// Parse stored proc results and return:
		var retval = new List<TaxpayerSummary>();
		for (int i = 0; i < queryResponse.ResultRowCount(0); ++i)
		{
			retval.Add(new TaxpayerSummary
			{
				TaxpayerId = queryResponse.GetResultLong(0, i, "TaxpayerId") ?? throw new InvalidOperationException("Database returned null TaxpayerId"),
				MostRecentComment = queryResponse.GetResultValue(0, i, "MostRecentComment") as string,
				FileId = queryResponse.GetResultLong(0, i, "FileId") ?? throw new InvalidOperationException("Database returned null FileId"),
			});
		}
		return retval;
	}

	/// <summary>
	/// Stream data from taxpayer list into IEnumerable to be applied to SQL UDT table
	/// </summary>
	private static IEnumerable<SqlDataRecord> StreamDataTable(IEnumerable<long> taxpayers)
	{
		var inputRecord = new SqlDataRecord(new SqlMetaData[] {
			new SqlMetaData("Taxpayer_ID", SqlDbType.BigInt)
		});
		foreach (var taxpayerId in taxpayers)
		{
			inputRecord.SetInt64(0, taxpayerId);
			yield return inputRecord;
		}
	}
}
