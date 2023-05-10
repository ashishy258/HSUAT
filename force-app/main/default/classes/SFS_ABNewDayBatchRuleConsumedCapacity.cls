/**
 * @description       : To Created Rule based CC records based on Rule based Capacity_Rule_Template__c records
 * @author            : Salesforce Services
 * @group             :
 * @last modified on  : 06-30-2021
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   05-10-2021   Salesforce Services    Initial Version
 **/
global class SFS_ABNewDayBatchRuleConsumedCapacity implements Database.Batchable<sObject>, Database.Stateful {
    global string query = 'SELECT ID, Slots__c, Active__c,Service_Territory__c,Type__c,Max__c,Day_Of_Week__c,Max_Rule__c,Object__c,Field__c,Value__c,Release_X_Hours_Before__c,Release_X_Hours_Before_Rule__c,Parent_Capacity_Rule_Template__c FROM Capacity_Rule_Template__c WHere Active__c=TRUE AND Type__c=\'Rule Based Capacity\'';
    final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    final string NEW_DAY_RULE_TERRITORY_SIZE = 'NewDayRuleTerritorySize';
    global Set<Id> territorySet;
    global Set<Id> currentTerritorySet;

    public SFS_ABNewDayBatchRuleConsumedCapacity(Set<Id> territoryIdSet) {
        territorySet = new Set<Id>();
        currentTerritorySet = new Set<Id>();
        territorySet = territoryIdSet;
    }

    // Query
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Integer newDayRuleTerritorySize;
        SFS_AB_Capacity_Settings__mdt appConfig = [
            SELECT Id, Configuration_Name__c, Configuration_Value__c
            FROM SFS_AB_Capacity_Settings__mdt
            WHERE Configuration_Name__c = :NEW_DAY_RULE_TERRITORY_SIZE
        ];
        newDayRuleTerritorySize = Integer.valueOf(appConfig.Configuration_Value__c);
        for (Id territoryId : territorySet) {
            currentTerritorySet.add(territoryId);
        }

        if (currentTerritorySet != null && currentTerritorySet.size() > 0) {
            query = query + ' AND Service_Territory__c IN: currentTerritorySet';
        }

        System.debug(LoggingLevel.debug, 'Started this one');

        return Database.getQueryLocator(query);
    }

    // Execute
    global void execute(Database.BatchableContext BC, List<Capacity_Rule_Template__c> crList) {
        // Vars
        List<Consumed_Capacity__c> ccList = new List<Consumed_Capacity__c>();
        Set<ID> templateIdSet = new Set<ID>();
        Map<String, Consumed_Capacity__c> capTemplateIdToListOfDailyRuleMap = new Map<String, Consumed_Capacity__c>();
        Map<String, Consumed_Capacity__c> existingCapacityRuleMap = new Map<String, Consumed_Capacity__c>();

        // Create Rule based Capacity based on Template + Daily rules that don't exist for the Max days to build
        try {
            // Get the Days to Create and the last date to check
            SFS_AB_Capacity_Settings__mdt appConfig = [
                SELECT Id, Configuration_Name__c, Configuration_Value__c
                FROM SFS_AB_Capacity_Settings__mdt
                WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
            ];
            Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
            Date lastDate = System.Today().addDays(daysToBuild);
            List<Capacity_Rule_Template__c> parentCapacityRuleList = new List<Capacity_Rule_Template__c>();
            // Get a set of the Template Ids
            for (Capacity_Rule_Template__c cr : crList) {
                templateIdSet.add(cr.Id);
            }

            system.debug('templateIdSet>> ' + templateIdSet);

            // Get the current Rule based to check for gaps and fill them and increment
            for (Consumed_Capacity__c currentRule : [
                SELECT ID, External_Id__c, Capacity_Rule_Template__c,Slots__c
                FROM Consumed_Capacity__c
                WHERE Capacity_Rule_Template__c IN :templateIdSet AND Capacity_Date__c <= :lastDate AND Type__c = 'Rule Based Capacity'
            ]) {
                existingCapacityRuleMap.put(currentRule.External_Id__c, currentRule);
            }

            // Get the associated Daily Rules to parent the rule based against
            for (Consumed_Capacity__c dailyRule : [
                SELECT ID, Service_Territory__c, Capacity_Date__c, Overall_Capacity__c, Capacity_Rule_Template__c,Slots__c
                FROM Consumed_Capacity__c
                WHERE Type__c = 'Daily Capacity' AND Capacity_Date__c <= :lastDate AND Service_Territory__c IN :currentTerritorySet
            ]) {
                String mapKey = dailyRule.Capacity_Rule_Template__c + '-' + dailyRule.Capacity_Date__c.format()+'-'+dailyRule.Slots__c;
                system.debug('mapKey' + mapKey);
                capTemplateIdToListOfDailyRuleMap.put(mapKey, dailyRule);
            }
            system.debug(capTemplateIdToListOfDailyRuleMap.size() + 'capTemplateIdToListOfDailyRuleMap>>>  ' + capTemplateIdToListOfDailyRuleMap);

            for (Capacity_Rule_Template__c cr : crList) {
                if (capTemplateIdToListOfDailyRuleMap != null && capTemplateIdToListOfDailyRuleMap.size() > 0) {
                    for (Integer x = 0; x < daysToBuild; x++) {
                        date mapKeydate = System.today().addDays(x);
                        String localDayofWeek = SFS_ABNewDayBatchDailyConsumedCapacity.getDayOfWeek(mapKeydate);
                        String tempMapKey = cr.Parent_Capacity_Rule_Template__c + '-' + mapKeydate.format()+'-'+cr.Slots__c;
                        system.debug('tempMapKey' + tempMapKey);
                        if (capTemplateIdToListOfDailyRuleMap.containsKey(tempMapKey)) {
                            system.debug('Found the record');
                            Consumed_Capacity__c dRule = capTemplateIdToListOfDailyRuleMap.get(tempMapKey);

                            system.debug('dRule>>> ' + dRule);
                            if (localDayofWeek != null && localDayofWeek == cr.Day_Of_Week__c && cr.Slots__c == dRule.Slots__c) {
                                Consumed_Capacity__c cc = createRuleBasedCapacity(cr, dRule, mapKeydate);
                                if (existingCapacityRuleMap != null && existingCapacityRuleMap.size() > 0 && !existingCapacityRuleMap.containsKey(cc.External_Id__c)) {
                                    system.debug('if>>> ' + cc);
                                    ccList.add(cc);
                                } else if (existingCapacityRuleMap != null && existingCapacityRuleMap.size() == 0) {
                                    system.debug('Else if ' + cc);
                                    ccList.add(cc);
                                }
                            }
                        }
                    }
                }
            }
            system.debug(LoggingLevel.debug, 'ccList>> ' + ccList);
            if (!ccList.isEmpty()) {
                insert ccList;
            }

            System.debug('Heapsize used>' + system.Limits.getHeapSize());
            System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        } catch (Exception e) {
            System.debug('Exception: ' + e);
        }
    }

    // Fire the New Resource Capacity
    global void finish(Database.BatchableContext BC) {
        territorySet.removeAll(currentTerritorySet);
        if (territorySet.size() > 0) {
            SFS_ABNewDayBatchRuleConsumedCapacity nextIteration = new SFS_ABNewDayBatchRuleConsumedCapacity(territorySet);
            Database.executeBatch(nextIteration, 200);
        } else {
            SFS_ABNewDailyBatchResourceCapacity nextBatch = new SFS_ABNewDailyBatchResourceCapacity();
            Database.executeBatch(nextBatch, 100);
        }
    }

    public static Consumed_Capacity__c createRuleBasedCapacity(Capacity_Rule_Template__c rule, Consumed_Capacity__c dailyRule, Date capacityDate) {
        Consumed_Capacity__c capacity = new Consumed_Capacity__c();

        System.debug(LoggingLevel.DEBUG, 'rule value: ' + rule.Value__c);
        capacity.Object__c = rule.Object__c;
        capacity.Field__c = rule.Field__c;
        capacity.Value__c = rule.Value__c;
        capacity.Max_Rule__c = rule.Max_Rule__c;
        capacity.Parent_Consumed_Capacity__c = dailyRule.Id;
        capacity.Capacity_Rule_Template__c = rule.Id;
        capacity.Slots__c = rule.Slots__c;
        capacity.Service_Territory__c = dailyRule.Service_Territory__c;
        capacity.Release_X_Hours_Before_Rule__c = rule.Release_X_Hours_Before_Rule__c;
        capacity.Type__c = 'Rule Based Capacity';
        capacity.RecordTypeId = Schema.SObjectType.Consumed_Capacity__c.getRecordTypeInfosByDeveloperName().get('Rule_Based_Capacity').getRecordTypeId();
		capacity.External_Id__c = dailyRule.Id + '__' + rule.Id+'__'+rule.Day_of_Week__c+'__'+rule.Value__c+'__'+ dailyRule.Capacity_Date__c.format()+'__'+dailyRule.Slots__c;
        capacity.Capacity_Date__c = capacityDate;
        if (rule.Max_Rule__c != null && dailyRule.Overall_Capacity__c != null) {
            capacity.Overall_Capacity_Rule__c = (rule.Max_Rule__c * 0.01) * dailyRule.Overall_Capacity__c;
        }

        return capacity;
    }
}