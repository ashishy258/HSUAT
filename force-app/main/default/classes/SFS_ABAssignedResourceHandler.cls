/**
* @description       :
* @author            : Salesforce Services
* @group             :
* @last modified on  : 04-20-2021
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* Modifications Log
* Ver   Date         Author                               Modification
* 1.0   11-02-2020   Salesforce Services                  Initial Version
* 2.0   20-02-2023   Vandana Verma                        Initial Version
* 3.0   03-03-2023   Divya Dalmia                         Initial Version
**/
public class SFS_ABAssignedResourceHandler implements rflib_TriggerHandler {
    public void run(rflib_TriggerManager.Args triggerArguments) {
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_INSERT) {
            // checkForResourceInsert(triggerArguments);
            System.debug('After Insert');
            updateSAFields(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_UPDATE) {
            // publishServiceAppointmentResourceChangeEvent(triggerArguments);
            System.debug('After Update');
            updateSAFields(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.BEFORE_UPDATE) {
            // checkForResourceUpdate(triggerArguments);
            checkSAStatus(triggerArguments);
        }
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.BEFORE_DELETE) {
            // checkForResourceDelete(triggerArguments);
        }
        
        if (triggerArguments.operation.name() == SFS_ABConstantUtil.AFTER_DELETE) {
            System.debug('After Delete');
            updateSAFields(triggerArguments);
        }
    }
    
    /* public static void checkForResourceInsert(rflib_TriggerManager.Args triggerArguments) {
System.debug('checkForResourceInsert');

List<Assigned_Resource_Change__e> eventList = new List<Assigned_Resource_Change__e>();
Set<Id> serviceAppointmentIds = new Set<Id>();
Set<Id> serviceResourceIds = new Set<Id>();
Map<Id, Set<Id>> serviceResourceIdToServiceAppointmentIdsMap = new Map<Id, Set<Id>>();

try {
for (AssignedResource newResource : (List<AssignedResource>) triggerArguments.newRecords) {
if (serviceResourceIds.contains(newResource.ServiceResourceId)) {
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
Set<Id> mapServiceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(newResource.ServiceResourceId);
mapServiceAppointmentIds.add(newResource.ServiceAppointmentId);
} else {
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIds.add(newResource.ServiceResourceId);
Set<Id> mapServiceAppointmentIds = new Set<Id>();
mapServiceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIdToServiceAppointmentIdsMap.put(newResource.ServiceResourceId, mapServiceAppointmentIds);
}
}
Map<Id, ServiceAppointment> serviceAppointmentMap = new Map<Id, ServiceAppointment>([SELECT Id, ParentRecordId, AccountId FROM ServiceAppointment WHERE Id IN :serviceAppointmentIds]);

List<ServiceResource> serviceResources = [SELECT Id FROM ServiceResource WHERE Id IN :serviceResourceIds];

for (Id serviceAppointmentId : serviceAppointmentIds) {
ServiceAppointment serviceAppointment = serviceAppointmentMap.get(serviceAppointmentId);
}
for (ServiceResource serviceResource : serviceResources) {
Set<Id> mapServiceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(serviceResource.Id);

for (Id serviceAppointmentId : mapServiceAppointmentIds) {
Assigned_Resource_Change__e newEvent = new Assigned_Resource_Change__e();
ServiceAppointment serviceAppointment = serviceAppointmentMap.get(serviceAppointmentId);
newEvent.Service_Appointment_Id__c = serviceAppointment.Id;
newEvent.Work_Order_Id__c = serviceAppointment.ParentRecordId;

eventList.add(newEvent);
}
}

List<Database.SaveResult> results = EventBus.publish(eventList);
} catch (Exception caughtException) {
System.debug(SFS_ABConstantUtil.EXCEPTION_MESSAGE + caughtException);
}
}*/
    
