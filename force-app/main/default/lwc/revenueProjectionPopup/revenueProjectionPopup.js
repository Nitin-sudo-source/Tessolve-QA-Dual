import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOppDetails from '@salesforce/apex/RevenueProjectionPopup.getOppDetails';
import getRevenueInfo from '@salesforce/apex/RevenueProjectionPopup.getRevenueInfo';
import getBookingWrapper from '@salesforce/apex/RevenueProjectionPopup.getBookingWrapper';
import Save from '@salesforce/apex/RevenueProjectionPopup.Save';
import UpdateRevenue from '@salesforce/apex/RevenueProjectionPopup.UpdateRevenue';

export default class RevenueProjectionPopup extends NavigationMixin(LightningElement) {
    @api recordId;
    @track psmArray = [];
    @track oppDetails;
    @track paymentMilestoneWrapperList = [];
    @track updatedPaymentMilestoneWrapperList = [];
    @track isSpinner = false;
    @track showFirstTime = true;
    // @track bkWrapper = { bk: {} };
    // @track getBookingWrapperList = [];
    @track revenue = {
        CurrentFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 0 },
        CurrentFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 1 },
        CurrentFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 2 },
        CurrentFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 3 },

        NextFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 4 },
        NextFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 5 },
        NextFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 6 },
        NextFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 7 },

        Extended: { Id: null, amount: 0, checkbox: false, help: '', index: 8 }
    };
    pageRef;
    @track isclosedWon = false;
    @track lost = false;
    @track isClosed = false;
    @track estimateProjectStartDate = null;


    @wire(CurrentPageReference)
    getPageRef(currentPageReference) {
        this.pageRef = currentPageReference;

        if (currentPageReference) {
            console.log('Page Reference:', currentPageReference);
            this.recordId = this.pageRef.state.recordId;

            console.log('Record Id:', this.recordId);

        }
    }
    redirecttofield(fieldName) {

        console.log('fieldName:', fieldName);

        setTimeout(() => {

            const inputs = this.template.querySelectorAll('lightning-input');

            let fieldEl = null;

            for (let input of inputs) {
                if (input.name === fieldName) {
                    fieldEl = input;
                    break;
                }
            }

            if (!fieldEl) {
                console.warn(`Field not found: ${fieldName}`);
                return;
            }

            // Scroll to field
            fieldEl.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            });

            try {

                const nativeInput = fieldEl.shadowRoot?.querySelector('input');

                if (nativeInput) {
                    nativeInput.focus();
                } else {
                    fieldEl.focus();
                }

            } catch (error) {
                console.error(`Focus error for ${fieldName}`, error);
            }

        }, 80);
    }

    currencySymbols = {
    INR: '₹',
    USD: '$',
    EUR: '€',
    GBP: '£',
    AUD: 'A$',
    CAD: 'C$',
    SGD: 'S$'
};

@track currencyCode = 'INR';

normalize(value) {
    return parseFloat(value) || 0;
}

formatCurrency(value) {
    return value.toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2
    });
}

get currencySymbol() {
    const code = this.oppDetails?.CurrencyIsoCode;
    return this.currencySymbols[code] || '';
}
get totalCurrentFY() {
    const total =
        this.normalize(this.revenue.CurrentFY_Q1.amount) +
        this.normalize(this.revenue.CurrentFY_Q2.amount) +
        this.normalize(this.revenue.CurrentFY_Q3.amount) +
        this.normalize(this.revenue.CurrentFY_Q4.amount);

    return this.formatCurrency(total);
}

get totalNextFY() {
    const total =
        this.normalize(this.revenue.NextFY_Q1.amount) +
        this.normalize(this.revenue.NextFY_Q2.amount) +
        this.normalize(this.revenue.NextFY_Q3.amount) +
        this.normalize(this.revenue.NextFY_Q4.amount);

    return this.formatCurrency(total);
}

