trigger SFS_PreventResourcePreferenceUpdate on ResourcePreference (before insert,before update, before delete) {
    rflib_TriggerManager.dispatch(ResourcePreference.SObjectType);
}