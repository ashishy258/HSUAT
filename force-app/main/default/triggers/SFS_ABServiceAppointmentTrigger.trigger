trigger SFS_ABServiceAppointmentTrigger on ServiceAppointment (before insert, after insert, before update, after update, before delete, after undelete) {
	rflib_TriggerManager.dispatch(ServiceAppointment.SObjectType); 
}