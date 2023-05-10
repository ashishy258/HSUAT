/************************************************************************************************
Name              : HS_AWSFileUploadUtil
Description       : 
Revision History  : - 
Created/Modified by   Created/Modified Date     Requested by          Related Task/Issue             
Vandana Verma         14/April/2023      HomeServe 
*************************************************************************************************/
global class HS_AWSFileUploadUtil  {
    
    //This method is used to post file to AWS
    @future(callout=true)
    public static void uploadFileToAWS(List<string> fileData)
    {
        try
        {
            String relatedRecordId=fileData[0];
            String versionData=fileData[1];
            String fileName=fileData[2];
            string fileType=fileData[3];
            String fileImageType=fileData[4];
            String fileDescription=fileData[5];
            string contentDocumentId =fileData[6];
            String namedCredentialName=fileData[7];
            String namedCredentialEndPoint=fileData[8];
            
            List<Work_Order_Files__c > listToAdd=new List<Work_Order_Files__c >();
            
            String formattedDateString = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
            string contentType=ContentType(fileType);
            String url = 'callout:'+namedCredentialName+'/'+filename;
            string enpointURL=namedCredentialEndPoint+'/'+filename;
            
            
            HttpRequest req  = new HttpRequest();
            HttpResponse res  = new HttpResponse();
            req.setMethod('PUT');
            req.setEndpoint(url);
            req.setHeader('Content-Encoding', 'UTF-8');
            req.setHeader('Content-type', contentType);
            req.setHeader('Connection', 'keep-alive');
            req.setHeader('Date', formattedDateString);
            req.setHeader('ACL', 'public-read');
            Blob pdfBlob = EncodingUtil.base64Decode(versionData);
            req.setBodyAsBlob(pdfBlob);
            Http http = new Http();
            res = http.send(req);
            system.debug('res '+res);
            system.debug(res.getStatusCode());
            system.debug(res.getBody());     		
            if(res.getStatusCode() == 200){
                
                Work_Order_Files__c  newobj=new Work_Order_Files__c();
                newobj.AWS_S3_File_Path__c =enpointURL;
                newobj.AWS_S3_File_Upload_Status__c ='Success';
                newobj.AWS_S3_Error_Message__c ='';
                newobj.Description__c  =fileDescription;
                newobj.Image_Type__c  =fileImageType;
                newobj.Work_Order__c =relatedRecordId;
                newobj.ContentDocumentId__c =contentDocumentId;
                newobj.File_Size__c =String.valueOf(versionData.length());
                listToAdd.add(newobj);
                system.debug('Success uploaded');
            }
            else
			{
                system.debug('failure uploaded');            
                String exceptionMsg= 'Status Code is  ' +res.getStatusCode() + '    Status message is  ' +res.getStatus(); 
                System.debug(exceptionMsg);
                Work_Order_Files__c  newobj=new Work_Order_Files__c();
                newobj.AWS_S3_File_Path__c =enpointURL;
                newobj.AWS_S3_File_Upload_Status__c ='Failure';
                newobj.AWS_S3_Error_Message__c =exceptionMsg;
                newobj.Description__c  =fileDescription;
                newobj.Image_Type__c  =fileImageType;
                newobj.Work_Order__c =relatedRecordId;
                newobj.ContentDocumentId__c =contentDocumentId;
                newobj.File_Size__c =String.valueOf(versionData.length());
                listToAdd.add(newobj);
            }
            if(listToAdd!=null)
            {
                insert listToAdd;
            }
        }
        catch(Exception ex)
        {
            System.debug('excepition. '+ex.getMessage() );
        }
        
    } 
    
    
    public static HttpResponse uploadFileToAWSFromBatch(List<string> fileData,String workorderFileId)
    {
        HttpResponse res  = new HttpResponse();
        try
        {
            String relatedRecordId=fileData[0];
            String versionData=fileData[1];
            String fileName=fileData[2];
            string fileType=fileData[3];
            String fileImageType=fileData[4];
            String fileDescription=fileData[5];
            string contentDocumentId =fileData[6];
            String namedCredentialName=fileData[7];
            String namedCredentialEndPoint=fileData[8];            
            String formattedDateString = Datetime.now().formatGMT('EEE, dd MMM yyyy HH:mm:ss z');
            string contentType=ContentType(fileType);
            String url = 'callout:'+namedCredentialName+'/'+filename;
            string enpointURL=namedCredentialEndPoint+'/'+filename;
            
            HttpRequest req  = new HttpRequest();
            
            req.setMethod('PUT');
            req.setEndpoint(url);
            req.setHeader('Content-Encoding', 'UTF-8');
            req.setHeader('Content-type', contentType);
            req.setHeader('Connection', 'keep-alive');
            req.setHeader('Date', formattedDateString);
            req.setHeader('ACL', 'public-read');
            Blob pdfBlob = EncodingUtil.base64Decode(versionData);
            req.setBodyAsBlob(pdfBlob);
            Http http = new Http();
            res = http.send(req);
            system.debug('res '+res);
            system.debug(res.getStatusCode());
            system.debug(res.getBody()); 
        }
        catch(Exception ex)
        {
            System.debug('excepition. '+ex.getMessage() );
        }
        return res;
    }  
    
    /*  public static String getSignedURL(string file) {

// Retrieve and save aws credentials based on custom settings.
AWS_Configuration__c aws = AWS_Configuration__c.getValues('AWS_S3');
String BucketName= aws.Bucketname__c;  //AWS bucket name
String AccessKey= aws.Access_Key_Id__c;
String SecretKey= aws.Secret_access_key__c;
Decimal ExpiresonTime =aws.Expireson__c;
String filename ='Signature_0WO4C000007R6M5WAK.png'; //EncodingUtil.urlEncode(file, 'UTF-8');
Datetime now = DateTime.now();
Datetime expireson = now.AddSeconds(Integer.valueOf(ExpiresonTime)); // Lifespan of the link as per the custom settings
Long Lexpires = expireson.getTime()/1000;
BucketName='salesforce-field-service-nonprod';
AccessKey='';
SecretKey='';
String stringtosign = 'GET\n\n\n'+Lexpires+'\n/'+BucketName+'/'+filename;
System.debug('redirectToS3Key stringstosign: ' + stringtosign);

String signingKey = EncodingUtil.base64Encode(Blob.valueOf(SecretKey));
Blob  mac = Crypto.generateMac('HMacSHA1', blob.valueof(stringtosign),blob.valueof(SecretKey)); 
String signed= EncodingUtil.base64Encode(mac);
do {       	
system.debug('signed -- '+signed);
signed = signed.replace('+', '%2B');
} while (signed.contains('+'));
//


String aWSVersion ='s3v4';
String codedsigned = EncodingUtil.urlEncode(signed,'UTF-8');
String url = 'https://'+BucketName+'.s3-fips.us-east-1.amazonaws.com/'+filename+'?AWSAccessKeyId='+AccessKey+
'&Expires='+Lexpires+'&signature_version='+aWSVersion+'&Signature='+signed;

System.debug('url ------'+url );
return url;  
}*/
    public static string ContentType(string fileType)
    {
        
        switch on fileType.toLowerCase()
        {
            when 'docx'
            {
                return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            }
            when 'csv'
            {
                return 'application/vnd.ms-excel';
            }
            when 'wav'
            {
                return 'audio/wav';
            }
            when 'wmv'
            {
                return 'video/x-ms-wmv';
            }
            when 'mp3'
            {
                return 'audio/mpeg';
            }
            when 'mp4'
            {
                return 'video/mp4';
            }
            when 'png'
            {
                return 'image/png';
                
            }
            when 'pdf'
            {
                return 'application/pdf';
                
            }
            when else {
                return 'image/jpeg';
            }
        }
    }
    
    
}