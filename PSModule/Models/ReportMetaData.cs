﻿using PSModule.ParallelRunner.SDK.Entity;
using System.Collections.Generic;

namespace PSModule.Models
{
    public class ReportMetaData
    {
        public string ReportPath { get; set; } //slave path of report folder(only for html report format)

        public string DisplayName { get; set; }

        public string ResourceURL { get; set; }

        public string DateTime { get; set; }

        public string Status { get; set; }

        public string Duration { get; set; }

        public string ErrorMessage { get; set; } = string.Empty;

        public List<TestRun> TestRuns { get; set; } = new(); // used for Parallel Runner
    }
}