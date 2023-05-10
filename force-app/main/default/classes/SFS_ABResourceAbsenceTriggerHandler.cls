/**
* @description       :
* @author            : Salesforce Services
* @group             :
* @last modified on  : 05-17-2021
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   11-11-2020   Salesforce Services                  Initial Version
* 2.0   09-03-2023   Divya Dalmia                         Initial Version
**/

public with sharing class SFS_ABResourceAbsenceTriggerHandler implements rflib_TriggerHandler {
    static final String DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    static final String CED_CUSTOM_PERMISSION = 'Allow_CED_on_Resource_Absence';
    static final String ERROR_MESSAGE = 'You do not have the appropriate permissions to create, edit or delete a Resource Absence';
    private static final rflib_logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('SFS_ABResourceAbsenceTriggerHandler'); 


    // Calculate default last date
    static SFS_AB_Capacity_Settings__mdt appConfig = [
        SELECT Id, Configuration_Name__c, Configuration_Value__c
        FROM SFS_AB_Capacity_Settings__mdt
        WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
    ];
    static Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
    public static Date maxDate = System.today().addDays(daysToBuild);
    public static Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    public void run(rflib_TriggerManager.Args args) {
        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
            createCapacityRebuildJobsforAbsenceInsert(args);
            checkScheduledJobsForNewAbsenceRecord(args);
        }
        
        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
            createCapacityRebuildJobsforAbsenceUpdate(args);
            checkScheduledJobsForNewAbsenceRecordOnUpdate(args);
        }
        
        if (args.operation == System.TriggerOperation.AFTER_DELETE) {
            createCapacityRebuildJobsforAbsenceDelete(args);
        }

        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            LOGGER.info('CALLING BEFORE INSERT');
            checkCEDResourceAbsenceCustomPermission(args);
        }

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            LOGGER.info('CALLING BEFORE UPDATE');
            checkCEDResourceAbsenceCustomPermission(args);
        }

        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            LOGGER.info('CALLING BEFORE DELETE');
            checkCEDResourceAbsenceCustomPermission(args);
        }
    }
    
    //Create CapacityRebuild records on insert of Resource Absence records
    public static void createCapacityRebuildJobsforAbsenceInsert(rflib_TriggerManager.Args args) {
        List<ResourceAbsence> resourceAbsenceList = new List<ResourceAbsence>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForResourceAbsenceInsert = new List<Capacity_Rebuild_Job__c>();
        try {
            //Looping through the new Resource Absences records
            // Ankit - Checking RA start date and end date less than max date whcih comes from metadata
            for (ResourceAbsence resourceAbsence : (List<ResourceAbsence>) args.newRecords) {
                if (resourceAbsence.Start.date() <= maxDate && resourceAbsence.End.date() <= maxDate) {
                    resourceAbsenceList.add(resourceAbsence);
                }
            }
            
            // System.debug('resourceAbsenceList***' + resourceAbsenceList);
            // if size >1 then create rebuild job
            // else process it
            if (resourceAbsenceList != null && resourceAbsenceList.size() > 1) {
                for (ResourceAbsence absence : resourceAbsenceList) {
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Absence Insert', absence.ResourceId, null, absence.Start.date(), absence.End.date())
                    );
                }
            } else if (resourceAbsenceList != null && resourceAbsenceList.size() == 1) {
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ resourceAbsenceList[0].ResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    if (
                        stmListForCapacityReCalculation[0].EffectiveEndDate == null ||
                        resourceAbsenceList[0].End.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date() ||
                        resourceAbsenceList[0].Start.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                    ) {
                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                            stmListForCapacityReCalculation[0].Id,
                            resourceAbsenceList[0].Start.date(),
                            resourceAbsenceList[0].End.date()
                        );
                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                            null,
                            capacityRebuildDateMap.minDate,
                            capacityRebuildDateMap.maxDate,
                            capacityRebuildDateMap.recordIdToDateMap
                        );
                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                            stmListForCapacityReCalculation[0].ServiceTerritoryId,
                            System.today(),
                            resourceAbsenceList[0].End.date()
                        );
                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(
                                stmListForCapacityReCalculation[0].ServiceTerritoryId,
                                new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), resourceAbsenceList[0].End.date())
                            );
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    //Ending stmListForCapacityReCalculation if condition
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
                            'Absence Insert',
                            resourceAbsenceList[0].ResourceId,
                            null,
                            resourceAbsenceList[0].Start.date(),
                            resourceAbsenceList[0].End.date()
                        )
                    );
                }
            }
            
            if (capacityRebuildJobListForResourceAbsenceInsert != null && capacityRebuildJobListForResourceAbsenceInsert.size() > 0) {
                insert capacityRebuildJobListForResourceAbsenceInsert;
            }
        } catch (Exception e) {
        }
    }
    
    //Create CapacityRebuild records on update of Resource Absence records
    public static void createCapacityRebuildJobsforAbsenceUpdate(rflib_TriggerManager.Args args) {
        List<ResourceAbsence> resourceAbsenceList = new List<ResourceAbsence>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForResourceAbsenceInsert = new List<Capacity_Rebuild_Job__c>();
        
        try {
            //Looping through the Resource Absences records
            for (ResourceAbsence resourceAbsence : (List<ResourceAbsence>) args.newRecords) {
                //Get updated record
                ResourceAbsence oldRAb = (ResourceAbsence) args.oldRecordsMap.get(resourceAbsence.Id);
                if (
                    resourceAbsence.Start.date() <= maxDate &&
                    resourceAbsence.End.date() <= maxDate &&
                    (resourceAbsence.Start != oldRAb.Start ||
                     resourceAbsence.End != oldRAb.End) &&
                    (resourceAbsence.RecordTypeId == Schema.SObjectType.ResourceAbsence.getRecordTypeInfosByDeveloperName().get('Non_Availability').getRecordTypeId())
                ) {
                    resourceAbsenceList.add(resourceAbsence);
                }
            }
            System.debug('resourceAbsenceList Update: ' + resourceAbsenceList.size());
            if (resourceAbsenceList != null && resourceAbsenceList.size() > 1) {
                for (ResourceAbsence absence : resourceAbsenceList) {
                    ResourceAbsence oldrec = (ResourceAbsence) args.oldRecordsMap.get(absence.Id);
                    Date rebuildStartDt = absence.Start.date() > oldrec.Start.date() ? oldrec.Start.date() : absence.Start.date();
                    Date rebuildEndDt = absence.End.date() < oldrec.End.date() ? oldrec.End.date() : absence.End.date();
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Absence Update', absence.ResourceId, null, rebuildStartDt, rebuildEndDt)
                    );
                }
            } else if (resourceAbsenceList != null && resourceAbsenceList.size() == 1) {
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ resourceAbsenceList[0].ResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    if (
                        stmListForCapacityReCalculation[0].EffectiveEndDate == null ||
                        resourceAbsenceList[0].End.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date() ||
                        resourceAbsenceList[0].Start.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                    ) {
                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                            stmListForCapacityReCalculation[0].Id,
                            resourceAbsenceList[0].Start.date(),
                            resourceAbsenceList[0].End.date()
                        );
                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                            null,
                            capacityRebuildDateMap.minDate,
                            capacityRebuildDateMap.maxDate,
                            capacityRebuildDateMap.recordIdToDateMap
                        );
                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                            stmListForCapacityReCalculation[0].ServiceTerritoryId,
                            System.today(),
                            resourceAbsenceList[0].End.date()
                        );
                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(
                                stmListForCapacityReCalculation[0].ServiceTerritoryId,
                                new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), resourceAbsenceList[0].End.date())
                            );
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    //Ending stmListForCapacityReCalculation if condition
                    ResourceAbsence oldrec = (ResourceAbsence) args.oldRecordsMap.get(resourceAbsenceList[0].Id);
                    Date rebuildStartDt = resourceAbsenceList[0].Start.date() > oldrec.Start.date() ? oldrec.Start.date() : resourceAbsenceList[0].Start.date();
                    Date rebuildEndDt = resourceAbsenceList[0].End.date() < oldrec.End.date() ? oldrec.End.date() : resourceAbsenceList[0].End.date();
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Absence Update', resourceAbsenceList[0].ResourceId, null, rebuildStartDt, rebuildEndDt)
                    );
                }
            }
            
            if (capacityRebuildJobListForResourceAbsenceInsert != null && capacityRebuildJobListForResourceAbsenceInsert.size() > 0) {
                insert capacityRebuildJobListForResourceAbsenceInsert;
            }
        } catch (Exception e) {
        }
    }
    
    //Create CapacityRebuild records on delete of Resource Absence records
    public static void createCapacityRebuildJobsforAbsenceDelete(rflib_TriggerManager.Args args) {
        List<ResourceAbsence> resourceAbsenceList = new List<ResourceAbsence>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForResourceAbsenceInsert = new List<Capacity_Rebuild_Job__c>();
        
        try {
            //Looping through the old Resource Absences records
            for (ResourceAbsence resourceAbsence : (List<ResourceAbsence>) args.oldRecords) {
                if (resourceAbsence.Start.date() <= maxDate && resourceAbsence.End.date() <= maxDate) {
                    resourceAbsenceList.add(resourceAbsence);
                }
            }
            System.debug('resourceAbsenceList delete: ' + resourceAbsenceList.size() + resourceAbsenceList);
            //   System.debug('resourceAbsenceList***' + resourceAbsenceList);
            if (resourceAbsenceList != null && resourceAbsenceList.size() > 1) {
                for (ResourceAbsence absence : resourceAbsenceList) {
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Absence Delete', absence.ResourceId, null, absence.start.date(), absence.end.date())
                    );
                }
            } else if (resourceAbsenceList != null && resourceAbsenceList.size() == 1) {
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ resourceAbsenceList[0].ResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    if (
                        stmListForCapacityReCalculation[0].EffectiveEndDate == null ||
                        resourceAbsenceList[0].End.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date() ||
                        resourceAbsenceList[0].Start.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                    ) {
                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                            stmListForCapacityReCalculation[0].Id,
                            resourceAbsenceList[0].Start.date(),
                            resourceAbsenceList[0].End.date()
                        );
                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                            null,
                            capacityRebuildDateMap.minDate,
                            capacityRebuildDateMap.maxDate,
                            capacityRebuildDateMap.recordIdToDateMap
                        );
                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                            stmListForCapacityReCalculation[0].ServiceTerritoryId,
                            System.today(),
                            resourceAbsenceList[0].End.date()
                        );
                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(
                                stmListForCapacityReCalculation[0].ServiceTerritoryId,
                                new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), resourceAbsenceList[0].End.date())
                            );
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    //Ending stmListForCapacityReCalculation if condition
                    capacityRebuildJobListForResourceAbsenceInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord(
                            'Absence Delete',
                            resourceAbsenceList[0].ResourceId,
                            null,
                            resourceAbsenceList[0].Start.date(),
                            resourceAbsenceList[0].End.date()
                        )
                    );
                }
            }
            
            if (capacityRebuildJobListForResourceAbsenceInsert != null && capacityRebuildJobListForResourceAbsenceInsert.size() > 0) {
                insert capacityRebuildJobListForResourceAbsenceInsert;
            }
        } catch (Exception e) {
        }
    }
    
    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
    }
    
    public static void checkScheduledJobsForNewAbsenceRecordOnUpdate(rflib_TriggerManager.Args args) {
        Boolean hasFSLOptimizerCustomPermission = FeatureManagement.checkPermission(SFS_ABConstantUtil.FSL_OPTIMIZATION_PERMISSION);
        if (!hasFSLOptimizerCustomPermission) {
            Set<Id> serviceResourceIds = new Set<Id>();
            List<AssignedResource> scheduledSAOfAbsentResource = new List<AssignedResource>();
            Map<Id, ResourceAbsence> resourceAbsenceMap = new Map<Id, ResourceAbsence>(); // key is the serviceResourceId
            Map<Id, List<AssignedResource>> assignedResourceMap = new Map<Id, List<AssignedResource>>(); // key is the serviceResourceId
            
            for (ResourceAbsence resAbsence : (List<ResourceAbsence>) args.newRecords) {
                if (resAbsence.RecordTypeId == SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE) {
                    serviceResourceIds.add(resAbsence.ResourceId);
                    resourceAbsenceMap.put(resAbsence.ResourceId, resAbsence);
                }
            }
            Set<Id> workOrderIdSet = new Set<Id>();
            try {
                scheduledSAOfAbsentResource = [
                    SELECT
                    Id,
                    ServiceResourceId,
                    ServiceResource.Name,
                    ServiceAppointment.ParentRecordId,
                    ServiceAppointmentId,
                    ServiceAppointment.Status,
                    ServiceAppointment.SchedStartTime,
                    ServiceAppointment.SchedEndTime,
                    ServiceAppointment.FSL__Pinned__c
                    FROM AssignedResource
                    WHERE
                    ServiceResource.Id IN : serviceResourceIds
                    AND ServiceAppointment.Status =: SFS_ABConstantUtil.SA_SCHEDULED
                    AND ServiceAppointment.SchedStartTime != NULL
                    AND ServiceAppointment.SchedEndTime != NULL
                    AND ServiceAppointment.FSL__Pinned__c = FALSE
                ];
            } catch (Exception e) {
            }
            
            if (scheduledSAOfAbsentResource != null && scheduledSAOfAbsentResource.size() > 0) {
                for (AssignedResource eachARrecord : scheduledSAOfAbsentResource) {
                    if (!assignedResourceMap.containsKey(eachARrecord.ServiceResourceId)) {
                        assignedResourceMap.put(eachARrecord.ServiceResourceId, new List<AssignedResource>());
                    }
                    assignedResourceMap.get(eachARrecord.ServiceResourceId).add(eachARrecord);
                    workOrderIdSet.add(eachARrecord.ServiceAppointment.ParentRecordId);
                }
                
                Map<Id, WorkOrder> parentWorkOrderIdMap = new Map<Id, WorkOrder>([SELECT Id, WorkOrderNumber FROM WorkOrder
                                                                                  WHERE Id IN (SELECT RelatedRecordId FROM ResourcePreference WHERE PreferenceType = 'Required')
                                                                                  AND Id IN : workOrderIdSet]);
                
                for (Id eachResource : resourceAbsenceMap.keySet()) {
                    List<AssignedResource> resourceScheduledAppointments = assignedResourceMap.get(eachResource);
                    ResourceAbsence eachRecordOfAbsence = resourceAbsenceMap.get(eachResource);
                    ResourceAbsence oldAbsenceRecord = (ResourceAbsence) args.oldRecordsMap.get(eachRecordOfAbsence.Id);
                    List<ServiceAppointment> updateServiceAppointmentList = new List<ServiceAppointment>();
                    List<FeedItem> chatterPostsList = new List<FeedItem>();
                    if ((oldAbsenceRecord.Start != eachRecordOfAbsence.Start) || (oldAbsenceRecord.End != eachRecordOfAbsence.End)) {
                        if (resourceScheduledAppointments != null && resourceScheduledAppointments.size() > 0) {
                            for (AssignedResource eachRec : resourceScheduledAppointments) {
                                if (
                                    (eachRecordOfAbsence.Start < eachRec.ServiceAppointment.SchedEndTime && eachRec.ServiceAppointment.SchedStartTime < eachRecordOfAbsence.End)
                                    && !parentWorkOrderIdMap.containsKey(eachRec.ServiceAppointment.ParentRecordId)
                                ) {
                                    //Try immediately Scheduling the job
                                    ServiceAppointment serviceAppointment = new ServiceAppointment();
                                    serviceAppointment.Id = eachRec.ServiceAppointmentId;
                                    serviceAppointment.Status = SFS_ABConstantUtil.SA_OPEN;
                                    updateServiceAppointmentList.add(serviceAppointment);
                                    
                                    FeedItem post = new FeedItem();
                                    post.ParentId = eachRec.ServiceAppointmentId;
                                    post.Body = 'Automatically unscheduled due to overlapping Absence';
                                    chatterPostsList.add(post);
                                }
                            }
                            
                            // if any SA found - Update to unschedule the SA's
                            if (updateServiceAppointmentList != null && updateServiceAppointmentList.size() > 0) {
                                try {
                                    update updateServiceAppointmentList;
                                    insert chatterPostsList;
                                } catch (Exception e) {
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public static void checkScheduledJobsForNewAbsenceRecord(rflib_TriggerManager.Args args) {
        Boolean hasFSLOptimizerCustomPermission = FeatureManagement.checkPermission(SFS_ABConstantUtil.FSL_OPTIMIZATION_PERMISSION);
        if (!hasFSLOptimizerCustomPermission) {
            Set<Id> serviceResourceIds = new Set<ID>();
            List<AssignedResource> scheduledSAOfAbsentResource = new List<AssignedResource>();
            Map<Id, ResourceAbsence> resourceAbsenceMap = new Map<Id, ResourceAbsence>(); // key is the serviceResourceId
            Map<Id, List<AssignedResource>> assignedResourceMap = new Map<Id, List<AssignedResource>>(); // key is the serviceResourceId

            for (ResourceAbsence resAbsence : (List<ResourceAbsence>) args.newRecords) {
                if (resAbsence.RecordTypeId == SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE) {
                    serviceResourceIds.add(resAbsence.ResourceId);
                    resourceAbsenceMap.put(resAbsence.ResourceId, resAbsence);
                }
            }
            
            try {
                scheduledSAOfAbsentResource = [
                    SELECT
                    Id,
                    ServiceResourceId,
                    ServiceResource.Name,
                    ServiceAppointment.ParentRecordId,
                    ServiceAppointmentId,
                    ServiceAppointment.Status,
                    ServiceAppointment.SchedStartTime,
                    ServiceAppointment.SchedEndTime,
                    ServiceAppointment.FSL__Pinned__c
                    FROM AssignedResource
                    WHERE
                    ServiceResource.Id IN :serviceResourceIds
                    AND ServiceAppointment.Status = :SFS_ABConstantUtil.SA_SCHEDULED
                    AND ServiceAppointment.SchedStartTime != NULL
                    AND ServiceAppointment.SchedEndTime != NULL
                    AND ServiceAppointment.FSL__Pinned__c = FALSE
                ];
            } catch (Exception e) {
            }
            Set<Id> workOrderIdSet = new Set<Id>();
            if (scheduledSAOfAbsentResource != null && scheduledSAOfAbsentResource.size() > 0) {
                for (AssignedResource eachARrecord : scheduledSAOfAbsentResource) {
                    if (!assignedResourceMap.containsKey(eachARrecord.ServiceResourceId)) {
                        assignedResourceMap.put(eachARrecord.ServiceResourceId, new List<AssignedResource>());
                    }
                    assignedResourceMap.get(eachARrecord.ServiceResourceId).add(eachARrecord);
                    workOrderIdSet.add(eachARrecord.ServiceAppointment.ParentRecordId);
                }
                
                Map<Id, WorkOrder> parentWorkOrderIdMap = new Map<Id, WorkOrder>([SELECT Id, WorkOrderNumber FROM WorkOrder
                                                                                  WHERE Id IN (SELECT RelatedRecordId FROM ResourcePreference WHERE PreferenceType = 'Required')
                                                                                  AND Id IN : workOrderIdSet]);
                
                for (Id eachResource : resourceAbsenceMap.keySet()) {
                    List<AssignedResource> resourceScheduledAppointments = assignedResourceMap.get(eachResource);
                    ResourceAbsence eachRecordOfAbsence = resourceAbsenceMap.get(eachResource);
                    List<ServiceAppointment> updateServiceAppointmentList = new List<ServiceAppointment>();
                    List<FeedItem> chatterPostsList = new List<FeedItem>();
                    if (resourceScheduledAppointments != null && resourceScheduledAppointments.size() > 0) {
                        for (AssignedResource eachRec : resourceScheduledAppointments) {
                            if (
                                (eachRecordOfAbsence.Start < eachRec.ServiceAppointment.SchedEndTime && eachRec.ServiceAppointment.SchedStartTime < eachRecordOfAbsence.End)
                                && !parentWorkOrderIdMap.containsKey(eachRec.ServiceAppointment.ParentRecordId)
                            ) {
                                //Try immediately Scheduling the job
                                ServiceAppointment serviceAppointment = new ServiceAppointment();
                                serviceAppointment.Id = eachRec.ServiceAppointmentId;
                                serviceAppointment.Status = SFS_ABConstantUtil.SA_OPEN;
                                updateServiceAppointmentList.add(serviceAppointment);
                                
                                FeedItem post = new FeedItem();
                                post.ParentId = eachRec.ServiceAppointmentId;
                                post.Body = 'Automatically unscheduled due to overlapping Absence';
                                chatterPostsList.add(post);
                            }
                        }
                        
                        // if any SA found - Update to unschedule the SA's
                        if (updateServiceAppointmentList != null && updateServiceAppointmentList.size() > 0) {
                            try {
                                update updateServiceAppointmentList;
                                insert chatterPostsList;
                            } catch (Exception e) {
                            }
                        }
                    }
                }
            }
        }
    }

    public static void checkCEDResourceAbsenceCustomPermission(rflib_TriggerManager.Args args){
        try{
            List<ResourceAbsence> resourceAbsenceList = new List<ResourceAbsence>();

            if(Trigger.isDelete){
                resourceAbsenceList = (List<ResourceAbsence>)args.oldRecords;
            }else{
                resourceAbsenceList = (List<ResourceAbsence>)args.newRecords;
            }

            Boolean hasCustomPermission = FeatureManagement.checkPermission(CED_CUSTOM_PERMISSION);
            LOGGER.info('hasCustomPermission ({0})', new Object[]{hasCustomPermission});
            for (ResourceAbsence ra : resourceAbsenceList) {
                if (!hasCustomPermission) {
                    ra.addError(ERROR_MESSAGE);                
                }
            }
        }
        catch(Exception e){
            LOGGER.error('EXCEPTION OCCURRED ({0})', new Object[]{e});
        }
    }
}