import { LightningElement, track, wire, api } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOppDetails from '@salesforce/apex/ResourceLineItemController.getOppDetails';
import getMasterDetails from '@salesforce/apex/ResourceLineItemController.getMasterDetails';
import getSellingRateInformation from '@salesforce/apex/ResourceLineItemController.getSellingRateInformation';
import saveDetails from '@salesforce/apex/ResourceLineItemController.saveDetails';
import RESOURCE_OBJECT from '@salesforce/schema/Resource_Line_Item__c';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import fetchSkillCategoryMatrix from '@salesforce/apex/ResourceLineItemController.fetchSkillCategoryMatrix';
import fetchExperienceOptions from '@salesforce/apex/ResourceLineItemController.fetchExperienceOptions';
import { deleteRecord } from 'lightning/uiRecordApi';



export default class ResourceCreationBulk extends LightningElement {
    @api recordId;
    @track showSpinner = false;
    @track selectedModificationId = '';
    @track getBookingRecordInfo = {};
    @track isValidationError = false;
    @track searchPlaceholder = 'Search Skill Category Matrix...';
    @track searchPlaceholderex = 'Search Experience...';
    @api prefilled = '';
    rateDebounceTimer;
    activeSections = [];
    activeTabValue = null;
    @track currencyCode = 'INR';

    currencySymbols = {
        INR: '₹',   // Indian Rupee
        USD: '$',   // US Dollar
        EUR: '€',   // Euro
        GBP: '£',   // British Pound
        AUD: 'A$',  // Australian Dollar
        CAD: 'C$',  // Canadian Dollar
        SGD: 'S$',  // Singapore Dollar
        JPY: '¥',   // Japanese Yen
        MYR: 'RM'   // Malaysian Ringgit
    };
    @track otherCharges = {
        originalData: {
            id: 'recordTypeID',
            sequenceNo: 0,

            parentskillbusinessUnit: '',
            subBusinessUnit: '',
            childBusinessUnitskills: '',
            category: '',
            skillFunctionalArea: '',
            experience: '',

            numberOfResources: 0,

            tentativeStartDate: '',
            billingStartDate: '',

            region: '',
            regionGroup: '',
            salesUnit: 'Monthly',

            durationMonths: 0,
            durationMonthsCalculated: 0,
            convertedUnits: 0,

            sellingRate: 0,
            nonMSASellingRate: 0,
            modifiednonMSASellingRate: 0,
            isMSA: false,
            isNonMSA: false,
            projectedRevenue: 0,

            status: '',
            approvalStatus: '',
            engineerName: '',
            remarks: '',
            lostremarks: '',
            lostreasonvalue: '',
            isRemarksRequired: false,
            isLostRemarksRequired: false,

            currencyIsoCode: '',


            relatedOpportunityId: '',

            isEditable: this.isOppClosed || false
        },

        modifiedData: {
            rows: [],

            totalResources: 0,
            totalSellingRate: 0,
            totalnonMSASellingRate: 0,
            modifiednonMSASellingRate: 0,
            isMSA: false,
            isNonMSA: false,
            totalProjectedRevenue: 0,

            bookingId: '',
            level1Approver: '',
            level2Approver: ''
        },

        modifiedDataInStringFormat: {
            rows: [],

            totalResources: 0,
            totalSellingRate: 0,
            totalnonMSASellingRate: 0,
            totalProjectedRevenue: 0
        },

        newchargesData: [
            {
                parentskillbusinessUnit: '',
                subBusinessUnit: '',
                childBusinessUnitskills: '',
                category: '',
                skillFunctionalArea: '',
                experience: '',

                numberOfResources: 0,

                tentativeStartDate: '',
                billingStartDate: '',

                region: '',
                salesUnit: 'Monthly',

                durationMonths: 0,

                sellingRate: 0,
                nonMSASellingRate: 0,
                nonMSASellingRate: 0,
                isMSA: false,
                isNonMSA: false,
                projectedRevenue: 0,

                status: '',
                remarks: '',
                lostremarks: '',
                lostreasonvalue: '',
                isRemarksRequired: false,
                isLostRemarksRequired: false,
                isMSA: false,

                isEditable: this.isOppClosed || false
            }
        ],

        metadata: {
            businessUnits: [],
            subBusinessUnits: [],
            childBusinessUnitskills: [],
            categories: [],
            skillFunctionalAreas: [],
            experiences: [],
            regions: [],
            salesUnits: [],
            statuses: []
        },

    };

    parentSkillbusinessUnitOptions = [];
    categoryOptions = [];
    experienceOptions = [];
    regionsOptions = [];
    lostOptions = [];
    salesoptions = [];
    statusOptions = [];

    subBUValues;
    childBUValues;
    skillValues;
    @track oppDefaults;
    modalInitialized = false;
    allExpanded = false;
    @track rateTimer = 100;
    @track showQuickView = false;

    get getBookingOpportunity() {
        return this.getBookingRecordInfo?.Name || '';
    }

    get getProjectId() {
        return this.getBookingRecordInfo?.AccountId || '';
    }

    get currencySymbol() {
        const code = this.getBookingRecordInfo?.CurrencyIsoCode;
        return this.currencySymbols[code] || '';
    }

    get filteredRows() {

        const activeFilter =
            this.unitSalesStatusOptions.find(o => o.checkBoxStatus)?.filterType;

        if (!activeFilter || activeFilter === 'ALL') {
            return this.otherCharges.newchargesData;
        }

        return this.otherCharges.newchargesData.filter(
            row => row.status === activeFilter
        );
    }


    get totalResources() {
        return this.otherCharges.newchargesData.length || 0;
    }

    get isSaveDisabled() {
        return this.otherCharges.newchargesData.length === 0 || this.isOppClosed;
    }

    get toggleLabel() {
        return this.allExpanded ? 'Collapse All' : 'Expand All';
    }

    get toggleIcon() {
        return this.allExpanded ? 'utility:collapse_all' : 'utility:expand_all';
    }


    // Get object metadata
    @wire(getObjectInfo, { objectApiName: RESOURCE_OBJECT })
    objectInfo;

    @wire(CurrentPageReference)
    getPageRef(currentPageReference) {
        this.pageRef = currentPageReference;

        if (currentPageReference) {
            //console.log('Page Reference:', currentPageReference);
            this.recordId = this.pageRef.state.recordId;

            //console.log('Record Id:', this.recordId);

        }
    }

    // Get all picklists
    @wire(getPicklistValuesByRecordType, {
        objectApiName: RESOURCE_OBJECT,
        recordTypeId: '$objectInfo.data.defaultRecordTypeId'
    })
    picklistHandler({ data, error }) {

        if (data) {

            // Business Unit
            this.parentSkillbusinessUnitOptions =
                data.picklistFieldValues.Sub_Skills__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            // Category
            this.categoryOptions =
                data.picklistFieldValues.Category__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            // Experience
            this.experienceOptions =
                data.picklistFieldValues.Experience__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            // regionsOptions
            this.regionsOptions =
                data.picklistFieldValues.Region__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            //LostOptions
            this.lostOptions =
                data.picklistFieldValues.Lost_Reason__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            // salesoptions
            this.salesoptions =
                data.picklistFieldValues.Sales_Unit__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));


            this.statusOptions =
                data.picklistFieldValues.Status__c.values.map(v => ({
                    label: v.label,
                    value: v.value
                }));

