import { LightningElement, api } from 'lwc';

export default class NotificationOverlay extends LightningElement {

    @api isOpen = false;

    @api title = '';

    @api subtitle = '';

    @api message = '';

    @api variant = 'info';

    @api errors = [];

    copied = false;

    // -------------------------------
    // Public API
    // -------------------------------

    @api
    open(config = {}) {

        this.title = config.title || 'Notification';
        this.subtitle = config.subtitle || '';
        this.message = config.message || '';
        this.variant = config.variant || 'info';
        this.errors = config.errors || [];

        this.isOpen = true;
    }

    @api
    close() {

        this.isOpen = false;

        this.dispatchEvent(
            new CustomEvent('close')
        );
    }

    // -------------------------------
    // Computed Properties
    // -------------------------------

    get hasErrors() {
        return this.errors && this.errors.length > 0;
    }

    get iconName() {

        switch (this.variant) {

            case 'success':
                return 'utility:success';

            case 'error':
                return 'utility:error';

            case 'warning':
                return 'utility:warning';

            default:
                return 'utility:info';
        }
    }

    get headerClass() {

        let css = 'header ';

        switch (this.variant) {

            case 'success':
                css += 'success';
                break;

            case 'error':
                css += 'error';
                break;

            case 'warning':
                css += 'warning';
                break;

            default:
                css += 'info';
        }

        return css;
    }

    // -------------------------------
    // Copy Details
    // -------------------------------

    async copyDetails() {

        let text = '';

        if (this.title) {
            text += this.title + '\n\n';
        }

        if (this.message) {
            text += this.message + '\n\n';
        }

        if (this.hasErrors) {

            this.errors.forEach(err => {

                text +=
                    'Opportunity : ' +
                    err.opportunity +
                    '\n';

                text +=
                    'Reason      : ' +
                    err.reason +
                    '\n\n';

            });

        }

        try {

            await navigator.clipboard.writeText(text);

            this.copied = true;

            setTimeout(() => {
                this.copied = false;
            }, 1500);

        } catch (e) {

            console.error(e);

        }

    }

    // -------------------------------
    // Close
    // -------------------------------

    handleBackdropClick() {

        this.close();

    }

    // -------------------------------
    // Utility
    // -------------------------------

    /**
     * Parse Apex Error Message
     *
     * Example:
     *
     * Opportunity: Opp -10009
     * Reason: Parent Opportunity Required
     */
    @api
    parseErrors(message) {

        this.errors = [];

        if (!message) {
            return;
        }

        const regex =
            /Opportunity:\s*(.*?)\s*Reason:\s*(.*?)(?=Opportunity:|$)/gs;

        let match;

        let index = 1;

        while ((match = regex.exec(message)) !== null) {

            this.errors.push({

                id: index++,

                opportunity: match[1].trim(),

                reason: match[2].trim()

            });

        }

        // Remove parsed text from summary

        if (this.errors.length) {

            this.message =
                message.substring(
                    0,
                    message.indexOf('Opportunity:')
                ).trim();

        } else {

            this.message = message;

        }

    }

}