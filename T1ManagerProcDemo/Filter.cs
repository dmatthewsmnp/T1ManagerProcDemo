#nullable disable
namespace T1ManagerProcDemo;

public class Filter
{
	public FilterType FilterType { get; set; }
	public int? FilterCriteria { get; set; }
	public string Description { get; set; }
	public ClientLocationType? LocationType { get; set; }
	public int? LocationNo { get; set; }
}