            // Dependent metadata
            this.subBUValues = data.picklistFieldValues.Sub_Business_Unit__c;
            this.childBUValues = data.picklistFieldValues.Business_Unit__c;
            this.skillValues = data.picklistFieldValues.Skill_Functional_Area__c;

        }
    }

    quickView = {};

    handleQuickView(event) {

        const id = event.currentTarget.dataset.id;

        const row = this.otherCharges.newchargesData.find(r => r.id === id);

        if (!row) {
            return;
        }

        // clone to avoid mutating original row
        this.quickView = { ...row };

        this.quickView.formattedSellingRate =
            this.formatCurrency(this.quickView.sellingRate, this.quickView.currencyIsoCode);

        this.quickView.formattedNonMSASellingRate =
            this.formatCurrency(this.quickView.nonMSASellingRate || 0, this.quickView.currencyIsoCode || 'INR');

        this.quickView.formattedProjectedRevenue =
            this.formatCurrency(this.quickView.projectedRevenue, this.quickView.currencyIsoCode);

        this.showQuickView = true;
    }

    closeQuickView(event) {
        this.openSectionById(event.currentTarget.dataset.id);
        this.showQuickView = false;
    }

    @track showInsightsModal = false;

    openResourceInsights() {
        //this.calculateInsights();
        this.showInsightsModal = true;
    }

    closeInsightsModal() {
        this.showInsightsModal = false;
    }


    @track viewRateCard = false;
    @track selectedRateRowSeq = null;


    handleBusinessUnitChange(event) {

        const rowId = event.target.dataset.id;
        const value = event.detail.value;

        const rowIndex =
            this.otherCharges.newchargesData.findIndex(
                r => r.id === rowId
            );

        const row =
            this.otherCharges.newchargesData[rowIndex];

        // Parent Business Unit
        row.parentskillbusinessUnit = value;

        // Reset children
        row.subBusinessUnit = null;
        row.childBusinessUnitskills = null;

        row.subBUOptions = [];
        row.childBUSkillsOptions = [];

        //==========================
        // Business Unit -> Sub BU
        //==========================
        if (value && this.subBUValues) {

            const controllingKey =
                this.subBUValues.controllerValues[value];

            row.subBUOptions =
                this.subBUValues.values
                    .filter(opt => opt.validFor.includes(controllingKey))
                    .map(opt => ({
                        label: opt.label,
                        value: opt.value
                    }));

            // Auto Select Sub BU
            if (row.subBUOptions.length === 1) {

                row.subBusinessUnit =
                    row.subBUOptions[0].value;

            }

        }

        //==========================
        // Sub BU -> Child Skills
        //==========================
        if (row.subBusinessUnit && this.childBUValues) {

            const controllingSkillsKey =
                this.childBUValues.controllerValues[
                row.subBusinessUnit
                ];

            row.childBUSkillsOptions =
                this.childBUValues.values
                    .filter(opt => opt.validFor.includes(controllingSkillsKey))
                    .map(opt => ({
                        label: opt.label,
                        value: opt.value
                    }));

            // Auto Select Child Skill
            if (row.childBUSkillsOptions.length === 1) {

                row.childBusinessUnitskills =
                    row.childBUSkillsOptions[0].value;

            }

        }

        this.otherCharges.newchargesData = [
            ...this.otherCharges.newchargesData
        ];

        console.log(
            'Updated Row:',
            JSON.stringify(row, null, 2)
        );

        this.fetchSkillOptions(rowId, '');
        this.fetchExperienceOptions(rowId, '');

        //this.handlecalculateValues();
        Promise.resolve().then(() => {
            this.handlecalculateValues();
        });
    }

    handleSubBUChange(event) {

        const rowId = event.target.dataset.id;
        const value = event.detail.value;

        const rowIndex =
            this.otherCharges.newchargesData.findIndex(
                r => r.id === rowId
            );

        const row =
            this.otherCharges.newchargesData[rowIndex];

        // Set Sub Business Unit
        row.subBusinessUnit = value;

        // Reset Child Skill
        row.childBusinessUnitskills = null;
        row.childBUSkillsOptions = [];

        //==========================
        // Sub BU -> Child Skills
        //==========================
        if (value && this.childBUValues) {

            const controllingSkillsKey =
                this.childBUValues.controllerValues[value];

            row.childBUSkillsOptions =
                this.childBUValues.values
                    .filter(opt => opt.validFor.includes(controllingSkillsKey))
                    .map(opt => ({
                        label: opt.label,
                        value: opt.value
                    }));

            // Auto Select Child Skill
            if (row.childBUSkillsOptions.length === 1) {

                row.childBusinessUnitskills =
                    row.childBUSkillsOptions[0].value;

            }

        }



        this.otherCharges.newchargesData = [
            ...this.otherCharges.newchargesData
        ];

        console.log(
            'Updated Row:',
            JSON.stringify(row, null, 2)
        );

        this.fetchSkillOptions(rowId, '');
        this.fetchExperienceOptions(rowId, '');

        Promise.resolve().then(() => {
            this.handlecalculateValues();
        });
    }

    fetchSkillOptions(rowId, searchKey) {
        // alert('rowId: ' + JSON.stringify((rowId)));

        console.log('ROW RECEIVED:', JSON.stringify(rowId));
        const rows = [...this.otherCharges.newchargesData];

        // ✅ Find index using rowId
        const index = rows.findIndex(r => r.id === rowId);

        if (index === -1) {
            console.error('Row not found for rowId:', rowId);
            return;
        }

        const row = rows[index];

        console.log('RowId:', rowId);
        console.log('Row Index:', index);
        console.log('Row Data:', JSON.stringify(row));

        row.isLoading = true;
        row.isDropdownOpen = true;

        fetchSkillCategoryMatrix({
            searchKey: searchKey,
            projectId: this.getProjectId,
            bu: row.childBusinessUnitskills,
            subBu: row.subBusinessUnit,
            subSkills: row.parentskillbusinessUnit,
            region: row.region,
            msaType: row.isMSA ? 'MSA' : 'Non MSA'
        })
            .then(result => {

                console.log('Apex Result Count:', result.length);
                console.log('Apex Result:', JSON.stringify(result));

                const options = result.map(rec => ({
                    label: rec.Name,
                    value: rec.Id,
                    className: 'slds-listbox__item'
                }));

                console.log('Mapped Options:', JSON.stringify(options));
                if (!options?.length) {
                    row.skillCategoryMatrixId = null;
                    row.skillCategoryMatrixName = '';
                }

                row.skillOptions = options;
                row.filteredOptions = options;
                row.isLoading = false;
                row.highlightIndex = -1;

                // 🔥 Auto-select if only 1
                // if (options.length === 1) {
                //     this.selectOption(index, options[0]); // ✅ use index
                // }

                this.otherCharges.newchargesData = rows;
            })
            .catch(error => {
                console.error('Apex Error:', JSON.stringify(error));
                row.isLoading = false;
                this.otherCharges.newchargesData = rows;
            });
    }


    fetchExperienceOptions(rowId, searchKey) {

        const rows = [...this.otherCharges.newchargesData];

        // ✅ Find index using rowId
        const index = rows.findIndex(r => r.id === rowId);

        if (index === -1) {
            console.error('Row not found for rowId:', rowId);
            return;
        }

        const row = rows[index];

        console.log('RowId:', rowId);
        console.log('Row Index:', index);
        console.log('Row Data:', JSON.stringify(row));

        row.isLoading = true;
        row.isDropdownOpen = true;

        fetchExperienceOptions({
            searchKey: searchKey,
            projectId: this.getProjectId,
            bu: row.childBusinessUnitskills,
            subBu: row.subBusinessUnit,
            subSkills: row.parentskillbusinessUnit,
            region: row.region,
            msaType: row.isMSA ? 'MSA' : 'Non MSA'
        })
            .then(result => {

                console.log('Apex Result Count:', result.length);
                console.log('Apex Result:', JSON.stringify(result));

                const options = result.map(rec => ({
                    label: rec.Name,
                    value: rec.Id,
                    className: 'slds-listbox__item'
                }));

                console.log('Mapped Options:', JSON.stringify(options));
                if (!options?.length) {
                    row.experienceId = null;
                    row.experienceName = '';
                }

                row.experienceOptions = options;
                row.isLoading = false;
                row.highlightIndex = -1;

                // 🔥 Auto-select if only 1
                // if (options.length === 1) {
                //     this.selectOptionexp(index, options[0]); // ✅ use index
                // }

                this.otherCharges.newchargesData = rows;
            })
            .catch(error => {
                console.error('Apex Error:', JSON.stringify(error));
                row.isLoading = false;
                this.otherCharges.newchargesData = rows;
            });
    }

    selectOptionexp(index, option) {

        const row = this.otherCharges.newchargesData[index];

        row.experienceId = option.value;
        row.experienceName = option.label;

        row.isDropdownOpen = false;
        this.refreshData();
        this.handlecalculateValues();
    }

    selectOption(index, option) {

        const row = this.otherCharges.newchargesData[index];

        row.skillCategoryMatrixId = option.value;
        row.skillCategoryMatrixName = option.label;

        row.isDropdownOpen = false;
        this.refreshData();
        this.handlecalculateValues();
    }

    handlexp(event) {

        const index = event.target.dataset.index;
        const selectedValue = event.detail.value;

        const row = this.otherCharges.newchargesData[index];

        // ✅ Find selected option using value
        const selectedOption = row.experienceOptions.find(
            opt => opt.value === selectedValue
        );

        row.experienceId = selectedValue;
        row.experienceName = selectedOption?.label;

        console.log('Selected Value:', selectedValue);
        console.log('Selected Label:', selectedOption?.label);



        //this.refreshData();
        this.handlecalculateValues();
        console.log('Full Row:', JSON.stringify(this.otherCharges.newchargesData[index]));
    }

    handleSkillChange(event) {

        const index = event.target.dataset.index;
        const selectedValue = event.detail.value;

        const row = this.otherCharges.newchargesData[index];

        // ✅ Find selected option using value
        const selectedOption = row.skillOptions.find(
            opt => opt.value === selectedValue
        );

        row.skillCategoryMatrixId = selectedValue;
        row.skillCategoryMatrixName = selectedOption?.label;

        console.log('Selected Value:', selectedValue);
        console.log('Selected Label:', selectedOption?.label);


        //this.refreshData();
        this.handlecalculateValues();
        console.log('Full Row:', JSON.stringify(this.otherCharges.newchargesData[index]));
    }


    // refreshData() {
    //     this.otherCharges.newchargesData = [...this.otherCharges.newchargesData];
    // }


    handleRowChange(event) {

        const rowId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.detail?.value ?? event.target.value;

        let shouldFetch = false;


        const updatedData = this.otherCharges.newchargesData.map(row => {

            if (row.id !== rowId) {
                return row;
            }

            const updatedRow = {
                ...row,
                [field]: value
            };

            // Status logic
            if (field === 'status') {
                updatedRow.isRemarksRequired = value === 'Resource Fulfilled';
                updatedRow.isLostRemarksRequired = value === 'Lost';
            }

            // MSA toggle reset
            // if (field === 'isMSA') {
            // updatedRow.region = null;
            // updatedRow.parentskillbusinessUnit = null;
            // updatedRow.subBusinessUnit = null;
            // updatedRow.childBusinessUnitskills = null;

            //     updatedRow.skillCategoryMatrixId = null;
            //     updatedRow.skillCategoryMatrixName = '';
            //     updatedRow.skillOptions = [];
            // }

            // ✅ mark for fetch AFTER update
            if (field === 'region' || field === 'childBusinessUnitskills' || field === 'childBusinessUnitskills' || field === 'isMSA') {
                shouldFetch = true;
                updatedRow.isRecalculation = true;

                // ✅ reset stale values immediately
                // updatedRow.sellingRate = 0;
                // updatedRow.nonMSASellingRate = 0;
                // updatedRow.msaRate = 0;
                // updatedRow.nonMsaRate = 0;
            }

            return updatedRow;
        });

        this.otherCharges.newchargesData = [...updatedData];

        // ✅ Call AFTER state update
        if (shouldFetch) {
            this.fetchSkillOptions(rowId, '');
            this.fetchExperienceOptions(rowId, '');
        }

        Promise.resolve().then(() => {
            this.handlecalculateValues();
        });
    }

    handleToggle(event) {

        const rowId = event.target.dataset.id;
        const isChecked = event.target.checked;
        const field = event.target.dataset.field;
        let shouldFetch = false;
        let updatedTargetRow = null;

        this.otherCharges.newchargesData = this.otherCharges.newchargesData.map(row => {

            if (row.id !== rowId) {
                return row;
            }

            // ✅ preserve base values
            const msaRate = Number(row.sellingRate) || 0;
            const nonMsaRate = Number(row.nonMSASellingRate) || 0;

            // ✅ ensure modified value exists
            const modifiedNonMsaRate =
                Number(row.modifiedNonMsaRate) || nonMsaRate;

            const updatedRow = {
                ...row,

                // ✅ flags
                isMSA: isChecked,
                isNonMSA: !isChecked,
                msaType: isChecked ? 'MSA' : 'Non MSA',

                // ⚠️ reset only dependent fields
                skillCategoryMatrixId: null,
                Skill_Category_Matrix__c: null,
                experienceId: null,
                Experience1__c: null,
                // ✅ KEEP ALL VALUES (do not lose data)
                sellingRate: 0,
                nonMSASellingRate: 0,
                modifiednonMSASellingRate: modifiedNonMsaRate,
                modifiedNonMsaRate: modifiedNonMsaRate
            };

            if (field === 'isMSA') {
                shouldFetch = true;
            }
            updatedTargetRow = updatedRow.id;

            return updatedRow;
        });

        // ✅ pass FULL ROW instead of rowId
        if (shouldFetch && updatedTargetRow) {
            this.fetchSkillOptions(updatedTargetRow, '');
            this.fetchExperienceOptions(updatedTargetRow, '');
        }

        Promise.resolve().then(() => {
            this.handlecalculateValues();
        });

    }

    handleRowChangeInput(event) {

        const rowId = event.target.dataset.id;
        const field = event.target.dataset.field;

        // 🔥 Always get latest value safely
        const value = event.detail?.value ?? event.target.value;

        // 🔥 Clone array to force reactivity
        const updatedData = this.otherCharges.newchargesData.map(row => {

            if (row.id !== rowId) {
                return row;
            }

            const updatedRow = {
                ...row,
                [field]: value
            };

            // ✅ Handle status logic
            if (field === 'status') {
                updatedRow.isRemarksRequired = value === 'Resource Fulfilled';
                updatedRow.isLostRemarksRequired = value === 'Lost';
            }

            return updatedRow;
        });

        // 🔥 Assign new reference (important for LWC reactivity)
        this.otherCharges.newchargesData = [...updatedData];

        // // 🔥 Ensure calculation runs on updated data (next tick safety)
        Promise.resolve().then(() => {
            this.handlecalculateValues();
        });
    }

    handleModificationSelection(event) {

        const selectedRecord = event.detail.selectedRecord;
        const action = event.detail.action;
        const rowIndex = parseInt(event.target.dataset.index, 10);

        const lookup = this.template.querySelector(
            `[data-field="skillCategoryMatrixId"][data-index="${rowIndex}"]`
        );

        if (lookup) {
            lookup.classList.remove('lookup-error');
        }


        console.log('Action:', action, 'Selected Record:', selectedRecord, 'at Index:', rowIndex);

        if (rowIndex === -1) {
            return;
        }

        if (action === 'Removed') {

            this.otherCharges.newchargesData[rowIndex] = {
                ...this.otherCharges.newchargesData[rowIndex],

                skillCategoryMatrixId: '',
                Skill_Category_Matrix__c: '',

                sellingRate: 0,
                nonMSASellingRate: 0,
                modifiednonMSASellingRate: 0,
                isMSA: false,
                isNonMSA: false,
                formattedNonMSASellingRate: '',
                formattedSellingRate: '',
                formattedMargin: '',
                rateCardLines: [],
                filteredRateCardLines: []
            };

        }
        else if (action === 'Added') {

            console.log('selectedRecord:', JSON.stringify(selectedRecord));

            this.otherCharges.newchargesData[rowIndex] = {

                ...this.otherCharges.newchargesData[rowIndex],

                skillCategoryMatrixId: selectedRecord.Id,
                Skill_Category_Matrix__c: selectedRecord.Id
            };
        }

        this.otherCharges.newchargesData = [
            ...this.otherCharges.newchargesData
        ];

        this.handlecalculateValues();

        console.log(
            'Updated Rows:',
            JSON.stringify(this.otherCharges.newchargesData)
        );
    }

    handleExperienceSelection(event) {

        const selectedRecord = event.detail.selectedRecord;
        const action = event.detail.action;
        const rowIndex = parseInt(event.target.dataset.index, 10);

        const lookup = this.template.querySelector(
            `[data-field="experienceId"][data-index="${rowIndex}"]`
        );

        if (lookup) {
            lookup.classList.remove('lookup-error');
        }


        console.log('Action:', action, 'Selected Record:', selectedRecord, 'at Index:', rowIndex);

        if (rowIndex === -1) {
            return;
        }

        if (action === 'Removed') {

            this.otherCharges.newchargesData[rowIndex] = {
                ...this.otherCharges.newchargesData[rowIndex],

                experienceId: '',
                Experience1__c: '',

                sellingRate: 0,
                nonMSASellingRate: 0,
                modifiednonMSASellingRate: 0,
                isMSA: false,
                isNonMSA: false,
                formattedNonMSASellingRate: '',
                formattedSellingRate: '',
                formattedMargin: '',
                rateCardLines: [],
                filteredRateCardLines: []
            };

        }
        else if (action === 'Added') {

            console.log('selectedRecord:', JSON.stringify(selectedRecord));

            this.otherCharges.newchargesData[rowIndex] = {

                ...this.otherCharges.newchargesData[rowIndex],

                experienceId: selectedRecord.Id,
                Experience1__c: selectedRecord.Id
            };
        }

        this.otherCharges.newchargesData = [
            ...this.otherCharges.newchargesData
        ];

        this.handlecalculateValues();

        console.log(
            'Updated Rows:',
            JSON.stringify(this.otherCharges.newchargesData)
        );
    }

    debounceSellingRateCall() {

        // clear existing timer
        if (this.rateDebounceTimer) {
            clearTimeout(this.rateDebounceTimer);
        }

        // wait before calling Apex
        this.rateDebounceTimer = setTimeout(() => {

            this.getSellingRateInformationCall();

        }, this.rateTimer || 100);

    }

    connectedCallback() {
        // alert('recordId: ' + this.recordId);
        if (this.recordId !== undefined) {
            this.showSpinner = true;
            this.getOppDetailsCall();
        }
    }

    renderedCallback() {
        if (this.modalInitialized) {
            return;
        }

        this.modalInitialized = true;

        const modal = document.querySelector('.slds-modal__container');

        if (modal) {
            modal.style.width = '80vw';
            modal.style.maxWidth = '90vw';
        }
    }
    @track isOppClosed = false;
    getOppDetailsCall() {
        this.showSpinner = true;
        getOppDetails({ oppId: this.recordId })
            .then(result => {
                //console.log('getOppDetails: ' + JSON.stringify(result));
                this.getBookingRecordInfo = result;
                console.log('getOppDetails: ' + JSON.stringify(this.getBookingRecordInfo));
                const stageName = this.getBookingRecordInfo.StageName;

                if (stageName === 'Closed Won' || stageName === 'Closed Lost') {
                    this.isOppClosed = true;
                } else {
                    this.isOppClosed = false;
                }
                this.getMasterDetailsCall();
            }).catch(error => {
                //console.log('getOppDetails Error: ' + JSON.stringify(error));
            })
    }

    buildAccordionHeader(row) {

        const seq = row.sequenceNo || '-';
        const bu = row.parentskillbusinessUnit || '-';
        const subBU = row.subBusinessUnit || '-';
        const subSkills = row.childBusinessUnitskills || '-';

        const exp = row.experience ? row.experience + 'Y' : '-';
        const res = row.numberOfResources || '-';
        const region = row.region || '-';

        const sales = row.salesUnit || '-';
        const duration = Number(row?.durationMonths) ? Number(row?.durationMonths) + 'M' : '-';

        const price = row.sellingRate || 0
            ? new Intl.NumberFormat('en-US').format(row.sellingRate)
            : '-';

        return `🔵 ${seq} | ${bu} > ${subBU} > ${subSkills} | Exp ${exp} | Res ${res} | ${region} |  ${sales} | ${duration}`;
    }

    toggleSection(event) {

        const clickedSection =
            event.currentTarget.closest('.slds-accordion__section');

        if (!clickedSection) return;

        const sections =
            this.template.querySelectorAll('.slds-accordion__section');

        const isOpen =
            clickedSection.classList.contains('slds-is-open');

        // close all
        sections.forEach(sec => sec.classList.remove('slds-is-open'));

        // open clicked
        if (!isOpen) {
            clickedSection.classList.add('slds-is-open');
        }

        this.allExpanded =
            [...sections].every(sec =>
                sec.classList.contains('slds-is-open')
            );
    }

    openSectionById(rowId, forceOpen = false) {

        const sections = this.template.querySelectorAll('.slds-accordion__section');

        let targetSection;

        sections.forEach(sec => {

            const sectionId = sec.getAttribute('data-toggle');

            // Close all sections first
            sec.classList.remove('slds-is-open');

            // Find target section
            if (sectionId === rowId) {
                targetSection = sec;
            }
        });

        if (targetSection) {

            if (forceOpen || !targetSection.classList.contains('slds-is-open')) {
                targetSection.classList.add('slds-is-open');
            }

        }

        this.allExpanded = false;
    }
    handleToggleAccordion() {

        const allSections = this.template.querySelectorAll('.slds-accordion__section');

        if (this.allExpanded) {
            // Collapse all
            allSections.forEach(section => {
                section.classList.remove('slds-is-open');
            });
            this.allExpanded = false;
        } else {
            // Expand all
            allSections.forEach(section => {
                section.classList.add('slds-is-open');
            });
            this.allExpanded = true;
        }
    }

    createRow(wrapper, index) {

        const rec = wrapper?.rliRecord || {};

        const numberOfResources = rec.Number_of_Resources__c || 0;
        const sellingRate = rec.Selling_Rate__c || 0;
        const nonMSASellingRate = rec.Sales_Selling_Rate__c || 0;
        const durationMonths = rec.Duration_Months__c || 0;
        const durationMonthsCalculated = rec.Duration_Months_Calculated_c__c || 0;
        const convertedUnits = Number(wrapper?.convertedUnits) || 0;
        // const margin = (rec.Sales_Selling_Rate__c ?? 0) - (rec.Selling_Rate__c ?? 0);
        const margin =
            rec.Sales_Selling_Rate__c
                ? rec.Sales_Selling_Rate__c - (rec.Selling_Rate__c ?? 0)
                : 0;

        const projectedRevenue = numberOfResources * sellingRate * convertedUnits;

        // 🔹 Currency (single source of truth)
        const currencyIsoCode =
            wrapper?.rateCardLines?.[0]?.CurrencyIsoCode ||
            rec.CurrencyIsoCode ||
            rec.Related_Opportunity__r?.CurrencyIsoCode ||
            'INR';

        const row = {

            sequenceNo: wrapper?.sequenceNo || index + 1,
            id: rec.Id ? rec.Id : 'temp_' + index,
            recordExists: wrapper?.recordExists || false,

            parentskillbusinessUnit: rec.Sub_Skills__c || '',
            subBusinessUnit: rec.Sub_Business_Unit__c || '',
            childBusinessUnitskills: rec.Business_Unit__c || '',

            // category: rec.Category__c || '',
            // skillFunctionalArea: rec.Skill_Functional_Area__c || '',
            skillCategoryMatrixId: rec.Skill_Category_Matrix__c || '',
            skillCategoryMatrixName: rec.Skill_Category_Matrix__r?.Name || '',

            experienceId: rec.Experience1__c || '',
            experienceName: rec.Experience1__r?.Name || '',

            numberOfResources,
            tentativeStartDate: rec.Tentative_Start_Date__c || '',
            billingStartDate: rec.Billing_Start_Date__c || '',

            region: rec.Region__c || '',
            salesUnit: rec.Sales_Unit__c || 'Monthly',

            durationMonths,
            durationMonthsCalculated: rec.Duration_Months_Calculated_c__c || 0,
            convertedUnits: wrapper?.convertedUnits || 0,

            sellingRate,
            nonMSASellingRate,
            modifiednonMSASellingRate: nonMSASellingRate,
            isMSA: rec.MSA_Customer__c || false,
            isNonMSA: !rec.MSA_Customer__c || rec.Sales_Selling_Rate__c != null || false,
            margin,

            projectedRevenue,

            // 🔹 ALWAYS use computed currencyIsoCode
            formattedSellingRate:
                this.formatCurrency(sellingRate, currencyIsoCode),

            formattedMargin:
                this.formatCurrency(margin, currencyIsoCode),

            formattedNonMSASellingRate:
                this.formatCurrency(nonMSASellingRate, currencyIsoCode),

            formattedProjectedRevenue:
                this.formatCurrency(projectedRevenue, currencyIsoCode),

            status: rec.Status__c || 'Resource To Be Identified',

            engineerName: rec.Engineer_Name__c || '',
            remarks: rec.Remarks__c || '',
            lostremarks: rec.Lost_Remarks__c || '',
            lostreasonvalue: rec.Lost_Reason__c || '',

            isRemarksRequired: rec.Status__c === 'Resource Fulfilled',
            isLostRemarksRequired: rec.Status__c === 'Lost',

            currencyIsoCode,

            relatedOpportunityId:
                rec.Related_Opportunity__c || this.recordId,

            subBUOptions: [],
            childBUSkillsOptions: [],
            skillOptions: [],
            isDropdownOpen: false,
            isLoading: false,
            focusIndex: -1,

            isEditable: this.isOppClosed || false
        };

        row.headerLabel = this.buildAccordionHeader(row);

        console.log('Row created', JSON.stringify(row));

        return row;
    }

    setOpportunityDefaults() {

        const firstRow = this.otherCharges.newchargesData[0] || {};

        this.oppDefaults = {

            parentskillbusinessUnit: firstRow.parentskillbusinessUnit || '',
            subBusinessUnit: firstRow.subBusinessUnit || '',
            childBusinessUnitskills: firstRow.childBusinessUnitskills || '',

            region: firstRow.region || '',
            salesUnit: firstRow.salesUnit || 'Monthly',

            currencyIsoCode: firstRow.currencyIsoCode || 'INR',

            relatedOpportunityId: this.recordId,

            status: 'Resource To Be Identified',

            sellingRate: 0,

            nonMSASellingRate: 0,
            modifiednonMSASellingRate: 0,
            isMSA: false,
            isNonMSA: false,
        };
    }


    getMasterDetailsCall() {

        getMasterDetails({ opportunityId: this.recordId })
            .then(result => {

                this.otherCharges.originalData = {};
                this.otherCharges.newchargesData = [];

                console.log('RLI result:' + JSON.stringify(result));

                if (result?.length) {

                    result.forEach((wrapper, index) => {

                        const row = this.createRow(wrapper, index);

                        // ✅ Ensure currency always present
                        const currency = row.currencyIsoCode || 'INR';

                        // ✅ SET BASE VALUES (IMPORTANT)
                        row.msaRate = parseFloat(row.sellingRate) || 0;
                        row.nonMsaRate = parseFloat(row.nonMSASellingRate) || 0;

                        // ✅ Ensure flags
                        row.isNonMSA = !row.isMSA;

                        // =========================
                        // 🔥 GENERIC CALCULATION
                        // =========================
                        this.calculateRowValues(row);

                        /* -------- Business Unit → Sub BU dependency -------- */

                        if (row.parentskillbusinessUnit && this.subBUValues && this.childBUValues) {

                            const controllingKey =
                                this.subBUValues.controllerValues[row.parentskillbusinessUnit];

                            row.subBUOptions =
                                this.subBUValues.values
                                    .filter(opt => opt.validFor.includes(controllingKey))
                                    .map(opt => ({
                                        label: opt.label,
                                        value: opt.value
                                    }));

                            if (row.subBusinessUnit) {

                                const controllingSkillsKey =
                                    this.childBUValues.controllerValues[row.subBusinessUnit];

                                row.childBUSkillsOptions =
                                    this.childBUValues.values
                                        .filter(opt => opt.validFor.includes(controllingSkillsKey))
                                        .map(opt => ({
                                            label: opt.label,
                                            value: opt.value
                                        }));
                            }
                        }

                        // 🔥 Inject selected Skill into options
                        if (row.skillCategoryMatrixId && row.skillCategoryMatrixName) {
                            row.skillOptions = [
                                {
                                    label: row.skillCategoryMatrixName,
                                    value: row.skillCategoryMatrixId
                                }
                            ];
                        }

                        // 🔥 Inject selected Experience into options
                        if (row.experienceId && row.experienceName) {
                            row.experienceOptions = [
                                {
                                    label: row.experienceName,
                                    value: row.experienceId
                                }
                            ];
                        }

                        row.headerLabel = this.buildAccordionHeader(row);

                        this.otherCharges.originalData[row.id] = row;
                        this.otherCharges.newchargesData.push({ ...row });

                    });

                } else {

                    const row = this.createRow({}, 0);

                    const currency = row.currencyIsoCode || 'INR';

                    // ✅ SET BASE VALUES
                    row.msaRate = parseFloat(row.sellingRate) || 0;
                    row.nonMsaRate = parseFloat(row.nonMSASellingRate) || 0;

                    row.isNonMSA = !row.isMSA;

                    // =========================
                    // 🔥 GENERIC CALCULATION
                    // =========================
                    this.calculateRowValues(row);

                    this.otherCharges.originalData[row.id] = row;
                    this.otherCharges.newchargesData.push({ ...row });
                }

                /* ---- Open first section ---- */

                if (this.otherCharges.newchargesData.length > 0) {

                    const firstRowId = this.otherCharges.newchargesData[0].id;

                    setTimeout(() => {
                        if (!this.otherCharges.newchargesData[0].recordExists) {
                            this.openSectionById(firstRowId);
                        }
                    }, 0);
                }

                /* ---- Opportunity Defaults ---- */

                this.setOpportunityDefaults();
                this.showSpinner = false;
                this.handlecalculateValues();

            })
            .catch(error => {
                console.error('getMasterDetails Error:' + this.parseError(error));
                const errorMessage = this.parseError(error);
                this.showErrorToast('Error', errorMessage);
                this.showSpinner = false;

            });
    }


    calculateRowValues(row) {
        console.log('InsideCalculatedRowBefore: ' + JSON.stringify(row));

        const resources = Number(row?.numberOfResources);
        const duration = Number(row?.durationMonths);
        const durationMonthsCalculated = Number(row?.durationMonthsCalculated);
        const convertedUnits = Number(row?.convertedUnits);

        const safeResources = isNaN(resources) ? 0 : resources;
        const safeDuration = isNaN(convertedUnits) ? 0 : convertedUnits;

        const currency = row?.currencyIsoCode || 'INR';

        const msaRate = Number(row?.msaRate ?? row?.sellingRate) || 0;

        const baseNonMsaRate =
            Number(row?.nonMsaRate ?? row?.nonMSASellingRate) || 0;

        // ✅ FIX: don't use || here
        const modifiedNonMsaRate = row?.nonMSASellingRate !== null && row?.nonMSASellingRate !== undefined ? Number(row.nonMSASellingRate) : baseNonMsaRate;

        const originalSellingRate = Number(row?.sellingRate) || 0;

        row.isMSA = Boolean(row?.isMSA);
        row.isNonMSA = !row.isMSA;

        let effectiveRate = 0;

        if (row.isMSA) {

            row.sellingRate = msaRate;
            row.nonMSASellingRate = 0;
            row.margin = 0;

            effectiveRate = msaRate;

        } else if (row.isNonMSA && row.recordExists) {
            //row.sellingRate = row?.nonMSASellingRate || 0;
            // const margin = modifiedNonMsaRate - originalSellingRate;
            // row.margin = margin ? margin : 0;
            const margin =
                row.nonMSASellingRate != null
                    ? modifiedNonMsaRate - originalSellingRate
                    : 0;

            row.margin = margin;
            row.sellingRate = row.msaRate;
            effectiveRate = modifiedNonMsaRate || row.msaRate || row.sellingRate;
        } else if (row.isNonMSA && row.recordExists === false) {
            console.log('insidenonmsa: ' + JSON.stringify(row.nonMsaRate));
            row.sellingRate = row.nonMsaRate || 0;
            // const margin = (modifiedNonMsaRate - originalSellingRate) || 0;
            // row.margin = margin != null ? margin : 0;
            const margin =
                row.nonMsaRate != null
                    ? modifiedNonMsaRate - row.nonMsaRate
                    : 0;

            row.margin = margin;
            if (modifiedNonMsaRate > 0) {
                effectiveRate = modifiedNonMsaRate;
            } else {
                effectiveRate = row.nonMsaRate || row.msaRate;
            }
        }
        // console.log('effectiveRate: ' + JSON.stringify(effectiveRate));
        // console.log('row.sellingRate: ' + JSON.stringify(row.sellingRate));
        // console.log('modifiedNonMsaRate: ' + JSON.stringify(modifiedNonMsaRate));
        row.projectedRevenue = safeResources * effectiveRate * safeDuration;
        console.log('projectedRevenue: ' + JSON.stringify(row.projectedRevenue));
        row.formattedSellingRate = this.formatCurrency(row.sellingRate || 0, currency);

        row.formattedNonMSASellingRate = this.formatCurrency(modifiedNonMsaRate || 0, currency);

        row.formattedProjectedRevenue = this.formatCurrency(row.projectedRevenue || 0, currency);

        row.formattedMargin =
            row.margin != null
                ? this.formatCurrency(row.margin, currency)
                : '';

        row.headerLabel = this.buildAccordionHeader(row);

        console.log('InsideCalculatedRow: ' + JSON.stringify(row));



        return row;
    }
    handleAddRow() {

        const rows = this.otherCharges.newchargesData;
        const lastRow = rows.length ? rows[rows.length - 1] : {};

        const newRow = {
            id: 'temp_' + Date.now(),
            sequenceNo: rows.length + 1,
            recordExists: false,

            parentskillbusinessUnit: lastRow.parentskillbusinessUnit || this.oppDefaults?.parentskillbusinessUnit || '',
            subBusinessUnit: lastRow.subBusinessUnit || this.oppDefaults?.subBusinessUnit || '',
            childBusinessUnitskills: lastRow.childBusinessUnitskills || this.oppDefaults?.childBusinessUnitskills || '',

            category: '',
            skillFunctionalArea: '',
            experience: '',
            skillCategoryMatrixId: '',
            experienceId: '',

            numberOfResources: 0,

            tentativeStartDate: '',
            billingStartDate: '',

            region: '',
            regionGroup: '',
            salesUnit: 'Monthly',

            durationMonths: 0,
            durationMonthsCalculated: 0,
            convertedUnits: 0,

            sellingRate: 0,
            nonMSASellingRate: 0,
            modifiednonMSASellingRate: 0,
            isMSA: false,
            isNonMSA: true,
            projectedRevenue: 0,

            status: 'Resource To Be Identified',

            engineerName: '',
            remarks: '',
            lostremarks: '',
            lostreasonvalue: '',
            isRemarksRequired: false,
            isLostRemarksRequired: false,

            currencyIsoCode: lastRow.currencyIsoCode || this.oppDefaults?.currencyIsoCode || '',

            relatedOpportunityId: this.recordId,

            subBUOptions: [],
            childBUSkillsOptions: [],
            skillOptions: [],
            isDropdownOpen: false,
            isLoading: false,
            focusIndex: -1,
            isRecalculation: true,

            isEditable: this.isOppClosed || false
        };

        /* ---------- Business Unit → Sub BU ---------- */

        if (newRow.parentskillbusinessUnit && this.subBUValues) {

            const controllingKey =
                this.subBUValues.controllerValues[newRow.parentskillbusinessUnit];

            newRow.subBUOptions = this.subBUValues.values
                .filter(opt => opt.validFor.includes(controllingKey))
                .map(opt => ({
                    label: opt.label,
                    value: opt.value
                }));
        }

        /* ---------- Sub BU → Sub BU Skills ---------- */

        if (newRow.subBusinessUnit && this.childBUValues) {

            const controllingKey =
                this.childBUValues.controllerValues[newRow.subBusinessUnit];

            newRow.childBUSkillsOptions = this.childBUValues.values
                .filter(opt => opt.validFor.includes(controllingKey))
                .map(opt => ({
                    label: opt.label,
                    value: opt.value
                }));
        }

        /* ---------- Category → Skill ---------- */

        // if (newRow.category && this.skillValues) {

        //     const controllingKey =
        //         this.skillValues.controllerValues[newRow.category];

        //     newRow.skillOptions = this.skillValues.values
        //         .filter(opt => opt.validFor.includes(controllingKey))
        //         .map(opt => ({
        //             label: opt.label,
        //             value: opt.value
        //         }));
        // }


        this.otherCharges.newchargesData = [...rows, newRow];

        //this.activeTabValue = newRow.id;

        console.log('Added new RLI:', JSON.stringify(newRow));
        this.handlecalculateValues();
        const newRowId = newRow.id; // or whatever id you use

        // Wait for DOM to render
        setTimeout(() => {
            this.openSectionById(newRowId, true);
        }, 0);

        //this.showCalculate = true;
    }

    handleRemoveRow(event) {
        event.stopPropagation();

        const rowId = event.currentTarget.dataset.id;
        const recordExists = event.currentTarget.dataset.exists === 'true';


        const currentIndex = this.otherCharges.newchargesData.findIndex(
            row => row.id === rowId
        );

        if (currentIndex === -1) {
            return;
        }
        const isSalesforceRecord = rowId && rowId.length >= 15 && !rowId.startsWith('temp');


        // 🔥 CASE 1: Record exists in Salesforce → delete from DB
        // if (isSalesforceRecord && recordExists) {
        //     deleteRecord(rowId)
        //         .then(() => {
        //             this.removeRowFromUI(currentIndex);
        //         })
        //         .catch(error => {
        //             console.error('Delete Error:', error);
        //         });
        // }
        // // 🔥 CASE 2: Only UI record
        // else {
        //     this.removeRowFromUI(currentIndex);
        // }
        if (isSalesforceRecord) {
            if (!confirm('Are you sure you want to delete this record from Salesforce?')) {
                return;
            }

            deleteRecord(rowId)
                .then(() => {
                    this.removeRowFromUI(currentIndex);

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Deleted',
                            message: 'Record deleted successfully',
                            variant: 'success'
                        })
                    );
                })
                .catch(error => {
                    console.error('Delete Error:', error);

                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: error.body?.message || 'Delete failed',
                            variant: 'error'
                        })
                    );
                });

        } else {
            // 🔥 No confirmation for UI-only rows
            this.removeRowFromUI(currentIndex);
        }

    }

    removeRowFromUI(currentIndex) {
        this.otherCharges.newchargesData.splice(currentIndex, 1);

        this.otherCharges.newchargesData = this.otherCharges.newchargesData.map((row, index) => {
            return {
                ...row,
                sequenceNo: index + 1
            };
        });

        if (this.otherCharges.newchargesData.length > 0) {
            const newIndex = currentIndex > 0 ? currentIndex - 1 : 0;
            this.activeTabValue = this.otherCharges.newchargesData[newIndex].id;
        } else {
            this.activeTabValue = null;
        }

        this.otherCharges.newchargesData = [...this.otherCharges.newchargesData];

        this.handlecalculateValues();
    }

    get currencyTotals() {
        return this.otherCharges.modifiedDataInStringFormat.currencyTotals || [];
    }

    handlecalculateValues() {

        let totalResources = 0;
        const currencyTotals = {};

        const modifiedRows = this.otherCharges.newchargesData.map((item, index) => {

            const updatedRow = this.calculateRowValues({ ...item });

            updatedRow.sequenceNo = index + 1;

            const resources = Number(updatedRow.numberOfResources) || 0;
            const currency = updatedRow.currencyIsoCode || 'INR';

            totalResources += resources;

            if (!currencyTotals[currency]) {
                currencyTotals[currency] = {
                    totalSellingRate: 0,
                    totalProjectedRevenue: 0,
                    rowCount: 0
                };
            }

            if (resources > 0) {
                currencyTotals[currency].totalSellingRate += updatedRow.sellingRate;
                currencyTotals[currency].totalProjectedRevenue += updatedRow.projectedRevenue;
                currencyTotals[currency].rowCount++;
            }

            return updatedRow;
        });

        this.otherCharges.modifiedData = {
            rows: modifiedRows,
            totalResources,
            currencyTotals
        };

        const formattedCurrencyTotals = Object.keys(currencyTotals).map(curr => {

            const bucket = currencyTotals[curr];

            const avg =
                bucket.rowCount > 0
                    ? bucket.totalSellingRate / bucket.rowCount
                    : 0;

            return {
                currency: curr,
                totalSellingRate:
                    this.formatCurrency(bucket.totalSellingRate, curr),

                totalProjectedRevenue:
                    this.formatCurrency(bucket.totalProjectedRevenue, curr)

                // averageSellingRate:
                //     this.formatCurrency(avg, curr)
            };

        });

        const firstCurrency = Object.keys(currencyTotals)[0] || 'INR';
        const firstBucket = currencyTotals[firstCurrency] || {
            totalSellingRate: 0,
            totalProjectedRevenue: 0,
            rowCount: 0
        };

        this.otherCharges.modifiedDataInStringFormat = {
            rows: modifiedRows,

            totalResources,

            totalSellingRate:
                this.formatCurrency(firstBucket.totalSellingRate, firstCurrency),

            totalProjectedRevenue:
                this.formatCurrency(firstBucket.totalProjectedRevenue, firstCurrency),

            currencyTotals: formattedCurrencyTotals,
        };

        this.debounceSellingRateCall();
    }

    getSellingRateInformationCall() {

        const rowsForApex = (this.otherCharges?.newchargesData || []).map((row, index) => {
            return {
                rliRecord: {
                    Id: row?.id || ('temp_' + index),
                    Sub_Skills__c: row?.parentskillbusinessUnit || null,
                    Sub_Business_Unit__c: row?.subBusinessUnit || null,
                    Business_Unit__c: row?.childBusinessUnitskills || null,
                    Category__c: row?.category || null,
                    Skill_Functional_Area__c: row?.skillFunctionalArea || null,
                    Region__c: row?.region || null,
                    Sales_Unit__c: row?.salesUnit || null,
                    Selling_Rate__c: row?.sellingRate ?? 0,
                    Sales_Selling_Rate__c: row?.nonMSASellingRate ?? 0,
                    CurrencyIsoCode: row?.currencyIsoCode || 'INR',
                    Duration_Months__c: Number(row?.durationMonths) ?? 0,
                    Status__c: row?.status || null,
                    Engineer_Name__c: row?.engineerName || null,
                    Tentative_Start_Date__c: row?.tentativeStartDate || null,
                    Billing_Start_Date__c: row?.billingStartDate || null,
                    Number_of_Resources__c: row?.numberOfResources ?? 0,
                    Skill_Category_Matrix__c: row?.skillCategoryMatrixId || null,
                    Experience1__c: row?.experienceId || null,
                    Opportunity__c: this.recordId,
                    Remarks__c: row?.isRemarksRequired ? row?.remarks : null,
                    Lost_Remarks__c: row?.isLostRemarksRequired ? row?.lostremarks : null,
                    Lost_Reason__c: row?.isLostRemarksRequired ? row?.lostreasonvalue : null,
                },
                sequenceNo: row?.sequenceNo ?? index,
                recordExists: Boolean(row?.recordExists),
                isMSA: Boolean(row?.isMSA),
                isNonMSA: Boolean(row?.isNonMSA),
                isRecalculation: Boolean(row.isRecalculation),
                convertedUnits: row?.convertedUnits,
            };
        });

        getSellingRateInformation({
            rows: rowsForApex,
            opportunityId: this.recordId
        })
            .then(result => {

                const resultMap = new Map();

                (result || []).forEach(wrap => {
                    if (wrap?.rliRecord?.Id) {
                        resultMap.set(String(wrap.rliRecord.Id), wrap);
                    }
                    if (wrap?.sequenceNo !== undefined) {
                        resultMap.set(String(wrap.sequenceNo), wrap);
                    }
                });

                (this.otherCharges?.newchargesData || []).forEach(row => {

                    const wrap =
                        resultMap.get(String(row?.id)) ||
                        resultMap.get(String(row?.sequenceNo));
                    console.log('wrap: ' + JSON.stringify(wrap));
                    console.log('rowAfterAPex: ' + JSON.stringify(row));


                    let msaRate = wrap?.sellingRate ?? row?.sellingRate ?? 0;
                    let nonMsaRate = row?.nonMSASellingRate ?? 0;

                    if (wrap?.rateCardLines?.length > 0) {

                        const msaCard = wrap.rateCardLines.find(r => r?.Rate_Card__r?.Type__c === 'MSA');
                        const nonMsaCard = wrap.rateCardLines.find(r => r?.Rate_Card__r?.Type__c === 'Non MSA');

                        msaRate = Number(msaCard?.Rate_Amount__c) || msaRate;
                        nonMsaRate = Number(nonMsaCard?.Rate_Amount__c) || nonMsaRate;

                        row.currencyIsoCode =
                            msaCard?.CurrencyIsoCode ||
                            nonMsaCard?.CurrencyIsoCode ||
                            'INR';

                    }

                    // ✅ store base values
                    row.msaRate = msaRate || wrap?.sellingRate;
                    row.nonMsaRate = nonMsaRate || wrap?.nonMSASellingRate;
                    row.convertedUnits = wrap?.convertedUnits || row?.durationMonths || 0;
                    // if (wrap?.convertedUnits != null) {
                    //     row.convertedUnits = parseFloat(wrap?.convertedUnits).toFixed(2);
                    // }


                    // ✅ CALL GENERIC METHOD
                    this.calculateRowValues(row);

                });


                this.otherCharges.newchargesData = [
                    ...(this.otherCharges?.newchargesData || [])
                ];
                console.log('final Data inside selling: ' + JSON.stringify(this.otherCharges.newchargesData));

            }).catch(error => {
                console.error(error);
                const errorMessage = this.parseError(error);
                this.showErrorToast('Error', errorMessage);
                this.showSpinner = false;
            });
    }

    formatCurrency(amount, currency) {

        const value = amount ?? 0;
        const safeCurrency = currency || 'INR';

        return new Intl.NumberFormat('en-IN', {
            style: 'currency',
            currency: safeCurrency,
            minimumFractionDigits: 2
        }).format(value);

    }

    validateFields() {

        let isValid = true;
        let matrixErrorRows = [];
        let matrixErrorRowsExp = [];
        let lostErrorRows = [];
        let fulfilledErrorRows = [];


        this.otherCharges.newchargesData.forEach((row, index) => {
            // Console.log('row: ' + JSON.stringify(row));

            if (row.skillCategoryMatrixId === null || row.skillCategoryMatrixId === undefined || row.skillCategoryMatrixId === '') {

                const lookup = this.template.querySelector(
                    `[data-field="skillCategoryMatrixId"][data-index="${index}"]`
                );

                if (lookup) {
                    lookup.classList.add('lookup-error');
                    matrixErrorRows.push(row.sequenceNo);
                }

                isValid = false;
            }
            // Console.log('row.experienceId: ' + JSON.stringify(row.experienceId));
            if (row.experienceId === null || row.experienceId === undefined || row.experienceId === '') {

                const lookup = this.template.querySelector(
                    `[data-field="experienceId"][data-index="${index}"]`
                );

                if (lookup) {
                    lookup.classList.add('lookup-error');
                    matrixErrorRowsExp.push(row.sequenceNo);
                }

                isValid = false;
            }

            // LOST Validation
            if (row.status === 'Lost') {

                if (!row.lostreasonvalue || !row.lostremarks || row.lostremarks.trim() === '') {

                    lostErrorRows.push(row.sequenceNo);

                    // highlight fields
                    this.highlightField(index, 'lostreasonvalue');
                    this.highlightField(index, 'lostremarks');

                    isValid = false;
                }
            }

            // RESOURCE FULFILLED Validation
            if (row.status === 'Resource Fulfilled') {

                if (!row.engineerName) {

                    fulfilledErrorRows.push(row.sequenceNo);

                    // highlight fields
                    // this.highlightField(index, 'remarks');
                    this.highlightField(index, 'engineerName');

                    isValid = false;
                }
            }


            this.checkField(row.parentskillbusinessUnit, index, 'parentskillbusinessUnit', 'Business Unit is required');
            this.checkField(row.subBusinessUnit, index, 'subBusinessUnit', 'Sub Business Unit is required');
            if (!(row.subBusinessUnit === 'Tester Rental' && !row.childBusinessUnitskills)) {
                this.checkField(
                    row.childBusinessUnitskills,
                    index,
                    'childBusinessUnitskills',
                    'Sub Business Unit Skills is required'
                );
            }
            // this.checkField(row.childBusinessUnitskills, index, 'childBusinessUnitskills', 'Sub Business Unit Skills is required');
            this.checkField(row.region, index, 'region', 'Region is required');
            this.checkField(row.salesUnit, index, 'salesUnit', 'Sales Unit is required');
            this.checkField(row.durationMonths, index, 'durationMonths', 'Duration Months is required');
            this.checkField(row.status, index, 'status', 'Status is required');
            this.checkField(row.billingStartDate, index, 'billingStartDate', 'Billing Start Date is required');
            this.checkField(row.numberOfResources, index, 'numberOfResources', 'Number of Resources is required');



            if (!row.recordExists && (
                !row.parentskillbusinessUnit ||
                !row.subBusinessUnit ||
                (row.subBusinessUnit !== 'Tester Rental' && !row.childBusinessUnitskills) ||
                !row.region ||
                !row.salesUnit ||
                !row.durationMonths ||
                !row.numberOfResources ||
                !row.status ||
                !row.billingStartDate)
            ) {
                isValid = false;
            }

        });
        if (matrixErrorRows.length) {
            this.showErrorToast(
                'Error',
                `Skill Category Matrix is required for Resource Line Item(s): ${matrixErrorRows.join(', ')}`
            );
        }
        if (matrixErrorRowsExp.length) {
            this.showErrorToast(
                'Error',
                `Experience is required for Resource Line Item(s): ${matrixErrorRowsExp.join(', ')}`
            );
        }

        if (lostErrorRows.length) {
            this.showErrorToast(
                'Error',
                `Lost Reason and Lost Remarks are required for Resource Line Item(s): ${lostErrorRows.join(', ')}`
            );
        }

        if (fulfilledErrorRows.length) {
            this.showErrorToast(
                'Error',
                `Resource Name are required for Resource Fulfilled Resource Line Item(s): ${fulfilledErrorRows.join(', ')}`
            );
        }

        return isValid;
    }

    highlightField(index, fieldName) {
        const field = this.template.querySelector(
            `[data-field="${fieldName}"][data-index="${index}"]`
        );
        if (field) {
            field.classList.add('lookup-error');
        }
    }

    checkField(value, index, fieldName, message) {

        const field = this.template.querySelector(
            `[data-field="${fieldName}"][data-index="${index}"]`
        );

        if (!field) return;

        if (!value) {
            field.setCustomValidity(message);
            //this.redirecttofield(fieldName, index);
            //this.showErrorToast('Error', 'Please fill all the required fields');

        } else {
            field.setCustomValidity('');
        }

        field.reportValidity();
    }
    get resourceOptions() {
        return this.otherCharges.newchargesData.map(row => ({
            label: `${row.sequenceNo} - ${row.parentskillbusinessUnit} - ${row.status} `,
            value: row.id
        }));
    }
    get showSellingRateHelp() {
        return this.otherCharges?.newchargesData?.some(
            row => !row.sellingRate || row.sellingRate === 0
        );
    }

    handleJumpSelect(event) {
        const id = event.detail.value;

        this.openSectionById(id, true);

        setTimeout(() => {
            const el = this.template.querySelector(`[data-toggle="${id}"]`);
            if (el) {
                el.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
        }, 50);
    }

    buildSaveSummaryMessage(result) {

        if (!result || !result.length) {
            return 'No records processed';
        }

        let createdCount = 0;
        let updatedCount = 0;

        result.forEach(row => {
            if (row.isNewRecordCreated) {
                createdCount++;
            } else {
                updatedCount++;
            }
        });

        let messageParts = [];

        if (createdCount > 0) {
            messageParts.push(`${createdCount} Resource Line Item${createdCount > 1 ? 's' : ''} created`);
        }

        if (updatedCount > 0) {
            messageParts.push(`${updatedCount} Resource Line Item${updatedCount > 1 ? 's' : ''} updated`);
        }

        return messageParts.join(', ');
    }

    handleSave() {

        const isValid = this.validateFields();

        console.log('Inside Save - isValid:', isValid);

        if (!isValid) {
            console.log('❌ Validation failed - stopping save');
            return;
        }

        this.showSpinner = true;

        console.log('📦 Raw UI Data:', JSON.stringify(this.otherCharges.newchargesData));

        const rowsForApex = this.otherCharges.newchargesData.map((row, index) => {

            const payload = {
                rliRecord: {
                    Id: row.id || ('temp_' + index),

                    Sub_Skills__c: row.parentskillbusinessUnit || null,
                    Sub_Business_Unit__c: row.subBusinessUnit || null,
                    Business_Unit__c: row.childBusinessUnitskills || null,
                    // Category__c: row.category || null,
                    // Skill_Functional_Area__c: row.skillFunctionalArea || null,
                    Region__c: row.region || null,
                    Sales_Unit__c: row.salesUnit || null,

                    // ✅ safer numeric handling
                    Selling_Rate__c: Number(row.sellingRate) || 0,
                    Sales_Selling_Rate__c: Number(row.nonMSASellingRate) || 0,

                    CurrencyIsoCode: row.currencyIsoCode || 'INR',

                    Duration_Months__c: Number(row.durationMonths) || 0,
                    Status__c: row.status || null,
                    Engineer_Name__c: row.engineerName || null,
                    Tentative_Start_Date__c: row.tentativeStartDate || null,
                    Billing_Start_Date__c: row.billingStartDate || null,
                    Number_of_Resources__c: Number(row.numberOfResources) || 0,

                    Skill_Category_Matrix__c: row.skillCategoryMatrixId || null,
                    Experience1__c: row.experienceId || null,
                    Opportunity__c: this.recordId,

                    Remarks__c: row.isRemarksRequired ? row.remarks : null,
                    Lost_Remarks__c: row.isLostRemarksRequired ? row.lostremarks : null,
                    Lost_Reason__c: row.isLostRemarksRequired ? row.lostreasonvalue : null,

                    // ✅ FIXED (important)
                    MSA_Customer__c: row.isMSA === true
                },

                sequenceNo: row.sequenceNo ?? index,
                recordExists: Boolean(row.recordExists),
                isMSA: Boolean(row.isMSA),
                isNonMSA: Boolean(row.isNonMSA)
            };

            // 🔍 Row level debug
            console.log(`🧾 Row ${index} Payload:`, JSON.stringify(payload));

            return payload;
        });

        console.log('🚀 Final Payload to Apex:', JSON.stringify(rowsForApex));

        saveDetails({
            rows: rowsForApex,
            opportunityId: this.recordId
        })
            .then(result => {

                console.log('✅ saveDetails Result:', JSON.stringify(result));

                const message = this.buildSaveSummaryMessage(result);
                this.showSuccessToast('Success', message);

                setTimeout(() => {
                    this.showSpinner = false;
                    location.replace('/' + this.recordId);
                }, 2000);
            })
            .catch(error => {

                console.log('❌ saveDetails Error:', JSON.stringify(error));

                const errorMessage = this.parseError(error);
                this.showErrorToast('Error', errorMessage);

                this.showSpinner = false;
            });
    }

    parseError(error) {

        let messages = [];

        try {

            if (!error) {
                return 'Unknown error';
            }

            // Handle array errors
            if (Array.isArray(error)) {
                error.forEach(e => {
                    if (e?.message) messages.push(e.message);
                    if (e?.body?.message) messages.push(e.body.message);
                });
            }

            // Apex errors
            if (error?.body?.message) {
                messages.push(error.body.message);
            }

            // UI API errors
            if (error?.body?.output?.errors) {
                error.body.output.errors.forEach(e => messages.push(e.message));
            }

            // Field errors
            if (error?.body?.output?.fieldErrors) {
                Object.values(error.body.output.fieldErrors).forEach(fieldErr => {
                    fieldErr.forEach(e => messages.push(e.message));
                });
            }

            // Page errors
            if (error?.body?.pageErrors) {
                error.body.pageErrors.forEach(e => messages.push(e.message));
            }

            // JS error
            if (error?.message && messages.length === 0) {
                messages.push(error.message);
            }

            // Clean Salesforce DML validation messages
            messages = messages.map(msg => {

                if (msg.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
                    msg = msg.split('FIELD_CUSTOM_VALIDATION_EXCEPTION,')[1];
                }

                if (msg.includes('FIELD_FILTER_VALIDATION_EXCEPTION')) {
                    msg = msg.split('FIELD_FILTER_VALIDATION_EXCEPTION,')[1];
                }

                if (msg.includes('first error:')) {
                    msg = msg.split('first error:')[1];
                }

                if (msg.includes(': [')) {
                    msg = msg.split(': [')[0];
                }

                return msg.trim();
            });

        } catch (e) {
            console.error('Error parsing failed', e);
            return 'Unexpected error occurred';
        }

        const uniqueMessages = [...new Set(messages)];

        return uniqueMessages.join('\n');
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
            variant: 'Error',
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    formatSummary(summaryObj) {

        return Object.keys(summaryObj).map(key => {
            return {
                name: key,
                count: summaryObj[key]
            };
        });

    }


}