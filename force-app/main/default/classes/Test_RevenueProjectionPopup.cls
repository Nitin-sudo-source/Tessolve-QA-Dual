@isTest
public class Test_RevenueProjectionPopup {
    
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
    }
    
    static testMethod void testRevenueProjectionMethods() {
        
        Test.startTest();
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        // getOppDetails
        RevenueProjectionPopup.getOppDetails(opp.Id);
        
        // getBookingWrapper
        List<RevenueProjectionPopup.RevenueWrapper> wrapperList =
            RevenueProjectionPopup.getBookingWrapper(opp.Id);
        
        if(wrapperList != null && !wrapperList.isEmpty()){
            for(RevenueProjectionPopup.RevenueWrapper bk : wrapperList){
                bk.psm.Quarter_Amount__c = 1000;
            }
            
            RevenueProjectionPopup.Save(wrapperList, opp.Id);
        }
        
        // getRevenueInfo
        List<RevenueProjectionPopup.RevenueWrapper> revenueList =
            RevenueProjectionPopup.getRevenueInfo(opp.Id);
        
        if(revenueList != null && !revenueList.isEmpty()){
            for(RevenueProjectionPopup.RevenueWrapper rw : revenueList){
                rw.psm.Quarter_Amount__c = 1111;
            }
            
            RevenueProjectionPopup.UpdateRevenue(revenueList);
        }
        
        // Quarter methods
        RevenueProjectionPopup.getQuarterStart(2025,1);
        RevenueProjectionPopup.getQuarterEnd(2025,1);
        
        Test.stopTest();
    }
}