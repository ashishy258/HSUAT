/**
 * @description       : To Created daily based CC records based on daily based Capacity_Rule_Template__c records
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 02-14-2021
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   02-14-2021   Ashish Yadav    Initial Version
 **/
global class SFS_ABNewDayBatchDailyConsumedCapacity implements Database.Batchable<sObject> {
    global string query = 'SELECT ID, Slots__c, Active__c,Service_Territory__c,Type__c,Max__c,Max_Rule__c,Object__c,Field__c,Value__c,Release_X_Hours_Before__c,Release_X_Hours_Before_Rule__c,Day_Of_Week__c,RecordTypeId FROM Capacity_Rule_Template__c WHERE Active__c=TRUE AND Type__c=\'Daily Capacity\'';
    global final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';

    public SFS_ABNewDayBatchDailyConsumedCapacity()
    {
        
    }
    // Run the query
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    // Execute
    global void execute(Database.BatchableContext BC, List<Capacity_Rule_Template__c> crList) {
        System.debug(crList.size() + '<<crList>> ' + crList);
        System.debug(LoggingLevel.DEBUG, 'debug details');
        capcityLogicExecution(crList);
        
    }
    
    public static void capcityLogicExecution(List<Capacity_Rule_Template__c> crList)
    {
System.debug(' capcityLogicExecution executed');
        // Vars
        Map<String, Consumed_Capacity__c> insertConsumedCapacityMap = new Map<String, Consumed_Capacity__c>();
        Set<ID> templateIdSet = new Set<ID>();
        Map<String, Consumed_Capacity__c> existingCapacityRuleMap = new Map<String, Consumed_Capacity__c>();

        // Create Consumed Capacity Org + Territory "Daily Rules"
        try {
            // Get the Days to Create
            SFS_AB_Capacity_Settings__mdt appConfig = [
                SELECT Id, Configuration_Name__c, Configuration_Value__c
                FROM SFS_AB_Capacity_Settings__mdt
                WHERE Configuration_Name__c = :SFS_ABConstantUtil.DAYS_TO_BUILD_CAPACITY
            ];
            Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
            Date lastDate = System.Today().addDays(daysToBuild);
            system.debug('daysToBuild>> ' + daysToBuild);

            // Get a set of the Template Ids
            for (Capacity_Rule_Template__c cr : crList) {
                templateIdSet.add(cr.Id);
            }
            system.debug(templateIdSet.size() + ' templateIdSet>> ' + templateIdSet);

            // Get the current Daily Rules to check for gaps and fill them and increment
            for (Consumed_Capacity__c ccRecord : [
                SELECT ID, External_Id__c, Active__c
                FROM Consumed_Capacity__c
                WHERE Capacity_Rule_Template__c IN :templateIdSet AND Capacity_Date__c <= :lastDate AND Type__c = 'Daily Capacity'
            ]) {
                existingCapacityRuleMap.put(ccRecord.External_Id__c, ccRecord);
            }
            system.debug(existingCapacityRuleMap.size() + ' <<<existingCapacityRuleMap>>> ' + existingCapacityRuleMap);
            // Loop through Capacity Rules and Days -> Insert any days that are missing from now until the max days

            for (Capacity_Rule_Template__c ruleTemplateRecord : crList) {
                for (Integer x = 0; x < daysToBuild; x++) {
                    date mapKeydate = System.today().addDays(x);
                    system.debug('mapKeydate>>>> ' + mapKeydate);
                    //String mapKeyString = ruleTemplateRecord.Organization__c + '-' + ruleTemplateRecord.Service_Territory__c + '-' + mapKeydate.format() + '-' + 'Daily-Capacity';
                    String mapKeyString = ruleTemplateRecord.Service_Territory__c + '-' + mapKeydate.format()+'-'+ ruleTemplateRecord.Slots__c+ '-' + 'Daily-Capacity';

                    String localDayofWeek = getDayOfWeek(mapKeydate);
                    if (string.isNotBlank(localDayofWeek) && ruleTemplateRecord.Day_Of_Week__c == localDayofWeek) {
                        if (existingCapacityRuleMap != null && existingCapacityRuleMap.size() > 0 && !existingCapacityRuleMap.containsKey(mapKeyString)) {
                            system.debug('Key not found>> ' + mapKeyString);
                            Consumed_Capacity__c ccRecord = createCapacity(ruleTemplateRecord, mapKeyString, x);
                            insertConsumedCapacityMap.put(mapKeyString, ccRecord);
                        } else if (existingCapacityRuleMap != null && existingCapacityRuleMap.size() == 0) {
                            system.debug('Map is null');
                            Consumed_Capacity__c ccRecord = createCapacity(ruleTemplateRecord, mapKeyString, x);
                            insertConsumedCapacityMap.put(mapKeyString, ccRecord);
                        }
                    }
                }
            }

            system.debug(insertConsumedCapacityMap.size() + ' <<insertConsumedCapacityMap insert>> ' + insertConsumedCapacityMap);
            if (insertConsumedCapacityMap != null && insertConsumedCapacityMap.size() > 0) {
                insert insertConsumedCapacityMap.values();
                insertConsumedCapacityMap = new Map<String, Consumed_Capacity__c>();
            }

            System.debug('Heapsize used>' + system.Limits.getHeapSize());
            System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        } catch (Exception e) {
            System.debug('Exception: ' + e);
        }
    }

    // Call the Rule Batch to build the next days rule records associated to the daily rules
    global void finish(Database.BatchableContext BC) {
        System.debug(LoggingLevel.DEBUG, 'in finish');
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE '%NewDayBatchDailyCC Job%' AND TimesTriggered != 0]) {
            try {
                //then use the active job id and abort it
                system.abortJob(ct.Id);
            } catch (Exception e) {
                // Handle this exception here
                System.debug('An exception occurred: ' + e.getMessage());
            }
        }
        //List<ServiceTerritory> stList = [SELECT Id from ServiceTerritory WHERE IsActive = TRUE AND TerritoryType__c  != 'DMA'];
        List<ServiceTerritory> stList = [SELECT Id FROM ServiceTerritory WHERE IsActive = TRUE];
        Set<Id> territoryIds = new Set<Id>();
        for (ServiceTerritory st : stList) {
            territoryIds.add(st.Id);
        }
        System.debug('ABOUT TO CALL RULE ONE');
        SFS_ABNewDayBatchRuleConsumedCapacity ruleBatch = new SFS_ABNewDayBatchRuleConsumedCapacity(territoryIds);
        Database.executeBatch(ruleBatch, 200);
        //  SFS_ABNewDailyBatchResourceCapacity nextBatch = new SFS_ABNewDailyBatchResourceCapacity();
        //  Database.executeBatch(nextBatch, 100);
    }

    //Craete Consumed Capacity Record Based on Rule Template
    public static Consumed_Capacity__c createCapacity(Capacity_Rule_Template__c ruleRecord, String mapKey, Integer dayIncrement) {
        Consumed_Capacity__c ccRecord = new Consumed_Capacity__c();
        ccRecord.Capacity_Date__c = System.Today().addDays(dayIncrement);
        ccRecord.Type__c = 'Daily Capacity';
        ccRecord.RecordTypeId = Schema.SObjectType.Consumed_Capacity__c.getRecordTypeInfosByDeveloperName().get('Daily_Capacity').getRecordTypeId();
        if (ruleRecord.Service_Territory__c != null) {
            ccRecord.Service_Territory__c = ruleRecord.Service_Territory__c;
        }
        /*if (ruleRecord.Organization__c != null) {
            ccRecord.Organization__c = ruleRecord.Organization__c;
        }*/
        ccRecord.Max_Rule__c = ruleRecord.Max_Rule__c;
        ccRecord.Release_X_Hours_Before__c = ruleRecord.Release_X_Hours_Before__c;
        ccRecord.Max__c = ruleRecord.Max__c;
        ccRecord.External_Id__c = mapKey;
        ccRecord.Capacity_Rule_Template__c = ruleRecord.Id;
        ccRecord.Overall_Capacity__c = ruleRecord.Max__c;
        ccRecord.Slots__c = ruleRecord.Slots__c;
        return ccRecord;
    }

    //To get Day of Week from Date
    public static String getDayOfWeek(Date dt) {
        DateTime myDateTime = (DateTime) dt.addDays(1);
        String dayOfWeek = myDateTime.format('EEEE');
        return dayOfWeek;
    }
}