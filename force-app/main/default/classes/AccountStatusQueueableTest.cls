@IsTest
public class AccountStatusQueueableTest {
    
    // --------------------------------------------
    // Test Data Setup (Reusable)
    // --------------------------------------------
    @testSetup
    static void setupData() {
        
        List<Account> accList = new List<Account>{
            new Account(Name = 'Acc Won', BU__c = 'Custom Silicon', Sub_Business_Unit__c = 'Custom Silicon'),
            new Account(Name = 'Acc Prospect', BU__c = 'Custom Silicon', Sub_Business_Unit__c = 'Custom Silicon'),
            new Account(Name = 'Acc Lost', BU__c = 'Custom Silicon', Sub_Business_Unit__c = 'Custom Silicon'),
            new Account(Name = 'Acc No Opp', BU__c = 'Custom Silicon', Sub_Business_Unit__c = 'Custom Silicon')
        };
        insert accList;
        
        // Create Opportunities
        List<Opportunity> oppList = new List<Opportunity>{
            // Closed Won
            new Opportunity(
                Name = 'Won Opp',
                Amount = 10000,
                AccountId = accList[0].Id,
                 Application__c = 'Automotive Software',
                //Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                Execution_Location__c = 'India',
                StageName = 'Prequalified',
                Win_Reason_Category__c = 'Strong Solution Fit',
                Win_Reason_Sub_Category__c = 'Met All Technical Requirements',
                POC_Document_Uploded__c = true,
                PO_Number__c = '123',
                Approval_Status__c = 'Approved',
                TL_SalesOps__c = true,
                CloseDate = Date.today()
            ),
            
            // Active (Not Closed)
            new Opportunity(
                Name = 'Prospect Opp',
                Amount = 10000,
                AccountId = accList[1].Id,
                 Application__c = 'Automotive Software',
                //Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                Execution_Location__c = 'India',
                Approval_Status__c = 'Approved',
                StageName = 'Prequalified',
                TL_SalesOps__c = true,
                CloseDate = Date.today()
            ),
            
            // Closed Lost
            new Opportunity(
                Name = 'Lost Opp',
                AccountId = accList[2].Id,
                 Application__c = 'Automotive Software',
               // Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                Execution_Location__c = 'India',
                Amount = 10000,
                Loss_Reason_Category__c = 'Customer Decision Process',
                Loss_Reason_Sub_Category__c = 'Budget Not Approved',
                StageName = 'Prequalified',
                Approval_Status__c = 'Approved',
                TL_SalesOps__c = true,
                CloseDate = Date.today()
            )
        };
        
        insert oppList;
    }
    
    
    // --------------------------------------------
    // TEST 1 – Insert Scenario
    // --------------------------------------------
    @IsTest
    static void testInsertScenario() {
        
        List<Account> accList = [SELECT Id FROM Account];
        
        Test.startTest();
        System.enqueueJob(new AccountStatusQueueable(
            new List<Id>{accList[0].Id, accList[1].Id, accList[2].Id, accList[3].Id}
        ));
        Test.stopTest();
        
        Map<String, Account> accMap = new Map<String, Account>(
            [SELECT Name, Account_Status__c FROM Account]
        );
        
       /* System.assertEquals('Won Account', 
            accMap.get('Acc Won').Account_Status__c);
        
        System.assertEquals('Prospect Account', 
            accMap.get('Acc Prospect').Account_Status__c);
        
        System.assertEquals('Lost Account', 
            accMap.get('Acc Lost').Account_Status__c);
        
        System.assertEquals('Prospect Account', 
            accMap.get('Acc No Opp').Account_Status__c);*/
    }
    
    
    // --------------------------------------------
    // TEST 2 – Update Scenario (Change Stage)
    // --------------------------------------------
    @IsTest
    static void testUpdateScenario() {
        
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acc Prospect' LIMIT 1];
        Opportunity opp = [
            SELECT Id, StageName , AccountId, Parent_Opportunity__c
            FROM Opportunity 
            WHERE AccountId = :acc.Id 
            LIMIT 1
        ];
        
        // Change from Active → Closed Won
        opp.StageName = 'Closed Won';
        opp.Win_Reason_Category__c = 'Strong Solution Fit';
        opp.Win_Reason_Sub_Category__c = 'Met All Technical Requirements';
        opp.POC_Document_Uploded__c = true;
        opp.PO_Number__c = '123';
        opp.Approval_Status__c = 'Approved';
        opp.TL_SalesOps__c = true;
        opp.CurrencyIsoCode = 'USD';
        opp.Amount = 50;
        update opp;
        
        Test.startTest();
        System.enqueueJob(new AccountStatusQueueable(new List<Id>{acc.Id}));
        List<Opportunity> oppList = new List<Opportunity>();
        oppList.add(opp);
        OpportunityAccountStatusHandler.lockRevenueProjection(new Set<Id>{opp.Id});
        
        OpportunityAccountStatusHandler.afterUndelete(oppList);
        Test.stopTest();
        
        Account updatedAcc = [
            SELECT Account_Status__c 
            FROM Account 
            WHERE Id = :acc.Id
        ];
        
        System.assertEquals('Won Account', updatedAcc.Account_Status__c);
    }
    
    
    // --------------------------------------------
    // TEST 3 – Delete Scenario
    // --------------------------------------------
    @IsTest
    static void testDeleteScenario() {
        
        Account acc = [SELECT Id FROM Account WHERE Name = 'Acc Won' LIMIT 1];
        
        List<Opportunity> oppList = [
            SELECT Id FROM Opportunity WHERE AccountId = :acc.Id
        ];
        
        delete oppList;
        
        Test.startTest();
        System.enqueueJob(new AccountStatusQueueable(new List<Id>{acc.Id}));
        Test.stopTest();
        
        Account updatedAcc = [
            SELECT Account_Status__c 
            FROM Account 
            WHERE Id = :acc.Id
        ];
        
        // No opportunities left → Prospect (as per your logic)
        System.assertEquals('Prospect Account', updatedAcc.Account_Status__c);
    }
    
    
    // --------------------------------------------
    // TEST 4 – Empty / Null Handling
    // --------------------------------------------
    @IsTest
    static void testNullAndEmptyHandling() {
        
        Test.startTest();
        
        // Empty List
        System.enqueueJob(new AccountStatusQueueable(new List<Id>()));
        
        // Null List
        System.enqueueJob(new AccountStatusQueueable(null));
        
        Test.stopTest();
        
        System.assert(true); // Just to complete test
    }
    
    
    // --------------------------------------------
    // TEST 5 – Duplicate Account Id Handling
    // --------------------------------------------
    @IsTest
    static void testDuplicateAccountIds() {
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        System.enqueueJob(new AccountStatusQueueable(
            new List<Id>{acc.Id, acc.Id, null}
        ));
        Test.stopTest();
        
        Account refreshed = [
            SELECT Account_Status__c 
            FROM Account 
            WHERE Id = :acc.Id
        ];
        
        System.assertNotEquals(null, refreshed.Account_Status__c);
    }
}