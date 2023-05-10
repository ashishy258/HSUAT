/**
* @description       :
* @author            : Vandana Verma
* @group             :
* @last modified on  : 02-20-2023
* @last modified by  : Vandana Verma
* Modifications Log
* Ver   Date         Author          Modification
* 1.0   02-20-2023   Vandana Verma   Initial Version
* 2.0   02-20-2023   Vandana Verma   updated version CTSM-162
**/
@isTest
public class SFS_ABAssignedResourceHandlerTest {

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
  FSL__Scheduling_Policy__c schedulingPolicy = new FSL__Scheduling_Policy__c(Name='Customer First',FSL__Daily_Optimization__c=true,FSL__Fix_Overlaps__c=false,FSL__Travel_Mode__c=false);
            insert schedulingPolicy;
        //Using System.runAs to avoid MIXED_DML error.
        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(thisUser) {
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'FSL_Resource_Permissions'];
            insert new PermissionSetAssignment(AssigneeId = newUser.id, PermissionSetId = ps.Id);
            
            insert new PermissionSetAssignment(AssigneeId = newUser1.id, PermissionSetId = ps.Id);
            
            
            
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
            
            ServiceResource newSR1 = new ServiceResource();
            newSR1.IsActive = true;
            newSR1.Name = 'Test Resource1';
            newSR1.ResourceType = 'T';
            //newSR.Organization__c = newOrg.Id;
            newSR1.RelatedRecordId = newUser1.Id;
            //newSR.Relocation_Travel_Radius__c = '0';
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
            
            
            
            //Create Parent Work Order for SA
            WorkOrder wo = new WorkOrder();
            wo.Status = 'Open';
            //wo.EdgeID__c = '2352125';
            insert wo;
            
            ServiceResource sr = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource' LIMIT 1];
            
            //Create Service Appointment
            ServiceAppointment sa = new ServiceAppointment();
            sa.SchedStartTime = DateTime.now().addDays(1);
            sa.SchedEndTime = DateTime.now().addDays(1).addHours(3);
            sa.ServiceTerritoryId = territory.Id;
            sa.Duration = 2;
            sa.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa.ParentRecordId = wo.Id;
            sa.Subject='ToBeConfirmed';
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, 'Confirmed');
            insert sa;

            //Create Assigned Resource
            AssignedResource ar = new AssignedResource();
            ar.ServiceAppointmentId = sa.Id;
            ar.ServiceResourceId = newSR.Id;
            insert ar;
        }
    }
    
    @isTest
    static void checkSAStatusTest() {
        try{         
            Test.StartTest();
            ServiceAppointment appointment = [SELECT Id FROM ServiceAppointment WHERE Subject = 'ToBeConfirmed'];
            appointment.Status = 'Confirmed';
            update appointment;
            ServiceResource sr = [SELECT Id, Name FROM ServiceResource WHERE Name = 'Test Resource1' LIMIT 1];
            
            AssignedResource assignedResource = [SELECT ServiceResourceId FROM AssignedResource WHERE ServiceAppointmentId = :appointment.Id];
            assignedResource.ServiceResourceId = sr.Id;
            
            update assignedResource;
            Test.StopTest();        
        }catch (Exception e){

            System.Assert(e.getMessage().contains('FIELD_CUSTOM_VALIDATION_EXCEPTION'));
        }
    }
}