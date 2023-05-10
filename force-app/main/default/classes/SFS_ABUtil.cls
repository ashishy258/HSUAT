/**
 * @description       :
 * @author            : Salesforce Service
 * @group             :
 * @last modified on  : 11-20-2020
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   11-08-2020   Salesforce Service     Initial Version
 **/
public class SFS_ABUtil {
    public static Map<Id, List<ServiceAppointment>> resourceIdToServiceAppointmentMap = new Map<Id, List<ServiceAppointment>>();
    public static Boolean statusChangeForMuleUser = false;

    public static DateTime convertDateTimeToTerritorysTZ(ServiceAppointment serviceAppointment, Map<Id, ServiceTerritory> territoryMap, DateTime dateTimeValue) {
        String tzString = territoryMap.get(serviceAppointment.ServiceTerritoryId).OperatingHours.TimeZone;
        String convertedTimeZoneString = dateTimeValue.format('yyyy-MM-dd HH:mm:ss', tzString);
        DateTime finalConvertedDateTime = DateTime.valueOfGMT(convertedTimeZoneString);
        return finalConvertedDateTime;
    }

    public static List<Resource_Capacity__c> resourceCapacityUpdate(ServiceAppointment appointmentReturned, Id resourceId) {
        // Get the RC to update the Capacity numbers on a quick Decrement
        //String rcQuery = 'SELECT ID, X12_16_Slot_Minutes__c, X16_20_Slot_Minutes__c, X8_12_SlotMinutes__c, Capacity__c, CapacityDate__c,ServiceResource__c, ServiceTerritory__c, Assigned_Appointment_Minutes__c ';

        //AW removing slot_minutes fields
        //String rcQuery = 'SELECT ID, X12_16_Slot_Minutes__c, X16_20_Slot_Minutes__c, X8_12_SlotMinutes__c, Capacity__c, CapacityDate__c,ServiceResource__c, ServiceTerritory__c, ServiceTerritory__r.OperatingHours.TimeZone, Assigned_Appointment_Minutes__c ';
        String rcQuery = 'SELECT ID, Capacity__c, Capacity_Date__c,Service_Resource__c, Service_Territory__c, Service_Territory__r.OperatingHours.TimeZone, Assigned_Appointment_Minutes__c ';

        //rcQuery+= 'From Resource_Capacity__c FOR Update ';
        rcQuery += 'From Resource_Capacity__c ';
        rcQuery += 'WHERE Capacity_Date__c =' + appointmentReturned.ArrivalWindowStartTime.format('yyyy-MM-dd') + ' ';
        //rcQuery+= 'AND ServiceResource__c = \''+ resourceToAddToBody.Id+'\' ';
        rcQuery += 'AND Service_Resource__c = \'' + resourceId + '\' FOR UPDATE';
        //rcQuery+= 'AND ServiceTerritory__c = \''+ appointmentReturned.ServiceTerritoryId+'\' LIMIT 1 FOR UPDATE';
        //Resource_Capacity__c rc;
        List<Resource_Capacity__c> rcList;

        system.debug('rcQuery>>> ' + rcQuery);
        // Query RCs
        //rc = database.query(rcQuery);
        rcList = database.query(rcQuery);

        // Query to get AR
        AssignedResource ar = [
            SELECT Id, EstimatedTravelTime, ServiceResource.FSL__Efficiency__c
            FROM AssignedResource
            WHERE ServiceResourceId = :resourceId AND ServiceAppointmentid = :appointmentReturned.Id
            LIMIT 1
        ];

        // Calc the total time to modify
        Time timeToEnd = SFS_ABResourceCapacityTimeSlotUtil.getTimeFromDateTime(appointmentReturned.SchedEndTime);
        Time timeToStart = SFS_ABResourceCapacityTimeSlotUtil.getTimeFromDateTime(appointmentReturned.SchedStartTime);
        Decimal minFromStartAndEnd = SFS_ABResourceCapacityTimeSlotUtil.getMinutesFormTime(timeToStart, timeToEnd);
        Decimal timeToDecrement = (minFromStartAndEnd * ar.ServiceResource.FSL__Efficiency__c) + ar.EstimatedTravelTime;

        //** TODO Test and/or convert the ArrivalwindowStart.Hour into 8-12, 12-4, 4-8 with timezones correctly

        // 8AM - 12PM Booking window
        //Start of confirm RC update fix
        for (Resource_Capacity__c rc : rcList) {
            DateTime convertedArrivalStartDtTm = SFS_ABUtil.convertDateTimeToTerritorysTZ(
                rc.Service_Territory__r.OperatingHours.get('TimeZone').tostring(),
                appointmentReturned.ArrivalWindowStartTime
            );
            DateTime convertedArrivalEndDtTm = SFS_ABUtil.convertDateTimeToTerritorysTZ(rc.Service_Territory__r.OperatingHours.get('TimeZone').tostring(), appointmentReturned.ArrivalWindowEndTime);
            System.debug('converted arrival start ' + convertedArrivalStartDtTm.hourGMT());
            System.debug('converted arrival date ' + convertedArrivalEndDtTm.hourGMT());

            //if (appointmentReturned.ArrivalWindowStartTime.hourGMT()==13 &&
            //appointmentReturned.ArrivalWindowEndTime.hourGMT()==17){
            if (convertedArrivalStartDtTm.hourGMT() == 8 && convertedArrivalEndDtTm.hourGMT() == 12) {
                //End of confirm RC update fix
                //if (rc.X8_12_Slot_Minutes__c != null && rc.X8_12_Slot_Minutes__c > timeToDecrement) {
                //    rc.X8_12_Slot_Minutes__c -= timeToDecrement;
                //} else {
                //    rc.X8_12_Slot_Minutes__c = 0;
                // }
                if (rc.Assigned_Appointment_Minutes__c != null) {
                    rc.Assigned_Appointment_Minutes__c += timeToDecrement;
                } else {
                    rc.Assigned_Appointment_Minutes__c = timeToDecrement;
                }
            }

            // // 12PM - 4PM Booking window
            // //Start of confirm RC update fix
            // //if (appointmentReturned.ArrivalWindowStartTime.hourGMT()==17 &&
            // //appointmentReturned.ArrivalWindowEndTime.hourGMT()==21){
            // if (convertedArrivalStartDtTm.hourGMT() == 12 && convertedArrivalEndDtTm.hourGMT() == 16) {
            //     //End of confirm RC update fix
            //     // if (rc.X12_16_Slot_Minutes__c != null && rc.X12_16_Slot_Minutes__c > timeToDecrement) {
            //     //     rc.X12_16_Slot_Minutes__c -= timeToDecrement;
            //     // } else {
            //     //     rc.X12_16_Slot_Minutes__c = 0;
            //     // }
            //     if (rc.Assigned_Appointment_Minutes__c != null) {
            //         rc.Assigned_Appointment_Minutes__c += timeToDecrement;
            //     } else {
            //         rc.Assigned_Appointment_Minutes__c = timeToDecrement;
            //     }
            // }

            // // 4PM - 8PM Booking window
            // //Start of confirm RC update fix
            // //if (appointmentReturned.ArrivalWindowStartTime.hourGMT()==21 &&
            // //appointmentReturned.ArrivalWindowEndTime.hourGMT()==0){
            // if (convertedArrivalStartDtTm.hourGMT() == 16 && convertedArrivalEndDtTm.hourGMT() == 20) {
            //     //End of confirm RC update fix
            //     if (rc.X16_20_Slot_Minutes__c != null && rc.X16_20_Slot_Minutes__c > timeToDecrement) {
            //         rc.X16_20_Slot_Minutes__c -= timeToDecrement;
            //     } else {
            //         rc.X16_20_Slot_Minutes__c = 0;
            //     }
            //     if (rc.Assigned_Appointment_Minutes__c != null) {
            //         rc.Assigned_Appointment_Minutes__c += timeToDecrement;
            //     } else {
            //         rc.Assigned_Appointment_Minutes__c = timeToDecrement;
            //     }
            // }

            // Update the RC to quickly get this data updated before the CR job runs
            update rc;
        }
        return rcList;
    }

