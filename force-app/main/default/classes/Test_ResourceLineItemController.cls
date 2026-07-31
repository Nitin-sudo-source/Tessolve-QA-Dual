@IsTest
public class Test_ResourceLineItemController {
    
    @TestSetup
    static void setupData() {
        
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Skill_Category_Matrix__c skill = new Skill_Category_Matrix__c(Name='Test', Sub_Skills__c = 'Analog',
                                                                      Business_Unit__c = 'Pre-Silicon',
                                                                      Sub_Business_Unit__c = 'IC Design (Analog)',
                                                                      //Experience__c = '0-2',
                                                                      Region__c = 'India', Customer__c = acc.Id);
        Experience__c exp1 = new Experience__c(Name='Test', Sub_Skills__c = 'Analog',
                                               Business_Unit__c = 'Pre-Silicon',
                                               Sub_Business_Unit__c = 'IC Design (Analog)',
                                               //Experience__c = '0-2',
                                               Region__c = 'India', Customer__c = acc.Id);
        insert skill;
        
        List<Opportunity> opps = new List<Opportunity>();
        
        for(Integer i = 0; i < 2; i++){
            opps.add(new Opportunity(
                Name = 'Test Opp ' + i,
                StageName = 'Prequalified',
                CloseDate = Date.today().addDays(30),
                Amount = 50000,
                Application__c = 'Automotive Software',
                Business_Type__c = 'Existing Account - New Group',
                Business_Unit_BU__c = 'Pre-Silicon',
                Sub_Business_Unit__c = 'IC Design (Analog)',
                Estimated_Project_Start_Date__c = System.today(),
                Markets__c = 'Telecom',
                Execution_Location__c = 'India',
                AccountId = acc.Id,
                CurrencyIsoCode = 'INR'
            ));
        }
        
        insert opps;
        System.debug('opps: '+opps);
        
        
        // Create Rate Card
        Rate_Card__c rateCard = new Rate_Card__c(
            Account__c = acc.Id,
            Type__c = 'MSA',
            Start_Date__c = System.today(),
            End_Date__c = System.today().addDays(50)
        );
        insert rateCard;
        
        
        // Create Rate Card Line Item (MATCHING VALUES)
        Rate_card_Line_Item__c rateLine = new Rate_card_Line_Item__c(
            Rate_Card__c = rateCard.Id,
            Rate_Amount__c = 150,
            CurrencyIsoCode = 'INR',
            Sub_Skills__c = 'Analog',
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            //Experience__c = '0-2',
            Region__c = 'India',
            Sales_Unit__c = 'Monthly',
            Account__c = acc.Id,
            Skill_Category__c = skill.Id
        );
        insert rateLine;
        
        
        
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opps[0].Id,
            Account__c = acc.Id,
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Billing_Start_Date__c = Date.today(),
            Region__c = 'India',
            CurrencyIsoCode = 'INR',
            Selling_Rate__c = 100,
            Sub_Skills__c = 'Analog',
            //Experience__c = '0-2',
            Duration_Months__c = 12,
            Status__c = 'Lost',
            Sales_Unit__c = 'Monthly',
            Tentative_Start_Date__c = Date.today().addDays(5),
            Number_of_Resources__c = 2,
            Engineer_Name__c = 'Test Engineer',
            Skill_Category_Matrix__c = skill.Id,
            Remarks__c = 'Test Remarks',
            Is_Rate_Modified__c = true
        );
        insert rli;
        System.debug('rli: '+rli);
        Test.startTest();
        //ResourceLineItemController.getMasterDetails(opps[0].Id);
        Test.stopTest();
        
    }
    
    @IsTest
    static void testGetOppDetails() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        Test.startTest();
        ResourceLineItemController.getOppDetails(opp.Id);
        ResourceLineItemController.getMasterDetails(opp.Id);
        Test.stopTest();
    }
    
    /* @IsTest
static void testGetMasterDetails() {
Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

Test.startTest();
ResourceLineItemController.getMasterDetails(opp.Id);
Test.stopTest();
}*/
    
    @IsTest
    static void testConvertCurrency() {
        Test.startTest();
        ResourceLineItemController.convertCurrency(100, 'INR', 'USD');
        Test.stopTest();
    }
    
     @IsTest
    static void testSaveDetails_InsertNonMSA() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Skill_Category_Matrix__c skill = [SELECT Id FROM Skill_Category_Matrix__c LIMIT 1];
        
        // ✅ Create Experience (IMPORTANT)
        Experience__c exp1 = new Experience__c(
            Name = '0-2',
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert exp1;
        
        Resource_Line_Item__c tempRLI = new Resource_Line_Item__c();
        tempRLI.put('Id', 'temp123'); 
        tempRLI.Business_Unit__c = 'Pre-Silicon';
        tempRLI.Sub_Business_Unit__c = 'IC Design (Analog)';
        tempRLI.Billing_Start_Date__c = Date.today();
        tempRLI.Region__c = 'India';
        tempRLI.CurrencyIsoCode = 'INR';
        tempRLI.Selling_Rate__c = 100;
        tempRLI.Sales_Selling_Rate__c = 89;
        tempRLI.Experience__c = '0-2';
        tempRLI.Duration_Months__c = 12;
        tempRLI.Duration_Months_Calculated_c__c = 12;
        tempRLI.Status__c = 'Lost';
        tempRLI.Lost_Remarks__c = 'Test';
        tempRLI.Lost_Reason__c = 'Lost';
        
        tempRLI.Sales_Unit__c = 'Monthly';
        tempRLI.Tentative_Start_Date__c = Date.today().addDays(5);
        tempRLI.Number_of_Resources__c = 2;
        tempRLI.Engineer_Name__c = 'Test Engineer';
        tempRLI.Skill_Category_Matrix__c = skill.Id;
        tempRLI.Experience1__c = exp1.Id;
        tempRLI.Remarks__c = 'Test Remarks';
        
        // ✅ USE CONSTRUCTOR
        ResourceLineItemController.RLIWrapper wrap =
            new ResourceLineItemController.RLIWrapper(tempRLI, 1, false);
        
        wrap.isMSA = false;
        wrap.isNonMSA = true;
        wrap.isRecalculation = true;
        
        List<ResourceLineItemController.RLIWrapper> rows =
            new List<ResourceLineItemController.RLIWrapper>{ wrap };
                
                Test.startTest();
        ResourceLineItemController.saveDetails(rows, opp.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testSaveDetails_Insert() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        Skill_Category_Matrix__c skill = [SELECT Id FROM Skill_Category_Matrix__c LIMIT 1];
        
        // ✅ Create Experience (IMPORTANT)
        Experience__c exp1 = new Experience__c(
            Name = '0-2',
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert exp1;
        
        Resource_Line_Item__c tempRLI = new Resource_Line_Item__c();
        tempRLI.put('Id', 'temp123'); 
        tempRLI.Business_Unit__c = 'Pre-Silicon';
        tempRLI.Sub_Business_Unit__c = 'IC Design (Analog)';
        tempRLI.Billing_Start_Date__c = Date.today();
        tempRLI.Region__c = 'India';
        tempRLI.CurrencyIsoCode = 'INR';
        tempRLI.Selling_Rate__c = 100;
        tempRLI.Experience__c = '0-2';
        tempRLI.Duration_Months__c = 12;
        tempRLI.Status__c = 'Resource Fulfilled';
        tempRLI.Sales_Unit__c = 'Monthly';
        tempRLI.Tentative_Start_Date__c = Date.today().addDays(5);
        tempRLI.Number_of_Resources__c = 2;
        tempRLI.Engineer_Name__c = 'Test Engineer';
        tempRLI.Skill_Category_Matrix__c = skill.Id;
        tempRLI.Experience1__c = exp1.Id;
        tempRLI.Remarks__c = 'Test Remarks';
        
        // ✅ USE CONSTRUCTOR
        ResourceLineItemController.RLIWrapper wrap =
            new ResourceLineItemController.RLIWrapper(tempRLI, 1, false);
        
        wrap.isMSA = true;
        wrap.isNonMSA = false;
        wrap.isRecalculation = true;
        
        List<ResourceLineItemController.RLIWrapper> rows =
            new List<ResourceLineItemController.RLIWrapper>{ wrap };
                
                Test.startTest();
        ResourceLineItemController.saveDetails(rows, opp.Id);
        Test.stopTest();
    }
    
    
    
    @IsTest
    static void testSaveDetails_Update() {
        
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];
        
        List<ResourceLineItemController.RLIWrapper> wrapperList =
            ResourceLineItemController.getMasterDetails(opp.Id);
        
        // ✅ Use existing wrapper directly
        ResourceLineItemController.RLIWrapper wrap = wrapperList[0];
        
        // ✅ Ensure required flags (VERY IMPORTANT)
        wrap.isMSA = true;
        wrap.isNonMSA = false;
        wrap.isRecalculation = true;
        
        List<ResourceLineItemController.RLIWrapper> rows =
            new List<ResourceLineItemController.RLIWrapper>{ wrap };
                
                Test.startTest();
        ResourceLineItemController.saveDetails(rows, opp.Id); // ✅ UNCOMMENTED
        Test.stopTest();
    }
    
    @IsTest
    static void testGetSellingRateInformation() {
        
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Skill_Category_Matrix__c sk = [
            SELECT Id, Business_Unit__c, Sub_Business_Unit__c, Sub_Skills__c, Region__c
            FROM Skill_Category_Matrix__c LIMIT 1
        ];
        
        // ✅ Create Experience (MANDATORY for key match)
        Experience__c exp1 = new Experience__c(
            Name = '0-2',
            Business_Unit__c = sk.Business_Unit__c,
            Sub_Business_Unit__c = sk.Sub_Business_Unit__c,
            Sub_Skills__c = sk.Sub_Skills__c,
            Region__c = sk.Region__c
        );
        insert exp1;
        
        Resource_Line_Item__c rli = new Resource_Line_Item__c(
            Related_Opportunity__c = opp.Id,
            Account__c = acc.Id,
            Business_Unit__c = sk.Business_Unit__c,
            Sub_Business_Unit__c = sk.Sub_Business_Unit__c,
            Billing_Start_Date__c = Date.today(),
            Region__c = 'India',
            CurrencyIsoCode = 'INR',
            Selling_Rate__c = 0,
            Sub_Skills__c = sk.Sub_Skills__c,
            Experience__c = '0-2',
            Experience1__c = exp1.Id, // ✅ CRITICAL
            Duration_Months__c = 12,
            Status__c = 'Lost',
            Sales_Unit__c = 'Monthly',
            Number_of_Resources__c = 2,
            Engineer_Name__c = 'Test Engineer',
            Skill_Category_Matrix__c = sk.Id,
            Remarks__c = 'Test Remarks'
        );
        
        // ✅ USE CONSTRUCTOR
        ResourceLineItemController.RLIWrapper wrap =
            new ResourceLineItemController.RLIWrapper(rli, 1, true);
        
        // ✅ REQUIRED FLAGS
        wrap.isMSA = true;
        wrap.isNonMSA = false;
        wrap.isRecalculation = true;
        
        List<ResourceLineItemController.RLIWrapper> rows =
            new List<ResourceLineItemController.RLIWrapper>{ wrap };
                
                Test.startTest();
        ResourceLineItemController.getSellingRateInformation(rows, opp.Id); // ✅ UNCOMMENTED
        Test.stopTest();
    }
    
    @IsTest
    static void testFetchSkillCategoryMatrix_MSA() {
        
        Opportunity opp = [SELECT Id, AccountId FROM Opportunity LIMIT 1];
        
        // ✅ Create Skill Category Matrix (MSA - with Customer)
        Skill_Category_Matrix__c scm = new Skill_Category_Matrix__c(
            Name = 'Java Developer',
            Customer__c = opp.AccountId,
            Business_Unit__c = 'Custom Silicon',
            Sub_Business_Unit__c = 'Custom Silicon',
            Sub_Skills__c = 'SoC Services',
            Region__c = 'India'
        );
        insert scm;
        
        Test.startTest();
        
        List<Skill_Category_Matrix__c> result =
            ResourceLineItemController.fetchSkillCategoryMatrix(
                'Java',              
                opp.AccountId,              
                scm.Business_Unit__c,
                scm.Sub_Business_Unit__c,
                scm.Sub_Skills__c,
                null,
                'India',
                null,
                'MSA'
            );
        
        Test.stopTest();
        
    }
    
    
    @IsTest
    static void testFetchSkillCategoryMatrix_NonMSA() {
        
        // ✅ Create Skill Category Matrix (Non-MSA → Customer__c = NULL)
        Skill_Category_Matrix__c scm = new Skill_Category_Matrix__c(
            Name = 'Python Developer',
            Business_Unit__c = 'Custom Silicon',
            Sub_Business_Unit__c = 'Custom Silicon',
            Sub_Skills__c = 'SoC Services',
            Region__c = 'India'
        );
        insert scm;
        
        Test.startTest();
        
        List<Skill_Category_Matrix__c> result =
            ResourceLineItemController.fetchSkillCategoryMatrix(
                'Java',              
                null,              
                scm.Business_Unit__c,
                scm.Sub_Business_Unit__c,
                scm.Sub_Skills__c,
                null,
                'India',
                null,
                'Non MSA'
            );
        
        Test.stopTest();
        
        // ✅ Assertions
        
    }
    
    @IsTest
    static void testFetchExperienceOptions() {
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // ✅ MSA Experience (with Customer)
        Experience__c expMSA = new Experience__c(
            Name = 'MSA Exp',
            Customer__c = acc.Id,
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert expMSA;
        
        // ✅ Non-MSA Experience (no Customer)
        Experience__c expNonMSA = new Experience__c(
            Name = 'NonMSA Exp',
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert expNonMSA;
        
        Test.startTest();
        
        // 🔹 MSA case
        List<Experience__c> msaResult =
            ResourceLineItemController.fetchExperienceOptions(
                'MSA',
                acc.Id,
                'Pre-Silicon',
                'IC Design (Analog)',
                'Analog',
                null,
                'India',
                null,
                'MSA'
            );
        
        // 🔹 Non-MSA case
        List<Experience__c> nonMsaResult =
            ResourceLineItemController.fetchExperienceOptions(
                null,
                acc.Id,
                'Pre-Silicon',
                'IC Design (Analog)',
                'Analog',
                null,
                'India',
                null,
                'Non MSA'
            );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFetchLookupData() {
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // ✅ Skill record
        Skill_Category_Matrix__c skill = new Skill_Category_Matrix__c(
            Name = 'Java Skill',
            Customer__c = acc.Id,
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert skill;
        
        // ✅ Experience record
        Experience__c exp = new Experience__c(
            Name = '0-2',
            Customer__c = acc.Id,
            Business_Unit__c = 'Pre-Silicon',
            Sub_Business_Unit__c = 'IC Design (Analog)',
            Sub_Skills__c = 'Analog',
            Region__c = 'India'
        );
        insert exp;
        
        Test.startTest();
        
        // 🔹 SEARCH mode - Skill
        List<sObject> resultSkillSearch =
            ResourceLineItemController.fetchLookupData(
                'Java',
                'Skill_Category_Matrix__c',
                acc.Id,
                null, null, null, null, null, null
            );
        
        // 🔹 DEFAULT mode - Skill
        List<sObject> resultSkillDefault =
            ResourceLineItemController.fetchLookupData(
                null,
                'Skill_Category_Matrix__c',
                acc.Id,
                'Pre-Silicon',
                'IC Design (Analog)',
                'Analog',
                null,
                'India',
                null
            );
        
        // 🔹 Experience search
        List<sObject> resultExp =
            ResourceLineItemController.fetchLookupData(
                '0-2',
                'Experience__c',
                acc.Id,
                null, null, null, null, null, null
            );
        
        Test.stopTest();
    }
    
    @IsTest
    static void testFetchDefaultRecord() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        ResourceLineItemController.fetchDefaultRecord(
            acc.Id,
            'Account'
        );
        Test.stopTest();
    }
}