    /* public static void shareAppointmentOnResourceInsert(rflib_TriggerManager.Args triggerArguments) {
System.debug('inside shareAppointmentOnResourceInsert');
List<Assigned_Resource_Insert__e> eventList = new List<Assigned_Resource_Insert__e>();
Set<Id> serviceResourceIds = new Set<Id>();
Map<Id, Set<Id>> serviceResourceIdToServiceAppointmentIdsMap = new Map<Id, Set<Id>>();

try {
for (AssignedResource newResource : (List<AssignedResource>) triggerArguments.newRecords) {
if (serviceResourceIds.contains(newResource.ServiceResourceId)) {
Set<Id> serviceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(newResource.ServiceResourceId);
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
} else {
serviceResourceIds.add(newResource.ServiceResourceId);
Set<Id> serviceAppointmentIds = new Set<Id>();
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIdToServiceAppointmentIdsMap.put(newResource.ServiceResourceId, serviceAppointmentIds);
}
}

List<ServiceResource> serviceResources = [SELECT Id FROM ServiceResource WHERE Id IN :serviceResourceIds];

for (ServiceResource serviceResource : serviceResources) {
Set<Id> serviceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(serviceResource.Id);
for (Id serviceAppointmentId : serviceAppointmentIds) {
Assigned_Resource_Insert__e newEvent = new Assigned_Resource_Insert__e();
newEvent.Service_Appointment_Id__c = serviceAppointmentId;
//newEvent.Organization_Id__c = serviceResource.Organization__c;

eventList.add(newEvent);
}
}
List<Database.SaveResult> results = EventBus.publish(eventList);
} catch (Exception caughtException) {
System.debug(SFS_ABConstantUtil.EXCEPTION_MESSAGE + caughtException);
}
}*/
    
    /* public static void checkForResourceUpdate(rflib_TriggerManager.Args triggerArguments) {
List<Assigned_Resource_Change__e> eventList = new List<Assigned_Resource_Change__e>();
Set<Id> serviceAppointmentIds = new Set<Id>();
Set<Id> serviceResourceIds = new Set<Id>();
Map<Id, Set<Id>> serviceResourceIdToServiceAppointmentIdsMap = new Map<Id, Set<Id>>();

try {
for (AssignedResource newResource : (List<AssignedResource>) triggerArguments.newRecords) {
AssignedResource oldResource = (AssignedResource) triggerArguments.oldRecordsMap.get(newResource.Id);
if (newResource.ServiceResourceId != oldResource.ServiceResourceId) {
if (serviceResourceIds.contains(newResource.ServiceResourceId)) {
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
Set<Id> mapServiceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(newResource.ServiceResourceId);
mapServiceAppointmentIds.add(newResource.ServiceAppointmentId);
} else {
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIds.add(newResource.ServiceResourceId);
Set<Id> mapServiceAppointmentIds = new Set<Id>();
mapServiceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIdToServiceAppointmentIdsMap.put(newResource.ServiceResourceId, mapServiceAppointmentIds);
}
}
}

Map<Id, ServiceAppointment> serviceAppointmentMap = new Map<Id, ServiceAppointment>([SELECT Id, ParentRecordId, AccountId FROM ServiceAppointment WHERE Id IN :serviceAppointmentIds]);
List<ServiceResource> serviceResources = [SELECT Id FROM ServiceResource WHERE Id IN :serviceResourceIds];

for (Id serviceAppointmentId : serviceAppointmentIds) {
ServiceAppointment serviceAppointment = serviceAppointmentMap.get(serviceAppointmentId);
}
for (ServiceResource serviceResource : serviceResources) {
Set<Id> mapServiceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(serviceResource.Id);
for (Id serviceAppointmentId : mapServiceAppointmentIds) {
Assigned_Resource_Change__e newEvent = new Assigned_Resource_Change__e();
ServiceAppointment serviceAppointment = serviceAppointmentMap.get(serviceAppointmentId);
newEvent.Service_Appointment_Id__c = serviceAppointment.Id;
newEvent.Work_Order_Id__c = serviceAppointment.ParentRecordId;
//newEvent.Organization_Id__c = serviceResource.Organization__c;

eventList.add(newEvent);
}
}
if (!eventList.isEmpty()) {
List<Database.SaveResult> results = EventBus.publish(eventList);
}
} catch (Exception caughtException) {
System.debug(SFS_ABConstantUtil.EXCEPTION_MESSAGE + caughtException);
}
}*/
    
