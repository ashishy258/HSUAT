import { LightningElement,api, wire, track } from 'lwc';
import saveSign from '@salesforce/apex/HS_SignatureHelper.saveSign';
import isSignatureScreenVisible from '@salesforce/apex/HS_SignatureHelper.isSignatureScreenVisible';
import costInformation from '@salesforce/apex/HS_SignatureHelper.costInformation';
import LightningAlert from 'lightning/alert';
import { NavigationMixin } from 'lightning/navigation';
import { updateRecord } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';

//Importing fields for Updaing Work Order
import ID_FIELD from '@salesforce/schema/WorkOrder.Id';
import TOTALPAYMENT_FIELD from '@salesforce/schema/WorkOrder.Total_Payments__c';
import CREDITCARDAMOUNT_FIELD from '@salesforce/schema/WorkOrder.Credit_Card_Amount__c';
import CHEQUEAMOUNT_FIELD from '@salesforce/schema/WorkOrder.Check_Amount__c';
import CHEQUENUMBER_FIELD from '@salesforce/schema/WorkOrder.Check_Number__c';
import CASHAMOUNT_FIELD from '@salesforce/schema/WorkOrder.Cash_Amount__c';
import MONEYORDERAMOUNT_FIELD from '@salesforce/schema/WorkOrder.Money_Order_Amount__c';
import MONEYORDERNUMBER_FIELD from '@salesforce/schema/WorkOrder.Money_Order_Number__c';
import MONEYORDERBANKNAME_FIELD from '@salesforce/schema/WorkOrder.Money_Order_Bank_Name__c';
import REMAININGBALANCE_FIELD from '@salesforce/schema/WorkOrder.Remaining_Balance__c';
import REMAININGBALNACENOTES_FIELD from '@salesforce/schema/WorkOrder.Remaining_Balance_Notes__c';

//declaration of variables for calculations
let prevX = 0,
    currX = 0,
    prevY = 0,
    currY = 0;            
       
let x = "#0000A0"; //blue color
let y = 1.5; //weight of line width and dot.       
let attachment;
let canvasElement, ctx,customerDeclined=false,customersigned=false; //storing canvas context
let dataURL,convertedDataURI; //holds image data
//canvas on mobile
document.body.addEventListener("touchstart", function (e) {
    if (e.target == canvas) {
      e.preventDefault();
    }
  }, false);
 
  document.body.addEventListener("touchmove", function (e) {
    if (e.target == canvas) {
      e.preventDefault();
    }
  }, false);
export default class CaptureSignature extends NavigationMixin(LightningElement) {
    @api recordId;
    error;
    isScreenVisible = false;
    isCannotInitiate = false;
    parentWorkOrderId;
    notOnsite=false;
    randomNumber;
    showSpinner = false;
    wrapUpFalseMessage;
    isWOComplete = false;
    showCanvas = false;
    fields;
    isChequeNumberReq = false;
    isMoneyOrderReq = false;
    isRemainingBalanceCheckBoxReq = false;
    isRemainingBalanceReq = false;
    @track chequeNumber;
    @track moneyOrderNumber;
    @track moneyOrderBankName;
    isChequeNumberDisabled = true;
    isMoneyOrderNumberDisabled = true;
    isMoneyOrderBankNameDisabled = true;
    isRemainingBalanceNotesDisabled = false;
    remainingCheckBoxValue = true;
    totalTax = 0;
    totalLabor = 0;
    totalParts = 0;
    totalAdjustments = 0;
    totalServiceCall = 0;
    outstandingBalance = 0;
    totalSavings = 0;
    totalDue = 0;
    totalPayment = 0;
    @wire(costInformation, {recordId : '$recordId', randomNumber: '$randomNumber'})
    tableData({ error, data }){
        if (data) {
            console.log('tableData', JSON.parse(JSON.stringify(data)));
            this.totalTax = data.hasOwnProperty('Tax') ? data['Tax'] : 0;
            this.totalLabor = data.hasOwnProperty('Total_Labor__c') ? data['Total_Labor__c'] : 0;
            this.totalParts = data.hasOwnProperty('Total_Parts__c') ? data['Total_Parts__c'] : 0;
            this.totalAdjustments = data.hasOwnProperty('Total_Adjustments__c') ? data['Total_Adjustments__c'] : 0;
            this.totalServiceCall = data.hasOwnProperty('Total_Service_Call__c') ? data['Total_Service_Call__c'] : 0;
            this.outstandingBalance = data.hasOwnProperty('Outstanding_Balance__c') ? data['Outstanding_Balance__c'] : 0;
            this.totalSavings = data.hasOwnProperty('Total_Savings__c') ? data['Total_Savings__c'] : 0;
            this.totalDue = data.hasOwnProperty('Total_Due__c') ? data['Total_Due__c'] : 0;

            if(this.totalDue > 0){
                this.isRemainingBalanceCheckBoxReq = true;
                this.isRemainingBalanceReq = true;
            }
        }
        else if (error) {
            console.log('error', JSON.parse(JSON.stringify(error)));
        }
    }

