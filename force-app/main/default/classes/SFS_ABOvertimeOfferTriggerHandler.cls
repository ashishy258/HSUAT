public class SFS_ABOvertimeOfferTriggerHandler implements rflib_TriggerHandler{
    private static final rflib_Logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('SFS_ABOvertimeOfferTriggerHandler');
    public void run(rflib_TriggerManager.Args triggerArguments) {
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_INSERT) {
            
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_UPDATE) {
            LOGGER.info('CALLING AFTER UPDATE');
            createOvertimeShifts(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.BEFORE_INSERT) {
            updateRecallDateToCurrentDatetime(triggerArguments);
            converOvertimeOfferTimeToLocalTime(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.BEFORE_UPDATE) {
            updateRecallDateToCurrentDatetime(triggerArguments);
            converOvertimeOfferTimeToLocalTime(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.BEFORE_DELETE) {
            //before delete methods
        }
        
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_DELETE) {
            //after delete methods
        }
    }
    
    public static void createOvertimeShifts(rflib_TriggerManager.Args triggerArguments) {
        Set<Date> setShiftDates = new Set<Date>();
        Set<Id> setServiceResource = new Set<Id>();
        Map<String, Shift> serviceResourceShift = new Map<String, Shift>();
        Map<String, Overtime_Offers__c> resIdToOvertimeMap = new Map<String, Overtime_Offers__c>();
        Map<Id, Shift> deleteShifts = new Map<Id, Shift>();
        List<Shift> insertShifts = new List<Shift>();
        List<ResourceAbsence> absences = new List<ResourceAbsence>();

        for (Overtime_Offers__c ov : (List<Overtime_Offers__c>) triggerArguments.newRecords) {
            //Get old record
            Overtime_Offers__c oldrec = (Overtime_Offers__c) triggerArguments.oldRecordsMap.get(ov.Id);
            if (oldrec.Status__c == SFS_ABConstantUtil.OVERTIME_OFFERED && ov.Status__c == SFS_ABConstantUtil.OVERTIME_HIRED && ov.Offer_Start_Time__c != null && ov.Offer_Finish_Time__c!=null) {
                setServiceResource.add(ov.Service_Resource__c);
                setShiftDates.add(ov.Offer_Start_Time__c.Date());
                String resourceOverTime = ov.Service_Resource__c + '_' + String.valueOf(ov.Offer_Start_Time__c.Date());
                resIdToOvertimeMap.put(resourceOverTime, ov);
            }
        }

        for (Shift shift : [SELECT Id, StartTime, EndTime, Status, ServiceResourceId FROM Shift WHERE DAY_ONLY(StartTime) IN :setShiftDates AND ServiceResourceId IN :setServiceResource]) {
            String resourceShiftForDate = shift.ServiceResourceId + '_' + String.valueOf(shift.StartTime.date());
            serviceResourceShift.put(resourceShiftForDate, shift);
        }

        for (String resourceOverTime : resIdToOvertimeMap.keySet()) {
            Shift resourceShift = serviceResourceShift.get(resourceOverTime);
            if (resourceShift == null) {
                Overtime_Offers__c overtimeOffer = resIdToOvertimeMap.get(resourceOverTime);
                Shift overtimeShift = new Shift();
                overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                overtimeShift.StartTime = overtimeOffer.Offer_Start_Time__c;
                overtimeShift.EndTime = overtimeOffer.Offer_Finish_Time__c;
                insertShifts.add(overtimeShift);
            } else {
                Overtime_Offers__c overtimeOffer = resIdToOvertimeMap.get(resourceOverTime);
                if (resourceShift.Status == SFS_ABConstantUtil.SHIFT_TENTATIVE || resourceShift.Status == SFS_ABConstantUtil.SHIFT_PUBLISHED)//published
                {
                    deleteShifts.put(resourceShift.Id, resourceShift);
                    Shift overtimeShift = new Shift();
                    overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                    overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                    overtimeShift.StartTime = overtimeOffer.Offer_Start_Time__c;
                    overtimeShift.EndTime = overtimeOffer.Offer_Finish_Time__c;
                    insertShifts.add(overtimeShift);
                } else {
                    //overlapping
                    if (overtimeOffer.Offer_Start_Time__c >= resourceShift.StartTime && overtimeOffer.Offer_Start_Time__c <= resourceShift.EndTime /*&& overtimeOffer.Offer_Finish_Time__c>=resourceShift.EndTime*/) {
                        deleteShifts.put(resourceShift.Id, resourceShift);
                        Shift overtimeShift = new Shift();
                        overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                        overtimeShift.StartTime = resourceShift.StartTime;
                        overtimeShift.EndTime = overtimeOffer.Offer_Finish_Time__c > resourceShift.EndTime ? overtimeOffer.Offer_Finish_Time__c : resourceShift.EndTime;
                        overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                        insertShifts.add(overtimeShift);
                    }
                    //2 non mutual shifts
                    else if (overtimeOffer.Offer_Start_Time__c >= resourceShift.EndTime) {
                        deleteShifts.put(resourceShift.Id, resourceShift);

                        Shift overtimeShift = new Shift();
                        overtimeShift.StartTime = resourceShift.StartTime;
                        overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                        overtimeShift.EndTime = overtimeOffer.Offer_Finish_Time__c;
                        overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                        insertShifts.add(overtimeShift);

                        if (overtimeOffer.Offer_Start_Time__c > resourceShift.EndTime) {
                            ResourceAbsence resourceAbsence = new ResourceAbsence();
                            resourceAbsence.Start = resourceShift.EndTime;
                            resourceAbsence.End = overtimeOffer.Offer_Start_Time__c;
                            resourceAbsence.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
                            resourceAbsence.ResourceId = resourceShift.ServiceResourceId;
                            absences.add(resourceAbsence);
                        }
                    } else if (overtimeOffer.Offer_Start_Time__c <= resourceShift.StartTime && overtimeOffer.Offer_Finish_Time__c <= resourceShift.StartTime) {
                        deleteShifts.put(resourceShift.Id, resourceShift);

                        Shift overtimeShift = new Shift();
                        overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                        overtimeShift.StartTime = overtimeOffer.Offer_Start_Time__c;
                        overtimeShift.EndTime = resourceShift.EndTime;
                        overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                        insertShifts.add(overtimeShift);

                        ResourceAbsence resourceAbsence = new ResourceAbsence();
                        resourceAbsence.Start = overtimeOffer.Offer_Finish_Time__c;
                        resourceAbsence.End = resourceShift.StartTime;
                        resourceAbsence.RecordTypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
                        resourceAbsence.ResourceId = resourceShift.ServiceResourceId;
                        absences.add(resourceAbsence);
                    } else if (overtimeOffer.Offer_Start_Time__c <= resourceShift.StartTime && overtimeOffer.Offer_Finish_Time__c >= resourceShift.StartTime) {
                        deleteShifts.put(resourceShift.Id, resourceShift);

                        Shift overtimeShift = new Shift();
                        overtimeShift.ServiceResourceId = overtimeOffer.Service_Resource__c;
                        overtimeShift.StartTime = overtimeOffer.Offer_Start_Time__c;
                        overtimeShift.EndTime = overtimeOffer.Offer_Finish_Time__c > resourceShift.EndTime ? overtimeOffer.Offer_Finish_Time__c : resourceShift.EndTime;
                        overtimeShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
                        insertShifts.add(overtimeShift);
                    }
                }
            }
            if (deleteShifts != null) {
                Database.delete(deleteShifts.values());
            }
            if (insertShifts != null) {
                Database.insert(insertShifts);
            }
            if (absences != null) {
                Database.insert(absences);
            }
        }
    }

    public static void converOvertimeOfferTimeToLocalTime(rflib_TriggerManager.Args args) {
        string defaulttimeZone='America/New_York';
        Set<Id> serviceResourceIdSet=new Set<Id>();
        for (Overtime_Offers__c overtimeOffer : (List<Overtime_Offers__c>) args.newRecords) {
            serviceResourceIdSet.add(overtimeOffer.Service_Resource__c);
        }
        List<ServiceTerritoryMember> stmList=[SELECT Id, ServiceResourceId, ServiceTerritory.OperatingHours.TimeZone FROM ServiceTerritoryMember WHERE ServiceResourceId IN : serviceResourceIdSet];
        Map<Id,String> serviceRsourceMap=new Map<Id,String>();
        for(ServiceTerritoryMember stm : stmList){
            serviceRsourceMap.put(stm.ServiceResourceId, stm.ServiceTerritory.OperatingHours.TimeZone);
        }
        for (Overtime_Offers__c overtimeOffer : (List<Overtime_Offers__c>) args.newRecords){
            String resourceTimeZone = serviceRsourceMap.get(overtimeOffer.Service_Resource__c) == null ? defaulttimeZone : serviceRsourceMap.get(overtimeOffer.Service_Resource__c);
            overtimeOffer.Local_Start_Time__c = HSCommonUtil.convertTimeZone(overtimeOffer.Offer_Start_Time__c, resourceTimeZone);
            overtimeOffer.Local_End_Time__c = HSCommonUtil.convertTimeZone(overtimeOffer.Offer_Finish_Time__c, resourceTimeZone);
        }
    }
    
    public static void updateRecallDateToCurrentDatetime(rflib_TriggerManager.Args args){
        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            for (Overtime_Offers__c overtimeOffer : (List<Overtime_Offers__c>) args.newRecords) {
                Overtime_Offers__c oldOvertimeOffer = (Overtime_Offers__c) args.oldRecordsMap.get(overtimeOffer.Id);
                if(oldOvertimeOffer.Status__c == 'Offered' && overtimeOffer.Status__c == 'Recalled'){
                    overtimeOffer.Recall_Date__c = Datetime.now();
                }
            }
        }
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            for (Overtime_Offers__c overtimeOffer : (List<Overtime_Offers__c>) args.newRecords) {
                if(overtimeOffer.Status__c == 'Recalled'){
                    overtimeOffer.Recall_Date__c = Datetime.now();
                }
                else if(overtimeOffer.Status__c == 'Offered'){
                    overtimeOffer.Offer_Submit_Date__c = Datetime.now();
                }
            }
        }
    }
    
    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
    }
}