    /*   public static void shareAppointmentOnResourceUpdate(rflib_TriggerManager.Args triggerArguments) {
List<Assigned_Resource_Update__e> eventList = new List<Assigned_Resource_Update__e>();
Set<Id> newServiceResourceIds = new Set<Id>();
Set<Id> oldServiceResourceIds = new Set<Id>();
Map<Id, Id> newResourceIdToOldResourceIdMap = new Map<Id, Id>();
Map<Id, Set<Id>> serviceResourceIdToServiceAppointmentIdsMap = new Map<Id, Set<Id>>();

try {
for (AssignedResource newResource : (List<AssignedResource>) triggerArguments.newRecords) {
AssignedResource oldResource = (AssignedResource) triggerArguments.oldRecordsMap.get(newResource.Id);
if (newResource.ServiceResourceId != oldResource.ServiceResourceId) {
if (newServiceResourceIds.contains(newResource.ServiceResourceId)) {
Set<Id> serviceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(newResource.ServiceResourceId);
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
} else {
newServiceResourceIds.add(newResource.ServiceResourceId);
oldServiceResourceIds.add(oldResource.ServiceResourceId);
newResourceIdToOldResourceIdMap.put(newResource.ServiceResourceId, oldResource.ServiceResourceId);
Set<Id> serviceAppointmentIds = new Set<Id>();
serviceAppointmentIds.add(newResource.ServiceAppointmentId);
serviceResourceIdToServiceAppointmentIdsMap.put(newResource.ServiceResourceId, serviceAppointmentIds);
}
}
}

List<ServiceResource> newServiceResources = [SELECT Id FROM ServiceResource WHERE Id IN :newServiceResourceIds];
Map<Id, ServiceResource> oldServiceResourceMap = new Map<Id, ServiceResource>([SELECT Id FROM ServiceResource WHERE Id IN :oldServiceResourceIds]);

for (ServiceResource newServiceResource : newServiceResources) {
serviceResource oldServiceResource = oldServiceResourceMap.get(newResourceIdToOldResourceIdMap.get(newServiceResource.Id));
Set<Id> serviceAppointmentIds = serviceResourceIdToServiceAppointmentIdsMap.get(newServiceResource.Id);
for (Id serviceAppointmentId : serviceAppointmentIds) {
Assigned_Resource_Update__e newEvent = new Assigned_Resource_Update__e();
newEvent.Service_Appointment_Id__c = serviceAppointmentId;
eventList.add(newEvent);
}
}
if (!eventList.isEmpty()) {
List<Database.SaveResult> results = EventBus.publish(eventList);
}
} catch (Exception caughtException) {
System.debug(SFS_ABConstantUtil.EXCEPTION_MESSAGE + caughtException);
}
}*/
    
    /* public static void checkForResourceDelete(rflib_TriggerManager.Args triggerArguments) {
System.debug('checkForResourceDelete>>');
List<Assigned_Resource_Change__e> eventList = new List<Assigned_Resource_Change__e>();
Set<Id> serviceAppointmentIds = new Set<Id>();
Set<Id> serviceTerritoryIds = new Set<Id>();

try {
for (AssignedResource oldResource : (List<AssignedResource>) triggerArguments.oldRecords) {
serviceAppointmentIds.add(oldResource.ServiceAppointmentId);
}

List<ServiceAppointment> serviceAppointments = [
SELECT Id, ServiceTerritoryId, ParentRecordId, AccountId, ArrivalWindowStartTime
FROM ServiceAppointment
WHERE Id IN :serviceAppointmentIds
];

for (ServiceAppointment serviceAppointment : serviceAppointments) {
serviceTerritoryIds.add(serviceAppointment.ServiceTerritoryId);
}

for (ServiceAppointment serviceAppointment : serviceAppointments) {
//If the AR was deleted when the Arrival Window Start Time is today, don't fire the event
if (serviceAppointment.ArrivalWindowStartTime == null || serviceAppointment.ArrivalWindowStartTime.dateGMT() != System.DateTime.now().dateGMT()) {
Assigned_Resource_Change__e newEvent = new Assigned_Resource_Change__e();
newEvent.Service_Appointment_Id__c = serviceAppointment.Id;
newEvent.Work_Order_Id__c = serviceAppointment.ParentRecordId;

eventList.add(newEvent);
}
}
System.debug('checkForResourceDelete:: Published PE>>' + eventList);
List<Database.SaveResult> results = EventBus.publish(eventList);
} catch (Exception caughtException) {
System.debug(SFS_ABConstantUtil.EXCEPTION_MESSAGE + caughtException);
}
}*/
    
