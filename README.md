# KPI Monitoring Dashboard
![image]()

## Background
MSA & Associates owns and operates several business on the west coast of the United States.  Their executive management team relies on current information about their operations in order to make strategic decisions. Specifically, the team needs to track variations between actuals and forecasts for several of the company's key performance indicators (KPIs).  However, obtaining data from their siloed source systems is cumbersome and inefficient.  Further, once data is finally available, it's often difficult to consume.

## Project Objectives
This project set out to streamline the acquisiton and integration of MSAs KPI data, as well as to visualize the information in an intuitive way for managers to be able to make quick decisions.  The team needed a compact, information-dense dashboard that would enable them to view at-a-glance performance among their six primary KPIs, and to dive into the components of each, viewing trends over time.  

## Report
A link to the live report is available [here](https://app.powerbi.com/view?r=eyJrIjoiNTczMjA5MmItZmM0My00MDk2LWJjYTUtYjUxNWE4NmRiODFlIiwidCI6IjEwMmY4MzcyLTBlMWUtNDFhMy04ZWU4LTZhOTQ5NzAyZjcxNCJ9).

## Administration & Governance

### Workspace
My Workspace

### Distribution
Publish to web

### Sensitivity Label
Public

### Permissions
Public

## Repository Organization
The repository is organized into the following folders:

### 1. Data Pipeline
Storage of all SQL scripts governing the ETL process from source system to warehouse.

### 2. Forecast Monitoring Tool.Dataset
A collection of files and folders that represent a Power BI dataset. It contains some of the most important files you're likely to work on, like model.bim. To learn more about the files and subfolders and files in here, see [Project Dataset folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-dataset).

### 3. Forecast Monitoring Tool.Report
A collection of files and folders that represent a Power BI report. To learn more about the files and subfolders and files in here, see [Project report folder](https://learn.microsoft.com/en-us/power-bi/developer/projects/projects-report).

### 4. .gitignore
Specifies intentionally untracked files Git should ignore. Dataset and report subfolders each have default git ignored files specified in .gitIgnore:

* Dataset
    - .pbi\localSettings.json
    - .pbi\cache.abf

* Report
    - .pbi\localSettings.json

In addition to these, all client project docs (project plans, sketches, wireframes, etc), data and ux artifacts are ignored.

### 5. Forecast Monitoring Tool.pbip
The PBIP file contains a pointer to a report folder, opening a PBIP opens the targeted report and model for authoring. For more information, refer to the [pbip schema document](https://github.com/microsoft/powerbi-desktop-samples/blob/main/item-schemas/common/pbip.md).