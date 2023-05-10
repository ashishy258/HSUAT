@RestResource(UrlMapping='/BookSlots/*')
global with sharing class BookSlots {
    
    global static Integer statusCode = 400;
    private static final rflib_logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('ABBookSlots'); 
    
    @HttpPost
    global static void doPost() {
        
        String returnJson = '';
        RestRequest restReq = RestContext.request;
        ABWrapper.requestWrapper reqWrapper = new ABWrapper.requestWrapper();
        try {
            LOGGER.info('CALLING CUSTOM REST API: BOOK SLOTS');

            reqWrapper = (ABWrapper.requestWrapper)JSON.deserialize(restReq.requestBody.toString(), ABWrapper.requestWrapper.class);
            if(reqWrapper.serviceAppointmentNumber!=null){
                returnJson = bookAppointment(reqWrapper);
            }
            else{
                LOGGER.info('MISSING PARAMETER');
                returnJson = JSON.serialize(ABUtil.setBookApptResponseWrapper(null, ABUtil.MISSING_PARAMETER, ABUtil.MISSING_PARAMETER_CODE, null, null));
            }
        }
        catch (Exception ex) {
            LOGGER.error('EXCEPTION OCCURRED IN CUSTOM REST API: BOOK SLOTS({0})', new Object[]{ex});
            returnJson = JSON.serialize(ABUtil.setBookApptResponseWrapper(null, ABUtil.ERROR_MESSAGE, ABUtil.FAILURE_STATUS_CODE, null, null));
        }
        finally {
            RestResponse res = RestContext.response;
            res.statusCode = statusCode;
            res.responseBody = Blob.valueOf(returnJson);
        }
    }
    
    public static String bookAppointment(ABWrapper.requestWrapper req){
        Boolean isError=false;
        String appointNumber='';
        ServiceAppointment sa;
        List <FSL.AppointmentBookingSlot> slots =new List <FSL.AppointmentBookingSlot>();
        List <ServiceAppointment> serviceAppointments = new List<ServiceAppointment>();
        serviceAppointments = ABUtil.getServiceAppointment(req.serviceAppointmentNumber);
        ABWrapper.bookApptResponseWrapper bookResponse = new ABWrapper.bookApptResponseWrapper();
        
        // SA Check
        if(!isError && serviceAppointments != null && serviceAppointments.size()==0) {
            LOGGER.info('SERVICE APPOINTMENT NOT FOUND');
            isError = true;
            bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.NO_SERVICE_APPOINTMENT_FOUND, ABUtil.NO_SERVICEAPPOINTMENT_STATUS_CODE, null, null);
        }
        
        // Scheduling Policy Check
        FSL__Scheduling_Policy__c policy = ABUtil.fetchSchedulingPolicy(true);
        
        if(!isError && policy==null){
            LOGGER.info('INVALID SERVICE POLICY');
            isError = true;
            bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.NO_SERVICEPOLICY, ABUtil.NO_SERVICEPOLICY_CODE, null, null);
        }
        
        if(!isError){
            sa = serviceAppointments[0];
            appointNumber = sa.AppointmentNumber;
        }
        
        // Status Check
        if(!isError && sa.Status != ABUtil.SA_STATUS_OPEN && sa.Status != ABUtil.SA_STATUS_SCHEDULED){
            LOGGER.info('INVALID STATUS');
            isError = true;
            bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.NOT_SCHEDULED_UNSCHEDULED, ABUtil.DIFFERENT_STATUS_CODE, null, null);
        }
        
        if(!isError){
            // If all the checks are passed then go for Scheduling
            try{
                LOGGER.info('ALL THE PARAMETERS PRESENT FOR SCHEDULING. POLICY, AND SA({0},{1})', new Object[]{policy,sa});
                FSL.ScheduleResult myResult = new FSL.ScheduleResult();
                myResult = FSL.ScheduleService.schedule(policy.Id,sa.Id); //schedule the job
                if(myResult!= null && myResult.Resource!=null){
                    LOGGER.info('SCHEDULED SUCCESSFULLY');
                    bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.SUCCESSFULLY_SCHEDULED, ABUtil.SUCCESS_STATUS_CODE, myResult.Service.SchedStartTime, myResult.Service.SchedEndTime);
                    statusCode = 200;
                }
                else{
                    LOGGER.info('APPOINTMENT WAS NOT BOOKED SUCCESSFULLY. TRY SELECTING ANOTHER SLOT');
                    bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.APPOINTMENT_REQUEST_FAILED, ABUtil.APPOINTMENT_REQUEST_STATUS_CODE, null, null);
                }
            }
            catch (Exception ex){
                LOGGER.error('EXCEPTION OCCURRED IN BOOKING SLOT({0})', new Object[]{ex});
                bookResponse = ABUtil.setBookApptResponseWrapper(appointNumber, ABUtil.APPOINTMENT_REQUEST_FAILED, ABUtil.APPOINTMENT_REQUEST_STATUS_CODE, null, null);
            }
            
        }
        return JSON.serialize(bookResponse).removeStart('"').removeEnd('"').replace('\\"','"');
        
    }
}