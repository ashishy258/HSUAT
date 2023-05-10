/**
 * @description       : Cover the code coverage of SFS_ABNewDayBatchDailyConsumedCapacity, SFS_ABNewDayBatchRuleConsumedCapacity and SFS_ABNewDailyBatchResourceCapacity apex classes
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 03-15-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   03-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class SFS_ABNewDayBatchConsumedCapacityTest {

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
            member1.TerritoryType = 'P';
            member1.EffectiveStartDate = Date.today();
            insert member1;

            //Creating Daily based Consumed Capacity template Records
            String todaysDayOfTheWeek = SFS_ABNewDayBatchDailyConsumedCapacity.getDayOfWeek(System.today());
            List<Capacity_Rule_Template__c> dailyCapacityTemplates = new List<Capacity_Rule_Template__c>();
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Daily Capacity', '8:00AM - 12:00PM', null));
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Daily Capacity', '12:00PM - 4:00PM', null));
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Daily Capacity', '4:00PM - 8:30PM', null));
            dailyCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Daily Capacity', '8:30PM - 10:30PM', null));
            insert dailyCapacityTemplates;

            //Creating Rule based Consumed Capacity template Records
            List<Capacity_Rule_Template__c> ruleCapacityTemplates = new List<Capacity_Rule_Template__c>();
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Rule Based Capacity', '8:00AM - 12:00PM', dailyCapacityTemplates[0].Id));
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Rule Based Capacity', '12:00PM - 4:00PM', dailyCapacityTemplates[1].Id));
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Rule Based Capacity', '4:00PM - 8:30PM', dailyCapacityTemplates[2].Id));
            ruleCapacityTemplates.add(SFS_ABTestFactory.createConsumedCapacityTemplate(serviceTerritory1.Id, todaysDayOfTheWeek, 'Rule Based Capacity', '8:30PM - 10:30PM', dailyCapacityTemplates[3].Id));
            insert ruleCapacityTemplates;

        }
    }

    @IsTest
    public static void testABNewDayBatchDailyConsumedCapacity(){
        List<Consumed_Capacity__c> consumeCapacityListInitial = [SELECT Id FROM Consumed_Capacity__c WHERE Capacity_Date__c =: System.today() AND Type__c = 'Daily Capacity'];
        System.assertEquals(0, consumeCapacityListInitial.size(), 'The initial list of daily consumed capacity records is zero');
        Test.startTest();
        Database.executeBatch(new SFS_ABNewDayBatchDailyConsumedCapacity(), 200);
        Test.stopTest();
        List<Consumed_Capacity__c> consumeCapacityListInserted = [SELECT Id FROM Consumed_Capacity__c WHERE Capacity_Date__c =: System.today() AND Type__c = 'Daily Capacity'];
        System.assertEquals(4, consumeCapacityListInserted.size(), 'The size of newly created todays daily consumed capacity list is four');

    }

    @IsTest
    public static void testABNewDayBatchDailyRuleConsumedCapacity(){
        List<Consumed_Capacity__c> ruleConsumeCapacityListInitial = [SELECT Id FROM Consumed_Capacity__c WHERE Capacity_Date__c =: System.today() AND Type__c = 'Rule Based Capacity'];
        System.assertEquals(0, ruleConsumeCapacityListInitial.size(), 'The initial list of rule consumed capacity records is zero');
        Test.startTest();
        Database.executeBatch(new SFS_ABNewDayBatchDailyConsumedCapacity(), 200);
        Test.stopTest();
        List<Consumed_Capacity__c> ruleConsumeCapacityListInserted = [SELECT Id FROM Consumed_Capacity__c WHERE Capacity_Date__c =: System.today() AND Type__c = 'Rule Based Capacity'];
        System.assertEquals(4, ruleConsumeCapacityListInserted.size(), 'The size of newly created todays rule consumed capacity list is four');

    }

    @IsTest
    public static void testABNewDailyBatchResourceCapacity(){
        ServiceTerritoryMember stm = [SELECT Id, ServiceTerritoryId, ServiceResourceId FROM ServiceTerritoryMember LIMIT 1];
        List<Resource_Capacity__c> resourceCapacityListInitial = [SELECT Id FROM Resource_Capacity__c WHERE Capacity_Date__c =: System.today() AND Service_Territory__c =: stm.ServiceTerritoryId AND Service_Resource__c =: stm.ServiceResourceId];
        System.assertEquals(0, resourceCapacityListInitial.size(), 'The initial list of resource capacity records is zero');
        Test.startTest();
        Database.executeBatch(new SFS_ABNewDayBatchDailyConsumedCapacity(), 200);
        Test.stopTest();
        List<Resource_Capacity__c> resourceCapacityListFinal = [SELECT Id, External_Id__c FROM Resource_Capacity__c WHERE Capacity_Date__c =: System.today() AND Service_Territory__c =: stm.ServiceTerritoryId AND Service_Resource__c =: stm.ServiceResourceId];
        System.assertEquals(1, resourceCapacityListFinal.size(), 'The size of newly created todays resource capacity list is one');
        String externalId = stm.ServiceResourceId + '_' + stm.ServiceTerritoryId + '_' + System.today().format();
        System.assertEquals(externalId, resourceCapacityListFinal[0].External_Id__c, 'The external created from batch and one created above should be equal.');

    }
}