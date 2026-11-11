public class QuoteCalculationResult {
    public Solar_Panel__c panel { get; set; }
    public Integer panelCount { get; set; }
    public Decimal panelTotalCost { get; set; }
    public Inverter__c inverter { get; set; }
    public Battery_Storage__c battery { get; set; }
    public Integer batteryCount { get; set; }
    public Decimal batteryTotalCost { get; set; }
    public Accessory__c accessory { get; set; }
    public Decimal accessoryTotalCost { get; set; }
    public ProductCatalog__c protBox { get; set; }
    public ProductCatalog__c cable { get; set; }
    public Decimal laborCost { get; set; }
    public Decimal acElectricalCost { get; set; }
    public Decimal adminCost { get; set; }
    public Decimal logisticsCost { get; set; }
    public Map<String, ProductCatalog__c> serviceMap { get; set; }
    public Decimal grossTotal { get; set; }
    public Decimal yearlyGeneration { get; set; }
    public Decimal yearlySavings { get; set; }
    public Decimal netInvestment { get; set; }
    public Decimal paybackYears { get; set; }
    public Boolean isSuccess { get; set; }
    public String errorMessage { get; set; }
}