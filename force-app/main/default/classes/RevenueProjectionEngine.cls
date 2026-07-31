public with sharing class RevenueProjectionEngine {
    
    /* =========================================================
CONSTANTS
========================================================= */
    private static final String RT_TM = 'T_M';
    private static final Set<String> RT_MILESTONE =
        new Set<String>{'SoC_Services','IP','Pro_Video','ASIC'};
            private static final String SOURCE_RESOURCE = 'Resource';
    private static final String SOURCE_MILESTONE = 'Milestone';
    private static final String SOURCE_MANUAL = 'Manual';
    private static final String STATUS_ACTIVE = 'Active';
    private static final String STATUS_LOCKED = 'Locked';
    
    
    /* =========================================================
RESOURCE BASED (9 RECORD MODEL)
========================================================= */
    
    /* public static void recalcFromResourceLines(Set<Id> oppIds){

if(oppIds == null || oppIds.isEmpty()) return;

Map<Id, Opportunity> oppMap = getEligibleOpportunities(oppIds);
if(oppMap.isEmpty()) return;

// Filter T&M only
Map<Id, Opportunity> tmOpps = new Map<Id, Opportunity>();
for(Opportunity opp : oppMap.values()){
if(opp.RecordType.DeveloperName == RT_TM){
tmOpps.put(opp.Id, opp);
}
}
if(tmOpps.isEmpty()) return;

Integer currentFY = getFiscalYear(Date.today());
Integer nextFY    = currentFY + 1;
Integer extendedFY = nextFY + 1;

// STEP 1: Query Existing Projection Records
Map<String, Revenue_Projection__c> projectionKeyMap =
fetchExistingQuarterRecords(tmOpps.keySet());

syncCurrency(projectionKeyMap, oppMap);

// STEP 2: Ensure 9 records exist per Opp
ensureNineRecordsPerOpportunity(
projectionKeyMap,
tmOpps,
currentFY,
nextFY,
extendedFY,
SOURCE_RESOURCE
);

// STEP 3: Reset all Quarter Amounts
for(Revenue_Projection__c rp : projectionKeyMap.values()){
if(rp.Projection_Status__c != STATUS_LOCKED &&
rp.Projection_Source__c != SOURCE_MANUAL){
rp.Quarter_Amount__c = 0;
}
}

// STEP 4: Fetch RLIs
List<Resource_Line_Item__c> rlis = [
SELECT Related_Opportunity__c,
Billing_Start_Date__c,
Duration_Months_Calculated_c__c,
Duration_Months__c,
Projected_Revenue__c
FROM Resource_Line_Item__c
WHERE Related_Opportunity__c IN :tmOpps.keySet()
];

// STEP 5: Allocate
for(Resource_Line_Item__c rli : rlis){

if(rli.Billing_Start_Date__c == null ||
rli.Projected_Revenue__c == null)
continue;

Decimal revenue = rli.Projected_Revenue__c;



Integer months = (rli.Duration_Months__c == null)
? 0
: Integer.valueOf(rli.Duration_Months__c);
System.debug('months: '+months);

// BELOW THRESHOLD → Full revenue in start quarter
if(months <= 0){
allocateAmount(
projectionKeyMap,
rli.Related_Opportunity__c,
rli.Billing_Start_Date__c,
revenue,
currentFY,
nextFY,
extendedFY
);
}
else{
Decimal monthlyRevenue = revenue / months;

for(Integer i = 0; i < months; i++){

Date revenueDate = rli.Billing_Start_Date__c.addMonths(i);

allocateAmount(
projectionKeyMap,
rli.Related_Opportunity__c,
revenueDate,
monthlyRevenue,
currentFY,
nextFY,
extendedFY
);
}
}
}

for(Revenue_Projection__c rp : projectionKeyMap.values()){

if(rp.Projection_Status__c != STATUS_LOCKED &&
rp.Projection_Source__c != SOURCE_MANUAL){

rp.Is_Auto_Calculated__c = true;
rp.Last_Recalculated_On__c = System.now();
}
}

upsert projectionKeyMap.values();
}*/
    
    public static void recalcFromResourceLines(Set<Id> oppIds){
        
        if(oppIds == null || oppIds.isEmpty()) return;
        
        Map<Id, Opportunity> oppMap = getEligibleOpportunities(oppIds);
        if(oppMap.isEmpty()) return;
        
        // Filter T&M only
        Map<Id, Opportunity> tmOpps = new Map<Id, Opportunity>();
        for(Opportunity opp : oppMap.values()){
            if(opp.RecordType.DeveloperName == RT_TM){
                tmOpps.put(opp.Id, opp);
            }
        }
        if(tmOpps.isEmpty()) return;
        
        Integer currentFY = getFiscalYear(Date.today());
        Integer nextFY    = currentFY + 1;
        Integer extendedFY = nextFY + 1;
        
        // STEP 1: Query Existing Projection Records
        Map<String, Revenue_Projection__c> projectionKeyMap =
            fetchExistingQuarterRecords(tmOpps.keySet());
        
        syncCurrency(projectionKeyMap, oppMap);
        
        // STEP 2: Ensure 9 records exist per Opp
        ensureNineRecordsPerOpportunity(
            projectionKeyMap,
            tmOpps,
            currentFY,
            nextFY,
            extendedFY,
            SOURCE_RESOURCE
        );
        
        // STEP 3: Reset all Quarter Amounts
        for(Revenue_Projection__c rp : projectionKeyMap.values()){
            if(rp.Projection_Status__c != STATUS_LOCKED &&
               rp.Projection_Source__c != SOURCE_MANUAL){
                   rp.Quarter_Amount__c = 0;
               }
        }
        
        // STEP 4: Fetch RLIs
        List<Resource_Line_Item__c> rlis = [
            SELECT Related_Opportunity__c,
            Billing_Start_Date__c,
            Duration_Months_Calculated_c__c,
            Duration_Months__c,
            Projected_Revenue__c,
            Sales_Unit__c,
            Region_Group__c,
            Region__c
            FROM Resource_Line_Item__c
            WHERE Related_Opportunity__c IN :tmOpps.keySet()
        ];
        
        Map<String, Decimal> monthlyHoursByRegion = new Map<String, Decimal>();
        
        for(Sales_Unit_Master__c su : [
            SELECT Sales_Unit__c, Region_Group__c, Conversion_Factor__c
            FROM Sales_Unit_Master__c
            WHERE Active__c = true
        ]){
            String key = su.Sales_Unit__c + '_' +su.Region_Group__c;
            monthlyHoursByRegion.put(key, su.Conversion_Factor__c);
        }
        
        // STEP 5: Allocate (NEW LOGIC)
        for(Resource_Line_Item__c rli : rlis){
            
            if(rli.Billing_Start_Date__c == null ||
               rli.Projected_Revenue__c == null)
                continue;
            
            System.debug('----- RLI START -----');
            System.debug('OppId: ' + rli.Related_Opportunity__c);
            System.debug('Start Date: ' + rli.Billing_Start_Date__c);
            System.debug('Revenue: ' + rli.Projected_Revenue__c);
            System.debug('Duration: ' + rli.Duration_Months__c);
            
            Decimal totalRevenue = rli.Projected_Revenue__c;
            Decimal duration = (rli.Duration_Months__c == null) ? 0 : rli.Duration_Months__c;
            
            if(duration <= 0){
                allocateAmount(
                    projectionKeyMap,
                    rli.Related_Opportunity__c,
                    rli.Billing_Start_Date__c,
                    totalRevenue,
                    currentFY,
                    nextFY,
                    extendedFY
                );
                continue;
            }
            
            String key = rli.Sales_Unit__c + '_' + rli.Region_Group__c;
            
            Decimal monthlyHours = monthlyHoursByRegion.containsKey(key)
                ? monthlyHoursByRegion.get(key)
                : 176; 
            
            Decimal rate = (monthlyHours > 0)
                ? totalRevenue / (monthlyHours * duration)
                : 0;
            
            Decimal monthlyRevenue = monthlyHours * rate;
            
            Integer fullMonths = Integer.valueOf(Math.floor(duration));
            Decimal partialMonth = duration - fullMonths;
            
            System.debug('Monthly Revenue: ' + monthlyRevenue);
            System.debug('Full Months: ' + fullMonths);
            System.debug('Partial Month: ' + partialMonth);
            
            for(Integer i = 0; i <= fullMonths; i++){
                
                Date currentMonthDate = rli.Billing_Start_Date__c.addMonths(i);
                Decimal factor;
                
                // 👉 FIRST MONTH (partial based on start date)
                if(i == 0){
                    factor = getWorkingDayFactor(rli.Billing_Start_Date__c);
                    System.debug('First Month Factor: ' + factor);
                }
                // 👉 LAST MONTH (fraction like 0.5)
                else if(i == fullMonths){
                    
                    Decimal firstFactor = getWorkingDayFactor(rli.Billing_Start_Date__c);
                    Decimal usedFactor = firstFactor + (fullMonths - 1);
                    
                    Decimal remainingFactor = duration - usedFactor;
                    
                    System.debug('Used Factor: ' + usedFactor);
                    System.debug('Remaining Factor (FIXED): ' + remainingFactor);
                    
                    factor = remainingFactor;
                }
                else{
                    factor = 1;
                }
                
                Decimal amount = monthlyRevenue * factor;
                
                System.debug('Month Index: ' + i);
                System.debug('Date: ' + currentMonthDate);
                System.debug('Allocated Amount: ' + amount);
                
                allocateAmount(
                    projectionKeyMap,
                    rli.Related_Opportunity__c,
                    currentMonthDate,
                    amount,
                    currentFY,
                    nextFY,
                    extendedFY
                );
            }
            
            System.debug('----- RLI END -----');
        }
        
        for(Revenue_Projection__c rp : projectionKeyMap.values()){
            
            if(rp.Projection_Status__c != STATUS_LOCKED &&
               rp.Projection_Source__c != SOURCE_MANUAL){
                   
                   rp.Is_Auto_Calculated__c = true;
                   rp.Last_Recalculated_On__c = System.now();
               }
        }
        
        upsert projectionKeyMap.values();
    }
    
    private static Integer countWorkingDays(Date startDate, Date endDate){
        
        if(startDate == null || endDate == null || startDate > endDate){
            return 0;
        }
        
        Integer count = 0;
        
        for(Date d = startDate; d <= endDate; d = d.addDays(1)){
            
            // 0 = Sunday, 6 = Saturday
            Integer dayOfWeek = Math.mod(Date.newInstance(1900, 1, 7).daysBetween(d), 7);
            
            if(dayOfWeek != 0 && dayOfWeek != 6){
                count++;
            }
        }
        
        System.debug('Working Days Count from ' + startDate + ' to ' + endDate + ' = ' + count);
        
        return count;
    }
    
    private static Decimal getWorkingDayFactor(Date startDate){
        
        Date monthStart = Date.newInstance(startDate.year(), startDate.month(), 1);
        Date monthEnd   = monthStart.addMonths(1).addDays(-1);
        
        Integer totalWorkingDays = countWorkingDays(monthStart, monthEnd);
        Integer remainingWorkingDays = countWorkingDays(startDate, monthEnd);
        
        Decimal factor = (totalWorkingDays == 0)
            ? 0
            : Decimal.valueOf(remainingWorkingDays) / totalWorkingDays;
        
        System.debug('Working Days Factor → Total: ' + totalWorkingDays +
                     ', Remaining: ' + remainingWorkingDays +
                     ', Factor: ' + factor);
        
        return factor;
    }
    
    /* =========================================================
FISCAL LOGIC (APR–MAR)
========================================================= */
    
    private static Date getQuarterStart(Integer fy, Integer q){
        if(q == 1) return Date.newInstance(fy,4,1);
        if(q == 2) return Date.newInstance(fy,7,1);
        if(q == 3) return Date.newInstance(fy,10,1);
        return Date.newInstance(fy+1,1,1);
    }
    
    private static Date getQuarterEnd(Integer fy, Integer q){
        if(q == 1) return Date.newInstance(fy,6,30);
        if(q == 2) return Date.newInstance(fy,9,30);
        if(q == 3) return Date.newInstance(fy,12,31);
        return Date.newInstance(fy+1,3,31);
    }
    
    
    private static Map<String, Revenue_Projection__c>
        fetchExistingQuarterRecords(Set<Id> oppIds){
            
            Map<String, Revenue_Projection__c> result =
                new Map<String, Revenue_Projection__c>();
            
            for(Revenue_Projection__c rp : [
                SELECT Id,
                Opportunity__c,
                Fiscal_Year__c,
                Fiscal_Quarter__c,
                Quarter_Amount__c,
                Projection_Status__c,
                Projection_Source__c,
                Is_Auto_Calculated__c,
                Last_Recalculated_On__c,
                CurrencyIsoCode 
                FROM Revenue_Projection__c
                WHERE Opportunity__c IN :oppIds
            ]){
                String key =
                    rp.Opportunity__c + '_' +
                    rp.Fiscal_Year__c + '_' +
                    rp.Fiscal_Quarter__c;
                
                result.put(key, rp);
            }
            
            return result;
        }
    
    private static void ensureNineRecordsPerOpportunity(
        Map<String, Revenue_Projection__c> mapRef,
        Map<Id, Opportunity> oppMap,
        Integer currentFY,
        Integer nextFY,
        Integer extendedFY,
        String projectionSource){
            
            for(Id oppId : oppMap.keySet()){
                
                for(Integer fy : new List<Integer>{currentFY, nextFY}){
                    
                    for(Integer q = 1; q <= 4; q++){
                        
                        String quarterLabel = 'Q' + q;
                        
                        String key = oppId + '_' + fy + '_' + quarterLabel;
                        
                        if(!mapRef.containsKey(key)){
                            
                            mapRef.put(key,
                                       new Revenue_Projection__c(
                                           Opportunity__c = oppId,
                                           Account__c = oppMap.get(oppId).AccountId,
                                           CurrencyIsoCode = oppMap.get(oppId).CurrencyIsoCode,
                                           Fiscal_Year__c = fy,
                                           Fiscal_Quarter__c = quarterLabel,
                                           Quarter_Start_Date__c = getQuarterStart(fy, q),
                                           Quarter_End_Date__c   = getQuarterEnd(fy, q),
                                           Quarter_Amount__c = 0,
                                           Is_Extended__c = false,
                                           Projection_Status__c = STATUS_ACTIVE,
                                           Projection_Source__c = projectionSource
                                           
                                       )
                                      );
                        }
                    }
                }
                
                // Extended Record
                String extKey = oppId + '_' + extendedFY + '_Extended';
                
                if(!mapRef.containsKey(extKey)){
                    
                    mapRef.put(extKey,
                               new Revenue_Projection__c(
                                   Opportunity__c = oppId,
                                   Account__c = oppMap.get(oppId).AccountId,
                                   CurrencyIsoCode = oppMap.get(oppId).CurrencyIsoCode,
                                   Fiscal_Year__c = extendedFY,
                                   Fiscal_Quarter__c = 'Extended',
                                   Is_Extended__c = true,
                                   Quarter_Amount__c = 0,
                                   Projection_Status__c = STATUS_ACTIVE,
                                   Projection_Source__c = projectionSource
                               )
                              );
                }
            }
        }
    
    private static void allocateAmount(
        Map<String, Revenue_Projection__c> mapRef,
        Id oppId,
        Date revenueDate,
        Decimal amount,
        Integer currentFY,
        Integer nextFY,
        Integer extendedFY){
            
            Integer fy = getFiscalYear(revenueDate);
            Integer q  = getFiscalQuarter(revenueDate);
            
            String quarterLabel = 'Q' + q;
            
            if(fy == currentFY || fy == nextFY){
                
                String key = oppId + '_' + fy + '_' + quarterLabel;
                
                if(mapRef.containsKey(key)){
                    Revenue_Projection__c rp = mapRef.get(key);
                    
                    if(rp.Projection_Status__c != STATUS_LOCKED &&
                       rp.Projection_Source__c != SOURCE_MANUAL){
                           
                           rp.Quarter_Amount__c += amount;
                       }
                    //mapRef.get(key).Quarter_Amount__c += amount;
                }
            }
            else{
                String extKey = oppId + '_' + extendedFY + '_Extended';
                
                if(mapRef.containsKey(extKey)){
                    Revenue_Projection__c rp = mapRef.get(extKey);
                    
                    if(rp.Projection_Status__c != STATUS_LOCKED &&
                       rp.Projection_Source__c != SOURCE_MANUAL){
                           
                           rp.Quarter_Amount__c += amount;
                       }
                    //mapRef.get(extKey).Quarter_Amount__c += amount;
                }
            }
        }
    
    
    public static void recalcFromMilestones(Set<Id> oppIds){
        
        if(oppIds == null || oppIds.isEmpty()) return;
        
        Map<Id, Opportunity> oppMap = getEligibleOpportunities(oppIds);
        if(oppMap.isEmpty()) return;
        
        Map<Id, Opportunity> milestoneOpps = new Map<Id, Opportunity>();
        
        for(Opportunity opp : oppMap.values()){
            if(RT_MILESTONE.contains(opp.RecordType.DeveloperName)){
                milestoneOpps.put(opp.Id, opp);
            }
        }
        
        if(milestoneOpps.isEmpty()) return;
        
        Integer currentFY  = getFiscalYear(Date.today());
        Integer nextFY     = currentFY + 1;
        Integer extendedFY = nextFY + 1;
        
        /* ----------------------------------------
STEP 1 – Fetch existing records
---------------------------------------- */
        Map<String, Revenue_Projection__c> projectionKeyMap =
            fetchExistingQuarterRecords(milestoneOpps.keySet());
        
        
        
        /* ----------------------------------------
STEP 2 – Ensure 9 records exist
---------------------------------------- */
        ensureNineRecordsPerOpportunity(
            projectionKeyMap,
            milestoneOpps,
            currentFY,
            nextFY,
            extendedFY,
            SOURCE_MILESTONE
        );
        
        syncCurrency(projectionKeyMap, milestoneOpps);
        
        /* ----------------------------------------
STEP 3 – Reset amounts
---------------------------------------- */
        for(Revenue_Projection__c rp : projectionKeyMap.values()){
            if(rp.Projection_Status__c != STATUS_LOCKED &&
               rp.Projection_Source__c != SOURCE_MANUAL){
                   rp.Quarter_Amount__c = 0;
               }
        }
        
        /* ----------------------------------------
STEP 4 – Fetch milestones
---------------------------------------- */
        List<Payment_Milestone__c> milestones = [
            SELECT Opportunity__c,
            Due_Date__c,
            Amount__c
            FROM Payment_Milestone__c
            WHERE Opportunity__c IN :milestoneOpps.keySet()
        ];
        
        /* ----------------------------------------
STEP 5 – Allocate
---------------------------------------- */
        for(Payment_Milestone__c ms : milestones){
            
            if(ms.Due_Date__c == null || ms.Amount__c == null)
                continue;
            
            allocateAmount(
                projectionKeyMap,
                ms.Opportunity__c,
                ms.Due_Date__c,
                ms.Amount__c,
                currentFY,
                nextFY,
                extendedFY
            );
        }
        for(Revenue_Projection__c rp : projectionKeyMap.values()){
            
            if(rp.Projection_Status__c != STATUS_LOCKED &&
               rp.Projection_Source__c != SOURCE_MANUAL){
                   
                   rp.Is_Auto_Calculated__c = true;
                   rp.Last_Recalculated_On__c = System.now();
               }
        }
        
        upsert projectionKeyMap.values();
    }
    
    /* =========================================================
OPPORTUNITY FILTER (EXCLUDE CLOSED WON)
========================================================= */
    
    private static Map<Id, Opportunity> getEligibleOpportunities(
        Set<Id> oppIds){
            
            Map<Id, Opportunity> result = new Map<Id, Opportunity>();
            
            for(Opportunity opp : [
                SELECT Id,
                StageName,
                AccountId,
                CurrencyIsoCode,
                RecordType.DeveloperName
                FROM Opportunity
                WHERE Id IN :oppIds
            ]){
                if(opp.StageName != 'Closed Won' || opp.StageName != 'Closed Lost' ){
                    result.put(opp.Id, opp);
                }
            }
            return result;
        }
    
    
    /* =========================================================
FISCAL YEAR CALCULATION (APR–MAR)
========================================================= */
    
    private static Integer getFiscalYear(Date d){
        
        if(d.month() >= 4){
            return d.year();
        } else {
            return d.year() - 1;
        }
    }
    
    
    /* =========================================================
FISCAL QUARTER (APR–MAR)
========================================================= */
    
    private static Integer getFiscalQuarter(Date d){
        
        Integer month = d.month();
        
        if(month >= 4 && month <= 6) return 1;     // Apr–Jun
        if(month >= 7 && month <= 9) return 2;     // Jul–Sep
        if(month >= 10 && month <= 12) return 3;   // Oct–Dec
        return 4;                                  // Jan–Mar
    }
    
    private static void syncCurrency(
        Map<String, Revenue_Projection__c> projectionKeyMap,
        Map<Id, Opportunity> oppMap){
            
            for(Revenue_Projection__c rp : projectionKeyMap.values()){
                
                Opportunity opp = oppMap.get(rp.Opportunity__c);
                
                if(opp != null && rp.CurrencyIsoCode != opp.CurrencyIsoCode){
                    rp.CurrencyIsoCode = opp.CurrencyIsoCode;
                }
            }
        }
}