/**
* @description       :
* @author            : Divya Dalmia
* @group             :
* @last modified on  : 15-03-2023
* @last modified by  : Divya Dalmia
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   15-03-2023   Vandana Verma                 Initial Version
* 2.0   24-04-2023   Divya Dalmia                  Modified Version
**/
@isTest
public class SFS_ABServApptTriggerHandlerTest {
    
    @testSetup
    static void setup() {
        //Create Organization (Account)
        Account newOrg = new Account();
        newOrg.Name = 'Test Org';
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
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.FederationIdentifier = 'test68168315136131686851';
        
        Profile sysAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        newUser.ProfileId = sysAdminProfile.Id;
        
        insert newUser;
        
        //Create User
        User newUser1 = new User();
        newUser1.FirstName = 'John1';
        newUser1.LastName = 'Smith1';
        newUser1.Email = 'testJohn1Smith1@test.com';
        newUser1.Alias = 'js234561';
        newUser1.Username = 'johnsmithfortesting1@smith.com';
        newUser1.IsActive = true;
        newUser1.EmailEncodingKey = 'UTF-8';
        newUser1.LastName = 'Testing1';
        newUser1.LanguageLocaleKey = 'en_US';
        newUser1.LocaleSidKey = 'en_US';
        newUser1.TimeZoneSidKey = 'America/Los_Angeles';
        newUser1.FederationIdentifier = 'test68168315136116868511';
        newUser1.ProfileId = sysAdminProfile.Id;
        
        insert newUser1;
        
        //Using System.runAs to avoid MIXED_DML error.
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'FSL_Resource_Permissions'];
            insert new PermissionSetAssignment(AssigneeId = newUser.id, PermissionSetId = ps.Id);
            
            insert new PermissionSetAssignment(AssigneeId = newUser1.id, PermissionSetId = ps.Id);
            
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
            newSr.IsActive = true;
            newSr.Name = 'Test Resource';
            newSR.ResourceType = 'T';
            newSR.RelatedRecordId = newUser.Id;
            insert newSR;
            
            ServiceResource newSR1 = new ServiceResource();
            newSR1.IsActive = true;
            newSR1.Name = 'Test Resource1';
            newSR1.ResourceType = 'T';
            newSR1.RelatedRecordId = newUser1.Id;
            insert newSR1;
            
            //Creating Service Territory Member
            ServiceTerritoryMember territoryMember = new ServiceTerritoryMember();
            territoryMember.ServiceResourceId = newSR.Id;
            territoryMember.ServiceTerritoryId = territory.Id;
            territoryMember.TerritoryType = 'P';
            territoryMember.EffectiveStartDate = DateTime.now();
            territoryMember.EffectiveEndDate = DateTime.now().addYears(1);
            territoryMember.Street = '2014 Meadowbrook Rd';
            territoryMember.City = 'Charlottesville';
            territoryMember.State = 'Virginia';
            territoryMember.Country = 'USA';
            territoryMember.PostalCode = '12345';
            insert territoryMember;
            
            //Creating Service Territory Member
            ServiceTerritoryMember territoryMember1 = new ServiceTerritoryMember();
            territoryMember1.ServiceResourceId = newSR1.Id;
            territoryMember1.ServiceTerritoryId = territory.Id;
            territoryMember1.TerritoryType = 'P';
            territoryMember1.EffectiveStartDate = DateTime.now();
            territoryMember1.EffectiveEndDate = DateTime.now().addYears(1);
            territoryMember1.Street = '2014 Meadowbrook Rd';
            territoryMember1.City = 'Charlottesville';
            territoryMember1.State = 'Virginia';
            territoryMember1.Country = 'USA';
            territoryMember1.PostalCode = '12345';
            insert territoryMember1;
            
            FSL__Scheduling_Policy__c schedulingPolicy = new FSL__Scheduling_Policy__c(Name='Customer First',FSL__Daily_Optimization__c=true,FSL__Fix_Overlaps__c=false,FSL__Travel_Mode__c=false);
            insert schedulingPolicy;
            
            //Create WorkType
            WorkType wt = new WorkType();
            wt.Name = 'E FFS WorkType';
            wt.Work_Type_Category__c = 'Emergency FFS';
            wt.EstimatedDuration = 60.00;
            wt.DurationType = 'Minutes';
            wt.Gantt_Icon__c = 'RedCircle';
            insert wt;
            
