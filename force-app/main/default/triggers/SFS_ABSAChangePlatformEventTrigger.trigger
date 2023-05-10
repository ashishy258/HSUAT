trigger SFS_ABSAChangePlatformEventTrigger on Service_Appointment_Change__e (after insert) {
    System.Debug('DWA ServiceAppointment Change PE Change Event Trigger.  Calling Utils');
       
       SFS_ABServiceAppointmentUtils.SAUpdateEvent(SFS_ABServiceAppointmentUtils.convertSAChangeEventToServiceAppointmentEvent(Trigger.New));
       
   }