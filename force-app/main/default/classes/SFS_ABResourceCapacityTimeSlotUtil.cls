/**
 * @description       : To create 60 days resource capacity records based on STM and filters
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 04-15-2023
 * Modifications Log
 * Ver   Date         Author                    Modification
 * 1.0   04-15-2023  Ashish Yadav      Initial Version
 **/
public class SFS_ABResourceCapacityTimeSlotUtil {
    public static Set<Id> operatingHoursIdSet;
    public static final Time x8_TimeSlotTime = Time.newInstance(8, 0, 0, 0);
    public static final Time x12_TimeSlotTime = Time.newInstance(12, 0, 0, 0);
    public static final Time x16_TimeSlotTime = Time.newInstance(16, 0, 0, 0);
    public static final Time x2030_TimeSlotTime = Time.newInstance(20, 30, 0, 0);
    public static final Time x2230_TimeSlotTime = Time.newInstance(22, 30, 0, 0);
    public static final Decimal x240_Value = 240;
    public static Integer daysLimit;
    public static Integer daysToBuild;
    public static Set<Resource_Capacity__c> lstResourceCapacity = new Set<Resource_Capacity__c>();
    public static Map<String, TimeSlotWrapper> totalTravelTimeMap = new Map<String, TimeSlotWrapper>();
    public static final Set<String> statusSet = new Set<String>{ 'Completed', 'Canceled' };
    public static Date stmLocalStartDate;
    public static Date stmLocalEndDate;
    public static Date stmMinStartDate;
    public static Date stmMaxEndDate;
    public static Date defaultLastDate;

    //To create ResourceCapacityWrapper and return type is also ResourceCapacityWrapper
    //Getting operating hours based on SR's and operating hours set. Storing it in the map
    //Also storing existing Resource capacity data in the map for update
    //Retrieving time slots based on OH and performing functinalty for creating and updating Resource capacity data
    public static ResourceCapacityWrapper CalculateResourceCapacity(
        List<ServiceTerritoryMember> stmList,
        Date stmStartDate,
        Date stmEndDate,
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmIdToDateMap
    ) {
        system.debug('CalculateResourceCapacity stmStartDate>>> ' + stmStartDate);
        system.debug('CalculateResourceCapacity stmEndDate>>> ' + stmEndDate);
        Map<Id, Set<Id>> srWithOHIdsMap = new Map<Id, Set<Id>>();
        Map<String, Resource_Capacity__c> resourceCapacityMap = new Map<String, Resource_Capacity__c>();
        //Map<Id, Map<String, TimeSlotWrapper>> timeSlotwithOHMap = new Map<Id, Map<String, TimeSlotWrapper>>();
        ResourceCapacityWrapper rcWrapperRecord;
        //Map<Id, Map<Date, TimeSlotWrapper>> raWithTimeSlotMap = new Map<Id, Map<Date, TimeSlotWrapper>>();
        SFS_AB_Capacity_Settings__mdt metadataRecord = getCustomMetadata();
        daysToBuild = Integer.valueOf(metadataRecord.Configuration_Value__c);
        defaultLastDate = System.Today().addDays(daysToBuild);

        if (stmStartDate != null && stmEndDate != null) {
            stmMinStartDate = stmStartDate;
            stmMaxEndDate = stmEndDate;
            daysLimit = stmStartDate.daysBetween(stmEndDate);
            system.debug('If daysLimit>>> ' + daysLimit);
        } else {
            daysLimit = Integer.valueOf(metadataRecord.Configuration_Value__c);
        }
        if (stmList != null && stmList.size() > 0) {
            srWithOHIdsMap = getOperatingHoursWithSR(stmList);
        } else {
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
                WHERE Id IN :stmIdToDateMap.keySet()
            ];
            srWithOHIdsMap = getOperatingHoursWithSR(stmList);
        }
        //calling method to get Map<SR,List<OH>
        system.debug('srWithOHIdsMap>>> ' + srWithOHIdsMap);
        if (srWithOHIdsMap != null && srWithOHIdsMap.size() > 0) {
            resourceCapacityMap = getResourceCapacity(srWithOHIdsMap.keySet()); //getting Resource capacity data
        }

        Map<String, TimeSlotWrapper> shiftTimeSlotMap = new Map<String, TimeSlotWrapper>();
        List<ResourceAbsence> resourceAbsenceList = new List<ResourceAbsence>();
        Map<String, TimeSlotWrapper> assignedResourceMap = new Map<String, TimeSlotWrapper>();
        Map<String, Map<Date, TimeSlotWrapper>> getRAWithTimeSLotMAp = new Map<String, Map<Date, TimeSlotWrapper>>();

        if (srWithOHIdsMap != null && srWithOHIdsMap.size() > 0) {
            shiftTimeSlotMap = getShiftCalculation(srWithOHIdsMap.keySet(), srWithOHIdsMap);
            resourceAbsenceList = getResourceAbsence(srWithOHIdsMap.keySet());
            system.debug('resourceAbsenceList>>> ' + resourceAbsenceList);

            getRAWithTimeSLotMAp = getRAWithTimeSlot(resourceAbsenceList, srWithOHIdsMap);
            system.debug('getRAWithTimeSLotMAp>>> ' + getRAWithTimeSLotMAp);

            assignedResourceMap = assignedResourceTimeSlotCal(srWithOHIdsMap.keySet());
        }

