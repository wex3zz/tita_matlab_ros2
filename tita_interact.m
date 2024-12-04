%% Set environment and initialize node
% setenv("ROS_DOMAIN_ID", "42");% use your DOMIAN_ID to replace 42
run get_tita_namespace.m ;

matlab_tita_interact_node = ros2node("/matlab_tita_interact_node");
pause(3); % Ensure connection is established
%% Initialize global state in a structured way
global state;
state = struct(...
    'isFigureOpen', true, ...
    'key_input', '', ...
    'pitch_cmd',0.0,...
    'roll_cmd',0.0,...
    'imu', struct('counter', 0, 'data', zeros(0, 3), 'plots', gobjects(1, 3),'plot_buffer',200), ...
    'motor', struct('counter', 0, 'data', zeros(0, 8), 'plots', struct('left', gobjects(1, 4), 'right', gobjects(1, 4)),'plot_buffer',200), ...
    'battery_left', struct('counter', 0, 'percentage', [], 'plot', gobjects(1),'plot_buffer',50), ...
    'battery_right', struct('counter', 0, 'percentage', [], 'plot', gobjects(1),'plot_buffer',50) ...
);

% Create figures and layouts
createFiguresAndLayouts();

% ROS Subscribers
ImuSub = ros2subscriber(matlab_tita_interact_node,['/',tita_namespace,'/imu_sensor_broadcaster/imu'],@ImuCallback);
MotorSub = ros2subscriber(matlab_tita_interact_node,['/',tita_namespace,'/joint_states'],@motorStatusCallback);
BatteryLeftSub = ros2subscriber(matlab_tita_interact_node,['/',tita_namespace,'/system/battery/left'],@batteryLeftStatusCallback);
BatteryRightSub = ros2subscriber(matlab_tita_interact_node,['/',tita_namespace,'/system/battery/right'],@batteryRightStatusCallback);

% Keyboard listener for teleoperation
clc;
fprintf('Teleop start now!\n');
disp('you can press Esc to exit the teleop control node');
keyboard_listener_fig = figure('KeyPressFcn', @(src, event) keyboardListener(src, event));
set(keyboard_listener_fig, 'Name', 'Teleop Control', 'NumberTitle', 'off');
text_handle = text(0.5, 0.5, '', 'HorizontalAlignment', 'center', 'FontSize', 10, 'Interpreter', 'none');
axis off;

% Control message initialization
ctrlMsgs = initializeMotionCtrlMsg();
tita_ctrl_topic = ['/',tita_namespace,'/command/user/command'];
TITACmdPub = ros2publisher(matlab_tita_interact_node, tita_ctrl_topic, "tita_locomotion_interfaces/LocomotionCmd");

%% Main loop
subscribe_draw_counter = 0;
while true
    if ~isempty(state.key_input)
        key = state.key_input;
        disp(key);
        if key == "escape"
            break;  % Exit the loop
        else
            ctrlMsgs = generateMsgs(ctrlMsgs, key);
            send(TITACmdPub, ctrlMsgs);  % Publish the message
            state.key_input = '';
        end
    else
        % Default message when no key pressed
        ctrlMsgs.twist.linear.x = 0.0 ;
        ctrlMsgs.twist.angular.z = 0.0 ;
        send(TITACmdPub, ctrlMsgs);
    end
    msg_str = struct2str(ctrlMsgs); 
    set(text_handle, 'String', msg_str); 

    if mod(subscribe_draw_counter, 5) == 0
        updateImuPlots();
        updateMotorPlots();
        updateBatteryPlots();
        drawnow;
    end
    subscribe_draw_counter = subscribe_draw_counter + 1;

    pause(0.04);  % 40 ms sleep
end

fprintf('exit!\n');
clear 

%% Function to create figures and layouts
function createFiguresAndLayouts()
    global state;
    fig = figure('Name', 'Robot Status', 'NumberTitle', 'off', 'CloseRequestFcn', @closeFigureCallback);
    tiledlayout(4, 4);  % 4 rows, 4 columns layout
    initializePlots();
end

