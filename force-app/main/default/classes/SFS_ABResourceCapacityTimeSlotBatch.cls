/**
 * @description       : To create 60 days resource capacity records based on STM and filters
 * @author            : Ashish Yadav 
 * @group             :
 * @last modified on  : 04-28-2023
 * Modifications Log
 * Ver   Date         Author                    Modification
 * 1.0   04-28-2023   Ashish Yadav      Initial Version
 **/
global class SFS_ABResourceCapacityTimeSlotBatch implements Database.Batchable<sObject>, Database.Stateful {
    private final String relocationString = 'R';
    private SFS_AB_Capacity_Settings__mdt endBatchDays;
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmIdToRebuildDateMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> relocationSTMidToRebuildDateMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryIdToRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    //public Set<Id> OrganizationIdSet;
    public Date startMinDate;
    public Date endMaxDate;
    public Boolean territorySizeFlagforCC = false;

    public SFS_ABResourceCapacityTimeSlotBatch(
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmWithDateMap,
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> relocationSTMWithDateMap,
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryMap,
        Boolean territorySizeFlag
    ) {
        stmIdToRebuildDateMap = stmWithDateMap;
        relocationSTMidToRebuildDateMap = relocationSTMWithDateMap;
        territoryIdToRebuildMap = territoryMap;
        //OrganizationIdSet = orgIdSet;
        territorySizeFlagforCC = territorySizeFlag;
        system.debug(relocationSTMidToRebuildDateMap + ' <<<consructor check>>> ' + stmIdToRebuildDateMap);
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query;
        Set<Id> stmIdSet;
        if (stmIdToRebuildDateMap != null && stmIdToRebuildDateMap.size() > 0) {
            minMaxdateCalculation(stmIdToRebuildDateMap);
            stmIdSet = stmIdToRebuildDateMap.keyset();
            system.debug('If stmIdSet>>> ' + stmIdSet);
            query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType,ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember WHERE Id IN: stmIdSet ORDER BY ServiceResourceId';
        }
        else {
            endBatchDays = SFS_ABResourceCapacityTimeSlotUtil.getCustomMetadata();
            Integer enddays = Integer.valueOf(endBatchDays.Configuration_Value__c);
            //query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType FROM ServiceTerritoryMember WHERE (EffectiveEndDate > LAST_N_DAYS:'+endDays+'OR EffectiveEndDate = NULL) AND TerritoryType !=:relocationString AND ServiceTerritory.IsActive = TRUE AND ServiceResource.IsActive = TRUE ORDER BY ServiceResourceId';
            query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType,ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember WHERE createddate > TOMORROW';
            system.debug('Else condition query>>> ' + query);
        }
        system.debug('query>>> ' + query);
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<ServiceTerritoryMember> stmList) {
        try {
            system.debug('stmList>>> ' + stmList);
            if (stmList != null && stmList.size() > 0) {
                system.debug(startMinDate + ' <<<Execute Method>>> ' + endMaxDate);
                SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                    stmList,
                    startMinDate,
                    endMaxDate,
                    stmIdToRebuildDateMap
                );
                if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                    insert rsWrapper.resourceCapacityForInsert;
                }
                if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                    update rsWrapper.resourceCapacityForUpdate;
                }
            } //Ending stmList if condition
            System.debug('Heapsize used>' + system.Limits.getHeapSize());
            System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        } catch (Exception e) {
            system.debug('Exception======' + e.getStackTraceString());
        }
    }

    global void finish(Database.BatchableContext BC) {
        system.debug('territorySizeFlagforCC======' + territorySizeFlagforCC);
        system.debug('territoryIdToRebuildMap======' + territoryIdToRebuildMap);
        SFS_ABRelocatingResourceCapacityBatch relocateBtach = new SFS_ABRelocatingResourceCapacityBatch(relocationSTMidToRebuildDateMap, territoryIdToRebuildMap, territorySizeFlagforCC);
        Database.executeBatch(relocateBtach, 100);
    }

    public void minMaxdateCalculation(Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmWithDateMap) {
        for (SFS_ABCapacityRebuildJobBatch.rebuildDate rebuildDateRecord : stmWithDateMap.values()) {
            startMinDate = startMinDate == null ? rebuildDateRecord.startDate : rebuildDateRecord.startDate < startMinDate ? rebuildDateRecord.startDate : startMinDate;
            endMaxDate = endMaxDate == null ? rebuildDateRecord.endDate : rebuildDateRecord.endDate > endMaxDate ? rebuildDateRecord.endDate : endMaxDate;
        }
    }
}