    handleInputChange(event) {
        event.target.reportValidity();
    }

    handleCheckBoxChange(event){
        this.isRemainingBalanceNotesDisabled = event.target.checked ? false : true;
        setTimeout(() => {
            this.handleValidation();
        }, 100);
    }

    handleBlur(event){
        this.totalPayment = 0;
        this.isChequeNumberReq = false;
        this.isMoneyOrderReq = false;
        this.template.querySelectorAll('.number')
        .forEach((element) => {
            if(parseFloat(element.value) > 0){
                this.totalPayment = this.totalPayment + parseFloat(element.value);
                if(element.name === "check_amount__c"){
                    this.isChequeNumberReq = true;
                    this.isChequeNumberDisabled = false;
                }
                if(element.name === "money_order_amount__c"){
                    this.isMoneyOrderReq = true;
                    this.isMoneyOrderNumberDisabled = false;
                    this.isMoneyOrderBankNameDisabled = false;
                }
            }
            else if(element.value === '' || element.value === '0'){
                element.value = '0';
                if(element.name === "check_amount__c"){
                    this.chequeNumber = '';
                    this.isChequeNumberDisabled = true;
                }
                if(element.name === "money_order_amount__c"){
                    this.moneyOrderNumber = '';
                    this.moneyOrderBankName = '';
                    this.isMoneyOrderNumberDisabled = true;
                    this.isMoneyOrderBankNameDisabled = true;
                }
            }
        });

        this.isRemainingBalanceCheckBoxReq = this.totalPayment !== this.totalDue ? true : false;
        this.remainingCheckBoxValue = this.totalPayment === this.totalDue ? false : true;
        this.isRemainingBalanceNotesDisabled = this.remainingCheckBoxValue ? false : true;
        this.isRemainingBalanceReq = this.isRemainingBalanceCheckBoxReq;

        setTimeout(() => {
            this.handleValidation();
        }, 100);
        
    }

    handleValidation(){
        this.template.querySelectorAll('.input')
        .forEach((element) => {
            if(element.required === false){
                if((element.name === 'remaining_balance__c' && element.checked === false) || (element.value === '' || element.value === undefined)){
                    element.setCustomValidity('');
                    element.reportValidity(); 
                }
            }
            if(element.disabled === true){
                element.value = '';
            }
        });
    }

    handleSave(){
        console.log('save');
        let editableElements = [];
        this.template.querySelectorAll('.input')
        .forEach((element) => {
            if(!element.disabled){
                editableElements.push(element);
            }
            else{
                element.value = '';
            }
        });
        const allValid = editableElements.reduce((validSoFar, inputFields) => {
                                                inputFields.reportValidity();
                                                return validSoFar && inputFields.checkValidity();
                                            }, true);
        
        if (allValid) {
            // Create the recordInput object
            const fields = {};
            fields[ID_FIELD.fieldApiName] = this.recordId;
            fields[TOTALPAYMENT_FIELD.fieldApiName] = parseFloat(this.template.querySelector("[data-field='total_payments__c']").value);
            fields[CREDITCARDAMOUNT_FIELD.fieldApiName] = parseFloat(this.template.querySelector("[data-field='credit_card_amount__c']").value);
            fields[CHEQUEAMOUNT_FIELD.fieldApiName] = parseFloat(this.template.querySelector("[data-field='check_amount__c']").value);
            fields[CHEQUENUMBER_FIELD.fieldApiName] = parseInt(this.template.querySelector("[data-field='check_number__c']").value);
            fields[CASHAMOUNT_FIELD.fieldApiName] = parseFloat(this.template.querySelector("[data-field='cash_amount__c']").value);
            fields[MONEYORDERAMOUNT_FIELD.fieldApiName] = parseFloat(this.template.querySelector("[data-field='money_order_amount__c']").value);
            fields[MONEYORDERNUMBER_FIELD.fieldApiName] = parseInt(this.template.querySelector("[data-field='money_order_number__c']").value);
            fields[MONEYORDERBANKNAME_FIELD.fieldApiName] = this.template.querySelector("[data-field='money_order_bank_name__c']").value;
            fields[REMAININGBALANCE_FIELD.fieldApiName] = this.template.querySelector("[data-field='remaining_balance__c']").checked;
            fields[REMAININGBALNACENOTES_FIELD.fieldApiName] = this.template.querySelector("[data-field='remaining_balance_notes__c']").value === undefined ? "" : this.template.querySelector("[data-field='remaining_balance_notes__c']").value;

            const recordInput = { fields };
            console.log('recordInput: ', recordInput);
            updateRecord(recordInput)
                .then(() => {
                    //this.handleSuccessAlert('Record has been saved successfully!.')
                    this.handleSaveClick();
                })
                .catch(error => {
                    this.handleErrorAlert(JSON.stringify(error));
                });
        }
        else {
            if(customersigned==false && customerDeclined==false){
            
                this.handleErrorAlert('Please enter Payment details and Customer Signature');
            }
            else{
                this.handleErrorAlert('Please enter Payment details');
            }
        }
    }

