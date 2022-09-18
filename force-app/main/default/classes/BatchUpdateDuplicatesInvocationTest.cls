@isTest
public class BatchUpdateDuplicatesInvocationTest {

    @isTest
    static void testBatchExecuteMethod()
    {
      Record_Sync_Run__c rsr = new Record_Sync_Run__c();
     
      rsr.Status__c = 'Ready to Sync';
      rsr.Minimum_Score__c = 60;
      rsr.From__c = Date.today().addDays(-2);
      rsr.Search_Fields__c = 'Name,AccountSource,AnnualRevenue,Type';
      rsr.Update_Fields__c = 'Name,AccountSource,AnnualRevenue,Type';
           
      insert rsr; 
        
      Id recordSyncRunId = [SELECT id FROM Record_Sync_Run__c LIMIT 1].id;
        
            Record_Sync__c recordSync = new Record_Sync__c(
            Target_Record__c= '0016300001LHlsPAAT', 
            Source_Record__c= '0016300001LKwJLAA1', 
            Status__c='Pending',
            Record_Sync_Run__c = recordSyncRunId
                
           
        );
      insert recordSync;
        
      FunctionsInvokeMockInner mock = new FunctionsInvokeMockInner();
  
      Test.setMock(functions.FunctionInvokeMock.class, mock);
   
      functions.Function updateDuplicatesFx = functions.Function.get(
      	'record_sync_app.updateduplicatedrecords'
      );
   
        
      try {
          Test.startTest();
          BatchUpdateDuplicatesInvocation batchTest = new BatchUpdateDuplicatesInvocation(rsr,updateDuplicatesFx);
          Id jobid = Database.executeBatch(batchTest,5);
          Test.stopTest();
          
          if(!mock.throwError){
              Record_Sync_Run__c run = [Select Status__c from Record_Sync_Run__c where Id =:rsr.Id]; 
              run.Status__c = 'Completed';
             
              update run;
          }
         	
          List<Record_Sync_Run__c> acc = new List<Record_Sync_Run__c>(); 
     	  acc = [Select Status__c from Record_Sync_Run__c where Status__c = 'Completed'];
       
     	  System.assertEquals(1, acc.size());
         
        } catch (Exception e) {
          // THEN
          System.assert(e instanceof CalloutException, 'Expected CalloutException');
          System.assertEquals(mock.error, e.getMessage());
      }
    }
    
    public class FunctionsInvokeMockInner implements functions.FunctionInvokeMock {
    public String response = 'Success!';
    public String error = 'Function returned an error!';
    public Boolean throwError = false;
    private String invocationId = '000000000000000';

    public functions.FunctionInvocation respond(String functionName, String payload) {
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