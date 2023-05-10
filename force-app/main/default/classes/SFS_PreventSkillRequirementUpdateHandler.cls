public with sharing class SFS_PreventSkillRequirementUpdateHandler implements rflib_TriggerHandler{

    public void run(rflib_TriggerManager.Args args) {
        

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            preventSkillRequirementUpdate(args);
        }

        if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            preventSkillRequirementUpdate(args);
        }

    }

    public static void preventSkillRequirementUpdate(rflib_TriggerManager.Args args){
        Map<Id,Id> sr_Wo = new Map<id,Id>();

        List<SkillRequirement> records = new List<SkillRequirement>();

        if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
            records = (List<SkillRequirement>)args.newRecords;
        }
        else if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
            records = (List<SkillRequirement>)args.oldRecords;
        }
        
        for(SkillRequirement sr:  records){
            sr_Wo.put(sr.Id,sr.RelatedRecordId);
        }

        Map<Id,WorkOrder> wo_Map = new Map<Id,WorkOrder>([Select Id,Status from WorkOrder where Id IN :sr_Wo.values()]);

        for(SkillRequirement sr:  records){

            WorkOrder woObj  = wo_Map.get(sr.RelatedRecordId);

            if(woObj!=null && woObj.Status=='Completed'){
                sr.addError('This Work Order has been Completed and can no longer be updated');
            }
        }
    }

    public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
        return;
    }
}