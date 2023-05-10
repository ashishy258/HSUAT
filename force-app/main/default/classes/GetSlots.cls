@RestResource(UrlMapping = '/GetSlots/*')
global with sharing class GetSlots {

    global static Integer statusCode=400;
    private static final rflib_logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('ABGetSlots'); 

    @HttpPost
    global static void doPost() {
        
        RestRequest restReq = RestContext.request;
        String returnJson = '';
        ABWrapper.requestWrapper saWrapper = new ABWrapper.requestWrapper();
        try 
		{
            LOGGER.info('CALLING CUSTOM REST API: GET SLOTS');

            saWrapper = (ABWrapper.requestWrapper)JSON.deserialize(restReq.requestBody.toString(), ABWrapper.requestWrapper.class);
            if(saWrapper.serviceAppointmentNumber!=null)
			{
                returnJson = generateTimeSlots(saWrapper,false, false);
            }
        } 
		catch (Exception ex) 
		{
            LOGGER.error('EXCEPTION OCCURRED IN CUSTOM REST API: GET SLOTS({0})', new Object[]{ex});
            returnJson = JSON.serialize(ABUtil.setAppointmentSlotsWrapper(null, ABUtil.ERROR_MESSAGE, ABUtil.FAILURE_STATUS_CODE, null));
        }
        finally 
		{
            RestResponse res = RestContext.response;
            res.statusCode = statusCode;
            res.responseBody = Blob.valueOf(returnJson);
        }
    }
    
    public static String generateTimeSlots(ABWrapper.requestWrapper req,Boolean isTest, Boolean isSkipCalcTest){
        String returnResponse = '';
        String appointNumber ='';
        ABWrapper.responseWrapper responseWrap = new ABWrapper.responseWrapper();
        List <FSL.AppointmentBookingSlot> slots =new List <FSL.AppointmentBookingSlot>();
        List <ServiceAppointment> serviceAppointments = new List <ServiceAppointment>();
        try
		{
            serviceAppointments = ABUtil.getServiceAppointment(req.serviceAppointmentNumber);

            if(serviceAppointments.size() == 0) 
			{
                //In case of no service appointment
                LOGGER.info('SERVICE APPOINTMENT NOT FOUND');
                return JSON.serialize(ABUtil.setAppointmentSlotsWrapper(req.serviceAppointmentNumber, 
                                                                        ABUtil.NO_SERVICE_APPOINTMENT_FOUND, 
                                                                        ABUtil.NO_SERVICEAPPOINTMENT_STATUS_CODE,
                                                                        slots));
            }
            
            appointNumber = serviceAppointments[0].AppointmentNumber;
            
            //Fetching the default scheduling policy
            FSL__Scheduling_Policy__c policy = ABUtil.fetchSchedulingPolicy(false);
            if (policy == null){
                //Checking for valid Scheduling Policy
                LOGGER.info('INVALID SERVICE POLICY');
                return JSON.serialize(ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                        ABUtil.NO_SERVICEPOLICY,
                                                                        ABUtil.NO_SERVICEPOLICY_CODE,
                                                                        slots));  
            }
            
            if(serviceAppointments[0].Status != ABUtil.SA_STATUS_OPEN && serviceAppointments[0].Status != ABUtil.SA_STATUS_SCHEDULED ) 
            {
                //Checking for valid statuses for SA
                LOGGER.info('INVALID STATUS');
                return JSON.serialize(ABUtil.setAppointmentSlotsWrapper(appointNumber, 
                                                                        ABUtil.NOT_SCHEDULED_UNSCHEDULED,
                                                                        ABUtil.DIFFERENT_STATUS_CODE,
                                                                        slots));     
            }
            
            if (serviceAppointments[0].ServiceTerritory == null){
                //Checking for valid Service Territory
                LOGGER.info('NO SERVICE TERRITORY FOUND ON SA');
                return JSON.serialize(ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                        ABUtil.NO_SERVICETERRITORY,
                                                                        ABUtil.NO_SERVICE_TERRITORY_CODE,
                                                                        slots));
            }
            
            //String operatingHr = serviceAppointments[0].ServiceTerritory.OperatingHoursId;
            OperatingHours operatingHr = ABUtil.fetchOperatingHour();
            Timezone tz = TimeZone.getTimeZone(serviceAppointments[0].ServiceTerritory.OperatingHours.TimeZone);
            
            //Fetching the default operating hour
            if (policy != null && tz != null && operatingHr != null) {
                //Calling the OOTB GetSlots API
                LOGGER.info('ALL THE PARAMETERS PRESENT. POLICY, TIMEZONE AND OPERATING HOUR({0},{1},{2})', new Object[]{policy,tz,operatingHr});
                slots = FSL.AppointmentBookingService.getSlots(serviceAppointments[0].Id, policy.Id, operatingHr.Id, tz, false);
                
                if(isTest){
                    slots = getDefaultSlotsInfo();
                }
                
                if (slots != null && !slots.isEmpty()) {
                    List <FSL.AppointmentBookingSlot> slotsWithCapacityLimits = null;
                    LOGGER.info('OOTB SLOTS AVAILABLE');
                    LOGGER.info('OOTB SLOTS SIZE({0})', new Object[]{slots.size()});

                    //Get custom setting 
                    Decimal lastSlot = ABUtil.getLastSlotCustomSetting();

                    //Get current time of service territory
                    Map<Id, ServiceTerritory> territoryMap = new Map<Id, ServiceTerritory>();
                    Datetime currentDateTime = DateTime.newInstance(Datetime.now().year(), Datetime.now().month(), Datetime.now().day(), Datetime.now().hour(), Datetime.now().minute(), Datetime.now().second());
                    //Datetime currentDateTime = DateTime.newInstance(2023, 3, 10, 22, 15, 0);
                    //Datetime currentDateTime = DateTime.newInstance(2023, 3, 14, 11, 45, 0);
                    territoryMap.put(serviceAppointments[0].ServiceTerritory.Id, serviceAppointments[0].ServiceTerritory);
                    DateTime finalConvertedDateTime = SFS_ABUtil.convertDateTimeToTerritorysTZ(serviceAppointments[0], territoryMap, currentDateTime);
                    LOGGER.info('CURRENT DATE & TIME AS PER TERRITORY TIMEZONE({0})', new Object[]{finalConvertedDateTime});

                    List <FSL.AppointmentBookingSlot> slotsWithoutLast30Mins = new List <FSL.AppointmentBookingSlot>();
                    
                    for(FSL.AppointmentBookingSlot sl :slots){
                        if(sl.Interval.Start.day() == finalConvertedDateTime.day()){
                            Integer totalDiff = System.Math.abs(((sl.Interval.Finish.hour() - finalConvertedDateTime.hour())*60) + (sl.Interval.Finish.minute() - finalConvertedDateTime.minute()));
    
                            if(totalDiff > lastSlot){
                                //Eliminating slots with last 30 mins
                                slotsWithoutLast30Mins.add(sl);
                            }
                        }else{
                            slotsWithoutLast30Mins.add(sl);
                        }
                    }

                    LOGGER.info('SLOTS SIZE AFTER CONSIDERING LAST 3O MINS({0})', new Object[]{slotsWithoutLast30Mins.size()});

                    //Get boolean SkipCapacityCalc__c
                    //decide whether to skip or consider capacity limiters
                    boolean skipCapacityCalc = serviceAppointments[0].WorkType.SkipCapacityCalc__c;
                    if(isTest){
                        skipCapacityCalc = isSkipCalcTest;
                    }

                    if(skipCapacityCalc){
                        if(slotsWithoutLast30Mins.size() > 0){
                            LOGGER.info('SLOTS AVAILABLE. CAPACITY LIMITS NOT CONSIDERED');
                            LOGGER.info('SLOTS SIZE({0})', new Object[]{slotsWithoutLast30Mins.size()});
                            responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                             ABUtil.SUCCESSFULL,
                                                                             ABUtil.SUCCESS_STATUS_CODE,
                                                                             slotsWithoutLast30Mins);
                            
                            statusCode = 200;
                        }
                        else{
                            LOGGER.info('NO SLOT AVAILABLE. CAPACITY LIMITS NOT CONSIDERED');
                            responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                             ABUtil.NO_SLOTAVAILABLE,
                                                                             ABUtil.NO_SLOTS_AVAILABLE_CODE,
                                                                             slotsWithoutLast30Mins);
                        }
                    }
                    else{
                        if(isTest){
                            slotsWithCapacityLimits = ABUtil.checkConsumedCapacity(slotsWithoutLast30Mins, serviceAppointments[0], true);
                        }
                        else{
                            slotsWithCapacityLimits = ABUtil.checkConsumedCapacity(slotsWithoutLast30Mins, serviceAppointments[0], false);
                        }
                        
                        if(slotsWithCapacityLimits.size() > 0){
                            LOGGER.info('SLOTS AVAILABLE CONSIDERING CAPACITY LIMITS');
                            LOGGER.info('SLOTS SIZE({0})', new Object[]{slotsWithCapacityLimits.size()});
                            responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                             ABUtil.SUCCESSFULL,
                                                                             ABUtil.SUCCESS_STATUS_CODE,
                                                                             slotsWithCapacityLimits);
                            
                            statusCode = 200;
                        }
                        else{
                            LOGGER.info('NO SLOTS AVAILABLE CONSIDERING CAPACITY LIMITS');
                            responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                             ABUtil.NO_SLOTAVAILABLE,
                                                                             ABUtil.NO_SLOTS_AVAILABLE_CODE,
                                                                             slotsWithCapacityLimits);
                        }
                    }
                }
                else {
                    LOGGER.info('NO SLOT AVAIABLE');
                    responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                                     ABUtil.NO_SLOTAVAILABLE,
                                                                     ABUtil.NO_SLOTS_AVAILABLE_CODE,
                                                                     slots);
                }
            }   
        }
        catch(Exception e) {
            LOGGER.error('EXCEPTION OCCURRED IN FETCHING SLOT({0})', new Object[]{e});
            responseWrap = ABUtil.setAppointmentSlotsWrapper(appointNumber,
                                                             ABUtil.ERROR_MESSAGE,
                                                             ABUtil.FAILURE_STATUS_CODE,
                                                             null);
        }    
        
        returnResponse =JSON.serialize(responseWrap);
        return returnResponse.removeStart('"').removeEnd('"').replace('\\"','"');
        
    }
    
    public static List<FSL.AppointmentBookingSlot> getDefaultSlotsInfo(){
            
        LOGGER.info('CALLING METHOD TO CREATE DUMMY AB SLOTS FOR TESTING');
        List<FSL.AppointmentBookingSlot> slots = new List<FSL.AppointmentBookingSlot>();
        
        //Adding Slot 1
        FSL.AppointmentBookingSlot slot = new FSL.AppointmentBookingSlot();
        slot.grade = 100;
        
        Datetime dtNow = Datetime.now();
        Datetime dtStart = Datetime.newInstance(dtNow.year(), dtNow.month(), dtNow.day(), 3, 0, 0);
        Datetime dtFinish = dtStart.addMinutes(240);
        FSL.TimeInterval intervalTemp = new FSL.TimeInterval(dtStart, dtFinish);
        slot.interval = intervalTemp;
        slots.add(slot);

        //Adding Slot 2
        FSL.AppointmentBookingSlot slot2 = new FSL.AppointmentBookingSlot();
        slot2.grade = 100;
        
        Datetime dtNow2 = Datetime.now();
        Datetime dtStart2 = Datetime.newInstance(dtNow.year(), dtNow.month(), dtNow.day()+1, 3, 0, 0);
        Datetime dtFinish2 = dtStart2.addMinutes(240);
        FSL.TimeInterval intervalTemp2 = new FSL.TimeInterval(dtStart2, dtFinish2);
        slot2.interval = intervalTemp2;
        slots.add(slot2);
        return slots;
    }


}