@IsTest
private class NS_AckAPI_Test {

    @TestSetup
    static void setupData() {

        Account acc = new Account(Name='Ack Account', BU__c='Pre-Silicon');
        insert acc;

        Opportunity opp = new Opportunity(
            Name='Ack Opp',
            StageName='Prequalified',
            CloseDate=Date.today().addDays(10),
            AccountId=acc.Id,
            Amount = 20000,
            Application__c = 'Cluster Design',
            //Business_Type__c = 'Existing Account - New Group',
            Business_Unit_BU__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Estimated_Project_Start_Date__c = System.today(),
            Markets__c = 'Telecom',
            Execution_Location__c = 'India'
        );
        insert opp;
    }

    // FULL SUCCESS
    @IsTest
    static void testBulkAckSuccess() {

        Account acc = [SELECT Id, NS_Manual_Pull__c FROM Account LIMIT 1];
        Opportunity opp = [SELECT Id, NS_Manual_Pull__c FROM Opportunity LIMIT 1];

        Map<String,Object> payload = new Map<String,Object>{
            'records' => new List<Object>{
                new Map<String,Object>{
                    'recordId' => acc.Id,
                    'objectType' => 'Account',
                    'status' => 'Success'
                },
                new Map<String,Object>{
                    'recordId' => opp.Id,
                    'objectType' => 'Opportunity',
                    'status' => 'Success'
                }
            }
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assertEquals(2, res.totalProcessed);
        System.assertEquals(0, res.totalFailed);

        acc = [SELECT NS_Manual_Pull__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(false, acc.NS_Manual_Pull__c);
    }

    //  PARTIAL FAILURE
    @IsTest
    static void testPartialFailure() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Map<String,Object> payload = new Map<String,Object>{
            'records' => new List<Object>{
                new Map<String,Object>{
                    'recordId' => acc.Id,
                    'objectType' => 'Account',
                    'status' => 'Success'
                },
                new Map<String,Object>{
                    'recordId' => '001000000000000AAA', // invalid Id
                    'objectType' => 'Account',
                    'status' => 'Success'
                }
            }
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assert(res.totalFailed > 0);
    }

    //  NO RECORDS
    @IsTest
    static void testNoRecords() {

        Map<String,Object> payload = new Map<String,Object>{
            'records' => new List<Object>()
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assertEquals('No records provided', res.message);
    }

    // NULL BODY
    @IsTest
    static void testNullBody() {

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('');

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assertEquals(500, RestContext.response.statusCode);
    }

    
    // MORE THAN 200 RECORDS   
    @IsTest
    static void testMoreThan200Records() {

        List<Object> records = new List<Object>();

        for(Integer i=0; i<201; i++){
            records.add(new Map<String,Object>{
                'recordId' => '001000000000000AAA',
                'objectType' => 'Account',
                'status' => 'Success'
            });
        }

        Map<String,Object> payload = new Map<String,Object>{
            'records' => records
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assertEquals(413, RestContext.response.statusCode);
    }

    // UNKNOWN OBJECT TYPE
    @IsTest
    static void testUnknownObjectType() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Map<String,Object> payload = new Map<String,Object>{
            'records' => new List<Object>{
                new Map<String,Object>{
                    'recordId' => acc.Id,
                    'objectType' => 'InvalidObject',
                    'status' => 'Success'
                }
            }
        };

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/netsuite/ack';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(payload));

        RestContext.request = req;
        RestContext.response = new RestResponse();

        NS_AckAPI.AckResponse res = NS_AckAPI.acknowledge();

        System.assertEquals(0, res.totalProcessed);
    }
}