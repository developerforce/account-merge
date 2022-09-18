import { LightningElement, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getRecordFields from "@salesforce/apex/RecordSyncRunController.getRecordFields";
import createSyncRun from "@salesforce/apex/RecordSyncRunController.createSyncRun";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

const columns = [
  { label: "Id", fieldName: "Id" },
  { label: "Status", fieldName: "Status__c" },
  {
    type: "button",
    typeAttributes: {
      label: "Detail"
    }
  }
];

export default class RecordSyncRun extends NavigationMixin(LightningElement) {
  @track searchFields = [];
  @track updateFields = [];
  @track error;
  columns = columns;

  selectedSearchFields = [];
  selectedUpdateFields = [];
  selectedDate = new Date().toISOString();
  selectedScore = 100;

  isFormValid;
  isLoading = false;

  @wire(getRecordFields) wiredRecordFields({ error, data }) {
    if (data) {
      this.searchFields = data.searchFields;
      this.updateFields = data.updateFields;
      this.error = null;
    } else if (error) {
      this.error = error;
      this.searchFields = [];
      this.updatefields = [];
    }
  }

  handleSearchFieldsChange(event) {
    this.selectedSearchFields = event.detail.value;
    this.checkFormValidity();
  }
  handleUpdateFieldsChange(event) {
    this.selectedUpdateFields = event.detail.value;
    this.checkFormValidity();
  }

  handleSelectedDate(event) {
    this.selectedDate = event.detail.value;
    this.checkFormValidity();
  }

  handleSelectedScore(event) {
    this.selectedScore = event.detail.value;
    this.checkFormValidity();
  }

  createSyncRunRecord() {
    this.isLoading = true;
    if (this.selectedSearchFields.indexOf("Id") !== -1) {
      this.selectedSearchFields.splice(
        this.selectedSearchFields.indexOf("Id"),
        1
      );
    }
    if (this.selectedUpdateFields.indexOf("Id") !== -1) {
      this.selectedUpdateFields.splice(
        this.selectedUpdateFields.indexOf("Id"),
        1
      );
    }
    createSyncRun({
      searchFields: this.selectedSearchFields.join(","),
      updateFields: this.selectedUpdateFields.join(","),
      fromDate: this.selectedDate,
      minimumScore: this.selectedScore
    })
      .then((recordId) => {
        this.showNotification({
          message: "Record Sync Run created successfully.",
          variant: "success",
          title: "Success"
        });
        this.navigateToDetail(recordId);
      })
      .catch((error) => {
        // TODO: display toast, redirect to the list
        this.error = error;
        console.log(error.message);
        this.showNotification({
          message: error.message,
          variant: "error",
          title: "Error"
        });
      })
      .finally(() => {
        this.isLoading = false;
      });
  }

  checkFormValidity() {
    const allInputsValid = [
      ...this.template.querySelectorAll("lightning-input")
    ].reduce((validSoFar, inputCmp) => {
      inputCmp.reportValidity();
      return validSoFar && inputCmp.checkValidity();
    }, true);
    if (
      allInputsValid &&
      this.selectedSearchFields.length &&
      this.selectedUpdateFields.length
    ) {
      this.isFormValid = true;
    } else {
      this.isFormValid = false;
    }
  }

  navigateToDetail(recordId) {
    this[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId,
        objectApiName: "Record_Sync_Run__c",
        actionName: "view"
      }
    });
  }
  showNotification({ message, title, variant }) {
    const evt = new ShowToastEvent({
      title,
      message,
      variant
    });
    this.dispatchEvent(evt);
  }

  get disableFind() {
    return !this.isFormValid;
  }
}
