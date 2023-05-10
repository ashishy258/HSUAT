import { LightningElement, api, wire, track } from 'lwc';
import getWorkOrder from '@salesforce/apex/ViewingRecordsOnMobileHelper.getWorkOrder';

export default class CustomerPhoneLWC extends LightningElement {

    @api recordId;
    phone;
    mobile;
    error;
    
    @wire(getWorkOrder, {recordId: '$recordId'})
    workOrderRecord({ error, data }){
        if (data) {
            this.mobile = data['Contact_Mobile_Number__c'];
            this.phone = data['Contact_Phone_Number__c'];
            console.log('data', JSON.parse(JSON.stringify(data)));
        }
        else if (error) {
            this.error = JSON.stringify(error);
            console.log('error', JSON.parse(JSON.stringify(error)));
        }
    }
}