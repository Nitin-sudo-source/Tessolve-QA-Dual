import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import loadClonePage from '@salesforce/apex/OpportunityCloneController.loadClonePage';
import cloneOpportunity from '@salesforce/apex/OpportunityCloneController.cloneOpportunity';

export default class OpportunityCloneWizard extends NavigationMixin(LightningElement) {

    @api recordId;



    isLoading = true;
    isSaving = false;
    currentStep = 1;

    @wire(CurrentPageReference)
    getPageRef(currentPageReference) {
        this.pageRef = currentPageReference;

        if (currentPageReference) {
            console.log('Page Reference:', currentPageReference);
            this.recordId = this.pageRef.state.recordId;

            console.log('Record Id:', this.recordId);

        }
    }

    @track wrapper = {
        cloneOpportunity: {},
        sourceOpportunity: {
            Account: {},
            RecordType: {}
        },
        relatedCounts: {
            revenueLineItems: 0,
            revenueProjections: 0,
            files: 0,
            opportunityTeam: 0,
            contactRoles: 0
        },
        cloneConfiguration: {}
    };

    showRevenueProjection = false;

    connectedCallback() {
        this.initialize();
    }

    async initialize() {

        this.isLoading = true;

        try {

            this.wrapper = await loadClonePage({
                opportunityId: this.recordId
            });

            this.wrapper = { ...this.wrapper };

            console.log('OUTPUT : ' + JSON.stringify(this.wrapper));

        } catch (error) {

            this.showError(this.reduceError(error));

        } finally {

            this.isLoading = false;

        }

    }

    /*==============================================================
        Getters
    ==============================================================*/

    get isStepOne() {
        return this.currentStep === 1;
    }

    get isStepTwo() {
        return this.currentStep === 2;
    }

    get isStepThree() {
        return this.currentStep === 3;
    }

    get disablePrevious() {
        return this.currentStep === 1;
    }

    get buttonLabel() {

        if (this.currentStep === 1) {
            return 'Continue';
        }

        if (this.currentStep === 2) {
            return 'Clone Opportunity';
        }

        return 'Finish';

    }

    /*==============================================================
        Generic Field Change
    ==============================================================*/

    handleFieldChange(event) {

        const field = event.target.dataset.field;

        let value = event.detail.value;

        this.wrapper = {
            ...this.wrapper,
            cloneOpportunity: {
                ...this.wrapper.cloneOpportunity,
                [field]: value
            }
        };

    }

    /*==============================================================
        Generic Toggle
    ==============================================================*/

    handleToggle(event) {

        const field = event.target.dataset.field;

        this.wrapper = {
            ...this.wrapper,
            cloneConfiguration: {
                ...this.wrapper.cloneConfiguration,
                [field]: event.target.checked
            }
        };

    }

    /*==============================================================
        Previous
    ==============================================================*/

    handlePrevious() {

        if (this.currentStep > 1) {
            this.currentStep--;
        }

    }

    /*==============================================================
        Next
    ==============================================================*/

    async handleNext() {

        if (this.currentStep === 1) {

            if (!this.validateStepOne()) {
                return;
            }

            this.currentStep = 2;

            return;

        }

        if (this.currentStep === 2) {

            await this.handleClone();

            return;

        }

    }

    /*==============================================================
        Clone
    ==============================================================*/

    async handleClone() {

        console.log('Source Opportunity', this.wrapper.sourceOpportunity);
        console.log('Source Id', this.wrapper.sourceOpportunity?.Id);

        console.log('Clone Opportunity', this.wrapper.cloneOpportunity);

        console.log('Clone Config', this.wrapper.cloneConfiguration);

        this.isSaving = true;

        try {

            const opp = JSON.parse(JSON.stringify(this.wrapper.cloneOpportunity));

            delete opp.Account;
            delete opp.Owner;
            delete opp.RecordType;
            delete opp.Technical_Owner__r;

            const request = {
                sourceOpportunityId: this.wrapper.sourceOpportunity.Id,
                cloneOpportunity: opp,
                cloneConfiguration: this.wrapper.cloneConfiguration
            };




            // const request = {
            //     sourceOpportunityId: this.wrapper.sourceOpportunity.Id,
            //     cloneOpportunity: JSON.parse(
            //         JSON.stringify(this.wrapper.cloneOpportunity)
            //     ),
            //     cloneConfiguration: JSON.parse(
            //         JSON.stringify(this.wrapper.cloneConfiguration)
            //     )
            // };

            alert('cloneOpportunity: ' + JSON.stringify(request));
            console.log('cloneOpportunity: ' + JSON.stringify(request));

            const response = await cloneOpportunity({
                request
            });

            if (!response.success) {

                this.showError(response.message);

                return;

            }

            if (response.showRevenueProjectionPopup) {

                this.showRevenueProjection = true;

                this.wrapper.clonedOpportunityId =
                    response.clonedOpportunityId;

                return;

            }

            this.showSuccess(
                'Opportunity cloned successfully.'
            );

            this.navigateToRecord(
                response.clonedOpportunityId
            );

        } catch (error) {

            this.showError(
                this.reduceError(error)
            );

        } finally {

            this.isSaving = false;

        }

    }

    /*==============================================================
        Revenue Projection Complete
    ==============================================================*/

    handleRevenueProjectionSaved(event) {

        this.showRevenueProjection = false;

        this.showSuccess(
            'Opportunity cloned successfully.'
        );

        this.navigateToRecord(
            event.detail.opportunityId
        );

    }

    handleRevenueProjectionCancel() {

        this.showRevenueProjection = false;

        this.navigateToRecord(
            this.wrapper.clonedOpportunityId
        );

    }

    /*==============================================================
        Validation
    ==============================================================*/

    validateStepOne() {

        let isValid = true;

        this.template
            .querySelectorAll(
                'lightning-input, lightning-combobox'
            )
            .forEach(field => {

                if (!field.checkValidity()) {

                    field.reportValidity();

                    isValid = false;

                }

            });

        return isValid;

    }

    /*==============================================================
        Navigation
    ==============================================================*/

    navigateToRecord(recordId) {

        this[NavigationMixin.Navigate]({

            type: 'standard__recordPage',

            attributes: {

                recordId,

                objectApiName: 'Opportunity',

                actionName: 'view'

            }

        });

    }

    /*==============================================================
        Cancel
    ==============================================================*/

    handleCancel() {

        this.navigateToRecord(this.recordId);

    }

    /*==============================================================
        Toast
    ==============================================================*/

    showSuccess(message) {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Success',

                message,

                variant: 'success'

            })

        );

    }

    showError(message) {

        this.dispatchEvent(

            new ShowToastEvent({

                title: 'Error',

                message,

                variant: 'error'

            })

        );

    }

    /*==============================================================
        Error Helper
    ==============================================================*/

    reduceError(error) {

        if (!error) {
            return 'Unknown Error';
        }

        if (Array.isArray(error.body)) {
            return error.body.map(e => e.message).join(', ');
        }

        if (error.body && error.body.message) {
            return error.body.message;
        }

        if (error.message) {
            return error.message;
        }

        return JSON.stringify(error);

    }

}