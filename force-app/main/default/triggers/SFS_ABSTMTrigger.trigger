trigger SFS_ABSTMTrigger on ServiceTerritoryMember (before insert, after insert, before update, after update, before delete, after undelete) {
    rflib_TriggerManager.dispatch(ServiceTerritoryMember.SObjectType);
}