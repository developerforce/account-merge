/**
 * @description Apex Class to run the update duplicates function in batches.
 */
public with sharing class BatchUpdateDuplicatesInvocation implements Database.Batchable<sObject> {
  private Record_Sync_Run__c recordSyncRun;
  private functions.Function updateDuplicatesFunction;

  public BatchUpdateDuplicatesInvocation(
    Record_Sync_Run__c rsr,
    functions.Function updateDuplicatesFunc
  ) {
    this.recordSyncRun = rsr;
    this.updateDuplicatesFunction = updateDuplicatesFunc;
  }
  /**
   * @description get the query locator.
   * @param  bc BatchableContext Context
   * @return query locator
   */
  public Database.querylocator start(Database.BatchableContext bc) {
    Id recordSyncRunId = this.recordSyncRun.Id;
    return Database.getQueryLocator(
      'SELECT Id, Target_Record__c, Source_Record__c, Status__c FROM Record_Sync__c WHERE Record_Sync_Run__c = :recordSyncRunId'
    );
  }
  /**
   * @description execute the update function in batches.
   * @param  bc BatchableContext Context
   * @param records list of records to be processed
   */
  public void execute(Database.BatchableContext bc, List<sObject> records) {
    FunctionUpdateInput functionInput = new FunctionUpdateInput();
    functionInput.recordSyncIds = (new Map<Id, SObject>(records)).keySet();
    functionInput.fields = this.recordSyncRun.Update_Fields__c;
    functions.FunctionInvocation invocation = this.updateDuplicatesFunction.invoke(
      JSON.serialize(functionInput)
    );
    // Check if there is any error during the invocation
    if (invocation.getStatus() == functions.FunctionInvocationStatus.ERROR) {
      throw new CalloutException(
        (invocation.getError() != null
          ? invocation.getError().getMessage()
          : 'UNKNOWN')
      );
    }
  }
  /**
   * @description Update record sync run to completed when all batches are done.
   * @param  bc BatchableContext Context
   */
  public void finish(Database.BatchableContext bc) {
    this.recordSyncRun.Status__c = 'Completed';
    new Safely().doUpdate(this.recordSyncRun);
  }

  public class FunctionUpdateInput {
    public Set<Id> recordSyncIds;
    public String fields;
  }
}
