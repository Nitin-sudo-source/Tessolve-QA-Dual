@IsTest
private class NS_AccountAPI_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            Name = 'Test Account',
            BillingStreet = '123 Main Street Bangalore',
            BillingCity = 'Bangalore',
            BillingState = 'KA',
            BillingCountry = 'India',
            NS_Manual_Pull__c = true,
            BU__c='Pre-Silicon'
        );
        insert acc;
        
        Account acc1 = new Account(
            Name = 'Test Account 11111',
            BillingStreet = '',
            BillingCity = '',
            BillingState = '',
            BillingCountry = '',
            NS_Manual_Pull__c = true,
            BU__c='Pre-Silicon'
        );
        insert acc1;
        
        Contact con = new Contact(
            firstName = 'Test',
            lastName = 'Contact'
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prequalified',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Amount = 10000,
            Application__c = 'Cluster Design',
            //Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India'
        );
        insert opp;
        
        OpportunityContactRole oppRole = new OpportunityContactRole(
            OpportunityId = opp.id,
            IsPrimary = true,
            ContactId = con.id
        );
        insert oppRole;
        
    }
    
    @isTest
    static void testAccountWrapper() {
        
        Account acc = [SELECT Id, Name, BillingStreet, Netsuite_ID__c, BillingCity, BillingState, BillingCountry, Primary_Subsidiary__c, Account_Group__c, Account_Status__c 
                       FROM Account LIMIT 1];
        
        Opportunity opp = [SELECT Id, CurrencyIsoCode,
                           (SELECT Contact.Name FROM OpportunityContactRoles)
                           FROM Opportunity LIMIT 1];
        
        Test.startTest();
        NS_AccountAPI.AccountWrapper wrapper = 
            new NS_AccountAPI.AccountWrapper(acc, opp);
        Test.stopTest();
        
    }


    @IsTest
    static void testDailyMode() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/accounts';
        req.httpMethod = 'GET';
        /*req.addParameter('lastSync',
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

        List<NS_AccountAPI.AccountWrapper> result =
            NS_AccountAPI.getAccounts();

        //System.assert(result.size() > 0);
    }

    @IsTest
    static void testManualMode() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/accounts';
        req.httpMethod = 'GET';
        req.addParameter('manual', 'true');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        List<NS_AccountAPI.AccountWrapper> result =
            NS_AccountAPI.getAccounts();

       // System.assert(result.size() > 0);
    }

    @IsTest
    static void testRecordIdMode() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/accounts';
        req.httpMethod = 'GET';
        req.addParameter('recordId', acc.Id);

        RestContext.request = req;
        RestContext.response = new RestResponse();

        List<NS_AccountAPI.AccountWrapper> result =
            NS_AccountAPI.getAccounts();

        ///System.assertEquals(1, result.size());
    }
    
    @IsTest
    static void testAccount_InvalidLastSync(){
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/accounts';
        req.httpMethod = 'GET';
        //req.addParameter('lastSync','INVALID_DATE');
        req.addParameter('fromDate','INVALID_DATE');
        req.addParameter('toDate','INVALID_DATE');
    
        RestContext.request = req;
        RestContext.response = new RestResponse();
    
        List<NS_AccountAPI.AccountWrapper> result =
            NS_AccountAPI.getAccounts();
    
        System.assertEquals(400, RestContext.response.statusCode);
    }
    
    @IsTest
    static void testAccount_CatchBlock(){
    
        NS_AccountAPI.TEST_FORCE_EXCEPTION = true;
    
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/accounts';
        req.httpMethod = 'GET';
    
        RestContext.request = req;
        RestContext.response = new RestResponse();
    
        NS_AccountAPI.getAccounts();
    
        System.assertEquals(500, RestContext.response.statusCode);
    
        NS_AccountAPI.TEST_FORCE_EXCEPTION = false;
    }
}