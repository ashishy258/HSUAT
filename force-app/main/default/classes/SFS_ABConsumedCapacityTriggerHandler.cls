/**
 * @description       :
 * @author            : Salesforce Services
 * @group             :
 * @last modified on  : 05-21-2021
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
 * Modifications Log
 * Ver   Date         Author                               Modification
 * 1.0   11-02-2020   Salesforce Services                  Initial Version
 **/
public with sharing class SFS_ABConsumedCapacityTriggerHandler implements rflib_TriggerHandler {
    public void run(rflib_TriggerManager.Args args) {
System.debug('run method exceuted');
        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
      if (!system.isBatch()) {
System.debug('AFTER_INSERT exceuted');
                callAfterInsert(args);
        }
        }

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
         if (!system.isBatch()) {
System.debug('BEFORE_UPDATE exceuted');
                callBeforeUpdate(args);
      }
        }

        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
         if (!system.isBatch()) {
System.debug('AFTER_UPDATE exceuted');
                callAfterUpdate(args);
               // callAfterInsert(args);
          }
        }

        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            //callDeletePlatformEvent(args);
        }
    }

    //To Create Calculate Rule Based Capacity on Daily Capacity Record Insert
    public static void callAfterInsert(rflib_TriggerManager.Args args) {
        Set<Id> territoryIds = new Set<ID>();
        Set<Id> ruleBasedCapacityIds = new Set<ID>();
        for (Consumed_Capacity__c capacity : (List<Consumed_Capacity__c>) args.newRecords) {
            if (capacity.Type__c == 'Daily Capacity') {
                territoryIds.add(capacity.Service_Territory__c);
            } else if (capacity.Type__c == 'Rule Based Capacity') {
                ruleBasedCapacityIds.add(capacity.Id);
            }
        }
        Map<Id, Map<String, List<Capacity_Rule_Template__c>>> ruleMap = getRuleBasedCapacityRuleMap(territoryIds);
        List<Consumed_Capacity__c> ruleBasedCapacities = new List<Consumed_Capacity__c>();
        Map<string,Consumed_Capacity__c> ruleBasedCapacitiesMap = new Map<string,Consumed_Capacity__c>();

        if (ruleBasedCapacityIds.size() > 0) {
            List<Consumed_Capacity__c> ruleBasedCapacityList = [
                SELECT Id, Parent_Consumed_Capacity__r.Overall_Capacity__c, Max_Rule__c, Overall_Capacity_Rule__c
                FROM Consumed_Capacity__c
                WHERE Id IN :ruleBasedCapacityIds
            ];
            for (Consumed_Capacity__c capacity : ruleBasedCapacityList) {
                capacity.Overall_Capacity_Rule__c = (capacity.Max_Rule__c * 0.01) * capacity.Parent_Consumed_Capacity__r.Overall_Capacity__c;
            }
            update ruleBasedCapacityList;
        }

        for (Consumed_Capacity__c capacity : (List<Consumed_Capacity__c>) args.newRecords) {
            if (capacity.Type__c == 'Daily Capacity') {
                if (ruleMap.containsKey(capacity.Service_Territory__c)) {
                    Map<String, List<Capacity_Rule_Template__c>> dailyRules = ruleMap.get(capacity.Service_Territory__c);
                    if (dailyRules.containsKey(HSCommonUtil.getDayOfWeek(capacity.Capacity_Date__c) + capacity.Slots__c)) {
                        for (Capacity_Rule_Template__c rule : dailyRules.get(HSCommonUtil.getDayOfWeek(capacity.Capacity_Date__c) + capacity.Slots__c)) {
                            ruleBasedCapacities.add(createRuleBasedCapacity(rule, capacity));
                        }
                    }
                }
            }
        }

        try {
            upsert ruleBasedCapacities External_Id__c;
        } catch (Exception e) {
            system.debug('Exception======' + e.getStackTraceString());
        }
    }

    //To Restrict Override Capacity if IsOverriden in Checked
    public static void callBeforeUpdate(rflib_TriggerManager.Args args) {
        Set<Id> parentCapacityIds = new Set<ID>();
        Set<Id> orgIds = new Set<ID>();
        system.debug((List<Consumed_Capacity__c>) args.newRecords);
        List<Consumed_Capacity__c> ruleBasedCapacities = new List<Consumed_Capacity__c>();
        for (Consumed_Capacity__c capacity : (List<Consumed_Capacity__c>) args.newRecords) {
            if (capacity.IsOverridden__c == true && HSCommonUtil.isOverrideOn == true) {
                capacity.Max__c = ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Max__c;
                capacity.Max_Rule__c = ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Max_Rule__c;
                capacity.Release_X_Hours_Before__c = ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Release_X_Hours_Before__c;
                capacity.Release_X_Hours_Before_Rule__c = ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Release_X_Hours_Before_Rule__c;
            }

            system.debug(capacity.Type__c);
            system.debug(((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Max_Rule__c);
            system.debug(((Consumed_Capacity__c) args.newRecordsMap.get(capacity.Id)).Max_Rule__c);
            if (
                capacity.Type__c == 'Rule Based Capacity' &&
                ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Max_Rule__c != ((Consumed_Capacity__c) args.newRecordsMap.get(capacity.Id)).Max_Rule__c
            ) {
                system.debug(capacity);
                parentCapacityIds.add(capacity.Parent_Consumed_Capacity__c);
                ruleBasedCapacities.add(capacity);
            }
        }

        Map<Id, Consumed_Capacity__c> parentCapcityMap = new Map<Id, Consumed_Capacity__c>([SELECT Id, Overall_Capacity__c FROM Consumed_Capacity__c WHERE Id IN :parentCapacityIds]);

        for (Consumed_Capacity__c capacity : ruleBasedCapacities) {
            if (capacity.Type__c == 'Rule Based Capacity' && parentCapcityMap.containsKey(capacity.Parent_Consumed_Capacity__c)) {
                capacity.Overall_Capacity_Rule__c = (capacity.Max_Rule__c * 0.01) * (parentCapcityMap.get(capacity.Parent_Consumed_Capacity__c)).Overall_Capacity__c;
                system.debug(capacity);
            }
        }
    }

    //To Calculate Rule Based Capacity on Daily Capacity Record Insert
    public static void callAfterUpdate(rflib_TriggerManager.Args args) {
        Set<Id> territoryIds = new Set<ID>();
        Set<Id> parentCapacityIds = new Set<ID>();
        for (Consumed_Capacity__c capacity : (List<Consumed_Capacity__c>) args.newRecords) {
            if (
                capacity.Type__c == 'Daily Capacity' &&
                ((Consumed_Capacity__c) args.oldRecordsMap.get(capacity.Id)).Overall_Capacity__c != ((Consumed_Capacity__c) args.newRecordsMap.get(capacity.Id)).Overall_Capacity__c
            ) {
                parentCapacityIds.add(capacity.Id);
            }
        }

        List<Consumed_Capacity__c> ruleBasedCapacities = [
            SELECT Id, Max_Rule__c, Parent_Consumed_Capacity__c
            FROM Consumed_Capacity__c
            WHERE Type__c = 'Rule Based Capacity' AND Parent_Consumed_Capacity__c IN :parentCapacityIds
        ];
        Map<Id, List<Consumed_Capacity__c>> parentChildCapacityMap = new Map<Id, List<Consumed_Capacity__c>>();
        for (Consumed_Capacity__c ruleBasedCapacity : ruleBasedCapacities) {
            if (parentChildCapacityMap.containsKey(ruleBasedCapacity.Parent_Consumed_Capacity__c)) {
                List<Consumed_Capacity__c> capacityList = parentChildCapacityMap.get(ruleBasedCapacity.Parent_Consumed_Capacity__c);
                capacityList.add(ruleBasedCapacity);
                parentChildCapacityMap.put(ruleBasedCapacity.Parent_Consumed_Capacity__c, capacityList);
            } else {
                List<Consumed_Capacity__c> capacityList = new List<Consumed_Capacity__c>();
                capacityList.add(ruleBasedCapacity);
                parentChildCapacityMap.put(ruleBasedCapacity.Parent_Consumed_Capacity__c, capacityList);
            }
        }

        for (Id capacityId : parentChildCapacityMap.keySet()) {
            for (Consumed_Capacity__c ruleBasedCapacity : parentChildCapacityMap.get(capacityId)) {
                if (ruleBasedCapacity.Max_Rule__c != null && ((Consumed_Capacity__c) args.newRecordsMap.get(capacityId)).Overall_Capacity__c != null) {
                    ruleBasedCapacity.Overall_Capacity_Rule__c = (ruleBasedCapacity.Max_Rule__c * 0.01) * ((Consumed_Capacity__c) args.newRecordsMap.get(capacityId)).Overall_Capacity__c;
                }
            }
        }

        try {
            update ruleBasedCapacities;
        } catch (Exception e) {
            system.debug('Exception======' + e.getStackTraceString());
        }
    }

    //To Create Rule Based Capacity Based on Template
    public static Consumed_Capacity__c createRuleBasedCapacity(Capacity_Rule_Template__c rule, Consumed_Capacity__c dailyRule) {
        Consumed_Capacity__c capacity = new Consumed_Capacity__c();
        capacity.Object__c = rule.Object__c;
        capacity.Field__c = rule.Field__c;
        capacity.Value__c = rule.Value__c;
        capacity.Max_Rule__c = rule.Max_Rule__c;
        capacity.Parent_Consumed_Capacity__c = dailyRule.Id;
        capacity.Capacity_Rule_Template__c = rule.Id;
        capacity.RecordTypeId = Schema.SObjectType.Consumed_Capacity__c.getRecordTypeInfosByDeveloperName().get('Rule_Based_Capacity').getRecordTypeId();
        capacity.Service_Territory__c = dailyRule.Service_Territory__c;
        capacity.Release_X_Hours_Before_Rule__c = rule.Release_X_Hours_Before_Rule__c;
        capacity.Type__c = 'Rule Based Capacity';
        capacity.External_Id__c = dailyRule.Id + '__' + rule.Id+'__'+rule.Day_of_Week__c+'__'+rule.Value__c+'__'+ dailyRule.Capacity_Date__c.format()+'__'+dailyRule.Slots__c;
		capacity.Slots__c = dailyRule.Slots__c;
        capacity.Capacity_Date__c = dailyRule.Capacity_Date__c;
        if (rule.Max_Rule__c != null && dailyRule.Overall_Capacity__c != null) {
            capacity.Overall_Capacity_Rule__c = (rule.Max_Rule__c * 0.01) * dailyRule.Overall_Capacity__c;
        }

        return capacity;
    }

  
    //To Get Territory Level Capacity Templates
    public static Map<Id, Map<String, List<Capacity_Rule_Template__c>>> getRuleBasedCapacityRuleMap(Set<Id> territoryIds) {
        List<Capacity_Rule_Template__c> capacityRules = [
            SELECT Id, Object__c, Release_X_Hours_Before_Rule__c, Field__c, Value__c, Max_Rule__c, Service_Territory__c, Day_Of_Week__c, Slots__c
            FROM Capacity_Rule_Template__c
            WHERE Type__c = 'Rule Based Capacity' AND Service_Territory__c IN :territoryIds
        ];
        Map<Id, Map<String, List<Capacity_Rule_Template__c>>> ruleMap = new Map<Id, Map<String, List<Capacity_Rule_Template__c>>>();
        for (Capacity_Rule_Template__c crt : capacityRules) {
            if (ruleMap.containsKey(crt.Service_Territory__c)) {
                Map<String, List<Capacity_Rule_Template__c>> territoryRuleMap = ruleMap.get(crt.Service_Territory__c);
                if (territoryRuleMap.containsKey(crt.Day_Of_Week__c + crt.Slots__c)) {
                    List<Capacity_Rule_Template__c> ruleList = territoryRuleMap.get(crt.Day_Of_Week__c + crt.Slots__c);
                    ruleList.add(crt);
                    territoryRuleMap.put(crt.Day_Of_Week__c + crt.Slots__c, ruleList);
                    ruleMap.put(crt.Service_Territory__c, territoryRuleMap);
                } else {
                    List<Capacity_Rule_Template__c> ruleList = new List<Capacity_Rule_Template__c>();
                    ruleList.add(crt);
                    territoryRuleMap.put(crt.Day_Of_Week__c + crt.Slots__c, ruleList);
                    ruleMap.put(crt.Service_Territory__c, territoryRuleMap);
                }
            } else {
                List<Capacity_Rule_Template__c> ruleList = new List<Capacity_Rule_Template__c>();
                ruleList.add(crt);
                Map<String, List<Capacity_Rule_Template__c>> territoryRuleMap = new Map<String, List<Capacity_Rule_Template__c>>();
                territoryRuleMap.put(crt.Day_Of_Week__c + crt.Slots__c, ruleList);
                ruleMap.put(crt.Service_Territory__c, territoryRuleMap);
            }
        }
        return ruleMap;
    }

   

    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
    }
}