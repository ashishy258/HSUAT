/**
* Created by ayushmathur on 14/03/23.
*/

public with sharing class SFS_ABServiceAppointmentJeopardyBatch implements Database.Batchable<SObject>,Database.Stateful{
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        List<String> saStatusToCheck = new List<String>();
        String saStatusValue = SFS_HS_GlobalSettings__mdt.getInstance(SFS_ABConstantUtil.JeopardyStatus).Values__c;
        if(saStatusValue!=null){
            saStatusToCheck=saStatusValue.trim().split(',');
        }
        String query ='SELECT Id,AppointmentNumber,SchedStartTime,SchedEndTime,Status,VEC__c,Static_Priority__c,ArrivalWindowStartTime,FSL__InJeopardy__c,FSL__InJeopardyReason__c FROM ServiceAppointment WHERE (SchedStartTime=TODAY  OR ArrivalWindowStartTime = TODAY) AND Status IN: saStatusToCheck AND FSL__InJeopardy__c =FALSE';
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext BC, List<ServiceAppointment> serviceAppointments) {
        System.debug('serviceAppointments.size() '+serviceAppointments.size());
        Datetime arrivalStart;
        Decimal diffFromArrivalStart;
        Decimal timeToTravel;
        Datetime scheduledStart;
        Decimal diffFromScheStart;
        Decimal diffFromScheStart_Travel;
        Datetime scheduledEnd;
        Decimal diffFromEnd;
        Map<Id, ServiceAppointment> idToServiceAppointmentMap= new Map<Id, ServiceAppointment>();
        List<ServiceAppointment> serviceAppointmentsToUpdate = new List<ServiceAppointment>();
        Datetime now = System.now();
        for(ServiceAppointment sa:serviceAppointments){
            if(sa.Status==SFS_ABConstantUtil.SA_OPEN && sa.ArrivalWindowStartTime!=null){
                arrivalStart = sa.ArrivalWindowStartTime;
                diffFromArrivalStart = ((arrivalStart.getTime())/1000/60) - ((now.getTime())/1000/60);
                if(diffFromArrivalStart<=60){
                    sa.FSL__InJeopardy__c=true;
                    sa.FSL__InJeopardyReason__c=SFS_ABConstantUtil.NOT_SCHEDULED;
                    serviceAppointmentsToUpdate.add(sa);
                }
            }
            else {
                idToServiceAppointmentMap.put(sa.Id,sa);
            }
        }

        if(idToServiceAppointmentMap!=null){
            for(AssignedResource ar : [SELECT ServiceAppointmentId, EstimatedTravelTime FROM AssignedResource WHERE ServiceAppointmentId IN:idToServiceAppointmentMap.keySet()]){

                timeToTravel = ar.EstimatedTravelTime==null?0:ar.EstimatedTravelTime;
                ServiceAppointment sa = idToServiceAppointmentMap.get(ar.ServiceAppointmentId);
                scheduledStart = sa.SchedStartTime;
                diffFromScheStart=((now.getTime())/1000/60) - ((scheduledStart.getTime())/1000/60);
             
                    if((sa.Status==SFS_ABConstantUtil.SA_DISPATCHED || sa.Status ==SFS_ABConstantUtil.SA_CONFIRMED)&& sa.VEC__c!=true && sa.Static_Priority__c!=1){
                    diffFromScheStart_Travel = (((now.getTime()) / 1000 / 60) + timeToTravel -(scheduledStart.getTime()) / 1000 / 60) ;
                    if(diffFromScheStart_Travel>=15) {
                        sa.FSL__InJeopardy__c=true;
                        sa.FSL__InJeopardyReason__c=SFS_ABConstantUtil.LATE_START_TRAVEL;
                        serviceAppointmentsToUpdate.add(sa);
                    }
                }
                // Check for Late Start Work
                else if((sa.Status == SFS_ABConstantUtil.SA_DISPATCHED  || sa.Status ==SFS_ABConstantUtil.SA_CONFIRMED || sa.Status ==SFS_ABConstantUtil.SA_PRE_DISPATCHED) && ( sa.VEC__c ==true || sa.Static_Priority__c==1)){
                    if(diffFromScheStart >= 15){
                        sa.FSL__InJeopardy__c=true;
                        sa.FSL__InJeopardyReason__c= SFS_ABConstantUtil.LATE_START_WORK;
                        serviceAppointmentsToUpdate.add(sa);
                    }
                }

               else if((sa.Status==SFS_ABConstantUtil.SA_DISPATCHED || sa.Status ==SFS_ABConstantUtil.SA_CONFIRMED || sa.Status==SFS_ABConstantUtil.SA_TRAVEL) && diffFromScheStart>=15){
                    sa.FSL__InJeopardy__c=true;
                    sa.FSL__InJeopardyReason__c=SFS_ABConstantUtil.LATE_START_WORK;
                    serviceAppointmentsToUpdate.add(sa);
                }
                // Check for Late Completion
                else if(sa.Status==SFS_ABConstantUtil.SA_ONSITE && sa.SchedEndTime!=null){
                    scheduledEnd=sa.SchedEndTime;
                    diffFromEnd = (((now.getTime())/1000/60) - ((scheduledEnd.getTime())/1000/60));
                    if(diffFromEnd >= 15){
                        sa.FSL__InJeopardy__c=true;
                        sa.FSL__InJeopardyReason__c=SFS_ABConstantUtil.LATE_COMPLETION;
                        serviceAppointmentsToUpdate.add(sa);
                    }
                }
            }
        }
           
        List<Database.SaveResult> updateResults = Database.update(serviceAppointmentsToUpdate, false);
        for(Integer i=0;i<updateResults.size();i++){
            if (updateResults.get(i).isSuccess()){
                updateResults.get(i).getId();
                
            }else if (!updateResults.get(i).isSuccess()){
                // DML operation failed
                Database.Error error = updateResults.get(i).getErrors().get(0);
                String failedDML = error.getMessage();
                serviceAppointmentsToUpdate.get(i);//failed record from the list
                System.debug('Failed ID'+serviceAppointmentsToUpdate.get(i).Id);
            }   
        }
    }
    public void finish(Database.BatchableContext BC) {
        if(!Test.isRunningTest())
        {
            System.scheduleBatch(new SFS_ABServiceAppointmentJeopardyBatch(), 'SFS_ABServiceAppointmentJeopardyBatch - '+System.now().addSeconds(300), 5);
        }   
    }
}