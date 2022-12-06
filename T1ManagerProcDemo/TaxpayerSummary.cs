#nullable disable
namespace T1ManagerProcDemo;

public class TaxpayerSummary
{
	public long TaxpayerId { get; set; }
	public Guid ClientGuid { get; set; }
	public long FileId { get; set; }
	public Guid FileGuid { get; set; }
	public string T1FilePath { get; set; }
	public string T1FileName { get; set; }
	public string T1FullPath { get { return T1FilePath + @"\" + T1FileName; } }
	public string ClientStatus { get; set; }
	public string Department { get; set; }
	public string EfileStatus { get; set; }
	public string Name { get { return this.FirstName + ' ' + this.LastName; } }
	public string FirstName { get; set; }
	public string LastName { get; set; }
	public string AdminNo { get; set; }
	public string Admin { get { return this.AdminFirstName + ' ' + AdminLastName; } }
	public string AdminFirstName { get; set; }
	public string AdminLastName { get; set; }
	public string PreparerNo { get; set; }
	public string Preparer { get { return this.PreparerFirstName + ' ' + PreparerLastName; } }
	public string PreparerFirstName { get; set; }
	public string PreparerLastName { get; set; }
	public string PreparerComplexity { get { return PreparerComplexityType.ToString(); } }
	public PreparerLevelEnum PreparerComplexityType { get; set; }
	public string ReviewerNo { get; set; }
	public string Reviewer { get { return this.ReviewerFirstName + ' ' + ReviewerLastName; } }
	public string ReviewerFirstName { get; set; }
	public string ReviewerLastName { get; set; }
	public string ReviewerComplexity { get { return ReviewerComplexityType.ToString(); } }
	public ReviewerLevelEnum ReviewerComplexityType { get; set; }
	public string SIN { get; set; }
	public bool IsPrincipal { get; set; }
	public int MPMClientNo { get; set; }
	public string MPMClientName { get; set; }
	public string MPMRegionName { get; set; }
	public string MPMBusinessUnitName { get; set; }
	public string MPMPracticeUnitName { get; set; }
	public string NameAndSIN { get { return this.Name + (string.IsNullOrEmpty(this.SIN) ? "" : " (" + this.SIN + ")"); } }
	public string Title { get; set; }
	public string Salutation { get; set; }
	public string CareOf { get; set; }
	public string Address { get; set; }
	public string Apartment { get; set; }
	public string POBox { get; set; }
	public string City { get; set; }
	public string Province { get; set; }
	public string PostalCode { get; set; }
	public long? PhoneNo { get; set; }
	public string Email { get; set; }
	public OpiStatusEnum OpiStatus { get; set; }
	public TP1StatusEnum? TP1Status { get; set; }
	public ClientDeliveryStatusEnum? ClientDeliveryStatus { get; set; }
	public string TP1StatusDesc { get; set; }
	public string ClientDeliveryMethod { get; set; }
	public string ClientDeliveryStatusDesc { get; set; }
	public DateTime? DueDate { get; set; }
	public DateTime? EFILEFutureDate { get; set; }
	public DateTime? ReturnStatusDate { get; set; }
	public DateTime? RecordsInDate { get; set; }
	public string ReturnStatus { get; set; }
	public string ReturnStatusColor { get; set; }
	public bool IsWaitingForClient { get; set; }
	public string DoxCycleFullPath { get; set; }

	public string MostRecentComment { get; set; }
	public decimal? CRABalance { get; set; }
	public ReturnTypeEnums ReturnType { get; set; }
	public PrintType OfferLetterPrintMethod { get; set; }
	public PrintType ClientPackagePrintMethod { get; set; }
	public bool DoNotCarryForward { get; set; }
	public bool PrintStagingEnabled { get; set; }
	public EnumPrintStagingRequired PrintStagingRequired { get; set; }
}
