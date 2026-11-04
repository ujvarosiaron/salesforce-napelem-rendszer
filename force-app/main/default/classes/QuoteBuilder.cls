public class QuoteBuilder {

public static Quote__c buildQuote(Id leadId, Decimal grossTotal) {
        // Üzleti szabály: Új ajánlat létrehozása alapértelmezett 'Piszkozat' státusszal, 
        // a kalkulált bruttó végösszeggel és egy 30 napos standard érvényességi ablakkal
        return new Quote__c(
            Lead__c = leadId,
            Status__c = 'Piszkozat',
            Brutto_vegosszeg__c = grossTotal,
            Ervenyesseg_datuma__c = System.today().addDays(30)
        );
    }

    public static void collectQuoteItems(Id quoteId, QuoteCalculationResult ctx, List<QuoteItem__c> items) {
        
        // Napelem panelek tételének felvétele: a mennyiség a kiszámolt panel darabszám 
        if (ctx.panel != null && ctx.panel.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.panel.Product_Catalog__c,
                Mennyiseg__c = ctx.panelCount,
                Egysegar__c = ctx.panel.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        
        // Inverter tétel felvétele: darabszáma fixen 1 db az optimalizációs motor kiválasztása alapján
        if (ctx.inverter != null && ctx.inverter.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.inverter.Product_Catalog__c,
                Mennyiseg__c = 1,
                Egysegar__c = ctx.inverter.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        
        // Akkumulátor tétel felvétele: a darabszám a fogyasztásfüggő logikát követi (1 vagy 2 db)
        if (ctx.battery != null && ctx.battery.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.battery.Product_Catalog__c,
                Mennyiseg__c = ctx.batteryCount,
                Egysegar__c = ctx.battery.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        
        // Tartószerkezet (tetőfedés-specifikus kiegészítő) tétel felvétele: mennyisége megegyezik a panelek számával
        if (ctx.accessory != null && ctx.accessory.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.accessory.Product_Catalog__c,
                Mennyiseg__c = ctx.panelCount, //Ugyanannyi tartószerkezet kell, mint panel
                Egysegar__c = ctx.accessory.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        
        // DC védelmi doboz (biztonsági hardverelem) felvétele: rendszerenként 1 db fix mennyiséggel
        if (ctx.protBox != null && ctx.protBox.Id != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.protBox.Id,
                Mennyiseg__c = 1,
                Egysegar__c = ctx.protBox.Brutto_egysegar__c
            ));
        }
        
        // Szolár kábelezés szett felvétele: teljes rendszerszintű egységként 1 db
        if (ctx.cable != null && ctx.cable.Id != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.cable.Id,
                Mennyiseg__c = 1,
                Egysegar__c = ctx.cable.Brutto_egysegar__c
            ));
        }
    }
}