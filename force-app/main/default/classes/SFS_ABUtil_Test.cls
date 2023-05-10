@isTest
public with sharing class SFS_ABUtil_Test {
    
    @isTest static void resourceCapacityUpdateTest() {
        User userRec = HSTestFactory.UserCreate();
        system.runAs(userRec) { 
            
            Test.startTest();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            OperatingHours operatingHourObj = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');
            TimeSlot timeSlotObj = HSTestFactory.creatTimeSlot(operatingHourObj, Time.newInstance(8,0,0,0), Time.newInstance(20,30,0,0));
            ServiceTerritory serviceTerritoryObj = HSTestFactory.creatServiceTerritory('Maryland',operatingHourObj,true);
            ServiceAppointment testSA = HSTestFactory.createSAWithArrivalWindow(testWO,'Open', DateTime.now().addDays(1),DateTime.now().addDays(10),serviceTerritoryObj);
            ServiceResource resource = SFS_ABTestFactory.createServiceResource(userRec);
            ServiceTerritoryMember stm = SFS_ABTestFactory.createServiceTerritoryMember(resource, serviceTerritoryObj);
            FSL.GlobalAPIS.addStatusTransition(SFS_ABConstantUtil.SA_OPEN, SFS_ABConstantUtil.SA_SCHEDULED);
            
            //Create Assigned Resource
            AssignedResource ar = new AssignedResource();
            ar.ServiceAppointmentId = testSA.Id;
            ar.ServiceResourceId = resource.Id;
            insert ar;
            
            //Insert RCs
            HSTestFactory.createResourceCapacity(8, System.Today() + 1, resource.id, serviceTerritoryObj.Id);
			HSTestFactory.createResourceCapacity(8, System.Today() + 1, resource.id, serviceTerritoryObj.Id);
            
            SFS_ABUtil.resourceCapacityUpdate(testSA, resource.Id);
            Test.stopTest();
        }
    }
    
    @isTest static void rescheduleJobsTest() {
        User userRec = HSTestFactory.UserCreate();
        system.runAs(userRec) {
            
            Test.startTest();
            WorkOrder testWO = HSTestFactory.createWorkOrder();
            ServiceAppointment testSA = HSTestFactory.createSAWithArrivalWindow(testWO,'Open',datetime.newInstance(2022, 7, 05, 13, 00, 0),datetime.newInstance(2022, 7, 30, 14, 00, 0),new ServiceTerritory());
            List<ServiceAppointment> listOfAppointments = new List<ServiceAppointment>();
            listOfAppointments.add(testSA);
            SFS_ABUtil.rescheduleJobs(listOfAppointments);
            Test.stopTest();
        }
    }
    
    @isTest static void getSchedulingPolicyByNameTest() {
        User userRec = HSTestFactory.UserCreate();
        system.runAs(userRec) {
            
            Test.startTest();
            SFS_ABUtil.getSchedulingPolicyByName('');
            Test.stopTest();
        }
    }
    
    @isTest static void timeZoneMethodsTest() {
        User userRec = HSTestFactory.UserCreate();
        system.runAs(userRec) {
            
            Test.startTest();
            OperatingHours opHours = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');
            SFS_ABUtil.convertDateTimeToTerritorysTZ(opHours.TimeZone, DateTime.now());
            SFS_ABUtil.convertDateTimeToTerritorysTZNonGMT(opHours.TimeZone, DateTime.now());
            SFS_ABUtil.formatDatesToAppointmentTimeZone(opHours.TimeZone, DateTime.now()); 
            SFS_ABUtil.formatDatesToAppointmentTimeZone(opHours.TimeZone, null); 
            
            Test.stopTest();
        }
    }
    
}