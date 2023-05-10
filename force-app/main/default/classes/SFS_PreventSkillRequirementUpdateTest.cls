/**
 * @description       : Cover the code coverage of SFS_PreventSkillRequirementUpdateHandler apex class
 * @author            : 
 * @group             :
 * @last modified on  : 02-26-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   02-15-2023   Ashish Yadav    Initial Version
 **/

 @IsTest
public with sharing class SFS_PreventSkillRequirementUpdateTest {


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
            
            Skill sk = [SELECT Id FROM Skill WHERE MasterLabel = 'Heating'];

            SkillRequirement sr = new SkillRequirement();
            sr.RelatedRecordId = wo.Id;
            sr.SkillId = sk.Id;
            sr.SkillLevel = 1;
            insert sr;


            wo.Status = 'Completed';
            update wo;

        }
    }

    @IsTest
    public static void testUpdateSkillRequirement(){
        

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SkillRequirement srObj = [Select id,RelatedRecordId,SkillId,SkillLevel from SkillRequirement];

            srObj.SkillLevel = 2;
            update srObj;
    
        } catch (Exception e) {
            exceptionThrown = true;
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Work Order has been Completed and can no longer be updated')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();
    }
    
    @IsTest
    public static void testDeleteSkillRequirement(){
        

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SkillRequirement srObj = [Select id,RelatedRecordId,SkillId,SkillLevel from SkillRequirement];
            delete srObj;
    
        } catch (Exception e) {
            exceptionThrown = true;
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Work Order has been Completed and can no longer be updated')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();
    }
    


}