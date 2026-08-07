public with sharing class RevenuePeriodUtil {
    
    public class RevenuePeriodWrapper {
        
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public String category;
        @AuraEnabled public Boolean isDefault;
        @AuraEnabled public Boolean isCustomRange;
        @AuraEnabled public Date fromDate;
        @AuraEnabled public Date toDate;
        
    }
    
    @AuraEnabled(cacheable=true)
    public static List<RevenuePeriodWrapper> getRevenuePeriods() {
        
        List<RevenuePeriodWrapper> results = new List<RevenuePeriodWrapper>();
        
        List<Revenue_Period_Configuration__mdt> configs = [

            SELECT
                Revenue_Period__c,
                Period_Code__c,
                Period_Category__c,
                Relative_Value__c,
                Default__c,
                Custom_Range__c,
                Display_Order__c,
                Active__c
            FROM Revenue_Period_Configuration__mdt
            WHERE Active__c = TRUE
            ORDER BY Display_Order__c

        ];
        
        for(Revenue_Period_Configuration__mdt config : configs){
            
            RevenuePeriodWrapper wrapper = new RevenuePeriodWrapper();
            
            wrapper.label = config.Revenue_Period__c;
            wrapper.value = config.Period_Code__c;
            wrapper.category = config.Period_Category__c;
            wrapper.isDefault = config.Default__c;
            wrapper.isCustomRange = config.Custom_Range__c;
            
            calculateDateRange(
                wrapper,
            config.Period_Category__c,
            Integer.valueOf(config.Relative_Value__c)
                );
            
            results.add(wrapper);
            
        }
        
        return results;
        
    }
    
    private static void calculateDateRange(
        RevenuePeriodWrapper wrapper,
    String category,
    Integer relativeValue
    ){
        
        Date today = Date.today();
        
        switch on category{
            
            when 'Fiscal Year'{
                
                calculateFiscalYear(wrapper, relativeValue);
                
            }
            
            when 'Quarter'{
                
                calculateQuarter(wrapper, relativeValue);
                
            }
            
            when 'Month'{
                
                calculateMonth(wrapper, relativeValue);
                
            }
            
            when 'Week'{
                
                calculateWeek(wrapper, relativeValue);
                
            }
            
            when 'Day'{
                
                calculateDay(wrapper, relativeValue);
                
            }
            
            when 'Rolling Days'{
                
                wrapper.fromDate = today.addDays(-relativeValue + 1);
                wrapper.toDate = today;
                
            }
            
            when 'Custom'{
                
                wrapper.fromDate = null;
                wrapper.toDate = null;
                
            }
            
            when 'All Time' {
                
                wrapper.fromDate = null;
                wrapper.toDate = null;
                
            }
            
        }
        
    }
    
    private static void calculateFiscalYear(
        RevenuePeriodWrapper wrapper,
    Integer offset
    ){
        
        Date today = Date.today();
        
        Integer fy =
            today.month() >= 4
            ? today.year()
            : today.year()-1;
        
        if(offset == 99){
            
            wrapper.fromDate = Date.newInstance(fy,4,1);
            wrapper.toDate = Date.newInstance(fy+2,3,31);
            
            return;
            
        }
        
        fy += offset;
        
        wrapper.fromDate = Date.newInstance(fy,4,1);
        wrapper.toDate = Date.newInstance(fy+1,3,31);
        
    }
    
    private static void calculateQuarter(
        RevenuePeriodWrapper wrapper,
    Integer offset
    ){
        
        Date today = Date.today();
        
        Integer month = today.month();
        
        Integer fiscalMonth =
            month >= 4
            ? month-3
            : month+9;
        
        Integer quarter =
            Integer.valueOf(Math.ceil(fiscalMonth/3.0));
        
        quarter += offset;
        
        Integer fiscalYear =
            month >= 4
            ? today.year()
            : today.year()-1;
        
        while(quarter < 1){
            
            fiscalYear--;
            quarter += 4;
            
        }
        
        while(quarter > 4){
            
            fiscalYear++;
            quarter -= 4;
            
        }
        
        Integer startMonth;
        
        switch on quarter{
            
            when 1{ startMonth = 4; }
            
            when 2{ startMonth = 7; }
            
            when 3{ startMonth = 10; }
            
            when else{
                
                startMonth = 1;
                fiscalYear++;
                
            }
            
        }
        
        wrapper.fromDate = Date.newInstance(fiscalYear,startMonth,1);
        
        wrapper.toDate =
            wrapper.fromDate
            .addMonths(3)
            .addDays(-1);
        
    }
    
    private static void calculateMonth(
        RevenuePeriodWrapper wrapper,
    Integer offset
    ){
        
        Date start =
            Date.newInstance(
            Date.today().year(),
        Date.today().month(),
        1
            ).addMonths(offset);
        
        wrapper.fromDate = start;
        
        wrapper.toDate =
            start.addMonths(1).addDays(-1);
        
    }
    
    private static void calculateWeek(
        RevenuePeriodWrapper wrapper,
    Integer offset
    ){
        
        Date today = Date.today();
        
        Integer day =
            Math.mod(today.toStartOfWeek().daysBetween(today),7);
        
        Date start =
            today.addDays(-day)
            .addDays(offset*7);
        
        wrapper.fromDate = start;
        wrapper.toDate = start.addDays(6);
        
    }
    
    private static void calculateDay(
        RevenuePeriodWrapper wrapper,
    Integer offset
    ){
        
        wrapper.fromDate =
            Date.today().addDays(offset);
        
        wrapper.toDate =
            wrapper.fromDate;
        
    }
    
}