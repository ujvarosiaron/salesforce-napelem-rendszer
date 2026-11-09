import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';

export default class OpenEmailComposer extends NavigationMixin(LightningElement) {
    @api recordId;
    @api recipientEmail;
    @api emailSubject;
    @api emailBody;

    _opened = false;

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
                        HtmlBody: this.emailBody || ''
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