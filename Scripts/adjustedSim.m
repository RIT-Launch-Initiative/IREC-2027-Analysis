%% Adjusted simulation tool
% IREC Systems 2026
% This script runs openrocket simulations with adjustments for atmospheric
% profile, drag curve, and with extra outputs
clear; close all; clc;
%% Inputs
targetMass = 27.724; 
% DO NOT LEAVE OVERRIDES ACTIVE
overrideAbMass = [0 0.26]; % [logical, value(kg)]
overrideAviMass = [0 1.66];
overridePayloadMass = [0 0];

%% Auto inputs
load("C://IREC-Analysis-2027/Design Reporting/reportData1.mat");
load("C://IREC-Analysis-2027/Design Reporting/reportData2.mat");
load("C://IREC-Analysis-2027/Design Reporting/reportData3.mat");
alt_var = 0.5*reportData1.control-reportData1.uncertainty;
alt_target = 3048 + reportData1.ind_error + 0.5*reportData1.control;
%% Setup
% Retrieve openrocket
filepath = "C:\IREC-Analysis-2027\Rocket Files\RISK.ork";
risk = openrocket(filepath);
rocket = risk.rocket();
% Reference simulation
sim = risk.sims("15mph-Midland");
% rocket parameters
L = rocket.getLength();
[D, ~] = risk.refdims();
% Other parameters
R = 0.287; % Specific gas constant for air

% Valid sites: "spaceport-midland", "spaceport-america", "urrg", "mars"
site = launchsites("spaceport-midland"); 
% Launch time
lTime.date = [2025, 06, 21]; % [year, month, day]
lTime.time = [10, 21, 00]; % [hour, minute, second]
airDataFilePath = "C:\IREC-Analysis-2027\atmosphereData\airdata.mat";

% Rasaero drag curve
dragFilePath = "C:\IREC-Analysis-2027\Data\CDplot-RISK-allTurbulent.csv";

%% Get atmosphere
airdata = importdata(airDataFilePath);
airdata.TMP = airdata.TMP + 273.15; % conv Celcius to Kelvin
%% Get drag curve
rasDrag = import_rasaero_aerodata(dragFilePath);
rasDrag = rasDrag.align("mach");
rasDrag = table(rasDrag.mach, rasDrag.pick{"aoa", 0, "field", "CD"}, ...
    VariableNames = ["MACH", "DRAG"]);
rasDrag.MACH(1) = 0;

%% Subsystem mass override
airbrake = risk.component(name="Airbrake");
avionics = risk.component(name="Avionics");
payload = risk.component(name="Payload");
if overrideAbMass(1)
    airbrake.setComponentMass(overrideAbMass(2))
end
if overrideAviMass(1)
    avionics.setComponentMass(overrideAviMass(2))
end
if overridePayloadMass(1)
    payload.setComponentMass(overridePayloadMass(2))
end

%% Simulate!!
simData = risk.simulate(sim, outputs = "ALL", atmos = airdata(:, ["HGT", "PRES", "TMP"]),...
    drag = rasDrag);
% Add density and dynamic pressure to table
simData.("Air density") = simData.("Air pressure")./(1000*R*simData.("Air temperature"));
simData.("Dynamic pressure") = 0.5*simData.("Air density").*simData.("Total velocity").^2;
% Add percent stability to table
simData.("Stability percent") = 100*simData.("Stability margin")*D/L;
% Add Indicated altitude to table
simData.("Indicated altitude") = pressalt("m", simData.("Air pressure"), "Pa") - pressalt("m", simData{1, "Air pressure"}, "Pa");
simData.("Altitude error") = simData.("Indicated altitude") - simData.("Altitude");
% Times vector
times = simData.Time;

%% Generate text output
% Apogee
ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("APOGEE"));
mAlt = max(simData.Altitude);
mAltInd = max(simData.("Indicated altitude"));
errAlt = mAlt - mAltInd;
targetErr = mAlt - alt_target;
lowErr = mAlt - (alt_target - alt_var);
highErr = mAlt - (alt_target + alt_var);
if abs(targetErr) <= alt_var
    strTarget = "ON TARGET";
else
    if targetErr > 0
        strTarget = "OVERSHOOT";
    else
        strTarget = "UNDERSHOOT";
    end
end
% Stability
stabData = simData(ascentRange, ["Stability margin", "Stability percent"]);
stabRod = stabData.("Stability percent")(2);
stabRodCal = stabData.("Stability margin")(2);
stabMax = max(simData.("Stability percent"));
stabMaxCal = max(simData.("Stability margin"));
% Flutter
fins = risk.component(class="FinSet");
flutterFOS = FOS_finflutter(simData, fins);
% Dynamic pressure
qData = simData(ascentRange, "Dynamic pressure").("Dynamic pressure");
max_q = [0 0];
for i = 1 : length(qData)
    if qData(i) > max_q(2)
        max_q = [seconds(times(i)) qData(i)];
        max_q_vel = simData.("Total velocity")(i);
    end
