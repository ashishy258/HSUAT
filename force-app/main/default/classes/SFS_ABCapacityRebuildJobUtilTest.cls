@isTest
public class SFS_ABCapacityRebuildJobUtilTest {
    //private static String subContractorName1 = SFS_ABConstantUtil.SUB_CONTRACTOR_ONE;
    // private static String organizationName1 = SFS_ABConstantUtil.ORGANIZATION_ONE;
    private static String serviceTerritoryName = SFS_ABConstantUtil.SERVICE_TERRITORY_ONE;
    //private static String serviceRegionName = SFS_ABConstantUtil.SERVICE_REGION;

    @TestSetup
    static void setUpData() {
        User serviceUserList = SFS_ABTestFactory.createAServiceUser();

        //User serviceUserList2 = SFS_ABTestFactory.createAServiceUser();
			PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'FSL_Resource_Permissions'];
            insert new PermissionSetAssignment(AssigneeId = serviceUserList.Id, PermissionSetId = ps.Id);
            
            PermissionSet ps1 = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'];
            insert new PermissionSetAssignment(AssigneeId = serviceUserList.Id, PermissionSetId = ps1.Id);
        System.runAs(serviceUserList) {
    		            
            // Account subContractor1 =
            //     SFS_ABTestFactory.createSubContractorAccount(subContractorName1);
            // insert subContractor1;
            // Account organization1 =
            //     SFS_ABTestFactory.createOrganizationAccount(organizationName1);
            // insert organization1;
            //  Account organization2 = SFS_ABTestFactory.createOrganizationAccount('Org 2');
            // insert organization2;
            // Account subCo2 = SFS_ABTestFactory.createSubContractorAccount('SubCo 2');
            // insert subCo2;

            //ServiceTerritory exceptionTerritory = SFS_ABTestFactory.createServiceTerritory(SFS_ABConstantUtil.SERVICE_TERRITORY_ONE, SFS_ABConstantUtil.EXPECTION_AREA);
            //insert exceptionTerritory;
            //
            OperatingHours oHourRecord = new OperatingHours();
            oHourRecord.Name = 'Central Standard Time 8am-4pm';
            oHourRecord.TimeZone = 'America/New_York';
            insert oHourRecord;

            // ServiceTerritory exceptionTerritory = new ServiceTerritory();
            // exceptionTerritory.name = SFS_ABConstantUtil.SERVICE_TERRITORY_ONE;
            // exceptionTerritory.OperatingHoursId = oHourRecord.Id;
            // exceptionTerritory.TerritoryType__c = SFS_ABConstantUtil.EXPECTION_AREA;
            // exceptionTerritory.IsActive = true;
            // insert exceptionTerritory;

            ServiceTerritory serviceTerritory = SFS_ABTestFactory.createServiceTerritory(SFS_ABConstantUtil.SERVICE_TERRITORY_TWO);
            //insert serviceTerritory;
            //serviceTerritory.EnableAutoAbsence__c = true;
            //serviceTerritory.MinutesUntilUnacknowledged__c = 30;
            update serviceTerritory;

            //Creating service user to create Group
            System.assertNotEquals(serviceUserList, null);
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUserList);

            //Creating service user to create Group
            //System.assertNotEquals(serviceUserList2, NULL);
            //ServiceResource serviceResource2 = SFS_ABTestFactory.createServiceResource(serviceUserList2, organization1, subContractor1);

            // ZipCode__c exceptionZip = new ZipCode__c();
            // exceptionZip.Name = SFS_ABConstantUtil.EXCEPTION_ZIP;
            // exceptionZip.ServiceTerritory__c = exceptionTerritory.Id;
            // insert exceptionZip;
            // ZipCode__c serviceZip = new ZipCode__c();
            // serviceZip.Name = SFS_ABConstantUtil.SERVICE_ZIP;
            // serviceZip.ServiceTerritory__c = serviceTerritory.Id;
            // insert serviceZip;

            ServiceTerritoryMember member1 = new ServiceTerritoryMember();
            member1.ServiceTerritoryId = serviceTerritory.Id;
            member1.ServiceResourceId = serviceResource1.Id;
            member1.EffectiveStartDate = Date.today().addDays(-5);
            member1.City = 'Test City';
            member1.State = 'Test State';
            member1.PostalCode = 'Test Postal Code';
            member1.Country = 'Test Country';
            insert member1;

