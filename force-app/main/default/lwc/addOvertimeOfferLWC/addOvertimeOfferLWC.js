import { LightningElement, api, wire, track } from 'lwc';
import getServiceResource from '@salesforce/apex/ViewingRecordsOnMobileHelper.getServiceResource';
import { createRecord  } from 'lightning/uiRecordApi';
import LightningAlert from 'lightning/alert';
import Id from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';
import TIME_ZONE from '@salesforce/i18n/timeZone';
import STARTDATE_FIELD from '@salesforce/schema/Overtime_Offers__c.Offer_Start_Time__c';
import FINISHDATE_FIELD from '@salesforce/schema/Overtime_Offers__c.Offer_Finish_Time__c';
import STATUS_FIELD from '@salesforce/schema/Overtime_Offers__c.Status__c';
import COMMENT_FIELD from '@salesforce/schema/Overtime_Offers__c.Comment__c';
import SERVICERESOURCE_FIELD from '@salesforce/schema/Overtime_Offers__c.Service_Resource__c';
import OVERTIMEOFFER_OBJECT from '@salesforce/schema/Overtime_Offers__c';

export default class AddOvertimeOfferLWC extends NavigationMixin(LightningElement) {

    userId = Id;
    serviceResourceId;
    allValid = true;
    errorMessage;

    @wire(getServiceResource, {userId: '$userId'})
    listInfo({ error, data }){
        if (data) {
            this.serviceResourceId = data;
        }
        else if (error) {
            console.log('error', JSON.parse(JSON.stringify(error)));
        }
    }

    handleSave(event){
        const fields = {};
        this.template.querySelectorAll('lightning-input')
        .forEach((element) => {
            if(element.name == 'startDateTime'){
                fields[STARTDATE_FIELD.fieldApiName] = element.value;
            }
            else if(element.name == 'finishDateTime'){
                fields[FINISHDATE_FIELD.fieldApiName] = element.value;
            }
            else if(element.name == 'comment'){
                fields[COMMENT_FIELD.fieldApiName] = element.value;
            }
        });
        fields[STATUS_FIELD.fieldApiName] = 'Offered';
        fields[SERVICERESOURCE_FIELD.fieldApiName] = this.serviceResourceId;
        const recordInput = { apiName: OVERTIMEOFFER_OBJECT.objectApiName, fields };
        const startDateTimeObj = this.convertDateTimeToUserLocal(fields[STARTDATE_FIELD.fieldApiName]);
        const finishDateTimeObj = this.convertDateTimeToUserLocal(fields[FINISHDATE_FIELD.fieldApiName]);

        if(Object.keys(startDateTimeObj).length !== 0 && Object.keys(finishDateTimeObj).length !== 0){
            this.allValid = this.validateDateTime(startDateTimeObj, finishDateTimeObj);
        }

        if(this.allValid){
            createRecord (recordInput)
            .then(() => {
                this.handleSuccessAlert('Record has been created successfully!')
                .then(() => {
                    this.clearInputValues();
                    this[NavigationMixin.Navigate]({
                        "type": "standard__webPage",
                        "attributes": {
                        "url": `com.salesforce.fieldservice://v1/sObject/${this.serviceResourceId}`
                        }
                    });
                })
                .catch((error) =>{
                    this.handleErrorAlert('Something went wrong');
                })
            })
            .catch(error => {
                this.handleErrorAlert('Something went wrong');
            });
        }
        else{
            this.handleErrorAlert(this.errorMessage);
        }
    }

    clearInputValues(){
        this.template.querySelectorAll('lightning-input')
        .forEach((element) => {
            element.value = '';
        });
    }

    validateDateTime(startDateTimeObj, finishDateTimeObj){

        if((finishDateTimeObj.date + ':' + finishDateTimeObj.time) <= (startDateTimeObj.date + ':' + startDateTimeObj.time)){
            this.errorMessage = 'Start time should be earlier than Finish time.';
            return false;
        }
        else if(finishDateTimeObj.date > startDateTimeObj.date && finishDateTimeObj.time > startDateTimeObj.time){
            this.errorMessage = 'Offered overtime cannot be having a span of more than one day.';
            return false;
        }
        else if(startDateTimeObj.time < '08:00'){
            this.errorMessage = 'Start time must be greater than 8 AM';
            return false;
        }
        else if(finishDateTimeObj.time > '22:30'){
            this.errorMessage = 'Finish time must be less than 10:30 PM';
            return false;
        }
        else{
            return true;
        }
    }

    convertDateTimeToUserLocal(dateGMT){
        let dateTimeObj = {};
        if(dateGMT === null || dateGMT === ''){
            this.allValid = false;
            this.errorMessage = 'Date fields are required'
        }
        else{
            // dateGMT = '2023-03-21T14:00:00.000Z'
            let localDateTime = new Date(dateGMT).toLocaleString("en-GB", {timeZone: TIME_ZONE});
            // localDateTime = '21/03/2023, 10:00:00'
            let localDateTimeString = localDateTime.toString();
            let localDate = localDateTimeString.substr(6, 4) + '-' + localDateTimeString.substr(3, 2) + '-' + localDateTimeString.substr(0, 2);
            let localTime = localDateTimeString.substr(12, 5);
            console.log(localDate, ':', localTime);
            dateTimeObj.date = localDate;
            dateTimeObj.time = localTime;
        }
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