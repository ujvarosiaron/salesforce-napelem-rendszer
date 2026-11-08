public with sharing class SolarQuotePdfController {
    public String formattedQuoteBody { get; set; }

    public SolarQuotePdfController() {
        Id leadId = ApexPages.currentPage().getParameters().get('id');
        if (leadId != null) {
            // Itt lekérdezheted a Lead-hez eltárolt szerkesztett szöveget, 
            // vagy átadhatod a Quote objektum mezőjéből.
            Lead l = [SELECT Formatted_Quote_Body__c FROM Lead WHERE Id = :leadId LIMIT 1];
            formattedQuoteBody = l.Formatted_Quote_Body__c;
        }
        if (String.isEmpty(formattedQuoteBody)) {
            formattedQuoteBody = 'Nincs megadott ajánlati leírás.';
        }
    }
}