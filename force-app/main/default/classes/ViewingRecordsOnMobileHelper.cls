public with sharing class ViewingRecordsOnMobileHelper {

    public Static Final Map<Integer, String> monthOfYear = new Map<Integer, String>{
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec'
    };

    @AuraEnabled(cacheable=true)
    public static List<Wrapper> getOvertimeOffersList(String userId){
        system.debug('request here: ');
        List<Wrapper> wrapperListToReturn = new List<Wrapper>();
        for(Overtime_Offers__c overTime : [SELECT Id, Offer_Start_Time__c, Offer_Finish_Time__c, Status__c, Comment__c, Local_Start_Time__c, Local_End_Time__c FROM Overtime_Offers__c WHERE Service_Resource__r.RelatedRecordId =: userId ORDER BY Local_Start_Time__c DESC]){
            Wrapper wrap = new Wrapper();
            wrap.id = overTime.Id;
            wrap.label = overTime.Local_Start_Time__c + ' : ' + overTime.Status__c;
            wrap.OfferStartTime = overTime.Offer_Start_Time__c;
            wrap.OfferFinishTime = overTime.Offer_Finish_Time__c;
            wrap.status = overTime.Status__c;
            wrap.comment = overTime.Comment__c;
            wrap.localStartDateTime = overTime.Local_Start_Time__c;
            wrap.localFinishDateTime = overTime.Local_End_Time__c;
            if(overTime.Status__c == 'Offered' || overTime.Status__c == 'Recalled'){
                wrap.isDisabled = false;
            }
            else{
                wrap.isDisabled = true;
            }
            wrapperListToReturn.add(wrap);
        }
        return wrapperListToReturn;
    }

    @AuraEnabled(cacheable=true)
    public static List<ShiftWrapper> getShiftsList(String userId){
        List<ShiftWrapper> wrapperListToReturn = new List<ShiftWrapper>();
        Datetime currentDatetime = DateTime.newInstance(system.today(), Time.newInstance(0, 0, 0, 0));
        Datetime after7DaysDatetime = DateTime.newInstance(system.today().addDays(7), Time.newInstance(23, 59, 0, 0));
        List<Shift> shiftListToResturn = [SELECT Id, ShiftNumber, StartTime, EndTime, Status, Local_Start_Time__c, Local_End_Time__c FROM Shift WHERE ServiceResource.RelatedRecordId =: userId AND StartTime >=: currentDatetime AND StartTime <=: after7DaysDatetime AND Status = 'Confirmed' ORDER BY StartTime ASC];
        for(Shift shiftRec : shiftListToResturn){
            ShiftWrapper shiftWrap = new ShiftWrapper();
            shiftWrap.id = shiftRec.Id;
            shiftWrap.shiftNumber = shiftRec.ShiftNumber;
            shiftWrap.status = shiftRec.Status;
            shiftWrap.startDate = convertDateTimeFormat(shiftRec.StartTime);
            shiftWrap.endDate = convertDateTimeFormat(shiftRec.EndTime);
            wrapperListToReturn.add(shiftWrap);
        }
        return wrapperListToReturn;
    }

    public static String convertDateTimeFormat(Datetime dateToFormat){
        String formatedDatetime = monthOfYear.get(dateToFormat.month()) + ' ' + String.valueOf(dateToFormat.day()) + ', ' + String.valueOf(dateToFormat.year()) + ' ';
        if(dateToFormat.hour() > 12){
            formatedDatetime = formatedDatetime + String.valueOf(dateToFormat.hour() - 12) + ':' + (String.valueOf(dateToFormat.minute()).length() == 1 ? '0' + String.valueOf(dateToFormat.minute()) : String.valueOf(dateToFormat.minute()));
        }
        else{
            formatedDatetime = formatedDatetime + String.valueOf(dateToFormat.hour()) + ':' + (String.valueOf(dateToFormat.minute()).length() == 1 ? '0' + String.valueOf(dateToFormat.minute()) : String.valueOf(dateToFormat.minute()));
        }
        if(dateToFormat.hour() > 11){
            formatedDatetime = formatedDatetime + ' PM';
        }
        else{
            formatedDatetime = formatedDatetime + ' AM';
        }
		return formatedDatetime;
    }

    @AuraEnabled(cacheable=true)
    public static String getServiceResource(String userId){
        ServiceResource svcresource = [SELECT Id FROM ServiceResource WHERE RelatedRecordId =: userId LIMIT 1];
        return svcresource.Id;
    }

    @AuraEnabled(cacheable=true)
    public static WorkOrder getWorkOrder(String recordId){
        WorkOrder workOrderRec = [SELECT Id, Contact_Phone_Number__c, Contact_Mobile_Number__c FROM WorkOrder WHERE Id =: recordId LIMIT 1];
        return workOrderRec;
    }

    public class Wrapper{
        @AuraEnabled
        public String id {get; set;}
        @AuraEnabled
        public String label {get; set;}
        @AuraEnabled
        public Datetime OfferStartTime {get; set;}
        @AuraEnabled
        public Datetime OfferFinishTime {get; set;}
        @AuraEnabled
        public String status {get; set;} 
        @AuraEnabled
        public String comment {get; set;} 
        @AuraEnabled
        public String localStartDateTime {get; set;} 
        @AuraEnabled
        public String localFinishDateTime {get; set;}
        @AuraEnabled
        public Boolean isDisabled {get; set;} 
    }

    public class ShiftWrapper{
        @AuraEnabled
        public String id {get; set;}
        @AuraEnabled
        public String startDate {get; set;}
        @AuraEnabled
        public String endDate {get; set;}
        @AuraEnabled
        public String shiftNumber {get; set;} 
        @AuraEnabled
        public String status {get; set;} 
    }
}