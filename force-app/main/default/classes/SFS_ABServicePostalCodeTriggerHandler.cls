public with sharing class SFS_ABServicePostalCodeTriggerHandler implements rflib_TriggerHandler {
    

    public void run(rflib_TriggerManager.Args args) {
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            preventDuplicatePostalCodes(args);
        }

        if (args.operation == System.TriggerOperation.AFTER_INSERT) {
        }

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            preventDuplicatePostalCodes(args);
        }

        if (args.operation == System.TriggerOperation.AFTER_UPDATE) {
        }

        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
        }

        if (args.operation == System.TriggerOperation.AFTER_DELETE) {
        }
    }

    public static void preventDuplicatePostalCodes(rflib_TriggerManager.Args args){

        List<Serviceable_Postal_Code__c> newServiceablePostalCodeRecords = new List<Serviceable_Postal_Code__c>();
        if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
            newServiceablePostalCodeRecords = (List<Serviceable_Postal_Code__c>) args.newRecords;
        }

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            for (Serviceable_Postal_Code__c svcPostalRec : (List<Serviceable_Postal_Code__c>) args.newRecords) {
                Serviceable_Postal_Code__c oldSVCPostalRec = (Serviceable_Postal_Code__c) args.oldRecordsMap.get(svcPostalRec.Id);
                if (oldSVCPostalRec.Service_Resource__c != svcPostalRec.Service_Resource__c || oldSVCPostalRec.Postal_Code__c != svcPostalRec.Postal_Code__c ) {
                    newServiceablePostalCodeRecords.add(svcPostalRec);
                }
            }
        }

        Map<String, List<String>> svcResourceToPostalCodeMap = new Map<String, List<String>>();
        for (Serviceable_Postal_Code__c spcRec : newServiceablePostalCodeRecords) {
            if (!svcResourceToPostalCodeMap.containsKey(spcRec.Service_Resource__c)) {
                svcResourceToPostalCodeMap.put(spcRec.Service_Resource__c, new List<String>());
            }
            svcResourceToPostalCodeMap.get(spcRec.Service_Resource__c).add(spcRec.Postal_Code__c);
        }

        List<Serviceable_Postal_Code__c> existingServiceablePostalCodeList = [SELECT Id, Service_Resource__c, Postal_Code__c FROM Serviceable_Postal_Code__c WHERE Service_Resource__c IN : svcResourceToPostalCodeMap.keySet()];

        for (Serviceable_Postal_Code__c existingsvcPostalRec : existingServiceablePostalCodeList) {
            if (!svcResourceToPostalCodeMap.containsKey(existingsvcPostalRec.Service_Resource__c)) {
                svcResourceToPostalCodeMap.put(existingsvcPostalRec.Service_Resource__c, new List<String>());
            }
            svcResourceToPostalCodeMap.get(existingsvcPostalRec.Service_Resource__c).add(existingsvcPostalRec.Postal_Code__c);
        }

        for (Serviceable_Postal_Code__c spcRec : newServiceablePostalCodeRecords) {
            Integer dupliatePostalCodeInstance = 0;
            if (svcResourceToPostalCodeMap.containsKey(spcRec.Service_Resource__c)) {
                for (String postalCode : svcResourceToPostalCodeMap.get(spcRec.Service_Resource__c)) {
                    if (spcRec.Postal_Code__c == postalCode) {
                        dupliatePostalCodeInstance = dupliatePostalCodeInstance + 1;
                    }
                }
            }

            if (dupliatePostalCodeInstance > 1) {
                spcRec.addError('This Serviceable Postal Code has already been added to the Resource');
            }
        }
    }

    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
        return;
    }
}