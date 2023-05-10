/**
* @description       :
* @author            : Ashish Yadav
* @group             :
* @last modified on  : 14-04-2023
* @last modified by  : Ashish Yadav
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   14-04-2023   Ashish Yadav   Initial Version
**/
@IsTest
public class SFS_ABResourceAbsenceTriggerHandlerTest {
    @TestSetup
    static void setup() {
        //Create Organization (Account)
        Account newOrg = new Account();
        newOrg.Name = 'Test Org';
        //newOrg.Type = 'Organization';
        insert newOrg;
        
        //Create User
        User newUser = new User();
        newUser.FirstName = 'John';
        newUser.LastName = 'Smith';
        newUser.Email = 'testJohnSmith@test.com';
        newUser.Alias = 'js23456';
        newUser.Username = 'johnsmithfortesting@smith.com';
        newUser.IsActive = true;
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LastName = 'Testing';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.LocaleSidKey = 'en_US';
        newUser.TimeZoneSidKey = 'America/New_York';
        newUser.FederationIdentifier = 'test68168315136131686851';
        
        Profile sysAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        newUser.ProfileId = sysAdminProfile.Id;
        
        insert newUser;
        
        //Using System.runAs to avoid MIXED_DML error.
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'FSL_Resource_Permissions'];
            insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps.Id);
            
            PermissionSet ps1 = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'];
            insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps1.Id);
            
            OperatingHours testOpp = new OperatingHours();
            testOpp.Name = 'Test Operating Hours';
            testOpp.TimeZone = 'America/New_York';
            insert testOpp;
            
            ServiceTerritory territory = new ServiceTerritory();
            territory.Name = 'Test Territory';
            territory.OperatingHoursId = testOpp.Id;
            territory.IsActive = true;
            insert territory;
            
            ServiceResource newSR = new ServiceResource();
            newSR.IsActive = true;
            newSR.Name = 'Test Resource';
            newSR.ResourceType = 'T';
            //newSR.Organization__c = newOrg.Id;
            newSR.RelatedRecordId = newUser.Id;
            //newSR.Relocation_Travel_Radius__c = '0';
            insert newSR;
            
            //Creating Service Territory Member
            ServiceTerritoryMember territoryMember = new ServiceTerritoryMember();
            territoryMember.ServiceResourceId = newSR.Id;
            territoryMember.ServiceTerritoryId = territory.Id;
            territoryMember.TerritoryType = 'P';
            territoryMember.EffectiveStartDate = Datetime.now();
            territoryMember.EffectiveEndDate = Datetime.now().addYears(1);
            territoryMember.Street = '2014 Meadowbrook Rd';
            territoryMember.City = 'Charlottesville';
            territoryMember.State = 'Virginia';
            territoryMember.Country = 'USA';
            territoryMember.PostalCode = '12345';
            insert territoryMember;
            
            //Create Parent Work Order for SA
            WorkOrder wo = new WorkOrder();
            wo.Status = 'Open';
            //wo.EdgeID__c = '2352125';
            insert wo;
            
            ServiceResource sr = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
            
             

            
            //Create Service Appointment
            ServiceAppointment sa = new ServiceAppointment();
            sa.ArrivalWindowStartTime = Datetime.now().addDays(1);
            sa.ArrivalWindowEndTime = Datetime.now().addDays(1).addHours(3);
            sa.SchedStartTime = Datetime.now().addDays(1);
            sa.SchedEndTime = Datetime.now().addDays(1).addHours(3);
            
            sa.ServiceTerritoryId = territory.Id;
            sa.Duration = 2;
            sa.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa.ParentRecordId = wo.Id;
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, 'Open');
            insert sa;
            
            //Create Assigned Resource
            AssignedResource ar = new AssignedResource();
            ar.ServiceAppointmentId = sa.Id;
            ar.ServiceResourceId = newSR.Id;
            insert ar;
            
            //Creating Daily based Consumed Capacity template Records
            String todaysDayOfTheWeek = SFS_ABNewDayBatchDailyConsumedCapacity.getDayOfWeek(System.today());
            List<Capacity_Rule_Template__c> dailyCapacityTemplates = new List<Capacity_Rule_Template__c>();
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(territory.Id, todaysDayOfTheWeek, 'Daily Capacity', SFS_ABConstantUtil.Slot8To12, null));
            insert dailyCapacityTemplates;

            //Creating Rule based Consumed Capacity template Records
            List<Capacity_Rule_Template__c> ruleCapacityTemplates = new List<Capacity_Rule_Template__c>();
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(territory.Id, todaysDayOfTheWeek, 'Rule Based Capacity', SFS_ABConstantUtil.Slot8To12, dailyCapacityTemplates[0].Id));
            insert ruleCapacityTemplates;
            
            Consumed_Capacity__c dailyCapacity = SFS_ABTestFactory.createConsumedCapacity(dailyCapacityTemplates[0], territory.Id, 'Daily Capacity', System.today(), null);
            insert dailyCapacity;
            Consumed_Capacity__c ruleBasedCapacity = SFS_ABTestFactory.createConsumedCapacity(ruleCapacityTemplates[0], territory.Id, 'Rule Based Capacity', System.today(), dailyCapacity);
            insert ruleBasedCapacity;
        }
    }
    
    @IsTest
    static void testUnscheduleJobsOnResourceAbsenceInsert() {
        //Query Service Resource
        ServiceResource resource = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource'];
        
        //Create Resource Absence
        ResourceAbsence ra = new ResourceAbsence();
        //ra.Start = DateTime.now().addDays(1).addHours(1);
        ra.Start = Datetime.now().addDays(1);
        //ra.End = DateTime.now().addDays(1).addHours(2);
        ra.End = Datetime.now().addDays(1).addHours(4);
        ra.ResourceId = resource.Id;
        ra.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        
        Test.startTest();
        insert ra;
        ServiceAppointment updatedSA = [SELECT Id, Status FROM ServiceAppointment LIMIT 1];
        Test.stopTest();
        System.assertEquals('Open', updatedSA.Status, 'The status of SA should get updated to Open.');
        
        
    }
    
    @IsTest
    static void testUnscheduleJobsOnResourceAbsenceUpdate() {
        //Query Service Resource
        ServiceResource resource = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource'];
        //Create Resource Absence
        ResourceAbsence ra = new ResourceAbsence();
        ra.Start = Datetime.now().addDays(5);
        ra.End = Datetime.now().addDays(6);
        ra.ResourceId = resource.Id;
        ra.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        insert ra;
        ServiceAppointment nonUpdatedSA = [SELECT Id, Status FROM ServiceAppointment LIMIT 1];
        System.assertEquals('Scheduled', nonUpdatedSA.Status, 'The status of SA should remain Scheduled.');
        ra.Start = Datetime.now().addDays(1);
        ra.End = Datetime.now().addDays(2);
        
        Test.startTest();
        update ra;
        ServiceAppointment updatedSA = [SELECT Id, Status FROM ServiceAppointment LIMIT 1];
        Test.stopTest();
        System.assertEquals('Open', updatedSA.Status, 'The status of SA should get updated to Open.');
    }
    
    @IsTest
    static void testPinnedSAOnResourceAbsenceUpdate() {
        //Query Service Resource
        ServiceResource resource = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource'];
        //pinned a SA
        ServiceAppointment pinnedSA = [SELECT Id, Status FROM ServiceAppointment LIMIT 1];
        pinnedSA.FSL__Pinned__c = true;
        update pinnedSA;
        
        //Create Resource Absence
        ResourceAbsence ra = new ResourceAbsence();
        ra.Start = Datetime.now().addDays(1);
        ra.End = Datetime.now().addDays(2);
        ra.ResourceId = resource.Id;
        ra.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        
        Test.startTest();
        insert ra;
        ServiceAppointment nonUpdatedSA = [SELECT Id, Status FROM ServiceAppointment LIMIT 1];
        Test.stopTest();
        System.assertEquals('Scheduled', nonUpdatedSA.Status, 'The status of SA should remain Scheduled.');
    }
    
    @isTest
    static void callCapacityRecalcMethod() {
        //Query Service Resource
        ServiceResource resource = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource'];
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForResourceAbsenceInsert = new List<Capacity_Rebuild_Job__c>();
        //Create Resource Absence
        ResourceAbsence ra = new ResourceAbsence();
        ra.Start = DateTime.now().addDays(4);
        ra.End = DateTime.now().addDays(6);
        ra.ResourceId = resource.Id;
        ra.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        insert ra;
        
        delete ra;
    }
    
    public static Shift createShift(String resourceId){
        Time startShiftTime = Time.newInstance(8, 0, 0, 0);
        Time endShiftTime = Time.newInstance(20, 0, 0, 0);
        DateTime startShiftDate = DateTime.newInstance(system.today(), startShiftTime);
        DateTime endShiftDate = DateTime.newInstance(system.today(), endShiftTime);
        Shift shiftRecord = new Shift();
        shiftRecord.StartTime = startShiftDate;
        shiftRecord.endTime = endShiftDate;
        shiftRecord.ServiceResourceId = resourceId;
        shiftRecord.TimeSlotType = 'Normal';
        
        return shiftRecord;
    }
    // Shift creation, RA creation --> Capacity calculations
    @isTest
    static void resourceCapacityCalculationOnMultipleRA(){
        Time startabsenceTime1 = Time.newInstance(10, 0, 0, 0);
        Time endabsenceTime1 = Time.newInstance(11, 0, 0, 0);
        DateTime startabsenceDate1 = DateTime.newInstance(system.today(), startabsenceTime1);
        DateTime endabsenceDate1 = DateTime.newInstance(system.today(), endabsenceTime1); 
        Time startabsenceTime2 = Time.newInstance(17, 0, 0, 0);
        Time endabsenceTime2 = Time.newInstance(18, 30, 0, 0);
        DateTime startabsenceDate2 = DateTime.newInstance(system.today(), startabsenceTime2);
        DateTime endabsenceDate2 = DateTime.newInstance(system.today(), endabsenceTime2);
        
        List<ResourceAbsence> resourceAbsenceInsertList = new List<ResourceAbsence>();    
        List<ResourceAbsence> resourceAbsenceUpdateList = new List<ResourceAbsence>();         
        ServiceResource sr = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
        Shift srShift =createShift(sr.id);
        srShift.Status= 'Confirmed';
        test.startTest();
        insert srShift;
        Resource_Capacity__c newResourceCapacity = [SELECT Id, Total_Absence_Duration__c, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: sr.Id LIMIT 1];
        System.assertEquals(720, newResourceCapacity.Availability_Before_Consumption__c, 'The capacity should be 720 minutes before consumption as shift is for 12 hours and resource efficiency is 1.');
        
        ResourceAbsence ra1 = new ResourceAbsence();
        ra1.Start = startabsenceDate1;
        ra1.End = endabsenceDate1;
        ra1.ResourceId = sr.Id;
        ra1.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        resourceAbsenceInsertList.add(ra1); 
        ResourceAbsence ra2 = new ResourceAbsence();
        ra2.Start = startabsenceDate2;
        ra2.End = endabsenceDate2;
        ra2.ResourceId = sr.Id;
        ra2.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        resourceAbsenceInsertList.add(ra2);
        insert resourceAbsenceInsertList;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecords = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c  =: sr.Id AND Type__c = 'Absence Insert'];
        System.assertEquals(2, capacityRebuildJobRecords.size(), 'The size of capacityRebuildJob list should be 2 as we are inserting 2 RA at a time.');
        
        ra1.Start=startabsenceDate1.addMinutes(10);
        ra1.End=endabsenceDate1.addMinutes(10);
        ra2.Start=startabsenceDate2.addMinutes(25);
        ra2.End=endabsenceDate2.addMinutes(25);
        resourceAbsenceUpdateList.add(ra1);
        resourceAbsenceUpdateList.add(ra2);
        update resourceAbsenceUpdateList;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobUpdateRecords = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c  =: sr.Id AND Type__c = 'Absence Update'];
        System.assertEquals(2, capacityRebuildJobUpdateRecords.size(), 'The size of capacityRebuildJob list should be 2 as we are updating 2 RA at a time.');
        delete resourceAbsenceUpdateList;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobDeleteRecords = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c  =: sr.Id AND Type__c = 'Absence Delete'];
        System.assertEquals(2, capacityRebuildJobDeleteRecords.size(), 'The size of capacityRebuildJob list should be 2 as we are deleting 2 RA at a time.');   
        
        ResourceAbsence ra3 = new ResourceAbsence();
        ra3.Start = startabsenceDate1;
        ra3.End = endabsenceDate1;
        ra3.ResourceId = sr.Id;
        ra3.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
        ra3.Type = 'Sick';
        insert ra3;
        Resource_Capacity__c updatedResourceCapacity = [SELECT Id, Total_Absence_Duration__c, Total_PTO_Duration__c, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: sr.Id LIMIT 1];
        System.assertEquals(60, updatedResourceCapacity.Total_Absence_Duration__c, 'Total absence of the resource capacity should be 60 mins.');
        System.assertEquals(60, updatedResourceCapacity.Total_PTO_Duration__c, 'Total PTO duration should be 60 mins as the NA is of type Sick.');
        Test.stopTest();      
    }
}