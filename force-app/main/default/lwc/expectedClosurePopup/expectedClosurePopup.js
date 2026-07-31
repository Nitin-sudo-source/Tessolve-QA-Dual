import { LightningElement, wire, api } from 'lwc';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_NAME from '@salesforce/schema/User.Name';

import getPendingOpportunities from '@salesforce/apex/ExpectedClosurePopupController.getPendingOpportunities';

import saveExpectedClosureDates from '@salesforce/apex/ExpectedClosurePopupController.saveExpectedClosureDates';
import LightningAlert from 'lightning/alert';

export default class ExpectedClosurePopup extends LightningElement {

   
    showModal = false;
    isLoading = false;

    opportunities = [];

    // Records after applying search
    filteredOpportunities = [];

    // Records displayed on current page
    paginatedOpportunities = [];

    searchKey = '';

    currentPage = 1;
    pageSize = 10;
    totalPages = 1;
    activeQuickFilter = 'all';
    _handleKeyDown;


    connectedCallback() {
        this.loadOpportunities();

        this._handleKeyDown = this.handleKeyDown.bind(this);
        window.addEventListener('keydown', this._handleKeyDown);
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this._handleKeyDown);
    }

    handleKeyDown(event) {
        if (event.key === 'Escape' && this.showModal) {
            event.preventDefault();

            clearTimeout(this.hoverTimer);

            this.paginatedOpportunities =
                this.paginatedOpportunities.map(opp => ({
                    ...opp,
                    showSummary: false
                }));

            this.showModal = false;
        }
    }
    userId = USER_ID;

    @wire(getRecord, {
        recordId: USER_ID,
        fields: [USER_NAME]
    })
    userRecord;

    get userName() {
        return getFieldValue(
            this.userRecord.data,
            USER_NAME
        ) || '';
    }


    get opportunityCount() {
        return this.opportunities.length;
    }

    async loadOpportunities() {

        this.isLoading = true;

        try {

            const result = await getPendingOpportunities();

            this.opportunities = result.map(opp => ({
                ...opp,
                ExpectedClosureDate: opp.expectedClosureDate
            }));

            this.filteredOpportunities = [...this.opportunities];

            this.showModal = this.opportunities.length > 0;

            this.currentPage = 1;

            this.updatePagination();

        } catch (error) {

            console.error(
                'Error loading Opportunities:',
                error
            );

            this.showModal = false;

        } finally {

            this.isLoading = false;
        }
    }

    /* ===============================
       SEARCH
    =============================== */

    handleSearch(event) {

        this.searchKey = event.target.value
            ? event.target.value.toLowerCase().trim()
            : '';
        this.activeQuickFilter = 'all';

        if (!this.searchKey) {

            this.filteredOpportunities = [
                ...this.opportunities
            ];

        } else {

            this.filteredOpportunities =
                this.opportunities.filter(opp => {

                    const opportunityName =
                        (opp.opportunityName || '')
                            .toLowerCase();

                    const accountName =
                        (opp.accountName || '')
                            .toLowerCase();

                    const stageName =
                        (opp.stageName || '')
                            .toLowerCase();

                    const oppIdFormat =
                        (opp.oppIdFormat || '')
                            .toLowerCase();

                    return (
                        opportunityName.includes(this.searchKey) ||
                        accountName.includes(this.searchKey) ||
                        stageName.includes(this.searchKey) ||
                        oppIdFormat.includes(this.searchKey)

                    );
                });
        }

        // Always return to first page after searching
        this.currentPage = 1;

        this.updatePagination();
    }

    handleQuickFilter(event) {

        const selectedFilter =
            event.currentTarget.dataset.filter;

        this.activeQuickFilter = selectedFilter;

        let records = [...this.opportunities];

        switch (selectedFilter) {

            case 'overdue': {

                const today = this.getToday();

                records = records.filter(opp =>
                    opp.closeDate &&
                    opp.closeDate < today
                );

                break;
            }

            case 'thisWeek': {

                const { start, end } =
                    this.getCurrentWeekRange();

                records = records.filter(opp =>
                    opp.closeDate &&
                    opp.closeDate >= start &&
                    opp.closeDate <= end
                );

                break;
            }

            case 'thisMonth': {

                const today = new Date();

                records = records.filter(opp => {

                    if (!opp.closeDate) {
                        return false;
                    }

                    const closeDate =
                        this.parseSalesforceDate(
                            opp.closeDate
                        );

                    return (
                        closeDate.getMonth() ===
                        today.getMonth() &&
                        closeDate.getFullYear() ===
                        today.getFullYear()
                    );
                });

                break;
            }

            case 'pending':

                records = records.filter(
                    opp => !opp.ExpectedClosureDate
                );

                break;

            case 'updated':

                records = records.filter(
                    opp => opp.ExpectedClosureDate
                );

                break;

            case 'all':
            default:

                records = [...this.opportunities];

                break;
        }

        this.filteredOpportunities = records;

        // Always return to first page
        this.currentPage = 1;

        // Existing pagination method
        this.updatePagination();
    }

    getToday() {

        const today = new Date();

        return [
            today.getFullYear(),
            String(today.getMonth() + 1).padStart(2, '0'),
            String(today.getDate()).padStart(2, '0')
        ].join('-');
    }

    parseSalesforceDate(dateValue) {

        if (!dateValue) {
            return null;
        }

        const [year, month, day] =
            dateValue.split('-').map(Number);

        return new Date(
            year,
            month - 1,
            day
        );
    }

    getCurrentWeekRange() {

        const today = new Date();

        const currentDay = today.getDay();

        const differenceToMonday =
            currentDay === 0
                ? -6
                : 1 - currentDay;

        const monday = new Date(today);

        monday.setDate(
            today.getDate() + differenceToMonday
        );

        const sunday = new Date(monday);

        sunday.setDate(
            monday.getDate() + 6
        );

        const formatDate = (date) => {

            return [
                date.getFullYear(),
                String(date.getMonth() + 1)
                    .padStart(2, '0'),
                String(date.getDate())
                    .padStart(2, '0')
            ].join('-');
        };

        return {
            start: formatDate(monday),
            end: formatDate(sunday)
        };
    }

    get allCount() {
        return this.opportunities.length;
    }

    get overdueCount() {

        const today = this.getToday();

        return this.opportunities.filter(
            opp =>
                opp.closeDate &&
                opp.closeDate < today
        ).length;
    }

    get thisWeekCount() {

        const { start, end } =
            this.getCurrentWeekRange();

        return this.opportunities.filter(
            opp =>
                opp.closeDate &&
                opp.closeDate >= start &&
                opp.closeDate <= end
        ).length;
    }

    get thisMonthCount() {

        const today = new Date();

        return this.opportunities.filter(opp => {

            if (!opp.closeDate) {
                return false;
            }

            const closeDate =
                this.parseSalesforceDate(
                    opp.closeDate
                );

            return (
                closeDate.getMonth() ===
                today.getMonth() &&
                closeDate.getFullYear() ===
                today.getFullYear()
            );
        }).length;
    }

    get pendingCount() {

        return this.opportunities.filter(
            opp => !opp.ExpectedClosureDate
        ).length;
    }

    get updatedCount() {

        return this.opportunities.filter(
            opp => opp.ExpectedClosureDate
        ).length;
    }

    get allChipClass() {
        return this.getChipClass('all');
    }

    get overdueChipClass() {
        return this.getChipClass('overdue');
    }

    get thisWeekChipClass() {
        return this.getChipClass('thisWeek');
    }

    get thisMonthChipClass() {
        return this.getChipClass('thisMonth');
    }

    get pendingChipClass() {
        return this.getChipClass('pending');
    }

    get updatedChipClass() {
        return this.getChipClass('updated');
    }

    getChipClass(filterName) {

        return this.activeQuickFilter === filterName
            ? 'quick-chip quick-chip-active'
            : 'quick-chip';
    }

    /* ===============================
       PAGINATION
    =============================== */

    updatePagination() {

        this.totalPages = Math.max(
            1,
            Math.ceil(
                this.filteredOpportunities.length /
                this.pageSize
            )
        );

        if (this.currentPage > this.totalPages) {
            this.currentPage = this.totalPages;
        }

        const startIndex =
            (this.currentPage - 1) * this.pageSize;

        const endIndex =
            startIndex + this.pageSize;

        this.paginatedOpportunities =
            this.filteredOpportunities.slice(
                startIndex,
                endIndex
            );
    }

    handlePrevious() {

        if (this.currentPage > 1) {

            this.currentPage--;

            this.updatePagination();
        }
    }

    handleNext() {

        if (this.currentPage < this.totalPages) {

            this.currentPage++;

            this.updatePagination();
        }
    }

    /* ===============================
       DATE CHANGE
    =============================== */

    handleDateChange(event) {

        const opportunityId =
            event.target.dataset.id;

        const selectedDate =
            event.target.value;

        this.opportunities =
            this.opportunities.map(opp => {

                if (
                    opp.opportunityId ===
                    opportunityId
                ) {

                    return {
                        ...opp,
                        ExpectedClosureDate: selectedDate,
                        isUpdated: true,
                        dateFieldClass: 'date-field date-field-updated'
                    };
                }

                return opp;
            });


        this.filteredOpportunities =
            this.filteredOpportunities.map(opp => {

                if (
                    opp.opportunityId ===
                    opportunityId
                ) {

                    return {
                        ...opp,
                        ExpectedClosureDate:
                            selectedDate
                    };
                }

                return opp;
            });


        this.updatePagination();
    }

    hoverTimer;
    handleOpportunityEnter(event) {
        const recordId = event.currentTarget.dataset.id;

        console.log('========== HOVER START ==========');
        console.log('Hovered recordId:', recordId);
        console.log('Current paginatedOpportunities:',
            JSON.stringify(this.paginatedOpportunities)
        );

        clearTimeout(this.hoverTimer);

        this.hoverTimer = setTimeout(() => {

            this.paginatedOpportunities = this.paginatedOpportunities.map(opp => {

                console.log('Current Opp:', JSON.stringify(opp));
                console.log('opp.opportunityId:', opp.opportunityId);
                console.log('recordId:', recordId);
                console.log(
                    'ID Match:',
                    opp.opportunityId === recordId
                );

                return {
                    ...opp,
                    showSummary: opp.opportunityId === recordId
                };
            });

            console.log(
                'After showSummary update:',
                JSON.stringify(this.paginatedOpportunities)
            );

        }, 300);
    }


    handleOpportunityLeave() {

        console.log('========== HOVER LEAVE ==========');

        clearTimeout(this.hoverTimer);

        this.paginatedOpportunities = this.paginatedOpportunities.map(opp => ({
            ...opp,
            showSummary: false
        }));

        console.log(
            'After hide:',
            JSON.stringify(this.paginatedOpportunities)
        );
    }
    /* ===============================
       GETTERS
    =============================== */

    get opportunityCount() {
        return this.opportunities.length;
    }

    get filteredCount() {
        return this.filteredOpportunities.length;
    }

    get isPreviousDisabled() {
        return this.currentPage === 1;
    }

    get isNextDisabled() {
        return this.currentPage === this.totalPages;
    }

    get pageInformation() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get recordInformation() {

        if (this.filteredCount === 0) {
            return 'No opportunities found';
        }

        const start =
            ((this.currentPage - 1) * this.pageSize) + 1;

        const end =
            Math.min(
                this.currentPage * this.pageSize,
                this.filteredCount
            );

        return `${start}-${end} of ${this.filteredCount}`;
    }

    /* ===============================
       BUTTONS
    =============================== */

    handleSaveLater() {
        this.showModal = false;
    }
    async handleContinue() {

        const updatedOpportunities = this.opportunities.filter(
            opp => opp.isUpdated
        );

        if (!updatedOpportunities.length) {

            this.showNotification(
                'No Changes Detected',
                'There are no changes to save.',
                'warning'
            );

            return;
        }

        this.isLoading = true;

        try {

            const result = await saveExpectedClosureDates({
                OpportunityWrapperUpdates: updatedOpportunities
            });

            if (result.success) {

                this.showNotification(
                    'Success',
                    result.message,
                    'success'
                );

                this.showModal = false;

                await this.loadOpportunities();

            } else {

                this.showNotification(
                    'Unable to Save',
                    result.message,
                    'error',
                    'Validation Errors'
                );

               // await this.loadOpportunities();

            }

        } catch (error) {

            this.showNotification(
                'Something Went Wrong',
                error?.body?.message ||
                'An unexpected error occurred while saving your changes. Please try again.',
                'error'
            );
            

        } finally {

            this.isLoading = false;
            //await this.loadOpportunities();

        }
    }

    // async handleContinue() {

    //     let updatedOpportunities = [];


    //     updatedOpportunities = this.opportunities.filter(
    //         opp => opp.isUpdated
    //     );

    //     // const result = await saveExpectedClosureDates({
    //     //     updates: updatedOpportunities
    //     // });
    //     this.isLoading = true;
    //     console.log('recordsToUpdate: ' + JSON.stringify(updatedOpportunities));
    //     try {

    //         const result = await saveExpectedClosureDates({
    //             OpportunityWrapperUpdates: updatedOpportunities
    //         });

    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: result.success ? 'Success' : 'Unable to Save',
    //                 message: result.message,
    //                 variant: result.success ? 'success' : 'error'
    //             })
    //         );

    //         if (result.success) {
    //             this.showModal = false;
    //             await this.loadOpportunities();
    //         }

    //     } catch (error) {

    //         let message =
    //             error?.body?.message ||
    //             'An unexpected error occurred while saving your changes. Please try again.';

    //         this.dispatchEvent(
    //             new ShowToastEvent({
    //                 title: 'Error',
    //                 message,
    //                 variant: 'error'
    //             })
    //         );

    //         await this.loadOpportunities();

    //     } finally {
    //         this.isLoading = false;
    //         await this.loadOpportunities();
    //     }
    // }

    // handleContinue() {
    //     console.log('Updated Opportunities:', JSON.stringify(this.opportunities));

    // }


    get saveButtonLabel() {
        const count = this.opportunities.filter(
            row => row.isUpdated
        ).length;

        if (count === 0) {
            return 'Save & Continue →';
        }

        return count === 1
            ? 'Save 1 Change & Continue →'
            : `Save ${count} Changes & Continue →`;
    }



    showNotification(title, message, variant = 'info', subtitle = '') {

        const notification = this.template.querySelector('c-notification-overlay');

        if (notification) {

            notification.open({
                title,
                subtitle,
                message,
                variant
            });

            // Automatically create error cards if message contains
            // Opportunity: ... Reason: ...
            notification.parseErrors(message);
        }
    }

    handleNotificationClose() {
        // Optional
    }

}