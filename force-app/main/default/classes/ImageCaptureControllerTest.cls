/**
 * @description       : Cover the code coverage of ImageCaptureController apex class
 * @author            : Ashish Yadav
 * @group             :
 * @last modified on  : 04-21-2023
 * Modifications Log
 * Ver   Date         Author                 Modification
 * 1.0   04-15-2023   Ashish Yadav    Initial Version
 **/
@IsTest
public class ImageCaptureControllerTest {

    @TestSetup
    static void setup(){
        
        //Create Parent Work Order
        WorkOrder workOrderRec = new WorkOrder();
        workOrderRec.Status = 'InProgress';
        workOrderRec.Wrap_Up__c = true;
        workOrderRec.Total_Due__c = 200;
        insert workOrderRec;
            
        //Creating Content Version record
        ContentVersion cv = new ContentVersion(Title = 'ABC',
                                  PathOnClient = 'test',
                                  VersionData = EncodingUtil.base64Decode('Unit Test Attachment Body'),
                                  ReasonForChange = 'TestClassCoverage'
                                 );
        insert cv;
    }

    @IsTest
    public static void getContentDocumentIdTest(){

        ContentVersion cvRecord = [SELECT Id FROM ContentVersion LIMIT 1];

        Test.startTest();
        List<ContentVersion> contentVersionList = ImageCaptureController.getContentDocumentId(cvRecord.Id);
        Test.stopTest();
        System.assertEquals(1, contentVersionList.size(), 'The size of contentVersion list should be 1');
    }

    @IsTest
    public static void getContentVersionIdTest(){

        ContentVersion cvRecord = [SELECT Id, ReasonForChange FROM ContentVersion LIMIT 1];

        Test.startTest();
        List<ContentVersion> contentVersionList = ImageCaptureController.getContentVersionId(cvRecord.ReasonForChange);
        Test.stopTest();
        System.assertEquals(1, contentVersionList.size(), 'The size of contentVersion list should be 1');
    }

    @IsTest
    public static void createContentDocumentLinkTest(){

        ContentVersion cvRecord = [SELECT Id, ContentDocumentId FROM ContentVersion LIMIT 1];
        WorkOrder woRecord = [SELECT Id FROM WorkOrder LIMIT 1];

        Test.startTest();
        ImageCaptureController.createContentDocumentLink(cvRecord.ContentDocumentId, 'Repair Images', woRecord.Id);
        Test.stopTest();

        ContentDocumentLink cdlRec = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId =: woRecord.Id LIMIT 1];
        System.assertEquals(woRecord.Id, cdlRec.LinkedEntityId, 'The LinkedEntityId of CDL and WorkOrder Id should be same');
    }

    @isTest
    static void getWorkOrderDetailsTest() {
        Test.StartTest();
        WorkOrder woRecord = [SELECT Id FROM WorkOrder LIMIT 1];
		WorkOrder workOrderRec = ImageCaptureController.getWorkOrderDetails(woRecord.Id);
        Test.StopTest();   
        System.assertEquals('InProgress', workOrderRec.Status, 'The status of fetched workOrder should be InProgress');
    }
}