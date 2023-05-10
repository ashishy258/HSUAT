trigger SFS_ABServicePostalCodeTrigger on Serviceable_Postal_Code__c (before insert,before update) {
    rflib_TriggerManager.dispatch(Serviceable_Postal_Code__c.SObjectType);
}