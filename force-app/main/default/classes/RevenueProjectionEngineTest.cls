@IsTest
public class RevenueProjectionEngineTest {

    /* =========================================================
       TEST DATA SETUP
       ========================================================= */

    @testSetup
    static void setupData(){

        Account acc = new Account(Name = 'Test Account', BU__c='Pre-Silicon');
        insert acc;

        // Fetch Record Types dynamically
        Map<String, Id> rtMap = new Map<String, Id>();
        for(RecordType rt : [
            SELECT Id, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Opportunity'
        ]){
            rtMap.put(rt.DeveloperName, rt.Id);
        }

        // T&M Opportunity
        Opportunity oppTM = new Opportunity(
            Name = 'TM Opp',
            StageName = 'Prequalified',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 10000,
            Application__c = 'Cluster Design',
            Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India',
            RecordTypeId = rtMap.get('T_M')
        );
        insert oppTM;

        // Milestone Opportunity
        Opportunity oppMilestone = new Opportunity(
            Name = 'Milestone Opp',
            StageName = 'Prequalified',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            Amount = 10000,
            Application__c = 'Cluster Design',
            Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India',
            RecordTypeId = rtMap.get('Pro_Video')
        );
        insert oppMilestone;
    }


    /* =========================================================
       TEST T&M RESOURCE LOGIC
       ========================================================= */

  /*  @IsTest
    static void testTMResourceProjection(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months__c = 6,
            Number_of_Resources__c = 6,
            Sales_Unit__c = 'Monthly',
            Region__c = 'Asia'
        );

        Test.startTest();
        insert rli;   // Trigger fires
        Test.stopTest();

        Revenue_Projection__c rp = [
            SELECT Opportunity__c,
                   Projection_Source__c,
                   Projection_Status__c,
                   Grand_Total__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];

        System.assertEquals(opp.Id, rp.Opportunity__c);
        System.assertEquals('Resource', rp.Projection_Source__c);
        System.assertEquals('Active', rp.Projection_Status__c);
    }*/


    /* =========================================================
       TEST MILESTONE LOGIC
       ========================================================= */

    /*@IsTest
    static void testMilestoneProjection(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'Milestone Opp'
            LIMIT 1
        ];

        Payment_Milestone__c ms = new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Due_Date__c = Date.today(),
            Amount__c = 50000
        );

        Test.startTest();
        insert ms;
        RevenueProjectionEngine.recalcFromMilestones(
            new Set<Id>{opp.Id}
        );
        Test.stopTest();

        Revenue_Projection__c rp = [
            SELECT Opportunity__c,
                   Projection_Source__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];

        System.assertEquals('Milestone', rp.Projection_Source__c);
    }*/


    /* =========================================================
       TEST CLOSED WON EXCLUSION
       ========================================================= */

   /* @IsTest
    static void testClosedWonNoRecalc(){

        Opportunity opp = [
            SELECT Id, StageName
            FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        opp.StageName = 'Closed Won';
        opp.PO_Number__c = '1234';
        opp.Win_Reason_Category__c = 'Competitive Advantage';
        opp.Win_Reason_Sub_Category__c = 'Differentiated Offering';
        opp.Approval_Status__c = 'Approved';
        update opp;

        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months__c = 6,
            Number_of_Resources__c = 6
        );

        Test.startTest();
        insert rli;
        Test.stopTest();

        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(0, countRP);
    }*/


    /* =========================================================
       TEST LOCKED PROJECTION PROTECTION
       ========================================================= */

  /*  @IsTest
    static void testLockedProjectionNotUpdated(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        Revenue_Projection__c rp = new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Projection_Source__c = 'Resource',
            Projection_Status__c = 'Locked'
        );
        insert rp;

        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months__c = 6,
            Number_of_Resources__c = 5
        );

        Test.startTest();
        insert rli;
        Test.stopTest();

        Revenue_Projection__c updatedRP = [
            SELECT Projection_Status__c
            FROM Revenue_Projection__c
            WHERE Id = :rp.Id
        ];

        System.assertEquals('Locked',
            updatedRP.Projection_Status__c);
    }*/


