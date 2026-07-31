import { LightningElement, api } from 'lwc';
import fetchMasterLookupData from '@salesforce/apex/ResourceLineItemController.fetchLookupData';
import fetchMasterDefaultRecord from '@salesforce/apex/ResourceLineItemController.fetchDefaultRecord';

const DELAY = 300; // dealy apex callout timing in miliseconds  


export default class CustomLookupLwc extends LightningElement {
  // Public properties
  @api placeholder = 'search...';
  @api iconName = 'standard:account';
  @api sObjectApiName = 'Skill_Category_Matrix__c';
  @api filter = '';
  @api idsToExclude = [];
  @api defaultRecordId = '';
  @api defaultRecordB = false;
  @api lstResult = [];
  @api searchKey = '';
  @api searchName;
  @api searchNameSourcing;
  @api projectId;
  @api value;
  @api storeprojectId = '';
  @api prefilled = '';

  @api bu;
  @api subBu;
  @api experience;
  @api region;
  @api skill;
  @api skillId;

  // Internal state
  isSearchLoading = false;
  delayTimeout;
  hasRecords = true;
  selectedRecord = {};
  action = '';

  connectedCallback() {
    console.log('defaultRecordB: '+this.defaultRecordB);
    console.log('===== Lookup Component INIT =====');
    console.log('BU:', this.bu);
    console.log('Sub BU:', this.subBu);
    console.log('Skill:', this.skill);
    console.log('Experience:', this.experience);
    console.log('Region:', this.region);
    this.storeprojectId = this.projectId;

    if (this.storeprojectId) {
    //   if (['user', 'Skill_Category_Matrix__c'].includes(this.sObjectApiName) && this.prefilled === '') {
    //     this.calldefaultlookup();
    //   }
      if (this.sObjectApiName === 'Skill_Category_Matrix__c' && this.defaultRecordId !== '') {
        this.callMasterDefaultLookup();
      }
      if (this.sObjectApiName === 'Experience__c' && this.defaultRecordId !== '') {
        this.callMasterDefaultLookup();
      }
    }
  }

  handlefetchLookupdata() {
    //this.prefilled = 'no';

    if (['Skill_Category_Matrix__c'].includes(this.sObjectApiName)) {
      this.callMasterLookup();
    }

    if (this.sObjectApiName === 'Skill_Category_Matrix__c') {
      this.callMasterLookup();
    }
     if (this.sObjectApiName === 'Experience__c') {
      this.callMasterLookup();
    }
  }


  callMasterDefaultLookup() {
    if (this.defaultRecordId !== '') {
      fetchMasterDefaultRecord({
        recordId: this.defaultRecordId,
        sObjectApiName: this.sObjectApiName,
        projectId: this.storeprojectId,
        bu: this.bu,
        subBu: this.subBu,
        skill: this.skill,
        experience: this.experience,
        region: this.region
      })
        .then((result) => {
            console.log('result : ' + JSON.stringify(result));
          if (result != null) {
            this.selectedRecord = result;
            this.handelSelectRecordHelper();
          }
        })
        .catch((error) => {
          this.error = error;
          this.selectedRecord = {};
        });
    }
  }

  callMasterLookup() {
     console.log('===== Lookup Component Call =====');
    console.log('BU:', this.bu);
    console.log('Sub BU:', this.subBu);
    console.log('Skill:', this.skill);
    console.log('Experience:', this.experience);
    console.log('Region:', this.region);
    fetchMasterLookupData({
      searchKey: this.searchKey,
      sObjectApiName: this.sObjectApiName,
      projectId: this.storeprojectId,
      bu: this.bu,
      subBu: this.subBu,
      skill: this.skill,
      experience: this.experience,
      region: this.region,
      skillId: this.skillId,
      // unitConfiguration: this.filter,
      // excludeIds: this.idsToExclude
    })
      .then((result) => {
        this.hasRecords = result.length > 0;
        this.lstResult = JSON.parse(JSON.stringify(result));

        if (this.lstResult.length > 0 &&
          this.sObjectApiName === 'Skill_Category_Matrix__c' &&
          this.filterids?.length > 0) {
          const existingIds = new Set(this.lstResult.map(item => item.Id));
          this.lstResult = this.filterids.filter(data => !existingIds.has(data.Id));
        }
        if (this.lstResult.length > 0 &&
          this.sObjectApiName === 'Experience__c' &&
          this.filterids?.length > 0) {
          const existingIds = new Set(this.lstResult.map(item => item.Id));
          this.lstResult = this.filterids.filter(data => !existingIds.has(data.Id));
        }
      })
      .catch((error) => {
        console.error('Error in fetchLookupData:', error);
      });
  }