            WorkOrder workOrder = new WorkOrder();
            //workOrder.EdgeID__c = '124234';
            insert workOrder;

            ServiceAppointment appointment1 = new ServiceAppointment();
            appointment1.ParentRecordId = workOrder.Id;
            appointment1.Subject = SFS_ABConstantUtil.SYSTEM_ADMIN;
            appointment1.EarliestStartTime = DateTime.now();
            appointment1.DueDate = DateTime.now().addDays(10);
            appointment1.Duration = 2.00;
            appointment1.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            appointment1.SchedStartTime = DateTime.now();
            appointment1.SchedEndTime = DateTime.now().addHours(2);
            //appointment1.TemporarySA__c = false;
            appointment1.ServiceTerritoryId = serviceTerritory.id;
            //appointment1.DwellingType__c = 'Residential';
            insert appointment1;

            ServiceAppointment appointment2 = new ServiceAppointment();
            appointment2.ParentRecordId = workOrder.Id;
            appointment2.Subject = 'Appointment 2';
            appointment2.EarliestStartTime = DateTime.now();
            appointment2.DueDate = DateTime.now().addDays(10);
            appointment2.Duration = 2.00;
            appointment2.Status = SFS_ABConstantUtil.SA_SCHEDULED;
            appointment2.SchedStartTime = DateTime.now().addMinutes(-60);
            appointment2.SchedEndTime = appointment2.SchedStartTime.addHours(2);
            //appointment2.TemporarySA__c = false;
            appointment2.ServiceTerritoryId = serviceTerritory.id;
            //appointment2.DwellingType__c = 'Residential';
            insert appointment2;
        }
    }

    @isTest
    static void testCreateCapacityRebuildJobRecord() {
        Test.StartTest();
        ServiceTerritory serviceTerritory = [SELECT Id FROM ServiceTerritory WHERE Name = :SFS_ABConstantUtil.SERVICE_TERRITORY_TWO];
        ServiceResource serviceResource = [SELECT Id FROM ServiceResource LIMIT 1];
        Capacity_Rebuild_Job__c cr = SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
            'Service Appointment Update',
            serviceResource.Id,
            serviceTerritory.Id,
            System.today(),
            System.today().addDays(1)
        );
        System.assertNotEquals(cr, null);
        Test.StopTest();
    }

    @isTest
    static void testGetConsumedCapacity() {
        Test.StartTest();
        ServiceTerritory serviceTerritory = [SELECT Id FROM ServiceTerritory WHERE Name = :SFS_ABConstantUtil.SERVICE_TERRITORY_TWO];
        //Account org = [SELECT Id FROM Account Limit 1];
        List<Consumed_Capacity__c> cc1 = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(serviceTerritory.Id, System.today(), System.today().addDays(1));
        List<Consumed_Capacity__c> cc2 = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(null, System.today(), System.today().addDays(1));
        Test.StopTest();
    }

    @isTest
    static void testGetSTMListById() {
        Test.StartTest();
        ServiceTerritory serviceTerritory = [SELECT Id FROM ServiceTerritory WHERE Name = :SFS_ABConstantUtil.SERVICE_TERRITORY_TWO];
        ServiceResource serviceResource = [SELECT Id FROM ServiceResource LIMIT 1];
        Set<Id> stId = new Set<Id>();
        stId.add(serviceTerritory.Id);
        Set<Id> srId = new Set<Id>();
        srId.add(serviceResource.Id);
        List<ServiceTerritoryMember> stm1 = SFS_ABCapacityRebuildJobUtil.getSTMListById(srId, stId);
        List<ServiceTerritoryMember> stm2 = SFS_ABCapacityRebuildJobUtil.getSTMListById(null, stId);
        List<ServiceTerritoryMember> stm3 = SFS_ABCapacityRebuildJobUtil.getSTMListById(srId, null);
        List<ServiceTerritoryMember> stm4 = SFS_ABCapacityRebuildJobUtil.getSTMListById(null, null);
        Test.StopTest();
    }

    @isTest
    static void testGetCapacityRebuildDataMap() {
        Test.StartTest();
        ServiceTerritoryMember stm = [SELECT Id FROM ServiceTerritoryMember LIMIT 1];
        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper cr = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(stm.Id, System.today(), system.today().addDays(1));
        Test.StopTest();
    }
}