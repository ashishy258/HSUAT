public class SFS_ABServiceAppointmentTriggerHandler implements rflib_TriggerHandler {
    
    private static final rflib_logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('ABServiceAppointmentTriggerHandler');
    
    public void run(rflib_TriggerManager.Args args) {
        
        // BEFORE INSERT
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            System.debug('Before Insert ==> SFS_ABServiceAppointmentTriggerHandler');
            handleSABeforeInsert(args);
        }
        
        // BEFORE UPDATE
        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            System.debug('Before Update ==> SFS_ABServiceAppointmentTriggerHandler');
            handleSABeforeUpdate(args);
            setServiceAppointmentGanttIcon(args);
        }
        
        // BEFORE DELETE
        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            System.debug('Before Delete ==> SFS_ABServiceAppointmentTriggerHandler');
        }
        
        // AFTER INSERT
        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
            System.debug('After Insert ==> SFS_ABServiceAppointmentTriggerHandler');
        }
        
        // AFTER UPDATE
        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
            System.debug('After Update ==> SFS_ABServiceAppointmentTriggerHandler');
            handleSAAfterUpdate(args);
            invokeSAStatusChangePE(args);
            serviceAppAssignmentDelete(args);
            // Uncomment this for RSO
            invokeRSO(args);
            updateParentWorkOrderToCancelled(args);
            updateWorkOrderFields(args);
        }
        
        // AFTER DELETE
        if (args.operation == System.TriggerOperation.AFTER_DELETE) {
            System.debug('After Delete ==> SFS_ABServiceAppointmentTriggerHandler');
        }
    }
    
    public static void handleSABeforeUpdate(rflib_TriggerManager.Args args) {
        try {
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                
                if (oldServiceAppointmentRecord.Status != appointment.Status) {
                    // For Status Updates
                    //code to prevent the Unschedule for the status Confimed or later
                    String sastatusValue = SFS_HS_GlobalSettings__mdt.getInstance(SFS_ABConstantUtil.AssignedResourceLockStatus).Values__c;
                    system.debug('sastatusValue if ' + sastatusValue);
                    //code to reset the jeopardy
                    if (oldServiceAppointmentRecord.FSL__InJeopardy__c) {
                        appointment.FSL__InJeopardy__c = false;
                        appointment.FSL__InJeopardyReason__c = '';
                    }
                    //Setting SA Gantt Color as per Status
                    appointment.FSL__GanttColor__c = SFS_ABConstantUtil.SASTATUSCOLORS.get(appointment.Status);
                    
                    if (oldServiceAppointmentRecord.Status.tolowercase() != SFS_ABConstantUtil.NONE.tolowercase() && appointment.Status == null) {
                        string errorMessage = 'None is not a valid status.';
                        appointment.addError(errorMessage);
                    }
                    if (sastatusValue != null) {
                        List<String> saStatusToCheck = sastatusValue.trim().split(',');
                        if (saStatusToCheck.contains(oldServiceAppointmentRecord.STATUS.tolowercase()) && appointment.Status == SFS_ABConstantUtil.SA_OPEN) {
                            string errorMessage = 'Cannot change status from ' + oldServiceAppointmentRecord.STATUS + ' to Open';
                            appointment.addError(errorMessage);
                        }
                    }
                }
            }
        } catch (Exception ex) {
            System.debug('Exception in SFS_ABServiceAppointmentTriggerHandler before Insert ' + ex);
        }
    }
    
    public static void handleSABeforeInsert(rflib_TriggerManager.Args args) {
        try {
            //setting work order id with the parent record id
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                if (!FeatureManagement.checkPermission('Allow_Create_on_Service_Appointment')) {
                    string errorMessage = 'You do not have  appropriate permission to create Service Appointments.';
                    appointment.addError(errorMessage);
                }
                else
                    appointment.Work_Order__c = appointment.ParentRecordId;
            }
        } catch (Exception ex) {
            System.debug('Exception in SFS_ABServiceAppointmentTriggerHandler before Insert ' + ex);
        }
    }
    
    public static void handleSAAfterUpdate(rflib_TriggerManager.Args args) {
        try {
            
            Boolean fslScheduleSwitch = false;
            Boolean createSAChangeEvent = true;
            Set<Id> serviceAppointmentSet = new Set<Id>();
            Set<Id> workOrderSet = new Set<Id>();
            Map<Id, Id> appointmentToResourceMap = new Map<Id, Id>();
            Map<Id, AssignedResource> assignedResourceRecordMap = new Map<Id, AssignedResource>();
            Map<Id, WorkOrder> workOrderMap = new Map<Id, WorkOrder>();
            Map<Id, ServiceAppointment> serviceAppointmentMap = new Map<Id, ServiceAppointment>();
            Map<Id, ServiceResource> serviceResourceMap = new Map<Id, ServiceResource>();
            string FSL_SCHEDULE_SWITCH_CONFIG_NAME = 'FSL_Schedule_Switch';
            SFS_AB_Capacity_Settings__mdt appConfig = [
                SELECT Id, Configuration_Name__c, Configuration_Value__c, Enable_Flag__c
                FROM SFS_AB_Capacity_Settings__mdt
                WHERE Configuration_Name__c = :FSL_SCHEDULE_SWITCH_CONFIG_NAME
            ];
            
            if (appConfig != null && appConfig.Enable_Flag__c) {
                fslScheduleSwitch = true;
            }
            
            //Adding Ids into a Set to use in queries.
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                serviceAppointmentSet.add(appointment.Id);
                workOrderSet.add(appointment.ParentRecordId);
            }
            
            //Getting Assigned Resource Records in order to access the info for the technician assigned to each job.
            List<AssignedResource> assignedResourceList = [SELECT ServiceAppointmentId, ServiceResourceId, EstimatedTravelTime FROM AssignedResource WHERE ServiceAppointmentId IN :serviceAppointmentSet];
            
            if (!assignedResourceList.isEmpty() && assignedResourceList.size() > 0) {
                for (AssignedResource assignedResource : assignedResourceList) {
                    appointmentToResourceMap.put(assignedResource.ServiceAppointmentId, assignedResource.ServiceResourceId);
                    assignedResourceRecordMap.put(assignedResource.ServiceAppointmentId, assignedResource);
                }
                //Getting Service Resource Data.
                serviceResourceMap = new Map<Id, ServiceResource>([SELECT Id, Location.Id, Location.Name, Name FROM ServiceResource WHERE Id IN :appointmentToResourceMap.values()]);
            }
            
            //Creating a Service Appointment Map to access the lookup values since they are not provided to us in the trigger context.
            serviceAppointmentMap = new Map<Id, ServiceAppointment>([SELECT Id, LastModifiedBy.Name, ServiceTerritory.Name, Account.Name, ServiceTerritory.OperatingHours.TimeZone FROM ServiceAppointment WHERE Id IN :serviceAppointmentSet]);
            //Creating a Work Order Map due to the fact that the Parent Record Id on the Service Appointment can be something other than
            //a work order so we are being more explicit here.
            workOrderMap = new Map<Id, WorkOrder>([SELECT Id, Status, WorkOrderNumber FROM WorkOrder WHERE Id IN :workOrderSet]);
            List<Service_Appointment_Change__e> serviceAppointmentChangePEList = new List<Service_Appointment_Change__e>();
            //List<ServiceAppointmentStatusChange__e> serviceAppointmentChangePEList = new List<ServiceAppointmentStatusChange__e>();
            System.debug('SA Record Size: ' + args.newRecords.size());
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                
                System.debug('old record: ' + oldServiceAppointmentRecord);
                System.debug('new record: ' + appointment);
                System.debug('old record status: ' + oldServiceAppointmentRecord.Status);
                System.debug('new record status: ' + appointment.Status);
                System.debug('old record status schedule time: ' + oldServiceAppointmentRecord.SchedStartTime);
                System.debug('new record status  schedule time: ' + appointment.SchedStartTime);
                
                Service_Appointment_Change__e serviceAppointmentChange = new Service_Appointment_Change__e();
                
                if (oldServiceAppointmentRecord.Status != appointment.Status) {
                    // For Status Updates
                    System.debug('status updates executed');
                    if (createSAChangeEvent) {
                        serviceAppointmentChange = setSAChangeEventData(oldServiceAppointmentRecord, appointment, serviceAppointmentMap, assignedResourceRecordMap, serviceResourceMap, workOrderMap, appointmentToResourceMap);
                        
                        serviceAppointmentChangePEList.add(serviceAppointmentChange);
                    }
                } else {
                    System.debug('General updates executed');
                    // For General Updates
                    if ((oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_SCHEDULED && appointment.Status == SFS_ABConstantUtil.SA_SCHEDULED &&
                         appointment.SchedStartTime != null && (appointment.SchedStartTime == oldServiceAppointmentRecord.SchedStartTime &&
                                                                appointment.SchedEndTime == oldServiceAppointmentRecord.SchedEndTime)) && appointment.ServiceTerritoryId == oldServiceAppointmentRecord.ServiceTerritoryId
                       ) {
                           System.debug('Prevent Addl. PE generation -2 ');
                           createSAChangeEvent = false;
                       }
                    if ((oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_OPEN && appointment.Status == SFS_ABConstantUtil.SA_OPEN &&
                         appointment.SchedStartTime != null && (appointment.SchedStartTime == oldServiceAppointmentRecord.SchedStartTime &&
                                                                appointment.SchedEndTime == oldServiceAppointmentRecord.SchedEndTime)) && appointment.ServiceTerritoryId == oldServiceAppointmentRecord.ServiceTerritoryId
                       ) {
                           System.debug('Prevent Addl. PE generation -2 ');
                           createSAChangeEvent = false;
                       }
                    if (oldServiceAppointmentRecord.Status == appointment.Status && appointment.Status == SFS_ABConstantUtil.SA_OPEN && oldServiceAppointmentRecord.SchedStartTime == null && appointment.SchedStartTime != null) {
                        createSAChangeEvent = false;
                    }
                    
                    if (oldServiceAppointmentRecord.Status == appointment.Status && appointment.Status == SFS_ABConstantUtil.SA_SCHEDULED && oldServiceAppointmentRecord.SchedStartTime != null && appointment.SchedStartTime == null) {
                        createSAChangeEvent = false;
                    }
                    if (createSAChangeEvent) {
                        serviceAppointmentChange = setSAChangeEventData(oldServiceAppointmentRecord, appointment, serviceAppointmentMap, assignedResourceRecordMap, serviceResourceMap, workOrderMap, appointmentToResourceMap);
                        System.debug('Creating serviceAppointmentChange record for genral updates ' + serviceAppointmentChange);
                        serviceAppointmentChangePEList.add(serviceAppointmentChange);
                    }
                }
                if (!serviceAppointmentChangePEList.isEmpty() && serviceAppointmentChangePEList.size() > 0) {
                    List<Database.SaveResult> results = EventBus.publish(serviceAppointmentChangePEList);
                    System.debug('Successfully published event. serviceAppointmentChangePEList for Status:  ' + serviceAppointmentChangePEList + 'size  ' + serviceAppointmentChangePEList.size());
                }
            }
        } catch (Exception ex) {
            System.debug('Exception: ' + ex);
        }
    }
    
    private static Service_Appointment_Change__e setSAChangeEventData(ServiceAppointment oldServiceAppointmentRecord, ServiceAppointment appointment, Map<Id, ServiceAppointment> serviceAppointmentMap, Map<Id, AssignedResource> assignedResourceRecordMap, Map<Id, ServiceResource> serviceResourceMap, Map<Id, WorkOrder> workOrderMap, Map<Id, Id> appointmentToResourceMap) {
        
        Service_Appointment_Change__e serviceAppointmentChange=new Service_Appointment_Change__e();
        serviceAppointmentChange.Previous_Status__c = oldServiceAppointmentRecord.Status;
        serviceAppointmentChange.New_Status__c = appointment.Status;
        serviceAppointmentChange.Actual_Duration_Mins__c = appointment.ActualDuration;
        serviceAppointmentChange.Duration_In_Minutes__c = appointment.DurationInMinutes;
        serviceAppointmentChange.Service_Territory_Id__c = appointment.ServiceTerritoryId;
        serviceAppointmentChange.Prev_Service_Territory_Id__c = oldServiceAppointmentRecord.ServiceTerritoryId;
        serviceAppointmentChange.Parent_Record_Id__c = appointment.ParentRecordId;
        serviceAppointmentChange.Service_Appointment_Id__c = appointment.Id;
        
        //Getting Time Zone associated with the job and using that to convert dates to that Time Zone.
        String timeZoneAssociatedToAppointment = serviceAppointmentMap.get(appointment.Id).ServiceTerritory.OperatingHours.TimeZone;
        if (timeZoneAssociatedToAppointment != null) {
            serviceAppointmentChange.Actual_End__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ActualEndTime);
            serviceAppointmentChange.Actual_Start__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ActualStartTime);
            serviceAppointmentChange.Arrival_Window_End__c =formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ArrivalWindowEndTime);//appointment.ArrivalWindowEndTime==null? formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, oldServiceAppointmentRecord.ArrivalWindowEndTime):formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ArrivalWindowEndTime);
            serviceAppointmentChange.Arrival_Window_Start__c =formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ArrivalWindowStartTime);//appointment.ArrivalWindowStartTime==null? formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, oldServiceAppointmentRecord.ArrivalWindowStartTime):formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.ArrivalWindowStartTime);// formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, oldServiceAppointmentRecord.ArrivalWindowStartTime);
            serviceAppointmentChange.Due_Date__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.DueDate);
            serviceAppointmentChange.Scheduled_End__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.SchedEndTime);
            serviceAppointmentChange.Scheduled_Start__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, appointment.SchedStartTime);
            serviceAppointmentChange.Prev_Scheduled_Start__c = formatDatesToAppointmentTimeZone(timeZoneAssociatedToAppointment, oldServiceAppointmentRecord.SchedStartTime);
        }
        
        //Accessing WorkOrder Object Map.
        if (workOrderMap.containsKey(appointment.ParentRecordId)) {
            serviceAppointmentChange.Work_Order_Id__c = appointment.ParentRecordId;
        }
        
        if (assignedResourceRecordMap.containsKey(appointment.Id)) {
            serviceAppointmentChange.Travel_Time_Mins__c = assignedResourceRecordMap.get(appointment.Id).EstimatedTravelTime;
        }
        
        //Accessing Service Resource Object Map.
        if (serviceResourceMap.containsKey(appointmentToResourceMap.get(appointment.Id))) {
            ServiceResource resource = serviceResourceMap.get(appointmentToResourceMap.get(appointment.Id));
            serviceAppointmentChange.Previous_Assigned_Id__c = resource.Id;
        }
        return serviceAppointmentChange;
    }
    
    public static DateTime convertDateTimeToTerritorysTZ(String timeZone, DateTime dateTimeValue) {
        String convertedTimeZoneString = dateTimeValue.format('yyyy-MM-dd HH:mm:ss', timeZone);
        DateTime finalConvertedDateTime = DateTime.valueOfGMT(convertedTimeZoneString);
        return finalConvertedDateTime;
    }
    
    public static String formatDatesToAppointmentTimeZone(String timeZone, DateTime dateTimeToConvert) {
        if (dateTimeToConvert != null) {
            String convertedDateTime = dateTimeToConvert.format('yyyy-MM-dd\'T\'HH:mm:ss', timeZone);
            return convertedDateTime;
        }
        return null;
    }
    
    // Uncomment this for RSO
     public static void invokeRSO(rflib_TriggerManager.Args args) {
        Set<Id> resourceIds = new Set<Id>();
        
        Datetime start = Datetime.newInstanceGmt(Datetime.now().dateGmt(), Time.newInstance(0,0,0,0));
        Datetime userStart =start;
        Datetime userFinish = start.addDays(2);
        System.debug('inside appt triggerhandler');
        for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
            ServiceAppointment oldrec = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
            System.debug('appointment.SchedEndTime '+appointment.SchedEndTime);
            System.debug('oldrec.SchedEndTime '+oldrec.SchedEndTime);
            System.debug('appointment.Status '+appointment.Status);
            System.debug('oldrec.Status '+oldrec.Status);
            //for late and early finish
            if ((   appointment.SchedEndTime != null
                 && oldrec.SchedEndTime != null)
                &&  appointment.Status == SFS_ABConstantUtil.SA_COMPLETED) {
                    Long diffWithNew = Math.abs(appointment.SchedEndTime.getTime() / 1000 / 60 - oldrec.SchedEndTime.getTime() / 1000 / 60);
                    System.debug('diffWithNew ' + diffWithNew);
                    if (oldrec.SchedEndTime != appointment.SchedEndTime
                        && appointment.SchedEndTime != null
                        && (diffWithNew >= 10)
                        && appointment.Assigned_Resource__c != null) {
                            resourceIds.add(appointment.Assigned_Resource__c);
                        }
                }
            // for cancellation
         
            else if(oldrec.SchedStartTime!=null
                    && appointment.Status==SFS_ABConstantUtil.SA_CANCELED
                    && appointment.Status!=oldrec.Status &&
                      oldrec.SchedStartTime.date()==System.today()){
                        {
                            resourceIds.add(appointment.Assigned_Resource__c);
                        }
                    }
            //for late or early arrival
            else if(appointment.Status==SFS_ABConstantUtil.SA_ONSITE && appointment.Status!=oldrec.Status && appointment.SchedStartTime!=null){
                Long diffWithNew = Math.abs(appointment.SchedStartTime.getTime() / 1000 / 60 - oldrec.SchedStartTime.getTime() / 1000 / 60);
                if(diffWithNew>=10){
                    resourceIds.add(appointment.Assigned_Resource__c);
                }
            }
            
        }
        System.debug('resourceIds.size() '+resourceIds.size());
        if(resourceIds.size()>0) {
            Id customerFirstId =[SELECT Id FROM FSL__Scheduling_Policy__c WHERE Name='Customer First' LIMIT 1].Id;
            if(customerFirstId !=null){
                List<RSO_PE__e> rsoPeList = new List<RSO_PE__e>();
                for(Id rId:resourceIds){
                    RSO_PE__e rsoEvent = new RSO_PE__e();
                    rsoEvent.StartTime__c=userStart;
                    rsoEvent.End_Time__c=userFinish;
                    rsoEvent.Resource_Id__c =rId;
                    rsoEvent.Scheduling_Policy__c=customerFirstId;
                    rsoPeList.add(rsoEvent);
                }
                System.debug('insert event list');
                List<Database.SaveResult> results = EventBus.publish(rsoPeList);
                
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('Successfully published event.');
                    } else {
                        for(Database.Error err : sr.getErrors()) {
                            System.debug('Error returned: ' + err.getStatusCode() );
                        }
                    }
                }
            }
        }
    }

    
    private static void invokeSAStatusChangePE(rflib_TriggerManager.Args args)
    {
        try{
            List<ServiceAppointmentStatusChange__e> statusChangeEventList = new List<ServiceAppointmentStatusChange__e>();
            
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                
                if (oldServiceAppointmentRecord.Status != appointment.Status){
                    
                    if(oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_SCHEDULED && appointment.Status == SFS_ABConstantUtil.SA_PRE_DISPATCHED
                       || oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_DISPATCHED && appointment.Status == SFS_ABConstantUtil.SA_CONFIRMED
                       || oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_CONFIRMED && appointment.Status == SFS_ABConstantUtil.SA_TRAVEL
                       || oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_CONFIRMED && appointment.Status == SFS_ABConstantUtil.SA_ONSITE
                       || oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_TRAVEL && appointment.Status == SFS_ABConstantUtil.SA_ONSITE
                       || oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_ONSITE && appointment.Status == SFS_ABConstantUtil.SA_COMPLETED)
                    {
                        ServiceAppointmentStatusChange__e serviceAppointmentStatusChange = new ServiceAppointmentStatusChange__e();
                        serviceAppointmentStatusChange.External_Id__c = appointment.External_ID__c;
                        serviceAppointmentStatusChange.Service_Appointment_ID__c = appointment.Id;
                        serviceAppointmentStatusChange.Status__c = appointment.Status;
                        
                        if (appointment.Status == SFS_ABConstantUtil.SA_COMPLETED) {
                            serviceAppointmentStatusChange.Outgoing_Type__c = 'AssignmentCompleted';
                        } else {
                            serviceAppointmentStatusChange.Outgoing_Type__c = 'AssignmentUpdate';
                        }
                        
                        statusChangeEventList.add(serviceAppointmentStatusChange);
                    }
                    
                }
                
            }
            
            if(statusChangeEventList.size() > 0){
                
                List<Database.SaveResult> results = EventBus.publish(statusChangeEventList);
                
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('Successfully published event.');
                    } else {
                        for(Database.Error err : sr.getErrors()) {
                            System.debug('Error returned: ' + err.getStatusCode() );
                        }
                    }
                }
            }
        }
        catch(Exception ex)
        {
            System.debug('Exception in SFS_ABServiceAppointmentTriggerHandler Publish Event '+ ex);
        }
    }

    private static void serviceAppAssignmentDelete(rflib_TriggerManager.Args args)
    {
        try{
            List<Service_Appointment_Unscheduled__e> saAssignmentDeleteEventList = new List<Service_Appointment_Unscheduled__e>();
            
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                
                if (oldServiceAppointmentRecord.Status == SFS_ABConstantUtil.SA_PRE_DISPATCHED && appointment.Status == SFS_ABConstantUtil.SA_OPEN){
                    Service_Appointment_Unscheduled__e saAssignmentDelete = new Service_Appointment_Unscheduled__e();
                    saAssignmentDelete.External_Id__c = appointment.External_ID__c;
                    saAssignmentDelete.Service_Appointment_ID__c = appointment.Id;
                    saAssignmentDelete.Status__c = appointment.Status;
                    saAssignmentDelete.Operation_Type__c = 'Unscheduled';
                    
                    saAssignmentDeleteEventList.add(saAssignmentDelete);
                    
                }
                
            }
            if(saAssignmentDeleteEventList.size() > 0){
                
                List<Database.SaveResult> results = EventBus.publish(saAssignmentDeleteEventList);
                
                for (Database.SaveResult sr : results) {
                    if (sr.isSuccess()) {
                        System.debug('Successfully published event.');
                    } else {
                        for(Database.Error err : sr.getErrors()) {
                            System.debug('Error returned: ' + err.getStatusCode() );
                        }
                    }
                }
            }
        }
        catch(Exception ex)
        {
            System.debug('Exception in SFS_ABServiceAppointmentTriggerHandler Publish Event '+ ex);
        }
    }
    
    public static void updateParentWorkOrderToCancelled(rflib_TriggerManager.Args args){
        Set<String> workOrderIdSet = new Set<String>();
        List<WorkOrder> workOrderList = new List<WorkOrder>();
        for (ServiceAppointment svcAppointment : (List<ServiceAppointment>) args.newRecords) {
            ServiceAppointment oldsvcAppointment = (ServiceAppointment) args.oldRecordsMap.get(svcAppointment.Id);
            if((oldsvcAppointment.status == 'Open'
                || oldsvcAppointment.status == 'Scheduled'
                || oldsvcAppointment.status == 'Pre-Dispatched'
                || oldsvcAppointment.status == 'Dispatched') && svcAppointment.status == 'Canceled'){
                    workOrderIdSet.add(svcAppointment.Work_Order__c);
                }
        }
        
        for(WorkOrder workOrderRec : [SELECT Id, Status FROM WorkOrder WHERE Id IN : workOrderIdSet]){
            workOrderRec.Status = 'Canceled';
            workOrderList.add(workOrderRec);
        }
        
        if(!workOrderList.isEmpty()){
            update workOrderList;
        }
    }
    public static void updateWorkOrderFields(rflib_TriggerManager.Args args) {
        Map<Id, ServiceAppointment> woIdToServiceAppointmentMap = new Map<Id, ServiceAppointment>();
        List<WorkOrder> workOrders = new List<WorkOrder>();
        for (ServiceAppointment svcAppointment : (List<ServiceAppointment>) args.newRecords) {
            ServiceAppointment oldsvcAppointment = (ServiceAppointment) args.oldRecordsMap.get(svcAppointment.Id);
            
            if ((oldsvcAppointment.Status != svcAppointment.Status) && (svcAppointment.Status == SFS_ABConstantUtil.SA_ONSITE || svcAppointment.Status == SFS_ABConstantUtil.SA_COMPLETED)) {
                woIdToServiceAppointmentMap.put(svcAppointment.Work_Order__c, svcAppointment);
            }
        }
        if (woIdToServiceAppointmentMap != null) {
            for (WorkOrder workOrderRec : [SELECT Id, Status, StartDate, EndDate FROM WorkOrder WHERE Id IN :woIdToServiceAppointmentMap.keySet()]) {
                ServiceAppointment sa = woIdToServiceAppointmentMap.get(workOrderRec.Id);
                if (sa.Status == SFS_ABConstantUtil.SA_ONSITE) {
                    workOrderRec.Status = SFS_ABConstantUtil.WO_INPROGRESS;
                    workOrderRec.StartDate = sa.ActualStartTime;
                    workOrders.add(workOrderRec);
                }
                if (sa.Status == SFS_ABConstantUtil.SA_COMPLETED) {
                    workOrderRec.Status = SFS_ABConstantUtil.WO_COMPLETED;
                    workOrderRec.EndDate = sa.ActualEndTime;
                    workOrders.add(workOrderRec);
                }
            }
            update workOrders;
        }
    }
    
    public static void setServiceAppointmentGanttIcon(rflib_TriggerManager.Args args) {
        try {
            Set<String> setGanttIcons = new Set<String>();
            Map<String, String> mapGanttIconURL = new Map<String, String>();
            Set<Id> setWorkTypeIds = new Set<Id>();
            
            for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                if (((oldServiceAppointmentRecord.Status != appointment.Status) && appointment.Status== SFS_ABConstantUtil.SA_SCHEDULED) ||(oldServiceAppointmentRecord.WorkTypeId != appointment.WorkTypeId)) {
                    LOGGER.info('SA changing from Open to Scheduled OR SA WorkType is changed');
                    setWorkTypeIds.add(appointment.WorkTypeId);
                }
            }
            
            if(setWorkTypeIds!= null)
            {
                Map<Id, WorkType> mapWorkTypes = new Map<Id, WorkType>([SELECT Id, Gantt_Icon__c FROM WorkType WHERE Id IN :setWorkTypeIds]);
                for(WorkType wt : mapWorkTypes.values())
                    setGanttIcons.add(wt.Gantt_Icon__c);
                
                LOGGER.info('Gantt Icons for WorkType{0})', new Object[]{setGanttIcons});
                
                String queryString = 'SELECT Name, NamespacePrefix, SystemModStamp FROM StaticResource WHERE Name IN ';
                queryString+=':setGanttIcons';
                
                List<StaticResource> staticResourceList = Database.query(queryString);
                LOGGER.info('Static Resources matching the WorkType Gantt Icons{0})', new Object[]{staticResourceList});
                if(staticResourceList.size() > 0){
                    for(StaticResource sr : staticResourceList){
                        // String iconURL = URL.getSalesforceBaseUrl().toExternalForm() + '/resource/'
                        //                 + String.valueOf(((DateTime)sr.get('SystemModStamp')).getTime())
                        //                 + '/'
                        //                 + sr.get('Name');
                        String iconURL = '/resource/' + sr.get('Name');
                        mapGanttIconURL.put(sr.Name, iconURL);
                    }
                }
                
                LOGGER.info('URLs for Gantt Icons{0})', new Object[]{mapGanttIconURL});
                
                for (ServiceAppointment appointment : (List<ServiceAppointment>) args.newRecords) {
                    ServiceAppointment oldServiceAppointmentRecord = (ServiceAppointment) args.oldRecordsMap.get(appointment.Id);
                    
                    if (((oldServiceAppointmentRecord.Status != appointment.Status) && appointment.Status== SFS_ABConstantUtil.SA_SCHEDULED) ||(oldServiceAppointmentRecord.WorkTypeId != appointment.WorkTypeId)) {
                        String icon = mapWorkTypes.get(appointment.WorkTypeId).Gantt_Icon__c;
                        String url = mapGanttIconURL.get(icon);
                        appointment.FSL__GanttIcon__c = mapGanttIconURL.get(icon);
                    }
                }
            }
        } catch (Exception ex) {
            LOGGER.error('Exception in SFS_ABServiceAppointmentTriggerHandler before Update({0})', new Object[]{ex});
        }
    }
    
    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
    }
}