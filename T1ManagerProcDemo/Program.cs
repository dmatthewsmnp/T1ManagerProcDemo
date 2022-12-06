using Microsoft.Extensions.DependencyInjection;
using MNP.Common.SqlDbUtils;
using T1ManagerProcDemo;

using var serviceProvider = new ServiceCollection()
	.AddMemoryCache()
	.AddSqlServerConnectionHandleFactory(new Dictionary<string,string>() { {  "devsql", "Server=devsql.mnp.ca\\dev;Database=MNP_T1_Manager;Trusted_Connection=true;TrustServerCertificate=True;" } })
	.BuildServiceProvider();

var dataProvider = ActivatorUtilities.CreateInstance<DataProvider>(serviceProvider);

var byTaxpayerId = await dataProvider.GetTaxpayerSummaries(new List<long> { 14, 15, 16, 17 }, 999, 1, 2021, new Filter() { });
Console.WriteLine($"Retrieved {byTaxpayerId.Count()} documents (taxpayerid filter)");

var byFilter = await dataProvider.GetTaxpayerSummaries(new List<long>(), 0, 1, 2021, new Filter() { FilterType = FilterType.Preparer, FilterCriteria = 4980 });
Console.WriteLine($"Retrieved {byFilter.Count()} documents (preparer filter)");
