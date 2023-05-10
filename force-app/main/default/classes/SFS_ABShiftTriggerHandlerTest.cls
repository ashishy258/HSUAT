/**
 * @description       : Cover the code coverage of SFS_ABShiftTriggerHandler apex class
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 02-15-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   02-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class SFS_ABShiftTriggerHandlerTest {

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

            //Creating Service Territory Member

            ServiceTerritoryMember member1 = new ServiceTerritoryMember();
            member1.ServiceTerritoryId = serviceTerritory1.Id;
            member1.ServiceResourceId = serviceResource1.Id;
            member1.EffectiveStartDate = Date.today();
            insert member1;

            ServiceTerritoryMember member2 = new ServiceTerritoryMember();
            member2.ServiceTerritoryId = serviceTerritory1.Id;
            member2.ServiceResourceId = serviceResource2.Id;
            member2.EffectiveStartDate = Date.today();
            insert member2;

            
            
            //Creating Daily based Consumed Capacity template Records
            String todaysDayOfTheWeek = SFS_ABNewDayBatchDailyConsumedCapacity.getDayOfWeek(System.today());
            List<Capacity_Rule_Template__c> dailyCapacityTemplates = new List<Capacity_Rule_Template__c>();
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Daily Capacity', SFS_ABConstantUtil.Slot8To12, null));
            insert dailyCapacityTemplates;

            //Creating Rule based Consumed Capacity template Records
            List<Capacity_Rule_Template__c> ruleCapacityTemplates = new List<Capacity_Rule_Template__c>();
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Rule Based Capacity', SFS_ABConstantUtil.Slot8To12, dailyCapacityTemplates[0].Id));
            insert ruleCapacityTemplates;

            //Creating Consumed Capacity Records
            Consumed_Capacity__c dailyCapacity = SFS_ABTestFactory.createConsumedCapacity(dailyCapacityTemplates[0], serviceTerritory1.Id, 'Daily Capacity', System.today(), null);
            insert dailyCapacity;
            Consumed_Capacity__c ruleBasedCapacity = SFS_ABTestFactory.createConsumedCapacity(ruleCapacityTemplates[0], serviceTerritory1.Id, 'Rule Based Capacity', System.today(), dailyCapacity);
            insert ruleBasedCapacity;
            
            //service app
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
        sa1.Subject='Open SA';
        sa1.Status=SFS_ABConstantUtil.SA_OPEN;
 Time startTime = Time.newInstance(8, 0, 0, 0);
        Time endTime = Time.newInstance(12, 0, 0, 0);

        sa1.ArrivalWindowStartTime =DateTime.newInstance(system.today(), startTime);
        sa1.ArrivalWindowEndTime =  DateTime.newInstance(system.today(), endTime);
        sa1.ServiceTerritoryId=serviceTerritory1.Id;
            insert sa1;
            //Create Service Appointments.
ServiceAppointment sa3 = new ServiceAppointment();
sa3.ParentRecordId = wo.Id;
sa3.EarliestStartTime = DateTime.now();
sa3.DueDate = DateTime.now().addDays(1);
sa3.Duration = 2.00;
sa3.Subject='Open SA3';
sa3.Status=SFS_ABConstantUtil.SA_OPEN;
Time startTime12 = Time.newInstance(12, 0, 0, 0);
Time endTime16 = Time.newInstance(16, 0, 0, 0);

sa3.ArrivalWindowStartTime =DateTime.newInstance(system.today(), startTime12);
sa3.ArrivalWindowEndTime =  DateTime.newInstance(system.today(), endTime16);
sa3.ServiceTerritoryId=serviceTerritory1.Id;
    insert sa3;
            //Create Service Appointments.
ServiceAppointment sa4 = new ServiceAppointment();
sa4.ParentRecordId = wo.Id;
sa4.EarliestStartTime = DateTime.now();
sa4.DueDate = DateTime.now().addDays(1);
sa4.Duration = 2.00;
sa4.Subject='Open sa4';
sa4.Status=SFS_ABConstantUtil.SA_OPEN;
Time startTime16 = Time.newInstance(16, 0, 0, 0);
Time startTime2030 = Time.newInstance(20, 30, 0, 0);

sa4.ArrivalWindowStartTime =DateTime.newInstance(system.today(), startTime16);
sa4.ArrivalWindowEndTime =  DateTime.newInstance(system.today(), startTime2030);
sa4.ServiceTerritoryId=serviceTerritory1.Id;
    insert sa4;

//Create Service Appointments.
      ServiceAppointment sa2 = new ServiceAppointment();
sa2.ParentRecordId = wo.Id;
sa2.EarliestStartTime = DateTime.now();
sa2.DueDate = DateTime.now().addDays(1);
sa2.Duration = 2.00;
sa2.Subject='Open SA2';
sa2.Status=SFS_ABConstantUtil.SA_OPEN;
 Time startTime2 = Time.newInstance(8, 0, 0, 0);
        Time endTime2 = Time.newInstance(12, 0, 0, 0);

        sa1.ArrivalWindowStartTime =DateTime.newInstance(system.today(), startTime2);
        sa1.ArrivalWindowEndTime =  DateTime.newInstance(system.today(), endTime2);
sa2.ServiceTerritoryId=serviceTerritory1.Id;
    insert sa2;
                  FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
 sa2.Status=SFS_ABConstantUtil.SA_SCHEDULED;
             Time startTime1 = Time.newInstance(9, 0, 0, 0);
        Time endTime1 = Time.newInstance(10, 0, 0, 0);
        sa2.SchedStartTime = DateTime.newInstance(system.today(), startTime1);
        sa2.SchedEndTime =DateTime.newInstance(system.today(), endTime1);
        update sa2;

        }
    }

    @IsTest
    public static void testNewSingleShiftInsert(){

        ServiceResource serviceResourceRecord = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' LIMIT 1];

        Shift shiftRecord = createShift(serviceResourceRecord.Id);
        shiftRecord.Status = 'Confirmed';

        Test.startTest();
        insert shiftRecord;
        Resource_Capacity__c newResourceCapacity = [SELECT Id, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: serviceResourceRecord.Id LIMIT 1];
        System.assertEquals(720, newResourceCapacity.Availability_Before_Consumption__c, 'The capacity should be 720 minutes before consumption as shift is for 12 hours and resource efficiency is 1.');
        Test.stopTest();
    }

    @IsTest
    public static void testSingleShiftUpdate(){

        List<ServiceResource> serviceResourceRecordsList = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' OR Name = 'Test ServiceResource2' ORDER BY Name ASC LIMIT 2];
        ServiceResource serviceResource1Record = serviceResourceRecordsList[0];
        ServiceResource serviceResource2Record = serviceResourceRecordsList[1];

        Shift shiftRecord = createShift(serviceResource1Record.Id);
        shiftRecord.Status = 'Tentative';

        Test.startTest();
        insert shiftRecord;
        List<Resource_Capacity__c> newResourceCapacity = [SELECT Id, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: serviceResource1Record.Id];
        System.assertEquals(0, newResourceCapacity.size(), 'The size of list should be zero as the Shift created is not confirmed.');
        shiftRecord.ServiceResourceId = serviceResource2Record.Id;
        shiftRecord.Status = 'Confirmed';
        update shiftRecord;
        Resource_Capacity__c updatedResourceCapacity = [SELECT Id, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: serviceResource2Record.Id LIMIT 1];
        System.assertEquals(720, updatedResourceCapacity.Availability_Before_Consumption__c, 'The capacity should be 720 minutes before consumption as shift is for 12 hours and resource efficiency is 1.');
        Test.stopTest();
    }

    @IsTest
    public static void testSingleShiftDelete(){

        ServiceResource serviceResourceRecord = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' LIMIT 1];

        Shift shiftRecord = createShift(serviceResourceRecord.Id);
        shiftRecord.Status = 'Confirmed';

        Test.startTest();
        insert shiftRecord;
        Resource_Capacity__c newResourceCapacity = [SELECT Id, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: serviceResourceRecord.Id LIMIT 1];
        System.assertEquals(720, newResourceCapacity.Availability_Before_Consumption__c, 'The capacity should be 720 minutes before consumption as shift is for 12 hours and resource efficiency is 1.');

        delete shiftRecord;
        Resource_Capacity__c updatedResourceCapacity = [SELECT Id, Availability_Before_Consumption__c FROM Resource_Capacity__c WHERE Service_Resource__c =: serviceResourceRecord.Id LIMIT 1];
        System.assertEquals(0, updatedResourceCapacity.Availability_Before_Consumption__c, 'The capacity ahould get updated to 0 as shift is deleted.');
        Test.stopTest();
    }

    @IsTest
    public static void testNewMultipleShiftInsert(){

        List<ServiceResource> serviceResourceRecordsList = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' OR Name = 'Test ServiceResource2' ORDER BY Name ASC LIMIT 2];
        ServiceResource serviceResource1Record = serviceResourceRecordsList[0];
        ServiceResource serviceResource2Record = serviceResourceRecordsList[1];

        Shift shiftRecord1 = createShift(serviceResource1Record.Id);
        shiftRecord1.Status = 'Confirmed';
        Shift shiftRecord2 = createShift(serviceResource2Record.Id);
        shiftRecord2.Status = 'Confirmed';

        List<Shift> shiftInsertList = new List<Shift>{shiftRecord1, shiftRecord2};

        Test.startTest();
        insert shiftInsertList;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecords = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c IN : serviceResourceRecordsList AND Type__c = 'Shift Insert'];
        System.assertEquals(2, capacityRebuildJobRecords.size(), 'The size of capacityRebuildJob list should be 2 as we are inserting 2 shifts at a time.');
        Test.stopTest();  
    }

    @IsTest
    public static void testNewMultipleShiftUpdate(){

        List<ServiceResource> serviceResourceRecordsList = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' OR Name = 'Test ServiceResource2' ORDER BY Name ASC LIMIT 2];
        ServiceResource serviceResource1Record = serviceResourceRecordsList[0];
        ServiceResource serviceResource2Record = serviceResourceRecordsList[1];

        Shift shiftRecord1 = createShift(serviceResource1Record.Id);
        shiftRecord1.Status = 'Tentative';
        Shift shiftRecord2 = createShift(serviceResource2Record.Id);
        shiftRecord2.Status = 'Tentative';

        List<Shift> shiftInsertList = new List<Shift>{shiftRecord1, shiftRecord2};

        Test.startTest();
        insert shiftInsertList;

        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecordsInsert = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c IN : serviceResourceRecordsList AND Type__c = 'Shift Insert'];
        System.assertEquals(0, capacityRebuildJobRecordsInsert.size(), 'The size of capacityRebuildJob list should be 0 as we are inserting 2 non confirmed shifts at a time.');

        Shift updatedShiftRecord1 = shiftInsertList[0];
        updatedShiftRecord1.Status = 'Confirmed';
        Shift updatedShiftRecord2 = shiftInsertList[1];
        updatedShiftRecord2.Status = 'Confirmed';

        List<Shift> shiftUpdateList = new List<Shift>{updatedShiftRecord1, updatedShiftRecord2};
        update shiftUpdateList;

        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecordsUpdate = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c IN : serviceResourceRecordsList AND Type__c = 'Shift Update'];
        System.assertEquals(2, capacityRebuildJobRecordsUpdate.size(), 'The size of capacityRebuildJob list should be 2 as we are updating 2 confirmed shifts at a time.');
        Test.stopTest();
    }

    @IsTest
    public static void testSingleShiftUpdateWithMultipleSTM(){

        List<ServiceResource> serviceResourceRecordsList = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' OR Name = 'Test ServiceResource2' ORDER BY Name ASC LIMIT 2];
        ServiceResource serviceResource1Record = serviceResourceRecordsList[0];
        ServiceResource serviceResource2Record = serviceResourceRecordsList[1];

        OperatingHours estOperatingHour = [SELECT Id FROM OperatingHours WHERE Name = 'Eastern Standard Time'];
        //Creating Service Territory Queens
        ServiceTerritory serviceTerritory2 = new ServiceTerritory();
        serviceTerritory2.Name = 'Queens';
        serviceTerritory2.OperatingHoursId = estOperatingHour.Id;
        serviceTerritory2.IsActive = true;
        insert serviceTerritory2;

        //Creating Service Territory Member
        ServiceTerritoryMember member2 = [SELECT Id, EffectiveStartDate, EffectiveEndDate FROM ServiceTerritoryMember WHERE ServiceResourceId =: serviceResource2Record.Id LIMIT 1];
        member2.EffectiveEndDate = Date.today().addDays(5);
        update member2;
        
        ServiceTerritoryMember member3 = new ServiceTerritoryMember();
        member3.ServiceTerritoryId = serviceTerritory2.Id;
        member3.ServiceResourceId = serviceResource2Record.Id;
        member3.EffectiveStartDate = Date.today().addDays(6);
        insert member3;

        Shift shiftRecord = createShift(serviceResource1Record.Id);
        shiftRecord.Status = 'Tentative';

        Test.startTest();
        insert shiftRecord;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecordsInsert = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c IN : serviceResourceRecordsList AND Type__c = 'Shift Insert'];
        System.assertEquals(0, capacityRebuildJobRecordsInsert.size(), 'The size of capacityRebuildJob list should be 0 as we are inserting a non confirmed shifts at a time.');
        shiftRecord.ServiceResourceId = serviceResource2Record.Id;
        shiftRecord.Status = 'Confirmed';
        update shiftRecord;
        List<Capacity_Rebuild_Job__c> capacityRebuildJobRecordsUpdate = [SELECT Id, Type__c FROM Capacity_Rebuild_Job__c WHERE Service_Resource__c IN : serviceResourceRecordsList AND Type__c = 'Shift Update'];
        System.assertEquals(1, capacityRebuildJobRecordsUpdate.size(), 'The size of capacityRebuildJob list should be 1 as the updated shift have more than one STMs.');
        Test.stopTest();
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
}