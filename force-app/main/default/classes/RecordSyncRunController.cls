/**
 * @description Apex Class to hanlde Record Sync Run records.
 */
public with sharing class RecordSyncRunController {
  /**
   * @description Method to retrieve standard fields from the Object
   * @return List of type FieldWrapper
   */
  @AuraEnabled(cacheable=true)
  public static FieldListWrapper getRecordFields() {
    // TODO: pass object name as param
    List<FieldWrapper> searchFields = new List<FieldWrapper>();
    List<FieldWrapper> updateFields = new List<FieldWrapper>();
    List<String> excludedFields = new List<String>{
      'CleanStatus',
      'ParentId',
      'OperatingHoursId',
      'CreatedById',
      'LastModifiedById',
      'MasterRecordId',
      'OwnerId',
      'DandbCompanyId'
    };
    SObjectType objectType = Schema.getGlobalDescribe().get('Account');
    Map<String, Schema.SObjectField> objectFields = objectType.getDescribe()
      .fields.getMap();
    for (Schema.SObjectField field : objectFields.values()) {
      Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
      if (
        !fieldDescribe.isCustom() &&
        (fieldDescribe.getType().name().toUpperCase() == 'STRING' ||
        fieldDescribe.getType().name().toUpperCase() == 'TEXTAREA')
      ) {
        searchFields.add(
          new FieldWrapper(fieldDescribe.getLabel(), fieldDescribe.getName())
        );
      }
      if (
        fieldDescribe.isUpdateable() &&
        !excludedFields.contains(fieldDescribe.getName())
      ) {
        updateFields.add(
          new FieldWrapper(fieldDescribe.getLabel(), fieldDescribe.getName())
        );
      }
    }
    return new FieldListWrapper(searchFields, updateFields);
  }

  /**
   * @description Create Record Sync Run
   *
   * @param  searchFields API field names from the object selected that are being used for finding duplicates.
   * @param  fromDate date to start find from.
   * @param  minimumScore score to be used in postrgres function to find duplicates
   * @return record Id
   */
  @AuraEnabled
  public static String createSyncRun(
    String searchFields,
    String updateFields,
    Date fromDate,
    Integer minimumScore
  ) {
    try {
      Record_Sync_Run__c recordSyncRun = new Record_Sync_Run__c(
        Search_Fields__c = searchFields,
        Update_Fields__c = updateFields,
        From__c = fromDate,
        Minimum_Score__c = minimumScore,
        Status__c = 'Search In Progress'
      );
      List<Database.SaveResult> recordSyncRuns = new Safely()
        .doInsert(recordSyncRun);
      Database.SaveResult result = recordSyncRuns.get(0);
      if (result != null && result.isSuccess()) {
        Record_Sync_Run__c recordSyncRunInserted = [
          SELECT Id, Search_Fields__c, From__c, Minimum_Score__c, Status__c
          FROM Record_Sync_Run__c
          WHERE Id = :result.getId()
          WITH SECURITY_ENFORCED
          LIMIT 1
        ];
        functions.Function findDuplicatesFx = functions.Function.get(
          'record_sync_app.findduplicatedrecords'
        );
        BatchFindDuplicatesInvocation findInvocation = new BatchFindDuplicatesInvocation(
          recordSyncRunInserted,
          findDuplicatesFx
        );
        Database.executeBatch(findInvocation, 200);
        return recordSyncRunInserted.Id;
      }
      return null;
    } catch (Exception e) {
      throw new AuraHandledException(e.getMessage());
    }
  }
  /**
   * @description Invocable Method to call Update Duplicates function
   *
   * @param  recordSyncRun List of records of type Record_Sync_Run__c to find duplicate records
   * @return List of updated Record_Sync_Run__c records from the function
   */
  @InvocableMethod(label='Update Duplicates')
  public static List<String> updateDuplicatesAction(
    List<Record_Sync_Run__c> recordSyncRun
  ) {
    functions.Function updateDuplicatesFx = functions.Function.get(
      'record_sync_app.updateduplicatedrecords'
    );
    BatchUpdateDuplicatesInvocation batchUpdateDuplicatesInvocation = new BatchUpdateDuplicatesInvocation(
      recordSyncRun.get(0),
      updateDuplicatesFx
    );
    String batchId = Database.executeBatch(
      batchUpdateDuplicatesInvocation,
      500
    );
    recordSyncRun.get(0).Status__c = 'Sync In Progress';
    new Safely().doUpdate(recordSyncRun);
    return new List<String>{ batchId };
  }

  /**
   * @description Custom wrapper for Record fields Labels and API Names into LWC
   */
  public class FieldWrapper {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String value;

    /**
     * @description Constructor for Record Wrapper
     *
     * @param  label label of the Record field.
     * @param  value API Name of the Record field.
     */
    public FieldWrapper(String label, String value) {
      this.label = label;
      this.value = value;
    }
  }
  /**
   * @description Custom wrapper for field lists
   */
  public class FieldListWrapper {
    @AuraEnabled
    public List<FieldWrapper> searchFields;
    @AuraEnabled
    public List<FieldWrapper> updateFields;

    /**
     * @description Constructor for Record Wrapper
     *
     * @param  searchFields Records with API Name of the fields will be used to search for duplicates.
     * @param  updateFields Records with API Name of the fields will be used to update data from duplicates.
     */
    public FieldListWrapper(
      List<FieldWrapper> searchFields,
      List<FieldWrapper> updateFields
    ) {
      this.searchFields = searchFields;
      this.updateFields = updateFields;
    }
  }
}
