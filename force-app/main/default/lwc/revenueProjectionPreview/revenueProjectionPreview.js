import { LightningElement, api, track } from 'lwc';

import getPreview from '@salesforce/apex/RevenueProjectionPreviewController.getPreview';
import startExport from '@salesforce/apex/RevenueProjectionExportController.startExport';

export default class RevenueProjectionPreview extends LightningElement {

    @api recordId;
    @api exportAll;

    @track previewData = [];
    @track filteredData = [];

    showModal = false;

    @track selectedCurrency = 'USD';

    currencyOptions = [
        { label: 'USD', value: 'USD' },
        { label: 'INR', value: 'INR' }
    ];

    handleCurrencyChange(event) {
        this.selectedCurrency = event.detail.value;
    }

    columns = [

        { label: 'Opportunity', fieldName: 'opportunityName' },

        { label: 'Opportunity Id', fieldName: 'opportunityId' },

        { label: 'Account', fieldName: 'accountName' },

        { label: 'Revenue Projection', fieldName: 'revenueProjectionStatus' },

        {
            label: 'TCV (USD)',
            fieldName: 'tcvUSD',
            type: 'currency'
        },

        {
            label: 'ACV (USD)',
            fieldName: 'acvUSD',
            type: 'currency'
        },

        {
            label: 'CQ1',
            fieldName: 'q1',
            type: 'currency'
        },

        {
            label: 'CQ2',
            fieldName: 'q2',
            type: 'currency'
        },

        {
            label: 'CQ3',
            fieldName: 'q3',
            type: 'currency'
        },

        {
            label: 'CQ4',
            fieldName: 'q4',
            type: 'currency'
        },

        {
            label: 'NQ1',
            fieldName: 'q5',
            type: 'currency'
        },

        {
            label: 'NQ2',
            fieldName: 'q6',
            type: 'currency'
        },

        {
            label: 'NQ3',
            fieldName: 'q7',
            type: 'currency'
        },

        {
            label: 'NQ4',
            fieldName: 'q8',
            type: 'currency'
        },

        {
            label: 'Extended',
            fieldName: 'extended',
            type: 'currency'
        }

    ];

    @api
    openPreview() {

        getPreview({

            opportunityId: this.recordId,
            exportAll: this.exportAll

        })
            .then(result => {

 console.log('Preview Result:', JSON.stringify(result));
    console.log('Record Count:', result.length);

   
                this.previewData = result;

                this.filteredData = result;

                this.showModal = true;

            })
            .catch(error => {

                console.error(error);

            });

    }

    handleSearch(event) {

        const value = event.target.value.toLowerCase();

        this.filteredData = this.previewData.filter(item => {

            return (
                (item.opportunityName || '')
                    .toLowerCase()
                    .includes(value)

                ||

                (item.accountName || '')
                    .toLowerCase()
                    .includes(value)

            );

        });

    }

    closeModal() {

        this.showModal = false;

    }

    downloadCSV() {

        startExport({
            opportunityId: this.recordId,
            fieldApiNames: [],
            columnLabels: [],
            exportAll: this.exportAll
        })
            .then(result => {

                this.dispatchEvent(
                    new CustomEvent('exportstarted', {
                        detail: {
                            jobId: result.jobId
                        },
                        bubbles: true,
                        composed: true
                    })
                );

                this.closeModal();

            })
            .catch(error => {

                console.error(error);

            });

    }

}