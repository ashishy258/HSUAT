@isTest
public class HS_SignatureHelper_Test {
    
    @testSetup
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
        newUser.TimeZoneSidKey = 'America/Los_Angeles';
        newUser.FederationIdentifier = 'test68168315136131686851';
        
        Profile sysAdminProfile = [SELECT Id, Name FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        newUser.ProfileId = sysAdminProfile.Id;
        
        insert newUser;
        
                    FSL__Scheduling_Policy__c schedulingPolicy = new FSL__Scheduling_Policy__c(Name='Customer First',FSL__Daily_Optimization__c=true,FSL__Fix_Overlaps__c=false,FSL__Travel_Mode__c=false);
            insert schedulingPolicy;
            
        //Using System.runAs to avoid MIXED_DML error.
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'FSL_Resource_Permissions'];
            insert new PermissionSetAssignment(AssigneeId = newUser.id, PermissionSetId = ps.Id);
            
            OperatingHours testOpp = new OperatingHours();
            testOpp.Name = 'Test Operating Hours';
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
            //newSR.Organization__c = newOrg.Id;
            newSR.RelatedRecordId = newUser.Id;
            //newSR.Relocation_Travel_Radius__c = '0';
            insert newSR;
            
            
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
            
            //Create Parent Work Order for SA
            WorkOrder wo = new WorkOrder();
            wo.Status = 'InProgress';
            wo.Wrap_Up__c=true;
            wo.Total_Due__c = 200;
            insert wo;
            
            ServiceResource sr = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
            
            //Create Service Appointment
            ServiceAppointment sa = new ServiceAppointment();
            sa.ServiceTerritoryId = territory.Id;
            sa.Duration = 2;
            sa.Planned_Scheduled_Start__c=DateTime.now().addDays(1);
            sa.Planned_Scheduled_End__c=DateTime.now().addDays(1).addHours(3);
            sa.SchedStartTime = DateTime.now().addDays(1);
            sa.SchedEndTime = DateTime.now().addDays(1).addHours(3);
            sa.Status = SFS_ABConstantUtil.SA_TRAVEL;
            sa.Work_Order__c = wo.Id;
            sa.ParentRecordId = wo.Id;
            sa.Subject='OnsiteSA';
            insert sa;
            //Create Assigned Resource
            AssignedResource ar = new AssignedResource();
            ar.ServiceAppointmentId = sa.Id;
            ar.ServiceResourceId = newSR.Id;
            insert ar;
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_TRAVEL, SFS_ABConstantUtil.SA_ONSITE);
            sa.Status=SFS_ABConstantUtil.SA_ONSITE;
            update sa;
            
        }
    }
    @isTest
    static void testCoverageSignatureScreen() {
        Test.StartTest();
        WorkOrder wo=[select id,Wrap_Up__c,Status from WorkOrder limit 1];
		HS_SignatureHelper hshelper=new HS_SignatureHelper();
        WorkOrder returnWO=HS_SignatureHelper.isSignatureScreenVisible(wo.Id,1);
        Test.StopTest();   
        System.assertEquals(wo, returnWO);
    }
    @isTest
    static void testCoverageWithCustomerDeclined() {
        Test.StartTest();
        String strElement=SFS_ABConstantUtil.captureSignaturestrElement;
        WorkOrder wo=[select id,Wrap_Up__c,Status from WorkOrder limit 1];
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_ONSITE, SFS_ABConstantUtil.SA_COMPLETED);
        HS_SignatureHelper.saveSign(wo.Id,strElement,true);
        Test.StopTest();   
        WorkOrder updatedWO=[select id,Customer_Declined_to_Sign__c,Status from WorkOrder limit 1];
		System.assertEquals(true, updatedWO.Customer_Declined_to_Sign__c);
    }
    @isTest
    static void testCoverageWithSignature() {
        Test.StartTest();
        String strElement=SFS_ABConstantUtil.captureSignaturestrElement;
        WorkOrder wo=[select id,Wrap_Up__c,Status from WorkOrder limit 1];
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_ONSITE, SFS_ABConstantUtil.SA_COMPLETED);
        HS_SignatureHelper.saveSign(wo.Id,strElement,false);
        Test.StopTest();   
		Id conDocument = [SELECT ContentDocumentId FROM ContentVersion limit 1].ContentDocumentId;
		ContentDocumentLink cdlink=[select Id,LinkedEntityId from ContentDocumentLink where ContentDocumentId=:conDocument limit 1];
		//System.assertEquals(cdlink.LinkedEntityId, wo.ID);
    }
    @isTest
    static void testCoverageCostInformation() {
        Test.StartTest();
        WorkOrder wo = [SELECT Id FROM WorkOrder LIMIT 1];
		WorkOrder workOrderRec = HS_SignatureHelper.costInformation(wo.Id, 1);
        Test.StopTest();   
        System.assertEquals(200, workOrderRec.Total_Due__c, 'The value of Total Due returned from HS_SignatureHelper should be 200');
    }
}