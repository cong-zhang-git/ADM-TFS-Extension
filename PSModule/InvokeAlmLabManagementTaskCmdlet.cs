﻿using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Management.Automation;

namespace PSModule
{
    [Cmdlet(VerbsLifecycle.Invoke, "AlmLabManagementTask")]

    public class InvokeAlmLabManagementTaskCmdlet : AbstractLauncherTaskCmdlet
    {
        [Parameter(Position = 0, Mandatory = true)]
        public string ALMServerPath;

        [Parameter(Position = 1, Mandatory = true)]
        public string ALMUserName;

        [Parameter(Position = 2)]
        public string ALMPassword;

        [Parameter(Position = 3, Mandatory = true)]
        public string ALMDomain;

        [Parameter(Position = 4, Mandatory = true)]
        public string ALMProject;

        [Parameter(Position = 5)]
        public string TestRunType;

        [Parameter(Position = 6, Mandatory = true)]
        public string ALMTestSet;

        [Parameter(Position = 7)]
        public string Description;

        [Parameter(Position = 8, Mandatory = true)]
        public string TimeslotDuration;

        [Parameter(Position = 9)]
        public string EnvironmentConfigurationID;

        [Parameter(Position = 10)]
        public string ReportName;

        [Parameter(Position = 11)]
        public bool UseCDA;

        [Parameter(Position = 12)]
        public string DeploymentAction;

        [Parameter(Position = 13)]
        public string DeploymentEnvironmentName;

        [Parameter(Position = 14)]
        public string DeprovisioningAction;

        /*[Parameter(Position = 15, Mandatory = true)]
        public string UploadArtifact;

        [Parameter(Position = 16)]
        public ArtifactType ArtType;

        [Parameter(Position = 17)]
        public string StorageAccount;

        [Parameter(Position = 18)]
        public string Container;

        [Parameter(Position = 19)]
        public string ReportFileName;

        [Parameter(Position = 20)]
        public string ArchiveName;*/

        [Parameter(Position = 15)]
        public string BuildNumber;

        protected override string GetReportFilename()
        {
            return string.IsNullOrEmpty(ReportName) ? base.GetReportFilename() : ReportName;
        }


        public override Dictionary<string, string> GetTaskProperties()
        {
            LauncherParamsBuilder builder = new LauncherParamsBuilder();

            builder.SetRunType(RunType.AlmLabManagement);
            builder.SetAlmServerUrl(ALMServerPath);
            builder.SetAlmUserName(ALMUserName);
            builder.SetAlmPassword(ALMPassword);
            builder.SetAlmDomain(ALMDomain);
            builder.SetAlmProject(ALMProject);
            builder.SetBuildNumber(BuildNumber);

            switch (TestRunType)
            {
                case "testSet":
                    builder.SetTestRunType(RunTestType.TEST_SUITE);
                    break;
                case "buildVerificationSuite":
                    builder.SetTestRunType(RunTestType.BUILD_VERIFICATION_SUITE);
                    break;
            }

            if (!string.IsNullOrEmpty(ALMTestSet))
            {
                int i = 1;
                foreach (string testSet in ALMTestSet.Split('\n'))
                {
                    builder.SetTestSet(i++, testSet.Replace(@"\", @"\\"));
                }
            }
            else
            {
                builder.SetAlmTestSet("");
            }


            if (UseCDA)
            {
                builder.SetDeploymentAction(DeploymentAction);
                builder.SetDeployedEnvironmentName(DeploymentEnvironmentName);
                builder.SetDeprovisioningAction(DeprovisioningAction);
            }

            //set ALM mandatory parameters
            builder.SetAlmTimeout(TimeslotDuration);
            builder.SetAlmRunMode(AlmRunMode.RUN_LOCAL);
            builder.SetAlmRunHost("localhost");

            /*builder.SetUploadArtifact(UploadArtifact);
            builder.SetArtifactType(ArtType);
            builder.SetReportName(ReportFileName);
            builder.SetArchiveName(ArchiveName);
            builder.SetStorageAccount(StorageAccount);
            builder.SetContainer(Container);*/

            return builder.GetProperties();
        }

        protected override string GetRetCodeFileName()
        {
            return "TestRunReturnCode.txt";
        }
    }
}
