public with sharing class SalesUnitUtil {
    
    private static Map<String, Decimal> conversionMap;
    
    // Load metadata once per transaction
    private static void loadConversionMap() {
        if (conversionMap != null) return;
        
        conversionMap = new Map<String, Decimal>();
        
        for (Sales_Unit_Master__c su : [
            SELECT Region_Group__c, Sales_Unit__c, Conversion_Factor__c
            FROM Sales_Unit_Master__c
            WHERE Active__c = true
        ]) {
            if (String.isBlank(su.Region_Group__c) || String.isBlank(su.Sales_Unit__c)) {
                continue;
            }
            
            String key = su.Region_Group__c.trim().toLowerCase() 
                       + '_' + 
                         su.Sales_Unit__c.trim().toLowerCase();
            
            conversionMap.put(
                key, 
                su.Conversion_Factor__c != null ? su.Conversion_Factor__c : 0
            );
        }
        
        System.debug('✅ Conversion Map Loaded: ' + conversionMap);
    }
    
    // 🔥 Main reusable method
    public static Decimal getConvertedUnits(
        Decimal durationMonths,
        String regionGroup,
        String salesUnit
    ){
        System.debug('--- Conversion START ---');
        
        if (durationMonths == null || String.isBlank(regionGroup) || String.isBlank(salesUnit)) {
            System.debug('❌ Invalid input');
            return 0;
        }
        
        loadConversionMap();
        
        // ✅ Normalize Region
        String normalizedRegion = regionGroup.trim();
        
        if (normalizedRegion.equalsIgnoreCase('India')) {
            normalizedRegion = 'India / APAC';
        } 
        else if (normalizedRegion.equalsIgnoreCase('USA')) {
            normalizedRegion = 'USA / Europe';
        }
        
        // ✅ Build Key
        String key = normalizedRegion.toLowerCase() 
                   + '_' + 
                     salesUnit.trim().toLowerCase();
        
        // ✅ Fetch factor
        Decimal factor = conversionMap.get(key);
        
        // 🔍 Debug everything
        System.debug('Duration: ' + durationMonths);
        System.debug('Region (Input): ' + regionGroup);
        System.debug('Region (Normalized): ' + normalizedRegion);
        System.debug('Sales Unit: ' + salesUnit);
        System.debug('Generated Key: ' + key);
        System.debug('Factor: ' + factor);
        
        if (factor == null || factor == 0) {
            System.debug('❌ No conversion factor found');
            return 0;
        }
        
        // ✅ Core calculation (supports decimals perfectly)
        Decimal result = durationMonths * factor;
        
        // ✅ Controlled rounding
        result = result.setScale(2, RoundingMode.HALF_UP);
        
        System.debug('✅ Final Result: ' + result);
        System.debug('--- Conversion END ---');
        
        return result;
    }
}