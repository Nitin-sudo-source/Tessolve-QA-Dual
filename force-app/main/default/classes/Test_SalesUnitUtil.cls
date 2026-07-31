@IsTest
public class Test_SalesUnitUtil {
    
    @TestSetup
    static void setupData() {
        
        List<Sales_Unit_Master__c> data = new List<Sales_Unit_Master__c>();
        
        // India / APAC - Monthly
        data.add(new Sales_Unit_Master__c(
            Region_Group__c = 'India / APAC',
            Sales_Unit__c = 'Monthly',
            Conversion_Factor__c = 1,
            Active__c = true
        ));
        
        // USA / Europe - Monthly
        data.add(new Sales_Unit_Master__c(
            Region_Group__c = 'USA / Europe',
            Sales_Unit__c = 'Monthly',
            Conversion_Factor__c = 2,
            Active__c = true
        ));
        
        // India / APAC - Weekly
        data.add(new Sales_Unit_Master__c(
            Region_Group__c = 'India / APAC',
            Sales_Unit__c = 'Weekly',
            Conversion_Factor__c = 4,
            Active__c = true
        ));
        
        insert data;
    }
    
    
    // ✅ 1. Normal scenario (India normalization)
    @IsTest
    static void testIndiaConversion() {
        
        Test.startTest();
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            12, 
            'India', 
            'Monthly'
        );
        
        Test.stopTest();
        
        System.assertEquals(12, result, 'India Monthly conversion failed');
    }
    
    
    // ✅ 2. USA normalization
    @IsTest
    static void testUSAConversion() {
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            10, 
            'USA', 
            'Monthly'
        );
        
        System.assertEquals(20, result, 'USA Monthly conversion failed');
    }
    
    
    // ✅ 3. Decimal duration (0.5, 1.5 etc.)
    @IsTest
    static void testDecimalDuration() {
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            1.5, 
            'India', 
            'Weekly'
        );
        
        // 1.5 * 4 = 6
        System.assertEquals(6.00, result, 'Decimal conversion failed');
    }
    
    
    // ✅ 4. Already normalized region
    @IsTest
    static void testNormalizedRegionDirect() {
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            5, 
            'India / APAC', 
            'Monthly'
        );
        
        System.assertEquals(5, result);
    }
    
    
    // ✅ 5. Missing factor (no record)
    @IsTest
    static void testMissingFactor() {
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            10, 
            'India', 
            'Yearly' // not موجود
        );
        
        System.assertEquals(0, result, 'Should return 0 when factor missing');
    }
    
    
    // ✅ 6. Null inputs
    @IsTest
    static void testNullInputs() {
        
        Decimal result1 = SalesUnitUtil.getConvertedUnits(null, 'India', 'Monthly');
        Decimal result2 = SalesUnitUtil.getConvertedUnits(10, null, 'Monthly');
        Decimal result3 = SalesUnitUtil.getConvertedUnits(10, 'India', null);
        
        System.assertEquals(0, result1);
        System.assertEquals(0, result2);
        System.assertEquals(0, result3);
    }
    
    
    // ✅ 7. Zero factor scenario
    @IsTest
    static void testZeroFactor() {
        
        insert new Sales_Unit_Master__c(
            Region_Group__c = 'India / APAC',
            Sales_Unit__c = 'Daily',
            Conversion_Factor__c = 0,
            Active__c = true
        );
        
        Decimal result = SalesUnitUtil.getConvertedUnits(
            10,
            'India',
            'Daily'
        );
        
        System.assertEquals(0, result, 'Zero factor should return 0');
    }
}