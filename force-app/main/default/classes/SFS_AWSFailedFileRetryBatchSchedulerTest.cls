@isTest
public class SFS_AWSFailedFileRetryBatchSchedulerTest {
    
    public static testMethod void testschedule() {
        
        Test.StartTest();
        SFS_AWSFailedFileRetryBatchScheduler sc = new SFS_AWSFailedFileRetryBatchScheduler();
        //Define cron expression
        String cronExp = '0 0 22 1/1 * ? *';
        String jobID = System.schedule('SFS_AWSFailedFileRetryBatch', cronExp, sc);
        Test.stopTest(); }
}