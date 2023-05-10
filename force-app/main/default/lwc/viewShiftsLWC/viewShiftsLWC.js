import { LightningElement, wire } from 'lwc';
import getShiftsList from '@salesforce/apex/ViewingRecordsOnMobileHelper.getShiftsList';
import { refreshApex } from '@salesforce/apex';
import LightningAlert from 'lightning/alert';
import Id from '@salesforce/user/Id';

export default class ViewShiftsLWC extends LightningElement {

    userId = Id;
    error;

    @wire(getShiftsList, {userId: '$userId'})
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