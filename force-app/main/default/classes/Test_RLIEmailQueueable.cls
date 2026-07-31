@IsTest
public class Test_RLIEmailQueueable {
    @IsTest
    static void testRLI_RateModified_EmailFlow() {
        
        // =========================
        // SETUP DATA
        // =========================
        Account acc = new Account(Name = 'Test Acc');
        insert acc;
        
        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            Email = 'test@example.com'
        );
        insert con;
        
       List<Opportunity> opps = new List<Opportunity>();
        
        for(Integer i = 0; i < 2; i++){
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prequalified',
                RecordTypeId =  Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('T_M').getRecordTypeId(),
                CloseDate = Date.today().addDays(30),
                Amount = 50000,
                Application__c = 'Automotive Software',
                //Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                LeadSource = 'Presales',
                Execution_Location__c = 'India'
                
                
            ));
        }
        
        insert opps;
        System.debug('opps: '+opps);
        
       
        // ✅ Create RLI where rate is modified
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opps[0].Id,
            Selling_Rate__c = 100,          // original
            Sales_Selling_Rate__c = 80,     // modified (lower)
            CurrencyIsoCode = 'INR',
            Number_of_Resources__c = 2,
            Duration_Months__c = 6,
            Sales_Unit__c = 'Monthly',
            Region__c = 'India',
            Status__c = 'Resource Shortlisted',
            Is_Email_Send__c = false,
            MSA_Customer__c = false // ✅ Non-MSA
        );
        
         Resource_Line_Item__c rli2 = new Resource_Line_Item__c(
            Related_Opportunity__c = opps[0].Id,
            Selling_Rate__c = 100,          // original
            Sales_Selling_Rate__c = 80,  
            Billing_Start_Date__c = System.today(),// modified (lower)
            CurrencyIsoCode = 'INR',
            Number_of_Resources__c = 2,
            Duration_Months__c = 6,
            Sales_Unit__c = 'Monthly',
            Region__c = 'India',
            Status__c = 'Resource Shortlisted',
            Is_Email_Send__c = false,
            MSA_Customer__c = true
        );
         insert rli2;
        insert rli;
        
        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = opps[0].Id,
            ContactId = con.Id,
            Role = 'Decision Maker',   // or any valid role
            IsPrimary = true
        );
        
        insert ocr;
        opps[0].StageName = 'Qualified';
        update opps[0];
        

        
        // =========================
        // EXECUTE QUEUEABLE
        // =========================
        Test.startTest();
        System.enqueueJob(new RLIEmailQueueable(new Set<Id>{ opps[0].Id} , false));
        Test.stopTest();
        
        // =========================
        // ASSERT
        // =========================
        Resource_Line_Item__c updatedRLI = [
            SELECT Is_Email_Send__c, Email_Sent_Date__c
            FROM Resource_Line_Item__c
            WHERE Id = :rli.Id
        ];
        
        System.assertEquals(true, updatedRLI.Is_Email_Send__c,
                            'RLI should be marked as email sent when rate is modified');
        
        System.assertNotEquals(null, updatedRLI.Email_Sent_Date__c,
                               'Email sent date should be populated');
    }
}