trigger SFS_ABRSO_PlatformEventTrigger on RSO_PE__e (after insert) {
    rflib_TriggerManager.dispatch(RSO_PE__e.SObjectType);
}