    /* public static void publishServiceAppointmentResourceChangeEvent(rflib_TriggerManager.Args triggerArguments) {
Boolean hasInboundIntegrationCustomPermission = FeatureManagement.checkPermission(SFS_ABConstantUtil.INBOUND_INTEGRATION_CUSTOM_PERMISSION);

system.debug('Integration Permission>>' + hasInboundIntegrationCustomPermission);

Boolean fslScheduleSwitch = false;
string FSL_SCHEDULE_SWITCH_CONFIG_NAME = 'FSL_Schedule_Switch';
SFS_AB_Capacity_Settings__mdt appConfig = [
SELECT Id, Configuration_Name__c, Configuration_Value__c, Enable_Flag__c
FROM SFS_AB_Capacity_Settings__mdt
WHERE Configuration_Name__c = :FSL_SCHEDULE_SWITCH_CONFIG_NAME
];
if (appConfig != null && appConfig.Enable_Flag__c) {
fslScheduleSwitch = true;
}
if (!hasInboundIntegrationCustomPermission) {
try {
System.debug('inside publishServiceAppointmentResourceChangeEvent');
Set<Id> serviceResourceSet = new Set<Id>();
Set<Id> serviceAppointmentSet = new Set<Id>();
Set<Id> workOrderSet = new Set<Id>();
Set<Id> oldServiceResourceSet = new Set<Id>();
Map<Id, WorkOrder> workOrderMap = new Map<Id, WorkOrder>();
Map<Id, ServiceResource> serviceResourceMap = new Map<Id, ServiceResource>();
Map<Id, ServiceResource> oldServiceResourceMap = new Map<Id, ServiceResource>();
Map<Id, ServiceAppointment> serviceAppointmentMap = new Map<Id, ServiceAppointment>();

for (AssignedResource assignedResource : (List<AssignedResource>) triggerArguments.newRecords) {
serviceResourceSet.add(assignedResource.ServiceResourceId);
serviceAppointmentSet.add(assignedResource.ServiceAppointmentId);
}

for (AssignedResource assignedResource : (List<AssignedResource>) triggerArguments.oldRecords) {
oldServiceResourceSet.add(assignedResource.ServiceResourceId);
}

serviceAppointmentMap = new Map<Id, ServiceAppointment>(
[
SELECT
Id,
Status,
ActualDuration,
ActualEndTime,
ActualStartTime,
ArrivalWindowEndTime,
ArrivalWindowStartTime,
DueDate,
SchedEndTime,
SchedStartTime,
DurationInMinutes,
FSL__InJeopardy__c,
FSL__InJeopardyReason__c,
FSL__Pinned__c,
ServiceTerritoryId,
AccountId,
Account.Name,
Latitude,
Longitude,
ParentRecordId,
LastModifiedBy.Name,
ServiceTerritory.OperatingHours.TimeZone,
ServiceTerritory.Name
FROM ServiceAppointment
WHERE Id IN :serviceAppointmentSet
]
);

serviceResourceMap = new Map<Id, ServiceResource>([SELECT Name, LocationId, Location.Name FROM ServiceResource WHERE Id IN :serviceResourceSet]);
oldServiceResourceMap = new Map<Id, ServiceResource>([SELECT Name, LocationId, Location.Name FROM ServiceResource WHERE Id IN :oldServiceResourceSet]);

for (ServiceAppointment appointment : serviceAppointmentMap.values()) {
workOrderSet.add(appointment.ParentRecordId);
}
workOrderMap = new Map<Id, WorkOrder>([SELECT Id, Status, WorkOrderNumber FROM WorkOrder WHERE Id IN :workOrderSet]);
List<Service_Appointment_Change__e> serviceAppointmentChangeList = new List<Service_Appointment_Change__e>();
for (AssignedResource assignedResource : (List<AssignedResource>) triggerArguments.newRecords) {
AssignedResource oldAssignedResourceRecord = (AssignedResource) triggerArguments.oldRecordsMap.get(assignedResource.Id);
if (oldAssignedResourceRecord.ServiceResourceId != assignedResource.ServiceResourceId) {
Service_Appointment_Change__e serviceAppointmentChange = new Service_Appointment_Change__e();
serviceAppointmentChange.Previous_Status__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Status;
serviceAppointmentChange.New_Status__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Status;
serviceAppointmentChange.Actual_Duration_Mins__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualDuration;
serviceAppointmentChange.Duration_In_Minutes__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).DurationInMinutes;
serviceAppointmentChange.Service_Territory_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ServiceTerritoryId;
serviceAppointmentChange.Prev_Service_Territory_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ServiceTerritoryId;
serviceAppointmentChange.Parent_Record_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId;
//serviceAppointmentChange.Organization_ID__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Organization__c;
serviceAppointmentChange.Service_Appointment_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Id;
serviceAppointmentChange.Travel_Time_Mins__c = assignedResource.EstimatedTravelTime;

//Getting Time Zone associated with the job and using that to convert dates to that Time Zone.
String timeZoneAssociatedToAppointment = serviceAppointmentMap.get(serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Id)
.ServiceTerritory.OperatingHours.TimeZone;
if (timeZoneAssociatedToAppointment != null) {
serviceAppointmentChange.Actual_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualEndTime
);
serviceAppointmentChange.Actual_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualStartTime
);
serviceAppointmentChange.Arrival_Window_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ArrivalWindowEndTime
);
serviceAppointmentChange.Arrival_Window_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ArrivalWindowStartTime
);
serviceAppointmentChange.Due_Date__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).DueDate
);
serviceAppointmentChange.Scheduled_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedEndTime
);
serviceAppointmentChange.Scheduled_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedStartTime
);
serviceAppointmentChange.Prev_Scheduled_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedStartTime
);
}

//Accessing WorkOrder Object Map.
if (workOrderMap.containsKey(serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId)) {
serviceAppointmentChange.Work_Order_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId;
}

//Accessing Service Resource Object Map.
if (serviceResourceMap.containsKey(assignedResource.ServiceResourceId)) {
ServiceResource resource = serviceResourceMap.get(assignedResource.ServiceResourceId);
ServiceResource oldResource = oldServiceResourceMap.get(oldAssignedResourceRecord.ServiceResourceId);
serviceAppointmentChange.Previous_Assigned_Id__c = oldResource.Id;
//if (!hasInboundIntegrationCustomPermission && SFS_ABScheduleAsyncCall.asyncScheduleStatusChange == true) {
serviceAppointmentChange.Organization_ID__c = resource.Organization__c;
//}
}
serviceAppointmentChangeList.add(serviceAppointmentChange);
}
}
if (!serviceAppointmentChangeList.isEmpty() && serviceAppointmentChangeList.size() > 0) {
List<Database.SaveResult> results = EventBus.publish(serviceAppointmentChangeList);
System.debug('Event Published Resource Assignment Change PE for update.');
}
} catch (Exception e) {
System.debug('Exception: ' + e);
}
}
}

public static void publishServiceAppointmentResourceChangeEventOnInsert(rflib_TriggerManager.Args triggerArguments) {
Boolean hasInboundIntegrationCustomPermission = FeatureManagement.checkPermission(SFS_ABConstantUtil.INBOUND_INTEGRATION_CUSTOM_PERMISSION);
if (!hasInboundIntegrationCustomPermission) {
try {
Set<Id> serviceResourceSet = new Set<Id>();
Set<Id> serviceAppointmentSet = new Set<Id>();
Set<Id> workOrderSet = new Set<Id>();
Set<Id> oldServiceResourceSet = new Set<Id>();
Map<Id, WorkOrder> workOrderMap = new Map<Id, WorkOrder>();
Map<Id, ServiceResource> serviceResourceMap = new Map<Id, ServiceResource>();
Map<Id, ServiceAppointment> serviceAppointmentMap = new Map<Id, ServiceAppointment>();

for (AssignedResource assignedResource : (List<AssignedResource>) triggerArguments.newRecords) {
serviceResourceSet.add(assignedResource.ServiceResourceId);
serviceAppointmentSet.add(assignedResource.ServiceAppointmentId);
}

serviceAppointmentMap = new Map<Id, ServiceAppointment>(
[
SELECT
Id,
Status,
ActualDuration,
ActualEndTime,
ActualStartTime,
ArrivalWindowEndTime,
ArrivalWindowStartTime,
DueDate,
SchedEndTime,
SchedStartTime,
DurationInMinutes,
FSL__InJeopardy__c,
FSL__InJeopardyReason__c,
FSL__Pinned__c,
ServiceTerritoryId,
AccountId,
Account.Name,
Latitude,
Longitude,
ParentRecordId,
LastModifiedBy.Name,
ServiceTerritory.OperatingHours.TimeZone,
ServiceTerritory.Name
FROM ServiceAppointment
WHERE Id IN :serviceAppointmentSet
]
);

serviceResourceMap = new Map<Id, ServiceResource>([SELECT Name, LocationId, Location.Name FROM ServiceResource WHERE Id IN :serviceResourceSet]);

for (ServiceAppointment appointment : serviceAppointmentMap.values()) {
workOrderSet.add(appointment.ParentRecordId);
}
workOrderMap = new Map<Id, WorkOrder>([SELECT Id, Status, WorkOrderNumber FROM WorkOrder WHERE Id IN :workOrderSet]);
List<Service_Appointment_Change__e> serviceAppointmentChangeList = new List<Service_Appointment_Change__e>();
for (AssignedResource assignedResource : (List<AssignedResource>) triggerArguments.newRecords) {
AssignedResource oldAssignedResourceRecord = (AssignedResource) triggerArguments.oldRecordsMap.get(assignedResource.Id);
Service_Appointment_Change__e serviceAppointmentChange = new Service_Appointment_Change__e();
//Accessing direct appointment values given to us in trigger context.
serviceAppointmentChange.Previous_Status__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Status;
serviceAppointmentChange.New_Status__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Status;
serviceAppointmentChange.Actual_Duration_Mins__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualDuration;
serviceAppointmentChange.Duration_In_Minutes__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).DurationInMinutes;
serviceAppointmentChange.Service_Territory_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ServiceTerritoryId;
serviceAppointmentChange.Prev_Service_Territory_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ServiceTerritoryId;
serviceAppointmentChange.Parent_Record_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId;
serviceAppointmentChange.Service_Appointment_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Id;
serviceAppointmentChange.Travel_Time_Mins__c = assignedResource.EstimatedTravelTime;

//Getting Time Zone associated with the job and using that to convert dates to that Time Zone.
String timeZoneAssociatedToAppointment = serviceAppointmentMap.get(serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).Id).ServiceTerritory.OperatingHours.TimeZone;
if (timeZoneAssociatedToAppointment != null) {
serviceAppointmentChange.Actual_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualEndTime
);
serviceAppointmentChange.Actual_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ActualStartTime
);
serviceAppointmentChange.Arrival_Window_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ArrivalWindowEndTime
);
serviceAppointmentChange.Arrival_Window_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ArrivalWindowStartTime
);
serviceAppointmentChange.Due_Date__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).DueDate
);
serviceAppointmentChange.Scheduled_End__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedEndTime
);
serviceAppointmentChange.Scheduled_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedStartTime
);
serviceAppointmentChange.Prev_Scheduled_Start__c = formatDatesToAppointmentTimeZone(
timeZoneAssociatedToAppointment,
serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).SchedStartTime
);
}

//Accessing WorkOrder Object Map.
if (workOrderMap.containsKey(serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId)) {
serviceAppointmentChange.Work_Order_Id__c = serviceAppointmentMap.get(assignedResource.ServiceAppointmentId).ParentRecordId;
}

//Accessing Service Resource Object Map.
if (serviceResourceMap.containsKey(assignedResource.ServiceResourceId)) {
ServiceResource resource = serviceResourceMap.get(assignedResource.ServiceResourceId);
serviceAppointmentChange.Previous_Assigned_Id__c = resource.Id;
}
serviceAppointmentChangeList.add(serviceAppointmentChange);
}
if (!serviceAppointmentChangeList.isEmpty() && serviceAppointmentChangeList.size() > 0) {
List<Database.SaveResult> results = EventBus.publish(serviceAppointmentChangeList);
System.debug('Published Resource Assignment Change PE for update.');
}
} catch (Exception e) {
System.debug('Exception: ' + e);
}
}
}

public static String formatDatesToAppointmentTimeZone(String timeZone, DateTime dateTimeToConvert) {
if (dateTimeToConvert != null) {
String convertedDateTime = dateTimeToConvert.format('yyyy-MM-dd\'T\'HH:mm:ss', timeZone);
return convertedDateTime;
}
return null;
}*/
    
