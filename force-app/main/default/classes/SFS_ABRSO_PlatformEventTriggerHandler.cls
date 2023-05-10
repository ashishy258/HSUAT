/**
 * Created by ayushmathur on 05/04/23.
 */

public with sharing class SFS_ABRSO_PlatformEventTriggerHandler implements rflib_TriggerHandler {
    private static final rflib_Logger LOGGER = rflib_LoggerUtil.getFactory().createLogger('SFS_ABRSO_PlatformEventTriggerHandler');
    public void run(rflib_TriggerManager.Args triggerArguments) {
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_INSERT) {
            LOGGER.info('CALLING AFTER Insert');
            invokeRSO(triggerArguments);
        }
    }
    public static void invokeRSO(rflib_TriggerManager.Args triggerArguments) {
        System.debug('Inside handler invokeRSO ');

        Map<Id,List<ServiceAppointment>> resourceIdToSAMap =new Map<Id, List<ServiceAppointment>>();
        Set<Id> requiredSaIds = new Set<Id>();
        Set<Id> candidatesIds = new Set<Id>();
        List<RSO_PE__e> rsoPes = (List<RSO_PE__e>) triggerArguments.newRecords;
        List<ServiceAppointment> futureAppointments=new List<ServiceAppointment>();
        Datetime startTime =rsoPes[0].StartTime__c;
        Datetime endTime = rsoPes[0].End_Time__c;
        Id customerFirstId = rsoPes[0].Scheduling_Policy__c;

        List<Id> resourceIds =new List<Id>();
        for(RSO_PE__e rsoEvent :rsoPes){
            resourceIds.add(rsoEvent.Resource_Id__c);
        }
        if(resourceIds.size()>0) {
            for (ServiceAppointment sa : [
                    SELECT Id, Assigned_Resource__c, FSL__Pinned__c,SchedStartTime
                    FROM ServiceAppointment
                    WHERE Assigned_Resource__c IN :resourceIds
                    AND SchedStartTime >= :startTime
                    AND SchedStartTime <= :endTime
            ]) {
                if (!resourceIdToSAMap.containsKey(sa.Assigned_Resource__c)) {
                    resourceIdToSAMap.put(sa.Assigned_Resource__c, new List<ServiceAppointment>());
                }
                resourceIdToSAMap.get(sa.Assigned_Resource__c).add(sa);
            }
System.debug('resourceIdToSAMap '+resourceIdToSAMap);
            for (Id resourceId : resourceIdToSAMap.keySet()) {
                System.debug('resourceIdToSAMap.keySet() '+resourceIdToSAMap.keySet());
                System.debug('resourceId '+resourceId);

                futureAppointments = resourceIdToSAMap.get(resourceId);
                if (futureAppointments.size() > 0) {
                    for (ServiceAppointment sa : futureAppointments) {
                        if (sa.SchedStartTime!=null) {
                            candidatesIds.add(sa.Id);
                            
                        } /*else {

                        }*/
                    }
/*
                    if (candidatesIds.size() > 0) {
*/
                        SFS_ABInvokeRSO.invokeRSO(resourceId, customerFirstId, startTime, endTime, candidatesIds, requiredSaIds);
                    /*}*/
                }
            }
        }
        }
    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
    }
}