public class QuoteCalculationEngine {

    public static String validateLeadAndGetPhase(Lead l) {
        if (l.Fazisszam__c == 'Egyfázisú / Bővítendő') return 'Egyfázisú (1f)';
        if (l.Fazisszam__c == 'Háromfázisú (szabványos)') return 'Háromfázisú (3f) Hibrid';
        return null;
    }

    public static Inverter__c findInverter(List<Inverter__c> invertersList, String targetPhase, Decimal totalArraykWp) {
        Inverter__c bestMatch = null;
        Decimal bestDifference = null;

        for (Inverter__c inv : invertersList) {
            if (inv.Fazisszam_tipus__c != targetPhase ||
                inv.Product_Catalog__c == null ||
                inv.Product_Catalog__r == null ||
                inv.Product_Catalog__r.Brutto_egysegar__c == null ||
                inv.Nevleges_teljesitmeny_kW__c == null ||
                inv.Nevleges_teljesitmeny_kW__c <= 0) {
                continue;
            }

            Decimal ratio = totalArraykWp / inv.Nevleges_teljesitmeny_kW__c;

            if (ratio >= 0.7 && ratio <= 1.2) {
                Decimal difference = (ratio - 1.1).abs();

                if (bestMatch == null || difference < bestDifference) {
                    bestMatch = inv;
                    bestDifference = difference;
                }
            }
        }
        return bestMatch;
    }

    public static Accessory__c findAccessory(List<Accessory__c> accessoriesList, String tetofedesTipusa) {
        if (tetofedesTipusa == null || accessoriesList == null || accessoriesList.isEmpty()) return null;

        String searchKeyword = '';
        String lowerType = tetofedesTipusa.toLowerCase();

        if (lowerType.contains('cserép')) {
            searchKeyword = 'cseréptetős szett';
        } else if (lowerType.contains('korcolt')) {
            searchKeyword = 'korcolt lemez szett';
        } else if (lowerType.contains('pala') || lowerType.contains('trapéz')) {
            searchKeyword = 'trapézlemez szett';
        } else {
            searchKeyword = 'trapézlemez szett';
        }

        for (Accessory__c acc : accessoriesList) {
            if (acc.Product_Catalog__c != null && 
                acc.Product_Catalog__r != null && 
                acc.Product_Catalog__r.Name != null) {
                
                String catNameLower = acc.Product_Catalog__r.Name.toLowerCase();
                if (catNameLower.contains(searchKeyword) && acc.Product_Catalog__r.Brutto_egysegar__c != null) {
                    return acc;
                }
            }
        }
        return accessoriesList[0];
    }

    public static QuoteCalculationResult calculateMetrics(Decimal yearlyConsumption, String postalCode, Solar_Panel__c panel, Inverter__c inverter, Battery_Storage__c battery, Accessory__c accessory, ProductCatalog__c protBox, ProductCatalog__c cable, Integer panelCount, Map<String, ProductCatalog__c> serviceMap) {
        QuoteCalculationResult result = new QuoteCalculationResult();

        if (panel == null || inverter == null || battery == null || accessory == null || protBox == null || cable == null) {
            result.isSuccess = false;
            result.errorMessage = 'Hiányzó rendszerelem vagy hardverkomponens a katalógusban. Kérlek, ellenőrizd a törzsadatokat!';
            return result;
        }

        if (yearlyConsumption == null || yearlyConsumption <= 0) {
            result.isSuccess = false;
            result.errorMessage = 'A becsült éves fogyasztás nem lehet nulla vagy negatív.';
            return result;
        }

        Decimal batteryCount = (yearlyConsumption > 5000) ? 2 : 1;

        Decimal panelTotalCost = panelCount * panel.Product_Catalog__r.Brutto_egysegar__c;
        Decimal accessoryTotalCost = panelCount * accessory.Product_Catalog__r.Brutto_egysegar__c;
        Decimal batteryTotalCost = batteryCount * battery.Product_Catalog__r.Brutto_egysegar__c;

        Decimal totalHardware = panelTotalCost + inverter.Product_Catalog__r.Brutto_egysegar__c + batteryTotalCost + accessoryTotalCost + protBox.Brutto_egysegar__c + cable.Brutto_egysegar__c;

        Decimal laborCost = Math.max(panelCount * 25000, 200000); 
        Decimal acElectricalCost = 180000;
        Decimal adminCost = 120000;
        Decimal logisticsCost = 45000;

        if (postalCode != null && postalCode.length() > 0) {
            String prefix = postalCode.substring(0, 1);
            if (prefix == '1') logisticsCost = 35000;      
            else if (prefix == '2') logisticsCost = 45000; 
            else logisticsCost = 65000;                    
        }

        Decimal totalServices = laborCost + acElectricalCost + adminCost + logisticsCost;
        Decimal grossTotal = totalHardware + totalServices;

        // Szakdolgozat 5.4.4. szerinti számítások
        Decimal panelkWp = panel.Nevleges_teljesitmeny__c / 1000.0;
        Decimal yearlyGeneration = panelCount * panelkWp * 1050; // kWh/év
        Decimal yearlySavings = yearlyGeneration * 70; // 70 Ft/kWh
        Decimal netInvestment = grossTotal; // Ha nincs külön pályázati támogatás mező lekérdezve, a bruttó összeg a nettó
        Decimal paybackYears = yearlySavings > 0 ? (netInvestment / yearlySavings).setScale(2) : 0;

        result.isSuccess = true;
        result.panel = panel;
        result.panelCount = panelCount;
        result.panelTotalCost = panelTotalCost;
        result.inverter = inverter;
        result.battery = battery;
        result.batteryCount = Integer.valueOf(batteryCount);
        result.batteryTotalCost = batteryTotalCost;
        result.accessory = accessory;
        result.accessoryTotalCost = accessoryTotalCost;
        result.protBox = protBox;
        result.cable = cable;
        result.laborCost = laborCost;
        result.acElectricalCost = acElectricalCost;
        result.adminCost = adminCost;
        result.logisticsCost = logisticsCost;
        result.serviceMap = serviceMap;
        result.grossTotal = grossTotal;
        result.yearlyGeneration = yearlyGeneration;
        result.yearlySavings = yearlySavings;
        result.netInvestment = netInvestment;
        result.paybackYears = paybackYears;

        return result;
    }
}