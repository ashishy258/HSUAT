/**
 * @description       : To create 60 days resource capacity records based on STM and filters
 * @author            : Salesforce Services
 * @group             :
 * @last modified on  : 05-19-2021
 * Modifications Log
 * Ver   Date         Author                    Modification
 * 1.0   04-22-2021   Salesforce Services       Initial Version
 **/
global class SFS_ABCapacityRebuildJobBatch implements Database.Batchable<sObject>, Database.Stateful {
    // Vars
    Map<Id, rebuildDate> stmIdToRebuildDateMap = new Map<Id, rebuildDate>();
    Map<Id, rebuildDate> relocationSTMidToRebuildDateMap = new Map<Id, rebuildDate>();
    Map<Id, rebuildDate> territoryIdToRebuildMap = new Map<Id, rebuildDate>();
    Map<Id, Capacity_Rebuild_Job__c> serviceResourceIdToCapJobMap = new Map<Id, Capacity_Rebuild_Job__c>();
    Map<Id, Capacity_Rebuild_Job__c> serviceTerritoryIdToCapJobMap = new Map<Id, Capacity_Rebuild_Job__c>();
    Map<String, Capacity_Rebuild_Job__c> srsTIdToCapJobMap = new Map<String, Capacity_Rebuild_Job__c>();
    Set<String> timezonesToRebuildSet = new Set<String>();
    Set<Id> orgIdSet = new Set<Id>();
    public String batchName;
    public Boolean territorySizeFlagforCC = false;

    public SFS_ABCapacityRebuildJobBatch(String batchInputName) {
        batchName = batchInputName;
        System.debug('batchName--- ' + batchName);
    }

    // Constants
    final String relocationString = 'R';
    final string DAYS_TO_BUILD_CAPACITY = 'Days_to_Build_Capacity_Data';
    final string CAP_REBUILD_SERVICE_APPOINTMENT_INSERT = 'Service Appointment Insert';
    final string CAP_REBUILD_SERVICE_APPOINTMENT_DELETE = 'Service Appointment Delete';
    final string CAP_REBUILD_SERVICE_APPOINTMENT_UPDATE_NO_AR = 'Service Appointment Update No AR';
    final string CAP_REBUILD_CAPACITY_TEMPLATE_DELETE = 'Capacity Template Delete';
    final string CAP_REBUILD_CAPCITY_TEMPLATE_INSERT = 'Capacity Template Insert';
    final string CAP_REBUILD_CAPCITY_TEMPLATE_UPDATE = 'Capacity Template Update';
    final string CAP_REBUILD_SERVICE_TERRITORY_UPDATE = 'Service Territory Update';

    // Initial Query to get the Capacity Rebuild Jobs
    global Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT ID, End_Date__c,Start_Date__c,Service_Territory__c,Type__c,Service_Resource__c,Service_Territory__r.OperatingHours.TimeZone FROM Capacity_Rebuild_Job__c';
        return Database.getQueryLocator(query);
    }

    // Execute to process the Cap Rebuild Jobs and Start the next batch
    global void execute(Database.BatchableContext BC, List<Capacity_Rebuild_Job__c> jobList) {
        try {
            // Vars
            List<Capacity_Rebuild_Job__c> deleteJobList = new List<Capacity_Rebuild_Job__c>();

            List<SFS_AB_Capacity_Batch_Configuration__mdt> capacityJobTimezones = [
                SELECT Id, Batch_Job_Name__c, Batch_Job_Timezones__c, Territory_Flag__c
                FROM SFS_AB_Capacity_Batch_Configuration__mdt
            ];

            System.debug('56>>'+capacityJobTimezones.size());

            for (SFS_AB_Capacity_Batch_Configuration__mdt batchConfig : capacityJobTimezones) {
                System.debug('batch job config name to match --> ' + batchConfig.Batch_Job_Name__c.subString(0, 6));
                if (batchConfig.Batch_Job_Name__c.subString(0, 6) == batchName) {
                    timezonesToRebuildSet.add(batchConfig.Batch_Job_Timezones__c);
                    territorySizeFlagforCC = batchConfig.Territory_Flag__c;
                }
            }
            System.debug('timezonesToRebuildSet --> ' + timezonesToRebuildSet);

            // Get the Days to Create
            SFS_AB_Capacity_Settings__mdt appConfig = [
                SELECT Id, Configuration_Name__c, Configuration_Value__c
                FROM SFS_AB_Capacity_Settings__mdt
                WHERE Configuration_Name__c = :DAYS_TO_BUILD_CAPACITY
            ];
            Integer daysToBuild = Integer.valueOf(appConfig.Configuration_Value__c);
            Date defaultLastDate = System.Today().addDays(daysToBuild);
            Map<Id, List<Capacity_Rebuild_Job__c>> srJobListMap = new Map<Id, List<Capacity_Rebuild_Job__c>>();
            List<Capacity_Rebuild_Job__c> srJobList;
            Set<Id> srIdSet = new Set<Id>();

            // Loop through the jobs and build a map of either SRs or STs
            for (Capacity_Rebuild_Job__c job : jobList) {
                if (job.Service_Territory__c != null) {
                    if (timezonesToRebuildSet.contains(job.Service_Territory__r.OperatingHours.TimeZone)) {
                        deleteJobList.add(job);
                    } else {
                        continue;
                    }
                }

                if (job.Service_Territory__c == null && job.Service_Resource__c != null) {
                    System.debug('job.Service_Resource__c ----> ' + job.Service_Resource__c);
                    if (srJobListMap.get(job.Service_Resource__c) != null) {
                        srJobList = srJobListMap.get(job.Service_Resource__c);
                        srJobList.add(job);
                        srJobListMap.put(job.Service_Resource__c, srJobList);
                    } else {
                        srJobList = new List<Capacity_Rebuild_Job__c>();
                        srJobList.add(job);
                        srJobListMap.put(job.Service_Resource__c, srJobList);
                    }
                }

                // Default the days to start
                if (job.Start_Date__c == null) {
                    job.Start_Date__c = System.Today();
                }
                if (job.End_Date__c == null) {
                    job.End_Date__c = defaultLastDate;
                }

                if (job.Service_Resource__c != null) {
                    if (serviceResourceIdToCapJobMap.get(job.Service_Resource__c) != null) {
                        Capacity_Rebuild_Job__c existJob = serviceResourceIdToCapJobMap.get(job.Service_Resource__c);
                        if (job.Start_Date__c > existjob.Start_Date__c) {
                            job.Start_Date__c = existjob.Start_Date__c;
                        }
                        if (job.End_Date__c < existjob.End_Date__c) {
                            job.End_Date__c = existjob.End_Date__c;
                        }
                    }
                    serviceResourceIdToCapJobMap.put(job.Service_Resource__c, job);
                }
                if (job.Service_Territory__c != null) {
                    if (serviceTerritoryIdToCapJobMap.get(job.Service_Territory__c) != null) {
                        Capacity_Rebuild_Job__c existJob = serviceTerritoryIdToCapJobMap.get(job.Service_Territory__c);
                        if (job.Start_Date__c > existjob.Start_Date__c) {
                            job.Start_Date__c = existjob.Start_Date__c;
                        }
                        if (job.End_Date__c < existjob.End_Date__c) {
                            job.End_Date__c = existjob.End_Date__c;
                        }
                    }
                    serviceTerritoryIdToCapJobMap.put(job.Service_Territory__c, job);
                }
                if (job.Service_Resource__c != null && job.Service_Territory__c != null) {
                    String s = job.Service_Resource__c + '|' + job.Service_Territory__c;
                    if (srsTIdToCapJobMap.get(s) != null) {
                        Capacity_Rebuild_Job__c existJob = srsTIdToCapJobMap.get(s);
                        if (job.Start_Date__c > existjob.Start_Date__c) {
                            job.Start_Date__c = existjob.Start_Date__c;
                        }
                        if (job.End_Date__c < existjob.End_Date__c) {
                            job.End_Date__c = existjob.End_Date__c;
                        }
                    }
                    srsTIdToCapJobMap.put(s, job);
                }
            }

            // Loop through the STMS to add to the set for rebuild
            for (
                ServiceTerritoryMember stm : [
                    SELECT Id, ServiceTerritoryId, ServiceResourceId, ServiceResource.IsActive, EffectiveStartDate, EffectiveEndDate, TerritoryType, ServiceTerritory.OperatingHours.TimeZone
                    FROM ServiceTerritoryMember
                    WHERE
                        ServiceTerritory.IsActive = TRUE
                        //ServiceResource.IsActive = TRUE AND
                        AND (ServiceResourceId IN :serviceResourceIdToCapJobMap.keySet()
                        OR ServiceTerritoryId IN :serviceTerritoryIdToCapJobMap.keySet())
                        AND (EffectiveEndDate = NULL
                        OR EffectiveEndDate >= TODAY)
                        AND ServiceTerritory.OperatingHours.TimeZone IN :timezonesToRebuildSet
                    ORDER BY ServiceResourceId
                ]
            ) {
                System.debug('stm.ServiceTerritory.OperatingHours.TimeZone --- ' + stm.ServiceTerritory.OperatingHours.TimeZone);

                System.debug('stm.ServiceTerritoryId --- ' + stm.ServiceTerritoryId);

                if (stm.TerritoryType != 'R') {
                    srIdSet.add(stm.ServiceResourceId);
                }

                // Get the associated Job record
                Capacity_Rebuild_Job__c job;
                String s = stm.ServiceResourceId + '|' + stm.ServiceTerritoryId;
                if (srsTIdToCapJobMap.get(s) != null) {
                    job = srsTIdToCapJobMap.get(s);
                }
                if (serviceTerritoryIdToCapJobMap.get(stm.ServiceTerritoryId) != null) {
                    Capacity_Rebuild_Job__c stJob = serviceTerritoryIdToCapJobMap.get(stm.ServiceTerritoryId);
                    if (job != null) {
                        if (job.Start_Date__c > stjob.Start_Date__c) {
                            job.Start_Date__c = stjob.Start_Date__c;
                        }
                        if (job.End_Date__c < stjob.End_Date__c) {
                            job.End_Date__c = stjob.End_Date__c;
                        }
                    } else {
                        job = stJob;
                    }
                }
                if (serviceResourceIdToCapJobMap.get(stm.ServiceResourceId) != null) {
                    Capacity_Rebuild_Job__c srJob = serviceResourceIdToCapJobMap.get(stm.ServiceResourceId);
                    if (job != null) {
                        if (job.Start_Date__c > srjob.Start_Date__c) {
                            job.Start_Date__c = srjob.Start_Date__c;
                        }
                        if (job.End_Date__c < srjob.End_Date__c) {
                            job.End_Date__c = srjob.End_Date__c;
                        }
                    } else {
                        job = srJob;
                    }
                }
                if (job == null) {
                    continue;
                } // Skip if no hits.  Shouldnt happen

                // Make sure the STM is Active based on effective date and rebuild date
                if (job.Start_Date__c != null && job.End_Date__c != null) {
                    if (stm.EffectiveStartDate.Date() <= job.End_Date__c && (stm.EffectiveEndDate == null || stm.EffectiveEndDate.Date() >= job.Start_Date__c)) {
                        // Only rebuild if RC needs to be updated
                        if (
                            job.Type__c != CAP_REBUILD_SERVICE_APPOINTMENT_INSERT &&
                            job.Type__c != CAP_REBUILD_SERVICE_APPOINTMENT_DELETE &&
                            job.Type__c != CAP_REBUILD_SERVICE_APPOINTMENT_UPDATE_NO_AR &&
                            job.Type__c != CAP_REBUILD_CAPACITY_TEMPLATE_DELETE &&
                            job.Type__c != CAP_REBUILD_CAPCITY_TEMPLATE_INSERT &&
                            job.Type__c != CAP_REBUILD_CAPCITY_TEMPLATE_UPDATE &&
                            job.Type__c != CAP_REBUILD_SERVICE_TERRITORY_UPDATE &&
                            stm.ServiceResource.IsActive
                        ) {
                            // Put in either Relocate or Primary/Secondary bucket based on ttype
                            if (stm.TerritoryType == relocationString) {
                                relocationSTMidToRebuildDateMap.put(stm.Id, new RebuildDate(job.Start_Date__c, job.End_Date__c));
                            } else {
                                stmIdToRebuildDateMap.put(stm.Id, new RebuildDate(job.Start_Date__c, job.End_Date__c));
                            }
                        }
                        // add related territories to the set for CC rebuild
                        if (territoryIdToRebuildMap.containsKey(stm.ServiceTerritoryId)) {
                            RebuildDate oldRebuildDate = territoryIdToRebuildMap.get(stm.ServiceTerritoryId);

                            if (job.Start_Date__c > oldRebuildDate.startDate) {
                                job.Start_Date__c = oldRebuildDate.startDate;
                            }
                            if (job.End_Date__c < oldRebuildDate.endDate) {
                                job.End_Date__c = oldRebuildDate.endDate;
                            }

                            territoryIdToRebuildMap.put(stm.ServiceTerritoryId, new RebuildDate(job.Start_Date__c, job.End_Date__c));
                        } else {
                            territoryIdToRebuildMap.put(stm.ServiceTerritoryId, new RebuildDate(job.Start_Date__c, job.End_Date__c));
                        }
                    }
                }
            }

            for (Id srId : srIdSet) {
                if (srJobListMap.get(srId) != null) {
                    deleteJobList.addAll(srJobListMap.get(srId));
                }
            }
            System.debug('Heapsize used>' + system.Limits.getHeapSize());
            delete deleteJobList; // Delete jobs once they are processed
            System.debug('SOQL query rows used>' + System.Limits.getQueryRows());
        } catch (Exception e) {
        }
    }

    // call the Resource Capacity rebuild batch for the relevant STMs
    global void finish(Database.BatchableContext BC) {
        system.debug('territorySizeFlagforCC======' + territorySizeFlagforCC);
        System.debug('territoryIdToRebuildMap --- ' + territoryIdToRebuildMap);
        if (territoryIdToRebuildMap != null && territoryIdToRebuildMap.size() > 0) {
            SFS_ABResourceCapacityTimeSlotBatch nextbatch = new SFS_ABResourceCapacityTimeSlotBatch(
                stmIdToRebuildDateMap,
                relocationSTMidToRebuildDateMap,
                territoryIdToRebuildMap,
                territorySizeFlagforCC
            );
            database.executeBatch(nextBatch, 100);
        }
		else if(!Test.isRunningTest())
        {
            System.scheduleBatch(new SFS_ABCapacityRebuildJobBatch('Batch1'), 'SFS_ABCapacityRebuildJobBatch - '+System.now().addSeconds(300), 5);
        }
    }

    // Global class to pass the rebuild dates along side the stms for better processing
    global class rebuildDate {
        public Date startDate;
        public Date endDate;

        global rebuildDate(Date sDate, Date eDate) {
            startDate = sDate;
            endDate = eDate;
        }
    }
}