/**
* @description       :
* @author            :  Vandana/Ashish
* @group             :
* @last modified on  : 26-04-2023
* @last modified by  :  Vandana/Ashish
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   26-04-2023   Vandana/Ashish   Initial Version
**/
@isTest
public class SFS_ABSTMTriggerHandlerTest {
    
    @TestSetup
    static void setup(){
        Profile servicesProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User serviceUser1 = new User();
        serviceUser1.FirstName = 'Test';
        serviceUser1.LastName = 'ServiceResource1';
        serviceUser1.ProfileId = servicesProfile.Id;
        serviceUser1.username = 'test_service_user1@test.com';
        serviceUser1.email = 'TestServiceUser@invalid.com';
        serviceUser1.Alias = '2222202';
        serviceUser1.TimeZoneSidKey = 'America/New_York';
        serviceUser1.LocaleSidKey = 'en_US';
        serviceUser1.EmailEncodingKey = 'UTF-8';
        serviceUser1.LanguageLocaleKey = 'en_US';
        serviceUser1.IsActive = true;
        serviceUser1.FederationIdentifier = 'test6816815136131686851';
        insert serviceUser1;
        
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'];
        insert new PermissionSetAssignment(AssigneeId = serviceUser1.id, PermissionSetId = ps.Id);
        
        User serviceUser2 = SFS_ABTestFactory.createAServiceUser2('test_service_user2@test.com');
        serviceUser2.TimeZoneSidKey = 'America/New_York';
        update serviceUser2;
        
        insert new PermissionSetAssignment(AssigneeId = serviceUser2.id, PermissionSetId = ps.Id);
        
        System.runAs(serviceUser1) {
            
            //Creating Operating Hours Record
            OperatingHours estOperatingHour = new OperatingHours();
            estOperatingHour.Name = 'Eastern Standard Time';
            estOperatingHour.TimeZone = 'America/New_York';
            insert estOperatingHour;
            
            //Creating Service Resource
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);
            ServiceResource serviceResource2 = SFS_ABTestFactory.createServiceResource(serviceUser2);
            serviceResource2.Name = 'Test ServiceResource2';
            update serviceResource2;
            
            //Creating Service Territory
            ServiceTerritory serviceTerritory1 = new ServiceTerritory();
            serviceTerritory1.Name = 'Brooklyn';
            serviceTerritory1.OperatingHoursId = estOperatingHour.Id;
            serviceTerritory1.IsActive = true;
            insert serviceTerritory1;
            //Creating Service Territory
            ServiceTerritory serviceTerritory2 = new ServiceTerritory();
            serviceTerritory2.Name = 'Queens';
            serviceTerritory2.OperatingHoursId = estOperatingHour.Id;
            serviceTerritory2.IsActive = true;
            insert serviceTerritory2;
            
            //Creating Service Territory
            ServiceTerritory serviceTerritory3 = new ServiceTerritory();
            serviceTerritory3.Name = 'SJ';
            serviceTerritory3.OperatingHoursId = estOperatingHour.Id;
            serviceTerritory3.IsActive = true;
            insert serviceTerritory3;
            //Creating Service Territory Member
            
            
        }
    }
    
    @IsTest
    public static void testSTMInsertUpdate(){
        
        ServiceTerritory serviceTerritory1 = [SELECT Id, OperatingHoursId FROM ServiceTerritory where name='Brooklyn' LIMIT 1];
        
        ServiceTerritory serviceTerritory2 = [SELECT Id, OperatingHoursId FROM ServiceTerritory where name='Queens' LIMIT 1];
        
        ServiceResource serviceResource1 = [SELECT Id FROM ServiceResource where name!='Test ServiceResource1' LIMIT 1];
        
        ServiceResource serviceResource2 = [SELECT Id FROM ServiceResource where name='Test ServiceResource1' LIMIT 1];
        
        Resource_Capacity__c resCapacityRecord = new Resource_Capacity__c();
        resCapacityRecord.Service_Resource__c = serviceResource2.Id;
        resCapacityRecord.Capacity_Date__c = System.today().addDays(1);
        resCapacityRecord.Service_Territory__c = serviceTerritory2.Id;
        resCapacityRecord.External_Id__c = serviceResource2.Id + '_' + serviceTerritory2.Id + '_' + system.today().format();
        insert resCapacityRecord;
        
        Test.startTest();
        
        //Creating Service Territory Member
        ServiceTerritoryMember territoryMember = new ServiceTerritoryMember();
        territoryMember.ServiceResourceId = serviceResource1.Id;
        territoryMember.ServiceTerritoryId = serviceTerritory1.Id;
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
        ServiceterritoryMember territoryMember1 = new ServiceterritoryMember();
        territoryMember1.ServiceResourceId = serviceResource2.Id;
        territoryMember1.ServiceTerritoryId = serviceTerritory2.Id;
        territoryMember1.TerritoryType = 'P';
        territoryMember1.EffectiveStartDate = DateTime.now();
        territoryMember1.EffectiveEndDate = DateTime.now().addYears(1);
        territoryMember1.Street = '2014 Meadowbrook Rd';
        territoryMember1.City = 'Charlottesville';
        territoryMember1.State = 'Virginia';
        territoryMember1.Country = 'USA';
        territoryMember1.PostalCode = '12345';
        insert territoryMember1;  
        
        territoryMember1.EffectiveStartDate=DateTime.now().addDays(1);
        territoryMember1.EffectiveEndDate=DateTime.now().addDays(9);
        update territoryMember1;
        delete territoryMember;
        Test.stopTest();
    }
    
    
    @IsTest
    public static void testRelocation(){
        test.startTest();
        ServiceTerritory serviceTerritory1 = [SELECT Id, OperatingHoursId FROM ServiceTerritory where name='Brooklyn' LIMIT 1];
        ServiceTerritory serviceTerritoryR = [SELECT Id, OperatingHoursId FROM ServiceTerritory where name='SJ' LIMIT 1];
        ServiceResource serviceResource1 = [SELECT Id FROM ServiceResource where name!='Test ServiceResource1' LIMIT 1];
        //Creating Service Territory Member
        ServiceTerritoryMember territoryMember = new ServiceTerritoryMember();
        territoryMember.ServiceResourceId = serviceResource1.Id;
        territoryMember.ServiceTerritoryId = serviceTerritory1.Id;
        territoryMember.TerritoryType = 'P';
        territoryMember.EffectiveStartDate = DateTime.now();
        territoryMember.EffectiveEndDate = DateTime.now().addYears(1);
        territoryMember.Street = '2014 Meadowbrook Rd';
        territoryMember.City = 'Charlottesville';
        territoryMember.State = 'Virginia';
        territoryMember.Country = 'USA';
        territoryMember.PostalCode = '12345';
        insert territoryMember;    
        
        WorkOrder wrkorder = SFS_ABTestFactory.createWorkOrder();
        System.assertNotEquals(wrkorder, null);
        
        //Create Service Appointments.
        ServiceAppointment sa1 = new ServiceAppointment();
        sa1.ParentRecordId = wrkorder.Id;
        sa1.EarliestStartTime = DateTime.now();
        sa1.DueDate = DateTime.now().addDays(4);
        sa1.Duration = 2.00;
        sa1.Subject='Relocation';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
        sa1.ArrivalWindowStartTime = DateTime.now().addDays(1);
        sa1.FSL__InJeopardy__c=true;
        sa1.ArrivalWindowEndTime = DateTime.now().addDays(1).addHours(2);
        sa1.ServiceTerritoryId=serviceTerritory1.Id;
        
        FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
        insert sa1;
        
        sa1.Status=SFS_ABConstantUtil.SA_SCHEDULED;
        sa1.SchedStartTime = DateTime.now().addDays(1);
        sa1.SchedEndTime = DateTime.now().addDays(1).addHours(2);
        update sa1;
        
        //Create Assigned Resource
        AssignedResource ar = new AssignedResource();
        ar.ServiceAppointmentId = sa1.Id;
        ar.ServiceResourceId = serviceResource1.Id;
        insert ar;
        
        //Creating Service Territory Member
        ServiceTerritoryMember territoryMemberR = new ServiceTerritoryMember();
        territoryMemberR.ServiceResourceId = serviceResource1.Id;
        territoryMemberR.ServiceTerritoryId = serviceTerritoryR.Id;
        territoryMemberR.TerritoryType = 'R';
        territoryMemberR.EffectiveStartDate = DateTime.now().addDays(1);
        territoryMemberR.EffectiveEndDate = DateTime.now().addDays(2);
        territoryMemberR.Street = '2014 Meadowbrook Rd';
        territoryMemberR.City = 'Charlottesville';
        territoryMemberR.State = 'Virginia';
        territoryMemberR.Country = 'USA';
        territoryMemberR.PostalCode = '1234578';
        insert territoryMemberR;   
        
        Test.stopTest();		
        
    }
    
}