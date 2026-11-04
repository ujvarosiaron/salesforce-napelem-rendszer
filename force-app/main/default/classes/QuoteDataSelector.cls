public with sharing class QuoteDataSelector {

    // Lekérdezi a kalkulációhoz szükséges Lead mezőket (fogyasztás, fázisszám, tetőfedés, irányítószám), 
    // biztosítva, hogy csak a releváns adatok kerüljenek a memóriába.
    public static Map<Id, Lead> getLeads(Set<Id> leadIds) {
        return new Map<Id, Lead>([
            SELECT Id, Havi_fogyasztas__c, Fazisszam__c, Tetofedes_tipusa__c, 
                   Finanszirozasi_statusz__c, PostalCode, Ellenorzest_igenyel__c 
            FROM Lead 
            WHERE Id IN :leadIds
        ]);
    }

    // A metódus lekérdezi azokat a leadeket, amelyekhez már tartozik érvényes ajánlat (Piszkozat, Elküldve, Elfogadva), 
    // támogatva az iteratív újragenerálást és a felülírási folyamatot.
    public static Set<Id> getLeadsWithExistingQuotes(Set<Id> leadIds) {
        Set<Id> existing = new Set<Id>();
        for (Quote__c q : [
            SELECT Lead__c 
            FROM Quote__c 
            WHERE Lead__c IN :leadIds 
            AND Status__c IN ('Piszkozat', 'Elküldve', 'Elfogadva')
        ]) {
            existing.add(q.Lead__c);
        }
        return existing;
    }

    // Betölti a katalógusból az elsődleges napelem-panel komponenst.
    public static List<Solar_Panel__c> getPanels() {
        return [
            SELECT Id, Nevleges_teljesitmeny__c, Product_Catalog__c, 
                   Product_Catalog__r.Name, Product_Catalog__r.Brutto_egysegar__c 
            FROM Solar_Panel__c 
            ORDER BY CreatedDate ASC 
            LIMIT 1
        ];
    }

    // Betölti a katalógusból az akkumulátoros energiatároló komponenst.
    public static List<Battery_Storage__c> getBatteries() {
        return [
            SELECT Id, Kapacitas_kWh__c, Product_Catalog__c, 
                   Product_Catalog__r.Name, Product_Catalog__r.Brutto_egysegar__c 
            FROM Battery_Storage__c 
            ORDER BY CreatedDate ASC 
            LIMIT 1
        ];
    }

    // Betölti a tartószerkezettel kapcsolatos kiegészítő elemeket.
    public static List<Accessory__c> getAccessories() {
        return [
            SELECT Id, Accessory_Type__c, Product_Catalog__c, 
                   Product_Catalog__r.Name, Product_Catalog__r.Brutto_egysegar__c 
            FROM Accessory__c 
            WHERE Accessory_Type__c = 'Tartószerkezet'
        ];
    }

    // Betölti az összes elérhető inverter opciót a kompatibilitási vizsgálathoz.
    public static List<Inverter__c> getInverters() {
        return [
            SELECT Id, Fazisszam_tipus__c, Nevleges_teljesitmeny_kW__c, 
                   Product_Catalog__c, Product_Catalog__r.Name, Product_Catalog__r.Brutto_egysegar__c 
            FROM Inverter__c
        ];
    }

    // Dinamikusan lekérdezi a termékkatalógus elemeit a megadott komponenscsoport alapján 
    // (a Cikkszam__c mező neve javítva lett ékezetmentesre).
    public static List<ProductCatalog__c> getProductCatalogsByGroup(String groupName) {
        return [
            SELECT Id, Name, Brutto_egysegar__c, Komponenscsoport__c, Cikkszam__c 
            FROM ProductCatalog__c 
            WHERE Komponenscsoport__c = :groupName
        ];
    }
}