end
accelData = simData(ascentRange, "Total acceleration");
maxVel = max(simData.("Total velocity"));
rodVel = simData(ascentRange, "Total velocity").("Total velocity")(1);
maxMach = max(simData.("Mach number"));
maxAccel = max(accelData.("Total acceleration"));
maxG = maxAccel/9.81;


%% Plot outputs :) :)
% plotRange = timerange(eventfilter("LAUNCH"), eventfilter("DROGUE"));
% plot_openrocket(simData(plotRange, :), "Altitude", "Total velocity", end_ev = "DROGUE", labels = ["LAUNCHROD", "BURNOUT", "APOGEE"]);
% plotAltitudeError(simData)
% plotErrorVAltitude(simData)
% plotStabPercent(simData)
% plotStabCombined(simData)
% plotCPlocation(simData)
% plotAltVelAccel(simData)

%% Update Report
reportData1.status = strTarget;
reportData1.apogee = mAlt;
reportData1.apogee_indicated = mAltInd;
reportData1.target = alt_target;
reportData1.error = targetErr;
reportData1.ind_error = errAlt;
save("C://IREC-Analysis-2027/Design Reporting/reportData1.mat", "reportData1")

reportData2.maxSpeed = maxVel;
reportData2.rodSpeed = rodVel;
reportData2.maxAccel = maxAccel;
reportData2.flightTime = seconds(times(end));
reportData2.rodStab = stabRod;
reportData2.maxStab = stabMax;
reportData2.flutterSpeed = flutterFOS*maxVel;
reportData2.flutterMargin = flutterFOS;
reportData2.q = max_q(2);
reportData2.qVel = max_q_vel;
reportData2.qTime = max_q(1);
save("C://IREC-Analysis-2027/Design Reporting/reportData2.mat", "reportData2")

% get subsystem masses
AB = risk.component(name="Airbrake");
avi = risk.component(name="Avionics");
payload = risk.component(name="Payload");
ABMass = AB.getMass;
avMass = avi.getMass;
payloadMass = payload.getMass;
systemsMass = ABMass + avMass + payloadMass;

% get reco dimensions
mainChute = risk.component(name="Main");
mainD = mainChute.getDiameter;
mainA = mainChute.getArea;
mainCD = mainChute.getCD;
drogueChute = risk.component(name="Drogue");
drogueD = drogueChute.getDiameter;
drogueA = drogueChute.getArea;
drogueCD = drogueChute.getCD;

% formulate report 3rd section
reportData3.length = L;
reportData3.diameter = D;
reportData3.area = (pi/4)*D^2;
reportData3.massLoaded = simData.("Mass")(1);
reportData3.massBurnout = simData.("Mass")(eventfilter("BURNOUT"));
reportData3.massNoMotor = simData.("Mass")(1) - simData.("Motor mass")(1);
reportData3.massEmpty = simData.("Mass")(1) - simData.("Motor mass")(1) - systemsMass;
reportData3.massTarget = targetMass;
reportData3.massErr = reportData3.massLoaded-targetMass;
reportData3.ABMass = ABMass;
reportData3.avMass = avMass;
reportData3.payloadMass = payloadMass;
reportData3.mainDiameter = mainD;
reportData3.mainArea = mainD;
reportData3.mainCD = mainCD;
reportData3.drogueDiameter = drogueD;
reportData3.drogueArea = drogueA;
reportData3.drogueCD = drogueCD;
save("C://IREC-Analysis-2027/Design Reporting/reportData3.mat", "reportData3")

updateReport;

%% Text output
fprintf("%s\n", strTarget);
fprintf("\nGeometric Apogee: %4.0f m\nIndicated Apogee: %4.0f m\nMeasurement Error: %3.0f m\n"...
    + "Apogee Error: %2.1f m\nLower bound delta: %2.1f m\nUpper bound delta: %2.1f m\n", mAlt, mAltInd, errAlt, targetErr, lowErr, highErr);
fprintf("\nMaximum velocity: %4.0f m/s\nMaximum acceleration: %3.0f m/s^2 (%2.1f g)\n" + ...
    "Maximum mach number: %1.2f\n", maxVel, maxAccel, maxG, maxMach);
fprintf("\nLaunch stability: %2.2f percent (%.2f cal)\nMaximum stability: %2.2f percent (%.2f cal)\n",...
      stabRod, stabRodCal, stabMax, stabMaxCal);
fprintf("\nFlutter FoS: %1.2f\n", flutterFOS);
fprintf("\nMax q: %.2f kPa at %.2f seconds\n", (max_q(2)*10^-3), max_q(1))

