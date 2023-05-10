@isTest
public with sharing class BookSlotTest {
    
    private static final String BOOK_SLOT_URL = '/services/apexrest/BookSlots';
    private static User sysAdmin = [SELECT ID, Name FROM USER WHERE Profile.Name = 'System Administrator' AND IsACTIVE = true LIMIT 1];
    // private static User newUser;
    
    @TestSetup
    static void setup(){
        // newUser = new User();
        // newUser = HSTestFactory.UserCreate();
    }
    
    @isTest
    static void doPostTestWithSANumber(){
        system.runAs(HSTestFactory.UserCreate()) {
            HSTestFactory.createSchedulingPolicy(true);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.ERROR_MESSAGE);        
    }
    
    @isTest
    static void doPostTestWithoutSANumber(){
        system.runAs(HSTestFactory.UserCreate()) {
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }
    
    @isTest
    static void doPostTestValidSchedulingPolicy(){
        system.runAs(HSTestFactory.UserCreate()) {
            HSTestFactory.createSchedulingPolicy(true);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }


  @isTest
    static void doPostTestValidSchedulingPolicyFalse(){
        system.runAs(HSTestFactory.UserCreate()) {
            FSL__Scheduling_Policy__c policttest = HSTestFactory.createSchedulingPolicy(true);
            policttest.Used_for_Appointment_Booking__c = false;
            update policttest;

            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }
    
    @isTest
    static void doPostTestInValidStatus(){
        system.runAs(HSTestFactory.UserCreate()) {
            FSL__Scheduling_Policy__c policttest=HSTestFactory.createSchedulingPolicy(true);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Dispatched');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            policttest.Used_for_Appointment_Booking__c=false;
            update policttest;
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }
    
    @isTest
    static void doPostTestNoSAFound(){
        system.runAs(HSTestFactory.UserCreate()) {
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            testWrapper.serviceAppointmentNumber = 'TestSA';
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }
    
    @isTest
    static void doPostTestNoSchedulingPolicy(){
        system.runAs(HSTestFactory.UserCreate()) {
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }
    
    @isTest
    static void doPostTestValidStatus(){
        system.runAs(HSTestFactory.UserCreate()) {
            HSTestFactory.createSchedulingPolicy(true);
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.newSAObj('Open');
            
            List<ServiceAppointment> tempObj = [Select id,AppointmentNumber from ServiceAppointment where id =: testSA.Id];
            
            
            ABWrapper.requestWrapper testWrapper = new ABWrapper.requestWrapper();
            // testWrapper.serviceAppointmentNumber = tempObj[0].AppointmentNumber;
            testWrapper.serviceAppointmentNumber = tempObj[0].Id;
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,testWrapper);
            
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
        System.assertEquals(ABUtil.FAILURE_STATUS_CODE, RestContext.response.statusCode,ABUtil.MISSING_PARAMETER);        
    }

    @isTest 
    static void catchBlock() {
        
        system.runAs(HSTestFactory.UserCreate()) {
            HSTestFactory.createPostRequest(BOOK_SLOT_URL,null);
            Test.startTest();
            BookSlots.doPost();
            Test.stopTest();
        }
    }
}