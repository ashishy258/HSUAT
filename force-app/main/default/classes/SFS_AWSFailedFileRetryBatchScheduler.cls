/**
 * @description       :  Used to call Daily Capacity Batch inserts
 * @author            : Vandana Verma
 * @group             :
 * @last modified on  : 26-04-2023
 * Modifications Log
 * Ver   Date         Author          Modification
 * 1.0   26-04-2023   Vandana Verma   Initial Version
 **/
/*

To execute execute below code in anonymous window
SFS_AWSFailedFileRetryBatchScheduler sc = new SFS_AWSFailedFileRetryBatchScheduler();
//Define cron expression
String cronExp = '0 0 22 1/1 * ? *';
String jobID = System.schedule('SFS_AWSFailedFileRetryBatch', cronExp, sc);


*/
global class SFS_AWSFailedFileRetryBatchScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        SFS_AWSFailedFileRetryBatch awsFailedFileRetryBatch = new SFS_AWSFailedFileRetryBatch();
        Database.executeBatch(awsFailedFileRetryBatch, 200);
    }
}