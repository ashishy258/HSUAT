/**
 * @description       : Cover the code coverage of ViewingRecordsOnMobileHelper apex class
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 04-15-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   04-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class ViewingRecordsOnMobileHelperTest {

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

            //Creating Service Resource
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);

            //Creating Service Territory
            ServiceTerritory serviceTerritory1 = new ServiceTerritory();
            serviceTerritory1.Name = 'Brooklyn';
            serviceTerritory1.OperatingHoursId = estOperatingHour.Id;
            serviceTerritory1.IsActive = true;
            insert serviceTerritory1;

            //Creating Service Territory Member

            ServiceTerritoryMember member1 = new ServiceTerritoryMember();
            member1.ServiceTerritoryId = serviceTerritory1.Id;
            member1.ServiceResourceId = serviceResource1.Id;
            member1.EffectiveStartDate = Date.today();
            insert member1;

            createShift(serviceResource1.Id);
            createOvertimeOffers(serviceResource1.Id);
        }
    }

    @IsTest
    public static void getOvertimeOffersListTest(){

        User serviceUser = [SELECT Id FROM User WHERE username = 'test_service_user1@test.com' LIMIT 1];

        Test.startTest();
        List<ViewingRecordsOnMobileHelper.Wrapper> wrapperList = ViewingRecordsOnMobileHelper.getOvertimeOffersList(serviceUser.Id);
        Test.stopTest();
        System.assertEquals(1, wrapperList.size(), 'The size of wrapper list should be 1');
        System.assertEquals(false, wrapperList[0].isDisabled, 'The isDisabled variable should set to false as Overtime Offered is having status Offered');

    }

    @IsTest
    public static void getShiftsListTest(){

        User serviceUser = [SELECT Id FROM User WHERE username = 'test_service_user1@test.com' LIMIT 1];

        Test.startTest();
        List<ViewingRecordsOnMobileHelper.ShiftWrapper> wrapperList = ViewingRecordsOnMobileHelper.getShiftsList(serviceUser.Id);
        Test.stopTest();
        System.assertEquals(1, wrapperList.size(), 'The size of shiftList list should be 1');
        System.assertEquals('Confirmed', wrapperList[0].status, 'The status of shift should be confirmed');

    }

    @IsTest
    public static void getServiceResourceTest(){

        ServiceResource serviceResourceRecord = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' LIMIT 1];
        User serviceUser = [SELECT Id FROM User WHERE username = 'test_service_user1@test.com' LIMIT 1];

        Test.startTest();
        String serviceResourceId = ViewingRecordsOnMobileHelper.getServiceResource(serviceUser.Id);
        Test.stopTest();
        System.assertEquals(serviceResourceRecord.Id, serviceResourceId, 'The Id returned from method should be equal to the service resource we inserted');

    }

    public static void createShift(String resourceId){
        Time startShiftTime = Time.newInstance(8, 0, 0, 0);
        Time endShiftTime = Time.newInstance(20, 0, 0, 0);
        DateTime startShiftDate = DateTime.newInstance(system.today().addDays(1), startShiftTime);
        DateTime endShiftDate = DateTime.newInstance(system.today().addDays(1), endShiftTime);
        Shift shiftRecord = new Shift();
        shiftRecord.StartTime = startShiftDate;
        shiftRecord.endTime = endShiftDate;
        shiftRecord.ServiceResourceId = resourceId;
        shiftRecord.TimeSlotType = 'Normal';
        shiftRecord.Status = 'Confirmed';

        insert shiftRecord;
    }

    public static void createOvertimeOffers(String resourceId){
        Time startTime = Time.newInstance(8, 0, 0, 0);
        Time finishTime = Time.newInstance(12, 0, 0, 0);
        DateTime startDateTime = DateTime.newInstance(system.today(), startTime);
        DateTime finishDateTime = DateTime.newInstance(system.today(), finishTime);
        Overtime_Offers__c overtimeOfferRecord = new Overtime_Offers__c();
        overtimeOfferRecord.Offer_Start_Time__c = startDateTime;
        overtimeOfferRecord.Offer_Finish_Time__c = finishDateTime;
        overtimeOfferRecord.Status__c = 'Offered';
        overtimeOfferRecord.Service_Resource__c = resourceId;

        insert overtimeOfferRecord;
    }
}