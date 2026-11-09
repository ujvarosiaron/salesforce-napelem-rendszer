public with sharing class QuotePdfService {

    public class PdfRequest {
        @InvocableVariable(required=true label='Lead ID')
        public Id leadId;
    }

    public class PdfResult {
        @InvocableVariable(label='Generated ContentDocumentId')
        public Id contentDocId;
    }

    @InvocableMethod(label='Generate PDF & Save to Lead' category='Quote Automation')
    public static List<PdfResult> generateAndSavePdf(List<PdfRequest> requests) {
        List<PdfResult> results = new List<PdfResult>();

        for (PdfRequest req : requests) {
            // 1. Friss, szerkesztett HTML kiolvasása a Lead adatbázisból
            Lead targetLead = [SELECT Formatted_Quote_Body__c, Email FROM Lead WHERE Id = :req.leadId LIMIT 1];

            PageReference pdfPage = Page.SolarQuotePdfTemplate;
            pdfPage.getParameters().put('id', req.leadId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // 2. Fájl mentése ContentVersion-ként
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Napelem_Arajanlat_' + System.now().format('yyyyMMdd_HHmm') + '.pdf';
            cv.PathOnClient = 'Napelem_Arajanlat.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;
            insert cv;

            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            // 3. Összekötés a Lead Files kapcsolódó listájával
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = req.leadId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            // 4. Eredmény visszaadása a Flow-nak (hogy a Flow csatolni tudja a fájlt)
            PdfResult res = new PdfResult();
            res.contentDocId = contentDocId;
            results.add(res);
        }
        return results;
    }
}