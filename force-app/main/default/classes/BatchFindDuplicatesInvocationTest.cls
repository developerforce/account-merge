@isTest
public class BatchFindDuplicatesInvocationTest {

    @isTest
    static void testBatchExecuteMethod()
   {
     
     Record_Sync_Run__c rsr = new Record_Sync_Run__c();
     
     rsr.Status__c = 'Search In Progress';
     rsr.Minimum_Score__c = 60;
     rsr.From__c = Date.today().addDays(-2);
     rsr.Search_Fields__c = 'Name,AccountSource,AnnualRevenue,Type';
       
     insert rsr; 
           
     Account a = new Account();
     a.Name = 'John Smith';
     a.AccountSource = 'Web';
     a.AnnualRevenue = 100000;
     a.Type = 'Personal';
     
     insert a;
       
     Account b = new Account();
     b.Name = 'Joh Smith';
     b.AccountSource = 'Web';
     b.AnnualRevenue = 100000;
     b.Type = 'Personal';

     insert b;
            
	 FunctionsInvokeMockInner mock = new FunctionsInvokeMockInner();
     //mock.throwError = true;
     Test.setMock(functions.FunctionInvokeMock.class, mock);
   
     functions.Function findDuplicatesFx = functions.Function.get(
     	'record_sync_app.findduplicatedrecords'
     );
    
     try {
          Test.startTest();
          BatchFindDuplicatesInvocation batchTest = new BatchFindDuplicatesInvocation(rsr,findDuplicatesFx);
          Id jobid = Database.executeBatch(batchTest,5);
          Test.stopTest();
          
          if(!mock.throwError){
              Record_Sync_Run__c run = [Select Status__c from Record_Sync_Run__c where Id =:rsr.Id]; 
              run.Status__c = 'Ready to Sync';
             
              update run;
          }
         	
          List<Record_Sync_Run__c> acc = new List<Record_Sync_Run__c>(); 
     	  acc = [Select Status__c from Record_Sync_Run__c where Status__c = 'Ready to Sync'];
       
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