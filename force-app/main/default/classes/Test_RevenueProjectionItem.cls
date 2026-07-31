@IsTest
public class Test_RevenueProjectionItem {
    
    
    @TestSetup
    static void setupData(){
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
    static void testInsertRollup(){
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Revenue_Projection__c rp1 = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Current_FY_Q1__c = 100,
            Current_FY_Q2__c = 200,
            Current_FY_Q3__c = 300,
            Current_FY_Q4__c = 400,
            Quarter_Amount__c = 100,
            Fiscal_Quarter__c = 'Q2',
           Fiscal_Year__c  = 2025
            
        );
        
        Revenue_Projection__c rp2 = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Current_FY_Q1__c = 50,
            Current_FY_Q2__c = 50,
            Current_FY_Q3__c = 50,
            Current_FY_Q4__c = 50,
           Quarter_Amount__c = 200,
            Fiscal_Quarter__c = 'Q1',
           Fiscal_Year__c  = 2025
        );
        
        Test.startTest();
        insert new List<Revenue_Projection__c>{rp1, rp2};
            RevenueProjectionItemRollup.rollupData(
                new Set<Id>{opp.Id}
            );
        Test.stopTest();
        
        Opportunity updatedOpp = [
            SELECT ACV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        
        // (100+200+300+400) + (50+50+50+50)
        // 1000 + 200 = 1200
       // System.assertEquals(1200, updatedOpp.ACV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= UPDATE TEST ================= */
    
    @IsTest
    static void testUpdateRollup(){
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Revenue_Projection__c rp = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Fiscal_Quarter__c = 'Q1',
           Fiscal_Year__c  = 2024
        );
        
        insert rp;
        
        Test.startTest();
        rp.Fiscal_Year__c = 2025;
        update rp;
        
        RevenueProjectionItemRollup.rollupData(
            new Set<Id>{opp.Id}
        );
        Test.stopTest();
        
    }
    
    
    /* ================= DELETE TEST ================= */
    
    @IsTest
    static void testDeleteRollup(){
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Revenue_Projection__c rp = new Revenue_Projection__c(
              Opportunity__c = opp.Id,
            Fiscal_Quarter__c = 'Q1',
           Fiscal_Year__c  = 2024
        );
        
        insert rp;
        delete rp;
        
        Test.startTest();
        RevenueProjectionItemRollup.rollupData(
            new Set<Id>{opp.Id}
        );
        Test.stopTest();
    }
    
     /* ================= UNDELETE TEST ================= */
    
    @IsTest
    static void testAfterUndelete() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Revenue_Projection__c rp = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Current_FY_Q1__c = 100,
            Current_FY_Q2__c = 100,
            Current_FY_Q3__c = 100,
            Current_FY_Q4__c = 100,
            Quarter_Amount__c = 100
        );
        
        
        insert rp;
        delete rp;
        
        Test.startTest();
        undelete rp;
        
        Opportunity updatedOpp = [
            SELECT ACV_in_Opportunity_Currency__c
            FROM Opportunity
            WHERE Id = :opp.Id
        ];
        
        Test.stopTest();
        
        //System.assertEquals(500, updatedOpp.TCV_in_Opportunity_Currency__c);
    }
    
    
    /* ================= BULK TEST ================= */
    
    @IsTest
    static void testBulkRollup(){
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        List<Revenue_Projection__c> listRP = new List<Revenue_Projection__c>();
        
        for(Integer i=0; i<200; i++){
            listRP.add(new Revenue_Projection__c(
                Opportunity__c = opp.Id,
                Current_FY_Q1__c = 10,
                Current_FY_Q2__c = 10,
                Current_FY_Q3__c = 10,
                Current_FY_Q4__c = 10,
                Quarter_Amount__c = 10
            ));
        }
        
        Test.startTest();
        insert listRP;
        RevenueProjectionItemRollup.rollupData(
            new Set<Id>{opp.Id}
        );
        Test.stopTest();
        
    }
    
}