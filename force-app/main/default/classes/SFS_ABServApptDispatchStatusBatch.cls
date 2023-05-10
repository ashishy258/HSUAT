/**
 * @description       : Make status of scheduled appointments from Scheduled to Dispatch where the assigned resource is having Drip feed as dispatch policy.
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 03-14-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   03-14-2023   Ashish Yadav    Initial Version
 * 2.0   04-18-2023   Ashish Yadav    Updated the start query
 **/
public class SFS_ABServApptDispatchStatusBatch implements Database.Batchable<sObject> {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime currentDateTime = datetime.now();
        Datetime endDateTime = currentDateTime.addHours(2);
        String query = 'SELECT Id, ServiceAppointmentId FROM AssignedResource WHERE ServiceAppointment.Status = \'Scheduled\' AND ServiceResource.Dispatch_Policy__c = \'Drip Feed\' AND ServiceAppointment.SchedStartTime >=: currentDateTime AND ServiceAppointment.SchedStartTime <: endDateTime';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext bc, List<AssignedResource> scope) {
        List<ServiceAppointment> serviceAppointmentsToUpdate = new List<ServiceAppointment>();
        Set<String> serviceAppointmentsIdSet = new Set<String>();

        for(AssignedResource assignedResourceRec : scope){
            serviceAppointmentsIdSet.add(assignedResourceRec.ServiceAppointmentId);
        }

        for(ServiceAppointment sa : [SELECT Id, Status FROM ServiceAppointment WHERE Id IN : serviceAppointmentsIdSet]){
            sa.Status = SFS_ABConstantUtil.SA_PRE_DISPATCHED;
            serviceAppointmentsToUpdate.add(sa);
        }

        if(!serviceAppointmentsToUpdate.isEmpty()){
            List<Database.SaveResult> result = Database.update(serviceAppointmentsToUpdate, false);
            for (Database.SaveResult sr : result) {
                if (sr.isSuccess()) {
                    // Operation was successful, so get the ID of the record that was processed
                    System.debug('Successfully updated Service Appointment with Id: ' + sr.getId());
                }
                else {
                    // Operation failed, so get all errors                
                    for(Database.Error err : sr.getErrors()) {
                        System.debug('The following error has occurred.');                    
                        System.debug(err.getStatusCode() + ': ' + err.getMessage());
                        System.debug('ServiceAppointment fields that affected this error: ' + err.getFields());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        if(!Test.isRunningTest()){
            System.scheduleBatch(new SFS_ABServApptDispatchStatusBatch(), 'SA_Status_Dispatch_Update', 15);
        }
    }
}