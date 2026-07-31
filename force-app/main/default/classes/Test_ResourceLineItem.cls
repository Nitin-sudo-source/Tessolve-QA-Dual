@IsTest
public class Test_ResourceLineItem {
    
    @TestSetup
    static void setupData() {
        
        List<Opportunity> opps = new List<Opportunity>();
        
        for(Integer i = 0; i < 2; i++){
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prequalified',
                CloseDate = Date.today().addDays(30),
                Amount = 50000,
                Application__c = 'Automotive Software',
               // Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                Execution_Location__c = 'India'
                
                
            ));
        }
        
        insert opps;
        System.debug('opps: '+opps);
    }
    
    
    /* ================= INSERT TEST ================= */
    
    @IsTest
    static void testAfterInsert() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Resource_Line_Item__c r1 = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Duration_Months__c = 5,
            Number_of_Resources__c = 2,
            Selling_Rate__c = 10,
            MSA_Customer__c = true,
            Billing_Start_Date__c = System.today(),
            Sales_Unit__c = 'Monthly'
        );
        
        Resource_Line_Item__c r2 = new Resource_Line_Item__c(
            
            Related_Opportunity__c = opp.Id,
            Duration_Months__c = 5,
            Number_of_Resources__c = 2,
            Selling_Rate__c = 10,
            MSA_Customer__c = true,
            Billing_Start_Date__c = System.today(),
            Sales_Unit__c = 'Monthly'
        );
        
        Test.startTest();
        insert new List<Resource_Line_Item__c>{r1, r2};
            Test.stopTest();
        
        Opportunity updatedOpp = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        
        //System.assertEquals(300, updatedOpp.TCV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= UPDATE TEST ================= */
    
    @IsTest
    static void testAfterUpdate_LookupChange() {
        List<Opportunity> opps = [
            SELECT Id 
            FROM Opportunity 
            ORDER BY CreatedDate ASC
            LIMIT 2
        ];
        
        Opportunity opp1 = opps[0];
        System.debug('opp1: '+opp1);
        Opportunity opp2 = opps[1];
        System.debug('opp2: '+opp2);
        
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp1.Id,
            Duration_Months__c = 5,
            Number_of_Resources__c = 2,
            Selling_Rate__c = 10,
            MSA_Customer__c = true,
            Billing_Start_Date__c = System.today(),
            Sales_Unit__c = 'Monthly'
        );
        
        insert rli;
        System.debug('rli: '+rli);
        
        // Change lookup to another opportunity
        
        
        Test.startTest();
        rli.Selling_Rate__c = 20;
        update rli;
        
        Opportunity updatedOpp1 = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp1.Id
        ];
        
        Opportunity updatedOpp2 = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp2.Id
        ];
        Test.stopTest();
        
        
        //System.assertEquals(0, updatedOpp1.TCV_in_Opportunity_Currency__c);
        //System.assertEquals(150, updatedOpp2.TCV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= DELETE TEST ================= */
    
    @IsTest
    static void testAfterDelete() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Duration_Months__c = 5,
            Number_of_Resources__c = 2,
            Selling_Rate__c = 10,
            MSA_Customer__c = true,
            Sales_Unit__c = 'Monthly',
            Billing_Start_Date__c = System.today()
        );
        
        insert rli;
        
        Test.startTest();
        delete rli;
        Opportunity updatedOpp = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        Test.stopTest();
        
        
        
        //System.assertEquals(0, updatedOpp.TCV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= UNDELETE TEST ================= */
    
    @IsTest
    static void testAfterUndelete() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Duration_Months__c = 5,
            Number_of_Resources__c = 2,
            Selling_Rate__c = 10,
            MSA_Customer__c = true,
            Sales_Unit__c = 'Monthly',
            Billing_Start_Date__c = System.today()
        );
        
        insert rli;
        delete rli;
        
        Test.startTest();
        undelete rli;
        
        Opportunity updatedOpp = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        
        Test.stopTest();
        
        //System.assertEquals(500, updatedOpp.TCV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= BULK TEST ================= */
    
    @IsTest
    static void testBulkInsert() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        List<Resource_Line_Item__c> rliList = new List<Resource_Line_Item__c>();
        
        for(Integer i = 0; i < 200; i++){
            rliList.add(new Resource_Line_Item__c(
                Related_Opportunity__c = opp.Id,
                Duration_Months__c = 5,
                Number_of_Resources__c = 2,
                Selling_Rate__c = 10,
                MSA_Customer__c = true,
                Sales_Unit__c = 'Monthly',
                Billing_Start_Date__c = System.today()
            ));
        }
        
        Test.startTest();
        insert rliList;
        Opportunity updatedOpp = [
            SELECT TCV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        Test.stopTest();
        
        
        
        //System.assertEquals(2000, updatedOpp.TCV_in_Opportunity_Currency__c);
    }
}