    @wire(isSignatureScreenVisible, {recordId:'$recordId', randomNumber: '$randomNumber'})
    listInfo({ error, data }){
        if (data) {
            console.log(data);
            this.valuetoprint=data['Customer_Name__c'];
            this.error = 'data';
            this.isScreenVisible = data['Wrap_Up__c'];
            
            this.parentWorkOrderId = data['Id'];

            if(data['Status']!='In Progress' && data['Status']!=='Completed')
            {
                this.notOnsite=true;
            }
            else{
                this.isCannotInitiate = !this.isScreenVisible;
            
           if(this.isScreenVisible && data['Status']!=='Completed')
            {
                this.showCanvas=true;
            }
            else if(data['Status']=='Completed')
            {
            this.isWOComplete=true;
            }
            
        }
        }
        else if (error) {
            this.handleErrorAlert('You are currently offline. Please try when online');
            this.error = JSON.stringify(error);
            console.log('error', JSON.parse(JSON.stringify(error)));
        }
    }

    connectedCallback(){
      this.randomNumber = Math.random();
    }

    //retrieve canvase and context
    renderedCallback(){
        if(this.showCanvas){
            canvasElement = this.template.querySelector('canvas');
            ctx = canvasElement.getContext("2d");
        }
    }
    handleChange(event)
    {
        customerDeclined=event.target.checked;
    }
    
   
    handleSaveClick(){
        //convert to png image as dataURL
        dataURL = canvasElement.toDataURL("image/png");
        //convert that as base64 encoding
        convertedDataURI = dataURL.replace(/^data:image\/(png|jpg);base64,/, "");
       if(customersigned==false && customerDeclined==false)
       {
       
            this.handleErrorAlert('Please collect Customer Signature or select Customer Declined to Sign checkbox');
       }
       else{
        this.showSpinner = true;  
        //call Apex method imperatively and use promise for handling sucess & failure
        saveSign({relatedId:this.recordId,strSignElement: convertedDataURI,customerDeclined:customerDeclined})
            .then(result => {
                this.showSpinner = false;
                 //set to draw behind current content
                ctx.globalCompositeOperation = "destination-over";
                ctx.fillStyle = "#FFF"; //white
                ctx.fillRect(0,0,canvasElement.width, canvasElement.height); 
                customersigned=false;
            
                this.handleSuccessAlert('Service Appointment has been Completed successfully!')
                .then(() => {
                    
                    this[NavigationMixin.Navigate]({
                        "type": "standard__webPage",
                        "attributes": {
                            "url": `com.salesforce.fieldservice://v1/sObject/${this.parentWorkOrderId}/details`
                        }
                    });
                })
                .catch((error) =>{
                    this.showSpinner = false;
                    this.handleErrorAlert('Something went wrong.');
                })
            
            })
            .catch(error => {
                this.showSpinner = false;
                //show error message
                console.log('error '+error);
                this.handleErrorAlert('Some error occured. Please try again or contact administrator.');
            });
        }
    }

    //clear the signature from canvas
    handleClearClick(){
        customersigned=false;
        ctx.clearRect(0, 0, canvasElement.width, canvasElement.height);          
    }

    

    //This method is primary called from mouse down & move to setup cordinates.
    setupCoordinate(eventParam){
        //get size of an element and its position relative to the viewport 
        //using getBoundingClientRect which returns left, top, right, bottom, x, y, width, height.
        const clientRect = canvasElement.getBoundingClientRect();
        prevX = currX;
        prevY = currY;
        currX = eventParam.clientX -  clientRect.left;
        currY = eventParam.clientY - clientRect.top;
    }

    //For every mouse move based on the coordinates line to redrawn
    redraw() {
        ctx.beginPath();
        ctx.lineJoin = "round";
        ctx.moveTo(prevX, prevY);
        ctx.lineTo(currX, currY);
        ctx.strokeStyle = x; //sets the color, gradient and pattern of stroke
        ctx.lineWidth = y;        
        ctx.closePath(); //create a path from current point to starting point
        ctx.stroke(); //draws the path
    }
    
    //this draws the dot
    drawDot(){
        ctx.beginPath();
        ctx.lineJoin = "round";
        ctx.fillStyle = x; //blue color
        ctx.fillRect(currX, currY, y, y); //fill rectrangle with coordinates
        ctx.closePath();
    }
    touchfunctionStart(eventParam)
    {
        eventParam.preventDefault();
        const clientRect = canvasElement.getBoundingClientRect();
        prevX = currX;
        prevY = currY;
        currX = eventParam.touches[0].clientX -  clientRect.left;
        currY = eventParam.touches[0].clientY - clientRect.top;
       
       this.drawDot();
       customersigned=true;
    }

    touchfunctionMove(eventParam)
    {
        eventParam.preventDefault();
        const clientRect = canvasElement.getBoundingClientRect();
        prevX = currX;
        prevY = currY;
        currX = eventParam.touches[0].clientX -  clientRect.left;
        currY = eventParam.touches[0].clientY - clientRect.top;
        this.redraw();
        
        
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