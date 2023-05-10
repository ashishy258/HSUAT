@isTest
public class HSCommonUtil_Test {
 @TestSetup
    static void setup(){
        Profile servicesProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User serviceUser1 = new User();
        serviceUser1.FirstName = 'Test';
        serviceUser1.LastName = 'ServiceResource1';
        serviceUser1.ProfileId = servicesProfile.Id;
        serviceUser1.username = 'test_service_user1@test.com';
        serviceUser1.email = 'TestServiceUser@invalid.com';
        serviceUser1.Alias = '2222202';
        serviceUser1.TimeZoneSidKey = 'America/New_York';
        serviceUser1.LocaleSidKey = 'en_US';
        serviceUser1.EmailEncodingKey = 'UTF-8';
        serviceUser1.LanguageLocaleKey = 'en_US';
        serviceUser1.IsActive = true;
        serviceUser1.FederationIdentifier = 'test6816815136131686851';
        insert serviceUser1;

        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'];
        insert new PermissionSetAssignment(AssigneeId = serviceUser1.id, PermissionSetId = ps.Id);

        System.runAs(serviceUser1) {

            //Creating Operating Hours Record
            OperatingHours estOperatingHour = new OperatingHours();
            estOperatingHour.Name = 'Eastern Standard Time';
            estOperatingHour.TimeZone = 'America/New_York';
            insert estOperatingHour;
        }
    }
    @IsTest
    public static void testCoverageForMethods(){
        OperatingHours ohr = [SELECT Id,TimeZone FROM OperatingHours limit 1];
        HSCommonUtil util=new HSCommonUtil();
        Test.startTest();
        HSCommonUtil.convertTimeZone(DateTime.now(),ohr.TimeZone);
        HSCommonUtil.convertTimeZoneDate(DateTime.now(),ohr.TimeZone);
        HSCommonUtil.convertTimeZoneDateTime(DateTime.now(),ohr.TimeZone);      
        HSCommonUtil.getDayOfWeek(DateTime.now().date());      
        Test.stopTest();
    }
}