            //Create WorkType2
            WorkType wt2 = new WorkType();
            wt2.Name = 'R FFS WorkType';
            wt2.Work_Type_Category__c = 'Repair FFS';
            wt2.EstimatedDuration = 60.00;
            wt2.DurationType = 'Minutes';
            wt2.Gantt_Icon__c = 'BlackCircle';
            insert wt2;
        }
    }
    
    @isTest
    static void testInsert() {
        //Create Parent Work Order for SA
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        
        //Create Service Appointments.
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='BeforeInsert';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        test.startTest();
        insert sa1;
        ServiceAppointment sainserted = [SELECT Id, Work_Order__c FROM ServiceAppointment WHERE Subject = 'BeforeInsert' LIMIT 1];
        System.assertEquals(sainserted.Work_Order__c, sa1.ParentRecordId);
        Test.stopTest();
    }
    
    @isTest
    static void testBeforeUpdate() {
        //Create Parent Work Order for SA
        try
        {
            WorkOrder wo = new WorkOrder();
            wo.Status = 'Open';
            insert wo;
            
            //Create Service Appointments.
            ServiceAppointment sa1 = new ServiceAppointment();
            sa1.ParentRecordId = wo.Id;
            sa1.EarliestStartTime = DateTime.now();
            sa1.DueDate = DateTime.now().addDays(1);
            sa1.Duration = 2.00;
            sa1.Subject='BeforeUpdate';
            sa1.SchedStartTime = DateTime.now().addDays(1);
            sa1.SchedEndTime = DateTime.now().addDays(2);
            sa1.Status= SFS_ABConstantUtil.SA_CONFIRMED;
            insert sa1;
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_CONFIRMED, SFS_ABConstantUtil.SA_OPEN);
            test.startTest();
            ServiceAppointment sainserted = [SELECT Id,Status FROM ServiceAppointment WHERE Subject = 'BeforeUpdate' LIMIT 1];
            sainserted.Status=SFS_ABConstantUtil.SA_OPEN;
            update sainserted;
            Test.stopTest();
        }
        catch(Exception e)
        {
            Boolean expectedExceptionThrown =  e.getMessage().contains('Cannot change status from') ? true : false;
            System.AssertEquals(expectedExceptionThrown, true);
        }   
    }
    @isTest
    static void testAfterStatusUpdate() {
        //Create Parent Work Order for SA
        
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        //Create Service Appointments.
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='AfterStatusUpdate';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = DateTime.now();
        sa1.ArrivalWindowEndTime = DateTime.now().addHours(2);
        sa1.ServiceTerritoryId=st.Id;
        test.startTest();
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
        insert sa1;
        ServiceResource newSR = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
        
        ServiceAppointment appointment = [SELECT Id,Status FROM ServiceAppointment WHERE Subject = 'AfterStatusUpdate' LIMIT 1];
        appointment.Status=SFS_ABConstantUtil.SA_SCHEDULED;
        appointment.SchedStartTime = DateTime.now();
        appointment.SchedEndTime = DateTime.now().addHours(1);
        update appointment;
        
        //Create Assigned Resource
        AssignedResource ar = new AssignedResource();
        ar.ServiceAppointmentId = sa1.Id;
        ar.ServiceResourceId = newSR.Id;
        insert ar;
        Test.stopTest();
        
    }
    @isTest
    static void testAfterGeneralUpdate() {
        //Create Parent Work Order for SA
        
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        //Create Service Appointments.
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='AfterGeneralUpdate';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ServiceTerritoryId=st.Id;
        test.startTest();
        insert sa1;
        ServiceAppointment appointment = [SELECT Id,Status FROM ServiceAppointment WHERE Subject = 'AfterGeneralUpdate' LIMIT 1];
        appointment.ArrivalWindowStartTime = DateTime.now();
        appointment.ArrivalWindowEndTime = DateTime.now().addHours(2);
        update appointment;
        Test.stopTest();
        
    }
    @isTest
    static void testInvokeSAStatusChangePE() {
        //Create Parent Work Order for SA
        
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        //Create Service Appointments.
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='AfterStatusUpdate';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = DateTime.now();
        sa1.FSL__InJeopardy__c=true;
        sa1.ArrivalWindowEndTime = DateTime.now().addHours(2);
        sa1.ServiceTerritoryId=st.Id;
        test.startTest();
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
        insert sa1;
        
        ServiceResource newSR = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
        
        sa1.Status=SFS_ABConstantUtil.SA_SCHEDULED;
        sa1.SchedStartTime = DateTime.now();
        sa1.SchedEndTime = DateTime.now().addHours(1);
        update sa1;
        //Create Assigned Resource
        AssignedResource ar = new AssignedResource();
        ar.ServiceAppointmentId = sa1.Id;
        ar.ServiceResourceId = newSR.Id;
        insert ar;
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, SFS_ABConstantUtil.SA_PRE_DISPATCHED);
        sa1.Status=SFS_ABConstantUtil.SA_PRE_DISPATCHED;
        update sa1;

        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_PRE_DISPATCHED, SFS_ABConstantUtil.SA_OPEN);
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        update sa1;
        Test.stopTest();
    }
    @IsTest
    static void testUpdateWorkOrderFields(){
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = Datetime.now();
        sa1.DueDate = Datetime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='AfterStatusUpdate';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = Datetime.now();
        sa1.ArrivalWindowEndTime = Datetime.now().addHours(2);
        sa1.ServiceTerritoryId=st.Id;
        Test.startTest();
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
        insert sa1;
        ServiceResource newSR = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
        
        sa1.Status=SFS_ABConstantUtil.SA_SCHEDULED;
        sa1.SchedStartTime = Datetime.now();
        sa1.SchedEndTime = Datetime.now().addHours(1);
        update sa1;
        //Create Assigned Resource
        AssignedResource ar = new AssignedResource();
        ar.ServiceAppointmentId = sa1.Id;
        ar.ServiceResourceId = newSR.Id;
        insert ar;
        
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, SFS_ABConstantUtil.SA_ONSITE);
        sa1.Status=SFS_ABConstantUtil.SA_ONSITE;
        update sa1;
        System.assertEquals(sa1.ActualStartTime, wo.StartDate,'Should be same');
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_ONSITE, SFS_ABConstantUtil.SA_COMPLETED);
        sa1.Status=SFS_ABConstantUtil.SA_COMPLETED;
        update sa1;
        System.assertEquals(sa1.ActualEndTime, wo.EndDate,'Should be same');
        Test.stopTest();
        
    }
    
    //    Uncomment this for RSO
    @IsTest
    static void testInvokeRSO(){
        
        
        List<ServiceAppointment> serviceAppointments = new List<ServiceAppointment>();
        List<ServiceAppointment> updateSAs = new List<ServiceAppointment>();
        List<AssignedResource> assignedResources = new List<AssignedResource>();
        List<ServiceAppointment> completedAppointments = new List<ServiceAppointment>() ;
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        insert wo;
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = Datetime.now();
        sa1.DueDate = Datetime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject='AfterStatusUpdate';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = Datetime.now();
        sa1.ArrivalWindowEndTime = Datetime.now().addHours(2);
        sa1.ServiceTerritoryId=st.Id;
        
        
        insert sa1;
        
        ServiceAppointment sa2 = new ServiceAppointment();
        sa2.ParentRecordId = wo.Id;
        sa2.EarliestStartTime = Datetime.now();
        sa2.DueDate = Datetime.now().addDays(1);
        sa2.Duration = 2.00;
        sa2.Subject='AfterStatusUpdate for Sa2';
        sa2.Status=SFS_ABConstantUtil.SA_OPEN;
        sa2.ArrivalWindowStartTime = Datetime.now();
        sa2.ArrivalWindowEndTime = Datetime.now().addHours(2);
        sa2.ServiceTerritoryId=st.Id;
        
        insert sa2;
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            Test.startTest();
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
            
            ServiceResource newSR = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
            
            sa1.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa1.SchedStartTime = Datetime.now();
            sa1.SchedEndTime = sa1.SchedStartTime.addHours(2);
            update sa1;
            sa2.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa2.SchedStartTime = sa2.ArrivalWindowStartTime;
            sa2.SchedEndTime = sa2.SchedStartTime.addHours(2);
            update sa2;
            
            AssignedResource ar1 = new AssignedResource();
            ar1.ServiceAppointmentId = sa1.Id;
            ar1.ServiceResourceId = newSR.Id;
            insert ar1;
            AssignedResource ar2 = new AssignedResource();
            ar2.ServiceAppointmentId = sa2.Id;
            ar2.ServiceResourceId = newSR.Id;
            insert ar2;
            
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, SFS_ABConstantUtil.SA_CONFIRMED);
            sa1.Status = SFS_ABConstantUtil.SA_CONFIRMED;
            update sa1;
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_CONFIRMED, SFS_ABConstantUtil.SA_ONSITE);
            sa1.Status = SFS_ABConstantUtil.SA_ONSITE;
            update sa1;
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_ONSITE, SFS_ABConstantUtil.SA_COMPLETED);
            sa1.Status = SFS_ABConstantUtil.SA_COMPLETED;
            update sa1;
            
            Test.stopTest();
            
        }
    }
    
    @isTest
    static void testCatchMethod() {
        Test.startTest();
        SFS_ABServiceAppointmentTriggerHandler.handleSAAfterUpdate(null);
        SFS_ABServiceAppointmentTriggerHandler.handleSABeforeInsert(null);
        SFS_ABServiceAppointmentTriggerHandler.handleSABeforeUpdate(null);
        Test.stopTest();
    }
    
    @isTest
    static void testSAGanttIcon() {
        
        Test.startTest();
        
        //Get WorkType
        WorkType wtEmergency = [SELECT Id, Name, Work_Type_Category__c, Gantt_Icon__c  FROM WorkType WHERE Name = 'E FFS WorkType' LIMIT 1];
        WorkType wtRepair = [SELECT Id, Name, Work_Type_Category__c, Gantt_Icon__c  FROM WorkType WHERE Name = 'R FFS WorkType' LIMIT 1];
        
        //Get Service Territory
        ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
        
        //Create Parent Work Order for SA
        WorkOrder wo = new WorkOrder();
        wo.Status = 'Open';
        wo.WorkTypeId = wtEmergency.Id;
        insert wo;
        
        //Create Service Appointment
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wo.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(1);
        sa1.Duration = 2.00;
        sa1.Subject = 'SA Gantt Icon Testing';
        sa1.Status = SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = DateTime.now();
        sa1.ArrivalWindowEndTime = DateTime.now().addHours(2);
        sa1.ServiceTerritoryId = st.Id;
        insert sa1;
        
        wo.WorkTypeId = wtRepair.Id;
        update wo;
        update sa1;
        
        Test.stopTest();
    }
    
    @istest
    private static void testCustomPermission()
    {
        try
        {
        //Create User
        User newUser = new User();
        newUser.FirstName = 'test';
        newUser.LastName = 'customper';
        newUser.Email = 'testcustomper@test.com';
        newUser.Alias = 'js2t';
        newUser.Username = 'testcustomper@smith.com';
        newUser.IsActive = true;
        newUser.EmailEncodingKey = 'UTF-8';
        newUser.LastName = 'test';
        newUser.LanguageLocaleKey = 'en_US';
        newUser.LocaleSidKey = 'en_US';
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.FederationIdentifier = 'cust68168315136131686851';
        
        Profile sysAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        newUser.ProfileId = sysAdminProfile.Id;
        
        insert newUser;
        system.runAs(newUser) {
            Test.startTest();
            //Get Service Territory
            ServiceTerritory st = [SELECT Id FROM ServiceTerritory WHERE Name = 'Test Territory' LIMIT 1];
            //Create Parent Work Order for SA
            WorkOrder wo = new WorkOrder();
            wo.Status = 'Open';
            insert wo;
            
            //Create Service Appointment
            ServiceAppointment sa1 = new ServiceAppointment();
            sa1.ParentRecordId = wo.Id;
            sa1.EarliestStartTime = DateTime.now();
            sa1.DueDate = DateTime.now().addDays(1);
            sa1.Duration = 2.00;
            sa1.Subject = 'SA Gantt Icon Testing';
            sa1.Status = SFS_ABConstantUtil.SA_OPEN;
            sa1.ArrivalWindowStartTime = DateTime.now();
            sa1.ArrivalWindowEndTime = DateTime.now().addHours(2);
            sa1.ServiceTerritoryId = st.Id;
            insert sa1;
            Test.stopTest();
        }
        }
        catch (Exception e) {
          
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('You do not have  appropriate permission to create Service Appointments')) ? true : false;
            System.assertEquals(true, expectedExceptionThrown, e.getMessage());
        }
    }
    
    @isTest static void testConvertDateTimeToTerritorysTZ() {
        User userRec = HSTestFactory.UserCreate();
        system.runAs(userRec) {
            
            Test.startTest();
            
            OperatingHours opHours = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');
            SFS_ABServiceAppointmentTriggerHandler.convertDateTimeToTerritorysTZ(opHours.TimeZone, DateTime.now());
            
            Test.stopTest();
        }
    }
}