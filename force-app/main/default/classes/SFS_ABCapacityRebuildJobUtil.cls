/**
 * @description       : To Capacity Rebuild Job data for any change related to Resource and Territory
 * @author            : Salesforce Services
 * @group             :
 * @last modified on  : 06-14-2021
 * Modifications Log
 * Ver   Date         Author                    Modification
 * 1.0   05-08-2021   Salesforce Services       Initial Version
 **/

public class SFS_ABCapacityRebuildJobUtil {
    final static string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    // Calculate default last date
    static SFS_AB_Capacity_Settings__mdt appConfig = [
        SELECT Id, Configuration_Name__c, Configuration_Value__c
        FROM SFS_AB_Capacity_Settings__mdt
        WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
    ];
    static Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
    static Date maxDate = System.Today().addDays(daysToBuild);

    //static method to create a single Capacity rebuild Job record
    public static Capacity_Rebuild_Job__c createCapacityRebuildJobRecord(String type, Id serviceResourceId, Id serviceTerritoryId, Date startDate, Date endDate) {
        Capacity_Rebuild_Job__c capacityRebuildJobRecord = new Capacity_Rebuild_Job__c();
        capacityRebuildJobRecord.Type__c = type;
        if (String.isNotBlank(serviceResourceId)) {
            capacityRebuildJobRecord.Service_Resource__c = serviceResourceId;
        }
        if (String.isNotBlank(serviceTerritoryId)) {
            capacityRebuildJobRecord.Service_Territory__c = serviceTerritoryId;
        }
        if (startDate != null) {
            capacityRebuildJobRecord.Start_Date__c = startDate;
        }
        if (endDate != null) {
            capacityRebuildJobRecord.End_Date__c = endDate;
        }

        return capacityRebuildJobRecord;
    }

    //Get STM records for a Service Resource ids and/or Service Territory Ids
    public static List<ServiceTerritoryMember> getSTMListById(Set<Id> serviceResourceIdSet, Set<Id> serviceterritoryIdSet) {
        System.debug('getSTMListById.serviceResourceIdSet>>' + serviceResourceIdSet);
        System.debug('getSTMListById.serviceterritoryIdSet>>' + serviceterritoryIdSet);

        List<ServiceTerritoryMember> stmList = new List<ServiceTerritoryMember>();

        if (serviceResourceIdSet != null && serviceterritoryIdSet == null) {
            System.debug('getSTMListById 1>');
            stmList = [
                SELECT
                    Id,
                    ServiceResourceId,
                    ServiceTerritoryId,
                    TerritoryType,
                    ServiceResource.FSL__Efficiency__c,
                    OperatingHoursId,
                    EffectiveStartDate,
                    EffectiveEndDate,
                    ServiceTerritory.OperatingHoursId,
                    ServiceTerritory.OperatingHours.TimeZone
                FROM ServiceTerritoryMember
                WHERE ServiceResourceId IN :serviceResourceIdSet AND EffectiveStartDate <= :maxDate AND (EffectiveEndDate >= TODAY OR EffectiveEndDate = NULL)
                ORDER BY ServiceResourceId
            ];
            return stmList;
        } else if (serviceResourceIdSet == null && serviceterritoryIdSet != null) {
            System.debug('getSTMListById 2>');

            stmList = [
                SELECT
                    Id,
                    ServiceResourceId,
                    ServiceTerritoryId,
                    TerritoryType,
                    EffectiveStartDate,
                    EffectiveEndDate,
                    ServiceResource.FSL__Efficiency__c,
                    OperatingHoursId,
                    ServiceTerritory.OperatingHoursId,
                    ServiceTerritory.OperatingHours.TimeZone
                FROM ServiceTerritoryMember
                WHERE ServiceTerritoryId IN :serviceterritoryIdSet AND EffectiveStartDate <= :maxDate AND (EffectiveEndDate >= TODAY OR EffectiveEndDate = NULL)
                ORDER BY ServiceResourceId
            ];
            return stmList;
        } else if (serviceResourceIdSet != null && serviceterritoryIdSet != null) {
            System.debug('getSTMListById 3>');

            stmList = [
                SELECT
                    Id,
                    ServiceResourceId,
                    ServiceTerritoryId,
                    TerritoryType,
                    EffectiveStartDate,
                    EffectiveEndDate,
                    ServiceResource.FSL__Efficiency__c,
                    OperatingHoursId,
                    ServiceTerritory.OperatingHoursId,
                    ServiceTerritory.OperatingHours.TimeZone
                FROM ServiceTerritoryMember
                WHERE
                    ServiceTerritoryId IN :serviceterritoryIdSet
                    AND ServiceResourceId = :serviceResourceIdSet
                    AND EffectiveStartDate <= :maxDate
                    AND (EffectiveEndDate >= TODAY
                    OR EffectiveEndDate = NULL)
                ORDER BY ServiceResourceId
            ];
            return stmList;
        } else {
            return null;
        }
    }

