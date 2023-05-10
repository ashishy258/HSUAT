trigger SFS_PreventSkillRequirementUpdate on SkillRequirement (before update, before delete) {
    rflib_TriggerManager.dispatch(SkillRequirement.SObjectType);
}