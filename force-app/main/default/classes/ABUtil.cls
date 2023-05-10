public with sharing class ABUtil {
    
    private static final rflib_logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('ABUtil'); 

    public static final String dailyCapacityType  = 'Daily Capacity'; 
    public static final String ruleCapacityType  = 'Rule Based Capacity';
    
    public static final String POLICYNAME  = 'Customer First'; //Default policy Name
    public static final String OPERATINGHR  = 'HomeServe Appointment Hours'; //Default Operating Hour
    
    public static final String SA_STATUS_OPEN  = 'Open';
    public static final String SA_STATUS_SCHEDULED  = 'Scheduled';
    
    //Status Code
    public static final Integer FAILURE_STATUS_CODE  = 400;
    public static final Integer SUCCESS_STATUS_CODE  = 200;
    
    //Success message
    public static final String SUCCESSFULLY_SCHEDULED  = 'SCHEDULED SUCCESSFULLY'; 
    public static final String SUCCESSFULL  = 'GET SLOT SUCCESSFULL';
    
    //Fail message
    
    public static final String ERROR_MESSAGE = 'INVALID JSON';
    
    public static final String NO_SLOTAVAILABLE = 'NO SLOT AVAILABLE';
    public static final Integer NO_SLOTS_AVAILABLE_CODE  = 902;
    
    public static final String NO_SERVICETERRITORY = 'NO SERVICE TERRITORY FOUND ON SA';
    public static final Integer NO_SERVICE_TERRITORY_CODE  = 903;
    
    public static final String NOT_SCHEDULED_UNSCHEDULED = 'INVALID STATUS';
    public static final Integer DIFFERENT_STATUS_CODE  = 904;
    
    public static final String NO_SERVICEPOLICY = 'INVALID SERVICE POLICY';
    public static final Integer NO_SERVICEPOLICY_CODE  = 905;
    
    public static final String NO_SERVICE_APPOINTMENT_FOUND   = 'SERVICE APPOINTMENT NOT FOUND';
    public static final Integer NO_SERVICEAPPOINTMENT_STATUS_CODE  = 906;
    
    public static final String APPOINTMENT_REQUEST_FAILED  = 'APPOINTMENT WAS NOT BOOKED SUCCESSFULLY. TRY SELECTING ANOTHER SLOT.';
    public static final Integer APPOINTMENT_REQUEST_STATUS_CODE  = 907;
    
    public static final String MISSING_PARAMETER = 'MISSING PARAMETER';
    public static final Integer MISSING_PARAMETER_CODE = 908;
    
    
    public static List<ServiceAppointment> getServiceAppointment(String sANumber){
        LOGGER.info('CALLING getServiceAppointment FROM UTIL({0})', new Object[]{sANumber});
        String queryString = 'SELECT Id, AppointmentNumber, ParentRecordId, Status, DurationType, Duration,ArrivalWindowStartTime,ArrivalWindowEndTime,';
        queryString += ' ServiceTerritoryId, ServiceTerritory.OperatingHoursId, ServiceTerritory.OperatingHours.TimeZone, WorkType.Work_Type_Category__c, WorkType.SkipCapacityCalc__c, WorkType.Gantt_Icon__c FROM ServiceAppointment';
        queryString += ' WHERE Id =:sANumber';
        
        List <ServiceAppointment> saList = Database.query(queryString);
        return saList;
    }
    
    //Get the scheduling policy
    public static FSL__Scheduling_Policy__c fetchSchedulingPolicy(boolean bookSlot){
        List<FSL__Scheduling_Policy__c> policyRecord;
        if(bookSlot){
            policyRecord = [SELECT Id, Name from FSL__Scheduling_Policy__c where Used_for_Appointment_Booking__c = FALSE and FSL__Daily_Optimization__c = TRUE];
        }else{
            policyRecord = [SELECT Id, Name from FSL__Scheduling_Policy__c where Used_for_Appointment_Booking__c = TRUE and FSL__Daily_Optimization__c = FALSE];
        }

        if(policyRecord != null && policyRecord.Size()>0){
            return policyRecord[0];
        }
        else{
            for(FSL__Scheduling_Policy__c schedulingPolicyInstance:[SELECT Id, Name from FSL__Scheduling_Policy__c where Name =: POLICYNAME]) {
                return schedulingPolicyInstance;
            }
        }
        return null;
    }
    
    //Get the operating hour
    public static OperatingHours fetchOperatingHour(){
        
        List<OperatingHours> opHrRecord = [SELECT Id, Name from OperatingHours where Used_for_Appointment_Booking__c = TRUE LIMIT 1];
        
        if(opHrRecord != null && opHrRecord.Size()>0){
            return opHrRecord[0];
        }
        else{
            for(OperatingHours operatingHrInstance:[SELECT Id, Name from OperatingHours where Name =: OPERATINGHR]) {
                return operatingHrInstance;
            }
        }
        return null;
    }
    
    public static ABWrapper.responseWrapper setAppointmentSlotsWrapper(String sAppointment, String message, Integer statusCode, List <FSL.AppointmentBookingSlot> slots){
        ABWrapper.responseWrapper responsewrap = new ABWrapper.responseWrapper();
        responsewrap.saNumber = sAppointment;
        responsewrap.message = message ;
        responsewrap.statusCode = statusCode;
        if(slots != null && !slots.isEmpty()){
            for (FSL.AppointmentBookingSlot slot: slots){
                ABWrapper.slotInfo slotWrapper = new ABWrapper.slotInfo();
                
                slotWrapper.Start = slot.Interval.Start;
                slotWrapper.Finish = slot.Interval.Finish;
                responsewrap.slotInfoList.add(slotWrapper);
            }
        }
        
        return responsewrap;
    }
    
    public static ABWrapper.bookApptResponseWrapper setBookApptResponseWrapper(String serviceAppt, String message, Integer statusCode, Datetime scheduledStartTime, Datetime scheduledFinishTime){
        ABWrapper.bookApptResponseWrapper responseWrap = new ABWrapper.bookApptResponseWrapper();
        
        responseWrap.saNumber = serviceAppt;
        responseWrap.message = message;
        responseWrap.statusCode = statusCode;
        responseWrap.scheduledStartTime = scheduledStartTime;
        responseWrap.schedueledFinishTime = scheduledFinishTime;
        
        return responseWrap;
    }
    
    public static List <FSL.AppointmentBookingSlot> checkConsumedCapacity(List <FSL.AppointmentBookingSlot> slots, ServiceAppointment SA, boolean isTest){
        Map<String,Consumed_Capacity__c> dailyCapacityMap = new Map<String,Consumed_Capacity__c>();
        Map<String,Consumed_Capacity__c> ruleCapacityMap = new Map<String,Consumed_Capacity__c>();
        List<FSL.AppointmentBookingSlot> finalSlotsDateList = new List<FSL.AppointmentBookingSlot>();
        try
        {
            //Fetch WorkTypeCategory for SA
            String workTypeCategory = SA.WorkType.Work_Type_Category__c;
            LOGGER.info('SA WORKTYPE CATEGORY({0})', new Object[]{workTypeCategory});

            Id serviceTerritoryId = SA.ServiceTerritory.Id;
            LOGGER.info('SA SERVICE TERRITORY{0})', new Object[]{serviceTerritoryId});

            Map<String,List<FSL.AppointmentBookingSlot>> mapWithDateAndSlot1 = getDateFromDateTime(slots);
           
            Set<String> dateStrSet1= mapWithDateAndSlot1.keyset();
            Set<date> dateStrSet= new Set<date>();
            
            for (String str : dateStrSet1) {
                Date dt = Date.valueOf(str.substringBefore('_'));
                if(!dateStrSet.contains(dt)){
                    dateStrSet.add(dt);
                }
            }
            
            String queryString = 'SELECT Id, Name, Type__c, Is_Daily_Capacity_Available__c, Is_Rule_Based_Capacity_Available__c, Value__c, Capacity_Date__c, Active__c, Slots__c FROM Consumed_Capacity__c where Capacity_Date__c IN :dateStrSet';
            //Fetch active consumed capacity as per Capacity Date
            LOGGER.info('FETCHING ACTIVE CONSUMED CAPACITY FOR DATES({0})', new Object[]{dateStrSet});
            if(!isTest){
                queryString+= ' and Service_Territory__c =: serviceTerritoryId';
                queryString+= ' and Active__c = true order by Capacity_Date__c';
            }
            
            List<Consumed_Capacity__c > consumedCapacityRecs = Database.query(queryString);
            
            if(consumedCapacityRecs != null && consumedCapacityRecs.Size()>0){
                LOGGER.info('CONSUMED CAPACITY AVAILABLE');
                for(Consumed_Capacity__c ccr:consumedCapacityRecs)
                {
                    if(ccr.Type__c == dailyCapacityType && ccr.Is_Daily_Capacity_Available__c)
                    {
                        
                        string dailyStr = string.valueOf(ccr.Capacity_Date__c) +'_'+ccr.Slots__c;
                        
                        //Filtering Daily Consumed Capacity 
                        dailyCapacityMap.put(dailyStr,ccr);
                    }
                    if(ccr.Type__c == ruleCapacityType && ccr.Is_Rule_Based_Capacity_Available__c && ccr.Value__c == workTypeCategory)
                    {
                        
                        string ruleStr =  string.valueOf(ccr.Capacity_Date__c)  +'_'+ccr.Slots__c;
                        
                        //Filtering Rule-Based Consumed Capacity 
                        ruleCapacityMap.put(ruleStr,ccr);
                    }
                }
                LOGGER.info('SIZE OF DAILY CONSUMED CAPACITY AVAILABLE({0})', new Object[]{dailyCapacityMap.size()});
                
                LOGGER.info('SIZE OF RULE-BASED CONSUMED CAPACITY AVAILABLE({0})', new Object[]{ruleCapacityMap.size()});
                
                List <FSL.AppointmentBookingSlot> fslot = new List<FSL.AppointmentBookingSlot>();
                for (String ruleslotDate: ruleCapacityMap.keyset())
                {
                    LOGGER.info('RULE KEY({0})', new Object[]{ruleslotDate});
                    //Comparsion between Rule-Based and Daily Consumed Capacity
                    //and making sure all the Rule-Based CC is a part of Daily CC
                    
                    if(dailyCapacityMap.containsKey(ruleslotDate))
                    {   
                        fslot = mapWithDateAndSlot1.get(ruleslotDate);
                        if(fslot != null){
                            for(FSL.AppointmentBookingSlot sl:fslot){
                                finalSlotsDateList.add(sl);
                            } 
                        }
                    }
                }
            }
        }
        catch(Exception ex)
        {
            LOGGER.error('EXCEPTION OCCURRED IN FETCHING CONSUMED CAPACITY({0})', new Object[]{ex});
        }
        return finalSlotsDateList;       
    }
    
    public static Map<String,List<FSL.AppointmentBookingSlot>> getDateFromDateTime(List <FSL.AppointmentBookingSlot> slots){
        
        Map<Date,List<FSL.AppointmentBookingSlot>> dateStringMap = new Map<Date,List<FSL.AppointmentBookingSlot>>();
        Map<String,List<FSL.AppointmentBookingSlot>> dateStringMap1 = new Map<String,List<FSL.AppointmentBookingSlot>>();
        
        //This method takes Slots Datetime and returns them in Date format 
        
        for (FSL.AppointmentBookingSlot slot: slots){
            
            Date dateStrDate = date.newinstance(slot.Interval.Start.year(), slot.Interval.Start.month(), slot.Interval.Start.day());
            
            Datetime myDTStart = DateTime.newInstance(slot.Interval.Start.year(), slot.Interval.Start.month(), slot.Interval.Start.day(), slot.Interval.Start.hourGMT(), slot.Interval.Start.minuteGMT(), 55);
            List<String> startSlotList = myDTStart.format('yyyy-MM-dd h:mm a').split(' ');
            String startSlot = startSlotList[1] + startSlotList[2];
            
            Datetime myDTFinish = DateTime.newInstance(slot.Interval.Finish.year(), slot.Interval.Finish.month(), slot.Interval.Finish.day(), slot.Interval.Finish.hourGMT(), slot.Interval.Finish.minuteGMT(), 55);
            List<String> finishSlotList = myDTFinish.format('yyyy-MM-dd h:mm a').split(' ');
            String finishSlot = finishSlotList[1] + finishSlotList[2];
            
            string mapString = startSlotList[0]+'_'+startSlot+' - '+finishSlot;
            
            if(dateStringMap1.ContainsKey(mapString)){
                dateStringMap1.get(mapString).add(slot);
            }else{
                dateStringMap1.put(mapString, new List<FSL.AppointmentBookingSlot>{slot});
            }  
        }
        
        return dateStringMap1;
    }

    public static Decimal getLastSlotCustomSetting(){
        HS_AB_Last_Slot__c lastSlot = HS_AB_Last_Slot__c.getOrgDefaults();
        return lastSlot.Last_Slot__c;
    }
}