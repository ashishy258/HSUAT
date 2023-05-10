global with sharing class ABWrapper {
    
    public class requestWrapper{
        public String serviceAppointmentNumber;
    }

    global class responseWrapper{
        global String saNumber;
        global String message;
        global Integer statusCode;
        global List <slotInfo> slotInfoList;

        global responseWrapper(){
            slotInfoList = new List<slotInfo>();
        }
    }

    global class slotInfo {
        global Datetime start;
        global Datetime finish;
    }

    global class bookApptResponseWrapper{
        global String saNumber;
        global String message;
        global Integer statusCode;
        global Datetime scheduledStartTime;
        global Datetime schedueledFinishTime;
    }

}