    public void onConsecutiveRun(rflib_TriggerManager.Args triggerArguments, Integer numInvocation) {}
    
    //This method is to check the SA status to lock the assigned resource change for the specific SA status
    public static void checkSAStatus(rflib_TriggerManager.Args triggerArguments)
    {
        System.debug('checkSAStatus method called');
        String sastatusValue = SFS_HS_GlobalSettings__mdt.getInstance(SFS_ABConstantUtil.AssignedResourceLockStatus).Values__c;
        system.debug('sastatusValue if '+sastatusValue);
        if(sastatusValue!=null)
        {
            List<String> saStatusToCheck=sastatusValue.trim().split(',');
            List<AssignedResource> arList=new List<AssignedResource>();
            arList=(List<AssignedResource>)triggerArguments.newRecords;
            Set<Id> servApptIdsNeeded = new Set<Id>();
            for (AssignedResource ar : arList) {
                AssignedResource oldResource = (AssignedResource) triggerArguments.oldRecordsMap.get(ar.Id);
                //check if Assigned Resource has changed
                if (ar.ServiceResourceId != oldResource.ServiceResourceId){
                    servApptIdsNeeded.add(ar.ServiceAppointmentId);
                }
            }
            
            Map<Id, ServiceAppointment> servAppts = new Map<Id, ServiceAppointment>([
                SELECT Id, Status, AppointmentNumber
                FROM ServiceAppointment
                WHERE Id IN :servApptIdsNeeded
            ]);
            
            for (AssignedResource ar : arList) {
                if (servAppts.containsKey(ar.ServiceAppointmentId)) {
                    string strSAStatus = servAppts.get(ar.ServiceAppointmentId).status;
                    string strSANumber = servAppts.get(ar.ServiceAppointmentId).AppointmentNumber;
                    if (saStatusToCheck.contains(strSAStatus.toLowerCase())){
                        ar.addError('Assigned Resource cannot be changed on Service Appointment '+strSANumber+' in status ' +strSAStatus+'.');
                    }                      
                }
            }
        }
    }
    