%% Function to initialize plots
function initializePlots()
    global state;
    titles = {'IMU Roll', 'IMU Pitch', 'IMU Yaw', 'Left Leg1 Position', 'Left Leg2 Position', 'Left Leg3 Position', 'Left Leg4 Position',...
              'Right Leg1 Position', 'Right Leg2 Position', 'Right Leg3 Position', 'Right Leg4 Position','Battery Left Data','Battery Right Data'};
    for i = 1:3
        nexttile;
        state.imu.plots(i) = plot(nan, nan);
        title(titles{i}, 'FontSize', 8);
        ylabel('Position (rad)', 'FontSize', 8);
        xlabel('Message Number', 'FontSize', 8);
    end
    for i= 5:12
        nexttile(i);
        if i <= 8
            state.motor.plots.left(i-4) = plot(nan, nan);
        else
            state.motor.plots.right(i-8) = plot(nan, nan);
        end
        title(titles{i-1}, 'FontSize', 8);
        ylabel('Position (rad)', 'FontSize', 8);
        xlabel('Message Number', 'FontSize', 8);
    end
    nexttile(13, [1, 2]);
    state.battery_left.plot = plot(nan, nan);
    title(titles{12}, 'FontSize', 8);
    ylabel('Percentage (%)', 'FontSize', 8);
    xlabel('Message Number', 'FontSize', 8);
    nexttile(15, [1, 2]);
    state.battery_right.plot = plot(nan, nan);
    title(titles{13}, 'FontSize', 8);
    ylabel('Percentage (%)', 'FontSize', 8);
    xlabel('Message Number', 'FontSize', 8);
end

%% Close figure callback
function closeFigureCallback(~, ~)
    global state;
    disp('Closing figure');
    state.isFigureOpen = false;
    delete(gcf);
end

%% Update IMU 
function ImuCallback(msg)
    global state;
    if ~state.isFigureOpen
        return;
    end
    updateImuData(msg);
end

function updateImuData(msg)
    global state;
    x = msg.orientation.x;
    y = msg.orientation.y;
    z = msg.orientation.z;
    w = msg.orientation.w;
    EulerZYX = quat2eul([w x y z], "ZYX");
    state.imu.data = [state.imu.data; EulerZYX];
    if size(state.imu.data, 1) > state.imu.plot_buffer
        state.imu.data = state.imu.data(end-(state.imu.plot_buffer-1):end, :);
    end
    state.imu.counter = state.imu.counter + 1;
end

function updateImuPlots()
    global state;
    for i = 1:3
        set(state.imu.plots(i), 'XData', max(1, state.imu.counter-(state.imu.plot_buffer-1)):state.imu.counter, 'YData', state.imu.data(:, 3-i+1));
    end
end

%% Update motor 
function motorStatusCallback(msg)
    global state;
    if ~state.isFigureOpen
        return;
    end
    updateMotorData(msg);
end

function updateMotorData(msg)
    global state;
    new_data = [msg.position(1) msg.position(2) msg.position(3) msg.position(4) msg.position(5) msg.position(6) msg.position(7) msg.position(8)];
    state.motor.data = [state.motor.data; new_data];
    if size(state.motor.data, 1) > state.motor.plot_buffer
        state.motor.data = state.motor.data(end-(state.motor.plot_buffer-1):end, :);
    end
    state.motor.counter = state.motor.counter + 1;
end

function updateMotorPlots()
    global state;
    for i = 1:4
        set(state.motor.plots.left(i), 'XData', max(1, state.motor.counter-(state.motor.plot_buffer-1)):state.motor.counter, 'YData', state.motor.data(:, i));
        set(state.motor.plots.right(i), 'XData', max(1, state.motor.counter-(state.motor.plot_buffer-1)):state.motor.counter, 'YData', state.motor.data(:, i+4));
    end
end

%% Update battery 
function batteryLeftStatusCallback(msg)
    global state;
    if ~state.isFigureOpen
        return;
    end
    updateBatteryLeftData(msg);
end

function updateBatteryLeftData(msg)
    global state;
    state.battery_left.percentage = [state.battery_left.percentage; msg.percentage];
    if length(state.battery_left.percentage) > state.battery_left.plot_buffer
        state.battery_left.percentage = state.battery_left.percentage(end-(state.battery_left.plot_buffer-1):end);
    end
    state.battery_left.counter = state.battery_left.counter + 1;
end

function batteryRightStatusCallback(msg)
    global state;
    if ~state.isFigureOpen
        return;
    end
    updateBatteryRightData(msg);
end

function updateBatteryRightData(msg)
    global state;
    state.battery_right.percentage = [state.battery_right.percentage; msg.percentage];
    if length(state.battery_right.percentage) > state.battery_right.plot_buffer
        state.battery_right.percentage = state.battery_right.percentage(end-(state.battery_right.plot_buffer-1):end);
    end
    state.battery_right.counter = state.battery_right.counter + 1;
end

function updateBatteryPlots()
    global state;
    set(state.battery_left.plot, 'XData', max(1, state.battery_left.counter-(state.battery_left.plot_buffer-1)):state.battery_left.counter, 'YData', state.battery_left.percentage);
    set(state.battery_right.plot, 'XData', max(1, state.battery_right.counter-(state.battery_right.plot_buffer-1)):state.battery_right.counter, 'YData', state.battery_right.percentage);
