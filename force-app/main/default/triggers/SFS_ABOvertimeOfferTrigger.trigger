trigger SFS_ABOvertimeOfferTrigger on Overtime_Offers__c (before insert, after insert, before update, after update, before delete, after undelete, after delete) {
    rflib_TriggerManager.dispatch(Overtime_Offers__c.SObjectType);
}