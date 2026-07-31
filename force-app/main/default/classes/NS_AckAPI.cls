@RestResource(urlMapping='/netsuite/ack')
global without sharing class NS_AckAPI {

    global class AckItem {
        public Id recordId;
        public String objectType; // Account, Opportunity
        public String status;     // Success / Failed
        public String netsuiteId;
    }

    global class AckRequest {
        public List<AckItem> records;
    }

    global class AckResponse {
        public Integer totalReceived;
        public Integer totalProcessed;
        public Integer totalFailed;
        public List<String> failedRecordIds;
        public String message;
    }

    @HttpPost
    global static AckResponse acknowledge() {

        AckResponse response = new AckResponse();
        response.failedRecordIds = new List<String>();
        String body = RestContext.request.requestBody.toString();
        
        try {

            
            AckRequest request =
                (AckRequest) JSON.deserialize(body, AckRequest.class);

            if(request == null || request.records == null || request.records.isEmpty()){
                RestContext.response.statusCode = 400;
                NS_IntegrationUtil.logError(
                null,
                null,
                null,
                'No records provided',
                400,
                body
            );
                response.message = 'No records provided';
                return response;
            }

            //governor protection
            if(request.records.size() > 200){
                RestContext.response.statusCode = 413;
                NS_IntegrationUtil.logError(
                null,
                null,
                null,
                'Maximum 200 records allowed per request',
                413,
                body
            );
                response.message = 'Maximum 200 records allowed per request';
                return response;
            }

            response.totalReceived = request.records.size();

            List<Account> accountsToUpdate = new List<Account>();
            List<Opportunity> oppsToUpdate = new List<Opportunity>();

            for(AckItem item : request.records){

                if(item.recordId == null ||
                   String.isBlank(item.objectType) ||
                   String.isBlank(item.status)){
                    continue;
                }

                if(item.objectType == 'Account'){

                    Account acc = new Account(Id = item.recordId);
                    acc.NS_Integration_Status__c = item.status;
                    acc.NS_Last_Push_Date__c = System.now();
                    acc.NS_Custom_Account_Id__c = item.netsuiteId;

                    if(item.status == 'Success'){
                        acc.NS_Manual_Pull__c = false;
                    }

                    accountsToUpdate.add(acc);
                }

                else if(item.objectType == 'Opportunity'){

                    Opportunity opp = new Opportunity(Id = item.recordId);
                    opp.NS_Integration_Status__c = item.status;
                    opp.NS_Last_Push_Date__c = System.now();
                    opp.NS_Custom_Opp_Id__c = item.netsuiteId;

                    if(item.status == 'Success'){
                        opp.NS_Manual_Pull__c = false;
                    }

                    oppsToUpdate.add(opp);
                }
            }

            Integer processedCount = 0;

            // Partial DML for Accounts
            if(!accountsToUpdate.isEmpty()){
                Database.SaveResult[] accResults =
                    Database.update(accountsToUpdate, false);

                for(Integer i=0; i<accResults.size(); i++){
                    if(accResults[i].isSuccess()){
                        processedCount++;
                    }else{
                        response.failedRecordIds
                            .add(accountsToUpdate[i].Id);
                    }
                }
            }

            // Partial DML for Opportunities
            if(!oppsToUpdate.isEmpty()){
                Database.SaveResult[] oppResults =
                    Database.update(oppsToUpdate, false);

                for(Integer i=0; i<oppResults.size(); i++){
                    if(oppResults[i].isSuccess()){
                        processedCount++;
                    }else{
                        response.failedRecordIds
                            .add(oppsToUpdate[i].Id);
                    }
                }
            }

            response.totalProcessed = processedCount;
            response.totalFailed =
                response.totalReceived - processedCount;

            response.message = 'Bulk ACK processed';

            RestContext.response.statusCode = 200;

        } catch(Exception e){

            RestContext.response.statusCode = 500;
             NS_IntegrationUtil.logError(
                null,
                null,
                null,
                e.getMessage(),
                500,
                body
            );
            response.message =
                'Error processing ACK: ' + e.getMessage();
        }

        return response;
    }
}