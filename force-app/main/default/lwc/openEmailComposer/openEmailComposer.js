import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

export default class OpenEmailComposer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recipientEmail;
    @api emailSubject;
    @api emailBody;

    _opened = false;

    // Az HtmlBody HTML-t vár: a sima szövegben lévő sortöréseket (\n) a HTML nem jeleníti meg.
    // Ha a szöveg már tartalmaz HTML blokk-tageket, békén hagyjuk, különben bekezdésekre bontjuk.
    formatBody(raw) {
        let text = String(raw || '');
        if (!text.trim()) {
            return '';
        }

        // A Flow/prompt néha szó szerinti "\n" jeleket ad a valódi sortörés helyett
        text = text.replace(/\\r\\n|\\n/g, '\n').replace(/\r\n/g, '\n');

        const hasHtml = /<\/?(p|br|div|h[1-6]|ul|ol|li|table)\b/i.test(text);
        if (hasHtml) {
            // Ha van HTML, de a sorok közti sima sortörések is megmaradtak, azokat <br>-re cseréljük
            // csak a tagen kívüli szövegben nem tudjuk biztosan, ezért csak a dupla sortöréseket kezeljük
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

    openComposer() {
        try {
            const pageRef = {
                type: 'standard__quickAction',
                attributes: {
                    apiName: 'Global.SendEmail'
                },
                state: {
                    // A kontextus rekord (Lead) itt kell, nem a defaultFieldValues-ban
                    recordId: this.recordId,
                    defaultFieldValues: encodeDefaultFieldValues({
                        ToAddress: this.recipientEmail || '',
                        Subject: this.emailSubject || '',
                        HtmlBody: this.formatBody(this.emailBody)
                        // RelatedToId szándékosan nincs: Lead kontextusnál a Lead a címzett (WhoId),
                        // a Lead ID RelatedToId-ként hibát okozhat.
                    })
                }
            };

            this[NavigationMixin.Navigate](pageRef);
            this._opened = true;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('Hiba az e-mail szerkesztő megnyitásakor: ', error);
        }
    }

    // A gomb kézi indításhoz (ha a Flow lábléc el van rejtve)
    handleOpenComposer() {
        this.openComposer();
    }

    // A Flow "Tovább" / "Befejezés" gombja is ezt hívja: így a gombnyomásra is megnyílik
    @api
    validate() {
        if (!this._opened) {
            this.openComposer();
        }
        return { isValid: true };
    }
}