namespace T1ManagerProcDemo;

public enum PreparerLevelEnum
{
	Unknown,
	Complex,
	Intermediate,
	Simple
}

public enum ReviewerLevelEnum
{
	Unknown,
	TaxSpecialist,
	GP,
	TaxPoolExpManager,
	TaxPoolManagerOrSeniorTech
}

public enum OpiStatusEnum
{
	None = 1,
	OutToOpi = 2,
	InFromOpi = 3,
	Complete = 4
}

public enum TP1StatusEnum
{
	NA,
	InProgress,
	NetFiled,
	PaperFiled,
	Completed
}

public enum ClientDeliveryStatusEnum
{
	NA,
	Completed
}

public enum ReturnTypeEnums
{
	Unknown = 0,
	Farm = 1,
	SelfEmployment = 2,
	Investment = 3,
	SlipReturn = 4,
	NilReturn = 5
}

public enum PrintType
{
	None,
	Paper,
	PDF,
	PaperAndPDF
}

public enum EnumPrintStagingRequired
{
	NotRequired,
	ParagraphChanged
}

public enum FilterType
{
	All = 0,
	Preparer = 1,
	Reviewer = 2,
	DeptPu = 3,
	GP = 4,
	ReturnType = 5,
	PreparerComplexity = 6,
	ReviewerComplexity = 7,
	MyFiles = 8
}

public enum ClientLocationType
{
	PracticeUnit,
	Department
}
