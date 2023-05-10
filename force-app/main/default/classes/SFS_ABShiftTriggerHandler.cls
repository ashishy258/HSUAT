/**
 * @description       : Handle the trigger functionality of Shift Object's records.
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 27th Feb 2023
 * @last modified by  : Ashish Yadav
 **/
public with sharing class SFS_ABShiftTriggerHandler implements rflib_TriggerHandler {

    static final String DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    // Calculate default last date
    static SFS_AB_Capacity_Settings__mdt appConfig = [SELECT Id, Configuration_Name__c, Configuration_Value__c FROM SFS_AB_Capacity_Settings__mdt
                                                      WHERE Configuration_Name__c =: DAYS_TO_BUILD_CAPACITY];

    static Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
    public static Date maxDate = System.Today().addDays(daysToBuild);
    public static Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();

    public void run(rflib_TriggerManager.Args args) {
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            converShiftTimeToLocalTimeOnInsert(args);
        }

        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
            createCapacityRebuildJobsforShiftInsert(args);
            createGenericInsert(args);
        }
        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {

            converShiftTimeToLocalTimeOnUpdate(args);
        }
        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
            createCapacityRebuildJobsforShiftUpdate(args);
            system.debug('shift update:');
            createGenericUpdate(args);
        }

        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
        }
        if (args.operation == System.TriggerOperation.AFTER_DELETE) {
            createCapacityRebuildJobsforShiftDelete(args);
        }
    }

    public static void converShiftTimeToLocalTimeOnInsert(rflib_TriggerManager.Args args) {
        string defaulttimeZone='America/New_York';
        Set<Id> serviceResourceIdSet=new Set<Id>();
        for (Shift Shift : (List<Shift>) args.newRecords) {
            serviceResourceIdSet.add(Shift.ServiceResourceId);
        }
        List<ServiceTerritoryMember> stmList=[select Id,ServiceResourceId, ServiceTerritory.OperatingHours.TimeZone from ServiceTerritoryMember where ServiceResourceId in : serviceResourceIdSet];
        Map<Id,String> serviceRsourceMap=new Map<Id,String>();
        for(ServiceTerritoryMember stm:stmList)
            serviceRsourceMap.put(stm.ServiceResourceId,stm.ServiceTerritory.OperatingHours.TimeZone);
        for (Shift Shift : (List<Shift>) args.newRecords) 
        {
                string resourceTimeZone=serviceRsourceMap.get(Shift.ServiceResourceId)==null?defaulttimeZone:serviceRsourceMap.get(Shift.ServiceResourceId);
                Shift.Local_Start_Time__c=HSCommonUtil.convertTimeZone(Shift.StartTime,resourceTimeZone);
                Shift.Local_End_Time__c=HSCommonUtil.convertTimeZone(Shift.EndTime,resourceTimeZone);
                Shift.StartDate__c=HSCommonUtil.convertTimeZoneDate(Shift.StartTime,resourceTimeZone);
                Shift.EndDate__c=HSCommonUtil.convertTimeZoneDate(Shift.EndTime,resourceTimeZone);
            //mm
        }
    
        }

        public static void converShiftTimeToLocalTimeOnUpdate(rflib_TriggerManager.Args args) {
            string defaulttimeZone='America/New_York';
            Set<Id> serviceResourceIdSet=new Set<Id>();
            for (Shift Shift : (List<Shift>) args.newRecords) {
                Shift oldShift = (Shift) args.oldRecordsMap.get(shift.Id);
                if(oldShift.StartTime!=Shift.StartTime || oldShift.EndTime!=Shift.EndTime )
                serviceResourceIdSet.add(Shift.ServiceResourceId);
            }
            List<ServiceTerritoryMember> stmList=[select Id,ServiceResourceId, ServiceTerritory.OperatingHours.TimeZone from ServiceTerritoryMember where ServiceResourceId in : serviceResourceIdSet];
            Map<Id,String> serviceRsourceMap=new Map<Id,String>();
            for(ServiceTerritoryMember stm:stmList)
                serviceRsourceMap.put(stm.ServiceResourceId,stm.ServiceTerritory.OperatingHours.TimeZone);
            for (Shift Shift : (List<Shift>) args.newRecords) 
            {

                    string resourceTimeZone=serviceRsourceMap.get(Shift.ServiceResourceId)==null?defaulttimeZone:serviceRsourceMap.get(Shift.ServiceResourceId);
                   System.debug('resourceTimeZone' +resourceTimeZone);
 Shift.Local_Start_Time__c=HSCommonUtil.convertTimeZone(Shift.StartTime,resourceTimeZone);
                    Shift.Local_End_Time__c=HSCommonUtil.convertTimeZone(Shift.EndTime,resourceTimeZone);
                    Shift.StartDate__c=HSCommonUtil.convertTimeZoneDate(Shift.StartTime,resourceTimeZone);
                Shift.EndDate__c=HSCommonUtil.convertTimeZoneDate(Shift.EndTime,resourceTimeZone);
            }
        
            }
        

    public static void createGenericInsert(rflib_TriggerManager.Args args) {

        List<Shift_Insert_Platform_Event__e> shiftPEInsertList = new List<Shift_Insert_Platform_Event__e>();

        // Loop through the Shifts and add to the PE list
        for (Shift Shift : (List<Shift>) args.newRecords) {
            Shift_Insert_Platform_Event__e shiftPE = new Shift_Insert_Platform_Event__e();
            shiftPE.Service_Resource__c = shift.ServiceResourceId;
            shiftPE.Shift_Id__c = shift.id;
            shiftPE.Service_Territory__c = shift.ServiceTerritoryId;
            shiftPEInsertList.add(shiftPE);
        }

        try {
            List<Database.SaveResult> results = EventBus.publish(shiftPEInsertList);
        } catch (Exception E) {
            System.Debug('Error publishing Shift Insert Platform Event.  Error: ' + E);
        }
    }

    public static void createGenericUpdate(rflib_TriggerManager.Args args) {

        List<Shift_Update_Platform_Event__e> shiftPEUpdateList = new List<Shift_Update_Platform_Event__e>();

        // Loop through the Shifts and add to the PE list
        for (Shift Shift : (List<Shift>) args.newRecords) {
            Shift oldShift = (Shift) args.oldRecordsMap.get(shift.Id);

            if (oldShift.ServiceResourceId != shift.ServiceResourceId) {
                Shift_Update_Platform_Event__e shiftPE = new Shift_Update_Platform_Event__e();
                shiftPE.Service_Resource__c = shift.ServiceResourceId;
                shiftPE.Shift_Id__c = oldShift.id;
                shiftPE.Service_Territory__c = shift.ServiceTerritoryId;
                shiftPE.Service_Resource_Old__c = oldShift.ServiceResourceId;
                shiftPEUpdateList.add(shiftPE);
            }
        }

        try {
            List<Database.SaveResult> results = EventBus.publish(shiftPEUpdateList);
        } catch (Exception E) {
            System.Debug('Error publishing Shift Update Platform Event.  Error: ' + E);
        }
    }

    //Create CapacityRebuild records on insert of Shift records
    public static void createCapacityRebuildJobsforShiftInsert(rflib_TriggerManager.Args args) {
        List<Shift> ShiftList = new List<Shift>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForShiftInsert = new List<Capacity_Rebuild_Job__c>();

        try {
            //Looping through the new Resource shifts records
            for (Shift Shift : (List<Shift>) args.newRecords) {
                if (Shift.Status == 'Confirmed' && Shift.StartTime.date() <= maxDate && Shift.EndTime.date() <= maxDate) {  
                    ShiftList.add(Shift);
                }
            }

            if (ShiftList != null && ShiftList.size() > 1) {
                for (Shift shift : ShiftList) {
                    capacityRebuildJobListForShiftInsert.add(SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Shift Insert', shift.ServiceResourceId, null, shift.StartTime.date(), shift.EndTime.date()));
                }
            } else if (ShiftList != null && ShiftList.size() == 1) {
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ ShiftList[0].ServiceResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    if (stmListForCapacityReCalculation[0].EffectiveEndDate == null
                        || ShiftList[0].EndTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                        || ShiftList[0].StartTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()) {
                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                                                                                                                        stmListForCapacityReCalculation[0].id,
                                                                                                                        ShiftList[0].StartTime.date(),
                                                                                                                        ShiftList[0].EndTime.date());

                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                                                                                                                        null,
                                                                                                                        capacityRebuildDateMap.minDate,
                                                                                                                        capacityRebuildDateMap.maxDate,
                                                                                                                        capacityRebuildDateMap.recordIdToDateMap);

                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                                                                                stmListForCapacityReCalculation[0].serviceterritoryId,
                                                                                System.today(),
                                                                                ShiftList[0].EndTime.date());

                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(stmListForCapacityReCalculation[0].serviceterritoryId, new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), ShiftList[0].EndTime.date()));
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    //Ending stmListForCapacityReCalculation if condition
                    capacityRebuildJobListForShiftInsert.add(SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('shift Insert', ShiftList[0].ServiceResourceId, null, ShiftList[0].StartTime.date(), ShiftList[0].EndTime.date()));
                }
            }
            if (capacityRebuildJobListForShiftInsert != null && capacityRebuildJobListForShiftInsert.size() > 0) {
                insert capacityRebuildJobListForShiftInsert;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }

    //Create CapacityRebuild records on delete of Shift records
    public static void createCapacityRebuildJobsforShiftDelete(rflib_TriggerManager.Args args) {
        List<Shift> ShiftList = new List<Shift>();
        List<Resource_Capacity__c> resourceCapacityListToDelete = new List<Resource_Capacity__c>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForShiftInsert = new List<Capacity_Rebuild_Job__c>();

        try {
            //Looping through the old Resource shifts records
            for (Shift Shift : (List<Shift>) args.oldRecords) {
                if (Shift.Status == 'Confirmed' && Shift.StartTime.date() <= maxDate && Shift.EndTime.date() <= maxDate) {
                    ShiftList.add(Shift);
                }
            }

            if (ShiftList != null && ShiftList.size() > 1) {
                System.Debug('ShiftList > 1: ');
                for (Shift shift : ShiftList) {
                    capacityRebuildJobListForShiftInsert.add(SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Shift Delete', shift.ServiceResourceId, null, shift.StartTime.date(), shift.EndTime.date()));
                }
            } else if (ShiftList != null && ShiftList.size() == 1) {
                System.Debug('ShiftList == 1: ');
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ ShiftList[0].ServiceResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    System.Debug('stmListForCapacityReCalculation == 1: ');
                    if (stmListForCapacityReCalculation[0].EffectiveEndDate == null
                        || ShiftList[0].EndTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                        || ShiftList[0].StartTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()) {

                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                                                                                                                        stmListForCapacityReCalculation[0].id,
                                                                                                                        ShiftList[0].StartTime.date(),
                                                                                                                        ShiftList[0].EndTime.date());
        
                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                                                                                                                        null,
                                                                                                                        capacityRebuildDateMap.minDate,
                                                                                                                        capacityRebuildDateMap.maxDate,
                                                                                                                        capacityRebuildDateMap.recordIdToDateMap);

                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        System.Debug('rsWrapper: ' + rsWrapper);
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                                                                                stmListForCapacityReCalculation[0].serviceterritoryId,
                                                                                System.today(),
                                                                                ShiftList[0].EndTime.date());

                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(stmListForCapacityReCalculation[0].serviceterritoryId, new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), ShiftList[0].EndTime.date()));
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    System.Debug('stmListForCapacityReCalculation > 1: ');
                    //Ending stmListForCapacityReCalculation if condition
                    capacityRebuildJobListForShiftInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('shift Delete', ShiftList[0].ServiceResourceId, null, ShiftList[0].StartTime.date(), ShiftList[0].EndTime.date())
                    );
                }
            }
            if (capacityRebuildJobListForShiftInsert != null && capacityRebuildJobListForShiftInsert.size() > 0) {
                insert capacityRebuildJobListForShiftInsert;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }

    //Create CapacityRebuild records on start time or end time update of Shift records
    public static void createCapacityRebuildJobsforShiftUpdate(rflib_TriggerManager.Args args) {
        List<Shift> ShiftList = new List<Shift>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForShiftInsert = new List<Capacity_Rebuild_Job__c>();

        try {
            //Looping through the new Resource shifts records
            for (Shift Shift : (List<Shift>) args.newRecords) {
                //Get old record
                Shift oldrec = (Shift) args.oldRecordsMap.get(Shift.Id);
                if (oldrec.Status != shift.Status && Shift.Status == 'Confirmed' && Shift.StartTime.date() <= maxDate && Shift.EndTime.date() <= maxDate) {
                    ShiftList.add(Shift);
                }
            }

            if (ShiftList != null && ShiftList.size() > 1) {
                system.debug('ShiftList > 1:');
                for (Shift shift : ShiftList) {
                    Shift oldrec = (Shift) args.oldRecordsMap.get(Shift.Id);
                    Date rebuildStartDt = shift.StartTime.date() > oldrec.StartTime.date() ? oldrec.StartTime.date() : shift.StartTime.date();
                    Date rebuildEndDt = shift.EndTime.date() < oldrec.EndTime.date() ? oldrec.EndTime.date() : shift.EndTime.date();
                    capacityRebuildJobListForShiftInsert.add(SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Shift Update', shift.ServiceResourceId, null, rebuildStartDt, rebuildEndDt));
                }
            } else if (ShiftList != null && ShiftList.size() == 1) {
                system.debug('ShiftList = 1:');
                List<ServiceTerritoryMember> stmListForCapacityReCalculation = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ ShiftList[0].ServiceResourceId }, null);
                if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() == 1) {
                    system.debug('stmListForCapacityReCalculation = 1:');
                    if (stmListForCapacityReCalculation[0].EffectiveEndDate == null
                        || ShiftList[0].EndTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()
                        || ShiftList[0].StartTime.date() <= stmListForCapacityReCalculation[0].EffectiveEndDate.date()) {

                        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                                                                                                                        stmListForCapacityReCalculation[0].id,
                                                                                                                        ShiftList[0].StartTime.date(),
                                                                                                                        ShiftList[0].EndTime.date());

                        //Create or update the Resource Capacity
                        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                                                                                                                        null,
                                                                                                                        capacityRebuildDateMap.minDate,
                                                                                                                        capacityRebuildDateMap.maxDate,
                                                                                                                        capacityRebuildDateMap.recordIdToDateMap);

                        if (rsWrapper != null && rsWrapper.resourceCapacityForInsert != null && rsWrapper.resourceCapacityForInsert.size() > 0) {
                            insert rsWrapper.resourceCapacityForInsert;
                        }
                        if (rsWrapper != null && rsWrapper.resourceCapacityForUpdate != null && rsWrapper.resourceCapacityForUpdate.size() > 0) {
                            update rsWrapper.resourceCapacityForUpdate;
                        }
                        //Update the Consumed Capacity logic
                        List<Consumed_Capacity__c> consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                                                                                stmListForCapacityReCalculation[0].serviceterritoryId,
                                                                                System.today(),
                                                                                ShiftList[0].EndTime.date());
                                                                                
                        if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                            territoryRebuildMap.put(stmListForCapacityReCalculation[0].serviceterritoryId, new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), ShiftList[0].EndTime.date()));
                            SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                            List<Consumed_Capacity__c> updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                            if (updateConsumedCapacityList != null && updateConsumedCapacityList.size() > 0) {
                                update updateConsumedCapacityList;
                            }
                        }
                    }
                } else if (stmListForCapacityReCalculation != null && stmListForCapacityReCalculation.size() > 1) {
                    system.debug('stmListForCapacityReCalculation > 1:');
                    //Ending stmListForCapacityReCalculation if condition
                    Shift oldrec = (Shift) args.oldRecordsMap.get(ShiftList[0].Id);
                    Date rebuildStartDt = ShiftList[0].StartTime.date() > oldrec.StartTime.date() ? oldrec.StartTime.date() : ShiftList[0].StartTime.date();
                    Date rebuildEndDt = ShiftList[0].EndTime.date() < oldrec.EndTime.date() ? oldrec.EndTime.date() : ShiftList[0].EndTime.date();
                    capacityRebuildJobListForShiftInsert.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('shift Update', ShiftList[0].ServiceResourceId, null, rebuildStartDt, rebuildEndDt)
                    );
                }
            }

            if (capacityRebuildJobListForShiftInsert != null && capacityRebuildJobListForShiftInsert.size() > 0) {
                insert capacityRebuildJobListForShiftInsert;
            }
        } catch (Exception e) {
            System.Debug('Exception: ' + e);
        }
    }

    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
        return;
    }
}