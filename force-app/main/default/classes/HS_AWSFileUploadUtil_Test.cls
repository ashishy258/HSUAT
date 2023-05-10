/**
 * @description       :
 * @author            : Vandana Verma 
 * @group             :
 * @last modified on  : 04-04-2023
 * @last modified by  : Vandana Verma 
 * Modifications Log
 * Ver   Date         Author                               Modification
 * 1.0   04-04-2023   Vandana Verma                 Initial Version
 **/
@isTest
public class HS_AWSFileUploadUtil_Test {
   
    
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
                                  ReasonForChange = 'TestClassCoverage',
                                               Description='Test Image'
                                 );
        insert cv;
    }

    @isTest
    static void testMethod1() {
  Test.setMock(HttpCalloutMock.class, new HS_HttpUtilMockSuccess());
 NamedCredential namedCredential=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName ='SFS_AWS_S3_Credentials' limit 1];
        
string imageType='Repair Images';
     ContentVersion version=[SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,Description FROM ContentVersion limit 1];
    WorkOrder wo=[Select Id from WorkOrder limit 1];
                String relatedRecordId=wo.Id;
                String versionData=EncodingUtil.base64Encode(version.VersionData);
                String fileName=version.Title;
                string fileType=version.FileType;
                String fileImageType=imageType;
                String fileDescription=version.Description;
                String conDocumentId=version.ContentDocumentId;
                String namedCredentialName=namedCredential.DeveloperName;
                String namedCredentialEndPoint=namedCredential.Endpoint;
                List<string> contentversionstring=new List<string>{relatedRecordId,versionData,fileName,fileType,fileImageType,fileDescription,conDocumentId,namedCredentialName,namedCredentialEndPoint};
                HS_AWSFileUploadUtil.uploadFileToAWS(contentversionstring);
 HS_AWSFileUploadUtil.uploadFileToAWS(null);

  
    }
 @isTest
    static void testMethod2() {
  Test.setMock(HttpCalloutMock.class, new HS_HttpUtilMockFailure());
 NamedCredential namedCredential=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName ='SFS_AWS_S3_Credentials' limit 1];
        
string imageType='Repair Images';
     ContentVersion version=[SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,Description FROM ContentVersion limit 1];
    WorkOrder wo=[Select Id from WorkOrder limit 1];
                String relatedRecordId=wo.Id;
                String versionData=EncodingUtil.base64Encode(version.VersionData);
                String fileName=version.Title;
                string fileType=version.FileType;
                String fileImageType=imageType;
                String fileDescription=version.Description;
                String conDocumentId=version.ContentDocumentId;
                String namedCredentialName=namedCredential.DeveloperName;
                String namedCredentialEndPoint=namedCredential.Endpoint;
                List<string> contentversionstring=new List<string>{relatedRecordId,versionData,fileName,fileType,fileImageType,fileDescription,conDocumentId,namedCredentialName,namedCredentialEndPoint};
                HS_AWSFileUploadUtil.uploadFileToAWS(contentversionstring);
 HS_AWSFileUploadUtil.uploadFileToAWS(null);

  
    }

       
}