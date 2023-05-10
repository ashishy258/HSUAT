trigger SFS_ABResourceAbsenceTrigger on ResourceAbsence (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    rflib_TriggerManager.dispatch(ResourceAbsence.SObjectType);
}