/**
* @description       :
* @author            :  Vandana/Ashish
* @group             :
* @last modified on  : 26-04-2023
* @last modified by  :  Vandana/Ashish
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   26-04-2023   Vandana/Ashish   Initial Version
**/
public with sharing class SFS_ABSTMTriggerHandler implements rflib_TriggerHandler {
    static final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    
    // Calculate default last date
    static SFS_AB_Capacity_Settings__mdt appConfig = [
        SELECT Id, Configuration_Name__c, Configuration_Value__c
        FROM SFS_AB_Capacity_Settings__mdt
        WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
    ];
    static Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
    public static Date maxDate = System.Today().addDays(daysToBuild);
    
    public void run(rflib_TriggerManager.Args args) {
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            System.debug('BEFORE_INSERT executed');
        }
        
        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
            System.debug('AFTER_INSERT executed');
            createCapacityRebuildJobsforSTMInsert(args);
            checkScheduledJobsForRelocateRecord(args);
        }
        
        if (args.operation.name() == SFS_ABConstantUtil.BEFORE_UPDATE) {
            System.debug('BEFORE_UPDATE executed');
        }
        
        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
            System.debug('AFTER_UPDATE executed');
            createCapacityRebuildJobsforSTMUpdate(args);
            //Defect 202425 - Start
            rcDeleteForSTMEndDateUpdate(args);
            //Defect 202425 - End
        }
        
        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            createCapacityRebuildJobsforSTMDelete(args);//working as expected
        }
    }
    
    
    //Defect 202425 - Start
    public static void rcDeleteForSTMEndDateUpdate(rflib_TriggerManager.Args args) {
        List<Resource_Capacity__c> resourceCapacityDeleteList = new List<Resource_Capacity__c>();
        List<ServiceTerritoryMember> stmDeleteList = new List<ServiceTerritoryMember>();
        
        try {
            for (ServiceTerritoryMember eachSTM : (List<ServiceTerritoryMember>) args.newRecords) {
                ServiceTerritoryMember oldSTM = (ServiceTerritoryMember) args.oldRecordsMap.get(eachSTM.Id);
                //Compare if old EffectiveEndDate is lesser than new EffectiveEndDate
                if (eachSTM.EffectiveEndDate < oldSTM.EffectiveEndDate || (oldSTM.EffectiveEndDate == null && eachSTM.EffectiveEndDate != null)) {
                    System.debug('Get stm delete list');
                    stmDeleteList.add(eachSTM);
                }
            }
            system.debug('stmDeleteList '+stmDeleteList);
            if (stmDeleteList != null && stmDeleteList.size() > 0) {
                resourceCapacityDeleteList = getRCDeleteListForSTMEnddateUpdate(stmDeleteList, args);
                //Delete Resource capacity list
                system.debug('resourceCapacityDeleteList '+resourceCapacityDeleteList);
                if (resourceCapacityDeleteList != null && resourceCapacityDeleteList.size() > 0)
                    delete resourceCapacityDeleteList;
            }
        } catch (Exception e) {
            System.Debug('Exception: rcDeleteForSTMEndDateUpdate' + e);
        }
    }
    
    public static List<Resource_Capacity__c> getRCDeleteListForSTMEnddateUpdate(List<ServiceTerritoryMember> stmList, rflib_TriggerManager.Args args) {
        List<Resource_Capacity__c> resourceCapacityListForDelete = new List<Resource_Capacity__c>();
        Set<Id> srIdSet = new Set<Id>();
        Set<Id> stIdSet = new Set<Id>();
        Map<Id, ServiceTerritory> territoryTimeZoneMap;
        List<Resource_Capacity__c> existingResourceCapacityList = new List<Resource_Capacity__c>();
        
        for (ServiceTerritoryMember stm : stmList) {
            srIdSet.add(stm.ServiceResourceId);
            stIdSet.add(stm.ServiceTerritoryId);
        }
        territoryTimeZoneMap = new Map<Id, ServiceTerritory>([SELECT Id, OperatingHours.TimeZone FROM ServiceTerritory WHERE Id IN :stIdSet]);
        existingResourceCapacityList = getRCListForSTMEnddateUpdate(srIdSet, stIdSet);
        //Create Resource Capacity delete list
        if (existingResourceCapacityList != null && existingResourceCapacityList.size() > 0) {
            for (ServiceTerritoryMember stmRecord : stmList) {
                Datetime convertedSTMOldEndDate;
                Date oldSTMEndDate;
                String territoryTZ = territoryTimeZoneMap.get(stmRecord.serviceTerritoryId).OperatingHours.TimeZone;
                Datetime convertedSTMNewEndDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(territoryTZ, stmRecord.EffectiveEndDate);
                Date newSTMEndDate = convertedSTMNewEndDate.timeGMT() <= Time.newInstance(8, 0, 0, 0) ? convertedSTMNewEndDate.DateGMT().addDays(-1) : convertedSTMNewEndDate.DateGMT();
                System.debug('new STM End datetime in ST' + convertedSTMNewEndDate);
                System.debug('new STM End date in ST' + convertedSTMNewEndDate.dateGmt());
                System.debug('new STM End time in ST' + convertedSTMNewEndDate.timeGmt());
                System.debug('new STM End date' + newSTMEndDate);
                ServiceTerritoryMember oldRecord = (ServiceTerritoryMember) args.oldRecordsMap.get(stmRecord.Id);
                if (oldRecord.EffectiveEndDate != null) {
                    convertedSTMOldEndDate = SFS_ABUtil.convertDateTimeToTerritorysTZ(territoryTZ, oldRecord.EffectiveEndDate);
                    oldSTMEndDate = convertedSTMOldEndDate.timeGMT() <= Time.newInstance(8, 0, 0, 0) ? convertedSTMOldEndDate.DateGMT().addDays(-1) : convertedSTMOldEndDate.DateGMT();
                    System.debug('old STM End datetime in ST' + convertedSTMOldEndDate);
                    System.debug('old STM End date in ST' + convertedSTMOldEndDate.dateGmt());
                    System.debug('old STM End time in ST' + convertedSTMOldEndDate.timeGmt());
                    System.debug('old STM End date' + oldSTMEndDate);
                }
                for (Resource_Capacity__c resCap : existingResourceCapacityList) {
                    if (
                        stmRecord.EffectiveEndDate != null &&
                        stmRecord.ServiceResourceId == resCap.Service_Resource__c &&
                        stmRecord.ServiceTerritoryId == resCap.Service_Territory__c &&
                        ((oldRecord.EffectiveEndDate == null && resCap.Capacity_Date__c > newSTMEndDate) ||
                         (oldRecord.EffectiveEndDate != null &&
                          resCap.Capacity_Date__c > newSTMEndDate &&
                          resCap.Capacity_Date__c <= oldSTMEndDate))
                    ) {
                        resourceCapacityListForDelete.add(resCap);
                        system.debug('RC delete: ' + resCap);
                    }
                }
            }
        }
        return resourceCapacityListForDelete;
    }
    
    public static List<Resource_Capacity__c> getRCListForSTMEnddateUpdate(Set<Id> srIdsSet, Set<Id> stIdsSet) {
        List<Resource_Capacity__c> lstResourceCapacity = new List<Resource_Capacity__c>();
        
        if (srIdsSet != null && srIdsSet.size() > 0 && stIdsSet != null && stIdsSet.size() > 0) {
            //running loop on Resource_Capacity__c based on srIdSet and stIdSet and Capacity_Date__c
            for (Resource_Capacity__c rcRecord : [
                SELECT Capacity_Date__c, External_Id__c, Id, Service_Resource__c, Service_Territory__c
                FROM Resource_Capacity__c
                WHERE Service_Resource__c IN :srIdsSet AND Service_Territory__c IN :stIdsSet AND Capacity_Date__c >= TODAY
                ORDER BY External_Id__c
            ]) {
                lstResourceCapacity.add(rcRecord);
            } //Ending Resource_Capacity__c loop
        } // if statement ends here
        return lstResourceCapacity;
    }
    //Defect 202425 - End
    
    // This method is to create the Capacity Rebuild job records for STM Operating Hours change.
    public static void createCapacityRebuildJobsforSTMUpdate(rflib_TriggerManager.Args args) {
        System.debug('createCapacityRebuildJobsforSTMUpdate executed');
        List<Capacity_Rebuild_Job__c> capacityRebuildJobInsertList = new List<Capacity_Rebuild_Job__c>();
        Date maxEndDate;
        Date rebuildStartDt;
        Date rebuildEndDt;
        try {
            for (ServiceTerritoryMember serTerMember : (List<ServiceTerritoryMember>) args.newRecords) {
                ServiceTerritoryMember oldrec = (ServiceTerritoryMember) args.oldRecordsMap.get(serTerMember.Id);
                if (
                    (((ServiceTerritoryMember) args.oldRecordsMap.get(serTerMember.Id)).OperatingHoursId != ((ServiceTerritoryMember) args.newRecordsMap.get(serTerMember.Id)).OperatingHoursId) ||
                    (((ServiceTerritoryMember) args.oldRecordsMap.get(serTerMember.Id)).EffectiveStartDate != ((ServiceTerritoryMember) args.newRecordsMap.get(serTerMember.Id)).EffectiveStartDate) ||
                    (((ServiceTerritoryMember) args.oldRecordsMap.get(serTerMember.Id)).EffectiveEndDate != ((ServiceTerritoryMember) args.newRecordsMap.get(serTerMember.Id)).EffectiveEndDate) &&
                    serTerMember.EffectiveStartDate <= maxDate &&
                    (serTerMember.EffectiveEndDate == null || (serTerMember.EffectiveEndDate != null && serTerMember.EffectiveEndDate.date() >= System.today()))
                ) {
                    maxEndDate = serTerMember.EffectiveEndDate != null ? (serTerMember.EffectiveEndDate.date() <= maxDate ? serTerMember.EffectiveEndDate.date() : maxDate) : maxDate;
                    rebuildStartDt = serTerMember.EffectiveStartDate.date() > oldrec.EffectiveStartDate.date() ? oldrec.EffectiveStartDate.date() : serTerMember.EffectiveStartDate.date();
                    rebuildEndDt = maxEndDate < maxDate &&
                        oldrec.EffectiveEndDate != null &&
                        oldrec.EffectiveEndDate.date() < maxDate
                        ? (oldrec.EffectiveEndDate.date() > maxEndDate ? oldrec.EffectiveEndDate.date() : maxEndDate)
                        : maxDate;
                    capacityRebuildJobInsertList.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
                            'Service Territory Member Update',
                            serTerMember.ServiceResourceId,
                            serTerMember.ServiceTerritoryId,
                            rebuildStartDt,
                            rebuildEndDt
                        )
                    );
                }
            }
            if (capacityRebuildJobInsertList != null && capacityRebuildJobInsertList.size() > 0) {
                insert capacityRebuildJobInsertList;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }
    
    // This method is to create the Capacity Rebuild job records for STM insert.
    public static void createCapacityRebuildJobsforSTMInsert(rflib_TriggerManager.Args args) {
        List<Capacity_Rebuild_Job__c> capacityRebuildJobInsertList = new List<Capacity_Rebuild_Job__c>();
        Date maxEndDate;
        
        try {
            for (ServiceTerritoryMember serTerMember : (List<ServiceTerritoryMember>) args.newRecords) {
                maxEndDate = serTerMember.EffectiveEndDate != null ? (serTerMember.EffectiveEndDate.date() <= maxDate ? serTerMember.EffectiveEndDate.date() : maxDate) : maxDate;
                capacityRebuildJobInsertList.add(
                    SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
                        'Service Territory Member Insert',
                        serTerMember.ServiceResourceId,
                        serTerMember.ServiceTerritoryId,
                        serTerMember.EffectiveStartDate.date(),
                        maxEndDate
                    )
                );
            }
            if (capacityRebuildJobInsertList != null && capacityRebuildJobInsertList.size() > 0) {
                insert capacityRebuildJobInsertList;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }
    
    // This method is to create the Capacity Rebuild job records for STM delete.
    public static void createCapacityRebuildJobsforSTMDelete(rflib_TriggerManager.Args args) {
        System.debug('Inside createCapacityRebuildJobsforSTMDelete method');
        List<Capacity_Rebuild_Job__c> capacityRebuildJobInsertList = new List<Capacity_Rebuild_Job__c>();
        List<ServiceTerritoryMember> stmDeleteList = new List<ServiceTerritoryMember>();
        List<Resource_Capacity__c> resourceCapacityDeleteList = new List<Resource_Capacity__c>();
        Set<Id> stIdSet = new Set<Id>();
        Map<Id, ServiceTerritory> territoryTimeZoneMap = new Map<Id, ServiceTerritory>();
        Date maxEndDate;
        
        try {
            System.debug('STM Old Records '+(List<ServiceTerritoryMember>) args.oldRecords);
            for (ServiceTerritoryMember serTerMember : (List<ServiceTerritoryMember>) args.oldRecords) {
                maxEndDate = serTerMember.EffectiveEndDate != null ? (serTerMember.EffectiveEndDate.date() <= maxDate ? serTerMember.EffectiveEndDate.date() : maxDate) : maxDate;
                capacityRebuildJobInsertList.add(
                    SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
                        'Service Territory Member Delete',
                        serTerMember.ServiceResourceId,
                        serTerMember.ServiceTerritoryId,
                        serTerMember.EffectiveStartDate.date(),
                        maxEndDate
                    )
                );
                stmDeleteList.add(serTerMember);
                stIdSet.add(serTerMember.ServiceTerritoryId);
            }
            System.debug('stmDeleteList '+stmDeleteList);
            //Delete the Resource Capacity records if STM's are deleted
            if (stmDeleteList != null && stmDeleteList.size() > 0) {
                territoryTimeZoneMap = new Map<Id, ServiceTerritory>([SELECT Id, OperatingHours.TimeZone FROM ServiceTerritory WHERE Id IN :stIdSet]);
                //resourceCapacityDeleteList = SFS_ABResourceCapacityTimeSlotUtil.getResourceCapacityDeleteList(stmDeleteList, TRUE);
                resourceCapacityDeleteList = SFS_ABResourceCapacityTimeSlotUtil.getResourceCapacityDeleteList(stmDeleteList, true, territoryTimeZoneMap);
                System.debug('resourceCapacityDeleteList***' + resourceCapacityDeleteList);
                if (resourceCapacityDeleteList != null && resourceCapacityDeleteList.size() > 0) {
                    delete resourceCapacityDeleteList;
                }
            }
            
            if (capacityRebuildJobInsertList != null && capacityRebuildJobInsertList.size() > 0) {
                insert capacityRebuildJobInsertList;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }
    
    
    // Anand - 12/30/2020 - Added for US-578426
  public static void checkScheduledJobsForRelocateRecord(rflib_TriggerManager.Args args) {
        Set<Id> serviceResourceIds = new Set<ID>();
        List<AssignedResource> scheduledSAOfAbsentResource = new List<AssignedResource>();
        Map<Id, ServiceTerritoryMember> serviceTerritoryMemberMap = new Map<Id, ServiceTerritoryMember>(); // key is the serviceResourceId
        Map<Id, List<AssignedResource>> assignedResourceMap = new Map<Id, List<AssignedResource>>(); // key is the serviceResourceId
        List<ServiceAppointment> updateServiceAppointmentList = new List<ServiceAppointment>();
        
        FSL__Scheduling_Policy__c businessHoursPolicy = new FSL__Scheduling_Policy__c();
        FSL__Scheduling_Policy__c extendedHoursPolicy = new FSL__Scheduling_Policy__c();
        
        try {
            businessHoursPolicy = SFS_ABUtil.getSchedulingPolicyByName(SFS_ABConstantUtil.Only_Business_Hours_PolicyID);
            extendedHoursPolicy = SFS_ABUtil.getSchedulingPolicyByName(SFS_ABConstantUtil.Extended_Hours_PolicyID);
        } catch (Exception e) {
            System.debug(e);
        }
        
        SFS_AB_Capacity_Settings__mdt allowFutureOnReschedule = [SELECT Id, Enable_Flag__c FROM SFS_AB_Capacity_Settings__mdt WHERE Configuration_Name__c = :SFS_ABConstantUtil.RescheduleSwitchName];
        System.debug('(List<ServiceTerritoryMember>) args.newRecords '+(List<ServiceTerritoryMember>) args.newRecords);
        for (ServiceTerritoryMember resSTM : (List<ServiceTerritoryMember>) args.newRecords) {
            if (resSTM.TerritoryType == SFS_ABConstantUtil.TYPE_RELOCATION) {
                serviceResourceIds.add(resSTM.ServiceResourceId);
                serviceTerritoryMemberMap.put(resSTM.ServiceResourceId, resSTM);
            }
        }
        System.debug('serviceResourceIds'+serviceResourceIds);
        System.debug('serviceTerritoryMemberMap'+serviceTerritoryMemberMap);
        try {
            scheduledSAOfAbsentResource = [
                SELECT
                Id,
                ServiceResourceId,
                ServiceResource.Name,
                ServiceAppointment.Id,
                ServiceAppointment.Status,
                ServiceAppointment.SchedStartTime,
                ServiceAppointment.SchedEndTime,
                ServiceAppointment.ServiceTerritoryId
                FROM AssignedResource
                WHERE
                ServiceResource.Id IN :serviceResourceIds
                AND (ServiceAppointment.Status = :SFS_ABConstantUtil.SA_SCHEDULED
                     OR ServiceAppointment.Status = :SFS_ABConstantUtil.SA_DISPATCHED)
                AND ServiceAppointment.SchedStartTime != NULL
                AND ServiceAppointment.SchedEndTime != NULL
                AND ServiceAppointment.ServiceTerritoryId != NULL
            ];
        } catch (Exception e) {
            System.debug(e);
        }
                System.debug('scheduledSAOfAbsentResource'+scheduledSAOfAbsentResource);
        if (scheduledSAOfAbsentResource != null && scheduledSAOfAbsentResource.size() > 0) {
            for (assignedResource eachARrecord : scheduledSAOfAbsentResource) {
                if (assignedResourceMap.containsKey(eachARrecord.ServiceResourceId)) {
                    assignedResourceMap.get(eachARrecord.ServiceResourceId).add(eachARrecord);
                } else {
                    assignedResourceMap.put(eachARrecord.ServiceResourceId, new List<assignedResource>{ eachARrecord });
                }
            }
  System.debug('serviceTerritoryMemberMap'+serviceTerritoryMemberMap);
            for (Id eachSTM : serviceTerritoryMemberMap.keyset()) {
                List<AssignedResource> resourceScheduledAppointments = assignedResourceMap.get(eachSTM);
                ServiceTerritoryMember eachRelocateSTM = serviceTerritoryMemberMap.get(eachSTM);
                  System.debug('resourceScheduledAppointments'+resourceScheduledAppointments);
System.debug('eachRelocateSTM'+eachRelocateSTM);
                if (resourceScheduledAppointments != null && resourceScheduledAppointments.size() > 0) {
                    for (AssignedResource eachRec : resourceScheduledAppointments) {
                        System.debug('eachRec '+eachRec);
                        if (
                            eachRelocateSTM.EffectiveStartDate <= eachRec.ServiceAppointment.SchedStartTime &&
                            eachRelocateSTM.EffectiveEndDate >= eachRec.ServiceAppointment.SchedEndTime &&
                            eachRelocateSTM.ServiceTerritoryId != eachRec.ServiceAppointment.ServiceTerritoryId
                        ) {
                            ServiceAppointment unscheduleSA = new ServiceAppointment();
                            unscheduleSA.Id = eachRec.ServiceAppointmentId;
                            updateServiceAppointmentList.add(unscheduleSA);
                        }
                    }
                }
            }
                System.debug('updateServiceAppointmentList '+updateServiceAppointmentList);
            if (updateServiceAppointmentList != null && updateServiceAppointmentList.size() > 0) {
                try {
                    System.debug('Calling reschedule method');
                    SFS_ABUtil.rescheduleJobs(updateServiceAppointmentList);
                } catch (Exception e) {
                    System.debug('Exception 431: ' + e);
                }
            }
        }
    }
    
 
    
    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
        return;
    }
}