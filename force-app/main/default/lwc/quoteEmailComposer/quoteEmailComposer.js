import { LightningElement, api } from 'lwc';
import { FlowNavigationFinishEvent } from 'lightning/flowSupport';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendQuoteEmail from '@salesforce/apex/QuoteEmailService.sendQuoteEmail';
import getAttachmentName from '@salesforce/apex/QuoteEmailService.getAttachmentName';

export default class QuoteEmailComposer extends LightningElement {
    @api recordId;
    @api recipientEmail;
    @api emailSubject;
    @api emailBody;
    @api contentDocumentId;
    @api availableActions = [];

    toAddress = '';
    subject = '';
    body = '';
    attachmentName = '';
    errorMessage = '';
    isSending = false;
    sent = false;

    connectedCallback() {
        this.toAddress = this.recipientEmail || '';
        this.subject = this.emailSubject || '';
        this.body = this.formatBody(this.emailBody);

        if (this.contentDocumentId) {
            getAttachmentName({ contentDocumentId: this.contentDocumentId })
                .then((name) => {
                    this.attachmentName = name || '';
                })
                .catch(() => {
                    this.attachmentName = '';
                });
        }
    }

    // Sima szöveg esetén a sortöréseket HTML bekezdésekké alakítja
    formatBody(raw) {
        let text = String(raw || '');
        if (!text.trim()) {
            return '';
        }

        text = text.replace(/\\r\\n|\\n/g, '\n').replace(/\r\n/g, '\n');

        if (/<\/?(p|br|div|h[1-6]|ul|ol|li|table)\b/i.test(text)) {
            return text.replace(/\n{2,}/g, '\n');
        }

        const escaped = text
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');

        return escaped
            .split(/\n{2,}/)
            .map((paragraph) => '<p>' + paragraph.trim().replace(/\n/g, '<br>') + '</p>')
            .join('');
    }

    handleToChange(event) {
        this.toAddress = event.target.value;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handleBodyChange(event) {
        this.body = event.detail.value;
    }

    handleSend() {
        this.errorMessage = '';

        if (!this.toAddress || !this.toAddress.trim()) {
            this.errorMessage = 'Adj meg címzettet.';
            return;
        }
        if (!this.subject || !this.subject.trim()) {
            this.errorMessage = 'Adj meg tárgyat.';
            return;
        }

        this.isSending = true;

        sendQuoteEmail({
            leadId: this.recordId,
            toAddress: this.toAddress,
            subject: this.subject,
            htmlBody: this.body,
            contentDocumentId: this.contentDocumentId
        })
            .then(() => {
                this.sent = true;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Elküldve',
                        message: 'Az e-mail elment a címzettnek.',
                        variant: 'success'
                    })
                );

                // A Flow befejezése, ha van ilyen lehetőség ezen a képernyőn
                if (this.availableActions && this.availableActions.includes('FINISH')) {
                    this.dispatchEvent(new FlowNavigationFinishEvent());
                }
            })
            .catch((error) => {
                this.errorMessage =
                    (error && error.body && error.body.message) ||
                    (error && error.message) ||
                    'Ismeretlen hiba történt a küldés közben.';
            })
            .finally(() => {
                this.isSending = false;
            });
    }

    // A Flow "Tovább/Befejezés" gombja nem küld levelet: csak a küldés gomb
    @api
    validate() {
        if (!this.sent) {
            return {
                isValid: false,
                errorMessage: 'Az e-mail még nincs elküldve. Használd az "E-mail küldése" gombot.'
            };
        }
        return { isValid: true };
    }
}