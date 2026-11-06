clc; clear;
% Rasaero drag curve
dragFilePath = "C:\IREC-2027-Analysis\Data\CDplot-RISK-allTurbulent.CSV";

%% Get drag curve
rasDrag = import_rasaero_aerodata(dragFilePath);
rasDrag = rasDrag.align("mach");
rasDrag = table(rasDrag.mach, rasDrag.pick{"aoa", 0, "field", "CD"}, ...
    VariableNames = ["MACH", "DRAG"]);
rasDrag.MACH(1) = 0;

% Rasaero drag curve
dragFilePath2 = "C:\IREC-2027-Analysis\RASAero Files\CD Test.CSV";

%% Get drag curve
rasDrag2 = import_rasaero_aerodata(dragFilePath2);
rasDrag2 = rasDrag2.align("mach");
rasDrag2 = table(rasDrag2.mach, rasDrag2.pick{"aoa", 0, "field", "CD"}, ...
    VariableNames = ["MACH", "DRAG"]);
rasDrag2.MACH(1) = 0;

rasDrag2.DRAG = rasDrag.DRAG - rasDrag2.DRAG;
disp(rasDrag2)