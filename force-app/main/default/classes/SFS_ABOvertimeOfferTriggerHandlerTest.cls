/**
 * Created by ayushmathur on 24/03/23.
 */
@IsTest
public  class SFS_ABOvertimeOfferTriggerHandlerTest {
    @TestSetup
    static void testSetup() {
        User newUser = SFS_ABTestFactory.createAServiceUser();
        newUser.Username='johnsmithfortesting@smith.com';
        newUser.TimeZoneSidKey = 'America/New_York';
        update newUser;
        
        PermissionSet ps2 = new PermissionSet();
        ps2.Name = 'Test';
        ps2.Label = 'Test';
        insert ps2;

        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = ps2.Id;
        sea.SetupEntityId = [SELECT Id FROM CustomPermission WHERE DeveloperName = 'Allow_Edit_On_Service_Territory'][0].Id;
        insert sea;

        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.AssigneeId = newUser.Id;
        psa.PermissionSetId = ps2.Id;
        insert psa;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Resources'][0];
        insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps.Id);

        PermissionSet ps1 = [SELECT Id FROM PermissionSet WHERE Name = 'Field_Service_Manage_Work'][0];
        insert new PermissionSetAssignment(AssigneeId = newUser.Id, PermissionSetId = ps1.Id);
        System.runAs(newUser) {

            ServiceResource newSR = SFS_ABTestFactory.createServiceResource(newUser);
            newSR.Name='Test Resource';
            update newSR;
        }
    }

    @IsTest
    static void test_WithNoExistingShifts (){
        User u=[SELECT Id FROM User WHERE Username='johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();

            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 18, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 22, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;

            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();

            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, overtimeOffer.Offer_Start_Time__c, 'Should be same');
            System.assertEquals(shifts[0].EndTime, overtimeOffer.Offer_Finish_Time__c, 'Should be same');
        }
    }

    @IsTest
    static void test_WithTentativeShift () {
        User u = [SELECT Id FROM User WHERE Username = 'johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();
            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Shift tentativeShift = new Shift();
            tentativeShift.StartTime = Datetime.newInstance(2023, 3, 29, 8, 0, 0);
            tentativeShift.EndTime = Datetime.newInstance(2023, 3, 29, 17, 0, 0);
            tentativeShift.Status = SFS_ABConstantUtil.SHIFT_TENTATIVE;
            tentativeShift.ServiceResourceId = serviceResource.Id;
            insert tentativeShift;

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 18, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 22, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;

            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();
            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, overtimeOffer.Offer_Start_Time__c, 'Should be same');
            System.assertEquals(shifts[0].EndTime, overtimeOffer.Offer_Finish_Time__c, 'Should be same');
        }
    }

    @IsTest
    static void test_WithOverlappingShifts () {
        User u = [SELECT Id FROM User WHERE Username = 'johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();
            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Shift confirmedShift = new Shift();
            confirmedShift.StartTime = Datetime.newInstance(2023, 3, 29, 8, 0, 0);
            confirmedShift.EndTime = Datetime.newInstance(2023, 3, 29, 17, 0, 0);
            confirmedShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
            confirmedShift.ServiceResourceId = serviceResource.Id;
            insert confirmedShift;

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 14, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 20, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;

            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();
            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, confirmedShift.StartTime, 'Start time would be of existing shift since its before');
            System.assertEquals(shifts[0].EndTime, overtimeOffer.Offer_Finish_Time__c, 'End time would be of overtime shift');
        }
    }
    @IsTest
    static void test_WithMutualShifts () {
        User u = [SELECT Id FROM User WHERE Username = 'johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();
            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Shift confirmedShift = new Shift();
            confirmedShift.StartTime = Datetime.newInstance(2023, 3, 29, 8, 0, 0);
            confirmedShift.EndTime = Datetime.newInstance(2023, 3, 29, 17, 0, 0);
            confirmedShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
            confirmedShift.ServiceResourceId = serviceResource.Id;
            insert confirmedShift;

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 19, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 22, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();
            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            System.debug('shifts recived '+shifts);
Id recordtypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
            List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End, ResourceId FROM ResourceAbsence WHERE ResourceId = :serviceResource.Id AND RecordTypeId = :recordtypeId];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, confirmedShift.StartTime, 'Start time would be of existing shift since its before');
            System.assertEquals(shifts[0].EndTime, overtimeOffer.Offer_Finish_Time__c, 'End time would be of overtime shift');
            System.assertEquals(resourceAbsences.size(), 1, '1 RA should be returned');
            System.assertEquals(resourceAbsences[0].Start, confirmedShift.EndTime, 'RA start should be existing shift end');
            System.assertEquals(resourceAbsences[0].End, overtimeOffer.Offer_Start_Time__c, 'RA end should be Overtime shift start');
        }
    }
    @IsTest
    static void test_WithMutualShiftsBeforeOriginalShift () {
        User u = [SELECT Id FROM User WHERE Username = 'johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();
            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Shift confirmedShift = new Shift();
            confirmedShift.StartTime = Datetime.newInstance(2023, 3, 29, 17, 0, 0);
            confirmedShift.EndTime = Datetime.newInstance(2023, 3, 29, 19, 0, 0);
            confirmedShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
            confirmedShift.ServiceResourceId = serviceResource.Id;
            insert confirmedShift;

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 11, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 14, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();
            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            Id recordtypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
            List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End, ResourceId FROM ResourceAbsence WHERE ResourceId = :serviceResource.Id AND RecordTypeId = :recordtypeId];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, overtimeOffer.Offer_Start_Time__c, 'Start time would be of OVERTIME shift since its before');
            System.assertEquals(shifts[0].EndTime, confirmedShift.EndTime, 'End time would be of existing shift');
            System.assertEquals(resourceAbsences.size(), 1, '1 RA should be returned');
            System.assertEquals(resourceAbsences[0].Start, overtimeOffer.Offer_Finish_Time__c, 'RA start should be overtimeOffer shift end');
            System.assertEquals(resourceAbsences[0].End, confirmedShift.StartTime, 'RA end should be confirmedShift start');

        }
    }
    @IsTest
    static void test_WithOverlappingShiftsBeforeOriginalShift () {
        User u = [SELECT Id FROM User WHERE Username = 'johnsmithfortesting@smith.com'];
        System.runAs(u) {
            Test.startTest();
            ServiceResource serviceResource = [SELECT Id FROM ServiceResource WHERE Name = 'Test Resource'];

            Shift confirmedShift = new Shift();
            confirmedShift.StartTime = Datetime.newInstance(2023, 3, 29, 12, 0, 0);
            confirmedShift.EndTime = Datetime.newInstance(2023, 3, 29, 19, 0, 0);
            confirmedShift.Status = SFS_ABConstantUtil.SHIFT_CONFIRMED;
            confirmedShift.ServiceResourceId = serviceResource.Id;
            insert confirmedShift;

            Overtime_Offers__c overtimeOffer = new Overtime_Offers__c();
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_OFFERED;
            overtimeOffer.Offer_Start_Time__c = Datetime.newInstance(2023, 3, 29, 10, 0, 0);
            overtimeOffer.Offer_Finish_Time__c = Datetime.newInstance(2023, 3, 29, 14, 0, 0);
            overtimeOffer.Service_Resource__c = serviceResource.Id;
            insert overtimeOffer;
            overtimeOffer.Status__c = SFS_ABConstantUtil.OVERTIME_HIRED;
            update overtimeOffer;
            Test.stopTest();
            List<Shift> shifts = [SELECT Id, StartTime, EndTime, ServiceResourceId, Status FROM Shift WHERE Status = 'Confirmed'];
            Id recordtypeId = SFS_ABConstantUtil.RA_NON_AVAILABILITY_RECORDTYPE;
            List<ResourceAbsence> resourceAbsences = [SELECT Id, Start, End, ResourceId FROM ResourceAbsence WHERE ResourceId = :serviceResource.Id AND RecordTypeId = :recordtypeId];
            System.assertEquals(shifts.size(), 1, '1 shift should be returned');
            System.assertEquals(shifts[0].ServiceResourceId, overtimeOffer.Service_Resource__c, 'Should be same');
            System.assertEquals(shifts[0].StartTime, overtimeOffer.Offer_Start_Time__c, 'Start time would be of OVERTIME shift since its before');
            System.assertEquals(shifts[0].EndTime, confirmedShift.EndTime, 'End time would be of existing shift');
            System.assertEquals(resourceAbsences.size(), 0, '0 RA should be returned');
        }
    }
}