%% Functions
function plotMotion(simData)
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("DROGUE"), "openleft");
    data = simData(ascentRange, ["Altitude", "Total velocity"]);
    figure(name = "Total Motion")
    xlabel("Time [s]")
    yyaxis("left");
    plot(data, "Time", "Altitude")
    ylabel("Altitude [m]")
    yyaxis("right")
    plot(data, "Time", "Total velocity")
    ylabel("Velocity [m/s]")
end
function plotStabPercent(simData)
    % Trim data
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("APOGEE"), "openleft");
    stabData = simData(ascentRange, ["Stability percent", "Angle of attack"]);
    stabData.("Angle of attack") = (180/pi)*stabData.("Angle of attack");
    % Plot the data
    figure(name = "Stability")
    hold on;
    % Left side
    yyaxis("left")
    plot(stabData, "Time", "Stability percent");
    ylabel("Stability [%]")
    % Right side
    yyaxis("right")
    plot(stabData, "Time", "Angle of attack");
    ylabel("Angle of Attack [degrees]")
    hold off;
    % Finish plot
    xlabel("Time [s]")
    % xl = xline(ev_in_range.Time(selected_ev), "-k", ...
    % ev_in_range.EventLabels(selected_ev), ...
    % Interpreter = "none", HandleVisibility = "off");
    % xl(end).LabelHorizontalAlignment = "left";
end
function plotAltitudeError(simData)
    % Adjust data for plotting
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("APOGEE"), "openleft");
    altData = simData(ascentRange, ["Altitude", "Indicated altitude", "Altitude error"]);
    yMax = max(altData.("Altitude"))*1.1;
    % Plot altitudes
    figure(name = "Altitude comparison")
    % Left side
    yyaxis("left")
    plot(altData, "Time", "Altitude", "Color","b");
    ylim([0,yMax])
    ylabel("Altitude [m]")
    hold on;
    plot(altData, "Time", "Indicated altitude", "Color", "g");
    % Right side
    yyaxis("right")
    plot(altData, "Time", "Altitude error", "Color", "r");
    hold off;
    ylabel("Altitude error [m]")
    % Other plot related things
    xlabel("Time [s]")
    legend("Altitude", "Indicated altitude", "Error", "location", "northeast")
end
function plotErrorVAltitude(simData)
    % Adjust data for plotting
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("MAIN"), "openleft");
    altData = simData(ascentRange, ["Altitude", "Indicated altitude", "Altitude error"]);
    yMax = max(altData.("Altitude"))*1.1;
    % Plot altitudes
    figure(name = "Altitude comparison")
    % Left side
    yyaxis("left")
    plot(altData, "Time", "Altitude", "Color","b");
    ylim([0,yMax])
    ylabel("Altitude [m]")
    hold on;
    plot(altData, "Time", "Indicated altitude", "Color", "g");
    % Right side
    yyaxis("right")
    plot(altData, "Time", "Altitude error", "Color", "r");
    hold off;
    ylabel("Altitude error [m]")
    % Other plot related things
    xlabel("Time [s]")
    legend("Altitude", "Indicated altitude", "Error", "location", "northeast")
end
function plotCPlocation(simData)
    % Trim data
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("APOGEE"), "openleft");
    stabData = simData(ascentRange, ["CP location", "Angle of attack", "Mach number"]);
    stabData.("CP location") = stabData.("CP location")/0.0254;
    % Plot the data
    figure(name = "CP location")
    hold on;
    % Left side
    yyaxis("left")
    plot(stabData, "Time", "CP location", "Color", "r");
    ylabel("CP location [inches]")
    xlabel("Time [s]")
end
function plotStabCombined(simData)
    % Trim data
    ascentRange = timerange(eventfilter("LAUNCHROD"), eventfilter("APOGEE"), "openleft");
    stabData = simData(ascentRange, ["Stability percent", "Stability margin"]);
    % Plot the data
    figure(name = "Stability (% and cal)")
    hold on;
    % Left side
    yyaxis("left")
    plot(stabData, "Time", "Stability percent");
    ylabel("Stability [%]")
    % Right side
    yyaxis("right")
    plot(stabData, "Time", "Stability margin");
    ylabel("Stability calibers [cal]")
    hold off;
    % Finish plot
    xlabel("Time [s]")
    grid on
    title("Stability (No Wind)")
end
function plotAltVelAccel(simData)
    data = simData(:, ["Altitude", "Total velocity", "Total acceleration"]);
    figure(name = "Total Motion")
    xlabel("Time [s]")
    yyaxis("left")
    plot(data, "Time", "Altitude", "LineWidth", 1)
    ylabel("Altitude [m]")
    yyaxis("right")
    hold on
    plot(data, "Time", "Total velocity", "LineWidth", 1)
    plot(data, "Time", "Total acceleration", "Color", "#52C400", "LineStyle", "-", "LineWidth", 1)
    hold off
    grid on
    ylabel("Velocity [m/s], Acceleration [m/s^2]")
    legend("Altitude", "Velocity", "Acceleration")
end