/**
 * @description       :  Used to call Daily Capacity Batch inserts
 * @author            : Vandana/Ashish/Divya
 * @group             :
 * @last modified on  : 03-05-2023
 * Modifications Log
 * Ver   Date         Author          Modification
 * 1.0   03-05-2023   Vandana/Ashish/Divya   Initial Version
 **/
global class SFS_ABNewDayCapacityBatchScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        SFS_ABNewDayBatchDailyConsumedCapacity rebuildCapacityBatch = new SFS_ABNewDayBatchDailyConsumedCapacity();
        Database.executeBatch(rebuildCapacityBatch, 200);
    }
}