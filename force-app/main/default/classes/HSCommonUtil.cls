public with sharing class HSCommonUtil {
public static boolean isOverrideOn = false;
    public HSCommonUtil() {

    }
    public static String convertTimeZone (Datetime varDateTime, String zone){
        String timeString = '';
        if(varDateTime!=null && zone!=''){
            Timezone tz = Timezone.getTimeZone(zone);
            Integer offset = tz.getOffset(varDateTime);
            Datetime varDateTimeUpdated = varDateTime.addSeconds(offset/1000);
            System.debug('Converted DATE' + varDateTimeUpdated);
            timeString = String.valueOf(varDateTimeUpdated.formatGmt('yyyy-MM-dd HH:mm'));
        }
        return timeString;
    }

 public static Date convertTimeZoneDate (Datetime varDateTime, String zone){
        Date converteddate ;
        if(varDateTime!=null && zone!=''){
            Timezone tz = Timezone.getTimeZone(zone);
            Integer offset = tz.getOffset(varDateTime);
            Datetime varDateTimeUpdated = varDateTime.addSeconds(offset/1000);
            System.debug('Converted DATE' + varDateTimeUpdated);
            converteddate = varDateTimeUpdated.dateGMT();
        }
        return converteddate;
    }
 public static DateTime convertTimeZoneDateTime (Datetime varDateTime, String zone){
        DateTime converteddatetime ;
        if(varDateTime!=null && zone!=''){
            Timezone tz = Timezone.getTimeZone(zone);
            Integer offset = tz.getOffset(varDateTime);
            Datetime varDateTimeUpdated = varDateTime.addSeconds(offset/1000);
            System.debug('Converted DATE' + varDateTimeUpdated);
            converteddatetime = varDateTimeUpdated.dateGmt();
        }
        return converteddatetime;
    }
    
     //To get Day of Week from Date
    public static String getDayOfWeek(Date dt) {
        DateTime myDateTime = (DateTime) dt.addDays(1);
        String dayOfWeek = myDateTime.format('EEEE');
        return dayOfWeek;
    }
}