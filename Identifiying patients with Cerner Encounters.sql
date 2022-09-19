

/*******************************************************************************************************************************
Description : [MillCDS].[DimVALocation]
Contains OrganizationNameSID which is joined in all the Fact tables to get the Sta6a and StaPa

Including the date at which each site when live with Cerner. This is used in various other scripts in our architecture. 

December 2021 update:
The Tripler Army Medical Center went live with Genesis in late Summer 2021.
Within Tripler, there is a VA inpatient MH ward, and they are using Genesis
as well. It was noted in December 2021 that we are getting those inpatient
encounters for that VA MH ward. The VA MH ward is not setup the same 
way in the NDimMill.OrganizationName and NDimMill.OrganizationAlias as all
the other VA locations. So, we are adding some code to make sure it is included 
in our DimVALocation table.

JK Notes: Currently experimenting how to make a list of all patients with their first encounter to remove from RISK ID currently.
This is utilizing the PERC tables to create stored procedures until I get access/ file space figured out on where to save 
*******************************************************************************************************************************/

USE CDWWork2

	DROP TABLE IF EXISTS #StageMillCDSDimVALocation;

	SELECT 
		 orgn.OrganizationNameSID
		,orgn.OrganizationNameID
		,orgn.OrganizationName
		,visn.OrganizationAlias AS Visn
		,stap.OrganizationAlias AS STAPA
		,dvsn.OrganizationAlias AS STA6A
		,dvsa.OrganizationAlias AS Divison
		,IOCDate =
		 CASE
		 WHEN stap.OrganizationAlias = '668' THEN CAST('2020-10-24' AS DATETIME2(0)) /*Spokane*/
		 WHEN orgn.OrganizationNameID = '3435481' THEN CAST('2021-09-24' AS DATETIME2(0)) /*459 Inpatient MH Ward at Tripler DoD - IOCDate per Sean Griffith at Cerner.*/
		 WHEN stap.OrganizationAlias = '687' THEN CAST('2022-03-26' AS DATETIME2(0)) /*Walla Walla*/
		 WHEN stap.OrganizationAlias = '757' THEN CAST('2022-04-30' AS DATETIME2(0)) /*Columbus*/
		 WHEN stap.OrganizationAlias = '653' THEN CAST('2022-06-11' AS DATETIME2(0)) /*Roseburg*/
		 WHEN stap.OrganizationAlias = '692' THEN CAST('2022-06-11' AS DATETIME2(0)) /*White City*/
		 WHEN stap.OrganizationAlias = '531' THEN CAST('2022-07-23' AS DATETIME2(0)) /*Boise*/
		 ELSE CAST('8000-03-01' AS DATETIME2(0)) /*Setting all other sites to a date far into the future.*/
		 END
	INTO #StageMillCDSDimVALocation

	FROM NDimMill.OrganizationName				AS orgn --Organization details table

	INNER JOIN NDimMill.OrganizationAlias		AS visn --Code value for VA VISN
		ON orgn.OrganizationNameSID = visn.OrganizationNameSID
		AND EXISTS 
		(
			SELECT 1 
			FROM NDimMill.CodeValue AS cv 
			WHERE visn.AliasPoolCodeValueSID = cv.CodeValueSID
			AND cv.CodeValueSetID = '263'
			AND cv.DisplayKey = 'VAVISN'
			AND cv.ActiveIndicator = 1
		) 
		AND visn.ActiveIndicator = 1 

	INNER JOIN NDimMill.OrganizationAlias		AS stap --Code value for VA SITE PARENT
		ON orgn.OrganizationNameSID = stap.OrganizationNameSID
		AND EXISTS 
		(
			SELECT 1 
			FROM NDimMill.CodeValue AS cv 
			WHERE stap.AliasPoolCodeValueSID = cv.CodeValueSID
			AND cv.CodeValueSetID = '263'
			AND cv.DisplayKey = 'VASITEPARENT'
			AND cv.ActiveIndicator = 1
		) 
		AND stap.ActiveIndicator = 1 

	INNER JOIN NDimMill.OrganizationAlias		AS dvsn --Code value for VA STATION/DIVISON NUMBER
		ON orgn.OrganizationNameSID = dvsn.OrganizationNameSID
		AND EXISTS 
		(
			SELECT 1 
			FROM NDimMill.CodeValue AS cv 
			WHERE dvsn.AliasPoolCodeValueSID = cv.CodeValueSID
			AND cv.CodeValueSetID = '263'
			AND cv.DisplayKey = 'VASTATIONDIVISIONNUMBER'
			AND cv.ActiveIndicator = 1
		) 
		AND dvsn.ActiveIndicator = 1 

	LEFT JOIN NDimMill.OrganizationAlias		AS dvsa --Code value for VA DIVISION NAME
		ON orgn.OrganizationNameSID = dvsa.OrganizationNameSID
		AND EXISTS 
		(
			SELECT 1 
			FROM NDimMill.CodeValue AS cv 
			WHERE dvsa.AliasPoolCodeValueSID = cv.CodeValueSID
			AND cv.CodeValueSetID = '263'
			AND cv.DisplayKey = 'VADIVISIONNAME'
			AND cv.ActiveIndicator = 1
		) 
		AND dvsa.ActiveIndicator = 1 

	WHERE orgn.ActiveIndicator = 1 
	AND 
	EXISTS (SELECT 1 FROM NDimMill.CodeValue AS cdvl WHERE visn.AliasPoolCodeValueSID = cdvl.CodeValueSID AND cdvl.DisplayKey LIKE 'VA%') --Where Alias pool Display key includes 'VA' in the value


	/* 
	 Making sure the VA inpatient Mental Health Ward within the Tripler Army Medical Center is included in our
		output table. The ward is not setup the same way as all the other VA facilities in the OrganizationName
		and OrganizationAlias table, thus requires special considersation here. 
		459 Spark M Matsunaga Acute Psych HI VA Medical Center - ORGANIZATION.ORGANIZATION_ID = 3435481
	*/
	IF (SELECT COUNT(1) FROM #StageMillCDSDimVALocation WHERE 1=1 AND OrganizationNameID = '3435481') = 0
		BEGIN 
				INSERT INTO #StageMillCDSDimVALocation
				SELECT orgn.OrganizationNameSID
		 ,orgn.OrganizationNameID
		 ,orgn.OrganizationName
					 ,'21' AS Visn
					 ,'459' AS STAPA
					 ,'459' AS STA6A
					 ,NULL AS Divison
					 ,CAST('2021-09-24' AS DATETIME2(0)) AS IOCDate /*459 Inpatient MH Ward at Tripler DoD - IOCDate per Sean Griffith at Cerner.*/
				FROM NDimMill.OrganizationName orgn
				WHERE 1=1
				 AND OrganizationNameID = '3435481'; END;

/* This data set seems to pull only Cerner sites that are implemented or plan to be/ are in the same VISN as active Cerner sites
ie. Boise is listed even though implementation is delayed. Also Ann Arbor is listed 
Will have to monitor PERC Code here for any additional weird sites like above : https://vaww.pbi.cdw.va.gov/PBIRS/Pages/ReportViewer.aspx?/RVS/OMHSP_PERC/SSRS/Production/CDS/Definitions/PERCMillCodeSharing

As of 7/21/22 - 1,351 sites
*/

--Select * from #StageMillCDSDimVALocation
/*******************************************************************************************************************************
Description: Loading encounter records from Cerner EXCLUDING the records that were created to migrate historic VistA data into 
			 Cerner. Historic VistA data was added to Cerner for continuity of care. This historic data is sometimes referred to
			 as the PAMPI data. PAMPI = PHARMACY, ALLERGIES, MED, PROCEDURES, IMMUNIZATIONS. PAMPI data was prioritized in the 
			 migration of historic records.

			 Adding in STAPA, STA6A, and OrganizationName. 

			 EncounterSID is the primary key. 

Important Notes:

	-Beth Gibson: EncounterType = 'History' is reserved for migrated data. We are using that method in this script. 

	-Margaret Gonsoulin: Could check contributor system names on the PAMPI data as additional logic for identifying 
	 historically migrated data. 

*******************************************************************************************************************************/


	DROP TABLE IF EXISTS #EncMillEncounterStg;
		SELECT 
			 encr.[EncounterSID] 
			,encr.[EncounterID] 
			,encr.[PersonSID] 
			,encr.[ActiveIndicator] 
			,encr.[ActiveStatus] 
			,encr.[ActiveStatusCD] 
			,encr.[ActiveStatusCodeValueSID] 
			,encr.[ActiveStatusDateTime] 
			,encr.[ActiveStatusPersonStaffSID] 
			,encr.[CreateDateTime] 
			,encr.[CreatePersonStaffSID] 
			,encr.[BeginEffectiveDateTime] 
			,encr.[EndEffectiveDateTime] 
			,encr.[EncounterClass] 
			,encr.[EncounterClassCD] 
			,encr.[EncounterClassCodeValueSID] 
			,encr.[EncounterType] 
			,encr.[EncounterTypeCD] 
			,encr.[EncounterTypeCodeValueSID] 
			,encr.[EncounterTypeClass] 
			,encr.[EncounterTypeClassCD] 
			,encr.[EncounterTypeClassCodeValueSID] 
			,encr.[EncounterStatus] 
			,encr.[EncounterStatusCD] 
			,encr.[EncounterStatusCodeValueSID] 
			,encr.[PreRegistrationDateTime] 
			,encr.[PreRegistrationPersonStaffSID] 
			,encr.[RegistrationDateTime] 
			,encr.[RegistrationPersonStaffSID] 
			,encr.[EstimateArriveDateTime] 
			,encr.[EstimateDepartDateTime] 
			,encr.[ArriveDateTime] 
			,encr.[DepartDateTime] 
			,encr.[AdmitType] 
			,encr.[AdmitTypeCD] 
			,encr.[AdmitTypeCodeValueSID] 
			,encr.[AdmitSource] 
			,encr.[AdmitSourceCD] 
			,encr.[AdmitSourceCodeValueSID] 
			,encr.[AdmitMode] 
			,encr.[AdmitModeCD] 
			,encr.[AdmitModeCodeValueSID] 
			,encr.[AdmitWithMedication] 
			,encr.[AdmitWithMedicationCD] 
			,encr.[AdmitWithMedicationCodeValueSID] 
			,encr.[ReferringComment] 
			,encr.[DischargeDisposition] 
			,encr.[DischargeDispositionCD] 
			,encr.[DischargeDispositionCodeValueSID] 
			,encr.[DischargeToLocation] 
			,encr.[DischargeToLocationCD] 
			,encr.[DischargeToLocationCodeValueSID] 
			,encr.[PreadmitNumber] 
			,encr.[PreadmitTesting] 
			,encr.[PreadmitTestingCD] 
			,encr.[PreadmitTestingCodeValueSID] 
			,encr.[Readmit] 
			,encr.[ReadmitCD] 
			,encr.[ReadmitCodeValueSID] 
			,encr.[Accommodation] 
			,encr.[AccommodationCD] 
			,encr.[AccommodationCodeValueSID] 
			,encr.[AccommodationRequest] 
			,encr.[AccommodationRequestCD] 
			,encr.[AccommodationRequestCodeValueSID] 
			,encr.[AltResultDestination] 
			,encr.[AltResultDestinationCD] 
			,encr.[AltResultDestinationCodeValueSID] 
			,encr.[AmbulatoryCondition] 
			,encr.[AmbulatoryConditionCD] 
			,encr.[AmbulatoryConditionCodeValueSID] 
			,encr.[Courtesy] 
			,encr.[CourtesyCD] 
			,encr.[CourtesyCodeValueSID] 
			,encr.[DietType] 
			,encr.[DietTypeCD] 
			,encr.[DietTypeCodeValueSID] 
			,encr.[PatientIsolation] 
			,encr.[PatientIsolationCD] 
			,encr.[PatientIsolationCodeValueSID] 
			,encr.[MedicalService] 
			,encr.[MedicalServiceCD] 
			,encr.[MedicalServiceCodeValueSID] 
			,encr.[ResultDestination] 
			,encr.[ResultDestinationCD] 
			,encr.[ResultDestinationCodeValueSID] 
			,encr.[ConfidentialSecurityLevel] 
			,encr.[ConfidentialSecurityLevelCD] 
			,encr.[ConfidentialSecurityLevelCodeValueSID] 
			,encr.[PatientVIP] 
			,encr.[PatientVIPCD] 
			,encr.[PatientVIPCodeValueSID] 
			,encr.[DataStatus] 
			,encr.[DataStatusCD] 
			,encr.[DataStatusCodeValueSID] 
			,encr.[DataStatusDateTime] 
			,encr.[DataStatusPersonStaffSID] 
			,encr.[ContributorSystem] 
			,encr.[ContributorSystemCD] 
			,encr.[ContributorSystemCodeValueSID] 
			,encr.[Location] 
			,encr.[LocationCD] 
			,encr.[LocationCodeValueSID] 
			,encr.[LocationFacility] 
			,encr.[LocationFacilityCD] 
			,encr.[LocationFacilityCodeValueSID] 
			,encr.[LocationBuilding] 
			,encr.[LocationBuildingCD] 
			,encr.[LocationBuildingCodeValueSID] 
			,encr.[LocationNurseUnit] 
			,encr.[LocationNurseUnitCD] 
			,encr.[LocationNurseUnitCodeValueSID] 
			,encr.[LocationRoom] 
			,encr.[LocationRoomCD] 
			,encr.[LocationRoomCodeValueSID] 
			,encr.[LocationBed] 
			,encr.[LocationBedCD] 
			,encr.[LocationBedCodeValueSID] 
			,encr.[DischargeDateTime] 
			,encr.[GuarantorType] 
			,encr.[GuarantorTypeCD] 
			,encr.[GuarantorTypeCodeValueSID] 
			,encr.[LocationTemporary] 
			,encr.[LocationTemporaryCD] 
			,encr.[LocationTemporaryCodeValueSID] 
			,encr.[OrganizationNameSID] 
			,encr.[VisitReason] 
			,encr.[EncounterFinancialSID] 
			,encr.[FinancialClassification] 
			,encr.[FinancialClassificationCD] 
			,encr.[FinancialClassificationCodeValueSID] 
			,encr.[BloodBankDonorProcedure] 
			,encr.[BloodBankDonorProcedureCD] 
			,encr.[BloodBankDonorProcedureCodeValueSID] 
			,encr.[InformationGivenBy] 
			,encr.[Valuables] 
			,encr.[ValuablesCD] 
			,encr.[ValuablesCodeValueSID] 
			,encr.[ValuablesSafekeeping] 
			,encr.[ValuablesSafekeepingCD] 
			,encr.[ValuablesSafekeepingCodeValueSID] 
			,encr.[Trauma] 
			,encr.[TraumaCD] 
			,encr.[TraumaCodeValueSID] 
			,encr.[Triage] 
			,encr.[TriageCD] 
			,encr.[TriageCodeValueSID] 
			,encr.[TriageDateTime] 
			,encr.[VisitorStatus] 
			,encr.[VisitorStatusCD] 
			,encr.[VisitorStatusCodeValueSID] 
			,encr.[SecurityAccess] 
			,encr.[SecurityAccessCD] 
			,encr.[SecurityAccessCodeValueSID] 
			,encr.[ReferFacility] 
			,encr.[ReferFacilityCD] 
			,encr.[ReferFacilityCodeValueSID] 
			,encr.[TraumaDateTime] 
			,encr.[AccompaniedBy] 
			,encr.[AccompaniedByCD] 
			,encr.[AccompaniedByCodeValueSID] 
			,encr.[AccommodationReason] 
			,encr.[AccommodationReasonCD] 
			,encr.[AccommodationReasonCodeValueSID] 
			,encr.[ChartCompleteDateTime] 
			,encr.[ZeroBalanceDateTime] 
			,encr.[ArchiveEstimateDateTime] 
			,encr.[ArchiveActualDateTime] 
			,encr.[PurgeEstimateDateTime] 
			,encr.[PurgeActualDateTime] 
			,encr.[EncounterCompleteDateTime] 
			,encr.[PurgeArchiveCurrentStatus] 
			,encr.[PurgeArchiveCurrentStatusCD] 
			,encr.[PurgeArchiveCurrentStatusCodeValueSID] 
			,encr.[PurgeArchiveCurrentStatusDateTime] 
			,encr.[ServiceCategory] 
			,encr.[ServiceCategoryCD] 
			,encr.[ServiceCategoryCodeValueSID] 
			,encr.[ContractStatus] 
			,encr.[ContractStatusCD] 
			,encr.[ContractStatusCodeValueSID] 
			,encr.[EstimateLengthOfStay] 
			,encr.[AlternateLevelOfCare] 
			,encr.[AlternateLevelOfCareCD] 
			,encr.[AlternateLevelOfCareCodeValueSID] 
			,encr.[AssignToLocationDateTime] 
			,encr.[ProgramService] 
			,encr.[ProgramServiceCD] 
			,encr.[ProgramServiceCodeValueSID] 
			,encr.[SpecialtyUnit] 
			,encr.[SpecialtyUnitCD] 
			,encr.[SpecialtyUnitCodeValueSID] 
			,encr.[MentalHealthDateTime] 
			,encr.[MentalHealth] 
			,encr.[MentalHealthCD] 
			,encr.[MentalHealthCodeValueSID] 
			,encr.[DocumentReceiptDateTime] 
			,encr.[ReferralReceiptDateTime] 
			,encr.[AlternateLevelOfCareDateTime] 
			,encr.[AltLevelOfCareDecompensationDateTime] 
			,encr.[Region] 
			,encr.[RegionCD] 
			,encr.[RegionCodeValueSID] 
			,encr.[SitterRequired] 
			,encr.[SitterRequiredCD] 
			,encr.[SitterRequiredCodeValueSID] 
			,encr.[AltLevelOfCareReason] 
			,encr.[AltLevelOfCareReasonCD] 
			,encr.[AltLevelOfCareReasonCodeValueSID] 
			,encr.[PlacementAuthorizePersonStaffSID] 
			,encr.[PatientClassification] 
			,encr.[PatientClassificationCD] 
			,encr.[PatientClassificationCodeValueSID] 
			,encr.[MentalHealthCategory] 
			,encr.[MentalHealthCategoryCD] 
			,encr.[MentalHealthCategoryCodeValueSID] 
			,encr.[PsychiatricStatus] 
			,encr.[PsychiatricStatusCD] 
			,encr.[PsychiatricStatusCodeValueSID] 
			,encr.[InpatientAdmitDateTime] 
			,encr.[ResultAccumulationDateTime] 
			,encr.[PregnancyStatus] 
			,encr.[PregnancyStatusCD] 
			,encr.[PregnancyStatusCodeValueSID] 
			,encr.[InitialContactDateTime] 
			,encr.[SymptomOnsetDateTime] 
			,encr.[LastMenstrualPeriodDateTime] 
			,encr.[ExpectedDeliveryDateTime] 
			,encr.[AdvBeneficiaryNoticeStatus] 
			,encr.[AdvBeneficiaryNoticeStatusCD] 
			,encr.[AdvBeneficiaryNoticeStatusCodeValueSID] 
			,encr.[LevelOfService] 
			,encr.[LevelOfServiceCD] 
			,encr.[LevelOfServiceCodeValueSID] 
			,encr.[PlaceOfServiceAdmitDateTime] 
			,encr.[PlaceOfServiceType] 
			,encr.[PlaceOfServiceTypeCD] 
			,encr.[PlaceOfServiceTypeCodeValueSID] 
			,encr.[PlaceOfSvcOrganizationNameSID] 
			,encr.[EstimateFinancialRespAmount] 
			,encr.[ReferralSource] 
			,encr.[ReferralSourceCD] 
			,encr.[ReferralSourceCodeValueSID] 
			,encr.[AdmitDecisionDateTime] 
			,encr.[AccidentRelatedIndicator] 
			,encr.[OrderSource] 
			,encr.[OrderSourceCD] 
			,encr.[OrderSourceCodeValueSID] 
			,encr.[PaymentCollectionStatus] 
			,encr.[PaymentCollectionStatusCD] 
			,encr.[PaymentCollectionStatusCodeValueSID] 
			,encr.[DischargePersonStaffSID] 
			,encr.[AdmitEarlyIndicator] 
			,encr.[TreatmentPhase] 
			,encr.[TreatmentPhaseCD] 
			,encr.[TreatmentPhaseCodeValueSID] 
			,encr.[KioskQueueNumberText] 
			,encr.[KioskQueueNumberDateTime] 
			,encr.[ReferToUnitStaff] 
			,encr.[ReferToUnitStaffCD] 
			,encr.[ReferToUnitStaffCodeValueSID] 
			,encr.[Lodger] 
			,encr.[LodgerCD] 
			,encr.[LodgerCodeValueSID] 
			,encr.[CompleteRegistrationPersonStaffSID] 
			,encr.[Incident] 
			,encr.[IncidentCD] 
			,encr.[IncidentCodeValueSID] 
			,encr.[MilitaryServiceRelated] 
			,encr.[MilitaryServiceRelatedCD] 
			,encr.[MilitaryServiceRelatedCodeValueSID] 
			,encr.[PersonPlanProfileType] 
			,encr.[PersonPlanProfileTypeCD] 
			,encr.[PersonPlanProfileTypeCodeValueSID] 
			,encr.[ClientOrganizationNameSID] 
			,encr.[ClergyVisit] 
			,encr.[ClergyVisitCD] 
			,encr.[ClergyVisitCodeValueSID] 
			,encr.[CompleteRegistrationDateTime] 
			,encr.[EmergencyDeptReferralSource] 
			,encr.[EmergencyDeptReferralSourceCD] 
			,encr.[EmergencyDeptReferralSourceCodeValueSID] 
			,encr.[ExternalIndicator] 
			,cdvl.display 
			/* Q: Why are these no longer showing up?
			,encr.[PersonID] 
			,encr.[ModifiedCount] 
			,encr.[ModifiedDateTime] 
			,encr.[ModifiedPersonStaffID] 
			,encr.[ModifiedPersonStaffSID] 
			,encr.[ModifiedTask] 
			,encr.[ModifiedApplContext] 
			,encr.[ActiveStatusPersonStaffID] 
			,encr.[CreatePersonStaffID] 
			,encr.[PreRegistrationPersonStaffID] 
			,encr.[RegistrationPersonStaffID] 
			,encr.[DataStatusPersonStaffID] 
			,encr.[OrganizationNameID] */
			,orgname.[OrganizationName] 
			,DimVALoc.[STAPA] AS EncounterSTAPA
			,DimVALoc.[STA6A] AS EncounterSTA6A
			/*
			,encr.[EncounterFinancialID] 
			,encr.[PlacementAuthorizePersonStaffID] 
			,encr.[PlaceOfSvcOrganizationNameID] 
			,encr.[LastUTCDateTime] 
			,encr.[DischargePersonStaffID] 
			,encr.[TransactionIDText] 
			,encr.[CompleteRegistrationPersonStaffID] 
			,encr.[ClientOrganizationNameID] 
			,encr.[InstID] 
			,encr.[ETLBatchID] 
			,encr.[ETLCreateDate] 
			,encr.[ETLEditDate] 
			,encr.[OpCode] */
			,GETDATE() AS InsertDate
			,0 AS ExceptionRecordInd	
			,DimVALoc.IOCDate
		INTO #EncMillEncounterStg
		FROM [EncMill].[Encounter] AS encr WITH (NOLOCK)

		INNER JOIN [NDimMill].[CodeValue] AS cdvl WITH (NOLOCK) 
			ON encr.EncounterTypeCodeValueSID = cdvl.CodeValueSID

		LEFT JOIN [NDimMill].[OrganizationName] AS orgname WITH (NOLOCK)
			ON encr.OrganizationNameSID = orgname.OrganizationNameSID 

		LEFT JOIN #StageMillCDSDimVALocation AS DimVALoc WITH (NOLOCK)
			ON encr.OrganizationNameSID = DimVALoc.OrganizationNameSID
		WHERE 1=1
		AND cdvl.Display != 'History' 

		/* Take away questions:
		Do we only want active indicator = 1. What does that mean in the context of the person's encounter.*/

--Select top 100 * from #EncMillEncounterStg where personsid <> 0
/*
checks 

Select distinct EncounterStapa, count(encounterid) from #EncMillEncounterStg group by EncounterStapa
NULL
692 - active
668 - active
757 - active
508 - not active
655 - not active
531 -  active (but delayed so no active data should be used as of 7/23/22)
653 - active
515- not active
648 - not active
459 - not active
663 - not active
463 - not active
506 - not active
687 - active
Select distinct ActiveStatus, ActiveIndicator, count(encounterid) from #EncMillEncounterStg group by activestatus, ActiveIndicator;
ActiveStatus	ActiveIndicator	counts
Deleted	0	279027
Combined	0	1028
Active	0	1
*Unknown at this time*	0	124470
*Implied NULL*	-2	1
*Missing*	-1	1
Inactive	0	5
Active	1	3226023*/


DROP TABLE IF EXISTS #CernerValidationdate;
Select encountersid, encounterid, enc.personsid, sp.NameLast, sp.NameFirst , sp.BirthDateTime,
enc.activeindicator,enc.activestatus, enc.activestatuscd, enc.activestatusdatetime, enc.createdatetime, EncounterType,encountertypeclass, encounterstatus, RegistrationDateTime,
arrivedatetime, departdatetime, dischargedisposition, 
encounterstapa, encountersta6a, iocdate
,case when enc.CreateDateTime < IOCDate then 1 else 0 end as before_cernerlivedate
, case when encounterstapa in ('653', '692' , '757', '687', '668') then 1 else 0 end as cerner_livesite
into #CernerValidationdate
from #EncMillEncounterStg as enc
left join [SVeteranMill].[SPerson] as sp on sp.PersonSID = enc.PersonSID
where enc.ActiveIndicator=1 and encounterstapa is not null and sp.CDWPossibleTestPatientFlag <> 'Y'
/*
Chart Review needed:

Those with null arrivedatetime (what does this mean)
Those with before cerner live dat = 1
Those with create date time a few days difference than arrive date time
*/
Select count(distinct personsid) from #CernerValidationdate 
--150137
Select count(distinct personsid) from #CernerValidationdate where before_cernerlivedate = 1 
--76095
Select top 100* from #CernerValidationdate where before_cernerlivedate = 0 
Select top 100* from #CernerValidationdate where before_cernerlivedate = 1
Select count(distinct personsid) from #CernerValidationdate where before_cernerlivedate = 0 and cerner_livesite =1 
--129478
/* Do we need this? 
	--Drop clustered index 
	IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='CLI_EncMillEncounter' AND object_id = OBJECT_ID('[MillCDS].[EncMillEncounter]'))
	BEGIN 
		DROP INDEX [CLI_EncMillEncounter] ON [MillCDS].[EncMillEncounter];
	END

	--Drop non-clustered index 1 
	IF EXISTS (SELECT 1 FROM sys.indexes WHERE name='NC1_EncMillEncounter' AND object_id = OBJECT_ID('[MillCDS].[EncMillEncounter]'))
	BEGIN 
		DROP INDEX [NC1_EncMillEncounter] ON [MillCDS].[EncMillEncounter];
	END

	EXECUTE [Maintenance].[PublishTable] @PublishTable = 'MillCDS.EncMillEncounter',@SourceTable = '#EncMillEncounterStg';

	--Re-apply clustered index 
	IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='CLI_EncMillEncounter' AND object_id = OBJECT_ID('[MillCDS].[EncMillEncounter]'))
	BEGIN 
		CREATE CLUSTERED INDEX CLI_EncMillEncounter ON [MillCDS].[EncMillEncounter](EncounterSID);
	END

	--Re-apply non-clustered index 1 
	IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name='NC1_EncMillEncounter' AND object_id = OBJECT_ID('[MillCDS].[EncMillEncounter]'))
	BEGIN 
		CREATE NONCLUSTERED INDEX NC1_EncMillEncounter ON [MillCDS].[EncMillEncounter](BeginEffectiveDateTime,EndEffectiveDateTime) 
			INCLUDE (ActiveIndicator);
*/