  // UI Event Handlers
  // handleKeyChange(event) {
  //   window.clearTimeout(this.delayTimeout);
  //   this.searchKey = event.target.value;
  //   this.projectId = event.target.projectid;

  //   if (this.searchKey !== '') {
  //     this.handlefetchLookupdata();
  //   }
  // }

  handleKeyChange(event) {
    window.clearTimeout(this.delayTimeout);
    this.searchKey = event.target.value;

    this.handlefetchLookupdata(); // always call
}

  toggleResult(event) {
    const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
    const clsList = lookupInputContainer.classList;
    const whichEvent = event.target.getAttribute('data-source');

    switch (whichEvent) {
        case 'searchInputField':
            clsList.add('slds-is-open');

            // 👉 ADD THIS (fetch default data)
            if (!this.searchKey) {
                this.handlefetchLookupdata();
            }
            break;

        case 'lookupContainer':
            clsList.remove('slds-is-open');
            break;
    }
}

  // toggleResult(event) {
  //   const lookupInputContainer = this.template.querySelector('.lookupInputContainer');
  //   const clsList = lookupInputContainer.classList;
  //   const whichEvent = event.target.getAttribute('data-source');

  //   switch (whichEvent) {
  //     case 'searchInputField':
  //       clsList.add('slds-is-open');
  //       break;
  //     case 'lookupContainer':
  //       clsList.remove('slds-is-open');
  //       break;
  //   }
  // }

  handleRemove(event) {

    const value = event.target.value;

    this.searchKey = '';
    this.selectedRecord = {};
    //this.lstResult = [];

    const searchInput = this.template.querySelector('.searchInputField');

    if (searchInput) {
        searchInput.value = '';
    }

    this.lookupUpdatehandler('Removed', value);

    this.togglePillView(false);
}

  handelSelectedRecord(event) {
    const objId = event.target.getAttribute('data-recid');
    this.selectedRecord = this.lstResult.find(data => data.Id === objId);
    this.lookupUpdatehandler('Added', this.selectedRecord);
    this.handelSelectRecordHelper();
  }

  handelSelectRecordHelper() {
    const container = this.template.querySelector('.lookupInputContainer');
    container.classList.remove('slds-is-open');
    this.togglePillView(true);
  }

  // Helper to toggle between search & pill
  togglePillView(showPill) {
    const searchBoxWrapper = this.template.querySelector('.searchBoxWrapper');
    const pillDiv = this.template.querySelector('.pillDiv');

    if (showPill) {
      searchBoxWrapper.classList.remove('slds-show');
      searchBoxWrapper.classList.add('slds-hide');
      pillDiv.classList.remove('slds-hide');
      pillDiv.classList.add('slds-show');
    } else {
      searchBoxWrapper.classList.remove('slds-hide');
      searchBoxWrapper.classList.add('slds-show');
      pillDiv.classList.remove('slds-show');
      pillDiv.classList.add('slds-hide');
    }
  }

  // Dispatch selected/removed records
  lookupUpdatehandler(action, value) {
    const oEvent = new CustomEvent('lookupupdate', {
      detail: {
        selectedRecord: value,
        action: action
      }
    });
    this.dispatchEvent(oEvent);
  }
}