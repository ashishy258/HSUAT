/**
 * @description       :
 * @author            : Salesforce Service
 * @group             :
 * @last modified on  : 11-04-2023 
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   11-04-2023   Vandana Verma     Initial Version
 **/
@isTest
public class SFS_ABCapacityRebuildJobBatchTest {
    //private static String subContractorName1 = SFS_ABConstantUtil.SUB_CONTRACTOR_ONE;
    //private static String organizationName1 = SFS_ABConstantUtil.ORGANIZATION_ONE;
    private static String serviceTerritoryName = SFS_ABConstantUtil.SERVICE_TERRITORY_ONE;
    private static String serviceTerritoryName2 = SFS_ABConstantUtil.SERVICE_TERRITORY_TWO;
   private static String serviceTerritoryName3 = 'SERVICE_TERRITORY_THREE';
    //private static String serviceRegionName = SFS_ABConstantUtil.SERVICE_REGION;

    @testSetup
    static void dataSetup() {
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
         
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);

            User testUser2 = SFS_ABTestFactory.createAServiceUser();
            ServiceResource serviceResource2 = SFS_ABTestFactory.createServiceResource(testUser2);

            User testUser3 = SFS_ABTestFactory.createAServiceUser();
            ServiceResource serviceResource3 = SFS_ABTestFactory.createServiceResource(testUser3);

            //Creating Operating Hours Record
            OperatingHours oh = new OperatingHours();
            oh.Name = 'Test Operating Hours';
            oh.TimeZone = 'America/New_York';
            insert oh;

            WorkOrder workOrder = new WorkOrder();
            insert workOrder;

               //Creating Service Territory
            ServiceTerritory serviceTerritory = new ServiceTerritory();
            serviceTerritory.Name = serviceTerritoryName;
            serviceTerritory.OperatingHoursId = oh.Id;
            serviceTerritory.IsActive = true;
            insert serviceTerritory;
            
            //Creating Service Territory
            ServiceTerritory serviceTerritory2 = new ServiceTerritory();
            serviceTerritory2.Name = serviceTerritoryName2;
            serviceTerritory2.OperatingHoursId = oh.Id;
            serviceTerritory2.IsActive = true;
            insert serviceTerritory2;


            ServiceTerritory serviceTerritory3 = new ServiceTerritory();
            serviceTerritory3.Name = serviceTerritoryName3;
            serviceTerritory3.OperatingHoursId = oh.Id;
            serviceTerritory3.IsActive = true;
            insert serviceTerritory3;
            
            ServiceTerritoryMember member1 = new ServiceTerritoryMember();
            member1.ServiceTerritoryId = serviceTerritory.Id;
            member1.ServiceResourceId = serviceResource1.Id;
            member1.EffectiveStartDate = Date.today();
            member1.City = 'Test City G';
            member1.State = 'Test State G';
            member1.PostalCode = 'Test Postal Code G';
            member1.Country = 'Test Country G';
            insert member1;
            ServiceTerritoryMember member2 = new ServiceTerritoryMember();
            member2.TerritoryType = 'S';
            member2.ServiceTerritoryId = serviceTerritory2.Id;
            member2.ServiceResourceId = serviceResource1.Id;
            member2.EffectiveStartDate = Date.today();
            // member2.City = 'Test City H';
            // member2.State = 'Test State H';
            // member2.PostalCode = 'Test Postal Code H';
            // member2.Country = 'Test Country H';
            insert member2;
            ServiceTerritoryMember member3 = new ServiceTerritoryMember();
            member3.ServiceTerritoryId = serviceTerritory2.Id;
            member3.ServiceResourceId = serviceResource2.Id;
            member3.EffectiveStartDate = Date.today();
            member3.EffectiveEndDate = Date.Today().addDays(30);
            member3.City = 'Test City S';
            member3.State = 'Test State S';
            member3.PostalCode = 'Test Postal Code S';
            member3.Country = 'Test Country S';
            insert member3;
            ServiceTerritoryMember member4 = new ServiceTerritoryMember();
member4.ServiceTerritoryId = serviceTerritory3.Id;
member4.ServiceResourceId = serviceResource3.Id;
member4.EffectiveStartDate = Date.today();
member4.EffectiveEndDate = Date.Today().addDays(30);
  member4.TerritoryType = 'R';
member4.City = 'Test City R';
member4.State = 'Test State R';
member4.PostalCode = 'Test Postal Code R';
member4.Country = 'Test Country R';
insert member4;
            //Creating Capacity Templates for Service Territory
            List<Capacity_Rule_Template__c> TerritorydailyCapacityTemplates = SFS_ABTestFactory.createDailyCapacityTemplates(serviceTerritory.Id);
            System.assertNotEquals(TerritorydailyCapacityTemplates, null);

            List<Capacity_Rule_Template__c> TerritoryRuleBasedCapacityTemplates = SFS_ABTestFactory.createRuleBasedCapacityTemplates(TerritorydailyCapacityTemplates, serviceTerritory.Id);
            System.assertNotEquals(TerritoryRuleBasedCapacityTemplates, null);

            // //Creating Capacity Templates for Organization
            // List<Capacity_Rule_Template__c> OrgdailyCapacityTemplates = CapacityControllerTestFactory.createDailyCapacityTemplates(organization1.Id,null);
            // System.assertNotEquals(OrgdailyCapacityTemplates, NULL);
            // system.debug('OrgdailyCapacityTemplates====='+OrgdailyCapacityTemplates);

            // List<Capacity_Rule_Template__c> orgRuleBasedCapacityTemplates = CapacityControllerTestFactory.createRuleBasedCapacityTemplates(OrgdailyCapacityTemplates,null,organization1.Id);
            // System.assertNotEquals(orgRuleBasedCapacityTemplates, NULL);

            Capacity_Rebuild_Job__c job1 = new Capacity_Rebuild_Job__c();
            job1.End_Date__c = System.today().addDays(20);
            job1.Start_Date__c = System.Today();
            job1.Service_Resource__c = serviceResource1.id;
            job1.Type__c = 'Service Resource Update';
            insert job1;

            Capacity_Rebuild_Job__c job2 = new Capacity_Rebuild_Job__c();
            job2.Service_Territory__c = serviceTerritory.id;
            job2.Type__c = 'Service Territory Update';
            insert job2;

            Capacity_Rebuild_Job__c job3 = new Capacity_Rebuild_Job__c();
            job3.Service_Resource__c = serviceResource2.id;
            job3.Service_Territory__c = serviceTerritory2.id;
            job3.Type__c = 'Service Territory Member Insert';
            insert job3;
        }
    }

    // @isTest
    // static void testScheduler(){

    //     Test.startTest();
    //     String CRON_EXP = '0 0 5 * * ?';
    //     String jobId = System.schedule('New Daily Batch',  CRON_EXP, new CapacityRebuildJobScheduler('Batch3'));
    //     CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];
    //     System.assertEquals(CRON_EXP, ct.CronExpression);
    //     System.assertEquals(0, ct.TimesTriggered);
    //     Test.stopTest();
    // }

    @isTest
    static void testBasic() {
        Test.startTest();

        SFS_ABCapacityRebuildJobBatch nextBatch = new SFS_ABCapacityRebuildJobBatch('Batch1');
        Database.executeBatch(nextBatch, 200);

        Test.stopTest();
    }
}