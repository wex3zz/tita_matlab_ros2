%% Set environment and initialize node
% setenv("ROS_DOMAIN_ID", "42");% use your DOMIAN_ID to replace 42
run get_tita_namespace.m ;

matlab_tita_ception_show_node = ros2node("/matlab_tita_ception_show_node");
pause(3);% Ensure connection is established


%% Initialize global state 
global fig imu_text motor_left_text motor_right_text battery_left_text battery_right_text isFigureOpen;
isFigureOpen = true; 

% Create figures and layouts
fig = figure('Name', 'Robot Status', 'NumberTitle', 'off', 'CloseRequestFcn', @closeFigureCallback);
tiledlayout(3, 2); % IMU, Motor, Battery

% IMU
nexttile(1,[1,2]);
imu_text = text(0.1, 0.2, '', 'FontSize', 8, 'Interpreter', 'none');
title('IMU Data');
axis off;
% Motor
nexttile(3);
motor_left_text = text(0.1, 0.2, '', 'FontSize', 8, 'Interpreter', 'none');
title('Left Motor Data');
axis off;

nexttile(4);
motor_right_text = text(0.1, 0.2, '', 'FontSize', 8, 'Interpreter', 'none');
title('Right Motor Data');
axis off;
% Battery Left
nexttile(5);
battery_left_text = text(0.1, 0.5, '', 'FontSize', 8, 'Interpreter', 'none');
title('Battery Left Data');
axis off;
% Battery Right
nexttile(6);
battery_right_text = text(0.1, 0.5, '', 'FontSize', 8, 'Interpreter', 'none');
title('Battery Right Data');
axis off;

% ROS Subscribers
ImuSub = ros2subscriber(matlab_tita_ception_show_node,['/',tita_namespace,'/imu_sensor_broadcaster/imu'],@ImuCallback);
MotorSub = ros2subscriber(matlab_tita_ception_show_node,['/',tita_namespace,'/joint_states'],@motorStatusCallback);
BatteryLeftSub = ros2subscriber(matlab_tita_ception_show_node,['/',tita_namespace,'/system/battery/left'],@batteryLeftStatusCallback);
BatteryRightSub = ros2subscriber(matlab_tita_ception_show_node,['/',tita_namespace,'/system/battery/right'],@batteryRightStatusCallback);

% To remove the subscribers and node, input the following command into the command window
% clear ImuSub MotorSub BatteryLeftSub BatteryRightSub matlab_tita_ception_show_node; 

%% Callback functions
function ImuCallback(msg)
    global imu_text isFigureOpen;
    if ~isFigureOpen
        return; 
    end
    x = msg.orientation.x;
    y = msg.orientation.y;
    z = msg.orientation.z;
    w = msg.orientation.w;
    EulerZYX = quat2eul([w x y z], "ZYX");
    imu_data = sprintf(['Quaternion:\n x: %f\n y: %f\n z: %f\n w: %f\n', ...
                        'EulerZYX: %f %f %f\n'], ...
                        x, y, z, w, EulerZYX(1), EulerZYX(2), EulerZYX(3));
    set(imu_text, 'String', imu_data); 
end

function motorStatusCallback(msg)
    global motor_left_text motor_right_text isFigureOpen;
    if ~isFigureOpen
        return; 
    end
    left_leg1_pos = msg.position(1) ;
    left_leg2_pos = msg.position(2) ;
    left_leg3_pos = msg.position(3) ;
    left_leg4_pos = msg.position(4) ;
    
    right_leg1_pos = msg.position(5) ;
    right_leg2_pos = msg.position(6) ;
    right_leg3_pos = msg.position(7) ;
    right_leg4_pos = msg.position(8) ;

    motor_left_data = sprintf('LeftMotorStatus:\n left_leg1_pos: %f\n left_leg2_pos: %f\n left_leg3_pos: %f\n left_leg4_pos: %f\n', ...
                          left_leg1_pos,left_leg2_pos,left_leg3_pos,left_leg4_pos);
    motor_right_data = sprintf('RightMotorStatus:\n right_leg1_pos: %f\n right_leg2_pos: %f\n right_leg3_pos: %f\n right_leg4_pos: %f\n', ...
                          right_leg1_pos,right_leg2_pos,right_leg3_pos,right_leg4_pos);
    set(motor_left_text, 'String', motor_left_data); 
    set(motor_right_text, 'String', motor_right_data); 

end

function batteryLeftStatusCallback(msg)
    global battery_left_text isFigureOpen;
    if ~isFigureOpen
        return; 
    end
    battery_data = sprintf('Battery Left Percentage: %f%%\n',msg.percentage);
    set(battery_left_text, 'String', battery_data); 
end

function batteryRightStatusCallback(msg)
    global battery_right_text isFigureOpen;
    if ~isFigureOpen
        return; 
    end
    battery_data = sprintf('Battery Right Percentage: %f%%\n',msg.percentage);
    set(battery_right_text, 'String', battery_data); 
end

%% Close figure callback
function closeFigureCallback(~, ~)
    global isFigureOpen ;
    disp('Closing figure');
    isFigureOpen = false; 
    delete(gcf); 
end