    // Common method to re-schedule the service appointments.
    // Paramete is Json string of Service appointment record.
    public static void rescheduleJobs(List<ServiceAppointment> listOfAppointments) {
        FSL__Scheduling_Policy__c businessHoursPolicy = new FSL__Scheduling_Policy__c();
        FSL__Scheduling_Policy__c extendedHoursPolicy = new FSL__Scheduling_Policy__c();

        try {
            businessHoursPolicy = SFS_ABUtil.getSchedulingPolicyByName(SFS_ABConstantUtil.Only_Business_Hours_PolicyID);
            extendedHoursPolicy = SFS_ABUtil.getSchedulingPolicyByName(SFS_ABConstantUtil.Extended_Hours_PolicyID);
        } catch (Exception e) {
            System.debug(e);
        }

        for (ServiceAppointment eachSA : listOfAppointments) {
            String jsonString = JSON.serialize(eachSA);
            Id schedulingPolicyId;
            Date dateValueOfSA = Date.ValueOf(eachSA.SchedStartTime);
            if (dateValueOfSA != Date.Today()) {
                schedulingPolicyId = businessHoursPolicy.Id;
            } else {
                schedulingPolicyId = extendedHoursPolicy.Id;
            }
            queueFSLScheduler(jsonString, schedulingPolicyId);
        }
    }

