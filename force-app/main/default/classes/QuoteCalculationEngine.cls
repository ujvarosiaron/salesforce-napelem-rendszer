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
            // Üzleti és adatbázis-biztonsági szűrés: Csak az azonos fázisú, 
            // teljes körűen kitöltött, árazott és valid teljesítményű inverterek jöhetnek szóba
            if (inv.Fazisszam_tipus__c != targetPhase ||
                inv.Product_Catalog__c == null ||
                inv.Product_Catalog__r == null ||
                inv.Product_Catalog__r.Brutto_egysegar__c == null ||
                inv.Nevleges_teljesitmeny_kW__c == null ||
                inv.Nevleges_teljesitmeny_kW__c <= 0) {
                continue;
            }

            // DC/AC túlméretezési arány kiszámítása a napelem összteljesítménye és az inverter kapacitása alapján
            Decimal ratio = totalArraykWp / inv.Nevleges_teljesitmeny_kW__c;

            // Üzleti szabály: Az inverter kompatibilitási sávja 1.0 és 1.2 közötti DC/AC arányt követel meg
            if (ratio >= 1.0 && ratio <= 1.2) {
                // Optimalizációs cél: Az optimális 1.1-es arányhoz legközelebb eső inverter keresése
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
        for (Accessory__c acc : accessoriesList) {
            if (acc.Product_Catalog__c != null && 
                acc.Product_Catalog__r != null && 
                acc.Product_Catalog__r.Name != null && 
                acc.Product_Catalog__r.Name.containsIgnoreCase(tetofedesTipusa) && 
                acc.Product_Catalog__r.Brutto_egysegar__c != null) {
                return acc;
            }
        }
        return null;
    }

    public static QuoteCalculationResult calculateMetrics(Decimal yearlyConsumption, String postalCode, Solar_Panel__c panel, Inverter__c inverter, Battery_Storage__c battery, Accessory__c accessory, ProductCatalog__c protBox, ProductCatalog__c cable, Integer panelCount, Map<String, ProductCatalog__c> serviceMap) {
        // Üzleti szabály: 5000 kWh feletti éves fogyasztás esetén 2 akkumulátor, egyébként 1 akkumulátor kalkulálása
        Decimal batteryCount = (yearlyConsumption > 5000) ? 2 : 1;

        // Anyag- és hardverköltségek tételes kiszámítása a darabszámok és katalógus egységárak alapján
        Decimal panelTotalCost = panelCount * panel.Product_Catalog__r.Brutto_egysegar__c;
        Decimal accessoryTotalCost = panelCount * accessory.Product_Catalog__r.Brutto_egysegar__c;
        Decimal batteryTotalCost = batteryCount * battery.Product_Catalog__r.Brutto_egysegar__c;

        // Teljes hardver- és anyagköltség aggregálása
        Decimal totalHardware = panelTotalCost + inverter.Product_Catalog__r.Brutto_egysegar__c + batteryTotalCost + accessoryTotalCost + protBox.Brutto_egysegar__c + cable.Brutto_egysegar__c;

        // Üzleti fix díjak és sávos munkadíj kalkuláció: szerelési díj panelfüggő, de minimum 200.000 Ft
        Decimal laborCost = Math.max(panelCount * 25000, 200000); 
        Decimal acElectricalCost = 180000;
        Decimal adminCost = 120000;
        Decimal logisticsCost = 45000; // Alapértelmezett logisztikai díj

        // Zónaalapú logisztikai logika az irányítószám első karaktere (régió) alapján
        if (postalCode != null && postalCode.length() > 0) {
            String prefix = postalCode.substring(0, 1);
            if (prefix == '1') logisticsCost = 35000;      // Budapest
            else if (prefix == '2') logisticsCost = 45000; // Agglomeráció
            else logisticsCost = 65000;                    // Vidéki régiók
        }

        // Szolgáltatási díjak végösszegének összesítése
        Decimal totalServices = laborCost + acElectricalCost + adminCost + logisticsCost;

        // Eredmény objektum példányosítása és a kalkulált adatok átadása a kontextusnak
        QuoteCalculationResult result = new QuoteCalculationResult();
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
        
        // Végleges bruttó összeg: a hardverek és a szolgáltatások teljes összköltsége
        result.grossTotal = totalHardware + totalServices;

        return result;
    }
}