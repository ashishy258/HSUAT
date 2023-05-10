/**
 * @description       :
 * @author            : Vandana Verma 
 * @group             :
 * @last modified on  : 04-15-2023
 * Modifications Log
 * Ver   Date         Author              Modification
 * 1.0   04-15-2023   Vandana Verma        Initial Version
 **/
global class SFS_ABConstantUtil {
     public static final string SA_SCHEDULED = 'Scheduled';
    public static final string SA_DISPATCHED = 'Dispatched'; // For Mobile Dispatched Label
    public static final string SA_PRE_DISPATCHED = 'Pre-Dispatched';  // For  Dispatched Label
    public static final string SA_UNSCHEDULED = 'None';
    public static final string SA_CONFIRMED = 'Confirmed';
    public static final String TYPE_ORGANIZATION = 'Organization';
    public static final string SA_OPEN = 'Open';
    public static final string SA_CUSTOMER_UNSCHEDULED = '';
    public static final string SA_PENDINGCLOSED = 'Pending Closed';
    public static final String SA_CLOSED = 'Closed';
    public static final String SA_ONSITE = 'On-Site';
    public static final String SA_TRAVEL = 'Travel';
    public static final String SA_COMPLETED ='Completed';
    public static final String WO_OPEN = 'Open';
    public static final String WO_INPROGRESS = 'In Progress';
    public static final String WO_COMPLETED = 'Completed';
    public static final String SA_CANCELED = 'Canceled';
    public static final String SCHEDULING_BADREQUEST_MESSAGE = 'Bad Request: You must provide a Service Appointment Id and a Scheduling Policy Id.';
    public static final String AFTER_INSERT = 'AFTER_INSERT';
    public static final String BEFORE_INSERT = 'BEFORE_INSERT';
    public static final String BEFORE_UPDATE = 'BEFORE_UPDATE';
    public static final String AFTER_UPDATE = 'AFTER_UPDATE';
    public static final String BEFORE_DELETE = 'BEFORE_DELETE';
    public static final String AFTER_UNDELETE = 'AFTER_UNDELETE';
    public static final String AFTER_DELETE = 'AFTER_DELETE';
    public static final String EXCEPTION_MESSAGE = 'Exception: ';
    public static final String APPOINTMENT_NOT_CONFIRMED = 'The FSL Schedule Service did not succeed in scheduling this job. Please ensure Resources have availability to be assigned the job.';
    public static final String INBOUND_INTEGRATION_CUSTOM_PERMISSION = 'InboundIntegrationPermission';
    public static final String FSL_OPTIMIZATION_PERMISSION = 'FSLOptimizerPermission';
    public static final String DURATION_TYPE_MINUTES = 'Minutes';
    public static final STRING DURATION_TYPE_HOURS = 'Hours';
    public static final STRING Only_Business_Hours_PolicyID = 'Customer First';
    public static final STRING Extended_Hours_PolicyID = 'Customer First';
    public static final STRING RescheduleSwitchName = 'Reschedule_Switch';
    public static final String BADREQUEST_MESSAGE = 'Bad Request: You must provide a Service Appointment Id, Service Territory Id, and Scheduling Policy Id.';
    public static final String TYPE_RELOCATION = 'R';
    public static final String SYSTEM_ADMIN = 'System Administrator';
    public static final String SERVICE_ZIP = '35402';

    //Overtime_Offers__c Statuses
    public static final String OVERTIME_OFFERED ='Offered';
    public static final String OVERTIME_HIRED ='Hired';

    //Shift Status values
    public static final String SHIFT_CONFIRMED ='Confirmed';
    public static final String SHIFT_TENTATIVE ='Tentative';
    public static final String SHIFT_PUBLISHED ='Published';




    // SA's Jeopardy Reasons
    public static final String NOT_SCHEDULED ='Not Scheduled';
    public static final String LATE_COMPLETION ='Late Completion';
    public static final String LATE_START_WORK ='Late Start Work';
    public static final String LATE_START_TRAVEL ='Late Start Travel';
    
    //test constants
    public static final string MONTHLY = 'monthly';
    public static final string WEEKLY = 'weekly';
    
    public static final String TEST_USER_NAME1 = 'test_service_user1@test.com';
    public static final String TEST_USER_NAME2 = 'test_service_user2@test.com';
    public static final String TEST_ALIAS = '2222200';
    public static final String TEST_SR_GUID = '5BD0A0D3-6400-4AA4-BB08-545A42B34271';
    
    public static final String SERVICE_TERRITORY_ONE = 'ServiceTerritory1';
    public static final String SERVICE_TERRITORY_TWO = 'ServiceTerritory2';
    public static final String SERVICE_REGION = 'Service Region';
    
    public static final String GMT = 'GMT';
    public static final String EN_US = 'en_US';
    public static final String UTF_8 = 'UTF-8';
    public static final String TEST_FED_ID = 'test68168151131686851';
    public static final String GEO_REGION = 'Geo Region';
    public static final string NONE = 'None';
    
    public static final String ORGANIZATION_ONE = 'Organization1';
    public static final String ORGANIZATION_TWO = 'Organization2';
    public static final String SUB_CONTRACTOR_ACCOUNT_RELATIONSHIP = 'Sub Contractor';
    
    public static final string RS_NON_AVIAL_RT_NAME = 'Non Availability';
    
    
    //Record Type Ids
    public static final Id RA_NON_AVAILABILITY_RECORDTYPE = Schema.SObjectType.ResourceAbsence.getRecordTypeInfosByDeveloperName().get('Non_Availability').getRecordTypeId();
    public static final Id DAILY_CAPACITY_TEMPLATE = Schema.SObjectType.Capacity_Rule_Template__c.getRecordTypeInfosByDeveloperName().get('Daily_Capacity_Template').getRecordTypeId();
    public static final Id RULE_BASED_CAPACITY_TEMPLATE = Schema.SObjectType.Capacity_Rule_Template__c.getRecordTypeInfosByDeveloperName().get('Rule_Template').getRecordTypeId();
    public static final Id DAILY_CONSUMED_CAPACITY = Schema.SObjectType.Consumed_Capacity__c.getRecordTypeInfosByDeveloperName().get('Daily_Capacity').getRecordTypeId();
    public static final Id RULE_BASED_CONSUMED_CAPACITY = Schema.SObjectType.Consumed_Capacity__c.getRecordTypeInfosByDeveloperName().get('Rule_Based_Capacity').getRecordTypeId();
    
    //MetaData Name Keys
    public static final String AssignedResourceLockStatus='AssignedResourceLockStatus';
    public static final String JeopardyStatus ='JeopardyStatus';
    
    //Capacity Slots Keys
    public static final String Slot8To12='8:00AM - 12:00PM';
    public static final String Slot12To16='12:00PM - 4:00PM';
    public static final String Slot16To2030='4:00PM - 8:30PM';
    public static final String Slot2030To2230='8:30PM - 10:30PM';
    public static final string Daily_Capacity='Daily Capacity';
	public static final string Rule_Based_Capacity='Rule Based Capacity';

    //Resource capacity assigned capacity slot fields
    public static final string Slot0812AssignedMinutes='Slot_08_12_Assigned_Minutes__c';
    public static final string Slot1216AssignedMinutes='Slot_12_16_Assigned_Minutes__c';
    public static final string Slot162030AssignedMinutes='Slot_16_2030_Assigned_Minutes__c';
    public static final string Slot20302230AssignedMinutes='Slot_2030_2230_Assigned_Minutes__c';
    
    //Resource capacity available capacity slot fields
    public static final string Slot0812AvailMinutes='Slot_08_12_Avail_Minutes__c';
    public static final string Slot1216AvailMinutes='Slot_12_16_Avail_Minutes__c';
    public static final string Slot162030AvailMinutes='Slot_16_2030_Avail_Minutes__c';
    public static final string Slot20302230AvailMinutes='Slot_2030_2230_Avail_Minutes__c';
    //
    public static final Map<String,String> SASTATUSCOLORS = new Map<String, String>{
        'Scheduled' => '#80FF80', //Light Green
        'Pre-Dispatched' =>'#068C2F', //Green
        'Dispatched' =>'#74D9CF',  //Aqua
        'Travel' => '#8080FF', //Violet
        'On-Site' =>'#FFFF80', //Light Yellow
        'Completed'=>'#0080FF', //Blue
        'Confirmed'=> '#EB9147', //Orange
        'Multi Day'=> '#74D9CF'//Aqua
    };
        
    public static final String captureSignaturestrElement='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';
    public static final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    global class Slots_Response {
        global DateTime startTimeInterval;
        global DateTime endTimeInterval;
        global String timeZone;
        global String technicianId;
        global String techKey;
        global String resourceId;
        global String errorMessage;
    }

   
}