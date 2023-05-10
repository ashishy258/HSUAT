public without sharing class HS_SignatureHelper {
    public HS_SignatureHelper() {
        
    }
    
    @AuraEnabled(cacheable=true)
    public static WorkOrder isSignatureScreenVisible(String recordId, Decimal randomNumber){
        WorkOrder wo=[select id,Wrap_Up__c,Status from WorkOrder where Id= :recordId limit 1];
        system.debug('wo.Wrap_Up__c: ' + wo.Wrap_Up__c);
        return wo;
    }
    
    @AuraEnabled
    public static void saveSign(String relatedId,String strSignElement,Boolean customerDeclined){
        System.debug('relatedId '+relatedId);
        System.debug('customerDeclined '+customerDeclined);
        System.debug('strSignElement '+strSignElement);
        List<ContentVersion> cVersionList = new  List<ContentVersion>();
        ServiceAppointment sa=[select id,Work_Order__c,Status from ServiceAppointment where Work_Order__c= :relatedId limit 1];
        if(customerDeclined)
        {
            WorkOrder wo=[select id,Customer_Declined_to_Sign__c from WorkOrder where Id= :relatedId limit 1];
            wo.Customer_Declined_to_Sign__c=customerDeclined;
            update wo;
            
            //update service appointment
            sa.Status = SFS_ABConstantUtil.SA_COMPLETED;
            sa.Mobile_End_Time__c=DateTime.now();
            update sa;
        }
        else{
            System.debug(' strSignElement  '+strSignElement);
            ContentVersion cVersion = new ContentVersion();
            cVersion.ContentLocation = 'S'; //S-Document is in Salesforce.
            cVersion.PathOnClient = 'Signature-'+System.now() +'.png';//File name with extention
            cVersion.Origin = 'H';//C-Content Origin. H-Chatter Origin.
            cVersion.Title = 'Signature_'+relatedId+'-'+System.now() +'.png';//Name of the file
            cVersion.VersionData = EncodingUtil.base64Decode(strSignElement);//File content
            System.debug(' VersionData  '+cVersion.VersionData);
            
            insert cVersion;
            //Get the Uploaded doc ContentDocumentId
            Id conDocument = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:cVersion.Id].ContentDocumentId;
            
            //Insert ContentDocumentLink to share 
            ContentDocumentLink cDocLink = new ContentDocumentLink();
            cDocLink.ContentDocumentId = conDocument;
            cDocLink.LinkedEntityId = relatedId;
            cDocLink.ShareType = 'I';
            cDocLink.Visibility = 'AllUsers';
            Insert cDocLink;
            //Insert in S3
          
           // HS_AWSUploadDownloadFiles.putFileInS3(cDocLink.LinkedEntityId,cVersion);
            
            //update service appointment
            sa.Status = SFS_ABConstantUtil.SA_COMPLETED;
            sa.Mobile_End_Time__c=DateTime.now();
            update sa;
        }
    }

    @AuraEnabled(cacheable=true)
    public static WorkOrder costInformation(String recordId, Decimal randomNumber){
        WorkOrder workOrderRec = [SELECT Id, Tax, Total_Labor__c, Total_Parts__c, Total_Adjustments__c, Total_Service_Call__c, Outstanding_Balance__c, Total_Savings__c, Total_Due__c FROM WorkOrder WHERE Id =: recordId LIMIT 1];
        return workOrderRec;
    }
}