        ParamWrapper paramRecord = new ParamWrapper();
        paramRecord.stmListParam = stmList;
        paramRecord.resourceCapacityMapParam = resourceCapacityMap;
        paramRecord.resourceAbsenceMapParam = getRAWithTimeSLotMAp;
        paramRecord.shiftTimeSlotMapParam = shiftTimeSlotMap;
        paramRecord.assignedResourceMapParam = assignedResourceMap;
        paramRecord.stmIdWithDateMapParam = stmIdToDateMap;
        rcWrapperRecord = CalculateResourceWrapper(paramRecord);
        system.debug(resourceCapacityMap.size() + '  <<resourceCapacityMap>>> ' + resourceCapacityMap);
        system.debug('rcWrapperRecord>>> ' + rcWrapperRecord);
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        return rcWrapperRecord;
    }

    //To Get Operating Hours Based on SR's Id. Retrun type is map<ServiceResourceID, Set<OHID>>
    // if Map does not contain key and OperatingHoursId is not null,then adding operating hours form STM
    // If Map does not contain key and OperatingHoursId is null,then adding operating hours form territory
    //if map have key already, adding value based on OperatingHoursId hours above check
    public static Map<Id, Set<Id>> getOperatingHoursWithSR(List<ServiceTerritoryMember> stmList) {
        Map<Id, Set<Id>> srOHIdsMap = new Map<Id, Set<Id>>();

        for (ServiceTerritoryMember stmRecord : stmList) {
            if (!srOHIdsMap.containskey(stmRecord.ServiceResourceId)) {
                srOHIdsMap.put(stmRecord.ServiceResourceId, new Set<Id>());
            }
            srOHIdsMap.get(stmRecord.ServiceResourceId).add(stmRecord.OperatingHoursId != null ? stmRecord.OperatingHoursId : stmRecord.ServiceTerritory.OperatingHoursId);
        }
        system.debug('operatingHoursIdSet>> ' + operatingHoursIdSet);
        return srOHIdsMap;
    }

    //To Get ResourceCapacity__c based on ServiceResourceId
    public static Map<String, Resource_Capacity__c> getResourceCapacity(Set<Id> srIdsSet) {
        Map<String, Resource_Capacity__c> existingResourceCapacityMap = new Map<String, Resource_Capacity__c>();

        if (srIdsSet != null && srIdsSet.size() > 0) {
            for (Resource_Capacity__c rcRecord : [SELECT Capacity_Date__c, Assigned_Appointment_Minutes__c, External_Id__c, Id, Service_Resource__c, Service_Territory__c, Availability_Before_Consumption__c, Capacity__c, Total_Break_Duration__c, Total_Absence_Duration__c, Total_Travel_Time__c
                                                    FROM Resource_Capacity__c
                                                    WHERE Service_Resource__c = :srIdsSet AND Capacity_Date__c >= TODAY
                                                    ORDER BY External_Id__c]) {

                existingResourceCapacityMap.put(rcRecord.External_Id__c, rcRecord);
                lstResourceCapacity.add(rcRecord);
            }
        }
        system.debug('existingResourceCapacityMap>> ' + existingResourceCapacityMap);
        return existingResourceCapacityMap;
    }

    //To create ResourceCapacityWrapper data for insert and update.
    //public static ResourceCapacityWrapper CalculateResourceWrapper(List<ServiceTerritoryMember> stmList,Map<Id,Map<String,TimeSlotWrapper>> ohWithTimeSlotWrapperMap,Map<String,ResourceCapacity__c> resourceCapacityMap, Map<Id,Map<Date,TimeSlotWrapper>> resourceAbsenceMap,Map<String,TimeSlotWrapper> shiftTimeSlotMap,Map<String,TimeSlotWrapper>  assignedResourceMap,Map<Id,CapacityRebuildJobBatch.rebuildDate> stmIdWithDateMap){
    public static ResourceCapacityWrapper CalculateResourceWrapper(ParamWrapper paramWrapper) {
        //Variable assignment based on Wrapper class
        List<ServiceTerritoryMember> stmList = paramWrapper.stmListParam;
        Map<String, Resource_Capacity__c> resourceCapacityMap = paramWrapper.resourceCapacityMapParam;
        Map<String, Map<Date, TimeSlotWrapper>> resourceAbsenceMap = paramWrapper.resourceAbsenceMapParam;
        Map<String, TimeSlotWrapper> shiftTimeSlotMap = paramWrapper.shiftTimeSlotMapParam;
        Map<String, TimeSlotWrapper> assignedResourceMap = paramWrapper.assignedResourceMapParam;
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmIdWithDateMap = paramWrapper.stmIdWithDateMapParam;

        List<Resource_Capacity__c> resourceCapacityListForInsert = new List<Resource_Capacity__c>();
        List<Resource_Capacity__c> resourceCapacityListForUpdate = new List<Resource_Capacity__c>();
        List<Resource_Capacity__c> resourceCapacityListForDelete = new List<Resource_Capacity__c>();
        Map<Id, Resource_Capacity__c> resourceCapacityUpdateMap = new Map<Id, Resource_Capacity__c>();
        system.debug('stmIdWithDateMap in CalculateResourceWrapper>>> ' + stmIdWithDateMap);

        for (ServiceTerritoryMember stmRecord : stmList) {
            //creating startSTMDate and endSTMDate based on stm effectdata fields
            Date endSTMDate;
            Datetime convertedScheduledStartDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(stmRecord.ServiceTerritory.OperatingHours.TimeZone, stmRecord.EffectiveStartDate);
            Date startSTMDate = convertedScheduledStartDate.timeGMT() >= Time.newInstance(22, 30, 0, 0) ? convertedScheduledStartDate.DateGMT().addDays(1) : convertedScheduledStartDate.DateGMT();
            system.debug('startSTMDate ----- ' + startSTMDate);
            if (stmRecord.EffectiveEndDate != null) {
                Datetime convertedScheduledEndDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(stmRecord.ServiceTerritory.OperatingHours.TimeZone, stmRecord.EffectiveEndDate);
                endSTMDate = convertedScheduledEndDate.timeGMT() <= Time.newInstance(8, 0, 0, 0) ? convertedScheduledEndDate.DateGMT().addDays(-1) : convertedScheduledEndDate.DateGMT();
                system.debug('endSTMDate' + endSTMDate);
            }

            //to handle specific loop range for creation
            if (stmIdWithDateMap != null && stmIdWithDateMap.containsKey(stmRecord.Id)) {
                SFS_ABCapacityRebuildJobBatch.rebuildDate rebuildDateRecord = stmIdWithDateMap.get(stmRecord.Id);
                system.debug(rebuildDateRecord.startDate.format() + ' <<<rebuildDateRecord.startDate>>> ' + rebuildDateRecord.startDate);
                system.debug('rebuildDateRecord.startDate>>> ' + rebuildDateRecord.endDate);

                stmLocalStartDate = rebuildDateRecord.startDate;
                stmLocalEndDate = rebuildDateRecord.endDate.addDays(1);

                Date todayLocalDate = System.today();
                if (todayLocalDate >= stmLocalStartDate) {
                    daysLimit = todayLocalDate.daysBetween(stmLocalEndDate);
                } else {
                    daysLimit = stmLocalStartDate.daysBetween(stmLocalEndDate);
                }
                system.debug('daysLimit>>> ' + daysLimit);
                system.debug(endSTMDate + ' <<startSTMDate>>> ' + startSTMDate);
            }
            for (Integer i = 0; i < daysLimit; i++) {
                //storing today days and adding days based on inner loop
                system.debug('Loop Run >>>> ' + i);
                Date todayDate;

                if (stmLocalStartDate != null && stmLocalStartDate >= System.today()) {
                    todayDate = stmLocalStartDate.addDays(i);
                } else {
                    todayDate = System.today().addDays(i);
                }

                if (todayDate >= defaultLastDate) {
                    break;
                }
                String keyString = stmRecord.ServiceResourceId + '_' + stmRecord.ServiceTerritoryId + '_' + todayDate.format();
                Date localToday = Date.newinstance(todayDate.year(), todayDate.month(), todayDate.day());

                Decimal resourceCapacityFor8to12 = 0;
                Decimal resourceCapacityFor12to16 = 0;
                Decimal resourceCapacityFor16to2030 = 0;
                Decimal resourceCapacityFor2030to2230 = 0;
                Decimal assignedAppointmentFor8to12 = 0;
                Decimal assignedAppointmentFor12to16 = 0;
                Decimal assignedAppointmentFor16to2030 = 0;
                Decimal assignedAppointmentFor2030to2230 = 0;
                Decimal assignedResourceCapacity = 0;
                Decimal totalCapacityBeforeConsumption = 0;
                Decimal capacityFromShifts = 0;
                Decimal totalBreakDuration = 0;
                Decimal totalAbsenceDuration = 0;
                Decimal totalPTODuration = 0;
                Decimal totalShrinkDuration = 0;
                Decimal totalTravelTime = 0;

                String shiftKeyString;
                if (stmRecord.OperatingHoursId != null) {
                    shiftKeyString = stmRecord.ServiceResourceId + '__' + todayDate.format() + '__' + stmRecord.OperatingHoursId + '__' + getDayOfWeek(todayDate);
                } else {
                    shiftKeyString = stmRecord.ServiceResourceId + '__' + todayDate.format() + '__' + stmRecord.ServiceTerritory.OperatingHoursId + '__' + getDayOfWeek(todayDate);
                }

                if (shiftTimeSlotMap != null && shiftTimeSlotMap.containsKey(shiftKeyString)) {
                    system.debug('shiftTimeSlotMap>>> ');
                    TimeSlotWrapper timeSlotWrapperRecord = shiftTimeSlotMap.get(shiftKeyString);
                    resourceCapacityFor8to12 = timeSlotWrapperRecord.X8_12_Slot_Minutes;
                    resourceCapacityFor12to16 = timeSlotWrapperRecord.X12_16_Slot_Minutes;
                    resourceCapacityFor16to2030 = timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                    resourceCapacityFor2030to2230 = timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                }
                capacityFromShifts = resourceCapacityFor8to12 + resourceCapacityFor12to16 + resourceCapacityFor16to2030 + resourceCapacityFor2030to2230;
                system.debug('resourceCapacityFor8to12>>> ' + resourceCapacityFor8to12);

                //calculation resource absence based on time slot and deduction the absence time from resourceCapacityFor8to12,resourceCapacityFor12to16,resourceCapacityFor16to20 variables
                String breakResourceAbsenceKey = stmRecord.ServiceResourceId + '__' + 'Break';
                String nonAvailResourceAbsencePTOKey = stmRecord.ServiceResourceId + '__' + 'Non_Availability' + '__' + 'PTO';
                String nonAvailResourceAbsenceNonPTOKey = stmRecord.ServiceResourceId + '__' + 'Non_Availability' + '__' + 'nonPTO';
                if (resourceAbsenceMap != null && resourceAbsenceMap.containsKey(breakResourceAbsenceKey)) {
                    if (resourceAbsenceMap.get(breakResourceAbsenceKey).containsKey(localToday)) {
                        system.debug('resourceAbsenceMap>>> ' + resourceAbsenceMap);
                        TimeSlotWrapper timeSlotWrapperRecord = resourceAbsenceMap.get(breakResourceAbsenceKey).get(localToday);
                        resourceCapacityFor8to12 = resourceCapacityFor8to12 - timeSlotWrapperRecord.X8_12_Slot_Minutes;
                        resourceCapacityFor12to16 = resourceCapacityFor12to16 - timeSlotWrapperRecord.X12_16_Slot_Minutes;
                        resourceCapacityFor16to2030 = resourceCapacityFor16to2030 - timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                        resourceCapacityFor2030to2230 = resourceCapacityFor2030to2230 - timeSlotWrapperRecord.X2030_2230_Slot_Minutes;

                        totalBreakDuration = timeSlotWrapperRecord.X8_12_Slot_Minutes + timeSlotWrapperRecord.X12_16_Slot_Minutes + timeSlotWrapperRecord.X16_2030_Slot_Minutes + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    }
                }
                if (resourceAbsenceMap != null && resourceAbsenceMap.containsKey(nonAvailResourceAbsencePTOKey)) {
                    if (resourceAbsenceMap.get(nonAvailResourceAbsencePTOKey).containsKey(localToday)) {
                        system.debug('resourceAbsenceMap>>> ' + resourceAbsenceMap);
                        TimeSlotWrapper timeSlotWrapperRecord = resourceAbsenceMap.get(nonAvailResourceAbsencePTOKey).get(localToday);
                        resourceCapacityFor8to12 = resourceCapacityFor8to12 - timeSlotWrapperRecord.X8_12_Slot_Minutes;
                        resourceCapacityFor12to16 = resourceCapacityFor12to16 - timeSlotWrapperRecord.X12_16_Slot_Minutes;
                        resourceCapacityFor16to2030 = resourceCapacityFor16to2030 - timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                        resourceCapacityFor2030to2230 = resourceCapacityFor2030to2230 - timeSlotWrapperRecord.X2030_2230_Slot_Minutes;

                        totalPTODuration = timeSlotWrapperRecord.X8_12_Slot_Minutes + timeSlotWrapperRecord.X12_16_Slot_Minutes + timeSlotWrapperRecord.X16_2030_Slot_Minutes + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    }
                }
                if (resourceAbsenceMap != null && resourceAbsenceMap.containsKey(nonAvailResourceAbsenceNonPTOKey)) {
                    if (resourceAbsenceMap.get(nonAvailResourceAbsenceNonPTOKey).containsKey(localToday)) {
                        system.debug('resourceAbsenceMap>>> ' + resourceAbsenceMap);
                        TimeSlotWrapper timeSlotWrapperRecord = resourceAbsenceMap.get(nonAvailResourceAbsenceNonPTOKey).get(localToday);
                        resourceCapacityFor8to12 = resourceCapacityFor8to12 - timeSlotWrapperRecord.X8_12_Slot_Minutes;
                        resourceCapacityFor12to16 = resourceCapacityFor12to16 - timeSlotWrapperRecord.X12_16_Slot_Minutes;
                        resourceCapacityFor16to2030 = resourceCapacityFor16to2030 - timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                        resourceCapacityFor2030to2230 = resourceCapacityFor2030to2230 - timeSlotWrapperRecord.X2030_2230_Slot_Minutes;

                        totalShrinkDuration = timeSlotWrapperRecord.X8_12_Slot_Minutes + timeSlotWrapperRecord.X12_16_Slot_Minutes + timeSlotWrapperRecord.X16_2030_Slot_Minutes + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    }
                }

                if (resourceCapacityFor8to12 < 0) {
                    resourceCapacityFor8to12 = 0;
                }

                if (resourceCapacityFor12to16 < 0) {
                    resourceCapacityFor12to16 = 0;
                }

                if (resourceCapacityFor16to2030 < 0) {
                    resourceCapacityFor16to2030 = 0;
                }

                if (resourceCapacityFor2030to2230 < 0) {
                    resourceCapacityFor2030to2230 = 0;
                }

                totalAbsenceDuration = totalPTODuration + totalShrinkDuration;
                totalCapacityBeforeConsumption = resourceCapacityFor8to12 + resourceCapacityFor12to16 + resourceCapacityFor16to2030 + resourceCapacityFor2030to2230;
                //calculation for AssignedResource based on time slot and deduction the time from resourceCapacityFor8to12,resourceCapacityFor12to16,resourceCapacityFor16to20, resourceCapacityFor2030to2230 variables
                String assignedResourceKey = stmRecord.ServiceResourceId + '__' + todayDate.format(); // + '__' + stmRecord.ServiceTerritoryId; // DWA Changed the Key to include all ARs regarless of Territory
                if (assignedResourceMap != null && assignedResourceMap.containsKey(assignedResourceKey)) {
                    TimeSlotWrapper timeSlotWrapperRecord = assignedResourceMap.get(assignedResourceKey);
                    system.debug('assignedResourceMap>>> ');
                    assignedAppointmentFor8to12 = timeSlotWrapperRecord.X8_12_Slot_Minutes;
                    assignedAppointmentFor12to16 = timeSlotWrapperRecord.X12_16_Slot_Minutes;
                    assignedAppointmentFor16to2030 = timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                    assignedAppointmentFor2030to2230 = timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    assignedResourceCapacity = timeSlotWrapperRecord.X8_12_Slot_Minutes + timeSlotWrapperRecord.X12_16_Slot_Minutes + timeSlotWrapperRecord.X16_2030_Slot_Minutes + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                }

                //Ashish Calculate the total Travel time
                if (totalTravelTimeMap != null && totalTravelTimeMap.containsKey(assignedResourceKey)) {
                    system.debug('totalTravelTimeMap>>> ' + totalTravelTimeMap);
                    TimeSlotWrapper timeSlotWrapperRecord = totalTravelTimeMap.get(assignedResourceKey);
                    assignedAppointmentFor8to12 = assignedAppointmentFor8to12 + timeSlotWrapperRecord.X8_12_Slot_Minutes;
                    assignedAppointmentFor12to16 = assignedAppointmentFor12to16 + timeSlotWrapperRecord.X12_16_Slot_Minutes;
                    assignedAppointmentFor16to2030 = assignedAppointmentFor16to2030 + timeSlotWrapperRecord.X16_2030_Slot_Minutes;
                    assignedAppointmentFor2030to2230 = assignedAppointmentFor2030to2230 + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    totalTravelTime = timeSlotWrapperRecord.X8_12_Slot_Minutes + timeSlotWrapperRecord.X12_16_Slot_Minutes + timeSlotWrapperRecord.X16_2030_Slot_Minutes + timeSlotWrapperRecord.X2030_2230_Slot_Minutes;
                    //assignedResourceCapacity = assignedResourceCapacity + totalTravelTime;
                }

                //Preparing ResourceCapacityRecordParam wrapper for resource capacity insertion or updation with common values
                ResourceCapacityRecordParam rcRecordParam = new ResourceCapacityRecordParam();
                rcRecordParam.x8to12ValParam = resourceCapacityFor8to12;
                rcRecordParam.x12to16ValParam = resourceCapacityFor12to16;
                rcRecordParam.x16to2030ValParam = resourceCapacityFor16to2030;
                rcRecordParam.x2030to2230ValParam = resourceCapacityFor2030to2230;
                rcRecordParam.x8to12ValParamAssign = assignedAppointmentFor8to12;
                rcRecordParam.x12to16ValParamAssign = assignedAppointmentFor12to16;
                rcRecordParam.x16to2030ValParamAssign = assignedAppointmentFor16to2030;
                rcRecordParam.x2030to2230ValParamAssign = assignedAppointmentFor2030to2230;
                rcRecordParam.assignedAppointmentMinutes = assignedResourceCapacity;
                rcRecordParam.capactiyBeforeConsumptionParam = totalCapacityBeforeConsumption;
                rcRecordParam.capacityFromShifts = capacityFromShifts;
                rcRecordParam.totalBreakDuration = totalBreakDuration;
                rcRecordParam.totalAbsenceDuration = totalAbsenceDuration;
                rcRecordParam.totalPTODuration = totalPTODuration;
                rcRecordParam.totalShrinkDuration = totalShrinkDuration;
                rcRecordParam.totalTravelTime = totalTravelTime;

                if ((resourceCapacityMap != null && !resourceCapacityMap.containsKey(keyString)) || resourceCapacityMap == null) {

                    rcRecordParam.dtParam = todayDate;
                    rcRecordParam.serviceTerritoryIdParam = stmRecord.ServiceTerritoryId;
                    rcRecordParam.serviceResourceIdParam = stmRecord.ServiceResourceId;

                    if (stmRecord.EffectiveEndDate == null || (todayDate >= startSTMDate && todayDate <= endSTMDate)) {
                        Resource_Capacity__c rsRecord = resourceCapacityRecordCreation(rcRecordParam);
                        resourceCapacityListForInsert.add(rsRecord);
                        system.debug(todayDate + ' <<<if>>> ' + startSTMDate);
                    }
                } else if (resourceCapacityMap != null && resourceCapacityMap.containsKey(keyString)) {
                    //outter if ends here
                    if (todayDate > endSTMDate) {
                        break;
                    } else if (todayDate >= startSTMDate) {
                        //if map contains key, no need to create but checking for update
                        Resource_Capacity__c rsExisitingRecord = resourceCapacityMap.get(keyString);
                        //system.debug(resourceCapacityFor8to12 + ' <<<<rsExisitingRecord>>> ' + rsExisitingRecord.X8_12_Slot_Minutes__c);

                        //AW remove timelot
                        //if (rsExisitingRecord.X8_12_Slot_Minutes__c != resourceCapacityFor8to12 || rsExisitingRecord.X12_16_Slot_Minutes__c != resourceCapacityFor12to16 || rsExisitingRecord.X16_2030_Slot_Minutes__c != resourceCapacityFor16to20 || assignedResourceCapacity != rsExisitingRecord.Assigned_Appointment_Minutes__c) {
                        if ((assignedResourceCapacity != rsExisitingRecord.Assigned_Appointment_Minutes__c)
                            ||(totalCapacityBeforeConsumption != rsExisitingRecord.Availability_Before_Consumption__c)
                            ||(capacityFromShifts != rsExisitingRecord.Capacity__c)
                            ||(totalBreakDuration != rsExisitingRecord.Total_Break_Duration__c)
                            ||(totalAbsenceDuration != rsExisitingRecord.Total_Absence_Duration__c)
                            ||(totalTravelTime != rsExisitingRecord.Total_Travel_Time__c)) {

                            rcRecordParam.dtParam = todayDate;
                            rcRecordParam.startSTMDateParam = startSTMDate;
                            rcRecordParam.endSTMDateParam = endSTMDate;
                            rcRecordParam.stmRecordParam = stmRecord;
                            rcRecordParam.rsRecordParam = rsExisitingRecord;
                            rsExisitingRecord = resourceCapacityRecordUpdate(rcRecordParam);
                            resourceCapacityUpdateMap.put(rsExisitingRecord.Id, rsExisitingRecord);
                        }
                    }
                }
            } //inner loop ends here
        } //outter loop ends here

        //Get Resource Capacity delete list
        resourceCapacityListForDelete = getResourceCapacityDeleteList(stmList, false, null);

        system.debug('resourceCapacityListForInsert>>> ' + resourceCapacityListForInsert);
        resourceCapacityListForUpdate = new List<Resource_Capacity__c>(resourceCapacityUpdateMap.values());
        system.debug(resourceCapacityListForUpdate.size() + '    >resourceCapacityListForUpdate>>>>>>>>> ' + resourceCapacityListForUpdate);
        ResourceCapacityWrapper resourceWrapper = new ResourceCapacityWrapper(resourceCapacityListForInsert, resourceCapacityListForUpdate, resourceCapacityListForDelete);
        resourceCapacityListForUpdate = new List<Resource_Capacity__c>();
        resourceCapacityUpdateMap = new Map<Id, Resource_Capacity__c>();
        return resourceWrapper;
    }

    // This method returns the Resource Capacity List to be deleted based on the STM list provided in the parameters.
    // If DeleteAll is true it will delete all the ST passed n the STM based on conditional check
    // Else it will skip those territories if matched with Capacity resources ST data
    //public static List<ResourceCapacity__c> getResourceCapacityDeleteList(List<ServiceTerritoryMember> stmList, Boolean deleteAll){
    public static List<Resource_Capacity__c> getResourceCapacityDeleteList(List<ServiceTerritoryMember> stmList, Boolean deleteAll, Map<Id, ServiceTerritory> territoryTimeZoneMap) {
        List<Resource_Capacity__c> resourceCapacityListForDelete = new List<Resource_Capacity__c>();
        Set<Id> srIdSet = new Set<Id>();
        Map<String, Resource_Capacity__c> existingResourceCapacityMap = new Map<String, Resource_Capacity__c>();
        System.debug('lstResourceCapacity delete case '+lstResourceCapacity);
        //Check if the Resource Capacity for the resources are there else call the method to get it
        if (lstResourceCapacity == null || lstResourceCapacity.size() == 0) {
            System.debug('Get ResourceCapacitylist');
            for (ServiceTerritoryMember stm : stmList) {
                srIdSet.add(stm.ServiceResourceId);
            }
        }
        existingResourceCapacityMap = getResourceCapacity(srIdSet);

        //Create Resource Capacity delete list
        if (lstResourceCapacity != null && lstResourceCapacity.size() > 0) {
            //Add the Resource capacity in the list to be deletd if there are any Resource capacity for the resources compare
            // if it is for the same SR and ST combination as of STM record
            for (ServiceTerritoryMember stmRecord : stmList) {
                String territoryTZ = territoryTimeZoneMap != null && territoryTimeZoneMap.containsKey(stmRecord.ServiceTerritoryId)
                    ? territoryTimeZoneMap.get(stmRecord.serviceTerritoryId).OperatingHours.TimeZone
                    : stmRecord.ServiceTerritory.OperatingHours.TimeZone;
                system.debug('territoryTZ' + territoryTZ);
                Datetime convertedScheduledStartDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(territoryTZ, stmRecord.EffectiveStartDate);
                Date startSTMDate = convertedScheduledStartDate.timeGMT() >= Time.newInstance(22, 30, 0, 0) ? convertedScheduledStartDate.DateGMT().addDays(1) : convertedScheduledStartDate.DateGMT();
                Datetime convertedScheduledEndDate;
                Date endSTMDate;
                if (stmRecord.EffectiveEndDate != null) {
                    convertedScheduledEndDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(territoryTZ, stmRecord.EffectiveEndDate);
                    endSTMDate = convertedScheduledEndDate.timeGMT() <= Time.newInstance(8, 0, 0, 0) ? convertedScheduledEndDate.DateGMT().addDays(-1) : convertedScheduledEndDate.DateGMT();
                    system.debug('endSTMDate' + endSTMDate);
                }
                for (Resource_Capacity__c resCap : lstResourceCapacity) {
                    if (
                        stmRecord.EffectiveEndDate != null &&
                        stmRecord.ServiceResourceId == resCap.Service_Resource__c &&
                        ((deleteAll && stmRecord.ServiceTerritoryId == resCap.Service_Territory__c) || (!deleteAll && stmRecord.ServiceTerritoryId != resCap.Service_Territory__c)) &&
                        resCap.Capacity_Date__c >= startSTMDate &&
                        resCap.Capacity_Date__c <= endSTMDate
                    ) {
                        resourceCapacityListForDelete.add(resCap);
                    } else if (
                        stmRecord.EffectiveEndDate == null &&
                        stmRecord.ServiceResourceId == resCap.Service_Resource__c &&
                        ((deleteAll && stmRecord.ServiceTerritoryId == resCap.Service_Territory__c) || (!deleteAll && stmRecord.ServiceTerritoryId != resCap.Service_Territory__c)) &&
                        resCap.Capacity_Date__c >= startSTMDate
                    ) {
                        resourceCapacityListForDelete.add(resCap);
                    }
                }
            }
        }
        return resourceCapacityListForDelete;
    }

    //To get Day of Week from Date
    public static String getDayOfWeek(Date dt) {
        DateTime myDateTime = (DateTime) dt.addDays(1);
        String dayOfWeek = myDateTime.format('EEEE');
        return dayOfWeek;
    }

    // To Update ResourceCapacity__c record based on parameters
    public static Resource_Capacity__c resourceCapacityRecordUpdate(ResourceCapacityRecordParam rcRecordParam) {
        Date todayDate = rcRecordParam.dtParam;
        Date startSTMDate = rcRecordParam.startSTMDateParam;
        Date endSTMDate = rcRecordParam.endSTMDateParam;
        ServiceTerritoryMember stmRecord = rcRecordParam.stmRecordParam;
        Resource_Capacity__c rsRecord = rcRecordParam.rsRecordParam;

        if (stmRecord.EffectiveEndDate == null || (todayDate >= startSTMDate && todayDate <= endSTMDate)) {
            rsRecord.Slot_08_12_Avail_Minutes__c = rcRecordParam.x8to12ValParam;
            rsRecord.Slot_12_16_Avail_Minutes__c = rcRecordParam.x12to16ValParam;
            rsRecord.Slot_16_2030_Avail_Minutes__c = rcRecordParam.x16to2030ValParam;
            rsRecord.Slot_2030_2230_Avail_Minutes__c = rcRecordParam.x2030to2230ValParam;
            rsRecord.Slot_08_12_Assigned_Minutes__c = rcRecordParam.x8to12ValParamAssign;
            rsRecord.Slot_12_16_Assigned_Minutes__c = rcRecordParam.x12to16ValParamAssign;
            rsRecord.Slot_16_2030_Assigned_Minutes__c = rcRecordParam.x16to2030ValParamAssign;
            rsRecord.Slot_2030_2230_Assigned_Minutes__c = rcRecordParam.x2030to2230ValParamAssign;
            rsRecord.Assigned_Appointment_Minutes__c = rcRecordParam.assignedAppointmentMinutes;
            rsRecord.Availability_Before_Consumption__c = rcRecordParam.capactiyBeforeConsumptionParam;
            rsRecord.Capacity__c = rcRecordParam.capacityFromShifts;
            rsRecord.Total_Break_Duration__c = rcRecordParam.totalBreakDuration;
            rsRecord.Total_Absence_Duration__c = rcRecordParam.totalAbsenceDuration;
            rsRecord.Total_PTO_Duration__c = rcRecordParam.totalPTODuration;
            rsRecord.Total_Shrink_Duration__c = rcRecordParam.totalShrinkDuration;
            rsRecord.Total_Travel_Time__c = rcRecordParam.totalTravelTime;
        }
        system.debug('rsRecord>> ' + rsRecord);
        return rsRecord;
    }
    // To create ResourceCapacity__c record based on parameters
    public static Resource_Capacity__c resourceCapacityRecordCreation(ResourceCapacityRecordParam rcRecordParameter) {

        Resource_Capacity__c rcRecord = new Resource_Capacity__c();
        rcRecord.Service_Resource__c = rcRecordParameter.serviceResourceIdParam;
        rcRecord.Service_Territory__c = rcRecordParameter.serviceTerritoryIdParam;
        rcRecord.Capacity_Date__c = rcRecordParameter.dtParam;
        rcRecord.Slot_08_12_Avail_Minutes__c = rcRecordParameter.x8to12ValParam;
        rcRecord.Slot_12_16_Avail_Minutes__c = rcRecordParameter.x12to16ValParam;
        rcRecord.Slot_16_2030_Avail_Minutes__c = rcRecordParameter.x16to2030ValParam;
        rcRecord.Slot_2030_2230_Avail_Minutes__c = rcRecordParameter.x2030to2230ValParam;
        rcRecord.Slot_08_12_Assigned_Minutes__c = rcRecordParameter.x8to12ValParamAssign;
        rcRecord.Slot_12_16_Assigned_Minutes__c = rcRecordParameter.x12to16ValParamAssign;
        rcRecord.Slot_16_2030_Assigned_Minutes__c = rcRecordParameter.x16to2030ValParamAssign;
        rcRecord.Slot_2030_2230_Assigned_Minutes__c = rcRecordParameter.x2030to2230ValParamAssign;
        rcRecord.Assigned_Appointment_Minutes__c = rcRecordParameter.assignedAppointmentMinutes;
        rcRecord.Availability_Before_Consumption__c = rcRecordParameter.capactiyBeforeConsumptionParam;
        rcRecord.Capacity__c = rcRecordParameter.capacityFromShifts;
        rcRecord.Total_Break_Duration__c = rcRecordParameter.totalBreakDuration;
        rcRecord.Total_Absence_Duration__c = rcRecordParameter.totalAbsenceDuration;
        rcRecord.Total_PTO_Duration__c = rcRecordParameter.totalPTODuration;
        rcRecord.Total_Shrink_Duration__c = rcRecordParameter.totalShrinkDuration;
        rcRecord.Total_Travel_Time__c = rcRecordParameter.totalTravelTime;
        rcRecord.External_Id__c = rcRecordParameter.serviceResourceIdParam + '_' + rcRecordParameter.serviceTerritoryIdParam + '_' + rcRecordParameter.dtParam.format();
        return rcRecord;
    }

    //To Get Diff of Start and End Time for single Date
    public static Decimal getMinutesFormTime(Time startTime, Time endTime) {
        if (startTime == null || endTime == null) {
            return 0;
        }
        DateTime startTimeVal = DateTime.newInstance(Date.today(), startTime);
        DateTime endTimeVal = datetime.newinstance(Date.today(), endTime);
        Decimal timeAvailable = endTimeVal.getTime() - startTimeVal.getTime();
        timeAvailable /= 60000;
        return timeAvailable;
    }

    //getting ResourceAbsence data and saving it list
    public static List<ResourceAbsence> getResourceAbsence(Set<Id> resourceAbsenceId) {
        List<ResourceAbsence> absenceList = [
            SELECT Id, Start, End, ResourceId, Resource.RelatedRecord.TimeZoneSidKey, FSL__EstTravelTime__c, FSL__EstTravelTimeFrom__c, RecordType.DeveloperName, Type
            FROM ResourceAbsence
            WHERE ResourceId IN :resourceAbsenceId AND End >= TODAY
            ORDER BY ResourceId, Start
        ];
        System.debug('absenceList>> ' + absenceList);
        return absenceList;
    }

    //Doing resource absence Final caluction and saving it in the map for further calculation
    public static Map<String, Map<Date, TimeSlotWrapper>> getRAWithTimeSlot(
        List<ResourceAbsence> absenceList,
        Map<Id, Set<Id>> srWithOHIdsMap
    ) {
        Map<String, Map<Date, TimeSlotWrapper>> resourceAbsenceWithHTSWrapMap = new Map<String, Map<Date, TimeSlotWrapper>>();
        //running loop on absenceList and checking today has the absence record. If yes, doing time slot calculation for absence record
        // Saving it map for further use
        if (absenceList != null && absenceList.size() > 0) {
            system.debug('absenceList>>> ' + absenceList);
            for (ResourceAbsence abRecord : absenceList) {
                Date todayDate = system.Today();
                date localStartDate = date.newinstance(abRecord.Start.year(), abRecord.Start.month(), abRecord.Start.day());
                date localEndDate = date.newinstance(abRecord.End.year(), abRecord.End.month(), abRecord.End.day());
                DateTime localStartDtTm = DateTime.valueOfGMT(abRecord.Start.format('yyyy-MM-dd HH:mm:ss', abRecord.Resource.RelatedRecord.TimeZoneSidKey));
                DateTime localEndDtTm = DateTime.valueOfGMT(abRecord.End.format('yyyy-MM-dd HH:mm:ss', abRecord.Resource.RelatedRecord.TimeZoneSidKey));
                DateTime tempStartDtTm;
                DateTime tempEndDtTm;
                String dayOfWeek = getDayOfWeek(localStartDtTm.dateGmt());
                TimeSlotWrapper tsWrapperRecord;

                if (localStartDtTm.timeGMT() >= Time.newInstance(22, 30, 0, 0) && localStartDtTm.dateGMT() != localEndDtTm.dateGMT()) {
                    localStartDtTm = datetime.newInstanceGMT(localStartDtTm.year(), localStartDtTm.month(), localStartDtTm.dayGMT() + 1, 0, 0, 0);
                    system.debug('localStartDtTm' + localStartDtTm);
                }

                //Ashish Calculating travel time
                String resourceAbsenceKey = abRecord.ResourceId + '__' + localStartDtTm.dateGMT().format();
                if (abRecord.FSL__EstTravelTime__c != null) {
                    Datetime travelStart = localStartDtTm.addMinutes(-Integer.valueOf(abRecord.FSL__EstTravelTime__c));
                    Datetime travelEnd = localStartDtTm;
                    calculateTotalTravelTime(resourceAbsenceKey, travelStart, travelEnd);
                }
                if (abRecord.FSL__EstTravelTimeFrom__c != null) {
                    Datetime travelStart = localEndDtTm;
                    Datetime travelEnd = localEndDtTm.addMinutes(Integer.valueOf(abRecord.FSL__EstTravelTimeFrom__c));
                    calculateTotalTravelTime(resourceAbsenceKey, travelStart, travelEnd);
                }

                Integer numberDaysDue = localStartDtTm.dateGMT().daysBetween(localEndDtTm.dateGMT());
                system.debug('localStartDtTm>> ' + localStartDtTm);
                system.debug('numberDaysDue>> ' + numberDaysDue);
                system.debug('abRecord' + abRecord);
                //checking if absence record it more than one day
                if (numberDaysDue >= 1) {
                    for (Integer i = 0; i <= numberDaysDue; i++) {
                        Date localTodayDate = localStartDtTm.dateGMT().addDays(i);

                        if (localStartDtTm.dateGMT() == localTodayDate) {
                            //to handle first day
                            tempStartDtTm = localStartDtTm;
                            tempEndDtTm = datetime.newInstanceGMT(localStartDtTm.year(), localStartDtTm.month(), localStartDtTm.dayGMT(), 23, 0, 0);
                            tsWrapperRecord = new TimeSlotWrapper();
                            tsWrapperRecord = getTimeSlotFromAbsence(tempStartDtTm, tempEndDtTm);
                            resourceAbsenceWithHTSWrapMap = putTSWrapperToRATimeSlotMap(resourceAbsenceWithHTSWrapMap, tsWrapperRecord, abRecord, localTodayDate);
                        } else if (localStartDtTm.dateGMT() != localTodayDate && localTodayDate != localEndDtTm.dateGMT()) {
                            //to handle in between days
                            tsWrapperRecord = new TimeSlotWrapper();
                            tsWrapperRecord.X8_12_Slot_Minutes = 240;
                            tsWrapperRecord.X12_16_Slot_Minutes = 240;
                            tsWrapperRecord.X16_2030_Slot_Minutes = 270;
                            tsWrapperRecord.X2030_2230_Slot_Minutes = 120;

                            String resourceAbsenceKeyLocal;
                            if (abRecord.RecordType.DeveloperName == 'Break') {
                                resourceAbsenceKeyLocal = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName;
                            } else if (abRecord.RecordType.DeveloperName == 'Non_Availability' && (abRecord.Type == 'Sick' || abRecord.Type == 'Personal Day')) {
                                resourceAbsenceKeyLocal = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName + '__' + 'PTO';
                            } else {
                                resourceAbsenceKeyLocal = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName + '__' + 'nonPTO';
                            }

                            if (resourceAbsenceWithHTSWrapMap != null && resourceAbsenceWithHTSWrapMap.containsKey(resourceAbsenceKeyLocal) && tsWrapperRecord != null) {
                                Map<Date, TimeSlotWrapper> timeSlotWrapperMap = resourceAbsenceWithHTSWrapMap.get(resourceAbsenceKeyLocal);
                                timeSlotWrapperMap.put(localTodayDate, tsWrapperRecord);
                                resourceAbsenceWithHTSWrapMap.put(resourceAbsenceKeyLocal, timeSlotWrapperMap);
                            } else {
                                Map<Date, TimeSlotWrapper> timeSlotWrapperMap = new Map<Date, TimeSlotWrapper>();
                                timeSlotWrapperMap.put(localTodayDate, tsWrapperRecord);
                                resourceAbsenceWithHTSWrapMap.put(resourceAbsenceKeyLocal, timeSlotWrapperMap);
                            }
                        } else if (localTodayDate == localEndDtTm.dateGMT()) {
                            //to handle last day
                            tempStartDtTm = datetime.newInstanceGMT(localEndDtTm.year(), localEndDtTm.month(), localEndDtTm.dayGMT(), 0, 0, 0);
                            tempEndDtTm = localEndDtTm;
                            tsWrapperRecord = new TimeSlotWrapper();
                            tsWrapperRecord = getTimeSlotFromAbsence(tempStartDtTm, tempEndDtTm);
                            resourceAbsenceWithHTSWrapMap = putTSWrapperToRATimeSlotMap(resourceAbsenceWithHTSWrapMap, tsWrapperRecord, abRecord, localTodayDate);
                        }
                    }
                } else if (numberDaysDue == 0) {
                    tsWrapperRecord = new TimeSlotWrapper();
                    tsWrapperRecord = getTimeSlotFromAbsence(localStartDtTm, localEndDtTm);
                    resourceAbsenceWithHTSWrapMap = putTSWrapperToRATimeSlotMap(resourceAbsenceWithHTSWrapMap, tsWrapperRecord, abRecord, localStartDtTm.dateGMT());
                }
            } //Ending for loop here
        } //ending outter if loop
        system.debug('resourceAbsenceWithHTSWrapMap>>> ');
        return resourceAbsenceWithHTSWrapMap;
    }

    //Doing resource absence caluction based on SR and date. Storing it map for further calculation
    public static TimeSlotWrapper getTimeSlotFromAbsence(DateTime abStartDtTm, DateTime abEndDtTm) {
        // Time localStartTime = abRecord.Start.Time();
        // Time localEndTime = abRecord.End.Time();
        //DateTime localEndDateTime = DateTime.valueOfGMT(abRecord.End.format('yyyy-MM-dd HH:mm:ss',abRecord.Resource.RelatedRecord.TimeZoneSidKey));
        //DateTime localStartDateTime  = DateTime.valueOfGMT(abRecord.Start.format('yyyy-MM-dd HH:mm:ss',abRecord.Resource.RelatedRecord.TimeZoneSidKey));
        Time localStartTime = abStartDtTm.timeGmt();
        Time localEndTime = abEndDtTm.timeGmt();

        system.debug('Absence localStartTime>>> ' + localStartTime);
        system.debug('Absence localEndTime>>> ' + localEndTime);
        date localStartDate = abStartDtTm.dateGMT();
        String dayOfWeek = getDayOfWeek(localStartDate);
        system.debug('localStartDate>> ' + localStartDate);
        system.debug('dayOfWeek>> ' + dayOfWeek);

        HourSlotWrapper hourSlotWrap = new HourSlotWrapper();
        hourSlotWrap.startTime = localStartTime;
        hourSlotWrap.endTime = localEndTime;
        hourSlotWrap.dayOftheWeek = dayOfWeek;
        TimeSlotWrapper tWrapper = shiftTimeSlotCreation(hourSlotWrap);
        system.debug('tWrapper Absence>> ' + tWrapper);
        return tWrapper;
    }

    public static Map<String, Map<Date, TimeSlotWrapper>> putTSWrapperToRATimeSlotMap(
        Map<String, Map<Date, TimeSlotWrapper>> resourceAbsenceWithHTSWrapMap,
        TimeSlotWrapper tsWrapperRecord,
        ResourceAbsence abRecord,
        DateTime abtempStartDtTm
    ) {
        String resourceAbsenceKey;
        if (abRecord.RecordType.DeveloperName == 'Break') {
            resourceAbsenceKey = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName;
        } else if (abRecord.RecordType.DeveloperName == 'Non_Availability' && (abRecord.Type == 'Sick' || abRecord.Type == 'Personal Day')) {
            resourceAbsenceKey = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName + '__' + 'PTO';
        } else {
            resourceAbsenceKey = abRecord.ResourceId + '__' + abRecord.RecordType.DeveloperName + '__' + 'nonPTO';
        }

        if (resourceAbsenceWithHTSWrapMap != null && resourceAbsenceWithHTSWrapMap.containsKey(resourceAbsenceKey) && tsWrapperRecord != null) {
            Map<Date, TimeSlotWrapper> timeSlotWrapperMap = resourceAbsenceWithHTSWrapMap.get(resourceAbsenceKey);
            if (timeSlotWrapperMap != null && timeSlotWrapperMap.containsKey(abtempStartDtTm.dateGMT())) {
                TimeSlotWrapper previousTSWrapper = timeSlotWrapperMap.get(abtempStartDtTm.dateGmt());
                // if (tsWrapperRecord.X8_12_Slot_Minutes != previousTSWrapper.X8_12_Slot_Minutes) {
                //     tsWrapperRecord.X8_12_Slot_Minutes = tsWrapperRecord.X8_12_Slot_Minutes + previousTSWrapper.X8_12_Slot_Minutes;
                // }
                // if (tsWrapperRecord.X12_16_Slot_Minutes != previousTSWrapper.X12_16_Slot_Minutes) {
                //     tsWrapperRecord.X12_16_Slot_Minutes = tsWrapperRecord.X12_16_Slot_Minutes + previousTSWrapper.X12_16_Slot_Minutes;
                // }
                // if (tsWrapperRecord.X16_2030_Slot_Minutes != previousTSWrapper.X16_2030_Slot_Minutes) {
                //     tsWrapperRecord.X16_2030_Slot_Minutes = tsWrapperRecord.X16_2030_Slot_Minutes + previousTSWrapper.X16_2030_Slot_Minutes;
                // }
                tsWrapperRecord.X8_12_Slot_Minutes = tsWrapperRecord.X8_12_Slot_Minutes + previousTSWrapper.X8_12_Slot_Minutes;
                tsWrapperRecord.X12_16_Slot_Minutes = tsWrapperRecord.X12_16_Slot_Minutes + previousTSWrapper.X12_16_Slot_Minutes;
                tsWrapperRecord.X16_2030_Slot_Minutes = tsWrapperRecord.X16_2030_Slot_Minutes + previousTSWrapper.X16_2030_Slot_Minutes;
                tsWrapperRecord.X2030_2230_Slot_Minutes = tsWrapperRecord.X2030_2230_Slot_Minutes + previousTSWrapper.X2030_2230_Slot_Minutes;
                timeSlotWrapperMap.put(abtempStartDtTm.dateGmt(), tsWrapperRecord);
            } else {
                timeSlotWrapperMap.put(abtempStartDtTm.dateGmt(), tsWrapperRecord);
            }
            resourceAbsenceWithHTSWrapMap.put(resourceAbsenceKey, timeSlotWrapperMap);
        } else {
            if (tsWrapperRecord != null) {
                Map<Date, TimeSlotWrapper> timeSlotWrapperMap = new Map<Date, TimeSlotWrapper>();
                timeSlotWrapperMap.put(abtempStartDtTm.dateGmt(), tsWrapperRecord);
                resourceAbsenceWithHTSWrapMap.put(resourceAbsenceKey, timeSlotWrapperMap);
            }
        }
        return resourceAbsenceWithHTSWrapMap;
    }

    //Ashish Calculate the total Travel time from Absences and Assigned Resources
    public static void calculateTotalTravelTime(String travelTimeCalculationKey, Datetime travelStart, Datetime travelEnd){
        HourSlotWrapper hWrapperRecord = new HourSlotWrapper();
        hWrapperRecord.startTime = travelStart.timeGmt();
        hWrapperRecord.endTime = travelEnd.timeGmt();

        TimeSlotWrapper tWrapper = shiftTimeSlotCreation(hWrapperRecord);
        if (totalTravelTimeMap != null && !totalTravelTimeMap.containsKey(travelTimeCalculationKey)) {
            totalTravelTimeMap.put(travelTimeCalculationKey, new TimeSlotWrapper());
        }
        TimeSlotWrapper existingWrapper = totalTravelTimeMap.get(travelTimeCalculationKey);
        existingWrapper.X8_12_Slot_Minutes = existingWrapper.X8_12_Slot_Minutes + tWrapper.X8_12_Slot_Minutes;
        existingWrapper.X12_16_Slot_Minutes = existingWrapper.X12_16_Slot_Minutes + tWrapper.X12_16_Slot_Minutes;
        existingWrapper.X16_2030_Slot_Minutes = existingWrapper.X16_2030_Slot_Minutes + tWrapper.X16_2030_Slot_Minutes;
        existingWrapper.X2030_2230_Slot_Minutes = existingWrapper.X2030_2230_Slot_Minutes + tWrapper.X2030_2230_Slot_Minutes;

        totalTravelTimeMap.put(travelTimeCalculationKey, existingWrapper);
    }

    //getting shift record absed on SR'sId and returning that list
    public static List<Shift> getShift(Set<Id> resourceId) {
        Date startDate;
        Date endDate;

        if (stmMinStartDate != null && stmMaxEndDate != null) {
            system.debug('If Shift');
            startDate = stmMinStartDate;
            endDate = stmMinStartDate.addDays(daysLimit + 2);
        } else {
            system.debug('else Shift');
            startDate = system.Today();
            endDate = system.Today().addDays(daysLimit + 2);
        }
        system.debug(stmMinStartDate + ' <<<startDate>>> ' + startDate);
        system.debug(stmMaxEndDate + ' <<<startDate>>> ' + endDate);
        List<Shift> existingShiftList = [SELECT Id, ServiceResourceId, ServiceResource.RelatedRecord.TimeZoneSidKey, Duration_In_Minutes__c, EndTime, StartTime
                                            FROM Shift
                                            WHERE ServiceResourceId IN :resourceId AND TimeSlotType = 'Normal' AND StartTime >= :startDate AND StartTime < :endDate
                                            ORDER BY ServiceResourceId, StartTime ASC
        ];
        System.debug('existingShiftList>> ' + existingShiftList);
        return existingShiftList;
    }

    public static Map<String, TimeSlotWrapper> getShiftCalculation(Set<Id> resourceId, Map<Id, Set<Id>> srWithOHIdMap) {
        Map<String, TimeSlotWrapper> shiftWithTSWrapMap = new Map<String, TimeSlotWrapper>();
        Map<String, HourSlotWrapper> shiftWithHourWrapMap = new Map<String, HourSlotWrapper>();
        List<Shift> existingShiftList = getShift(resourceId);
        if (existingShiftList != null && existingShiftList.size() > 0) {
            for (Shift shiftRecord : existingShiftList) {
                date localStartDate = date.newinstance(shiftRecord.StartTime.year(), shiftRecord.StartTime.month(), shiftRecord.StartTime.day());

                String dayOfWeek = getDayOfWeek(localStartDate);
                DateTime localEndDateTime = DateTime.valueOfGMT(shiftRecord.EndTime.format('yyyy-MM-dd HH:mm:ss', shiftRecord.ServiceResource.RelatedRecord.TimeZoneSidKey));
                DateTime localStartDateTime = DateTime.valueOfGMT(shiftRecord.StartTime.format('yyyy-MM-dd HH:mm:ss', shiftRecord.ServiceResource.RelatedRecord.TimeZoneSidKey));
                system.debug('shift localStartDateTime>> ' + localStartDateTime);
                system.debug('shift localEndDateTime>> ' + localEndDateTime);

                Time shiftStartTime = localStartDateTime.timeGmt();
                Time shiftEndTime = localEndDateTime.timeGmt();

                Set<Id> OperatingHourSet = srWithOHIdMap != null && srWithOHIdMap.containsKey(shiftRecord.ServiceResourceId) ? srWithOHIdMap.get(shiftRecord.ServiceResourceId) : null;
                if (OperatingHourSet != null && OperatingHourSet.size() > 0) {
                    for (Id idRecord : OperatingHourSet) {
                        HourSlotWrapper hourSlotWrap = new HourSlotWrapper();
                        String shiftWithTSWrapMapKey = shiftRecord.ServiceResourceId + '__' + localStartDate.format() + '__' + idRecord + '__' + dayOfWeek;

                        if (!shiftWithHourWrapMap.containsKey(shiftWithTSWrapMapKey)) {
                            hourSlotWrap.startTime = shiftStartTime;
                            hourSlotWrap.endTime = shiftEndTime;
                            hourSlotWrap.dayOftheWeek = dayOfWeek;
                            shiftWithHourWrapMap.put(shiftWithTSWrapMapKey, hourSlotWrap);
                        }
                    }
                }
            }

            if (shiftWithHourWrapMap != null && shiftWithHourWrapMap.size() > 0) {
                for (String srtRecord : shiftWithHourWrapMap.keySet()) {
                    HourSlotWrapper hWrapper = shiftWithHourWrapMap.get(srtRecord);
                    TimeSlotWrapper tWrapper = shiftTimeSlotCreation(hWrapper);
                    shiftWithTSWrapMap.put(srtRecord, tWrapper);
                }
            }
            system.debug('shiftWithHourWrapMap>> ' + shiftWithHourWrapMap);
            system.debug('shiftWithTSWrapMap>> ' + shiftWithTSWrapMap);
        }
        return shiftWithTSWrapMap;
    }

    //time slot creation based on start time and end time and storing it in TimeSlotWrapper variable
    public static TimeSlotWrapper shiftTimeSlotCreation(HourSlotWrapper hourWrapperRecord) {
        TimeSlotWrapper timeWrapperRecord = new TimeSlotWrapper();
        if (hourWrapperRecord.startTime < x8_TimeSlotTime) {
            if (hourWrapperRecord.endTime >= x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 240;
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 120;
            } else if (hourWrapperRecord.endTime >= x2030_TimeSlotTime && hourWrapperRecord.endTime < x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 240;
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = getMinutesFormTime(x2030_TimeSlotTime, hourWrapperRecord.endTime);
            } else if (hourWrapperRecord.endTime >= x16_TimeSlotTime && hourWrapperRecord.endTime < x2030_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 240;
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(x16_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            } else if (hourWrapperRecord.endTime >= x12_TimeSlotTime && hourWrapperRecord.endTime < x16_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 240;
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(x12_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            } else if (hourWrapperRecord.endTime >= x8_TimeSlotTime && hourWrapperRecord.endTime < x12_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(x8_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            }
        } else if (hourWrapperRecord.startTime >= x8_TimeSlotTime && hourWrapperRecord.startTime < x12_TimeSlotTime) {
            if (hourWrapperRecord.endTime >= x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x12_TimeSlotTime);
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 120;
            } else if (hourWrapperRecord.endTime >= x2030_TimeSlotTime && hourWrapperRecord.endTime < x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x12_TimeSlotTime);
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = getMinutesFormTime(x2030_TimeSlotTime, hourWrapperRecord.endTime);
            } else if (hourWrapperRecord.endTime >= x16_TimeSlotTime && hourWrapperRecord.endTime < x2030_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x12_TimeSlotTime);
                timeWrapperRecord.X12_16_Slot_Minutes = 240;
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(x16_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            } else if (hourWrapperRecord.endTime >= x12_TimeSlotTime && hourWrapperRecord.endTime < x16_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x12_TimeSlotTime);
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(x12_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            } else if (hourWrapperRecord.endTime >= x8_TimeSlotTime && hourWrapperRecord.endTime < x12_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            }
        } else if (hourWrapperRecord.startTime >= x12_TimeSlotTime && hourWrapperRecord.startTime < x16_TimeSlotTime) {
            if (hourWrapperRecord.endTime >= x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x16_TimeSlotTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 120;
            } else if (hourWrapperRecord.endTime >= x2030_TimeSlotTime && hourWrapperRecord.endTime < x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x16_TimeSlotTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = 270;
                timeWrapperRecord.X2030_2230_Slot_Minutes = getMinutesFormTime(x2030_TimeSlotTime, hourWrapperRecord.endTime);
            } else if (hourWrapperRecord.endTime >= x16_TimeSlotTime && hourWrapperRecord.endTime < x2030_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x16_TimeSlotTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(x16_TimeSlotTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            } else if (hourWrapperRecord.endTime >= x12_TimeSlotTime && hourWrapperRecord.endTime < x16_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            }
        } else if (hourWrapperRecord.startTime >= x16_TimeSlotTime && hourWrapperRecord.startTime < x2030_TimeSlotTime) {
            if (hourWrapperRecord.endTime >= x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x2030_TimeSlotTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = 120;
            } else if (hourWrapperRecord.endTime >= x2030_TimeSlotTime && hourWrapperRecord.endTime < x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, x2030_TimeSlotTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = getMinutesFormTime(x2030_TimeSlotTime, hourWrapperRecord.endTime);
            } else if (hourWrapperRecord.endTime >= x16_TimeSlotTime && hourWrapperRecord.endTime < x2030_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, hourWrapperRecord.endTime);
                timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
            }
        } else if (hourWrapperRecord.startTime >= x2030_TimeSlotTime && hourWrapperRecord.startTime < x2230_TimeSlotTime) {
            if (hourWrapperRecord.endTime >= x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = 120;
            } else if (hourWrapperRecord.endTime >= x2030_TimeSlotTime && hourWrapperRecord.endTime < x2230_TimeSlotTime) {
                timeWrapperRecord.X8_12_Slot_Minutes = 0;
                timeWrapperRecord.X12_16_Slot_Minutes = 0;
                timeWrapperRecord.X16_2030_Slot_Minutes = 0;
                timeWrapperRecord.X2030_2230_Slot_Minutes = getMinutesFormTime(hourWrapperRecord.startTime, hourWrapperRecord.endTime);
            }
        } else if (hourWrapperRecord.startTime >= x2230_TimeSlotTime) {
            timeWrapperRecord.X8_12_Slot_Minutes = 0;
            timeWrapperRecord.X12_16_Slot_Minutes = 0;
            timeWrapperRecord.X16_2030_Slot_Minutes = 0;
            timeWrapperRecord.X2030_2230_Slot_Minutes = 0;
        }
        timeWrapperRecord.dayOftheWeek = hourWrapperRecord.dayOftheWeek;
        return timeWrapperRecord;
    }

    //To calculate assiged resource capacity from SA
    // Assign it TimeSlotWrapper map and returning it for further calculation
    public static Map<String, TimeSlotWrapper> assignedResourceTimeSlotCal(Set<Id> resourceId) {
        Map<String, TimeSlotWrapper> timeMapForAssignedResource = new Map<String, TimeSlotWrapper>();

        if (resourceId != null && resourceId.size() > 0) {
            Map<String, List<HourSlotWrapper>> mapAssignedResourceMap = new Map<String, List<HourSlotWrapper>>();

            List<AssignedResource> existingAssignedResourceList = getAssignedResource(resourceId);

            if (existingAssignedResourceList != null && existingAssignedResourceList.size() > 0) {
                for (AssignedResource assignedResourceRecord : existingAssignedResourceList) {
                    String assignedResourceKey = assignedResourceRecord.ServiceResourceId + '__' + assignedResourceRecord.Appointment_Scheduled_Date__c.format(); // + '__' + assignedResourceRecord.ServiceAppointment.ServiceTerritoryId; // DWA Changed the Key to include all ARs regarless of Territory

                    //for diving time in slots, creating HourSlotWrapper variable and adding values in it
                    //calling shiftTimeSlotCreation and pass HourSlotWrapper variable in it
                    HourSlotWrapper hWrapperRecord = new HourSlotWrapper();
                    Datetime tempStartDateTime = assignedResourceRecord.ServiceAppointment.SchedStartTime; //shift start time
                    Datetime tempEndDateTime = assignedResourceRecord.ServiceAppointment.SchedEndTime;

                    DateTime localEndDateTime = DateTime.valueOfGMT(tempEndDateTime.format('yyyy-MM-dd HH:mm:ss', assignedResourceRecord.ServiceAppointment.serviceTerritory.OperatingHours.TimeZone));
                    DateTime localStartDateTime = DateTime.valueOfGMT(tempStartDateTime.format('yyyy-MM-dd HH:mm:ss', assignedResourceRecord.ServiceAppointment.serviceTerritory.OperatingHours.TimeZone));

                    //Ashish Calculating travel time
                    if (assignedResourceRecord.EstimatedTravelTime != null) {
                        Datetime travelStart = localStartDateTime.addMinutes(-Integer.valueOf(assignedResourceRecord.EstimatedTravelTime));
                        Datetime travelEnd = localStartDateTime;
                        calculateTotalTravelTime(assignedResourceKey, travelStart, travelEnd);
                    }
                    if (assignedResourceRecord.FSL__EstimatedTravelTimeFrom__c != null) {
                        Datetime travelStart = localEndDateTime;
                        Datetime travelEnd = localEndDateTime.addMinutes(Integer.valueOf(assignedResourceRecord.FSL__EstimatedTravelTimeFrom__c));
                        calculateTotalTravelTime(assignedResourceKey, travelStart, travelEnd);
                    }

                    hWrapperRecord.startTime = localStartDateTime.timeGmt();
                    hWrapperRecord.endTime = localEndDateTime.timeGmt();

                    TimeSlotWrapper tWrapper = shiftTimeSlotCreation(hWrapperRecord);

                    if (timeMapForAssignedResource != null && timeMapForAssignedResource.containsKey(assignedResourceKey)) {
                        TimeSlotWrapper previousWrapper = timeMapForAssignedResource.get(assignedResourceKey);

                        if (previousWrapper != null) {
                            //if any change in calculation for time slot variable
                            if (previousWrapper.X12_16_Slot_Minutes != x240_Value || previousWrapper.X8_12_Slot_Minutes != x240_Value || previousWrapper.X16_2030_Slot_Minutes != 270 || previousWrapper.X2030_2230_Slot_Minutes != 120) {
                                tWrapper.X12_16_Slot_Minutes = tWrapper.X12_16_Slot_Minutes + previousWrapper.X12_16_Slot_Minutes;
                                tWrapper.X8_12_Slot_Minutes = tWrapper.X8_12_Slot_Minutes + previousWrapper.X8_12_Slot_Minutes;
                                tWrapper.X16_2030_Slot_Minutes = tWrapper.X16_2030_Slot_Minutes + previousWrapper.X16_2030_Slot_Minutes;
                                tWrapper.X2030_2230_Slot_Minutes = tWrapper.X2030_2230_Slot_Minutes + previousWrapper.X2030_2230_Slot_Minutes;
                            }
                        }
                        timeMapForAssignedResource.put(assignedResourceKey, tWrapper);
                    } else {
                        timeMapForAssignedResource.put(assignedResourceKey, tWrapper);
                    }
                }
                system.debug('timeMapForAssignedResource>>>> ' + timeMapForAssignedResource);
            }
        }
        return timeMapForAssignedResource;
    }

    //getting Assigned record absed on SR'sId and AppointmentScheduledDate__c filter. Saving it in list and returning it
    public static List<AssignedResource> getAssignedResource(Set<Id> resourceId) {
        Date startDate;
        Date endDateForQuery;
        if (stmMinStartDate != null && stmMaxEndDate != null) {
            startDate = stmMinStartDate;
            endDateForQuery = stmMinStartDate.addDays(daysLimit + 2);
        } else {
            startDate = system.Today();
            endDateForQuery = system.Today().addDays(daysLimit + 2);
        }
        system.debug('startDate>> ' + startDate);
        system.debug('EndDate>> ' + endDateForQuery);
        List<AssignedResource> existingAssignedResourceList = [
            SELECT
                ServiceAppointment.ServiceTerritory.OperatingHours.TimeZone,
                EstimatedTravelTime,
                FSL__EstimatedTravelTimeFrom__c,
                ActualTravelTime,
                Id,
                ServiceAppointmentId,
                ServiceAppointment.ServiceTerritoryId,
                ServiceAppointment.StatusCategory,
                ServiceAppointment.SchedEndTime,
                ServiceAppointment.SchedStartTime,
                ServiceResourceId,
                Appointment_Scheduled_Date__c
            FROM AssignedResource
            WHERE
                ServiceResourceId IN :resourceId
                AND Appointment_Scheduled_Date__c >= :startDate
                AND Appointment_Scheduled_Date__c < :endDateForQuery
                AND ServiceAppointment.StatusCategory != :statusSet
                AND ServiceAppointment.SchedStartTime != NULL
            ORDER BY ServiceResourceId, Appointment_Scheduled_Date__c ASC
        ];
        return existingAssignedResourceList;
    }

    //To get Time from DateTime
    public static Time getTimeFromDateTime(DateTime dtTime) {
        String[] strTimeSplit = dtTime.format('HH:mm:ss').split(':');
        Time timeChange = Time.newInstance(
            Integer.valueOf(strTimeSplit[0]), //hour
            Integer.valueOf(strTimeSplit[1]), //min
            0, //sec
            0
        );
        return timeChange;
    }

    //Geting data from custom metadata to handle number of day
    public static SFS_AB_Capacity_Settings__mdt getCustomMetadata() {
        SFS_AB_Capacity_Settings__mdt optionalHourRecord = [
            SELECT Configuration_Name__c, Configuration_Value__c
            FROM SFS_AB_Capacity_Settings__mdt
            WHERE DeveloperName = 'Days_to_Build_Capacity_Data' AND Configuration_Name__c = 'Days_to_Build_Capacity_Data'
        ];
        return optionalHourRecord;
    }

    //Wrapper class to return lists from CalculateResourceCapacity method
    public class ResourceCapacityWrapper {
        public List<Resource_Capacity__c> resourceCapacityForInsert = new List<Resource_Capacity__c>();
        public List<Resource_Capacity__c> resourceCapacityForUpdate = new List<Resource_Capacity__c>();
        public List<Resource_Capacity__c> resourceCapacityForDelete = new List<Resource_Capacity__c>();

        ResourceCapacityWrapper(List<Resource_Capacity__c> paramInsertList, List<Resource_Capacity__c> paramUpdateList, List<Resource_Capacity__c> paramDeleteList) {
            resourceCapacityForInsert = paramInsertList;
            resourceCapacityForUpdate = paramUpdateList;
            resourceCapacityForDelete = paramDeleteList;
        }
    }

    //Wrapper class to return lists from operating hours and timeslot
    public class TimeSlotWrapper {
        public OperatingHours operatingHourRecord;
        public Decimal X8_12_Slot_Minutes = 0;
        public Decimal X12_16_Slot_Minutes = 0;
        public Decimal X16_2030_Slot_Minutes = 0;
        public Decimal X2030_2230_Slot_Minutes = 0;
        public Decimal totalAssignedAppointment = 0;
        public String dayOftheWeek;

        TimeSlotWrapper() {
        }
    }

    //Wrapper class to return lists from operating hours and timeslot
    public class HourSlotWrapper {
        public Time startTime;
        public Time endTime;
        public String dayOftheWeek;
        public HourSlotWrapper() {
        }
    }

    //Wrapper class to return lists from operating hours and timeslot
    public class ParamWrapper {
        public List<ServiceTerritoryMember> stmListParam;
        public Map<String, Resource_Capacity__c> resourceCapacityMapParam;
        public Map<String, Map<Date, TimeSlotWrapper>> resourceAbsenceMapParam;
        public Map<String, TimeSlotWrapper> shiftTimeSlotMapParam;
        public Map<String, TimeSlotWrapper> assignedResourceMapParam;
        public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> stmIdWithDateMapParam;
        public ParamWrapper() {
        }
    }

    public class ResourceCapacityRecordParam {
        public Date dtParam;
        public String serviceTerritoryIdParam;
        public String serviceResourceIdParam;
        public Decimal x8to12ValParam;
        public Decimal x12to16ValParam;
        public Decimal x16to2030ValParam;
        public Decimal x2030to2230ValParam;
        public Decimal x8to12ValParamAssign;
        public Decimal x12to16ValParamAssign;
        public Decimal x16to2030ValParamAssign;
        public Decimal x2030to2230ValParamAssign;
        public Decimal assignedAppointmentMinutes;
        public Decimal capactiyBeforeConsumptionParam;
        public Decimal capacityFromShifts;
        public Decimal totalBreakDuration;
        public Decimal totalAbsenceDuration;
        public Decimal totalPTODuration;
        public Decimal totalShrinkDuration;
        public Decimal totalTravelTime;
        public Date startSTMDateParam;
        public Date endSTMDateParam;
        public ServiceTerritoryMember stmRecordParam;
        public Resource_Capacity__c rsRecordParam;

        ResourceCapacityRecordParam() {
        }
    }
}