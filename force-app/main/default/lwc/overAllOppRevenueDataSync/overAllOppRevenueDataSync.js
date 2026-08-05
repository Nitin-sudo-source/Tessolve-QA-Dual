import { LightningElement, api, track } from 'lwc';

import startExport from '@salesforce/apex/RevenueProjectionExportController.startExport';
import getJobStatus from '@salesforce/apex/RevenueProjectionExportController.getJobStatus';
//import getLatestExportFile from '@salesforce/apex/RevenueProjectionExportController.getLatestExportFile';
import getLatestExportFiles from '@salesforce/apex/RevenueProjectionExportController.getLatestExportFiles';
import getPreviewData from '@salesforce/apex/RevenueProjectionExportController.getPreviewData';
import getExportFields from '@salesforce/apex/RevenueProjectionExportController.getExportFields';
// import chartJs from '@salesforce/resourceUrl/ChartJS';
// import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class OverAllOppRevenueDataSync extends LightningElement {
    stageChart;
    ownerChart;
    recordTypeChart;
    statusChart;

    chartJsInitialized = false;
    @api recordId;

    @api columns = [];

    @track allColumns = [];

    @track isLoading = false;

    jobId;
    pollingId;

    @track previewData = [];
    @track paginatedData = [];

    page = 1;
    pageSize = 50;
    totalPages = 1;
    @track filteredData = [];

    searchKey = '';

    // handleSaveColumns(event) {
    //     try {
    //         console.log('Received:', JSON.stringify(event.detail));
    //         this.selectedFields = [...event.detail];
    //         console.log('Received selectedFields:', JSON.stringify(this.selectedFields));

    //         //this.selectedFields = event.detail;

    //     } catch (error) {
    //         console.error('Parent handleSave Error:', error);
    //     }

    // }


    get totalRecordCount() {
        return this.previewData.length;
    }

    get filteredRecordCount() {
        return this.filteredData.length;
    }

    get showingFrom() {
        return this.filteredData.length === 0
            ? 0
            : ((this.page - 1) * this.pageSize) + 1;
    }

    get showingTo() {
        const to = this.page * this.pageSize;
        return to > this.filteredData.length
            ? this.filteredData.length
            : to;
    }

    get columnOptions() {
        return this.allColumns.map(col => ({
            label: col.label,
            value: col.fieldName
        }));
    }

    @api lockedFields = [
        'Name'
    ];



    selectedStage = '';
    selectedBusinessUnit = '';
    selectedrecordType = '';
    selectedOwner = '';
    selectedGeo = '';
    selectedbussinessType = '';

    selectedStages = [];
    selectedBusinessUnits = [];
    selectedOwners = [];
    selectedRecordTypes = [];
    selectedGeos = [];
    selectedbussinessTypes = [];

    stageOptions = [];
    recordTypeNameOptions = [];
    businessUnitOptions = [];
    ownerOptions = [];
    geoOptions = [];

    bussinessTypeOptions = [];

    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;

    sortBy(field, reverse, primer) {
        const key = primer
            ? function (x) {
                return primer(x[field]);
            }
            : function (x) {
                return x[field];
            };

        return function (a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.paginatedData];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.paginatedData = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }



    handleStageChange(event) {
        this.selectedStage = event.detail;
        this.applyFilters();
    }

    handleBusinessUnitChange(event) {
        this.selectedBusinessUnit = event.detail;
        this.applyFilters();
    }

    handleOwnerChange(event) {
        this.selectedOwner = event.detail;
        this.applyFilters();
    }

    handleRecordTypeChange(event) {
        this.selectedrecordType = event.detail;
        this.applyFilters();
    }

    handleGeoChange(event) {
        this.selectedGeo = event.detail;
        this.applyFilters();
    }

    handleBussinessTypeChange(event) {
        this.selectedbussinessType = event.detail;
        this.applyFilters();
    }

    handleProjectionToggle(event) {

        this.projectionFilter = event.target.value;

        this.applyFilters();

    }

    get allVariant() {
        return this.projectionFilter === 'ALL'
            ? 'brand'
            : 'neutral';
    }

    projectionFilter = 'ALL';

    get hasVariant() {
        return this.projectionFilter === 'HAS'
            ? 'brand'
            : 'neutral';
    }

    get noVariant() {
        return this.projectionFilter === 'NO'
            ? 'brand'
            : 'neutral';
    }


    applyFilters() {

        const searchText = (this.searchKey || '').toLowerCase();

        this.filteredData = this.previewData.filter(row => {

            // ===============================
            // Global Search
            // ===============================

            const matchesSearch =
                !searchText ||

                (row.Name || '').toLowerCase().includes(searchText) ||
                (row.Id || '').toLowerCase().includes(searchText) ||
                (row.Opportunity_Id__c || '').toLowerCase().includes(searchText) ||
                (row['Owner.Name'] || '').toLowerCase().includes(searchText) ||
                (row.OwnerId || '').toLowerCase().includes(searchText) ||
                (row['Account.Name'] || '').toLowerCase().includes(searchText) ||
                (row.AccountId || '').toLowerCase().includes(searchText) ||
                (row.StageName || '').toLowerCase().includes(searchText) ||
                (row.Business_Unit_BU__c || '').toLowerCase().includes(searchText) ||
                (row.Sub_Business_Unit__c || '').toLowerCase().includes(searchText) ||
                (row['RecordType.Name'] || '').toLowerCase().includes(searchText) ||
                (row.Business_Type__c || '').toLowerCase().includes(searchText) ||
                (row.Geo__c || '').toLowerCase().includes(searchText) ||
                (row.revenueProjectionStatus || '').toLowerCase().includes(searchText);

            // ===============================
            // Record Type
            // ===============================

            const matchesRecordType =
                this.selectedrecordType.length === 0 ||
                this.selectedrecordType.includes(row['RecordType.Name']);

            // ===============================
            // Stage
            // ===============================

            const matchesStage =
                this.selectedStage.length === 0 ||
                this.selectedStage.includes(row.StageName);

            // ===============================
            // Business Unit
            // ===============================

            const matchesBusinessUnit =
                this.selectedBusinessUnit.length === 0 ||
                this.selectedBusinessUnit.includes(row.Business_Unit_BU__c);

            // ===============================
            // Owner
            // ===============================

            const matchesOwner =
                this.selectedOwner.length === 0 ||
                this.selectedOwner.includes(row['Owner.Name']);

            // ===============================
            // Geo
            // ===============================

            const matchesGeo =
                this.selectedGeo.length === 0 ||
                this.selectedGeo.includes(row.Geo__c);

            // ===============================
            // Business Type
            // ===============================

            const matchesBuType =
                this.selectedbussinessType.length === 0 ||
                this.selectedbussinessType.includes(row.Business_Type__c);

            // ===============================
            // Revenue Projection
            // ===============================

            const matchesProjection =

                this.projectionFilter === 'ALL' ||

                (
                    this.projectionFilter === 'HAS' &&
                    row.revenueProjectionStatus === 'Has Revenue Projection'
                ) ||

                (
                    this.projectionFilter === 'NO' &&
                    row.revenueProjectionStatus !== 'Has Revenue Projection'
                );

            return (
                matchesSearch &&
                matchesRecordType &&
                matchesStage &&
                matchesBusinessUnit &&
                matchesOwner &&
                matchesGeo &&
                matchesBuType &&
                matchesProjection
            );

        });

        this.calculateKPIs(this.filteredData);

        this.page = 1;

        this.totalPages = Math.max(
            1,
            Math.ceil(this.filteredData.length / this.pageSize)
        );

        this.updatePagination();

    }
    get hasActiveFilters() {
        return (
            this.selectedrecordType.length ||
            this.selectedStage.length ||
            this.selectedBusinessUnit.length ||
            this.selectedOwner.length ||
            this.selectedGeo.length ||
            this.selectedbussinessType.length
        );
    }
    removeFilter(event) {

        const value = event.target.name;
        const filter = event.target.dataset.filter;

        switch (filter) {

            case 'recordType':
                this.selectedrecordType =
                    this.selectedrecordType.filter(v => v !== value);
                break;

            case 'stage':
                this.selectedStage =
                    this.selectedStage.filter(v => v !== value);
                break;

            case 'businessUnit':
                this.selectedBusinessUnit =
                    this.selectedBusinessUnit.filter(v => v !== value);
                break;

            case 'owner':
                this.selectedOwner =
                    this.selectedOwner.filter(v => v !== value);
                break;

            case 'geo':
                this.selectedGeo =
                    this.selectedGeo.filter(v => v !== value);
                break;

            case 'bussinesstype':
                this.selectedbussinessType =
                    this.selectedbussinessType.filter(v => v !== value);
                break;
        }

        this.applyFilters();
    }


    clearFilters() {

        this.searchKey = '';

        this.selectedrecordType = [];
        this.selectedStage = [];
        this.selectedBusinessUnit = [];
        this.selectedOwner = [];
        this.selectedGeo = [];
        this.selectedbussinessType = [];

        // Clear child components
        this.template.querySelectorAll('c-multi-select-picklist-lwc')
            .forEach(component => component.clear());

        this.applyFilters();
    }

    handleFilterChange(event) {
        const { name, value } = event.target;

        switch (name) {
            case 'enModel':
                this.selectedrecordType = value;
                break;

            case 'stage':
                this.selectedStage = value;
                break;

            case 'businessUnit':
                this.selectedBusinessUnit = value;
                break;

            case 'owner':
                this.selectedOwner = value;
                break;

            case 'geo':
                this.selectedGeo = value;
                break;

            case 'bussinesstype':
                this.selectedbussinessType = value;
                break;
        }

        this.applyFilters();
    }

    loadColumns() {

        this.isLoading = true;

        getExportFields()
            .then(result => {

                this.allColumns = [];
                this.columnMap = new Map();
                this.selectedFields = [];
                this.defaultSelectedFields = [];

                //=====================================
                // Opportunity Metadata Columns
                //=====================================

                result.forEach(field => {

                    let column = {
                        label: field.fieldLabel,
                        fieldName: field.fieldApiName,
                        sortable: true,
                        initialWidth: 180
                    };

                    switch (field.dataType) {

                        case 'Date':

                            column.type = 'date';
                            column.typeAttributes = {
                                year: 'numeric',
                                month: 'short',
                                day: '2-digit'
                            };
                            break;

                        case 'Datetime':

                            column.type = 'date';
                            column.typeAttributes = {
                                year: 'numeric',
                                month: 'short',
                                day: '2-digit',
                                hour: '2-digit',
                                minute: '2-digit'
                            };
                            break;

                        case 'Number':

                            column.type = 'number';
                            break;

                        case 'Currency':

                            column.type = 'currency';
                            column.typeAttributes = {
                                currencyCode: 'USD'
                            };
                            break;

                        default:

                            column.type = 'text';

                    }

                    // Opportunity hyperlink
                    if (field.fieldApiName === 'Name') {

                        column.type = 'url';
                        column.fieldName = 'Name';

                        column.typeAttributes = {
                            label: {
                                fieldName: 'Name'
                            },
                            target: '_blank'
                        };

                    }

                    this.allColumns.push(column);

                    // IMPORTANT
                    this.columnMap.set(
                        column.fieldName,
                        column
                    );

                    if (field.defaultSelected) {

                        if (field.fieldApiName === 'Name') {

                            this.selectedFields.push('Name');
                            this.defaultSelectedFields.push('Name');

                        } else {

                            this.selectedFields.push(field.fieldApiName);
                            this.defaultSelectedFields.push(field.fieldApiName);

                        }

                    }

                });

                //=====================================
                // Revenue Projection Wrapper Columns
                // (Only until these are moved to CMDT)
                //=====================================

                const wrapperColumns = [

                    // {
                    //     label: 'Revenue Projection',
                    //     fieldName: 'revenueProjectionStatus'
                    // },
                    // {
                    //     label: 'Revenue Projection Ids',
                    //     fieldName: 'revenueProjectionIds'
                    // },
                    // {
                    //     label: 'Revenue Projection Count',
                    //     fieldName: 'revenueProjectionIdsCount',
                    //     type: 'number'
                    // },

                    {
                        label: 'TCV (USD)',
                        fieldName: 'tcvUSDFormatted',
                        type: 'currency'
                    },
                    {
                        label: 'ACV (USD)',
                        fieldName: 'acvUSDFormatted',
                        type: 'currency'
                    },

                    {
                        label: 'Current FY - Q1',
                        fieldName: 'q1Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Current FY - Q2',
                        fieldName: 'q2Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Current FY - Q3',
                        fieldName: 'q3Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Current FY - Q4',
                        fieldName: 'q4Formatted',
                        type: 'currency'
                    },

                    {
                        label: 'Next FY - Q1',
                        fieldName: 'q5Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Next FY - Q2',
                        fieldName: 'q6Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Next FY - Q3',
                        fieldName: 'q7Formatted',
                        type: 'currency'
                    },
                    {
                        label: 'Next FY - Q4',
                        fieldName: 'q8Formatted',
                        type: 'currency'
                    },

                    {
                        label: 'Extended',
                        fieldName: 'extendedFormatted',
                        type: 'currency'
                    }

                ];

                wrapperColumns.forEach(col => {

                    if (!this.columnMap.has(col.fieldName)) {

                        col.sortable = true;
                        col.initialWidth = 170;

                        if (col.type === 'currency') {

                            col.typeAttributes = {
                                currencyCode: 'USD'
                            };

                        }

                        this.allColumns.push(col);

                        this.columnMap.set(
                            col.fieldName,
                            col
                        );

                        this.selectedFields.push(col.fieldName);
                        this.defaultSelectedFields.push(col.fieldName);

                    }

                });

                this.updateColumns();

                this.loadPreviewData();

            })
            .catch(error => {

                this.showToast(
                    'Error',
                    error.body?.message || 'Unable to load columns.',
                    'error'
                );

                this.isLoading = false;

            });

    }
    connectedCallback() {
        this.loadColumns();

    }

    applyColumnSelection() {

        this.updateColumns();

        this.closeColumnModal();
    }

    showColumnModal = false;

    openColumnModal() {
        this.showColumnModal = true;
    }

    closeColumnModal() {
        this.handleSaveColumns();
        this.showColumnModal = false;
    }

    updatePagination() {

        const start = (this.page - 1) * this.pageSize;
        const end = start + this.pageSize;

        this.paginatedData = this.filteredData.slice(start, end);

    }

    handleSearch(event) {
        this.searchKey = (event.target.value || '').trim().toLowerCase();
        this.applyFilters();
    }

    handleNext() {

        if (this.page < this.totalPages) {

            this.page++;

            this.updatePagination();

        }

    }

    handlePrevious() {

        if (this.page > 1) {

            this.page--;

            this.updatePagination();

        }

    }

    get disablePrevious() {
        return this.page === 1;
    }

    get disableNext() {
        return this.page === this.totalPages;
    }

    get hasData() {
        return this.filteredData.length > 0;
    }

    @track kpi = {
        totalOpps: 0,
        hasRP: 0,
        noRP: 0,
        totalTCV: 0,
        totalACV: 0,
        cqRevenue: 0,
        nqRevenue: 0,
        extendedRevenue: 0
    };

    calculateKPIs(data) {

        this.kpi = {
            totalOpps: data.length,
            totalTCV: 0,
            totalACV: 0,
            cqRevenue: 0,
            nqRevenue: 0,
            extendedRevenue: 0,
            hasRP: 0,
            noRP: 0
        };

        data.forEach(row => {

            // Revenue Projection Count
            if (row.revenueProjectionStatus === 'Has Revenue Projection') {
                this.kpi.hasRP++;
            } else {
                this.kpi.noRP++;
            }

            // Safe Number Conversion
            const tcv = parseFloat(row.tcvUSDFormatted) || 0;
            const acv = parseFloat(row.acvUSDFormatted) || 0;

            const q1 = parseFloat(row.q1Formatted) || 0;
            const q2 = parseFloat(row.q2Formatted) || 0;
            const q3 = parseFloat(row.q3Formatted) || 0;
            const q4 = parseFloat(row.q4Formatted) || 0;

            const q5 = parseFloat(row.q5Formatted) || 0;
            const q6 = parseFloat(row.q6Formatted) || 0;
            const q7 = parseFloat(row.q7Formatted) || 0;
            const q8 = parseFloat(row.q8Formatted) || 0;

            const extended = parseFloat(row.extendedFormatted) || 0;

            // Totals
            this.kpi.totalTCV += tcv;
            this.kpi.totalACV += acv;

            this.kpi.cqRevenue +=
                q1 +
                q2 +
                q3 +
                q4;

            this.kpi.nqRevenue +=
                q5 +
                q6 +
                q7 +
                q8;

            this.kpi.extendedRevenue +=
                extended;

        });

        console.log('===== KPI =====');
        console.table(this.kpi);

    }
    loadPreviewData() {

        let exportColumns = this.columns.map(col => ({
            fieldName: col.fieldName,
            label: col.label
        }));

        console.log('Export Columns:', JSON.stringify(exportColumns, null, 2));

        this.isLoading = true;

        getPreviewData({
            opportunityId: this.recordId,
            exportAll: true,
            columns: JSON.stringify(this.selectedFields),
            exportColumns: JSON.stringify(exportColumns)
        })
            .then(result => {

                console.log('JSON Result:', JSON.stringify(result, null, 2));

                this.previewData = result
                    .map(row => {

                        let record = { ...row };

                        // Opportunity Link
                        record.opportunityLink = '/' + (row.Id || '');

                        // --------------------------------------------------
                        // Keep numeric values unchanged for KPI calculations
                        // Create separate display fields for the UI
                        // --------------------------------------------------

                        if (record.tcvUSDFormatted != null) {
                            record.tcvUSDDisplay =
                                this.formatUSD(record.tcvUSDFormatted);
                        }

                        if (record.acvUSDFormatted != null) {
                            record.acvUSDDisplay =
                                this.formatUSD(record.acvUSDFormatted);
                        }

                        if (record.q1Formatted != null) {
                            record.q1Display =
                                this.formatUSD(record.q1Formatted);
                        }

                        if (record.q2Formatted != null) {
                            record.q2Display =
                                this.formatUSD(record.q2Formatted);
                        }

                        if (record.q3Formatted != null) {
                            record.q3Display =
                                this.formatUSD(record.q3Formatted);
                        }

                        if (record.q4Formatted != null) {
                            record.q4Display =
                                this.formatUSD(record.q4Formatted);
                        }

                        if (record.q5Formatted != null) {
                            record.q5Display =
                                this.formatUSD(record.q5Formatted);
                        }

                        if (record.q6Formatted != null) {
                            record.q6Display =
                                this.formatUSD(record.q6Formatted);
                        }

                        if (record.q7Formatted != null) {
                            record.q7Display =
                                this.formatUSD(record.q7Formatted);
                        }

                        if (record.q8Formatted != null) {
                            record.q8Display =
                                this.formatUSD(record.q8Formatted);
                        }

                        if (record.extendedFormatted != null) {
                            record.extendedDisplay =
                                this.formatUSD(record.extendedFormatted);
                        }

                        return record;

                    })
                    .sort((a, b) =>
                        new Date(b.LastModifiedDate) -
                        new Date(a.LastModifiedDate)
                    );

                this.filteredData = [...this.previewData];

                // KPI now receives numeric values
                this.calculateKPIs(this.filteredData);

                this.totalPages = Math.ceil(
                    this.filteredData.length / this.pageSize
                );

                this.updatePagination();

                console.table(this.paginatedData);

                // Filters
                this.stageOptions = this.buildFilterOptions('StageName');
                this.ownerOptions = this.buildFilterOptions('Owner.Name');
                this.recordTypeNameOptions =
                    this.buildFilterOptions('RecordType.Name');
                this.businessUnitOptions =
                    this.buildFilterOptions('Business_Unit_BU__c');
                this.geoOptions =
                    this.buildFilterOptions('Geo__c');
                this.bussinessTypeOptions =
                    this.buildFilterOptions('Business_Type__c');

                this.isLoading = false;

            })
            .catch(error => {

                this.isLoading = false;

                this.showToast(
                    'Error',
                    error.body?.message || 'Unable to load preview data.',
                    'error'
                );

            });
    }

    buildFilterOptions(fieldName) {

        return [
            ...new Set(this.previewData.map(r => r[fieldName]))
        ]
            .filter(Boolean)
            .sort()
            .map(v => ({
                label: v,
                value: v
            }));

    }



    currencyFormatter = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        notation: 'compact',
        compactDisplay: 'short',
        minimumFractionDigits: 0,
        maximumFractionDigits: 1
    });

    formatUSD(value) {
        return this.currencyFormatter.format(Number(value || 0));
    }


    handleExport() {

        let exportColumns = [];

        exportColumns = this.columns.map(col => ({
            fieldName: col.fieldName,
            label: col.label
        }));

        console.log(JSON.stringify(exportColumns, null, 2));

        console.log('Export Columns:', JSON.stringify(exportColumns));

        this.isLoading = true;

        startExport({
            opportunityId: this.recordId,
            exportAll: true,
            columns: JSON.stringify(this.selectedFields),
            exportColumns: JSON.stringify(exportColumns)
        }).then(result => {

            this.jobId = result.jobId;

            this.showToast(
                'Success',
                result.message,
                'success'
            );

            this.startPolling();

        })
            .catch(error => {

                this.isLoading = false;

                this.showToast(
                    'Error',
                    error.body?.message || 'Unknown Error',
                    'error'
                );

            });
    }

    updateColumns() {

        this.columns = [];

        this.selectedFields.forEach(field => {

            const column = this.columnMap.get(field);

            if (column) {

                this.columns.push(column);

            }

        });

    }

    // updateColumns() {

    //     this.columns = this.selectedFields
    //         .map(fieldName => this.columnMap.get(fieldName))
    //         .filter(Boolean);
    // }

    // selectedFields = [
    //     'opportunityLink',
    //     'stageName',
    //     'bussinessType',
    //     'tcvUSDFormatted',
    //     'acvUSDFormatted',
    //     'q1Formatted',
    //     'q2Formatted',
    //     'q3Formatted',
    //     'q4Formatted',
    //     'q5Formatted',
    //     'q6Formatted',
    //     'q7Formatted',
    //     'q8Formatted',
    //     'extendedFormatted'
    // ];

    columnMap = new Map();

    handleSaveColumns() {
        const columnManager = this.template.querySelector('c-column-manager');

        if (columnManager) {
            const selectedColumns = columnManager.getValue();

            console.log('Selected Columns:', selectedColumns);

            this.selectedFields = [...selectedColumns];
            console.log('Selected Columns selectedFields:' + JSON.stringify(this.selectedFields));

            this.showColumnManager = false;
        }
    }

    handleResetColumns() {
        const columnManager = this.template.querySelector('c-column-manager');

        if (columnManager) {
            columnManager.setValue(this.defaultSelectedFields);
        }
    }


    closeColumnManager() {
        this.showColumnManager = false;
    }

    handleColumnChange(event) {

        this.selectedFields = [...event.detail];

        console.log('Selected Fields:', this.selectedFields);


        this.updateColumns();
    }

    startPolling() {

        this.pollingId = window.setInterval(() => {

            getJobStatus({
                jobId: this.jobId
            })

                .then(job => {

                    if (job.Status === 'Completed') {

                        clearInterval(this.pollingId);

                        this.downloadFile();

                    }

                    if (job.Status === 'Failed' ||
                        job.Status === 'Aborted') {

                        clearInterval(this.pollingId);

                        this.isLoading = false;

                        this.showToast(
                            'Error',
                            'Export Failed',
                            'error'
                        );

                    }

                });

        }, 3000);

    }

    downloadFile() {
        getLatestExportFiles()
            .then(files => {
                this.isLoading = false;

                if (!files || files.length === 0) {
                    this.showToast(
                        'Warning',
                        'No export files found.',
                        'warning'
                    );
                    return;
                }

                files.forEach(file => {
                    window.open(
                        `/sfc/servlet.shepherd/document/download/${file.ContentDocumentId}`,
                        '_blank'
                    );
                });

                this.showToast(
                    'Success',
                    `${files.length} CSV file(s) downloaded successfully.`,
                    'success'
                );
            })
            .catch(error => {
                this.isLoading = false;

                this.showToast(
                    'Error',
                    error.body?.message || 'Unable to download export files.',
                    'error'
                );

                console.error('Download Error:', error);
            });
    }



    showToast(title, message, variant) {

        this.dispatchEvent(

            new ShowToastEvent({

                title,
                message,
                variant

            })

        );

    }

    get totalTCVFormatted() {
        return this.formatUSD(this.kpi.totalTCV);
    }

    get totalACVFormatted() {
        return this.formatUSD(this.kpi.totalACV);
    }

    get cqRevenueFormatted() {
        return this.formatUSD(this.kpi.cqRevenue);
    }

    get nqRevenueFormatted() {
        return this.formatUSD(this.kpi.nqRevenue);
    }

    get extendedRevenueFormatted() {
        return this.formatUSD(this.kpi.extendedRevenue);
    }

    formatCurrency(value) {
        return new Intl.NumberFormat('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        }).format(value || 0);
    }


}