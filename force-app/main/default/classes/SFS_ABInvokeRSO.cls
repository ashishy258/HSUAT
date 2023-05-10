/**
 * Created by ayushmathur on 03/04/23.
 */

public with sharing class SFS_ABInvokeRSO {
    @Future(Callout=true)
    public static void invokeRSO(Id resourceId, Id customerFirstId,Datetime start, Datetime finish,Set<Id> candidatesIds,Set<Id>requiredSaIds){
        Id optimizationId;
        FSL.OAAS rsOaas = new FSL.OAAS();
        FSL.TimeInterval horizon = new FSL.TimeInterval(start,finish);
         System.debug('Start RSO');
               FSL.RSORequest rsoRequest = new FSL.RSORequest();
               rsoRequest.resourceId = resourceId;
               rsoRequest.policyId = customerFirstId;
               rsoRequest.horizon = horizon;
               rsoRequest.includeAllTasks = true;
               rsoRequest.candidateSas = candidatesIds;
               rsoRequest.includeOnlyResourceFutureSA = true;
               rsoRequest.unschedulableServices = requiredSaIds;
               System.debug('Run RSO Request : ' + rsoRequest);
               optimizationId = rsOaas.ResourceDayOptimization(rsoRequest);
        System.debug('optimizationId  check'+optimizationId);
               System.debug('End RSO');
    }

}