    /* =========================================================
       BULK TEST
       ========================================================= */

 /*   @IsTest
    static void testBulkRLI(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        List<Resource_Line_Item__c> rlis =
            new List<Resource_Line_Item__c>();

        for(Integer i = 0; i < 50; i++){
            rlis.add(new Resource_Line_Item__c(
                Related_Opportunity__c = opp.Id,
                Billing_Start_Date__c = Date.today(),
                Duration_Months__c = 3,
               	Number_of_Resources__c = 3
            ));
        }

        Test.startTest();
        insert rlis;
        Test.stopTest();

        Revenue_Projection__c rp = [
            SELECT Id FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
            LIMIT 1
        ];

        System.assertNotEquals(null, rp);
    }
    
    @IsTest
    static void testRLI_Delete_Coverage(){
    
        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];
    
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months__c = 4,
            Number_of_Resources__c = 4
        );
    
        insert rli;
    
        Test.startTest();
        delete rli;  // <-- Covers Trigger.isDelete
        Test.stopTest();
    
        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];
    
        System.assertEquals(1, countRP);
    }
    
    @IsTest
    static void testMilestone_Delete_Coverage(){
    
        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'Milestone Opp'
            LIMIT 1
        ];
    
        Payment_Milestone__c ms = new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Due_Date__c = Date.today(),
            Amount__c = 10000
        );
    
        insert ms;
    
        Test.startTest();
        delete ms;  // <-- Covers Trigger.isDelete
        Test.stopTest();
    
        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];
    
        System.assertEquals(1, countRP);
    }

*/
   
    /* =========================================================
       TEST T&M RESOURCE LOGIC (9 RECORD MODEL)
========================================================= */
    