    public static void updateSAFields(rflib_TriggerManager.Args triggerArguments) {
        System.debug('triggerArguments: ' + triggerArguments);
        List<AssignedResource> arList = new List<AssignedResource>();

        if(Trigger.isDelete){
            arList = (List<AssignedResource>)triggerArguments.oldRecords;
        }else{
            arList = (List<AssignedResource>)triggerArguments.newRecords;
        }
        
        Set<Id> servApptIdsNeeded = new Set<Id>();
        Set<Id> saIDsToUpdate = new Set<Id>();
        
        for (AssignedResource ar : arList) {
            servApptIdsNeeded.add(ar.ServiceAppointmentId);
        }
        
        Map<Id, ServiceAppointment> servAppts = new Map<Id, ServiceAppointment>([
            SELECT Id, Status, FSL__Schedule_Mode__c, Assigned_Resource__c
            FROM ServiceAppointment
            WHERE Id IN :servApptIdsNeeded
        ]);
        
        for (AssignedResource ar : arList) {
            System.debug('Looking at Assigned Resource: ' + ar.Id);
            System.debug('Service Appointment: ' + ar.ServiceAppointmentId);
            System.debug('Service Resource: ' + ar.ServiceResourceId);
            if (servAppts.containsKey(ar.ServiceAppointmentId)) {
                if (Trigger.isAfter && Trigger.isDelete) {
                    if (servAppts.get(ar.ServiceAppointmentId).Assigned_Resource__c == ar.ServiceResourceId) {
                        System.debug('Clearing Assigned_Resource__c on AssignedResource delete');
                        servAppts.get(ar.ServiceAppointmentId).Assigned_Resource__c = null;
                        saIDsToUpdate.add(ar.ServiceAppointmentId);
                    }
                }
                else if (Trigger.isAfter && (Trigger.isInsert || Trigger.isUpdate)){
                    if (servAppts.get(ar.ServiceAppointmentId).Assigned_Resource__c != ar.ServiceResourceId){
                        System.debug('Setting Assigned_Resource__c on AssignedResource insert or update');
                        servAppts.get(ar.ServiceAppointmentId).Assigned_Resource__c = ar.ServiceResourceId;
                        saIDsToUpdate.add(ar.ServiceAppointmentId);
                    }
                }
            }
        }
        System.debug('Have this many SAs to update: ' + saIDsToUpdate.size());
        if (!saIDsToUpdate.isEmpty()){
            List<ServiceAppointment> sasToUpdate = new List<ServiceAppointment>();
            for (Id thisSAId : saIDsToUpdate){
                sasToUpdate.add(servAppts.get(thisSAId));
            }
            update sasToUpdate;
        }
    }
    
    
}