get grandTotal() {
    const total =
        this.normalize(this.revenue.CurrentFY_Q1.amount) +
        this.normalize(this.revenue.CurrentFY_Q2.amount) +
        this.normalize(this.revenue.CurrentFY_Q3.amount) +
        this.normalize(this.revenue.CurrentFY_Q4.amount) +
        this.normalize(this.revenue.NextFY_Q1.amount) +
        this.normalize(this.revenue.NextFY_Q2.amount) +
        this.normalize(this.revenue.NextFY_Q3.amount) +
        this.normalize(this.revenue.NextFY_Q4.amount) +
        this.normalize(this.revenue.Extended.amount);

    return this.formatCurrency(total);
}
    connectedCallback() {
        console.log('recordId: ' + this.recordId);
        this.getOppDetailsInformation();
        
        //this.handleBookingWrapper();

    }

    handleCancel() {
        // View a custom object record.
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: this.recordId,
                objectApiName: "Opportunity", // objectApiName is optional
                actionName: "view",
            },
        });
    }

    getOppDetailsInformation() {
        getOppDetails({ oppId: this.recordId })
            .then(result => {
                console.log('result: ' + JSON.stringify(result));
                this.oppDetails = result;
                
                if (this.oppDetails.StageName == 'Closed Won') {
                    this.isclosedWon = true;
                }
                if (this.oppDetails.StageName == 'Closed Lost') {
                    this.lost = true;
                }
                this.isClosed = this.oppDetails.StageName === 'Closed Won' || this.oppDetails.StageName === 'Closed Lost';
                //this.currencyCode = this.oppDetails?.CurrencyIsoCode;
                this.currencyCode = `"${result.CurrencyIsoCode || 'INR'}"`;
                const normalize = (date) => {
                    const d = new Date(date);
                    d.setHours(0, 0, 0, 0);
                    return d;
                };
                
                // FIXED null check
                if (this.oppDetails.Estimated_Project_Start_Date__c) {
                    this.estimateProjectStartDate = normalize(this.oppDetails.Estimated_Project_Start_Date__c);
                } else {
                    this.estimateProjectStartDate = normalize(new Date());
                }
                
                console.log('currencyCode: ' + this.currencyCode);
                console.log('estimateProjectStartDate: ' + this.estimateProjectStartDate);
                this.getInitializeRecords();
                this.getRevenueInfo();
            })
            .catch(error => {
                console.log('error: ' + JSON.stringify(error));
            });
    }

    getInitializeRecords() {
        this.getRevenueDataInformationBefore();
    }

    getRevenueDataInformationBefore() {
        getBookingWrapper({ oppId: this.recordId })
            .then(data => {

                if (!data || data.length === 0) {
                    return;
                }

                this.psmArray = data;
                console.log('psmArray:', JSON.stringify(this.psmArray));

                this.paymentMilestoneWrapperList = data;
                this.updatedPaymentMilestoneWrapperList = [...data];

                const baseFY = data[0].psm.Fiscal_Year__c;

                let revenue = {
                    CurrentFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 0 },
                    CurrentFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 1 },
                    CurrentFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 2 },
                    CurrentFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 3 },

                    NextFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 4 },
                    NextFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 5 },
                    NextFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 6 },
                    NextFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 7 },

                    Extended: { Id: null, amount: 0, checkbox: false, help: '', index: 8 }
                };

                data.forEach((row, index) => {


                   
                    const fy = row.psm.Fiscal_Year__c;
                    const quarter = row.psm.Fiscal_Quarter__c;
                    const amount = row.psm.Quarter_Amount__c ?? 0;
                    const id = row.psm.Id ?? null;

                    const startDate = row.psm.Quarter_Start_Date__c
                        ? new Date(row.psm.Quarter_Start_Date__c)
                        : null;

                    const endDate = row.psm.Quarter_End_Date__c
                        ? new Date(row.psm.Quarter_End_Date__c)
                        : null;

                    // const today = new Date();
                    // today.setHours(0, 0, 0, 0);
                    const normalize = (date) => {
                        const d = new Date(date);
                        d.setHours(0, 0, 0, 0);
                        return d;
                    };
                    
                    const checkbox = endDate && this.estimateProjectStartDate
                        ? normalize(endDate) < normalize(this.estimateProjectStartDate)
                        : false;

                    console.log('Quarter:', quarter);
                    console.log('EndDate RAW:', row.psm.Quarter_End_Date__c);
                    console.log('EndDate Parsed:', endDate);
                    console.log('StartDate:', this.estimateProjectStartDate);
                    console.log('Comparison:', normalize(endDate) < normalize(this.estimateProjectStartDate));

                    //const checkbox = endDate ? endDate < this.estimateProjectStartDate : false;

                    let helpText = '';

                    if (startDate && endDate) {

                        const startFormatted = startDate.toLocaleDateString('en-GB', {
                            day: 'numeric',
                            month: 'long',
                            year: 'numeric'
                        });

                        const endFormatted = endDate.toLocaleDateString('en-GB', {
                            day: 'numeric',
                            month: 'long',
                            year: 'numeric'
                        });

                        helpText = `Start: ${startFormatted} | End: ${endFormatted}`;
                    }

                    // Extended record
                    if (row.psm.Is_Extended__c) {

                        revenue.Extended = {
                            ...revenue.Extended,
                            Id: id,
                            amount: amount,
                            checkbox: checkbox,
                            help: helpText
                        };

                        return;
                    }

                    // Determine key
                    let key;

                    if (fy === baseFY) {
                        key = `CurrentFY_${quarter}`;
                    } else {
                        key = `NextFY_${quarter}`;
                    }

                    revenue[key] = {
                        ...revenue[key], // preserves index
                        Id: id,
                        amount: amount,
                        checkbox: checkbox,
                        help: helpText
                    };

                });

                this.revenue = revenue;

                console.log('Revenue Object:', JSON.stringify(this.revenue));

                // Build Id → Index map
                this.idIndexMap = {};

                this.updatedPaymentMilestoneWrapperList.forEach((row, index) => {

                    const id = row.psm.Id ?? null;

                    if (id) {
                        this.idIndexMap[id] = index;
                    }

                });

                console.log('IdIndexMap:', JSON.stringify(this.idIndexMap));

            })
            .catch(error => {
                console.error('Revenue Load Error', error);
            });
    }


    getRevenueInfo() {
        getRevenueInfo({ schemeId: this.recordId })
            .then(data => {
                if (data) {
    
                    this.psmArray = data;
                    this.paymentMilestoneWrapperList = data;
                    this.updatedPaymentMilestoneWrapperList = [...data];
    
                    // Build Id → Index map FIRST
                    this.idIndexMap = {};
                    this.updatedPaymentMilestoneWrapperList.forEach((row, index) => {
                        this.idIndexMap[row.psm.Id] = index;
                    });
    
                    let revenue = {
                        CurrentFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 0 },
                        CurrentFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 1 },
                        CurrentFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 2 },
                        CurrentFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 3 },
    
                        NextFY_Q1: { Id: null, amount: 0, checkbox: false, help: '', index: 4 },
                        NextFY_Q2: { Id: null, amount: 0, checkbox: false, help: '', index: 5 },
                        NextFY_Q3: { Id: null, amount: 0, checkbox: false, help: '', index: 6 },
                        NextFY_Q4: { Id: null, amount: 0, checkbox: false, help: '', index: 7 },
    
                        Extended: { Id: null, amount: 0, checkbox: false, help: '', index: 8 }
                    };
    
                    data.forEach(row => {
    
                        const fyType = row.psm.FY_Type__c;
                        const quarter = row.psm.Fiscal_Quarter__c;
                        const amount = row.psm.Quarter_Amount__c;
                        const id = row.psm.Id;
    
                        const startDate = new Date(row.psm.Quarter_Start_Date__c);
                        const endDate = new Date(row.psm.Quarter_End_Date__c);

                        const normalize = (date) => {
                            const d = new Date(date);
                            d.setHours(0, 0, 0, 0);
                            return d;
                        };
                        
                        const checkbox = endDate && this.estimateProjectStartDate
                            ? normalize(endDate) < normalize(this.estimateProjectStartDate)
                            : false;

                        console.log('Quarter:', quarter);
                        console.log('EndDate RAW:', row.psm.Quarter_End_Date__c);
                        console.log('EndDate Parsed:', endDate);
                        console.log('StartDate:', this.estimateProjectStartDate);
                        console.log('Comparison:', normalize(endDate) < normalize(this.estimateProjectStartDate));
    
                        // const today = new Date();
                        // today.setHours(0,0,0,0);
                        //const checkbox = endDate ? endDate < this.estimateProjectStartDate : false;
                        //const checkbox = endDate < today;
                        const finalAmount = checkbox ? 0 : amount || 0;
        
                        const startFormatted = startDate.toLocaleDateString('en-GB',{day:'numeric',month:'long',year:'numeric'});
                        const endFormatted = endDate.toLocaleDateString('en-GB',{day:'numeric',month:'long',year:'numeric'});
    
                        const helpText = `Start: ${startFormatted} | End: ${endFormatted}`;
    
                        if (fyType === 'Current FY') {
    
                            revenue[`CurrentFY_${quarter}`] = {
                                Id: id,
                                amount: this.roundToDecimals(finalAmount),
                                checkbox: checkbox,
                                help: helpText
                            };
    
                        } else if (fyType === 'Next FY') {
    
                            revenue[`NextFY_${quarter}`] = {
                                Id: id,
                                amount: this.roundToDecimals(finalAmount),
                                checkbox: checkbox,
                                help: helpText
                            };
    
                        } else if (row.psm.Is_Extended__c) {
    
                            revenue.Extended = {
                                Id: id,
                                amount: this.roundToDecimals(finalAmount),
                                checkbox: checkbox,
                                help: helpText
                            };
                        }
    
                    });
    
                    this.revenue = revenue;

                    Object.values(this.revenue).forEach(item => {

                        if (!item.Id) {
                            return;
                        }
                    
                        const index = this.idIndexMap[item.Id];
                    
                        if (index !== undefined) {
                            this.updatedPaymentMilestoneWrapperList[index].psm.Quarter_Amount__c = item.amount;
                        }
                    
                    });
                    this.updatedPaymentMilestoneWrapperList = [...this.updatedPaymentMilestoneWrapperList];    
                    console.log('Revenue Object', JSON.stringify(this.revenue));
                    console.log('IdIndexMap', JSON.stringify(this.idIndexMap));
                    console.log('Updated List JSON', JSON.stringify(this.updatedPaymentMilestoneWrapperList));
    
                    this.showFirstTime = false;
                }
            })
            .catch(error => {
                console.error('Revenue Load Error', error);
            });

            
    }

    roundToDecimals(value, decimals = 2) {
    if (value === null || value === undefined || value === '') {
        return null;
    }

    return Number(Math.round(parseFloat(value + 'e' + decimals)) + 'e-' + decimals);
}

    

    handleSave(event) {
        //alert('Inside Save');
        this.save();

    }
    save() {
        if (!this.validateAllRevenueInputs()) {
            return;
        }
        this.isSpinner = true;
        //alert('Inside Save' + JSON.stringify(this.bkWrapper));
        Save({ RevenueWrapperList: this.updatedPaymentMilestoneWrapperList, oppId: this.recordId })
            .then(result => {
                console.log('Save success' + result);
                this.showSuccessToast('Success', 'Revenue Created Successfully');

                setTimeout(() => {
                    this.isSpinner = false;
                    location.replace('/' + result.Id);
                }, 2000); // 3 sec delay
            })
            .catch(error => {
                console.error('Error:', error);
                this.isSpinner = false;
            });
    }

    callingListSave() {
        if (!this.validateAllRevenueInputs()) {
            return;
        }
        this.isSpinner = true;
        console.log('finalResult: ' + JSON.stringify(this.updatedPaymentMilestoneWrapperList));
        UpdateRevenue({ RevenueWrapperList: this.updatedPaymentMilestoneWrapperList })
            .then(result => {
                console.log('Rev success' + result);
                this.showSuccessToast('Success', 'Revenue Updated Successfully');

                setTimeout(() => {
                    this.isSpinner = false;
                    location.replace('/' + this.recordId);
                }, 2000); // 2 sec delay


            })
            .catch(error => {
                console.error('Error:', error);
                this.isSpinner = false;
            });

    }
    // handlechange(event) {

    //     const field = event.target.name;
    //     const value = event.target.value;
    //     const recordId = event.target.dataset.id;

    //     console.log('Field:', field);
    //     console.log('Value:', value);
    //     console.log('Record Id:', recordId);

    //     // update revenue object
    //     this.revenue = {
    //         ...this.revenue,
    //         [field]: {
    //             ...this.revenue[field],
    //             Id: recordId,
    //             amount: value
    //         }
    //     };

    //     // get index from Id map
    //     const index = this.idIndexMap[recordId];

    //     if (index !== undefined) {

    //         const newObj = {
    //             ...this.updatedPaymentMilestoneWrapperList[index].psm,
    //             Quarter_Amount__c: value
    //         };

    //         const updatedList = [...this.updatedPaymentMilestoneWrapperList];
    //         updatedList[index].psm = newObj;

    //         this.updatedPaymentMilestoneWrapperList = updatedList;
    //     }

    //     console.log('Updated List:', JSON.stringify(this.updatedPaymentMilestoneWrapperList));
    // }

    normalizeCurrency(value) {

        if (value === null || value === undefined) {
            return 0;
        }

        const parsed = Number(value);

        if (!Number.isFinite(parsed) || parsed < 0) {
            return 0;
        }

        return parsed;
    }

    validateAllRevenueInputs() {

        const inputs = this.template.querySelectorAll('lightning-input');

        for (let input of inputs) {

            const value = input.value;

            if (!this.isValidPositiveNumber(value)) {

                input.setCustomValidity('Please enter a valid positive number');
                input.reportValidity();

                const fieldName = input.name;
                this.redirecttofield(fieldName);

                return false;
            }

            input.setCustomValidity('');
            input.reportValidity();
        }

        return true;
    }


    isValidPositiveNumber(value) {

        if (value === null || value === undefined || value === '') {
            return false;
        }

        // Allows: 0, 10, 0.5, 10.25
        const positiveNumberPattern = /^(?:\d+|\d+\.\d+)$/;

        return positiveNumberPattern.test(value);
    }

    handlechange(event) {

        const { name: field, value: rawValue, dataset } = event.target;
        const recordId = dataset.id;
        const indexFromUI = dataset.index;

        const inputField = event.target;
        console.log('field: ' + field);

        // -------- Field Validation --------
        // if (rawValue === '-' || rawValue === '' || rawValue === null || isNaN(rawValue)) {

        //     inputField.setCustomValidity('Please enter a valid number');
        //     inputField.reportValidity();

        //     this.redirecttofield(field);

        //     return;
        // }

        // ---- Strict validation (no negative numbers allowed) ----
        if (!this.isValidPositiveNumber(rawValue)) {

            inputField.setCustomValidity('Please enter a valid positive number');
            inputField.reportValidity();

            this.redirecttofield(field);

            return;
        }

        // Clear validation if correct
        inputField.setCustomValidity('');
        inputField.reportValidity();

        const value = this.normalizeCurrency(rawValue);

        // -------- Update revenue UI model --------
        this.revenue = {
            ...this.revenue,
            [field]: {
                ...this.revenue[field],
                Id: recordId ?? null,
                amount: value
            }
        };

        let index = null;

        if (recordId && this.idIndexMap?.[recordId] !== undefined) {
            index = this.idIndexMap[recordId];
        }
        else if (indexFromUI !== undefined) {
            index = Number(indexFromUI);
        }

        if (index === null || !this.updatedPaymentMilestoneWrapperList?.[index]) {
            return;
        }

        const updatedList = [...this.updatedPaymentMilestoneWrapperList];

        updatedList[index] = {
            ...updatedList[index],
            psm: {
                ...updatedList[index].psm,
                Quarter_Amount__c: value
            }
        };

        this.updatedPaymentMilestoneWrapperList = updatedList;
        console.log('Updated List:', JSON.stringify(this.updatedPaymentMilestoneWrapperList));

    }

    showSuccessToast(title, message) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    showErrorToast(title, message) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }


}