    @future(callout=true)
    public static void queueFSLScheduler(String appointmentString, Id schedulingPolicyId) {
        FSL.ScheduleResult myResult = new FSL.ScheduleResult();
        ServiceAppointment appointmentToReschedule = (ServiceAppointment) JSON.deserialize(appointmentString, ServiceAppointment.class);
        List<AssignedResource> assignedResourceList = new List<AssignedResource>();
        Id serviceAppointmentId = appointmentToReschedule.Id;
        try {
            statusChangeForMuleUser = true;
            System.debug('statusChangeForMuleUser : ' + statusChangeForMuleUser);
            myResult = FSL.ScheduleService.schedule(schedulingPolicyId, serviceAppointmentId);
            System.debug('Scheduling Result: ' + myResult);
            if (myResult == null) {
                assignedResourceList = [SELECT Id, ServiceAppointmentId FROM AssignedResource WHERE ServiceAppointmentId = :serviceAppointmentId LIMIT 1];
            }
        } catch (Exception e) {
            System.debug('In the scheduling exception block: ' + e);
            assignedResourceList = [SELECT Id, ServiceAppointmentId FROM AssignedResource WHERE ServiceAppointmentId = :serviceAppointmentId LIMIT 1];
        } finally {
            if (!assignedResourceList.isEmpty() && assignedResourceList.size() > 0) {
                delete assignedResourceList;
            }
        }
    }
    //Anand - 02/08/2021 - Common method to get the Policy ID using Policy Name as Parameter
    public static FSL__Scheduling_Policy__c getSchedulingPolicyByName(String policyName) {
        FSL__Scheduling_Policy__c schedulingPolicy = new FSL__Scheduling_Policy__c();
        if (!String.isBlank(policyName)) {
            schedulingPolicy = [SELECT Id, Name FROM FSL__Scheduling_Policy__c WHERE Name = :policyName LIMIT 1];
        }
        return schedulingPolicy;
    }

    public static DateTime convertDateTimeToTerritorysTZ(String timeZone, DateTime dateTimeValue) {
        String convertedTimeZoneString = dateTimeValue.format('yyyy-MM-dd HH:mm:ss', timeZone);
        DateTime finalConvertedDateTime = DateTime.valueOfGMT(convertedTimeZoneString);
        return finalConvertedDateTime;
    }

    public static DateTime convertDateTimeToTerritorysTZNonGMT(String timeZone, DateTime dateTimeValue) {
        String convertedTimeZoneString = dateTimeValue.format('yyyy-MM-dd HH:mm:ss', timeZone);
        DateTime finalConvertedDateTime = DateTime.valueOf(convertedTimeZoneString);
        return finalConvertedDateTime;
    }

    public static String formatDatesToAppointmentTimeZone(String timeZone, DateTime dateTimeToConvert) {
        if (dateTimeToConvert != null) {
            String convertedDateTime = dateTimeToConvert.format('yyyy-MM-dd\'T\'HH:mm:ss', timeZone);
            return convertedDateTime;
        }
        return null;
    }
}