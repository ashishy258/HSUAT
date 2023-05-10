trigger SFS_ABConsumedCapacityTrigger on Consumed_Capacity__c (before insert, after insert, before update, after update, before delete, after undelete) {
    rflib_TriggerManager.dispatch(Consumed_Capacity__c.SObjectType);
   }