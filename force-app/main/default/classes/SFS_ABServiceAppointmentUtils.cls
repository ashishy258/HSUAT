public class SFS_ABServiceAppointmentUtils {
    
    public static List<ServiceAppointmentEvent> convertSAChangeEventToServiceAppointmentEvent(List<Service_Appointment_Change__e> oldList) {
        List<ServiceAppointmentEvent> returnList = new List<ServiceAppointmentEvent>();
        
        System.debug('convertSAChangeEventToServiceAppointmentEvent returnlist: ' + returnlist);
        
        for (Service_Appointment_Change__e o : oldList) {
            ServiceAppointmentEvent n = new ServiceAppointmentEvent();
            n.Prev_Service_Territory_Id = o.Prev_Service_Territory_Id__c;
            n.Service_Territory_Id = o.Service_Territory_Id__c;
            n.Service_Appointment_Id = o.Service_Appointment_Id__c;
            n.Previous_Status = o.Previous_Status__c;
            n.New_Status = o.New_Status__c;
            n.Scheduled_Start = o.Scheduled_Start__c;
            n.Prev_Scheduled_Start = o.Prev_Scheduled_Start__c;
            n.Scheduled_End = o.Scheduled_End__c;
            n.Prev_Scheduled_End = o.Prev_Scheduled_End__c;
            n.Work_Order_Id = o.Work_Order_Id__c;
            n.Duration_In_Minutes = String.valueOf(o.Actual_Duration_Mins__c);
            n.Arrival_Window_Start = o.Arrival_Window_Start__c;
            n.Arrival_Window_End = o.Arrival_Window_End__c;
            n.Previous_Assigned_Id = o.Previous_Assigned_Id__c;
            returnList.add(n);
        }
        System.debug('convertSAChangeEventToServiceAppointmentEvent returnlist: ' + returnlist);
        return returnlist;
    }
    
    
    public static void SAUpdateEvent(List<ServiceAppointmentEvent> sacList) {
        System.Debug('DWA: ServiceAppointmentUtils.SAUpdateEvent: starting for a PE');
        
        // Vars
        Set<Id> workOrderIds = new Set<Id>();
        Map<Id, ServiceAppointmentEvent> woIdToSACMap = new Map<Id, ServiceAppointmentEvent>();
       /* List<WorkOrder> updateWOList = new List<WorkOrder>();*/
        Map<Id, AssignedResource> saIDToSRIDMap = new Map<ID, AssignedResource>();
        Map<Id, List<Date>> territoryIdToRebuildDtMap = new Map<ID, List<Date>>();
        List<Capacity_Rebuild_Job__c> capacityRebuildJobListForSAUpdates = new List<Capacity_Rebuild_Job__c>();
        List<ServiceAppointmentEvent> serviceAptEventListForCapacityRebuild = new List<ServiceAppointmentEvent>();
        Set<Id> serviceAptIdSetForCapacityRebuild = new Set<Id>();
        AssignedResource assignResForSACapacityCal = new AssignedResource();
        List<Consumed_Capacity__c> updateConsumedCapacityList = new List<Consumed_Capacity__c>();
        SFS_ABResourceCapacityTimeSlotUtil.ResourceCapacityWrapper rsWrapper;
        Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate> territoryRebuildMap = new Map<Id, SFS_ABCapacityRebuildJobBatch.rebuildDate>();
        SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper capacityRebuildDateMap =new SFS_ABCapacityRebuildJobUtil.CreateCapacityRebuildDataMapWrapper();
        System.debug('sacList>>' + sacList);
        System.debug('sacList Size>>' + sacList.size());
        // Loop through the Events and set the vars
        for (ServiceAppointmentEvent sac : sacList) {
            // Maps and Vars
            workOrderIds.add(sac.Work_Order_Id);
            woIdToSACMap.put(sac.Work_Order_Id, sac);
            System.debug('sac>>' + sac);
            if ((sac.New_Status != null && sac.New_Status != sac.Previous_Status) ||(sac.Service_Territory_Id != null &&
                                                                                     sac.Prev_Service_Territory_Id != null &&
                                                                                     sac.Prev_Service_Territory_Id != sac.Service_Territory_Id) ||
                (sac.Scheduled_Start != null) ||
                (sac.Scheduled_End != null)
               )
            {
                System.debug('inside if>> ' + sac);
                serviceAptEventListForCapacityRebuild.add(sac);
                serviceAptIdSetForCapacityRebuild.add(sac.Service_Appointment_Id);
            }
            else if(sac.New_Status == sac.Previous_Status && sac.New_Status == SFS_ABConstantUtil.SA_OPEN)
            {
                //AW handling scenario where appt is changed on an unscheduled SA.  
                serviceAptEventListForCapacityRebuild.add(sac);
                serviceAptIdSetForCapacityRebuild.add(sac.Service_Appointment_Id);
            }
        }
        System.debug('serviceAptEventListForCapacityRebuild***' + serviceAptEventListForCapacityRebuild);
        System.debug('serviceAptIdSetForCapacityRebuild****' + serviceAptIdSetForCapacityRebuild);
        
        // Get a map of the Work Orders Related to our SACS
       /* for (WorkOrder wo : [SELECT ID, Status FROM WorkOrder WHERE ID IN :workOrderIds]) {
            ServiceAppointmentEvent sac = woIdToSACMap.get(wo.Id);
            
            // Status change lets update the WO status
            if (sac.New_Status != sac.Previous_Status) {
                if (sac.New_Status == SFS_ABConstantUtil.SA_CANCELED) {
                    wo.Status = SFS_ABConstantUtil.SA_CANCELED;
                }
               
				else 
				{
                    wo.Status = SFS_ABConstantUtil.WO_OPEN;
                }
                updateWOList.add(wo);
            }
        }*/
        
        // Get Assigned Resources
        for (AssignedResource ar : [
            SELECT ID, ServiceAppointmentId, ServiceResourceId, ServiceAppointment.ServiceTerritoryId, ServiceAppointment.SchedStartTime
            FROM AssignedResource
            WHERE ServiceAppointmentId IN :serviceAptIdSetForCapacityRebuild
        ]) {
            saIDToSRIDMap.put(ar.ServiceAppointmentId, ar);
        }
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        //Calculate resource Capacity and Consumed Capacity for the Service Appointment
        
        
        if (serviceAptEventListForCapacityRebuild != null && serviceAptEventListForCapacityRebuild.size() == 1 ) {
            System.debug('serviceAptEventListForCapacityRebuild.size()==1 and not null');
            
            assignResForSACapacityCal = saIDToSRIDMap.get(serviceAptEventListForCapacityRebuild[0].Service_Appointment_Id);
            
            System.debug(
                'assignResForSACapacityCal ------ >> ' +
                assignResForSACapacityCal +
                '--- Previous_Assigned_Id ---- >> ' +
                serviceAptEventListForCapacityRebuild[0].Previous_Assigned_Id +
                '------ saIDToSRIDMap ---- >> ' +
                saIDToSRIDMap
            );
            
            List<ServiceTerritoryMember> stmListForCapacityRebuild = new List<ServiceTerritoryMember>();
            List<ServiceTerritoryMember> stmListForPreviousAR = new List<ServiceTerritoryMember>();
            
            if (assignResForSACapacityCal != null) 
            {
                System.debug('assignResForSACapacityCal!=null');
                Date rebuildStartDt = serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start != null &&
                    Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start)) < Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Scheduled_Start))
                    ? Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start))
                    : Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Scheduled_Start));
                Date rebuildEndDt = serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start != null &&
                    Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start)) > Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Scheduled_End))
                    ? Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start))
                    : Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Scheduled_End));
                // Get the STM list foor the assigned resource
                stmListForCapacityRebuild = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ assignResForSACapacityCal.ServiceResourceId }, null);
                
                //query to handle previous assigned resource capacity calculation
                if (
                    serviceAptEventListForCapacityRebuild[0].Previous_Assigned_Id != null &&
                    serviceAptEventListForCapacityRebuild[0].Previous_Assigned_Id != assignResForSACapacityCal.ServiceResourceId
                ) {
                    stmListForPreviousAR = SFS_ABCapacityRebuildJobUtil.getSTMListById(new Set<Id>{ serviceAptEventListForCapacityRebuild[0].Previous_Assigned_Id }, null);
                    System.debug(' Inside Previous_Assigned_Id not null query result ---- >>>> ' + stmListForPreviousAR);
                    stmListForCapacityRebuild.addAll(stmListForPreviousAR);
                }
                //if there is just one STM record then recalculate the resource capacity
                System.debug('stmListForCapacityRebuild >>>> ***' + stmListForCapacityRebuild + '***stmListForCapacityRebuild.size()***' + stmListForCapacityRebuild.size());
                capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                    stmListForCapacityRebuild[0].id,
                    rebuildStartDt,
                    rebuildEndDt
                );
            } else {
                system.debug('Unscheduled change single event');
                Date rebuildDt = serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start != null
                    ? Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start))
                    : Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Arrival_Window_Start));
                
                stmListForCapacityRebuild = SFS_ABCapacityRebuildJobUtil.getSTMListById(null, new Set<Id>{serviceAptEventListForCapacityRebuild[0].Service_Territory_Id});
                capacityRebuildDateMap = SFS_ABCapacityRebuildJobUtil.getCapacityRebuildDataMap(
                    stmListForCapacityRebuild[0].id,
                    rebuildDt,
                    rebuildDt
                );
                
            }
            system.debug('stmListForCapacityRebuild '+stmListForCapacityRebuild);
            rsWrapper = SFS_ABResourceCapacityTimeSlotUtil.CalculateResourceCapacity(
                stmListForCapacityRebuild,
                capacityRebuildDateMap.minDate,
                capacityRebuildDateMap.maxDate,
                capacityRebuildDateMap.recordIdToDateMap
            );
            system.debug('rsWrapper '+rsWrapper);
            if (rsWrapper != null) {
                System.debug('rsWrapper NOT NULL >>' + rsWrapper.resourceCapacityForInsert.isEmpty());
                
                if (!rsWrapper.resourceCapacityForInsert.isEmpty()) {
                    System.debug('INSERT rsWrapper>> ' + rsWrapper);
                    insert rsWrapper.resourceCapacityForInsert;
                }
                
                if (!rsWrapper.resourceCapacityForUpdate.isEmpty()) {
                    System.debug('update rsWrapper>> ' + rsWrapper);
                    update rsWrapper.resourceCapacityForUpdate;
                }
            }
            System.debug('Update the Consumed Capacity logic');
            List<Consumed_Capacity__c> consumedCapacityList = new List<Consumed_Capacity__c>();
            if (
                (assignResForSACapacityCal == null && (serviceAptEventListForCapacityRebuild[0].New_Status == SFS_ABConstantUtil.SA_OPEN || serviceAptEventListForCapacityRebuild[0].New_Status == SFS_ABConstantUtil.SA_CANCELED) && stmListForCapacityRebuild != null) ||
                (stmListForCapacityRebuild != null &&
                 !serviceAptEventListForCapacityRebuild.isEmpty() &&
                 serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start != null)
            ) {
                System.debug('Inside IF ---- serviceAptEventListForCapacityRebuild[0]>>' + serviceAptEventListForCapacityRebuild[0]);
                Date territoryRebuildEndDt = serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start != null &&
                    Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start)) >=
                    Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Arrival_Window_Start))
                    ? Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Prev_Scheduled_Start))
                    : Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Arrival_Window_Start));
                if (
                    serviceAptEventListForCapacityRebuild[0].Previous_Status == SFS_ABConstantUtil.SA_OPEN && // Ankit Change
                    serviceAptEventListForCapacityRebuild[0].New_Status == SFS_ABConstantUtil.SA_OPEN // Ankit Change
                ) {
                    System.debug('Scheduling attempt failed (INT) - Customer Unscheduled - Unscheduled OR Case of manual unschedule');
                    consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(
                        serviceAptEventListForCapacityRebuild[0].Service_Territory_Id,
                        System.today(),
                        Date.valueOf(String.valueOf(serviceAptEventListForCapacityRebuild[0].Arrival_Window_Start))
                    );
                } else {
                    System.debug('else>> other scenarios of status change');
                    consumedCapacityList = SFS_ABCapacityRebuildJobUtil.getConsumedCapacity(serviceAptEventListForCapacityRebuild[0].Service_Territory_Id, System.today(), territoryRebuildEndDt);
                }
                
                System.debug('consumedCapacityList***' + consumedCapacityList);
                if (consumedCapacityList != null && consumedCapacityList.size() > 0) {
                    territoryRebuildMap.put(serviceAptEventListForCapacityRebuild[0].Service_Territory_Id, new SFS_ABCapacityRebuildJobBatch.rebuildDate(System.today(), territoryRebuildEndDt));
                    SFS_ABRebuildConsumedCapacityBatch rebuildConsumedCapacityVar = new SFS_ABRebuildConsumedCapacityBatch(territoryRebuildMap, false);
                    updateConsumedCapacityList = rebuildConsumedCapacityVar.rebuildCCBasedOnRCAndSA(consumedCapacityList);
                    System.debug('updateConsumedCapacityList after rebuildCCBasedOnRCAndSA()>>' + updateConsumedCapacityList);
                    
                    if (!updateConsumedCapacityList.isEmpty()) {
                        System.debug('updateConsumedCapacityList***>>>' + updateConsumedCapacityList);
                        update updateConsumedCapacityList;
                    }
                }
            }
        }
        
        //Create Capacity rebuild Job records if more than one SA are getting updated
        if (serviceAptEventListForCapacityRebuild != null && serviceAptEventListForCapacityRebuild.size() > 1) {
            System.debug('serviceAptEventListForCapacityRebuild.size() > 1 and not null');
            
            for (ServiceAppointmentEvent saEvent : serviceAptEventListForCapacityRebuild) {
                Date rebuildDt = saEvent.Prev_Scheduled_Start != null ? Date.valueOf(String.valueOf(saEvent.Prev_Scheduled_Start)) : Date.valueOf(String.valueOf(saEvent.Arrival_Window_Start));
                List<Date> territoryRebuildDtList = new List<Date>();
                System.debug('ServiceAppointmentEvent>> ' + saEvent);
                
                if (territoryIdToRebuildDtMap.get(saEvent.Service_Territory_Id) != null) {
                    if (territoryIdToRebuildDtMap.get(saEvent.Service_Territory_Id).contains(rebuildDt)) {
                        system.debug('skip existing territory rebuilddt');
                        continue;
                    } else {
                        territoryRebuildDtList = territoryIdToRebuildDtMap.get(saEvent.Service_Territory_Id);
                        territoryRebuildDtList.add(rebuildDt);
                        territoryIdToRebuildDtMap.put(saEvent.Service_Territory_Id, territoryRebuildDtList);
                        system.debug('add existing territory new rebuilddt');
                        capacityRebuildJobListForSAUpdates.add(
                            SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Service Appointment Update', null, saEvent.Service_Territory_Id, rebuildDt, rebuildDt)
                        );
                    }
                } else {
                    territoryRebuildDtList.add(rebuildDt);
                    territoryIdToRebuildDtMap.put(saEvent.Service_Territory_Id, territoryRebuildDtList);
                    system.debug('add new territory rebuilddt');
                    capacityRebuildJobListForSAUpdates.add(
                        SFS_ABCapacityRebuildJobUtil.createCapacityRebuildJobRecord('Service Appointment Update', null, saEvent.Service_Territory_Id, rebuildDt, rebuildDt)
                    );
                }
            }
        }
        if (!capacityRebuildJobListForSAUpdates.isEmpty()) {
            System.debug('capacityRebuildJobListForSAUpdates***' + capacityRebuildJobListForSAUpdates);
            insert capacityRebuildJobListForSAUpdates;
        }
        
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        
        // DML Update WO Status
      /*  if (!updateWOList.isEmpty()) {
            System.Debug('DWA: ServiceAppointmentUtils.SAUpdateEvent: Updating Work Order Status' + updateWOList);
            update updateWOList;
        }*/
        
        System.debug('Heapsize used>' + system.Limits.getHeapSize());
        System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
    }
    
    public class ServiceAppointmentEvent {
        public String Prev_Service_Territory_Id;
        public String Service_Territory_Id;
        public String Service_Appointment_Id;
        public String Previous_Status;
        public String New_Status;
        public String Scheduled_Start;
        public String Prev_Scheduled_Start;
        public String Scheduled_End;
        public String Prev_Scheduled_End;
        public String Work_Order_Id;
        public String Duration_In_Minutes;
        public String Arrival_Window_Start;
        public String Arrival_Window_End;
        public String Previous_Assigned_Id;
    }
}