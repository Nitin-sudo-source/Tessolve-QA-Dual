import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ColumnManager extends LightningElement {

    //===========================
    // PUBLIC API
    //===========================

    @api title = 'Manage Columns';

    @api
    set columns(value) {
        this._columns = Array.isArray(value) ? value : [];
    }

    get columns() {
        return this._columns || [];
    }

    @api
    set lockedValues(value) {
        this._lockedValues = Array.isArray(value) ? value : [];
    }

    get lockedValues() {
        return this._lockedValues || [];
    }

    @track searchKey = '';

    @track _selectedValues = [];

    originalValues = [];

    //===========================
    // Selected Values
    //===========================

    @api
    get selectedValues() {
        return this._selectedValues;
    }

    set selectedValues(value) {

        this._selectedValues = value ? [...value] : [];

        this.originalValues = [...this._selectedValues];

    }

    //===========================
    // Counter
    //===========================

    get selectedCount() {

        return `${this._selectedValues.length} of ${this.columns.length}`;

    }

    //===========================
    // Available Fields
    //===========================

    get availableColumns() {

        const search = (this.searchKey || '').toLowerCase();

        return this.columns.filter(col => {

            const notSelected = !this._selectedValues.includes(col.value);

            const matchesSearch =
                col.label.toLowerCase().includes(search) ||
                (col.value || '').toLowerCase().includes(search);

            return notSelected && matchesSearch;

        });

    }

    //===========================
    // Selected Fields
    //===========================

    // getRowClass(col) {

    //     let css = 'row selected';

    //     if (this.lockedValues.includes(col.value)) {

    //         css += ' locked';

    //     } else {

    //         css += ' draggable';

    //     }

    //     if (this.dragValue === col.value) {

    //         css += ' dragging';

    //     }

    //     return css;

    // }

    getRowClass(col) {
        // alert('this.selectedColumnValue: '+this.selectedColumnValue);
        // alert('col.value: '+col.value);

        let css = 'row';
        if (this.displayedSelected === undefined) {
            css += '';
        }

        if (this.displayedSelected === col.value) {
            css += ' selected';
        }

        if (this.lockedValues.includes(col.value)) {
            css += ' locked';
        } else {
            css += ' draggable';
        }

        if (this.dragValue === col.value) {
            css += ' dragging';
        }

        return css;
    }

    get selectedColumns() {
        try {
            return this._selectedValues
                .map(value => {
                    const col = this.columns.find(c => c.value === value);

                    if (!col) {
                        return null;
                    }

                    return {
                        ...col,
                        locked: this.lockedValues.includes(value),
                        draggable: !this.lockedValues.includes(value),
                        cssClass: this.getRowClass(col)
                    };
                })
                .filter(Boolean);
        } catch (e) {
            console.error('selectedColumns Error', e);
            return [];
        }
    }

    //===========================
    // Search
    //===========================

    handleSearch(event) {

        this.searchKey = event.target.value;

    }

    //===========================
    // Add Column
    //===========================

    handleAvailableSelect(event) {
        this.availableSelected = event.currentTarget.dataset.value;
    }

    handleDisplayedSelect(event) {
        this.displayedSelected = event.currentTarget.dataset.value;
    }

    moveAvailableUp() {

        if (!this.availableSelected) return;

        const list = [...this.availableColumns];

        const index = list.findIndex(
            c => c.value === this.availableSelected
        );

        if (index <= 0) return;

        [list[index - 1], list[index]] =
            [list[index], list[index - 1]];

        this.columns = [
            ...list,
            ...this.selectedColumns
        ];
    }

    moveAvailableDown() {

        if (!this.availableSelected) return;

        const list = [...this.availableColumns];

        const index = list.findIndex(
            c => c.value === this.availableSelected
        );

        if (index === -1 || index === list.length - 1) return;

        [list[index], list[index + 1]] =
            [list[index + 1], list[index]];

        this.columns = [
            ...list,
            ...this.selectedColumns
        ];
    }

    moveSelectedUp() {

        if (!this.displayedSelected) return;

        const index =
            this._selectedValues.indexOf(this.displayedSelected);

        if (index <= 0) return;

        const values = [...this._selectedValues];

        [values[index - 1], values[index]] =
            [values[index], values[index - 1]];

        this._selectedValues = values;

        this.fireChange();
    }

    moveSelectedDown() {

        if (!this.displayedSelected) return;

        const index =
            this._selectedValues.indexOf(this.displayedSelected);

        if (
            index === -1 ||
            index === this._selectedValues.length - 1
        ) {
            return;
        }

        const values = [...this._selectedValues];

        [values[index], values[index + 1]] =
            [values[index + 1], values[index]];

        this._selectedValues = values;

        this.fireChange();
    }

    // handleAdd(event) {

    //     const value = event.currentTarget.dataset.value;
    //     //alert('value: ' + value);

    //     if (!this._selectedValues.includes(value)) {

    //         this._selectedValues = [

    //             ...this._selectedValues,

    //             value

    //         ];

    //         this.fireChange();
    //         // requestAnimationFrame(() => {
    //         //     this.dragValue = null;
    //         // });

    //     }

    // }
    handleAdd(event) {

        const value = event.currentTarget.dataset.value;

        if (this._selectedValues.includes(value)) {
            return;
        }

        // Maximum 15 columns
        if (this._selectedValues.length >= 20) {
            this.showToast(
                'Maximum Columns Reached',
                'You can display a maximum of 20 columns at a time. Remove a column before adding another.',
                'warning'
            );
            return;
        }

        this._selectedValues = [
            ...this._selectedValues,
            value
        ];

        this.fireChange();
    }
    //===========================
    // Remove Column
    //===========================

    handleRemove(event) {
        try {
            const value = event.currentTarget?.dataset?.value;
            //alert('value: ' + value);

            if (!value) {
                throw new Error('Unable to identify the selected field.');
            }

            if (this.lockedValues.includes(value)) {
                this.showToast(
                    'Field Locked',
                    'This field is mandatory and cannot be removed.',
                    'warning'
                );
                return;
            }

            this._selectedValues = this._selectedValues.filter(v => v !== value);

            this.fireChange();

            requestAnimationFrame(() => {
                this.dragValue = null;
            });

        } catch (error) {
            console.error('handleRemove Error:', error);

            this.showToast(
                'Unexpected Error',
                error?.message ||
                'Something went wrong while removing the field. Please try again.',
                'error'
            );
        }
    }

    //===========================
    // Reset
    //===========================

    handleReset() {

        this._selectedValues = [...this.originalValues];

        this.fireChange();
        requestAnimationFrame(() => {
            this.dragValue = null;
        });

    }

    //===========================
    // Cancel
    //===========================

    handleCancel() {

        this._selectedValues = [...this.originalValues];

        this.fireChange();
        requestAnimationFrame(() => {
            this.dragValue = null;
        });

    }

    //===========================
    // Save
    //===========================



    handleSave() {
        try {
            console.log('Selected Values:', JSON.stringify(this._selectedValues));

            this.dispatchEvent(
                new CustomEvent('save', {
                    detail: [...(this._selectedValues || [])]
                })
            );

        } catch (error) {
            console.error('handleSave Error:', error);

            this.showToast?.(
                'Error',
                error?.message || 'Unable to save the selected fields.',
                'error'
            );
        }
    }

    //===========================
    // Public Methods
    //===========================

    @api

    getValue() {

        return [...this._selectedValues];

    }

    @api

    setValue(values) {

        this._selectedValues = [...values];

        this.originalValues = [...values];

    }

    @api

    clear() {

        this._selectedValues =
            [...this.lockedValues];

        this.fireChange();
        requestAnimationFrame(() => {
            this.dragValue = null;
        });

    }

    //===========================
    // Fire Event
    //===========================

    dragIndex = null;

    dragValue = null;

    dropIndex = null;

    fireChange() {

        this.dispatchEvent(
            new CustomEvent('valuechange', {
                detail: [...this._selectedValues]
            })
        );

    }

    // ===============================
    // Drag Start
    // ===============================

    handleDragStart(event) {

        this.dragIndex = Number(event.currentTarget.dataset.index);
        this.dragValue = event.currentTarget.dataset.value;

        event.dataTransfer.effectAllowed = 'move';

        event.currentTarget.classList.add('dragging');

    }

    // ===============================
    // Drag Over
    // ===============================

    handleDragOver(event) {

        event.preventDefault();

        event.dataTransfer.dropEffect = 'move';

    }

    @track availableSelected = undefined;
    @track displayedSelected = undefined;

    // ===============================
    // Drop
    // ===============================

    handleDrop(event) {

        event.preventDefault();

        const dropValue = event.currentTarget.dataset.value;

        if (!dropValue || this.dragValue === dropValue) {
            return;
        }

        let values = [...this._selectedValues];

        const dragIndex = values.indexOf(this.dragValue);
        const targetIndex = values.indexOf(dropValue);

        if (dragIndex === -1 || targetIndex === -1) {
            return;
        }

        const moving = values.splice(dragIndex, 1)[0];

        values.splice(targetIndex, 0, moving);

        const locked = [];
        const others = [];

        values.forEach(v => {

            if (this.lockedValues.includes(v)) {
                locked.push(v);
            } else {
                others.push(v);
            }

        });

        this._selectedValues = [...locked, ...others];

        this.fireChange();
        requestAnimationFrame(() => {
            this.dragValue = null;
        });

    }

    // ===============================
    // Drag End
    // ===============================

    handleDragEnd() {

        this.dragIndex = null;
        this.dragValue = null;

        this.template.querySelectorAll('.dragging,.dropTarget')
            .forEach(el => {

                el.classList.remove('dragging');
                el.classList.remove('dropTarget');

            });

    }

    //===========================
    // Toast
    //===========================

    showToast(title, message, variant) {

        this.dispatchEvent(

            new ShowToastEvent({

                title,

                message,

                variant

            })

        );

    }

}