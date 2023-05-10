public with sharing class SFS_PreventResourcePrefUpdateHandler implements rflib_TriggerHandler
{
    

        public void run(rflib_TriggerManager.Args args) {
        
            if (args.operation == System.TriggerOperation.BEFORE_INSERT) {
                PreventResourcePreferenceUpdate(args);
            }

            if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
                PreventResourcePreferenceUpdate(args);
            }
    
            if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
                PreventResourcePreferenceUpdate(args);
            }
    
        }

        public static void PreventResourcePreferenceUpdate(rflib_TriggerManager.Args args){
            Map<Id,Id> Rp_Wo = new Map<id,Id>();
    
            List<ResourcePreference> records = new List<ResourcePreference>();
    
            if (args.operation == System.TriggerOperation.BEFORE_UPDATE) {
                records = (List<ResourcePreference>)args.newRecords;
            }
            else if(args.operation == System.TriggerOperation.BEFORE_INSERT)
            {
                records = (List<ResourcePreference>)args.newRecords;
            }
            else if (args.operation == System.TriggerOperation.BEFORE_DELETE) {
                records = (List<ResourcePreference>)args.oldRecords;
            }
            


            for(ResourcePreference rp:  records){
                Rp_Wo.put(rp.Id,rp.RelatedRecordId);
            }
    
            Map<Id,WorkOrder> wo_Map = new Map<Id,WorkOrder>([Select Id,Status from WorkOrder where Id IN :Rp_Wo.values()]);
    
            for(ResourcePreference rp:  records){
    
                WorkOrder woObj  = wo_Map.get(rp.RelatedRecordId);
    
                if(woObj!=null && woObj.Status=='Completed'){
                    rp.addError('This Work Order has been Completed and can no longer be updated');
                }
            }
        }
    
        public void onConsecutiveRun(rflib_TriggerManager.Args args, Integer numInvocation) {
            return;
        }
    

}