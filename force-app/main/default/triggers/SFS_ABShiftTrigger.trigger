trigger SFS_ABShiftTrigger on Shift (before insert, after insert, before update, after update, before delete, after delete) {
    rflib_TriggerManager.dispatch(Shift.SObjectType);
}