/**
* @description       :
* @author            : Salesforce Services
* @group             :
* @last modified on  : 11-04-2020
* @last modified by  : Salesforce Services
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   11-02-2020   Vandana Verma                 Initial Version
**/
@isTest
public class SFS_AWSFailedFileRetryBatch_Test {
 
    
    @TestSetup
    static void setup(){
        NamedCredential namedCredential=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName ='SFS_AWS_S3_Credentials' limit 1];
        
        //Create Parent Work Order
        WorkOrder workOrderRec = new WorkOrder();
        workOrderRec.Status = 'InProgress';
        workOrderRec.Wrap_Up__c = true;
        workOrderRec.Total_Due__c = 200;
        insert workOrderRec;
        system.debug('workOrderRec '+workOrderRec);
        //Creating Content Version record
        ContentVersion cv = new ContentVersion(Title = 'ABC',
                                               PathOnClient = 'test',
                                               VersionData = EncodingUtil.base64Decode('Unit Test Attachment Body'),
                                               ReasonForChange = 'TestClassCoverage',
                                               Description='Test Image'
                                              );
        insert cv;
        system.debug('cv '+cv);
        ContentVersion version=[SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,Description FROM ContentVersion limit 1];
        
        String filename='Test Image';
        String versionData='test data to upload';
        String url = 'callout:'+namedCredential.DeveloperName+'/'+filename;
        string enpointURL=namedCredential.Endpoint+'/'+filename;
        Work_Order_Files__c  newobj=new Work_Order_Files__c();
        newobj.AWS_S3_File_Path__c =enpointURL;
        newobj.AWS_S3_File_Upload_Status__c ='Failure';
        newobj.AWS_S3_Error_Message__c ='Some error occured';
        newobj.Description__c  ='Test File';
        newobj.Image_Type__c  ='Repair images';
        newobj.Work_Order__c =workOrderRec.Id;
        newobj.ContentDocumentId__c = version.ContentDocumentId;
        newobj.File_Size__c =String.valueOf(versionData.length());
        insert newobj;
        system.debug('newobj '+newobj);
    }
    
    @isTest
    static void testMethod1() {
        Test.setMock(HttpCalloutMock.class, new HS_HttpUtilMockSuccess());
        Test.startTest();
        
        SFS_AWSFailedFileRetryBatch nextBatch = new SFS_AWSFailedFileRetryBatch();
        Database.executeBatch(nextBatch, 200);
        
        Test.stopTest();
        
    } 
    @isTest
    static void testMethod2() {
        Test.setMock(HttpCalloutMock.class, new HS_HttpUtilMockFailure());
        Test.startTest();
        
        SFS_AWSFailedFileRetryBatch nextBatch = new SFS_AWSFailedFileRetryBatch();
        Database.executeBatch(nextBatch, 200);
        
        Test.stopTest();
        
    } 
}