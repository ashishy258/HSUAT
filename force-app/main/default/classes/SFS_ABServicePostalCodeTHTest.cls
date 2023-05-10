/**
 * @description       : Cover the code coverage of SFS_ABServicePostalCodeTriggerHandler apex class
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 02-15-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   02-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class SFS_ABServicePostalCodeTHTest {

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

            //Creating Service Resource
            ServiceResource serviceResource1 = SFS_ABTestFactory.createServiceResource(serviceUser1);

            //Creating Postal Code
            List<Postal_Codes__c> postalCodeList = new List<Postal_Codes__c>{
                new Postal_Codes__c(Name = '01007'),
                new Postal_Codes__c(Name = '01008')
            };
            insert postalCodeList;

            //Creating Serviceable Postal Code Junction Object record
            Serviceable_Postal_Code__c svcPostalCode = new Serviceable_Postal_Code__c(Service_Resource__c = serviceResource1.Id, Postal_Code__c = postalCodeList[0].Id);
            insert svcPostalCode;
        }
    }

    @IsTest
    public static void testInsertingDuplicateSvcPostalCode(){

        ServiceResource serviceResourceRecord = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' LIMIT 1];
        Postal_Codes__c postalCode01007 = [SELECT Id FROM Postal_Codes__c WHERE Name = '01007' LIMIT 1];

        Serviceable_Postal_Code__c svcPostalCode = [SELECT Id, Service_Resource__r.Name, Postal_Code__r.Name FROM Serviceable_Postal_Code__c LIMIT 1];
        System.assertEquals('Test ServiceResource1', svcPostalCode.Service_Resource__r.Name, 'The Name of service resource should be Test ServiceResource1.');
        System.assertEquals('01007', svcPostalCode.Postal_Code__r.Name, 'The existing postal code on above service resource is 01007.');

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            //Creating Serviceable Postal Code Junction Object record for same service resource with duplicate postal code
            Serviceable_Postal_Code__c duplicateSvcPostalCode = new Serviceable_Postal_Code__c(Service_Resource__c = serviceResourceRecord.Id, Postal_Code__c = postalCode01007.Id);
            insert duplicateSvcPostalCode; 
    
        } catch (Exception e) {
            exceptionThrown = true;
    
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Serviceable Postal Code has already been added to the Resource')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();

        List<Serviceable_Postal_Code__c> svcPostalCodeList = [SELECT Id, Service_Resource__r.Name, Postal_Code__r.Name FROM Serviceable_Postal_Code__c WHERE Service_Resource__c =: serviceResourceRecord.Id];
        System.assertEquals(1, svcPostalCodeList.size(), 'The size of list should remains one as we are not allowing suplicate postal code for same service resource.');
    }

    @IsTest
    public static void testUpdatingDuplicateSvcPostalCode(){

        ServiceResource serviceResourceRecord = [SELECT Id FROM ServiceResource WHERE Name = 'Test serviceResource1' LIMIT 1];
        Postal_Codes__c postalCode01007 = [SELECT Id FROM Postal_Codes__c WHERE Name = '01007' LIMIT 1];
        Postal_Codes__c postalCode01008 = [SELECT Id FROM Postal_Codes__c WHERE Name = '01008' LIMIT 1];

        Serviceable_Postal_Code__c SvcPostalCode01008 = new Serviceable_Postal_Code__c(Service_Resource__c = serviceResourceRecord.Id, Postal_Code__c = postalCode01008.Id);
        insert SvcPostalCode01008;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            //Creating Serviceable Postal Code Junction Object record for same service resource with duplicate postal code
            Serviceable_Postal_Code__c duplicateSvcPostalCode = new Serviceable_Postal_Code__c(Id = SvcPostalCode01008.Id, Postal_Code__c = postalCode01007.Id);
            update duplicateSvcPostalCode; 
    
        } catch (Exception e) {
            exceptionThrown = true;
    
            // assert
            Boolean expectedExceptionThrown =  (e.getMessage().contains('This Serviceable Postal Code has already been added to the Resource')) ? true : false; 
            System.assertEquals(true, expectedExceptionThrown, e.getMessage()); 
        }
        Test.stopTest();
        
        List<Serviceable_Postal_Code__c> svcPostalCodeList = [SELECT Id, Service_Resource__r.Name, Postal_Code__r.Name FROM Serviceable_Postal_Code__c WHERE Service_Resource__c =: serviceResourceRecord.Id AND Postal_Code__c =: postalCode01007.Id];
        System.assertEquals(1, svcPostalCodeList.size(), 'The size of list should remains one as we are not allowing suplicate postal code for same service resource.');
    }
}