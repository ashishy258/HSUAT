@IsTest
public with sharing class SFS_PreventResourcePrefUpdateTest {

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
        WorkOrder wo = HSTestFactory.createWorkOrder();

        //Creating Service Resource
        ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);


        //Creating Resource Preference Junction Object record
        ResourcePreference svcResourcePreference = new ResourcePreference
        (RelatedRecordId = wo.Id, 
        ServiceResourceId = serviceResource1.Id,
        PreferenceType = 'Preferred'
        );
        insert svcResourcePreference;
        
        wo.Status = 'Completed';
            update wo;

        }
    }

    @IsTest
    public static void testUpdatingResourcePreference(){

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ResourcePreference rpObj = [Select id,RelatedRecordId,ServiceResourceId,PreferenceType from ResourcePreference];

            rpObj.PreferenceType = 'Excluded';
            update rpObj;
    
        } catch (Exception e) {
            exceptionThrown = true;
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Work Order has been Completed and can no longer be updated')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();

    }

    @IsTest
    public static void testDeletionOfResourcePreference(){

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ResourcePreference rpObj = [Select id,RelatedRecordId,ServiceResourceId,PreferenceType from ResourcePreference];
            delete rpObj;
    
        } catch (Exception e) {
            exceptionThrown = true;
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Work Order has been Completed and can no longer be updated')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();

    }

    @IsTest
    public static void testInsertionOfResourcePreference(){
        WorkOrder woRecord = [SELECT Id FROM WorkOrder LIMIT 1];
        ServiceResource srRecord = [SELECT Id FROM ServiceResource LIMIT 1];
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ResourcePreference svcResourcePreference = new ResourcePreference
            (RelatedRecordId = woRecord.Id, 
            ServiceResourceId = srRecord.Id,
            PreferenceType = 'Preferred'
            );
            insert svcResourcePreference;
    
        } catch (Exception e) {
            exceptionThrown = true;
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Work Order has been Completed and can no longer be updated')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();

    }
}