    //Wrapper class to hold the data required for capacity calculation of the resource
    public class CreateCapacityRebuildDataMapWrapper {
        public Date minDate;
        public Date maxDate;
        public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> recordIdToDateMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    }

    //This method will create and return the createCapacityRebuildDataMapWrapper to process the capacity calculation for the Resource
    public static CreateCapacityRebuildDataMapWrapper getCapacityRebuildDataMap(Id recordId, Date startDate, Date EndDate) {
        createCapacityRebuildDataMapWrapper recordIdToDateMapWrapper = new createCapacityRebuildDataMapWrapper();
        if (startDate < System.TODAY()) {
            startDate = recordIdToDateMapWrapper.minDate = System.today();
        } else {
            recordIdToDateMapWrapper.minDate = startDate;
        }
        if (EndDate == null) {
            EndDate = recordIdToDateMapWrapper.maxDate = maxDate;
        } else if (startDate == EndDate) {
            EndDate = recordIdToDateMapWrapper.maxDate = startDate;
        } else {
            EndDate = recordIdToDateMapWrapper.maxDate = EndDate;
        }
        System.debug('recordIdToDateMapWrapper:' + recordIdToDateMapWrapper);
        recordIdToDateMapWrapper.recordIdToDateMap.put(recordId, new SFS_ABCapacityRebuildJobBatch.rebuildDate(startDate, endDate));
        return recordIdToDateMapWrapper;
    }

    //This method will return the Consumed Capacity list for the resource
    public static List<Consumed_Capacity__c> getConsumedCapacity(String territoryId, Date startDate, Date endDate) {
        System.debug('getConsumedCapacity>> ');
        System.debug('territoryId>> ' + territoryId);
        System.debug('startDate>> ' + startDate);
        System.debug('endDate>> ' + endDate);
        if (territoryId != null) {
            return [
                SELECT
                    Id,
                    Capacity_Date__c,
                    Active__c,
                    Field__c,
                    Capacity_Rule_Template__c,
                    External_Id__c,
                    IsOverridden__c,
                    Max__c,
                    Max_Rule__c,
                    Object__c,
                    Overall_Capacity__c,
                    Overall_Capacity_Rule__c,
                    Overall_Consumption__c,
                    Parent_Consumed_Capacity__c,
                    Release_X_Hours_Before__c,
                    Release_X_Hours_Before_Rule__c,
                    Parent_Consumed_Capacity__r.Overall_Capacity__c,
                    Rule_Consumption__c,
                    Service_Territory__c,
                    Type__c,
                    Value__c,
					Slots__c
                FROM Consumed_Capacity__c
                WHERE Service_Territory__c = :territoryId 
				AND Capacity_Date__c >= :startDate AND Capacity_Date__c <= :endDate
                ORDER BY Type__c
            ];
        } else {
            return null;
        }
    }
}