end

%% Keyboard listener
function keyboardListener(src, event)
    global state;
    if src == gcf
        state.key_input = event.Key;
        if strcmp(event.Key, 'escape')
            disp('Press Esc, exit the node...');
            close(src);  % Close figure window
        end
    end
end

%%
function ctrlMsgs = initializeMotionCtrlMsg()
    % Initialize the MotionCtrl message structure
    ctrlMsgs = ros2message("tita_locomotion_interfaces/LocomotionCmd");

    totalSecondsSince1970 = etime(datevec(now), [1970 1 1 0 0 0]);
    ctrlMsgs.header.stamp.sec = int32(floor(totalSecondsSince1970));
    ctrlMsgs.header.stamp.nanosec = uint32(rem(totalSecondsSince1970, 1) * 1e9);
    ctrlMsgs.header.frame_id = 'cmd';

    ctrlMsgs.fsm_mode = 'idle';

    ctrlMsgs.pose.position.x = 0.0 ;
    ctrlMsgs.pose.position.y = 0.0 ;
    ctrlMsgs.pose.position.z = 0.0 ;
    ctrlMsgs.pose.orientation.x = 0.0 ;
    ctrlMsgs.pose.orientation.y = 0.0 ;
    ctrlMsgs.pose.orientation.z = 0.0 ;
    ctrlMsgs.pose.orientation.w = 1.0 ;

    ctrlMsgs.twist.linear.x = 0.0 ;
    ctrlMsgs.twist.linear.y = 0.0 ;
    ctrlMsgs.twist.linear.z = 0.0 ;
    ctrlMsgs.twist.angular.x = 0.0 ;
    ctrlMsgs.twist.angular.y = 0.0 ;
    ctrlMsgs.twist.angular.z = 0.0 ;
end

function ctrlMsgs = generateMsgs(ctrlMsgs, key)
    global state
    % Update control message based on the input key
    totalSecondsSince1970 = etime(datevec(now), [1970 1 1 0 0 0]);
    ctrlMsgs.header.stamp.sec = int32(floor(totalSecondsSince1970));
    ctrlMsgs.header.stamp.nanosec = uint32(rem(totalSecondsSince1970, 1) * 1e9);
    switch key
        case 'w'
            ctrlMsgs.twist.linear.x = 0.5;
        case 's'
            ctrlMsgs.twist.linear.x = -0.5;
        case 'a'
            ctrlMsgs.twist.angular.z = 1.0;
        case 'd'
            ctrlMsgs.twist.angular.z = -1.0;
        case 'e'
            state.roll_cmd = 0.1;
        case 'q'
            state.roll_cmd = -0.1;
        case 'r'
            state.roll_cmd = 0.0;
        case 'h'
            ctrlMsgs.pose.position.z = 0.0;
        case 'j'
            ctrlMsgs.pose.position.z = 0.3;
        case 'k'
            ctrlMsgs.pose.position.z = 0.15;
        case 'u'
            state.pitch_cmd = 0.5;
        case 'i'
            state.pitch_cmd = 0.0;
        case 'o'
            state.pitch_cmd = -0.5;
        case 'z'
            ctrlMsgs.fsm_mode = 'transform_up';
            ctrlMsgs.pose.position.z = 0.2;
        case 'x'
            ctrlMsgs.fsm_mode = 'transform_down';
            ctrlMsgs.pose.position.z = 0.0;
        case 'c'
            ctrlMsgs.fsm_mode = 'idle';
            ctrlMsgs.pose.position.z = 0.0;
        otherwise
            % Do nothing for unrecognized keys
    end
    orientastion_cmd = eul2quat([0.0 state.pitch_cmd state.roll_cmd],'ZYX');
    ctrlMsgs.pose.orientation.w = orientastion_cmd(1);
    ctrlMsgs.pose.orientation.x = orientastion_cmd(2);
    ctrlMsgs.pose.orientation.y = orientastion_cmd(3);
    ctrlMsgs.pose.orientation.z = orientastion_cmd(4);
end


%% Convert struct to string for display
function str = struct2str(structVar)
    fields = fieldnames(structVar);
    str = '';
    for i = 1:length(fields)
        field = fields{i};
        value = structVar.(field);
        if isstruct(value)
            subfields = struct2str(value);
            str = [str, sprintf('%s:  %s', field, subfields)];
        else
            str = [str, sprintf('%s: %s\n', field, mat2str(value))];
        end
    end
end