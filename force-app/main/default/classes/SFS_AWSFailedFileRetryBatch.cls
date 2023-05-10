/**
* @description       : To retry sending failed content version
* @author            : Salesforce Services
* @group             :
* @last modified on  : 18-04-2023
* Modifications Log
* Ver   Date         Author                    Modification
* 1.0   18-04-2023   Vandana Verma      Initial Version
**/
global class SFS_AWSFailedFileRetryBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
    public SFS_AWSFailedFileRetryBatch() {
        
    }
    
    // Initial Query to get the Capacity Rebuild Jobs
    global Database.QueryLocator start(Database.BatchableContext BC) {
        Set<String> imageType = new Set<String>{'Face Plate Images', 'Repair Images'};
            String query = 'SELECT Id,ContentDocumentId__c, Work_Order__c, Image_Type__c   FROM Work_Order_Files__c where AWS_S3_File_Upload_Status__c=  \'Failure\' and Image_Type__c In :imageType';
        return Database.getQueryLocator(query);
    }
    
    // Execute to process the Cap Rebuild Jobs and Start the next batch
    global void execute(Database.BatchableContext BC, List<Work_Order_Files__c> fileList) {
        List<Work_Order_Files__c > listToAdd=new List<Work_Order_Files__c >();
        try {
            Map<String,Work_Order_Files__c> contentDocumentIdFileMap=new Map<String,Work_Order_Files__c>();
            NamedCredential namedCredential=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName ='SFS_AWS_S3_Credentials' limit 1];
            for(Work_Order_Files__c file:fileList)
            {
                contentDocumentIdFileMap.put(file.ContentDocumentId__c,file);
            }
            List<ContentVersion> versionList=[SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,Description FROM ContentVersion WHERE ContentDocumentId In :contentDocumentIdFileMap.keyset()];
            System.debug('versionList '+versionList);
            for(ContentVersion version : versionList)
            {
                String relatedRecordId=contentDocumentIdFileMap.get(version.ContentDocumentId).Work_Order__c;
                String versionData=EncodingUtil.base64Encode(version.VersionData);
                String fileName=version.Title;
                string fileType=version.FileType;
                String fileImageType=contentDocumentIdFileMap.get(version.ContentDocumentId).Image_Type__c;
                String fileDescription=version.Description;
                String conDocumentId=version.ContentDocumentId;
                String namedCredentialName=namedCredential.DeveloperName;
                String namedCredentialEndPoint=namedCredential.Endpoint;
                String workorderFileId=contentDocumentIdFileMap.get(version.ContentDocumentId).Id;
                List<string> contentversionstring=new List<string>{relatedRecordId,versionData,fileName,fileType,fileImageType,fileDescription,conDocumentId,namedCredentialName,namedCredentialEndPoint};
                    System.debug('contentversionstring '+contentversionstring);
                HttpResponse res=HS_AWSFileUploadUtil.uploadFileToAWSFromBatch(contentversionstring,workorderFileId);
                
                if(res.getStatusCode() == 200){
                    
                    Work_Order_Files__c  newobj=new Work_Order_Files__c();
                    newObj.Id=workorderFileId;
                    newobj.AWS_S3_File_Upload_Status__c ='Success';
                    newobj.AWS_S3_Error_Message__c ='';
                    listToAdd.add(newobj);
                    
                    system.debug('Success uploaded');
                }
                else{
                    Work_Order_Files__c  newobj=new Work_Order_Files__c();
                    newObj.Id=workorderFileId;
                    newobj.AWS_S3_File_Upload_Status__c ='Failure';
                    newobj.AWS_S3_Error_Message__c ='';
                    
                    listToAdd.add(newobj);
                    
                    system.debug('failure uploaded');            
                    String exceptionMsg= 'Status Code is  ' +res.getStatusCode() + '    Status message is  ' +res.getStatus(); 
                    System.debug(exceptionMsg);
                    
                }
            }
            if(listToAdd!=null)
            {
                update listToAdd;
            }        }
        catch(Exception ex)
        {
            System.debug('Error occured '+ex.getMessage());
        }
        
    }
    
    // call the Resource Capacity rebuild batch for the relevant STMs
    global void finish(Database.BatchableContext BC) {
        if(!Test.isRunningTest())
        {
            AsyncApexJob job = [SELECT Id, Status FROM AsyncApexJob WHERE Id = :bc.getJobId()]; 
            System.debug('>>>> finish ' + job.Status);
        }
    }
    
}