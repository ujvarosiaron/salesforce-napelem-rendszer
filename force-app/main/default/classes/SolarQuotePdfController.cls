
public with sharing class SolarQuotePdfController {

    public String formattedQuoteBody { get; private set; }

    public SolarQuotePdfController() {

        formattedQuoteBody = '';

        String leadIdParam =
            ApexPages.currentPage().getParameters().get('id');

        if (String.isNotBlank(leadIdParam)) {

            try {

                Id leadId = (Id) leadIdParam;

                List<Lead> leads = [
                    SELECT Id, Formatted_Quote_Body__c
                    FROM Lead
                    WHERE Id = :leadId
                    LIMIT 1
                ];

                if (!leads.isEmpty()) {
                    formattedQuoteBody =
                        leads[0].Formatted_Quote_Body__c;
                }

            } catch (Exception e) {

                formattedQuoteBody = '';
            }
        }

        if (String.isBlank(formattedQuoteBody)) {
            formattedQuoteBody =
                'Nincs megadott ajánlati leírás.';
        }
    }
}
