import { LightningElement, api, wire, track } from 'lwc';
import getOvertimeOffersList from '@salesforce/apex/ViewingRecordsOnMobileHelper.getOvertimeOffersList';
import { refreshApex } from '@salesforce/apex';
import { updateRecord } from 'lightning/uiRecordApi';
import LightningAlert from 'lightning/alert';
import Id from '@salesforce/user/Id';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import STARTDATE_FIELD from '@salesforce/schema/Overtime_Offers__c.Offer_Start_Time__c';
import FINISHDATE_FIELD from '@salesforce/schema/Overtime_Offers__c.Offer_Finish_Time__c';
import STATUS_FIELD from '@salesforce/schema/Overtime_Offers__c.Status__c';
import COMMENT_FIELD from '@salesforce/schema/Overtime_Offers__c.Comment__c';
import ID_FIELD from '@salesforce/schema/Overtime_Offers__c.Id';

export default class ViewOvertimeOffersLWC extends LightningElement {

    userId = Id;
    activeSections = [];

    get enabledStatusOptions() {
        return [
            { label: 'Offered', value: 'Offered' },
            { label: 'Recalled', value: 'Recalled' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get disabledStatusOptions() {
        return [
            { label: 'Cancelled', value: 'Cancelled' },
            { label: 'Not Hired', value: 'Not Hired' },
            { label: 'Hired', value: 'Hired' }
        ];
    }

    @wire(getOvertimeOffersList, {userId: '$userId'})
    listInfo;

    handleRefreshDataClicked() {
        refreshApex(this.listInfo)
        .then(() => {
            this.handleSuccessAlert('Records on page are up to date!');
        })
        .catch((error) =>{
            this.handleErrorAlert('Network Issue');
        })
    }

    handleComboboxChange(event){
        console.log(event.detail.value);
    }

    handleSectionToggle(event) {
        const openSections = event.detail.openSections;
    }

    handleSave(event){
        const fields = {};
        let allValid;
        const recId = event.target.dataset.id;
        this.template.querySelectorAll('[data-element=' + recId + ']')
        .forEach((element) => {
            fields[ID_FIELD.fieldApiName] = recId;
            if(element.name == 'startDateTime'){
                fields[STARTDATE_FIELD.fieldApiName] = element.value;
            }
            else if(element.name == 'finishDateTime'){
                fields[FINISHDATE_FIELD.fieldApiName] = element.value;
            }
            else if(element.name == 'status'){
                fields[STATUS_FIELD.fieldApiName] = element.value;
            }
            else if(element.name == 'comment'){
                fields[COMMENT_FIELD.fieldApiName] = element.value;
            }
        });
        const recordInput = {fields};
        const startDateTimeObj = this.convertDateTimeToUserLocal(fields[STARTDATE_FIELD.fieldApiName]);
        const finishDateTimeObj = this.convertDateTimeToUserLocal(fields[FINISHDATE_FIELD.fieldApiName]);
        allValid = this.validateDateTime(startDateTimeObj, finishDateTimeObj);

        if(allValid){
            updateRecord(recordInput)
            .then(() => {
                refreshApex(this.listInfo)
                .then(() => {
                    this.handleSuccessAlert('Record updated successfully!')
                    .then(() => {
                        refreshApex(this.listInfo)
                    })
                    .catch((error) =>{
                        this.handleErrorAlert('To update the record on page please hit Refresh when you are online');
                    })
                })
                .catch((error) =>{
                    this.handleErrorAlert('To update the record on page please hit Refresh when you are online');
                })
            })
            .catch(error => {
                this.handleErrorAlert('Record is not updated');
            });
            this.activeSections = [];
        }
        else{
            console.log('dates are invalid');
        }
    }

    handleCancel() {
        this.activeSections = [];
    }

    validateDateTime(startDateTimeObj, finishDateTimeObj){

        if((finishDateTimeObj.date + ':' + finishDateTimeObj.time) <= (startDateTimeObj.date + ':' + startDateTimeObj.time)){
            this.handleErrorAlert('Start time should be earlier than Finish time.');
            return false;
        }
        else if(finishDateTimeObj.date > startDateTimeObj.date && finishDateTimeObj.time > startDateTimeObj.time){
            this.handleErrorAlert('Offered overtime cannot be having a span of more than one day.');
            return false;
        }
        else if(startDateTimeObj.time < '08:00'){
            this.handleErrorAlert('Start time must be greater than 8 AM');
            return false;
        }
        else if(finishDateTimeObj.time > '22:30'){
            this.handleErrorAlert('Finish time must be less than 10:30 PM');
            return false;
        }
        else{
            return true;
        }
    }

    convertDateTimeToUserLocal(dateGMT){
        let dateTimeObj = {};
        // dateGMT = '2023-03-21T14:00:00.000Z'
        let localDateTime = new Date(dateGMT).toLocaleString("en-GB", {timeZone: TIME_ZONE});
        // localDateTime = '21/03/2023, 10:00:00'
        let localDateTimeString = localDateTime.toString();
        let localDate = localDateTimeString.substr(6, 4) + '-' + localDateTimeString.substr(3, 2) + '-' + localDateTimeString.substr(0, 2);
        let localTime = localDateTimeString.substr(12, 5);
        dateTimeObj.date = localDate;
        dateTimeObj.time = localTime;
        return dateTimeObj;
    }

    //handles error messages generated through the process
    async handleErrorAlert(msg) {
        await LightningAlert.open({
            message: msg,
            theme: 'error',
            label: 'Error!', // this is the header text
        });
    }

    //handles error messages generated through the process
    async handleSuccessAlert(msg) {
        await LightningAlert.open({
            message: msg,
            theme: 'success',
            label: 'Success!', // this is the header text
        });
    }
}