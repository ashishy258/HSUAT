public with sharing class ImageCaptureController {
    
    @AuraEnabled(cacheable=true)
    public static List<ContentVersion> getContentDocumentId(String contentVersionId) {
        return [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            WITH SECURITY_ENFORCED
        ];
    }
    
    @AuraEnabled
    public static List<ContentVersion> getContentVersionId(String uniqueCvId) {
        return [
            SELECT Id
            FROM ContentVersion
            WHERE ReasonForChange = :uniqueCvId
            WITH SECURITY_ENFORCED
        ];
    }
    
    @AuraEnabled
    public static void createContentDocumentLink(String contentDocumentId,String imageType, String recordId) {
        System.debug('imageType ' +imageType);
        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = recordId,
            ContentDocumentId = contentDocumentId,
            ShareType = 'V'
        );
        Database.SaveResult[] srList = Database.insert(new List<ContentDocumentLink>{cdl}, false);
        NamedCredential namedCredential=[SELECT DeveloperName, Endpoint FROM NamedCredential where DeveloperName ='SFS_AWS_S3_Credentials' limit 1];
        // Iterate through each returned result
        for (Database.SaveResult sr : srList) {
        
            if (sr.isSuccess()) {
                // Operation was successful, so get the ID of the record that was processed
                System.debug('Successfully inserted account. Account ID: ' + sr.getId());
                
                
               ContentVersion version=[SELECT VersionData,Title,ContentDocumentId,FileExtension,FileType,Description FROM ContentVersion WHERE ContentDocumentId = :contentDocumentId limit 1];
    
                String relatedRecordId=recordId;
                String versionData=EncodingUtil.base64Encode(version.VersionData);
                String fileName=version.Title;
                string fileType=version.FileType;
                String fileImageType=imageType;
                String fileDescription=version.Description;
                String conDocumentId=contentDocumentId;
                String namedCredentialName=namedCredential.DeveloperName;
                String namedCredentialEndPoint=namedCredential.Endpoint;
                List<string> contentversionstring=new List<string>{relatedRecordId,versionData,fileName,fileType,fileImageType,fileDescription,conDocumentId,namedCredentialName,namedCredentialEndPoint};
                HS_AWSFileUploadUtil.uploadFileToAWS(contentversionstring);
            }
            else {
                // Operation failed, so get all errors                
                for(Database.Error err : sr.getErrors()) {
                    System.debug('The following error has occurred.');                    
                    System.debug(err.getStatusCode() + ': ' + err.getMessage());
                    System.debug('ContentDocumentLink fields that affected this error: ' + err.getFields());
                }
            }
        }
        }
        
        @AuraEnabled
        public static WorkOrder getWorkOrderDetails(String recordId){
            WorkOrder workOrderRec = [SELECT Id, Status, Process_Payments__c FROM WorkOrder WHERE Id =: recordId LIMIT 1];
            return workOrderRec;
        }
    }