@isTest
public class SFS_ABNewDayCapacityBatchSchedulerTest {
    
    public static testMethod void testschedule() {
        
        Test.StartTest();
        SFS_ABNewDayCapacityBatchScheduler sc = new SFS_ABNewDayCapacityBatchScheduler();
        //Define cron expression
        String cronExp = '0 0 23 1/1 * ? *';
        String jobID = System.schedule('SFS_ABNewDayBatchDailyConsumedCapacity', cronExp, sc);
        Test.stopTest(); }
}