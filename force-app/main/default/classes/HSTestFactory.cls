@isTest
public with sharing class HSTestFactory {
    
    public static final String dailyCapacityType  = 'Daily Capacity'; 
    public static final String ruleCapacityType  = 'Rule Based Capacity';
    
    public static User UserCreate() { 
        UserRole obj=new UserRole(Name= 'ABC'); 
        insert obj; 
        
        Profile pf= [Select Id from profile where Name='System Administrator']; 
        
        String orgId=UserInfo.getOrganizationId(); 
        String dateString=String.valueof(Datetime.now()).replace(' ','').replace(':','').replace('-','') ;
        
        Integer RandomId=Integer.valueOf(Math.rint(Math.random()*1000000)); 
        String uniqueName=orgId+dateString+RandomId; 
        
        User uu=new User(firstname = 'ABC', 
                         lastName = 'XYZ', 
                         email = uniqueName + '@test' + orgId + '.org', 
                         Username = uniqueName + '@test' + orgId + '.org', 
                         EmailEncodingKey = 'ISO-8859-1', 
                         Alias = uniqueName.substring(18, 23), 
                         TimeZoneSidKey = 'America/New_York', 
                         LocaleSidKey = 'en_US', 
                         LanguageLocaleKey = 'en_US', 
                         ProfileId = pf.Id, 
                         UserRoleId = obj.Id);
        insert uu;
        
        PermissionSet ps = new PermissionSet();
        ps.Name = 'Test';
        ps.Label = 'Test';
        insert ps;
        SetupEntityAccess sea = new SetupEntityAccess();
        sea.ParentId = ps.Id;
        sea.SetupEntityId = [select Id from CustomPermission where DeveloperName = 'Allow_Edit_On_Service_Territory'][0].Id;
        insert sea;
        PermissionSetAssignment psa = new PermissionSetAssignment();
        psa.AssigneeId = uu.Id;
        psa.PermissionSetId = ps.Id;
        insert psa;
        
        return uu;
    } 
    
    public static OperatingHours creatOperatingHours(string name, String timeZone ){
        OperatingHours operatingHoursObj = new OperatingHours(Name = name,TimeZone = timeZone);
        insert operatingHoursObj;
        return operatingHoursObj;
    }
    
    public static TimeSlot creatTimeSlot(OperatingHours operatingHoursObj, Time startTime, Time endTime ){
        TimeSlot timeSlotObj = new TimeSlot(OperatingHoursId = operatingHoursObj.Id,StartTime = startTime,EndTime = endTime);                 
        insert timeSlotObj;
        return timeSlotObj;
    }
    
    public static ServiceTerritory creatServiceTerritory(string name, OperatingHours operatingHoursObj,boolean isActive  ){
        ServiceTerritory serviceTerritoryObj = new ServiceTerritory(Name = name,OperatingHoursId = operatingHoursObj.Id,IsACTIVE = isActive);
        Insert serviceTerritoryObj;
        return serviceTerritoryObj;
    }
    
    public static WorkOrder createWorkOrder(){
        WorkOrder workOrderObj = new WorkOrder();
        insert workOrderObj;
        return workOrderObj;
    }
    
    public static ServiceAppointment createSA(WorkOrder workOrderObj,string status, DateTime earlyStart, DateTime dueDate, ServiceTerritory serviceTerritoryObj){
        
        ServiceAppointment serviceAppointmentObj = new ServiceAppointment (ParentRecordId = workOrderObj.Id,Status = status,EarliestStartTime =  earlyStart,DueDate = dueDate,ServiceTerritoryId = serviceTerritoryObj.id);
        insert serviceAppointmentObj;
        return serviceAppointmentObj;
    }
    
    public static ServiceAppointment createSAWithArrivalWindow(WorkOrder workOrderObj,string status, DateTime earlyStart, DateTime dueDate, ServiceTerritory serviceTerritoryObj){
        
        ServiceAppointment serviceAppointmentObj = new ServiceAppointment (ParentRecordId = workOrderObj.Id,Status = status,EarliestStartTime =  earlyStart,DueDate = dueDate,ServiceTerritoryId = serviceTerritoryObj.id);
        serviceAppointmentObj.ArrivalWindowStartTime = Datetime.now().addDays(1);
        serviceAppointmentObj.ArrivalWindowEndTime = Datetime.now().addDays(1).addHours(3);
        serviceAppointmentObj.SchedStartTime = Datetime.now().addDays(1);
        serviceAppointmentObj.SchedEndTime = Datetime.now().addDays(1).addHours(3);
        insert serviceAppointmentObj;
        return serviceAppointmentObj;
    }
    
    
    
    public static void createPostRequest(String postURL, ABWrapper.requestWrapper wrapper) {
        RestRequest req = new RestRequest(); 
        RestResponse res = new RestResponse();
        
        req.requestURI = postURL;
        req.httpMethod = 'POST';
        
        
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        
        RestContext.request = req;
        RestContext.response= res;
    }
    
    public static ServiceAppointment createServiceAppt(id parentId, string status) {
        
        OperatingHours creatOperatingObj = HSTestFactory.creatOperatingHours('TestOH','America/New_York');
        
        ServiceTerritory serviceTerritoryObj = HSTestFactory.creatServiceTerritory('Maryland',creatOperatingObj,true);
        
        ServiceAppointment serAppointment = new ServiceAppointment();
        
        serAppointment.ParentRecordId = parentId;
        serAppointment.Status = status;
        serAppointment.EarliestStartTime =  datetime.newInstance(2023, 02, 12, 12, 00, 0);   
        serAppointment.DueDate = datetime.newInstance(2023, 12, 12, 12, 00, 0);                              
        serAppointment.ServiceTerritoryId = serviceTerritoryObj.id;
        serAppointment.Street = '23221 Stringtown Rd';
        serAppointment.City = 'Clarksburg';    
        serAppointment.State = 'MD';
        serAppointment.PostalCode ='20871';
        serAppointment.Country =  'United States';                         
        insert serAppointment;
        return serAppointment;
    }
    
    public static ServiceAppointment newSAObj(String Status){
        OperatingHours operatingHour = HSTestFactory.creatOperatingHours('Eastern Operating Hours Test', 'America/New_York');	
        ServiceTerritory serviceTerritory = HSTestFactory.creatServiceTerritory('MD', operatingHour, True);
        
        Datetime beforeStartDate = system.Today().addDays(1);	
        Datetime beforeEndDate = system.Today().addDays(3);	
        
        WorkOrder objWorkOrder = new WorkOrder();
        objWorkOrder.StartDate = beforeStartDate;	
        objWorkOrder.EndDate = beforeEndDate;	
        objWorkOrder.State = 'MD';	
        objWorkOrder.ServiceTerritoryId = serviceTerritory.Id;	
        insert objWorkOrder;	
        
        ServiceAppointment serAppointment = HSTestFactory.createSA(objWorkOrder,Status,datetime.newInstance(2022, 7, 05, 13, 00, 0),datetime.newInstance(2022, 7, 30, 14, 00, 0),serviceTerritory);
        return serAppointment;
    }
    
    public static FSL__Scheduling_Policy__c createSchedulingPolicy(Boolean bookSlot){
        FSL__Scheduling_Policy__c fslSchedulingPolicy = new FSL__Scheduling_Policy__c();	
        fslSchedulingPolicy.Name = 'HS Scheduling Policy';

        if(bookSlot){
            fslSchedulingPolicy.Used_for_Appointment_Booking__c = false;
            fslSchedulingPolicy.FSL__Daily_Optimization__c = true;
        }else{
            fslSchedulingPolicy.Used_for_Appointment_Booking__c = true;
            fslSchedulingPolicy.FSL__Daily_Optimization__c = false;
        }
       
        insert fslSchedulingPolicy;	
        return fslSchedulingPolicy;
    }
    
    public static void createOperatingHour(){
        OperatingHours operatingHour = new OperatingHours();	
        operatingHour.Name = 'HS Operating Hour';
        operatingHour.Used_for_Appointment_Booking__c = true;
        insert operatingHour;	
    }
    
    public static Consumed_Capacity__c createConsumedCapacity(String capacityType, integer overallCapacity, integer maxPercent, integer overallConsump, integer overallCapRule, integer ruleConsump, integer maxRule,  Consumed_Capacity__c parentCC){
        
        Consumed_Capacity__c cc = new Consumed_Capacity__c();
        cc.Type__c = capacityType;
        cc.Slots__c = SFS_ABConstantUtil.Slot8To12;
        cc.Capacity_Date__c = Date.newInstance(Datetime.now().year(), Datetime.now().month(), Datetime.now().day()+1);
        
        if(capacityType == dailyCapacityType){
            cc.Overall_Capacity__c = overallCapacity;
            cc.Max__c = maxPercent;
            cc.Overall_Consumption__c = overallConsump;
        }
        
        if(capacityType == ruleCapacityType){
            cc.Overall_Capacity_Rule__c = overallCapRule;
            cc.Rule_Consumption__c = ruleConsump;
            cc.Max_Rule__c = maxRule; 
            cc.Parent_Consumed_Capacity__c = parentCC.Id;
        }
        insert cc;
        
        Consumed_Capacity__c insertedCC = [SELECT Id, Name, Type__c, Is_Daily_Capacity_Available__c, Is_Rule_Based_Capacity_Available__c, Value__c, Capacity_Date__c, Active__c, Slots__c FROM Consumed_Capacity__c where Id =: cc.Id LIMIT 1];
        return insertedCC;
    }
    
    public static Resource_Capacity__c createResourceCapacity(Integer capacity, Date capacityDate, Id resourceId, Id territoryId){
        Resource_Capacity__c rc = new Resource_Capacity__c();
        rc.Capacity__c = capacity;
        rc.Capacity_Date__c = capacityDate;
        rc.Service_Resource__c = resourceId;
        rc.Service_Territory__c = territoryId;
        
        insert rc;
        
        Resource_Capacity__c insertedRC = [SELECT Id, Capacity__c, Capacity_Date__c, Service_Resource__c, Service_Territory__c FROM Resource_Capacity__c where Id =: rc.Id LIMIT 1];
        return insertedRC;
        
    }
}