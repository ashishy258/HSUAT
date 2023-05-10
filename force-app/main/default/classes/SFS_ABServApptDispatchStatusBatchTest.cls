/**
 * @description       : Cover the code coverage of SFS_ABServApptDispatchStatusBatch apex class
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 03-15-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   03-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class SFS_ABServApptDispatchStatusBatchTest {

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

        System.runAs(serviceUser1) {

            //Creating Operating Hours Record
            OperatingHours estOperatingHour = new OperatingHours();
            estOperatingHour.Name = 'Eastern Standard Time';
            estOperatingHour.TimeZone = 'America/New_York';
            insert estOperatingHour;

            //Creating Service Resource
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);
            serviceResource1.Dispatch_Policy__c = 'Drip Feed';
            update serviceResource1;

            //Creating Service Territory
            ServiceTerritory serviceTerritory1 = new ServiceTerritory();
            serviceTerritory1.Name = 'Brooklyn';
            serviceTerritory1.OperatingHoursId = estOperatingHour.Id;
            serviceTerritory1.IsActive = true;
            insert serviceTerritory1;

            //Creating Service Territory Member
            ServiceTerritoryMember member1 = new ServiceTerritoryMember();
            member1.ServiceTerritoryId = serviceTerritory1.Id;
            member1.ServiceResourceId = serviceResource1.Id;
            member1.EffectiveStartDate = Date.today();
            insert member1;

            //Create Parent Work Order for SA
            WorkOrder wo = new WorkOrder();
            wo.Status = 'Open';
            insert wo;
            
            //Create Service Appointment
            ServiceAppointment sa = new ServiceAppointment();
            sa.SchedStartTime = Datetime.now().addHours(1);
            sa.SchedEndTime = Datetime.now().addHours(2);
            sa.ServiceTerritoryId = serviceTerritory1.Id;
            sa.Assigned_Resource__c = serviceResource1.Id;
            sa.Subject = 'Scheduled within next 2 hours';
            sa.Duration = 1;
            sa.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa.ParentRecordId = wo.Id;
            insert sa;

            ServiceAppointment sa1 = new ServiceAppointment();
            sa1.SchedStartTime = Datetime.now().addHours(3);
            sa1.SchedEndTime = Datetime.now().addHours(4);
            sa1.ServiceTerritoryId = serviceTerritory1.Id;
            sa1.Assigned_Resource__c = serviceResource1.Id;
            sa1.Subject = 'Scheduled beyond next 2 hours';
            sa1.Duration = 1;
            sa1.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            sa1.ParentRecordId = wo.Id;
            insert sa1;

            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_SCHEDULED, SFS_ABConstantUtil.SA_PRE_DISPATCHED);

            //Create Assigned Resources
            AssignedResource ar = new AssignedResource();
            ar.ServiceAppointmentId = sa.Id;
            ar.ServiceResourceId = serviceResource1.Id;
            insert ar;

            AssignedResource ar1 = new AssignedResource();
            ar1.ServiceAppointmentId = sa1.Id;
            ar1.ServiceResourceId = serviceResource1.Id;
            insert ar1;
        }
    }

    @IsTest
    public static void testServApptDispatchStatusBatch(){
        ServiceAppointment scheduledSA = [SELECT Id, Status FROM ServiceAppointment ORDER BY SchedStartTime ASC LIMIT 1];
        Test.startTest();
        System.assertEquals(SFS_ABConstantUtil.SA_SCHEDULED, scheduledSA.Status, 'The Service Appointment should have status as Scheduled.');
        Database.executeBatch(new SFS_ABServApptDispatchStatusBatch(), 200);
        Test.stopTest();
        List<ServiceAppointment> updatedSA = [SELECT Id, Status FROM ServiceAppointment ORDER BY SchedStartTime ASC];
        System.assertEquals(SFS_ABConstantUtil.SA_PRE_DISPATCHED, updatedSA[0].Status, 'The Service Appointment should have updated status as Pre-Dispatched.');
        System.assertEquals(SFS_ABConstantUtil.SA_SCHEDULED, updatedSA[1].Status, 'The Service Appointment status should remain as Pre-Dispatched because its scheduled beyond 2 hours from now.');
    }
}