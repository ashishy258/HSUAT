trigger SFS_ABSAInsertPlatformEventTrigger on Service_Appointment_Insert__e (after insert) {
    //SFS_ABServiceAppointmentUtils.SAInsertEvent(SFS_ABServiceAppointmentUtils.convertSAInsertEventToServiceAppointmentEvent(Trigger.New));
}