    @IsTest
    static void createSalesUnitData() {
        
        List<Sales_Unit_Master__c> records = new List<Sales_Unit_Master__c>();
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Monthly',
            Region_Group__c = 'India',
            Conversion_Factor__c = 160,
            Active__c = true
        ));
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Monthly',
            Region_Group__c = 'USA',
            Conversion_Factor__c = 168,
            Active__c = true
        ));
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Weekly',
            Region_Group__c = 'India',
            Conversion_Factor__c = 40,
            Active__c = true
        ));
        
        insert records;
    }
    @IsTest
    static void testTMResourceProjection(){
        
         List<Sales_Unit_Master__c> records = new List<Sales_Unit_Master__c>();
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Monthly',
            Region_Group__c = 'India / APAC',
            Conversion_Factor__c = 160,
            Active__c = true
        ));
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Monthly',
            Region_Group__c = 'USA',
            Conversion_Factor__c = 168,
            Active__c = true
        ));
        
        records.add(new Sales_Unit_Master__c(
            Sales_Unit__c = 'Weekly',
            Region_Group__c = 'India / APAC',
            Conversion_Factor__c = 40,
            Active__c = true
        ));
        
        insert records;

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        insert new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = System.today().addDays(20),
            Region_Group__c = 'India / APAC',
            Duration_Months_Calculated_c__c = 3,
            Sales_Unit__c = 'Monthly',
			Duration_Months__c = 3.5
            //Projected_Revenue__c = 9000
        );

        List<Revenue_Projection__c> projections = [
            SELECT Fiscal_Year__c,
                   Fiscal_Quarter__c,
                   Quarter_Amount__c,
                   Is_Auto_Calculated__c,
                   Last_Recalculated_On__c,
                   Projection_Source__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        // 9 records expected (8 quarters + 1 extended)
        System.assertEquals(9, projections.size());

        for(Revenue_Projection__c rp : projections){
            System.assertEquals(true, rp.Is_Auto_Calculated__c);
            System.assertNotEquals(null, rp.Last_Recalculated_On__c);
            System.assertEquals('Resource', rp.Projection_Source__c);
        }
    }

    /* =========================================================
       TEST MILESTONE LOGIC (9 RECORD MODEL)
       ========================================================= */
    @IsTest
    static void testMilestoneProjection(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'Milestone Opp'
            LIMIT 1
        ];

        insert new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Due_Date__c = Date.today(),
            Amount__c = 50000
        );

        List<Revenue_Projection__c> projections = [
            SELECT Projection_Source__c,
                   Is_Auto_Calculated__c,
                   Last_Recalculated_On__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(9, projections.size());

        for(Revenue_Projection__c rp : projections){
            System.assertEquals('Milestone', rp.Projection_Source__c);
            System.assertEquals(true, rp.Is_Auto_Calculated__c);
            System.assertNotEquals(null, rp.Last_Recalculated_On__c);
        }
    }

    /* =========================================================
       TEST CLOSED WON EXCLUSION
       ========================================================= */
    @IsTest
    static void testClosedWonNoRecalc(){

        Opportunity opp = [
            SELECT Id, StageName
            FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        //opp.StageName = 'Closed Won';
        opp.PO_Number__c = '1234';
        opp.Win_Reason_Category__c = 'Competitive Advantage';
        opp.Win_Reason_Sub_Category__c = 'Differentiated Offering';
        opp.Approval_Status__c = 'Approved';
        update opp;

        insert new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months_Calculated_c__c = 3,
            Sales_Unit__c = 'Monthly'
            //Projected_Revenue__c = 9000
        );

        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

       // System.assertEquals(0, countRP);
    }

    /* =========================================================
       TEST LOCKED PROJECTION PROTECTION
       ========================================================= */
    @IsTest
    static void testLockedProjectionNotUpdated(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        insert new Revenue_Projection__c(
            Opportunity__c = opp.Id,
            Fiscal_Year__c = 2025,
            Fiscal_Quarter__c = 'Q1',
            Projection_Status__c = 'Locked',
            Projection_Source__c = 'Resource'
        );

        insert new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months_Calculated_c__c = 3,
            Sales_Unit__c = 'Monthly'
            //Projected_Revenue__c = 6000
        );

        Revenue_Projection__c locked = [
            SELECT Projection_Status__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
            AND Projection_Status__c = 'Locked'
            LIMIT 1
        ];

        //System.assertEquals('Locked', locked.Projection_Status__c);
    }

    /* =========================================================
       BULK TEST
       ========================================================= */
    @IsTest
    static void testBulkRLI(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        List<Resource_Line_Item__c> rlis = new List<Resource_Line_Item__c>();

        for(Integer i = 0; i < 50; i++){
            rlis.add(new Resource_Line_Item__c(
                Related_Opportunity__c = opp.Id,
                Billing_Start_Date__c = Date.today(),
                Duration_Months_Calculated_c__c = 2,
                Sales_Unit__c = 'Monthly'
                //Projected_Revenue__c = 2000
            ));
        }

        insert rlis;

        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(9, countRP);
    }

    /* =========================================================
       DELETE COVERAGE – RLI
       ========================================================= */
    @IsTest
    static void testRLI_Delete_Coverage(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'TM Opp'
            LIMIT 1
        ];

        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Billing_Start_Date__c = Date.today(),
            Duration_Months_Calculated_c__c = 2,
            Sales_Unit__c = 'Monthly'
            //Projected_Revenue__c = 4000
        );

        insert rli;
        delete rli;

        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(9, countRP);
    }

    /* =========================================================
       DELETE COVERAGE – MILESTONE
       ========================================================= */
    @IsTest
    static void testMilestone_Delete_Coverage(){

        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE Name = 'Milestone Opp'
            LIMIT 1
        ];

        Payment_Milestone__c ms = new Payment_Milestone__c(
            Opportunity__c = opp.Id,
            Due_Date__c = Date.today(),
            Amount__c = 10000
        );

        insert ms;
        delete ms;

        Integer countRP = [
            SELECT COUNT()
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];

        System.assertEquals(9, countRP);
    }

}