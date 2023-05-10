/**
 * @description       :
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 05-03-2023
 * @last modified by  : Ashish Yadav
 * Modifications Log
 * Ver   Date         Author                               Modification
 * 1.0   05-03-2023   Ashish Yadav   Initial Version
 **/
global class SFS_ABRelocatingResourceCapacityBatch implements Database.Batchable<sObject>, Database.Stateful {
    private SFS_AB_Capacity_Settings__mdt endBatchDays;
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> relocationSTMidToRebuildDateMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryIdToRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    //public Set<Id> territoryIdToRebuildSet;
    //public Set<Id> OrganizationIdSet;
    public Date startMinDate;
    public Date endMaxDate;
    public Boolean territorySizeFlagforCC = false;

    public SFS_ABRelocatingResourceCapacityBatch(
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> relocationSTMWithDateMap,
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryMap,
        Boolean territorySizeFlag
    ) {
        relocationSTMidToRebuildDateMap = relocationSTMWithDateMap;
        territoryIdToRebuildMap = territoryMap;
        //OrganizationIdSet = orgIdSet;
        territorySizeFlagforCC = territorySizeFlag;
        system.debug(relocationSTMidToRebuildDateMap + ' <<<SFS_ABRelocatingResourceCapacityBatch check>>> ' + territoryIdToRebuildMap);
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        String rolationString = 'R';
        String query;
        Set<Id> stmIdSet;

        system.debug(relocationSTMidToRebuildDateMap + ' <<<SFS_ABRelocatingResourceCapacityBatch start>>> ' + territoryIdToRebuildMap);
        if (relocationSTMidToRebuildDateMap != null && relocationSTMidToRebuildDateMap.size() > 0) {
            minMaxdateCalculation(relocationSTMidToRebuildDateMap);
            System.debug('startMinDate' + startMinDate);
            System.debug('endMaxDate' + endMaxDate);
            stmIdSet = relocationSTMidToRebuildDateMap.keyset();
            query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType,ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember WHERE Id IN: stmIdSet ORDER BY ServiceResourceId';
        } 
        else {
            endBatchDays = SFS_ABResourceCapacityTimeSlotUtil.getCustomMetadata();
            Integer enddays = Integer.valueOf(endBatchDays.Configuration_Value__c);
            //Start of 187041 fix
            //query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType FROM ServiceTerritoryMember WHERE EffectiveStartDate <= TODAY AND (EffectiveEndDate > LAST_N_DAYS:'+endDays+'OR EffectiveEndDate = NULL) AND TerritoryType =:rolationString AND ServiceTerritory.IsActive = TRUE AND ServiceResource.IsActive = TRUE ORDER BY ServiceResourceId';
            //query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType FROM ServiceTerritoryMember WHERE EffectiveEndDate >= TODAY AND TerritoryType =:rolationString AND ServiceTerritory.IsActive = TRUE AND ServiceResource.IsActive = TRUE ORDER BY ServiceResourceId';
            query = 'SELECT EffectiveEndDate,EffectiveStartDate,Id,ServiceResourceId,ServiceResource.FSL__Efficiency__c,OperatingHoursId,ServiceTerritoryId,ServiceTerritory.OperatingHoursId,TerritoryType,ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember WHERE createddate > TOMORROW';
            //End of 187041 fix
        }
        system.debug('query>>> ' + query);
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<ServiceTerritoryMember> stmList) {
        //checking the list and adding value in srIdSet based on ServiceResourceId
        if (stmList != null && stmList.size() > 0) {
            try {
                SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                    stmList,
                    startMinDate,
                    endMaxDate,
                    relocationSTMidToRebuildDateMap
                );
                system.debug('rsWrapper>>' + rsWrapper);

                if (rsWrapper != null && rsWrapper.resourceCapacityForDelete != null && rsWrapper.resourceCapacityForDelete.size() > 0) {
                    delete rsWrapper.resourceCapacityFordelete;
                }

                if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                    insert rsWrapper.resourceCapacityForInsert;
                }
                if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                    update rsWrapper.resourceCapacityForUpdate;
                }
            } catch (Exception e) {
                system.debug('Exception======' + e.getStackTraceString());
            }
        } //Ending stmList outter if condition
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
    }

    global void finish(Database.BatchableContext BC) {
        system.debug('territorySizeFlagforCC======' + territorySizeFlagforCC);
        system.debug('territoryIdToRebuildMap======' + territoryIdToRebuildMap);
        SFS_ABRebuildConsumedCapacityBatch comsumedCapacityBtach = new SFS_ABRebuildConsumedCapacityBatch(territoryIdToRebuildMap, territorySizeFlagforCC);
        Database.executeBatch(comsumedCapacityBtach, 50);
    }

    public void minMaxdateCalculation(Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmWithDateMap) {
        for (SFS_ABCapacityRebuildJobBatch.rebuildDate rebuildDateRecord : stmWithDateMap.values()) {
            startMinDate = startMinDate == null ? rebuildDateRecord.startDate : rebuildDateRecord.startDate < startMinDate ? rebuildDateRecord.startDate : startMinDate;
            endMaxDate = endMaxDate == null ? rebuildDateRecord.endDate : rebuildDateRecord.endDate > endMaxDate ? rebuildDateRecord.endDate : endMaxDate;
        }
    }
}