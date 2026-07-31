import { LightningElement, api, track } from 'lwc';

import startExport from '@salesforce/apex/RevenueProjectionExportController.startExport';
import getJobStatus from '@salesforce/apex/RevenueProjectionExportController.getJobStatus';
//import getLatestExportFile from '@salesforce/apex/RevenueProjectionExportController.getLatestExportFile';
import getLatestExportFiles from '@salesforce/apex/RevenueProjectionExportController.getLatestExportFiles';
import getPreviewData from '@salesforce/apex/RevenueProjectionExportController.getPreviewData';
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
        'opportunityLink'
    ];

    // allColumns = [
    //     { label: 'Revenue Projection', fieldName: 'revenueProjectionStatus' },
    //     {
    //         label: 'Opportunity',
    //         fieldName: 'opportunityLink',
    //         type: 'url',
    //         sortable: true,
    //         typeAttributes: {
    //             label: {
    //                 fieldName: 'opportunityId'
    //             },
    //             target: '_blank'
    //         }
    //     },
    //     // { label: 'Opportunity SF Id', fieldName: 'opportunitySFId', initialWidth: 180 },
    //     // {
    //     //     label: 'Opportunity Id',
    //     //     fieldName: 'opportunityLink',
    //     //     type: 'url',
    //     //     typeAttributes: {
    //     //         label: {
    //     //             fieldName: 'opportunityId'
    //     //         },
    //     //         target: '_blank'
    //     //     },
    //     //     initialWidth: 160
    //     // },
    //     //{ label: 'Opportunity Id', fieldName: 'opportunityId', initialWidth: 160 },
    //     // { label: 'Opportunity RecordType', fieldName: 'recordTypeName', initialWidth: 160 },
    //     // { label: 'Owner', fieldName: 'opportunityOwnerName', initialWidth: 170 },
    //     // { label: 'Account', fieldName: 'accountName', initialWidth: 180 },
    //     { label: 'Stage', fieldName: 'stageName', sortable: true },
    //     { label: 'Bussiness Type', fieldName: 'bussinessType', sortable: true },
    //     { label: 'Bussiness Unit', fieldName: 'businessUnit', sortable: true },
    //     { label: 'Sub Bussiness Unit', fieldName: 'subbusinessUnit', sortable: true },
    //     // { label: 'Close Date', fieldName: 'closeDate', type: 'date' },
    //     // { label: 'Expected Close', fieldName: 'expectedCloseDate', type: 'date', initialWidth: 150 },

    //     // { label: 'TCV (USD)', fieldName: 'tcvUSD' },
    //     // { label: 'ACV (USD)', fieldName: 'acvUSD' },
    //     // { label: 'CQ1', fieldName: 'q1', initialWidth: 120 },
    //     // { label: 'CQ2', fieldName: 'q2', initialWidth: 120 },
    //     // { label: 'CQ3', fieldName: 'q3', initialWidth: 120 },
    //     // { label: 'CQ4', fieldName: 'q4', initialWidth: 120 },
    //     // { label: 'NQ1', fieldName: 'q5', initialWidth: 120 },
    //     // { label: 'NQ2', fieldName: 'q6', initialWidth: 120 },
    //     // { label: 'NQ3', fieldName: 'q7', initialWidth: 120 },
    //     // { label: 'NQ4', fieldName: 'q8', initialWidth: 120 },
    //     // { label: 'Extended', fieldName: 'extended' }
    //     { label: 'TCV (USD)', fieldName: 'tcvUSDFormatted' }, // Total Contract Value
    //     { label: 'ACV (USD)', fieldName: 'acvUSDFormatted' }, // Annual Contract Value

    //     { label: 'Current FY - Q1', fieldName: 'q1Formatted' },
    //     { label: 'Current FY - Q2', fieldName: 'q2Formatted' },
    //     { label: 'Current FY - Q3', fieldName: 'q3Formatted' },
    //     { label: 'Current FY - Q4', fieldName: 'q4Formatted' },

    //     { label: 'Next FY - Q1', fieldName: 'q5Formatted' },
    //     { label: 'Next FY - Q2', fieldName: 'q6Formatted' },
    //     { label: 'Next FY - Q3', fieldName: 'q7Formatted' },
    //     { label: 'Next FY - Q4', fieldName: 'q8Formatted' },

    //     { label: 'Extended', fieldName: 'extendedFormatted' },
    // ];


    allColumns = [
        {
            label: 'Revenue Projection',
            fieldName: 'revenueProjectionStatus',
            sortable: true,
            initialWidth: 180
        },
        {
            label: 'Opportunity',
            fieldName: 'opportunityLink',
            type: 'url',
            sortable: true,
            initialWidth: 180,
            typeAttributes: {
                label: { fieldName: 'opportunityId' },
                target: '_blank'
            }
        },
        {
            label: 'Opportunity Name',
            fieldName: 'opportunityName',
            sortable: true,
            initialWidth: 250
        },
        {
            label: 'Opportunity SF Id',
            fieldName: 'opportunitySFId',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Opportunity Id',
            fieldName: 'opportunityId',
            sortable: true,
            initialWidth: 170
        },
        {
            label: 'Opportunity Owner',
            fieldName: 'opportunityOwnerName',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Opportunity Owner SF Id',
            fieldName: 'opportunityOwnerSFId',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Account Id',
            fieldName: 'accountId',
            sortable: true,
            initialWidth: 180
        },
        {
            label: 'Account Name',
            fieldName: 'accountName',
            sortable: true,
            initialWidth: 220
        },
        {
            label: 'Location',
            fieldName: 'location',
            sortable: true,
            initialWidth: 180
        },
        {
            label: 'Stage',
            fieldName: 'stageName',
            sortable: true,
            initialWidth: 180
        },
        {
            label: 'Record Type',
            fieldName: 'recordTypeName',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Business Type',
            fieldName: 'bussinessType',
            sortable: true,
            initialWidth: 180
        },
        {
            label: 'Business Unit',
            fieldName: 'businessUnit',
            sortable: true,
            initialWidth: 200
        },
        {
            label: 'Sub Business Unit',
            fieldName: 'subbusinessUnit',
            sortable: true,
            initialWidth: 220
        },
        {
            label: 'Close Date',
            fieldName: 'closeDate',
            type: 'date',
            sortable: true,
            initialWidth: 150,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        {
            label: 'Expected Close Date',
            fieldName: 'expectedCloseDate',
            type: 'date',
            sortable: true,
            initialWidth: 180,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit'
            }
        },
        {
            label: 'Created Date',
            fieldName: 'createdDate',
            type: 'date',
            sortable: true,
            initialWidth: 190,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        {
            label: 'Last Modified Date',
            fieldName: 'lastModifiedDate',
            type: 'date',
            sortable: true,
            initialWidth: 210,
            typeAttributes: {
                year: 'numeric',
                month: 'short',
                day: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }
        },
        {
            label: 'Revenue Projection Ids',
            fieldName: 'revenueProjectionIds',
            initialWidth: 260
        },
        {
            label: 'Revenue Projection Count',
            fieldName: 'revenueProjectionIdsCount',
            type: 'number',
            sortable: true,
            initialWidth: 170
        },

        // Financial Summary
        {
            label: 'TCV (USD)',
            fieldName: 'tcvUSDFormatted',
            sortable: true,
            initialWidth: 160
        },
        {
            label: 'ACV (USD)',
            fieldName: 'acvUSDFormatted',
            sortable: true,
            initialWidth: 160
        },

        // Current Financial Year
        {
            label: 'Current FY - Q1',
            fieldName: 'q1Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Current FY - Q2',
            fieldName: 'q2Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Current FY - Q3',
            fieldName: 'q3Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Current FY - Q4',
            fieldName: 'q4Formatted',
            sortable: true,
            initialWidth: 150
        },

        // Next Financial Year
        {
            label: 'Next FY - Q1',
            fieldName: 'q5Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Next FY - Q2',
            fieldName: 'q6Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Next FY - Q3',
            fieldName: 'q7Formatted',
            sortable: true,
            initialWidth: 150
        },
        {
            label: 'Next FY - Q4',
            fieldName: 'q8Formatted',
            sortable: true,
            initialWidth: 150
        },

        {
            label: 'Extended',
            fieldName: 'extendedFormatted',
            sortable: true,
            initialWidth: 160
        }
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

        this.filteredData = this.previewData.filter(row => {

            // Search
            const matchesSearch =
                !this.searchKey ||

                (row.opportunityName || '').toLowerCase().includes(this.searchKey) ||
                (row.opportunitySFId || '').toLowerCase().includes(this.searchKey) ||
                (row.opportunityId || '').toLowerCase().includes(this.searchKey) ||
                (row.opportunityOwnerName || '').toLowerCase().includes(this.searchKey) ||
                (row.opportunityOwnerSFId || '').toLowerCase().includes(this.searchKey) ||
                (row.accountName || '').toLowerCase().includes(this.searchKey) ||
                (row.accountId || '').toLowerCase().includes(this.searchKey) ||
                (row.stageName || '').toLowerCase().includes(this.searchKey) ||
                (row.businessUnit || '').toLowerCase().includes(this.searchKey) ||
                (row.subbusinessUnit || '').toLowerCase().includes(this.searchKey) ||
                (row.recordTypeName || '').toLowerCase().includes(this.searchKey) ||
                (row.revenueProjectionStatus || '').toLowerCase().includes(this.searchKey) ||
                (row.bussinessType || '').toLowerCase().includes(this.searchKey);


            // Engagement Model
            const matchesRecordType =
                this.selectedrecordType.length === 0 ||
                this.selectedrecordType.includes(row.recordTypeName);

            // Stage
            const matchesStage =
                this.selectedStage.length === 0 ||
                this.selectedStage.includes(row.stageName);

            // Business Unit
            const matchesBusinessUnit =
                this.selectedBusinessUnit.length === 0 ||
                this.selectedBusinessUnit.includes(row.businessUnit);

            // Owner
            const matchesOwner =
                this.selectedOwner.length === 0 ||
                this.selectedOwner.includes(row.opportunityOwnerName);

            // Geo
            const matchesGeo =
                this.selectedGeo.length === 0 ||
                this.selectedGeo.includes(row.location);

            const matchesBuType =
                this.selectedbussinessType.length === 0 ||
                this.selectedbussinessType.includes(row.bussinessType);

            const matchesProjection =

                this.projectionFilter === 'ALL' ||

                (this.projectionFilter === 'HAS' &&
                    row.revenueProjectionStatus === 'Has Revenue Projection') ||

                (this.projectionFilter === 'NO' &&
                    row.revenueProjectionStatus !== 'Has Revenue Projection');

            return (
                matchesSearch &&
                matchesRecordType &&
                matchesStage &&
                matchesBusinessUnit &&
                matchesOwner &&
                matchesGeo &&
                matchesProjection &&
                matchesBuType
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
    connectedCallback() {
        //console.log('Connected');
        this.loadPreviewData();
        this.columnMap = new Map();

        this.allColumns.forEach(col => {
            this.columnMap.set(col.fieldName, col);
        });
        this.updateColumns();
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
            hasRP: 0,
            noRP: 0,
            totalTCV: 0,
            totalACV: 0,
            cqRevenue: 0,
            nqRevenue: 0,
            extendedRevenue: 0
        };

        data.forEach(row => {

            if (row.revenueProjectionStatus === 'Has Revenue Projection') {
                this.kpi.hasRP++;
            } else {
                this.kpi.noRP++;
            }

            this.kpi.totalTCV += Number(row.tcvUSD || 0);
            this.kpi.totalACV += Number(row.acvUSD || 0);

            this.kpi.cqRevenue +=
                Number(row.q1 || 0) +
                Number(row.q2 || 0) +
                Number(row.q3 || 0) +
                Number(row.q4 || 0);

            this.kpi.nqRevenue +=
                Number(row.q5 || 0) +
                Number(row.q6 || 0) +
                Number(row.q7 || 0) +
                Number(row.q8 || 0);

            this.kpi.extendedRevenue +=
                Number(row.extended || 0);
        });
    }

    loadPreviewData() {

        let exportColumns = [];

        exportColumns = this.columns.map(col => ({
            fieldName: col.fieldName,
            label: col.label
        }));

        console.log(JSON.stringify(exportColumns, null, 2));

        console.log('Export Columns:', JSON.stringify(exportColumns));


        this.isLoading = true;
        //console.log('Calling Apex');

        getPreviewData({
            opportunityId: this.recordId,
            exportAll: true,
            columns: JSON.stringify(this.selectedFields),
            exportColumns: JSON.stringify(exportColumns)
        }).then(result => {

            //console.log('========== Preview Result ==========');

            ////console.log('Total Records:', result.length);

            //console.table(result);

            ////console.log('Raw Result:', result);

            //console.log('JSON Result:', JSON.stringify(result, null, 2));

            this.previewData = result;

            this.previewData = result
                .map(row => ({
                    ...row,
                    opportunityLink: `/${row.opportunitySFId}`,
                    tcvUSDFormatted: this.formatUSD(row.tcvUSD),
                    acvUSDFormatted: this.formatUSD(row.acvUSD),

                    q1Formatted: this.formatUSD(row.q1),
                    q2Formatted: this.formatUSD(row.q2),
                    q3Formatted: this.formatUSD(row.q3),
                    q4Formatted: this.formatUSD(row.q4),

                    q5Formatted: this.formatUSD(row.q5),
                    q6Formatted: this.formatUSD(row.q6),
                    q7Formatted: this.formatUSD(row.q7),
                    q8Formatted: this.formatUSD(row.q8),

                    extendedFormatted: this.formatUSD(row.extended)
                }))
                .sort((a, b) => new Date(b.lastModifiedDate) - new Date(a.lastModifiedDate));

            this.filteredData = [...this.previewData];
            //this.filteredData = [...this.previewData];
            this.calculateKPIs(this.filteredData);
            //this.buildChartData();
            this.totalPages = Math.ceil(
                this.filteredData.length / this.pageSize
            );

            //console.log('Total Pages:', this.totalPages);

            this.updatePagination();

            //console.log('Current Page Data:');
            console.table(this.paginatedData);

            this.recordTypeNameOptions = [
                ...new Set(this.previewData.map(r => r.recordTypeName))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));

            this.stageOptions = [
                ...new Set(this.previewData.map(r => r.stageName))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));

            this.businessUnitOptions = [
                ...new Set(this.previewData.map(r => r.businessUnit))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));

            this.ownerOptions = [
                ...new Set(this.previewData.map(r => r.opportunityOwnerName))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));

            this.geoOptions = [
                ...new Set(this.previewData.map(r => r.location))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));

            this.bussinessTypeOptions = [
                ...new Set(this.previewData.map(r => r.bussinessType))
            ]
                .filter(v => v)
                .sort()
                .map(v => ({ label: v, value: v }));



            this.isLoading = false;

        }).catch(error => {

            this.isLoading = false;

            this.showToast(
                'Error',
                error.body?.message || 'Unable to load preview data.',
                'error'
            );

        });

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

        this.columns = this.selectedFields
            .map(fieldName => this.columnMap.get(fieldName))
            .filter(Boolean);
    }

    selectedFields = [
        'opportunityLink',
        'stageName',
        'bussinessType',
        'tcvUSDFormatted',
        'acvUSDFormatted',
        'q1Formatted',
        'q2Formatted',
        'q3Formatted',
        'q4Formatted',
        'q5Formatted',
        'q6Formatted',
        'q7Formatted',
        'q8Formatted',
        'extendedFormatted'
    ];

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