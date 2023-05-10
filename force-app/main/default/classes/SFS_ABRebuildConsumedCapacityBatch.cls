global class SFS_ABRebuildConsumedCapacityBatch implements Database.Batchable<sObject>, Database.Stateful {

    final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    final string REBUILD_CC_TERRITORY_SIZE = 'RebuildCCTerritorySize';
    global Date startDate; // = System.today();  // REQUIRED
    global Date endDate; // REQUIRED
    global Set<ID> territoryIdsToRebuild;
    global Set<ID> currentTerritoryIdsToRebuild;
    public static Map<String, Decimal> appointmentConsumptionMap = new Map<String, Decimal>();
    public static Map<String, Decimal> UnscheduledappointmentConsumptionMap = new Map<String, Decimal>();
    public static Map<string, Decimal> unscheduleappointmentHoursCalculatedMap = new Map<string, Decimal> ();
    public Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
    public static Map<String, Decimal> territoryTotalConsumptionlMap = new Map<String, Decimal>();
    public Boolean territorySizeFlagforCC = false;
    public static Map<String, String> map_assigned_Slots_string = 
    new Map<String, String>{SFS_ABConstantUtil.Slot8To12 => SFS_ABConstantUtil.Slot0812AssignedMinutes, SFS_ABConstantUtil.Slot12To16 => SFS_ABConstantUtil.Slot1216AssignedMinutes, SFS_ABConstantUtil.Slot16To2030 => SFS_ABConstantUtil.Slot162030AssignedMinutes,SFS_ABConstantUtil.Slot2030To2230=>SFS_ABConstantUtil.Slot20302230AssignedMinutes};
    public static Map<String, String> map_Available_Slots_string =
    new Map<String, String>{SFS_ABConstantUtil.Slot8To12 => SFS_ABConstantUtil.Slot0812AvailMinutes, SFS_ABConstantUtil.Slot12To16 => SFS_ABConstantUtil.Slot1216AvailMinutes, SFS_ABConstantUtil.Slot16To2030 => SFS_ABConstantUtil.Slot162030AvailMinutes,SFS_ABConstantUtil.Slot2030To2230=>SFS_ABConstantUtil.Slot20302230AvailMinutes}; 
    public static final Time x8_TimeSlotTime = Time.newInstance(8, 0, 0, 0);
    public static final Time x12_TimeSlotTime = Time.newInstance(12, 0, 0, 0);
    public static final Time x16_TimeSlotTime = Time.newInstance(16, 0, 0, 0);
    public static final Time x2030_TimeSlotTime = Time.newInstance(20, 30, 0, 0);
    public static final Time x2230_TimeSlotTime = Time.newInstance(22, 30, 0, 0);
    
    public SFS_ABRebuildConsumedCapacityBatch(Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryMap, Boolean territorySizeFlag) {
        territoryIdsToRebuild = new Set<ID>();
        currentTerritoryIdsToRebuild = new Set<ID>();
        territorySizeFlagforCC = territorySizeFlag;
        territoryRebuildMap = territoryMap;
        territoryIdsToRebuild = territoryRebuildMap.keySet();
    }
    public SFS_ABRebuildConsumedCapacityBatch(){

    }
    
    //AW! Check this one again after removing organization
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String queryStr = queryMethod(territoryIdsToRebuild);
        Database.QueryLocator tempLocator;
        
        try {
            return Database.getQueryLocator(queryStr);
        } catch (Exception e) {
            System.debug('Query Exception: ' + e);
        }
        return tempLocator;
    }
    
    // Execute
    global void execute(Database.BatchableContext BC, List<Consumed_Capacity__c> ccList) {
        try {
            System.debug('execute>> ccList>>' + ccList);
            map<Id, Consumed_Capacity__c> consumedCapacityMap = new Map<Id, Consumed_Capacity__c>();
            ccList = rebuildCCBasedOnRCAndSA(ccList);
            System.debug(LoggingLevel.DEBUG, 'cclist size:' + ccList.size());
            if (ccList != null && ccList.size() > 0) {
                for (Consumed_Capacity__c ccRecord : ccList) {
                    consumedCapacityMap.put(ccRecord.id, ccRecord);
                }
            }
            if (consumedCapacityMap != null && consumedCapacityMap.size() > 0)
                update consumedCapacityMap.values();
        } catch (Exception e) {
            System.debug('Exception: ' + e);
        }
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
    }
    
    global void finish(Database.BatchableContext BC) {
        system.debug('territoryIdsToRebuild' + territoryIdsToRebuild);
        system.debug('currentTerritoryIdsToRebuild' + currentTerritoryIdsToRebuild);
        territoryIdsToRebuild.removeAll(currentTerritoryIdsToRebuild);
        if (territoryIdsToRebuild.size() > 0) {
            SFS_ABRebuildConsumedCapacityBatch comsumedCapacityBtach = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, territorySizeFlagforCC);
            Database.executeBatch(comsumedCapacityBtach, 50);
        }
        else if(!Test.isRunningTest())
        {
            System.scheduleBatch(new SFS_ABCapacityRebuildJobBatch('Batch1'), 'SFS_ABCapacityRebuildJobBatch - '+System.now().addSeconds(300), 5);
        }
    }
    
    public String queryMethod(Set<Id> territorySet) {
        Integer daysToBuild;
        Integer ccTerritorySize;
        List<SFS_AB_Capacity_Settings__mdt> appConfigList = [SELECT Id, Configuration_Name__c, Configuration_Value__c FROM SFS_AB_Capacity_Settings__mdt];
        for (SFS_AB_Capacity_Settings__mdt appConfig : appConfigList) {
            if (appConfig.Configuration_Name__c == DAYS_TO_BUILD_CAPACITY) {
                daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
            }
            if (appConfig.Configuration_Name__c == REBUILD_CC_TERRITORY_SIZE) {
                ccTerritorySize = Integer.valueOf(appConfig.Configuration_Value__c);
            }
        }
        
        for (Id territoryId : territorySet) {
            currentTerritoryIdsToRebuild.add(territoryId);
            if ((currentTerritoryIdsToRebuild.size() == ccTerritorySize) && territorySizeFlagforCC)
                break;
        }
        
        for (Id territoryId : currentTerritoryIdsToRebuild) {
            if (territoryRebuildMap.get(territoryId) != null) {
                startDate = startDate == null || territoryRebuildMap.get(territoryId).startDate < startDate ? territoryRebuildMap.get(territoryId).startDate : startDate;
                endDate = endDate == null || territoryRebuildMap.get(territoryId).endDate > endDate ? territoryRebuildMap.get(territoryId).endDate : endDate;
            }
        }
        
        //Build string and Query
        string query = 'SELECT Id,Capacity_Date__c,Active__c,Field__c,Capacity_Rule_Template__c,External_Id__c,IsOverridden__c,Max__c,Max_Rule__c,Object__c,Overall_Capacity__c, Overall_Capacity_Rule__c, Overall_Consumption__c, Parent_Consumed_Capacity__c, Release_X_Hours_Before__c, Release_X_Hours_Before_Rule__c, Rule_Consumption__c, Service_Territory__c, Type__c, Value__c,Parent_Consumed_Capacity__r.Overall_Capacity__c,Slots__c FROM Consumed_Capacity__c ';
        query += ' WHERE Capacity_Date__c >= :startDate AND Capacity_Date__c <= :endDate';
        if (currentTerritoryIdsToRebuild != null && currentTerritoryIdsToRebuild.size() > 0) {
            query = query + ' AND Service_Territory__c IN: currentTerritoryIdsToRebuild';
        }
        query = query + ' AND Service_Territory__c != NULL Order by Service_Territory__c, Type__c';
        system.debug('query>> ' + query);
        system.debug('startdate>' + startDate);
        system.debug('enddate>' + endDate);
        system.debug('territoryset>' + currentTerritoryIdsToRebuild);
        return query;
    }
    
    // ReCalc Method
    public List<Consumed_Capacity__c> rebuildCCBasedOnRCAndSA(List<Consumed_Capacity__c> ccList) {
        for(Consumed_Capacity__c cc: ccList)
            System.debug('cc '+cc.Capacity_Date__c+' '+cc);
        System.debug('rebuildCCBasedOnRCAndSA : ccList>> ' + ccList);
        // Vars
        Set<ID> territoryIdSet = new Set<ID>();
        Set<Id> parentCCIdSet = new Set<Id>();
        List<Consumed_Capacity__c> ccListToUpdate = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> orgCapacityRecords = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> territoryCapacityRecords = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> orgRuleBasedCapacityRecords = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> territoryRuleBasedCapacityRecords = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> dailyCCList = new List<Consumed_Capacity__c>();
        List<Consumed_Capacity__c> ruleCCList = new List<Consumed_Capacity__c>();
        Map<Id, Consumed_Capacity__c> parentCapacityMap = new Map<Id, Consumed_Capacity__c>();
        
        // Initial loop through the CC records
        for (Consumed_Capacity__c cc : ccList) {
            if (cc.Service_Territory__c != null) {
                territoryIdSet.add(cc.Service_Territory__c);
            }
            if (cc.Type__c == SFS_ABConstantUtil.Daily_Capacity)
                dailyCCList.add(cc);
            
            if (cc.Type__c == SFS_ABConstantUtil.Rule_Based_Capacity) {
                ruleCCList.add(cc);
                parentCCIdSet.add(cc.Parent_Consumed_Capacity__c);
            }
        }
        if (startDate == null && territoryRebuildMap.size() == 1) {
            startDate = System.today();
            endDate = territoryRebuildMap.values()[0].endDate;
        }
        System.debug('Start Date: ' + startDate);
        System.debug('End Date: ' + endDate);
        system.debug('TerrSet:' + territoryIdSet);
        
        CapacityRollupWrapper capacityRollupWrapper = rollUpResourceCapacitiesToTerritoryAndOrgs(territoryIdSet, startDate, endDate);
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        
        // Get the Service Appointments to run the Rules  Filter on Territory + Dates - closed, hold, pending closed
        // Map<Date, Map<Id, List<ServiceAppointment>>> appointmentData = getAppointmentData(territoryIdSet);
        Map<string,Decimal> appointmentDataMap= getAppointmentData(territoryIdSet);
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        
        //Looping over list and updating the Overall Capacity to be new value.
        system.debug('territoryTotalConsumptionlMap>> ' + territoryTotalConsumptionlMap);
        
        System.debug(LoggingLevel.DEBUG, 'about to start capacity loop');
        for (Consumed_Capacity__c cc : dailyCCList) {
            String mapAssignedTerritoryKeyString = cc.Service_Territory__c + '_' + cc.Capacity_Date__c+'_'+map_assigned_Slots_string.get(cc.Slots__c);
            String mapAvailableTerritoryKeyString = cc.Service_Territory__c + '_' + cc.Capacity_Date__c+'_'+map_Available_Slots_string.get(cc.Slots__c);
            
            System.debug('mapTerritoryKeyString '+mapAssignedTerritoryKeyString);
            System.debug('Service_Territory__c '+cc.Service_Territory__c);
            System.debug('Capacity_Date__c '+cc.Capacity_Date__c);
            
            if (cc.Type__c == SFS_ABConstantUtil.Daily_Capacity) {
                if (cc.Service_Territory__c != null) {
                    System.debug('Hereeeee');
                    if (capacityRollupWrapper.territoryLevelTotalCapacityMap != null && capacityRollupWrapper.territoryLevelTotalCapacityMap.containsKey(mapAvailableTerritoryKeyString)) {
                        System.debug('Hereeeee 1st if '+capacityRollupWrapper.territoryLevelTotalCapacityMap.get(mapAvailableTerritoryKeyString));
                        cc.Overall_Capacity__c = capacityRollupWrapper.territoryLevelTotalCapacityMap.get(mapAvailableTerritoryKeyString);
                    }
                }
                System.debug('Hereeeee 1st if cc '+cc);
                
                System.debug('territoryTotalConsumptionlMap 219'+territoryTotalConsumptionlMap);
                System.debug('UnscheduledappointmentConsumptionMap 220'+UnscheduledappointmentConsumptionMap);
                if (cc.Service_Territory__c != null && territoryTotalConsumptionlMap != null && territoryTotalConsumptionlMap.containsKey(mapAssignedTerritoryKeyString)) {
                    System.debug('222>> inside if');
                    cc.Overall_Consumption__c = territoryTotalConsumptionlMap.get(mapAssignedTerritoryKeyString);
                    if (UnscheduledappointmentConsumptionMap.get(mapAssignedTerritoryKeyString) != null) {
                        System.debug('225>> inside if');
                        cc.Overall_Consumption__c = cc.Overall_Consumption__c + UnscheduledappointmentConsumptionMap.get(mapAssignedTerritoryKeyString);
                    }
                }
                
                System.debug('219>>'+cc);
                System.debug('territoryCapacityRecords berfore add '+territoryCapacityRecords);
                territoryCapacityRecords.add(cc);
                System.debug('territoryCapacityRecords after add '+territoryCapacityRecords);
            }
            System.debug('territoryCapacityRecords after for '+territoryCapacityRecords);
        }
        
        ccListToUpdate.addAll(orgCapacityRecords);
        SYSTEM.debug('orgCapacityRecords>>' + orgCapacityRecords);
        System.debug('ccListToUpdate before add '+ccListToUpdate);
        System.debug('ccListToUpdate before add all '+territoryCapacityRecords);
        
        ccListToUpdate.addAll(territoryCapacityRecords);
        SYSTEM.debug('territoryCapacityRecords>>' + territoryCapacityRecords);
        
        try {
            system.debug('ccListToUpdate 270>> '+ccListToUpdate);
            if (ccListToUpdate != null && ccListToUpdate.Size() > 0)
            {
                system.debug('ccListToUpdate 273>> '+ccListToUpdate);
                update ccListToUpdate;
            }
        } catch (Exception ex) {
            system.debug(ex);
        }
        
        ccListToUpdate.clear();
        orgCapacityRecords.clear();
        territoryCapacityRecords.clear();
        
        if (ruleCCList != null && ruleCCList.size() > 0)
            parentCapacityMap = new Map<Id, Consumed_Capacity__c>([SELECT Id, Overall_Capacity__c FROM Consumed_Capacity__c WHERE Id IN :parentCCIdSet]);
        
        for (Consumed_Capacity__c cc : ruleCCList) {
            
            //Work Order Capacity Record - Territory Rule Based
            if (cc.Type__c == SFS_ABConstantUtil.Rule_Based_Capacity && cc.Service_Territory__c != null && parentCapacityMap.containsKey(cc.Parent_Consumed_Capacity__c)) {
                cc.Overall_Capacity_Rule__c = (cc.Max_Rule__c * 0.01) * (parentCapacityMap.get(cc.Parent_Consumed_Capacity__c)).Overall_Capacity__c;
                territoryRuleBasedCapacityRecords.add(cc);
            }
        }
        
        system.debug('territoryRuleBasedCapacityRecords>>> ' + territoryRuleBasedCapacityRecords);
        //Territory Rule Based Calculation
        for (Consumed_Capacity__c territoryRuleBasedCapacity : territoryRuleBasedCapacityRecords) {
            Date capacityDate = date.newinstance(
                territoryRuleBasedCapacity.Capacity_Date__c.year(),
                territoryRuleBasedCapacity.Capacity_Date__c.month(),
                territoryRuleBasedCapacity.Capacity_Date__c.day()
            );
            string ruleKey=territoryRuleBasedCapacity.Service_Territory__c  + '_' +capacityDate+'_'+ map_assigned_Slots_string.get(territoryRuleBasedCapacity.Slots__c)+'_'+territoryRuleBasedCapacity.Value__c;
            Decimal appointmentHours = 0;
            if (appointmentDataMap.containsKey(ruleKey)) {
                territoryRuleBasedCapacity.Rule_Consumption__c = (Decimal)appointmentDataMap.get(ruleKey);
            }
            if (unscheduleappointmentHoursCalculatedMap.get(ruleKey) != null) {
                System.debug('225>> inside if');
                territoryRuleBasedCapacity.Rule_Consumption__c =  territoryRuleBasedCapacity.Rule_Consumption__c - unscheduleappointmentHoursCalculatedMap.get(ruleKey);
            }
        }
        ccListToUpdate.addAll(orgRuleBasedCapacityRecords);
        SYSTEM.debug('orgRuleBasedCapacityRecords>>' + orgRuleBasedCapacityRecords);
        ccListToUpdate.addAll(territoryRuleBasedCapacityRecords);
        system.debug('territoryCapacityRecords>> ' + territoryRuleBasedCapacityRecords);
        SYSTEM.debug('ccListToUpdate>>' + ccListToUpdate);
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        return ccListToUpdate;
    }
    
    public static CapacityRollupWrapper rollUpResourceCapacitiesToTerritoryAndOrgs(Set<Id> territoryIds, Date startDate, Date endDate) {
        Map<String, Decimal> territoryTotalAvailMap = new Map<String, Decimal>();
        
        Decimal temptotal = 0.0;
        string teststring = '';
        list<Resource_Capacity__c> templist = new List<Resource_Capacity__c>();
        Date dt = System.today();
        
        String resourceCapacityString = 'SELECT Id,Service_Resource__c,Total_Capacity__c,Capacity_Date__c,Service_Territory__c,Availability_Before_Consumption__c,Assigned_Appointment_Minutes__c,Slot_08_12_Avail_Minutes__c,Slot_12_16_Avail_Minutes__c,Slot_16_2030_Avail_Minutes__c,Slot_2030_2230_Avail_Minutes__c,Slot_08_12_Assigned_Minutes__c,Slot_12_16_Assigned_Minutes__c,Slot_16_2030_Assigned_Minutes__c,Slot_2030_2230_Assigned_Minutes__c FROM Resource_Capacity__c';
        resourceCapacityString = resourceCapacityString + ' WHERE Capacity_Date__c >=:startDate AND Capacity_Date__c <=:endDate';
        
        if (territoryIds != null && territoryIds.size() > 0) {
            resourceCapacityString = resourceCapacityString + ' AND Service_Territory__c IN:territoryIds order by Availability_Before_Consumption__c';
        }
        System.debug('resourceCapacityString query '+resourceCapacityString);
        for (Resource_Capacity__c rc : Database.query(resourceCapacityString)) {
            System.debug('451>>rc '+rc);
            
            Decimal currentTotal = 0;
            //to add the territory consumption
            String territoryMapKey;
            currentTotal = 0;
            System.debug('499>> rc'+ rc);
            if (rc.Capacity_Date__c != null) {
                territoryMapKey = rc.Service_Territory__c + '_' + rc.Capacity_Date__c;//2023-03-01+
                
                System.debug('503>> territoryMapKey'+ territoryMapKey);
                System.debug('for 508>> territoryTotalConsumptionlMap '+territoryTotalConsumptionlMap);
                for(string assignedSlot :map_assigned_Slots_string.values())
                {
                    String assignedSlotKeyString = rc.Service_Territory__c + '_' + rc.Capacity_Date__c+'_'+assignedSlot;
                    System.debug('505>> assignedSlotKeyString not null' +assignedSlotKeyString);
                    currentTotal = 0;
                    if (territoryTotalConsumptionlMap != null && territoryTotalConsumptionlMap.size() > 0 && territoryTotalConsumptionlMap.containsKey(assignedSlotKeyString)) {
                        currentTotal = territoryTotalConsumptionlMap.get(assignedSlotKeyString);
                        if (rc.get(assignedSlot) != null) {
                            System.debug('511>>');
                            currentTotal = currentTotal + (Decimal)rc.get(assignedSlot);
                        }
                        territoryTotalConsumptionlMap.put(assignedSlotKeyString, currentTotal);
                    } else {
                        System.debug('516>>');
                        if (rc.get(assignedSlot) == null) {
                            System.debug('518>>');
                            currentTotal = 0;
                        } else {
                            System.debug('521>>');
                            currentTotal = (Decimal)rc.get(assignedSlot);
                        }
                        territoryTotalConsumptionlMap.put(assignedSlotKeyString, currentTotal);
                    }
                }
                for(string availableSlot :map_Available_Slots_string.values())
                {
                    String availableSlotKeyString = rc.Service_Territory__c + '_' + rc.Capacity_Date__c+'_'+availableSlot;
                    System.debug('526 territoryTotalAvailMap>>'+territoryTotalAvailMap);
                    System.debug('527 availableSlotKeyString>>'+availableSlotKeyString);
                    if (territoryTotalAvailMap != null && territoryTotalAvailMap.containsKey(availableSlotKeyString)) {
                        System.debug('529>>');
                        currentTotal = 0;
                        currentTotal = territoryTotalAvailMap.get(availableSlotKeyString);
                        if (rc.get(availableSlot)!= null) {
                            System.debug('533>> ');
                            currentTotal = currentTotal +(Decimal)rc.get(availableSlot);
                        }
                        territoryTotalAvailMap.put(availableSlotKeyString, currentTotal);
                    } else {
                        System.debug('538>> ');
                        if (rc.get(availableSlot) == null) {
                            System.debug('540>> ');
                            currentTotal = 0;
                        } else {
                            System.debug('543>> ');
                            currentTotal = (Decimal)rc.get(availableSlot);
                        }
                        territoryTotalAvailMap.put(availableSlotKeyString, currentTotal);
                    }
                }
                
            }
        } //ending for loop
        if (temptotal != null) {
            System.debug('temptotal ' + temptotal);
        }
        System.debug('territoryTotalConsumptionlMap>>' + territoryTotalConsumptionlMap);
        system.debug('territoryTotalAvailMap>> ' + territoryTotalAvailMap);
        CapacityRollupWrapper capacityWrapper = new CapacityRollupWrapper(territoryTotalAvailMap);
        territoryTotalAvailMap = new Map<String, Decimal>();
        system.debug('capacityWrapper>> ' + capacityWrapper);
        return capacityWrapper;
    }
    
    //To Get Appointment Data with hours for List of Territories
    public static  Map<string, Decimal> getAppointmentData(Set<Id> territoryIds) {
        //system.debug('getAppointmentData> organizationIds>>' + organizationIds);
        system.debug('getAppointmentData> territoryIds>>' + territoryIds);
        
        String query = 'SELECT Id,FSL__InJeopardyReason__c,Work_Type_Category__c,FSL__GanttLabel__c,parentrecordId,SchedStartTime,SchedEndTime,ServiceTerritoryId,ArrivalWindowStartTime,ArrivalWindowEndTime,DurationType,Duration,FSL__Duration_In_Minutes__c,Status,ServiceTerritory.OperatingHours.TimeZone FROM ServiceAppointment WHERE  Status != \'Complete\' AND (SchedStartTime >= TODAY OR ArrivalWindowStartTime >= TODAY)';
        if (territoryIds != null && territoryIds.size() > 0) {
            query = query + ' AND ServiceTerritoryId IN :territoryIds';
        }
        system.debug('getAppointmentData query>> ' + query);
        
        Map<Date, Map<Id, List<ServiceAppointment>>> appointmentHoursMap = new Map<Date, Map<Id, List<ServiceAppointment>>>();
        Map<string, Decimal> appointmentHoursCalculatedMap = new Map<string, Decimal> ();
        
        Date appointmentDate;
        string arrivalDateKey;
        for (ServiceAppointment appointment : Database.query(query)) {
            system.debug('appointment 584>>'+appointment);
            Decimal UnscheduledLocalConsumptionHour = 0;
            decimal varduration = 0.0;
            if (appointment.DurationType == 'Hours') {
                varduration = appointment.Duration * 60;
            } else {
                varduration = appointment.Duration;
            }
            
            string arrivalSlot='';
            if (appointment.SchedStartTime == null) {
                appointmentDate = date.newinstance(appointment.ArrivalWindowStartTime.year(), appointment.ArrivalWindowStartTime.month(), appointment.ArrivalWindowStartTime.day());
                // vandana
                
                
                Datetime tempArrStartDateTime = appointment.ArrivalWindowStartTime; //arrival start time
                
                DateTime localArrStartDateTime = DateTime.valueOfGMT(tempArrStartDateTime.format('yyyy-MM-dd HH:mm:ss', appointment.serviceTerritory.OperatingHours.TimeZone));
                
                Time startTime = localArrStartDateTime.timeGmt();
                if (startTime >= x8_TimeSlotTime && startTime< x12_TimeSlotTime) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot8To12;
                }
                else if (startTime >= x12_TimeSlotTime && startTime< x16_TimeSlotTime) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot12To16;
                }
                else if (startTime >= x16_TimeSlotTime && startTime< x2030_TimeSlotTime) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot16To2030;
                }
                else if (startTime >= x2030_TimeSlotTime && startTime< x2230_TimeSlotTime) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot2030To2230;
                }
                arrivalDateKey=appointmentDate+'_'+map_assigned_Slots_string.get(arrivalSlot);
                string appslotkeyOpen=appointment.ServiceTerritoryId + '_' +appointmentDate+'_'+ map_assigned_Slots_string.get(arrivalSlot)+'_'+appointment.Work_Type_Category__c;
                if (appointment.Status == SFS_ABConstantUtil.SA_OPEN) {
                    if (appointmentHoursCalculatedMap.containsKey(appslotkeyOpen)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(appslotkeyOpen)+varduration;
                        appointmentHoursCalculatedMap.put(appslotkeyOpen, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(appslotkeyOpen, varduration);
                    }
                }
                 if (appointment.Status == SFS_ABConstantUtil.SA_CANCELED) {
                    if (appointmentHoursCalculatedMap.containsKey(appslotkeyOpen)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(appslotkeyOpen)+0;
                        appointmentHoursCalculatedMap.put(appslotkeyOpen, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(appslotkeyOpen, 0);
                    }
                }
                
            }
            else 
            {
                appointmentDate = date.newinstance(appointment.SchedStartTime.year(), appointment.SchedStartTime.month(), appointment.SchedStartTime.day());
                Datetime tempStartDateTime = appointment.SchedStartTime; //shift start time
                Datetime tempEndDateTime = appointment.SchedEndTime;
                
                DateTime localEndDateTime = DateTime.valueOfGMT(tempEndDateTime.format('yyyy-MM-dd HH:mm:ss',appointment.serviceTerritory.OperatingHours.TimeZone));
                DateTime localStartDateTime = DateTime.valueOfGMT(tempStartDateTime.format('yyyy-MM-dd HH:mm:ss', appointment.serviceTerritory.OperatingHours.TimeZone));
                SFS_ABResourceCapacityTimeSlotUtil.HourSlotWrapper hWrapperRecord = new SFS_ABResourceCapacityTimeSlotUtil.HourSlotWrapper();
                hWrapperRecord.startTime = localStartDateTime.timeGmt();
                hWrapperRecord.endTime = localEndDateTime.timeGmt();
                
                SFS_ABResourceCapacityTimeSlotUtil.TimeSlotWrapper tWrapper = SFS_ABResourceCapacityTimeSlotUtil.shiftTimeSlotCreation(hWrapperRecord);
                arrivalDateKey=appointmentDate+'_'+map_assigned_Slots_string.get(arrivalSlot);
                if (tWrapper.X8_12_Slot_Minutes!=null) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot8To12;
                    String X8_12_Slot_Minutes_Key = appointment.ServiceTerritoryId + '_' +appointmentDate+'_'+ map_assigned_Slots_string.get(arrivalSlot)+'_'+appointment.Work_Type_Category__c;
                    if (appointmentHoursCalculatedMap.containsKey(X8_12_Slot_Minutes_Key)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(X8_12_Slot_Minutes_Key)+tWrapper.X8_12_Slot_Minutes;
                        appointmentHoursCalculatedMap.put(X8_12_Slot_Minutes_Key, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(X8_12_Slot_Minutes_Key, tWrapper.X8_12_Slot_Minutes);
                    }
                }
                if (tWrapper.X12_16_Slot_Minutes!=null) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot12To16;
                    String X12_16_Slot_Minutes_Key = appointment.ServiceTerritoryId + '_' +appointmentDate+'_'+ map_assigned_Slots_string.get(arrivalSlot)+'_'+appointment.Work_Type_Category__c;
                    if (appointmentHoursCalculatedMap.containsKey(X12_16_Slot_Minutes_Key)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(X12_16_Slot_Minutes_Key)+tWrapper.X12_16_Slot_Minutes;
                        appointmentHoursCalculatedMap.put(X12_16_Slot_Minutes_Key, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(X12_16_Slot_Minutes_Key, tWrapper.X12_16_Slot_Minutes);
                    }
                }
                if (tWrapper.X16_2030_Slot_Minutes!=null) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot16To2030;
                    String X16_2030_Slot_Minutes_Key = appointment.ServiceTerritoryId + '_' +appointmentDate+'_'+ map_assigned_Slots_string.get(arrivalSlot)+'_'+appointment.Work_Type_Category__c;
                    if (appointmentHoursCalculatedMap.containsKey(X16_2030_Slot_Minutes_Key)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(X16_2030_Slot_Minutes_Key)+tWrapper.X16_2030_Slot_Minutes;
                        appointmentHoursCalculatedMap.put(X16_2030_Slot_Minutes_Key, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(X16_2030_Slot_Minutes_Key, tWrapper.X16_2030_Slot_Minutes);
                    }
                }
                if (tWrapper.X2030_2230_Slot_Minutes!=null) 
                {
                    arrivalSlot=SFS_ABConstantUtil.Slot2030To2230;
                    String X2030_2230_Slot_Minutes_Key = appointment.ServiceTerritoryId + '_' +appointmentDate+'_'+ map_assigned_Slots_string.get(arrivalSlot)+'_'+appointment.Work_Type_Category__c;
                    if (appointmentHoursCalculatedMap.containsKey(X2030_2230_Slot_Minutes_Key)) {
                        Decimal tTime=(Decimal)appointmentHoursCalculatedMap.get(X2030_2230_Slot_Minutes_Key)+tWrapper.X2030_2230_Slot_Minutes;
                        appointmentHoursCalculatedMap.put(X2030_2230_Slot_Minutes_Key, tTime);
                    }
                    else{
                        appointmentHoursCalculatedMap.put(X2030_2230_Slot_Minutes_Key, tWrapper.X2030_2230_Slot_Minutes);
                    }
                }
                
            }
            
            String localConsumptionMapKey = appointment.ServiceTerritoryId + '_' + arrivalDateKey;
            if (appointment.Status == SFS_ABConstantUtil.SA_OPEN) {
                system.debug('645>>');
                if (UnscheduledappointmentConsumptionMap.containsKey(localConsumptionMapKey)) {
                    system.debug('647>>');
                    UnscheduledLocalConsumptionHour = UnscheduledappointmentConsumptionMap.get(localConsumptionMapKey);
                    Decimal LocalCalForUnscheduledConsump = UnscheduledLocalConsumptionHour + varduration;
                    UnscheduledappointmentConsumptionMap.put(localConsumptionMapKey, LocalCalForUnscheduledConsump);
                } else {
                    system.debug('652>>');
                    UnscheduledappointmentConsumptionMap.put(localConsumptionMapKey, varduration);
                }
            }
        }
        system.debug('appointmentHoursMap>>> ' + appointmentHoursMap);
        system.debug('appointmentHoursCalculatedMap>>> ' + appointmentHoursCalculatedMap);
        
        System.debug('UnscheduledappointmentConsumptionMap >>' + UnscheduledappointmentConsumptionMap);
        return appointmentHoursCalculatedMap;
    }
    
    public class CapacityRollupWrapper {
        
        public Map<String, Decimal> territoryLevelTotalCapacityMap = new Map<String, Decimal>();
        
        CapacityRollupWrapper(Map<String, Decimal> territoryParamMap) {
            territoryLevelTotalCapacityMap = territoryParamMap;
        }
    }
    
}