/**
* Created by ayushmathur on 20/03/23.
*/

@IsTest
private class SFS_ABServiceAppointmentJeopardyTest {
    @TestSetup
    static void testSetup() {
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
        
        PermissionSetGroup psg=[select id from PermissionSetGroup where developername='Field_Service_Administrator' limit 1];
PermissionSetAssignment assignment = new PermissionSetAssignment(
    PermissionSetGroupId = psg.Id,
    AssigneeId = newUser.Id);

insert assignment;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Resources'][0];
        insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps.Id);
        
        PermissionSet ps1 = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'][0];
        insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps1.Id);
        
        PermissionSet ps2 = new PermissionSet();
        ps2.Name = 'Test';
        ps2.Label = 'Test';
        insert ps2;
        
        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = ps2.Id;
        sea.SetupEntityId = [select Id from CustomPermission where DeveloperName = 'Allow_Edit_On_Service_Territory'][0].Id;
        insert sea;
        
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.AssigneeId = newUser.Id;
        psa.PermissionSetId = ps2.Id;
        insert psa;
        
        System.runAs(newUser) {

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
            newSR.RelatedRecordId = newUser.Id;
            insert newSR;
            
            //Creating Service Territory Member
            ServiceTerritoryMember territoryMember = new ServiceTerritoryMember();
            territoryMember.ServiceResourceId = newSR.Id;
            territoryMember.ServiceTerritoryId = territory.Id;
            territoryMember.TerritoryType = 'P';
            territoryMember.EffectiveStartDate = Datetime.now().addDays(-10);
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
            insert wo;
            List<ServiceAppointment> serviceAppointments = new List<ServiceAppointment>();
            //Create Service Appointment
            ServiceAppointment openSA = new ServiceAppointment();
            openSA.ArrivalWindowStartTime = Datetime.now().addMinutes(50);
            openSA.ArrivalWindowEndTime = Datetime.now().addDays(1);
            openSA.ServiceTerritoryId = territory.Id;
            openSA.Duration = 2;
            openSA.Status = SFS_ABConstantUtil.SA_OPEN;
            openSA.ParentRecordId = wo.Id;
            openSA.Subject='Open SA';
            insert openSA;
            
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_ONSITE);
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, SFS_ABConstantUtil.SA_ONSITE);
            List<AssignedResource> assignedResources = new List<AssignedResource>();
            ServiceAppointment onSiteSA = openSA;
            onSiteSA.FSL__InJeopardy__c =false;
            onSiteSA.Id=null;
            onSiteSA.ArrivalWindowStartTime=Datetime.now();
            onSiteSA.SchedStartTime = Datetime.now().addMinutes(-137);
            onSiteSA.SchedEndTime = Datetime.now().addMinutes(-17);
            onSiteSA.Status=SFS_ABConstantUtil.SA_ONSITE;
            insert onSiteSA;
            
            AssignedResource ar_onSiteSA = new AssignedResource();
            ar_onSiteSA.ServiceAppointmentId = onSiteSA.Id;
            ar_onSiteSA.ServiceResourceId = newSR.Id;
            assignedResources.add(ar_onSiteSA);
            
            ServiceAppointment vecSA = openSA;
            vecSA.FSL__InJeopardy__c =false;
            vecSA.Id=null;
            vecSA.ArrivalWindowStartTime=Datetime.now();
            vecSA.SchedStartTime = Datetime.now().addMinutes(-16);
            vecSA.SchedEndTime = Datetime.now().addMinutes(104);
            vecSA.Status=SFS_ABConstantUtil.SA_DISPATCHED;
            vecSA.VEC__c=true;
            insert vecSA;
            
            AssignedResource ar_vecSA = new AssignedResource();
            ar_vecSA.ServiceAppointmentId = vecSA.Id;
            ar_vecSA.ServiceResourceId = newSR.Id;
            assignedResources.add(ar_vecSA);
            
            
            ServiceAppointment dispatchedSA = vecSA;
            dispatchedSA.FSL__InJeopardy__c =false;
            dispatchedSA.Id=null;
            dispatchedSA.VEC__c=false;
            vecSA.SchedStartTime = Datetime.now().addMinutes(-16);
            insert dispatchedSA;
            
            AssignedResource ar_dispatchedSA = new AssignedResource();
            ar_dispatchedSA.ServiceAppointmentId = dispatchedSA.Id;
            ar_dispatchedSA.ServiceResourceId = newSR.Id;
            assignedResources.add(ar_dispatchedSA);
            
            ServiceAppointment travelSA = dispatchedSA;
            travelSA.FSL__InJeopardy__c=false;
            travelSA.Id=null;
            travelSA.SchedStartTime = Datetime.now().addMinutes(50);
            insert travelSA;
            
            AssignedResource ar_travelSA = new AssignedResource();
            ar_travelSA.ServiceAppointmentId = travelSA.Id;
            ar_travelSA.ServiceResourceId = newSR.Id;
            ar_travelSA.EstimatedTravelTime=10;
            assignedResources.add(ar_travelSA);
            insert assignedResources;
        }
    }
    @IsTest
    static void testSFS_ABServiceAppointmentJeopardy (){
        User newUser=[select Id from User where Username='johnsmithfortesting@smith.com'];
        System.runAs(newUser) {
        Test.startTest();
        SFS_ABServiceAppointmentJeopardyBatch obj = new SFS_ABServiceAppointmentJeopardyBatch();
        Database.executeBatch(obj);
        Test.stopTest();
        
        List<ServiceAppointment> jeopardySAs = [SELECT Id,Subject FROM ServiceAppointment WHERE FSL__InJeopardy__c=TRUE AND FSL__InJeopardyReason__c!=NULL];
        System.assertEquals(4,jeopardySAs.size());
 }
    }
}