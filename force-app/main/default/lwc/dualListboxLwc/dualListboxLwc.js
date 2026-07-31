import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DualListboxLwc extends LightningElement {

    @api label = 'Display Columns';

    @api disabled = false;

    @api options = [];

    // Fields that can NEVER be removed
    @api requiredFields = [''];

    @track selectedValues = [];

    get selectedCount() {
        return `Selected (${this.selectedValues.length}/${this.options.length})`;
    }

    get showOrdering() {
        return this.selectedValues.length > 1;
    }

    @api
    get value() {
        return this.selectedValues;
    }

    set value(values) {

        let list = values ? [...values] : [];

        // Always insert required fields first

        this.requiredFields.forEach(field => {

            if (!list.includes(field)) {
                list.unshift(field);
            }

        });

        this.selectedValues = this.sortMandatory(list);
    }

    sortMandatory(values) {

        const mandatory = [];
        const others = [];

        values.forEach(v => {

            if (this.requiredFields.includes(v)) {
                mandatory.push(v);
            } else {
                others.push(v);
            }

        });

        return [...mandatory, ...others];
    }

    handleChange(event) {

        let values = [...event.detail.value];

        // Restore mandatory fields

        this.requiredFields.forEach(field => {

            if (!values.includes(field)) {

                values.unshift(field);

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Mandatory Field',
                        message: `${field} cannot be removed.`,
                        variant: 'warning'
                    })
                );
            }

        });

        this.selectedValues = this.sortMandatory(values);

        this.fireEvent();
    }

    fireEvent() {

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: this.selectedValues
            })
        );

    }

    moveUp() {

        const listbox = this.template.querySelector('lightning-dual-listbox');

        const selected = listbox.value;

        if (selected.length !== 1) {
            return;
        }

        const field = selected[0];

        let index = this.selectedValues.indexOf(field);

        if (index <= this.requiredFields.length) {
            return;
        }

        [
            this.selectedValues[index - 1],
            this.selectedValues[index]
        ] = [
                this.selectedValues[index],
                this.selectedValues[index - 1]
            ];

        this.selectedValues = [...this.selectedValues];

        this.fireEvent();

    }

    moveDown() {

        const listbox = this.template.querySelector('lightning-dual-listbox');

        const selected = listbox.value;

        if (selected.length !== 1) {
            return;
        }

        const field = selected[0];

        let index = this.selectedValues.indexOf(field);

        if (index === this.selectedValues.length - 1) {
            return;
        }

        [
            this.selectedValues[index],
            this.selectedValues[index + 1]
        ] = [
                this.selectedValues[index + 1],
                this.selectedValues[index]
            ];

        this.selectedValues = [...this.selectedValues];

        this.fireEvent();

    }

    @api
    clear() {

        this.selectedValues = [...this.requiredFields];

        this.fireEvent();

    }

    @api
    getValue() {
        return [...this.selectedValues];
    }

}