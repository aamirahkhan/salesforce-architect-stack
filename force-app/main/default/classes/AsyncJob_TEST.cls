@IsTest
private class AsyncJob_TEST {
    private static Integer queueableRuns = 0;
    private static Integer batchRecordCount = 0;
    private static Integer scheduledRuns = 0;

    private class SampleQueueableJob extends QueueableJob {
        public override void run(QueueableContext context) {
            queueableRuns++;
        }
    }

    private class FailingQueueableJob extends QueueableJob {
        public override void run(QueueableContext context) {
            throw AppException.async('Queueable failure for test.');
        }
    }

    private class SampleBatchJob extends BatchJob {
        public override String getQuery() {
            return 'SELECT Id FROM Account';
        }

        public override void run(Database.BatchableContext context, List<SObject> scope) {
            batchRecordCount += scope.size();
        }
    }

    private class FailingBatchJob extends BatchJob {
        public override String getQuery() {
            return 'SELECT Id FROM Account';
        }

        public override void run(Database.BatchableContext context, List<SObject> scope) {
            throw AppException.async('Batch failure for test.');
        }
    }

    private class SampleSchedulableJob extends SchedulableJob {
        public override void run(SchedulableContext context) {
            scheduledRuns++;
        }
    }

    @IsTest
    static void runsQueueableJob() {
        Test.startTest();
        System.enqueueJob(new SampleQueueableJob());
        Test.stopTest();

        Assert.areEqual(1, queueableRuns);
    }

    @IsTest
    static void runsBatchJob() {
        TestDataFactory.insertAccounts(2);

        Test.startTest();
        new SampleBatchJob().submit();
        Test.stopTest();

        Assert.areEqual(2, batchRecordCount);
    }

    @IsTest
    static void runsScheduledJob() {
        Test.startTest();
        Id jobId = System.schedule('AsyncJob_TEST', '0 0 0 1 1 ? 2099', new SampleSchedulableJob());
        Test.stopTest();

        Assert.isNotNull(jobId, 'The job should be registered with the scheduler.');

        // Test.stopTest() does not execute future-scheduled jobs, so exercise the body directly.
        new SampleSchedulableJob().execute(null);
        Assert.areEqual(1, scheduledRuns);
    }

    @IsTest
    static void queueableRethrowsAndLogsFailures() {
        FailingQueueableJob job = new FailingQueueableJob();

        try {
            job.execute(null);
            Assert.fail('Expected the queueable to rethrow.');
        } catch (AppException problem) {
            Assert.areEqual(AppException.ASYNC, problem.errorCode);
        }

        Integer errorLogCount = [SELECT COUNT() FROM ApplicationLog__c WHERE Level__c = 'ERROR' WITH SYSTEM_MODE];
        Assert.isTrue(errorLogCount >= 1, 'The queueable failure should be logged.');
    }

    @IsTest
    static void batchScopeFailuresAreLoggedAndDoNotAbort() {
        TestDataFactory.insertAccounts(2);

        Test.startTest();
        Database.executeBatch(new FailingBatchJob(), 200);
        Test.stopTest();

        Integer errorLogCount = [SELECT COUNT() FROM ApplicationLog__c WHERE Level__c = 'ERROR' WITH SYSTEM_MODE];
        Assert.isTrue(errorLogCount >= 1, 'The batch failure should be logged without aborting the job.');
    }

    @IsTest
    static void exposesJobNames() {
        Assert.areEqual('SampleQueueableJob', new SampleQueueableJob().getJobName());
        Assert.areEqual('SampleBatchJob', new SampleBatchJob().getJobName());
        Assert.areEqual('SampleSchedulableJob', new SampleSchedulableJob().getJobName());
    }
}
