@isTest
public class RevenueProjectionExportControllerTest {
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
            // Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
             CurrencyISOCOde = 'USD',
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
            CurrencyISOCOde = 'USD',
            Amount = 10000,
            Application__c = 'Cluster Design',
            // Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India',
            RecordTypeId = rtMap.get('T_M'),
            TCV_in_Opportunity_Currency__c = 1000,
            ACV_in_Opportunity_Currency__c = 500,
            Expected_Close_Date__c = Date.today().addDays(25)
        );
        insert oppMilestone;
    }
    
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
        
        System.debug('opp.Id: '+opp.Id);
        
        List<Revenue_Projection__c> projections = [
            SELECT Fiscal_Year__c,
            Fiscal_Quarter__c,
            FY_Type__c,
            Quarter_Amount__c,
            Is_Auto_Calculated__c,
            Last_Recalculated_On__c,
            Projection_Source__c
            FROM Revenue_Projection__c
            WHERE Opportunity__c = :opp.Id
        ];
        RevenueProjectionExportQueueable.ExportWrapper wrapper = new RevenueProjectionExportQueueable.ExportWrapper();
        
        
        Integer currentFY = (Date.today().month() >= 4)
            ? Date.today().year()
            : Date.today().year() - 1;
        
        // Current FY - Q1
        projections[0].Fiscal_Year__c = currentFY;
        projections[0].Fiscal_Quarter__c = 'Q1';
        projections[0].Is_Extended__c = false;
        projections[0].Quarter_Amount__c = 100;
        
        // Next FY - Q2
        if (projections.size() > 1) {
            projections[1].Fiscal_Year__c = currentFY + 1;
            projections[1].Fiscal_Quarter__c = 'Q2';
            projections[1].Is_Extended__c = false;
            projections[1].Quarter_Amount__c = 200;
        }
        
        // Extended
        if (projections.size() > 2) {
            projections[2].Fiscal_Year__c = currentFY + 2;
            projections[2].Fiscal_Quarter__c = 'Extended';
            projections[2].Is_Extended__c = true;
            projections[2].Quarter_Amount__c = 300;
        }
		System.debug('Size: '+ projections.size());
        
        for (Revenue_Projection__c rp : projections) {
            System.debug('rp: '+rp);
            
            if (rp.FY_Type__c == 'Current FY') {
                switch on rp.Fiscal_Quarter__c {
                    when 'Q1' { wrapper.q1 = rp.Quarter_Amount__c; }
                    when 'Q2' { wrapper.q2 = rp.Quarter_Amount__c; }
                    when 'Q3' { wrapper.q3 = rp.Quarter_Amount__c; }
                    when 'Q4' { wrapper.q4 = rp.Quarter_Amount__c; }
                }
            }
            else if (rp.FY_Type__c == 'Next FY') {
                switch on rp.Fiscal_Quarter__c {
                    when 'Q1' { wrapper.q1 = rp.Quarter_Amount__c; }
                    when 'Q2' { wrapper.q2 = rp.Quarter_Amount__c; }
                    when 'Q3' { wrapper.q3 = rp.Quarter_Amount__c; }
                    when 'Q4' { wrapper.q4 = rp.Quarter_Amount__c; }
                }
            }
            else if (rp.FY_Type__c == 'Extended') {
                wrapper.extended = rp.Quarter_Amount__c;
            }
        }
        
        if (!projections.isEmpty()) {
            update projections;
        }
        
        Test.startTest();
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result =
            RevenueProjectionPreviewController.getPreview(
                opp.Id,
                false
            );
        
        Test.stopTest();
        
        
    }


    
    @isTest
    static void testGetPreviewDataSingleOpportunity() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        Test.startTest();
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result =
            RevenueProjectionExportController.getPreviewData(
                opp.Id,
                false
            );
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result1 =
            RevenueProjectionPreviewController.getPreview(
                opp.Id,
                false
            );
        
        Test.stopTest();
        
        System.assert(!result.isEmpty());
        System.assertEquals(1, result.size());
    }
    
    @isTest
    static void testGetPreviewDataExportAll() {
        
        Test.startTest();
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result =
            RevenueProjectionExportController.getPreviewData(
                null,
                true
            );
        
        Test.stopTest();
        
        System.assert(result.size() > 0);
    }
    
    @isTest
    static void testStartExportSingle() {
        
        Opportunity opp = [
            SELECT Id
            FROM Opportunity
            LIMIT 1
        ];
        
        Test.startTest();
        
        RevenueProjectionExportController.ExportResponse response =
            RevenueProjectionExportController.startExport(
                opp.Id,
                false
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, response);
        System.assertNotEquals(null, response.jobId);
        System.assertEquals(
            'Export started successfully.',
            response.message
        );
    }
    
    @isTest
    static void testStartExportAll() {
        
        Test.startTest();
        
        RevenueProjectionExportController.ExportResponse response =
            RevenueProjectionExportController.startExport(
                null,
                true
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, response.jobId);
        System.assertEquals(
            'Export of all Revenue Projections started successfully.',
            response.message
        );
    }
    
    @isTest
    static void testStartExportNullBoolean() {
        
        Test.startTest();
        
        RevenueProjectionExportController.ExportResponse response =
            RevenueProjectionExportController.startExport(
                null,
                null
            );
        
        Test.stopTest();
        
        System.assertNotEquals(null, response.jobId);
        System.assertEquals(
            'Export of all Revenue Projections started successfully.',
            response.message
        );
    }
    
    @isTest
    static void testGetJobStatus() {
        
        Test.startTest();
        
        RevenueProjectionExportController.ExportResponse response =
            RevenueProjectionExportController.startExport(
                null,
                true
            );
        
        Test.stopTest();
        
        AsyncApexJob job =
            RevenueProjectionExportController.getJobStatus(
                response.jobId
            );
        
        System.assertEquals(response.jobId, job.Id);
        System.assertEquals('Completed', job.Status);
    }
    
    @isTest
    static void testGetLatestExportFile() {
        
        Test.startTest();
        
        RevenueProjectionExportController.startExport(
            null,
            true
        );
        
        Test.stopTest();
        
        ContentVersion cv =
            RevenueProjectionExportController.getLatestExportFile();
        
        System.assertNotEquals(null, cv);
        System.assert(
            cv.Title.startsWith('RevenueProjectionExport_')
        );
    }
    
    @isTest
    static void testPreviewExportAll() {
        
        Test.startTest();
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result =
            RevenueProjectionPreviewController.getPreview(
                null,
                true
            );
        
        Test.stopTest();
        
        System.assert(result.size() >= 2);
    }
    
    @isTest
    static void testPreviewNullExportAll() {
        
        Test.startTest();
        
        List<RevenueProjectionExportQueueable.ExportWrapper> result =
            RevenueProjectionPreviewController.getPreview(
                null,
                null
            );
        
        Test.stopTest();
        
        System.assert(result.size() > 0);
    }
}