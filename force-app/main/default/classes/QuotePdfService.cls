public with sharing class QuotePdfService {

    public class PdfRequest {
        @InvocableVariable(required=true label='Lead ID')
        public Id leadId;

        @InvocableVariable(required=true label='Címzett E-mail Cím')
        public String recipientEmail;

        @InvocableVariable(required=true label='E-mail Tárgy')
        public String emailSubject;

        @InvocableVariable(required=true label='Formázott HTML Szöveg (Szerkesztőből)')
        public String htmlBody;
    }

    public class PdfResult {
        @InvocableVariable(label='Generated ContentDocumentId')
        public Id contentDocId;
    }

    @InvocableMethod(label='Generate PDF, Save to Lead & Send Email' category='Quote Automation')
    public static List<PdfResult> generateAndSavePdf(List<PdfRequest> requests) {
        List<PdfResult> results = new List<PdfResult>();

        for (PdfRequest req : requests) {
            // 0. (Opcionális, de ajánlott) Ha a SolarQuotePdfController ezt a mezőt olvassa,
            // érdemes elmenteni a Lead-re a szerkesztett HTML-t, mielőtt a PDF lefut.
            update new Lead(Id = req.leadId, Formatted_Quote_Body__c = req.htmlBody);

            PageReference pdfPage = Page.SolarQuotePdfTemplate;
            pdfPage.getParameters().put('id', req.leadId);
            
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                pdfBlob = pdfPage.getContentAsPDF();
            }

            // 1. Fájl mentése ContentVersion-ként
            ContentVersion cv = new ContentVersion();
            cv.Title = 'Napelem_Arajanlat_' + System.now().format('yyyyMMdd_HHmm') + '.pdf';
            cv.PathOnClient = 'Napelem_Arajanlat.pdf';
            cv.VersionData = pdfBlob;
            cv.IsMajorVersion = true;
            insert cv;

            // 2. ContentDocumentId lekérdezése
            Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            // 3. Összekötés a Lead Files kapcsolódó listájával
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = contentDocId;
            cdl.LinkedEntityId = req.leadId;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;

            // 4. E-mail küldése a generált PDF csatolmánnyal és a szerkesztett HTML szöveggel
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { req.recipientEmail });
            mail.setSubject(req.emailSubject);
            mail.setHtmlBody(req.htmlBody);
            mail.setEntityAttachments(new List<Id>{ contentDocId });

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

            // Eredmény visszaadása a Flow-nak
            PdfResult res = new PdfResult();
            res.contentDocId = contentDocId;
            results.add(res);
        }
        return results;
    }
}