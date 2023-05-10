public with sharing class SFS_ABTestFactory {
    public SFS_ABTestFactory() {
    }

    public static final string TEST_USER_NAME1 = 'test_service_user@test.com';

    // Creating an test service resource user
    public static User createAServiceUser() {
        // Get the Profile for System Admin profile
        integer STRING_LENGTH = 3;
        Double MAX = Math.pow(10, STRING_LENGTH) - 1; // Returns 999
        String aleaNumberN = String.valueOf(Math.Round(Math.Random() * MAX)).leftPad(STRING_LENGTH, '0');
        Profile servicesProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testServiceUser = new User();
        testServiceUser.FirstName = 'Test';
        testServiceUser.LastName = 'Service Resource';
        testServiceUser.ProfileId = servicesProfile.Id;
        testServiceUser.username = TEST_USER_NAME1 + aleaNumberN;
        testServiceUser.email = 'TestServiceUser@test.com' + aleaNumberN;
        testServiceUser.Alias = '02' + aleaNumberN;
        testServiceUser.AboutMe = SFS_ABConstantUtil.TEST_SR_GUID;
        testServiceUser.TimeZoneSidKey = 'GMT';
        testServiceUser.LocaleSidKey = 'en_US';
        testServiceUser.EmailEncodingKey = 'UTF-8';
        testServiceUser.LanguageLocaleKey = 'en_US';
        testServiceUser.IsActive = true;
        testServiceUser.FederationIdentifier = 'test5136131686851' + aleaNumberN;
        insert testServiceUser;
        return testServiceUser;
    }

    // Creating an test service resource user
    public static User createAServiceUser2(String UserName) {
        // Get the Profile for System Admin profile
        Profile servicesProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User testServiceUser = new User();
        testServiceUser.FirstName = 'Test';
        testServiceUser.LastName = 'Service Resource';
        testServiceUser.ProfileId = servicesProfile.Id;
        testServiceUser.username = UserName;
        testServiceUser.email = UserName;
        testServiceUser.Alias = '2222202';
        testServiceUser.TimeZoneSidKey = 'GMT';
        testServiceUser.LocaleSidKey = 'en_US';
        testServiceUser.EmailEncodingKey = 'UTF-8';
        testServiceUser.LanguageLocaleKey = 'en_US';
        testServiceUser.IsActive = true;
        testServiceUser.FederationIdentifier = UserName; //'test666666666668131686851';
        insert testServiceUser;
        return testServiceUser;
    }


    // Creating Contractor Account relationship data
    public static List<Capacity_Rule_Template__c> createDailyCapacityTemplates(String territoryId) {
        List<String> weekDays = new List<String>{ 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' };
        List<Capacity_Rule_Template__c> rules = new List<Capacity_Rule_Template__c>();
        if (territoryId != null) {
            rules = [SELECT Id, Day_Of_Week__c FROM Capacity_Rule_Template__c WHERE Service_Territory__c = :territoryId];
        }

        if (rules.size() == 0) {
            for (String day : weekDays) {
                Capacity_Rule_Template__c rule = new Capacity_Rule_Template__c();
                rule.RecordTypeId = SFS_ABConstantUtil.DAILY_CAPACITY_TEMPLATE;
                rule.Day_Of_Week__c = day;
                rule.Active__c = true;
                rule.Max__c = 90;
                rule.Max_Rule__c = 33;
                rule.Active__c = true;
                rule.Type__c = 'Daily Capacity';
                if (territoryId != null) {
                    rule.Service_Territory__c = territoryId;
                }  
                rules.add(rule);
            }
            insert rules;
        }
        return rules;
    }

    // Creating Contractor Account relationship data
    public static List<Capacity_Rule_Template__c> createRuleBasedCapacityTemplates(List<Capacity_Rule_Template__c> dailyTemplates, String territoryId) {
        List<Capacity_Rule_Template__c> childRules = new List<Capacity_Rule_Template__c>();
        for (Capacity_Rule_Template__c dailyTemplate : dailyTemplates) {
            Capacity_Rule_Template__c template = new Capacity_Rule_Template__c();
            template.RecordTypeId = SFS_ABConstantUtil.RULE_BASED_CAPACITY_TEMPLATE;
            template.Object__c = 'ServiceAppointment';
            template.Field__c = 'Work_Type_Category__c';
            template.Value__c = 'Repair FFS';
            template.Max_Rule__c = 20;
            template.Active__c = true;
            template.Day_Of_Week__c = dailyTemplate.Day_Of_Week__c;
            template.Parent_Capacity_Rule_Template__c = dailyTemplate.Id;
            if (territoryId != null) {
                template.Service_Territory__c = territoryId;
            }  
            template.Type__c = 'Rule Based Capacity';
            childRules.add(template);
        }
        insert childRules;
        return childRules;
    }

    // Creating Service Resource data
    public static ServiceResource createServiceResource(User userRecord) {
        ServiceResource srRecord = new ServiceResource();
        srRecord.Name = (String.isBlank(userRecord.FirstName) ? '' : userRecord.FirstName + ' ') + userRecord.LastName;
        srRecord.IsActive = true;
        srRecord.RelatedRecordId = userRecord.Id;
        srRecord.ResourceType = 'T';
        srRecord.FSL__Efficiency__c = 1;
        //srRecord.Organization__c = organizationAccount.Id;
        //srRecord.SubContractor__c = contractorAccount.Id;
        insert srRecord;
        return srRecord;
    }


    // Creating WorkOrder data
    public static WorkOrder createWorkOrder() {
        WorkOrder workOrder = new WorkOrder();
        //workOrder.OrganizationAccount__c =  OrgnizationId;
        //workOrder.Sub_Contractor__c = subContractor1.Id;
        //workOrder.AccountId = personAccount.Id;
        integer STRING_LENGTH = 3;
        Double MAX = Math.pow(10, STRING_LENGTH) - 1; // Returns 999
        String aleaNumberN = String.valueOf(Math.Round(Math.Random() * MAX)).leftPad(STRING_LENGTH, '0');
        //workOrder.EdgeID__c = '194' + Integer.ValueOf(aleaNumberN);
        insert workOrder;
        return workOrder;
    }

    public static ServiceTerritory createServiceTerritory(String terrName) {
        OperatingHours testHours = createOperatingHours();
        insert testHours;
        OperatingHours tmpHours = [SELECT Id FROM OperatingHours WHERE Name = 'tstHours' LIMIT 1];

        ServiceTerritory testTerritory = new ServiceTerritory();
        testTerritory.Name = terrName;
        testTerritory.OperatingHoursId = tmpHours.Id;
        testTerritory.IsActive = true;

        insert testTerritory;

        return testTerritory;
    }

    // Creating ServiceTerritoryMember Data
    public static ServiceTerritoryMember createServiceTerritoryMember(ServiceResource srRecord, ServiceTerritory srTerritoryRecord) {
        ServiceTerritory tmpTerr = [SELECT Id FROM ServiceTerritory WHERE Name = :srTerritoryRecord.Name LIMIT 1];

        ServiceTerritoryMember stMemberRecord = new ServiceTerritoryMember();
        stMemberRecord.TerritoryType = 'P';
        stMemberRecord.ServiceTerritoryId = tmpTerr.Id;
        stMemberRecord.ServiceResourceId = srRecord.Id;
        stMemberRecord.EffectiveStartDate = System.now() - 1;
        stMemberRecord.EffectiveEndDate = System.now().addDays(5);
        insert stMemberRecord;
        ServiceTerritoryMember serviceTerritoryMemberRecord = [SELECT Id, ServiceTerritoryId, TerritoryType FROM ServiceTerritoryMember LIMIT 1];

        return serviceTerritoryMemberRecord;
    }

    public static OperatingHours createOperatingHours() {
        OperatingHours testHours = new OperatingHours(Name = 'tstHours');

        return testHours;
    }

    public static Consumed_Capacity__c createConsumedCapacity(Capacity_Rule_Template__c ruleTemplateRecord, String serviceTerritoryId, String type, Date capacityDate, Consumed_Capacity__c parentConsumedCapacity) {
        Consumed_Capacity__c capacity = new Consumed_Capacity__c();
        capacity.Capacity_Date__c = capacityDate;
        capacity.Service_Territory__c = serviceTerritoryId;
        capacity.Capacity_Rule_Template__c = ruleTemplateRecord.Id;
        capacity.Slots__c = ruleTemplateRecord.Slots__c;
        if (type == 'Daily Capacity') {
            capacity.RecordTypeId = SFS_ABConstantUtil.DAILY_CONSUMED_CAPACITY;
            capacity.Type__c = type;
            capacity.Max__c = 100;
            capacity.Overall_Capacity__c = 0;
            capacity.Overall_Consumption__c = 0;
            capacity.External_Id__c = ruleTemplateRecord.Service_Territory__c + '-' + capacityDate.format()+'-'+ ruleTemplateRecord.Slots__c+ '-' + 'Daily-Capacity';
        } else if (type == 'Rule Based Capacity') {
            capacity.RecordTypeId = SFS_ABConstantUtil.RULE_BASED_CONSUMED_CAPACITY;
            capacity.Type__c = type;
            capacity.Max_Rule__c = 50;
            capacity.Object__c = 'ServiceAppointment';
            capacity.Field__c = 'Work_Type_Category__c	';
            capacity.Value__c = 'Installation';
            capacity.Parent_Consumed_Capacity__c = parentConsumedCapacity.Id;
            capacity.Overall_Capacity_Rule__c = 0;
            capacity.Rule_Consumption__c = 0;
            capacity.External_Id__c = parentConsumedCapacity.Id + '__' + ruleTemplateRecord.Id+'__'+ruleTemplateRecord.Day_of_Week__c+'__'+ruleTemplateRecord.Value__c+'__'+ parentConsumedCapacity.Capacity_Date__c.format()+'__'+parentConsumedCapacity.Slots__c;
        }
        return capacity;
    }

    public static Capacity_Rule_Template__c createConsumedCapacityTemplate(String serviceTerritoryId, String dayOfTheWeek, String type, String slot, String parentConsumedCapacityTemplateId) {
        Capacity_Rule_Template__c template = new Capacity_Rule_Template__c();
        template.Service_Territory__c = serviceTerritoryId;
        template.Day_of_Week__c = dayOfTheWeek;
        template.Active__c = true;
        template.Slots__c = slot;
        if (type == 'Daily Capacity') {
            template.RecordTypeId = SFS_ABConstantUtil.DAILY_CAPACITY_TEMPLATE;
            template.Type__c = type;
            template.Max__c = 100;
        } else if (type == 'Rule Based Capacity') {
            template.RecordTypeId = SFS_ABConstantUtil.RULE_BASED_CAPACITY_TEMPLATE;
            template.Type__c = type;
            template.Max_Rule__c = 50;
            template.Object__c = 'ServiceAppointment';
            template.Field__c = 'Work_Type_Category__c	';
            template.Value__c = 'Installation';
            template.Parent_Capacity_Rule_Template__c = parentConsumedCapacityTemplateId;
        }
        return template;
    }
}