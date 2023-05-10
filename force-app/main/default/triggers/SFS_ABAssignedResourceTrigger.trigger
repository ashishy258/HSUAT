trigger SFS_ABAssignedResourceTrigger on AssignedResource (before insert, after insert, before update, after update, before delete, after undelete, after delete) {
    rflib_TriggerManager.dispatch(AssignedResource.SObjectType);
}