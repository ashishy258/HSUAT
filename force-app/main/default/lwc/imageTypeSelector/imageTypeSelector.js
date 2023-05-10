import { LightningElement } from 'lwc';

export default class ImageTypeSelector extends LightningElement {

    handleFacePlateImageSelected(){
        this.dispatchEvent(
            new CustomEvent("faceplateimageselected", {
                detail: 'Face Plate Images'
            })
        );
    }

    handleRepairImageSelected(){
        this.dispatchEvent(
            new CustomEvent("repairimageselected", {
                detail: 'Repair Images'
            })
        );
    }
}