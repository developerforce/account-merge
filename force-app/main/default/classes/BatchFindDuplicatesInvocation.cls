/**
 * @description Apex Class to run the search of record sync records in batches.
 */
public with sharing class BatchFindDuplicatesInvocation implements Database.Batchable<sObject> {
  private Record_Sync_Run__c recordSyncRun;
  private functions.Function findDuplicatesFunction;

  public BatchFindDuplicatesInvocation(
    Record_Sync_Run__c rsr,
    functions.Function findDuplicatesFunc
  ) {
    this.recordSyncRun = rsr;
    this.findDuplicatesFunction = findDuplicatesFunc;
  }
  /**
   * @description get the query locator.
   * @param  bc BatchableContext Context
   * @return query locator
   */
  public Database.querylocator start(Database.BatchableContext bc) {
    @SuppressWarnings('PMD.UnusedLocalVariable')
    Date fromDate = this.recordSyncRun.From__c;
    // TODO: make this generic to work with any object.
    return Database.getQueryLocator(
      'SELECT Id,' +
      this.recordSyncRun.Search_Fields__c +
      ' FROM Account WHERE LastModifiedDate >= :fromDate ORDER BY NAME LIMIT 10000'
    );
  }

  /**
   * @description execute find function in batches
   * @param  bc BatchableContext Context
   * @param records list of records to be processed
   */
  public void execute(Database.BatchableContext bc, List<sObject> records) {
    FunctionFindInput functionInput = new FunctionFindInput();
    functionInput.recordSyncRunId = this.recordSyncRun.Id;
    functionInput.searchFields = this.recordSyncRun.Search_Fields__c;
    functionInput.minimumScore = this.recordSyncRun.Minimum_Score__c > 0
      ? this.recordSyncRun.Minimum_Score__c / 100
      : 0;
    functionInput.targetRecordIds = (new Map<String, SObject>(records))
      .keySet();
    functions.FunctionInvocation invocation = this.findDuplicatesFunction.invoke(
      JSON.serialize(functionInput)
    );
    if (invocation.getStatus() == functions.FunctionInvocationStatus.ERROR) {
      throw new CalloutException(
        (invocation.getError() != null
          ? invocation.getError().getMessage()
          : 'UNKNOWN')
      );
    }
  }
  /**
   * @description Update record merge run to completed when all batches are done.
   * @param  bc BatchableContext Context
   */
  public void finish(Database.BatchableContext bc) {
    String recordSyncRunId = this.recordSyncRun.Id;
    Record_Sync_Run__c rsr = [
      SELECT Id, Duplicated_Records__c
      FROM Record_Sync_Run__c
      WHERE Id = :recordSyncRunId
      LIMIT 1
    ];
    if (rsr.Duplicated_Records__c > 0) {
      this.recordSyncRun.Status__c = 'Ready to Sync';
    } else {
      this.recordSyncRun.Status__c = 'No Records Found';
    }
    new Safely().doUpdate(this.recordSyncRun);
  }

  /**
   * @description Function Find Input
   */
  public class FunctionFindInput {
    public Id recordSyncRunId;
    public String searchFields;
    public Decimal minimumScore;
    public Set<String> targetRecordIds;
  }
}
