public class QuoteBuilder {

    public static Quote__c buildQuote(Id leadId, QuoteCalculationResult ctx) {
        String itemsSummary = 'A KISZÁMOLT MŰSZAKI ÉS PÉNZÜGYI TÉTELEK:\n';
        
        if (ctx.panel != null) {
            itemsSummary += '- Napelem panel: ' + ctx.panelCount + ' db ' + 
                            (ctx.panel.Product_Catalog__r != null ? ctx.panel.Product_Catalog__r.Name : '') + 
                            ' (Összesen: ' + ctx.panelTotalCost + ' Ft)\n';
        }
        if (ctx.inverter != null) {
            itemsSummary += '- Inverter: 1 db ' + 
                    (ctx.inverter.Product_Catalog__r != null ? ctx.inverter.Product_Catalog__r.Name : '') + 
                    ' (Összesen: ' + (ctx.inverter.Product_Catalog__r.Brutto_egysegar__c != null ? ctx.inverter.Product_Catalog__r.Brutto_egysegar__c : 0) + ' Ft)\n';
}
        if (ctx.battery != null) {
            itemsSummary += '- Energiatároló akkumulátor: ' + ctx.batteryCount + ' db ' + 
                            (ctx.battery.Product_Catalog__r != null ? ctx.battery.Product_Catalog__r.Name : '') + 
                            ' (Összesen: ' + ctx.batteryTotalCost + ' Ft)\n';
        }
        if (ctx.accessory != null) {
            itemsSummary += '- Tartószerkezet szett: ' + ctx.panelCount + ' db (Összesen: ' + ctx.accessoryTotalCost + ' Ft)\n';
        }
        itemsSummary += '- DC védelmi doboz: 1 szett (' + (ctx.protBox != null ? ctx.protBox.Brutto_egysegar__c : 0) + ' Ft)\n';
        itemsSummary += '- Szolár kábelezés: 1 szett (' + (ctx.cable != null ? ctx.cable.Brutto_egysegar__c : 0) + ' Ft)\n';
        itemsSummary += '- Telepítési munkadíj: ' + ctx.laborCost + ' Ft\n';
        itemsSummary += '- AC villanyszerelés: ' + ctx.acElectricalCost + ' Ft\n';
        itemsSummary += '- Engedélyezés és tervezés: ' + ctx.adminCost + ' Ft\n';
        itemsSummary += '- Logisztikai díj: ' + ctx.logisticsCost + ' Ft\n';
        itemsSummary += '- KALKULÁLT BRUTTÓ VÉGÖSSZEG: ' + ctx.grossTotal + ' Ft\n';
        
        // Szakdolgozat szerinti számított mutatók dinamikus kiírása a meglévő motor adatai alapján
        Decimal panelkWp = (ctx.panel != null && ctx.panel.Nevleges_teljesitmeny__c != null) ? ctx.panel.Nevleges_teljesitmeny__c / 1000.0 : 0.44;
        Decimal gen = ctx.panelCount * panelkWp * 1050;
        Decimal sav = gen * 70;
        Decimal netInv = ctx.grossTotal;
        Decimal payback = sav > 0 ? (netInv / sav).setScale(2) : 0;

        itemsSummary += '- Várható éves termelés: ' + gen.setScale(0) + ' kWh/év\n';
        itemsSummary += '- Várható éves megtakarítás: ' + sav.setScale(0) + ' Ft/év\n';
        itemsSummary += '- Nettó beruházási költség: ' + netInv.setScale(0) + ' Ft\n';
        itemsSummary += '- Bruttó megtérülési idő: ' + payback + ' év';

        return new Quote__c(
            Lead__c = leadId,
            Status__c = 'Piszkozat',
            Brutto_vegosszeg__c = ctx.grossTotal,
            Kalkulalt_Tetelek_Osszegzo__c = itemsSummary,
            Ervenyesseg_datuma__c = System.today().addDays(30)
        );
    }

    public static void collectQuoteItems(Id quoteId, QuoteCalculationResult ctx, List<QuoteItem__c> items) {
        if (ctx.panel != null && ctx.panel.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.panel.Product_Catalog__c,
                Mennyiseg__c = ctx.panelCount,
                Egysegar__c = ctx.panel.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        if (ctx.inverter != null && ctx.inverter.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.inverter.Product_Catalog__c,
                Mennyiseg__c = 1,
                Egysegar__c = ctx.inverter.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        if (ctx.battery != null && ctx.battery.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.battery.Product_Catalog__c,
                Mennyiseg__c = ctx.batteryCount,
                Egysegar__c = ctx.battery.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        if (ctx.accessory != null && ctx.accessory.Product_Catalog__c != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.accessory.Product_Catalog__c,
                Mennyiseg__c = ctx.panelCount,
                Egysegar__c = ctx.accessory.Product_Catalog__r.Brutto_egysegar__c
            ));
        }
        if (ctx.protBox != null && ctx.protBox.Id != null) {
            items.add(new QuoteItem__c(
                Quote__c = quoteId,
                Product_Catalog__c = ctx.protBox.Id,
                Mennyiseg__c = 1,
                Egysegar__c = ctx.protBox.Brutto_egysegar__c
            ));
        }
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