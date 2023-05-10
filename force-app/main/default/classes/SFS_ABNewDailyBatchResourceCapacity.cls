/**
 * @description       :
 * @author            : David
 * @group             :
 * @last modified on  : 03-12-2021
 * Modifications Log
 * Ver   Date         Author   Modification
 * 1.0   05-10-2021   David    Initial Version
 **/
global class SFS_ABNewDailyBatchResourceCapacity implements Database.Batchable<sObject> {
    global string query = 'SELECT ID,ServiceTerritoryId,ServiceResourceId,EffectiveStartDate,EffectiveEndDate,ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember Where ServiceResource.IsActive=TRUE AND ServiceTerritory.IsActive=TRUE AND TerritoryType!=\'R\'';
    final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';

    // Run the query
    global Database.QueryLocator start(Database.BatchableContext BC) {
        // Get the Days to Create
        SFS_AB_Capacity_Settings__mdt appConfig = [SELECT Id, Configuration_Name__c, Configuration_Value__c FROM SFS_AB_Capacity_Settings__mdt WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY];
        Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
        Date lastDate = System.Today().addDays(daysToBuild);

        return Database.getQueryLocator(query + ' AND EffectiveStartDate <=:lastDate AND (EffectiveEndDate > :lastDate OR EffectiveEndDate = NULL)');
    }

    // Execute
    global void execute(Database.BatchableContext BC, List<ServiceTerritoryMember> stmList) {
        // Vars
        List<Resource_Capacity__c> rcList = new List<Resource_Capacity__c>();
        List<Capacity_Rebuild_Job__c> jobList = new List<Capacity_Rebuild_Job__c>();
        Set<String> existingCapKeys = new Set<String>();
        Set<Id> serviceResourceIdSet = new Set<ID>();
        Set<Id> serviceTerritoryIdSet = new Set<ID>();
        Set<ID> territoryIdModifiedSet = new Set<ID>();
        Map<Id, rebuildJobData> territoryIdToRebuildJobDataMap = new Map<Id, rebuildJobData>();

        // Create ResourceCapacity records based on Existing Active Resources and the Max days to create
        try {
            // Get the Days to Create
            SFS_AB_Capacity_Settings__mdt appConfig = [
                SELECT Id, Configuration_Name__c, Configuration_Value__c
                FROM SFS_AB_Capacity_Settings__mdt
                WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
            ];
            Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
            Date lastDate = System.Today().addDays(daysToBuild);

            // Get some vars to filters
            for (ServiceTerritoryMember stm : stmList) {
                serviceTerritoryIdSet.add(stm.ServiceTerritoryId);
                serviceResourceIdSet.add(stm.ServiceResourceId);
            }

            // Get the current Service Resource to check for gaps and fill them and increment
            for (Resource_Capacity__c existingRC : [
                SELECT ID, External_Id__c
                FROM Resource_Capacity__c
                WHERE Service_Resource__c IN :serviceResourceIdSet AND Service_Territory__c IN :serviceTerritoryIdSet AND Capacity_Date__c <= :lastDate
            ]) {
                existingCapKeys.add(existingRC.External_Id__c);
            }

            // Loop through Capacity and Days -> Insert any days that are missing from now until the max days
            Date earliestDate = null;
            Date latestDate = null;
            Date stmStartDt;
            //Date stmEndDt;
            DateTime convertedSTMStartDt;
            for (ServiceTerritoryMember stm : stmList) {
                convertedSTMStartDt = SFS_ABUtil.convertDateTimeToTerritorysTZ(stm.ServiceTerritory.OperatingHours.TimeZone, stm.EffectiveStartDate);
                stmStartDt = convertedSTMStartDt.timeGMT() >= Time.newInstance(20, 0, 0, 0) ? convertedSTMStartDt.DateGMT().addDays(1) : convertedSTMStartDt.DateGMT();
                System.debug('stm.EffectiveStartDate>>' + stm.EffectiveStartDate + ' convertedSTMStartDt>>' + convertedSTMStartDt + ' stmStartDt>>' + stmStartDt);
                System.debug('stm.EffectiveEndDate: ' + stm.EffectiveEndDate);
                System.debug('lastDate: ' + lastDate);
                System.debug('daysToBuild: ' + daysToBuild);
                for (Integer x = 0; x < daysToBuild; x++) {
                    Resource_Capacity__c rc = new Resource_Capacity__c();
                    rc.Capacity_Date__c = System.Today().addDays(x);
                    if (rc.Capacity_Date__c < stmStartDt) {
                        continue;
                    }

                    rc.External_Id__c = stm.ServiceResourceId + '_' + stm.ServiceTerritoryId + '_' + rc.Capacity_Date__c.format();
                    rc.Service_Territory__c = stm.ServiceTerritoryId;
                    rc.Service_Resource__c = stm.ServiceResourceId;
                    if (!existingCapKeys.contains(rc.External_Id__c)) {
                        rcList.add(rc);
                        RebuildJobData rj = new RebuildJobData();
                        if (territoryIdToRebuildJobDataMap.get(rc.Service_Territory__c) != null) {
                            rj = territoryIdToRebuildJobDataMap.get(rc.Service_Territory__c);
                        }
                        if (rj.startDate == null || rj.startDate >= rc.Capacity_Date__c) {
                            rj.startDate = rc.Capacity_Date__c;
                        }
                        if (rj.endDate == null || rj.endDate <= rc.Capacity_Date__c) {
                            rj.endDate = rc.Capacity_Date__c;
                        }
                        territoryIdToRebuildJobDataMap.put(rc.Service_Territory__c, rj);
                    }
                }
            }

            // Create new Job records for the Territories to Rebuild for the specific dates
            for (Id territoryId : territoryIdToRebuildJobDataMap.keySet()) {
                RebuildJobData rj = territoryIdToRebuildJobDataMap.get(territoryId);
                Capacity_Rebuild_Job__c rebuildJob = new Capacity_Rebuild_Job__c();
                rebuildJob.Service_Territory__c = territoryId;
                rebuildJob.End_Date__c = rj.endDate;
                rebuildJob.Start_Date__c = rj.startDate;
                rebuildJob.Type__c = 'Resource Capacity Insert New Day';
                jobList.add(rebuildJob);
            }

            if (!rcList.isEmpty()) {
                insert rcList;
            }

            if (!jobList.isEmpty()) {
                insert jobList;
            }

            System.debug('Heapsize used>' + system.Limits.getHeapSize());
            System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        } catch (Exception e) {
            System.debug('Exception: ' + e);
        }
    }

    // Call the Rule Batch to build the next days rule records associated to the daily rules
    global void finish(Database.BatchableContext BC) {
    }

    global class rebuildJobData {
        public Date startDate;
        public Date endDate;
    }
}