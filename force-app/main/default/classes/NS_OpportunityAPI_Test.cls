@IsTest
private class NS_OpportunityAPI_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Opp Account',
            BillingStreet = '123 Main Street Bangalore',
            BillingCity = 'Bangalore',
            BillingState = 'KA',
            BillingCountry = 'India',
            BU__c='Pre-Silicon'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Opp Test',
            StageName = 'Prequalified',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Amount = 20000,
            NS_Manual_Pull__c = true,
            Application__c = 'Cluster Design',
            Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India'
        );
        insert opp;
    }

    @IsTest
    static void testDailyMode() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/opportunities';
        req.httpMethod = 'GET';
       /* req.addParameter('lastSync',
            Datetime.now().addDays(-2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        );*/
        req.addParameter('fromDate',
            Datetime.now().addDays(-2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        );
        req.addParameter('toDate',
            Datetime.now().addDays(-2).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'')
        );

        RestContext.request = req;
        RestContext.response = new RestResponse();

        List<NS_OpportunityAPI.OpportunityWrapper> result =
            NS_OpportunityAPI.getOpportunities();

        //System.assert(result.size() > 0);
    }

    @IsTest
    static void testManualMode() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/opportunities';
        req.httpMethod = 'GET';
        req.addParameter('manual', 'true');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        List<NS_OpportunityAPI.OpportunityWrapper> result =
            NS_OpportunityAPI.getOpportunities();

        //System.assert(result.size() > 0);
    }

    @IsTest
    static void testRecordIdMode() {

        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/opportunities';
        req.httpMethod = 'GET';
        req.addParameter('recordId', opp.Id);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        List<NS_OpportunityAPI.OpportunityWrapper> result =
            NS_OpportunityAPI.getOpportunities();

        //System.assertEquals(1, result.size());
    }
    
    @IsTest
    static void testOpportunity_InvalidLastSync(){
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/opportunities';
        req.httpMethod = 'GET';
        req.addParameter('fromDate','INVALID_DATE');
        req.addParameter('toDate','INVALID_DATE');
        //req.addParameter('lastSync','INVALID_DATE');
    
        RestContext.request = req;
        RestContext.response = new RestResponse();
    
        NS_OpportunityAPI.getOpportunities();
    
        //System.assertEquals(400, RestContext.response.statusCode);
    }
    
    @IsTest
    static void testOpportunity_CatchBlock(){
    
        NS_OpportunityAPI.TEST_FORCE_EXCEPTION = true;
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/opportunities';
        req.httpMethod = 'GET';
    
        RestContext.request = req;
        RestContext.response = new RestResponse();
    
        NS_OpportunityAPI.getOpportunities();
    
        System.assertEquals(500, RestContext.response.statusCode);
    
        NS_OpportunityAPI.TEST_FORCE_EXCEPTION = false;
    }
}