@isTest
public class RecordSyncRunControllerTest {

    @isTest
    static void getRecordFields(){
        List<String> recordFields = new List<String>();
		RecordSyncRunController.FieldListWrapper fieldListWrapper = RecordSyncRunController.getRecordFields();
		List<RecordSyncRunController.FieldWrapper> fieldsWrapper = fieldListWrapper.searchFields;
		for(RecordSyncRunController.FieldWrapper fieldWrapper: fieldsWrapper ){
		    recordFields.add(fieldWrapper.value);
		}
        
		Boolean name = recordFields.contains('Name');
		System.assertEquals(true, name);
        
        Boolean parentId = recordFields.contains('ParentId');
        System.assertEquals(false,parentId);
        
    }
	
    @isTest
        static void createSyncRun(){
 		String searchFields = 'name,BillingCity' ;
        String updateFields = 'name' ;
        Date fromDate = Date.newInstance(2022,1,1) ;
        Integer minimumScore = 1;
        Test.startTest();
        	String runId = RecordSyncRunController.createSyncRun(searchFields,updateFields,fromDate,minimumScore);
        	Id recordSyncRunId = [SELECT id FROM Record_Sync_Run__c LIMIT 1].id;
        Test.stopTest();
		System.assertEquals(String.valueOf(recordSyncRunId), runId);
    }
    
    @isTest
    static void updateDuplicatesAction(){
        FunctionsInvokeMockInner mock = new FunctionsInvokeMockInner();
    	Test.setMock(functions.FunctionInvokeMock.class, mock);
        
        List<Record_Sync_Run__c> listRecordSyncRun = new List<Record_Sync_Run__c>();
        String searchFields = 'name,BillingCity' ;
        String updateFields = 'name' ;
        Date fromDate = Date.newInstance(2022,1,1) ;
        Integer minimumScore = 1;
        
        Record_Sync_Run__c recordSyncRun = new Record_Sync_Run__c(
        Search_Fields__c = searchFields,
        Update_Fields__c = updateFields,
        From__c = fromDate,
        Minimum_Score__c = minimumScore,
        Status__c = 'Search In Progress');
        
        listRecordSyncRun.add(recordSyncRun);
        insert recordSyncRun;

        Test.startTest();

        Id recordSyncRunId = [SELECT id FROM Record_Sync_Run__c LIMIT 1].id;
        
            Record_Sync__c recordSync = new Record_Sync__c(
            Target_Record__c= '0016300001LHlsPAAT', 
            Source_Record__c= '0016300001LKwJLAA1', 
            Status__c='Pending',
            Record_Sync_Run__c = recordSyncRunId
        );
        insert recordSync;
        List<String> result = RecordSyncRunController.updateDuplicatesAction(listRecordSyncRun);
        List<AsyncApexJob> batch = [SELECT id FROM AsyncApexJob WHERE Id=:result.get(0)];
		Test.stopTest();
		System.assertEquals(1,batch.size()); 
    }
    
    public class FunctionsInvokeMockInner implements functions.FunctionInvokeMock {
    public String response = 'Success!';
    public String error = 'Function returned an error!';
    public Boolean throwError = false;
    private String invocationId = '000000000000000';

    public functions.FunctionInvocation respond(
      String functionName,
      String payload
    ) {
      if (throwError) {
        return functions.MockFunctionInvocationFactory.createErrorResponse(
          invocationId,
          functions.FunctionErrorType.FUNCTION_EXCEPTION,
          error
        );
      }

      return functions.MockFunctionInvocationFactory.createSuccessResponse(
        invocationId,
        response
      );
    }
  }
}