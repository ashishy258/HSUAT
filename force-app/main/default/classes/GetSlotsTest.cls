/*****************************************************************
Name:  GetSlotsTest
Copyright © 2023  ITC
============================================================
Purpose: Test Class for the GetSlots Class
============================================================
History                                                            
-------                                                            
VERSION   AUTHOR          DATE            DETAIL          Description
1.0  	Divya Dalmia   08-02-2023         Created        Created the class 
*****************************************************************/

@isTest
public with sharing class GetSlotsTest {
    
    private static final String GET_SLOT_URL = '/services/apexrest/GetSlots';
    
    @isTest static void doPostTestWithSANumber() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            //requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
            
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.ERROR_MESSAGE);
    }
    
    @isTest static void doPostTestWithNoSAFound() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            requestWrap.serviceAppointmentNumber = 'TestSA';
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
            
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.NO_SERVICE_APPOINTMENT_FOUND);
    }
    
    @isTest static void doPostTestWithNoPolicy() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            //WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
            
        }
        
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.NOT_SCHEDULED_UNSCHEDULED);
    }
    
    @isTest static void doPostTestWithInvalidStatus() {
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Dispatched');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
            
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.NOT_SCHEDULED_UNSCHEDULED);
    }
    
    @isTest static void doPostTestWithNoTerritory() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            //ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            ServiceAppointment testSA = HSTestFactory.createSA(testWO,'Open',datetime.newInstance(2022, 7, 05, 13, 00, 0),datetime.newInstance(2022, 7, 30, 14, 00, 0),new ServiceTerritory());
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];		    
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.NO_SERVICETERRITORY); 
    }
    
    @isTest static void doPostTestWithNoSlots() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            HSTestFactory.createOperatingHour();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.NO_SLOTAVAILABLE); 
    }
    
    @isTest static void doPostTestWithSlots() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            HSTestFactory.createOperatingHour();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            OperatingHours operatingHourObj = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');
            TimeSlot timeSlotObj = HSTestFactory.creatTimeSlot(operatingHourObj, Time.newInstance(8,0,0,0), Time.newInstance(20,30,0,0));
            ServiceTerritory serviceTerritoryObj = HSTestFactory.creatServiceTerritory('Maryland',operatingHourObj,true);
            ServiceAppointment testSA = HSTestFactory.createSA(testWO,'Open', DateTime.now().addDays(1),DateTime.now().addDays(10),serviceTerritoryObj);
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            FSL__Scheduling_Policy__c policy = ABUtil.fetchSchedulingPolicy(false);
            
            //Creating daily capacity
            Consumed_Capacity__c dailyCC = HSTestFactory.createConsumedCapacity('Daily Capacity', 16108 , 100, 1, 0, 0, 0, null);
            
            //Creating rule-based capacity
            Consumed_Capacity__c ruleBasedCC = HSTestFactory.createConsumedCapacity('Rule Based Capacity', 0, 0, 0, 8054, 50, 50, dailyCC);
                        
            Test.startTest();
            GetSlots.generateTimeSlots(requestWrap, true, false);
            Test.stopTest();
        }
        // System.AssertEquals(ABUtil.SUCCESS_STATUS_CODE, RestContext.response.statusCode, ABUtil.SUCCESSFULL); 
    }

    @isTest static void doPostTestWithSkipCalcTrue() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            HSTestFactory.createOperatingHour();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            OperatingHours operatingHourObj = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');
            TimeSlot timeSlotObj = HSTestFactory.creatTimeSlot(operatingHourObj, Time.newInstance(8,0,0,0), Time.newInstance(20,30,0,0));
            ServiceTerritory serviceTerritoryObj = HSTestFactory.creatServiceTerritory('Maryland',operatingHourObj,true);
            ServiceAppointment testSA = HSTestFactory.createSA(testWO,'Open', DateTime.now().addDays(1),DateTime.now().addDays(10),serviceTerritoryObj);
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            FSL__Scheduling_Policy__c policy = ABUtil.fetchSchedulingPolicy(false);
            
            //Creating daily capacity
            Consumed_Capacity__c dailyCC = HSTestFactory.createConsumedCapacity('Daily Capacity', 16108 , 100, 1, 0, 0, 0, null);
            
            //Creating rule-based capacity
            Consumed_Capacity__c ruleBasedCC = HSTestFactory.createConsumedCapacity('Rule Based Capacity', 0, 0, 0, 8054, 50, 50, dailyCC);
                        
            Test.startTest();
            GetSlots.generateTimeSlots(requestWrap, true, true);
            Test.stopTest();
        }
        // System.AssertEquals(ABUtil.SUCCESS_STATUS_CODE, RestContext.response.statusCode, ABUtil.SUCCESSFULL); 
    }
    
    @isTest static void catchBlock() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            HSTestFactory.createPostRequest(GET_SLOT_URL,null);
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
        }
    }
    
    @isTest static void doPostTestWithDefaultOH() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            HSTestFactory.createSchedulingPolicy(false);
            //HSTestFactory.createOperatingHour();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.MISSING_PARAMETER); 
    }
    
    @isTest static void doPostTestWithDefaultSP() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            
            //HSTestFactory.createSchedulingPolicy(false);
            HSTestFactory.createOperatingHour();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper requestWrap = new ABWrapper.requestWrapper();
            // requestWrap.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            requestWrap.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(GET_SLOT_URL,requestWrap);
            
            Test.startTest();
            GetSlots.doPost();
            Test.stopTest();
        }
        System.AssertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode, ABUtil.MISSING_PARAMETER); 
    }
   
    @isTest static void checkConsumedCapacityException(){
        system.runAs(HSTestFactory.UserCreate()) {
            
            List <FSL.AppointmentBookingSlot> slots = new List <FSL.AppointmentBookingSlot>();
            FSL.AppointmentBookingSlot sl = new FSL.AppointmentBookingSlot();
            
            sl.Grade = 100.0;
            slots.add(sl);
            
            Test.startTest();
            ABUtil.checkConsumedCapacity(null, null, false);
            Test.stopTest();
        }
    }
	
}