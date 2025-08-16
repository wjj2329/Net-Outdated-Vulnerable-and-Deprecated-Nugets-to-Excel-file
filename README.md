You can run this script on a visual studio solution and it will output outdated, deprecated and/or vulnerable nuget libraries to an excel file.  Please note that this will only work on solutions that contain net core targetting projects only. 
The arguments you can provide are as follows. 

-outdated  Write to excel all outdated nugets for the targeted solution

-deprecated Write to excel all deprecated nugets for the targeted solution

-vulnerable Write to excel all vulnerable nugets for the targed solution

-verbose Print to the console all settings that have been selected IE deprecated vulnerable outdated

-all Write to excel all outdated deprecated and vulnerable nugets for the targeted solution

-solutionPath The path to the solution we want to analyze
