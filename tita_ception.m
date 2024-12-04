%% Set environment and initialize node
% setenv("ROS_DOMAIN_ID", "42");% use your DOMIAN_ID to replace 42
run get_tita_namespace.m ;

matlab_tita_ception_node = ros2node("/matlab_tita_ception_node");
pause(3);% Ensure connection is established

ImuSub = ros2subscriber(matlab_tita_ception_node,['/',tita_namespace,'/imu_sensor_broadcaster/imu'],@ImuCallback);
MotorSub = ros2subscriber(matlab_tita_ception_node,['/',tita_namespace,'/joint_states'],@motorStatusCallback);
BatteryLeftSub = ros2subscriber(matlab_tita_ception_node,['/',tita_namespace,'/system/battery/left'],@batteryLeftStatusCallback);
BatteryRightSub = ros2subscriber(matlab_tita_ception_node,['/',tita_namespace,'/system/battery/right'],@batteryRightStatusCallback);

% To remove the subscribers and node, input the following command into the command window
% clear ImuSub MotorSub BatteryLeftSub BatteryRightSub matlab_tita_ception_node; 
%%
function ImuCallback(msg)
    x = msg.orientation.x;
    y = msg.orientation.y;
    z = msg.orientation.z;
    w = msg.orientation.w;
    EulerZYX = quat2eul([w x y z],"ZYX");
    fprintf('Quaternion:\n x: %f\n y: %f\n z: %f\n w: %f\n',x,y,z,w);
    fprintf('EulerZYX: %f %f %f\n',EulerZYX(1), EulerZYX(2), EulerZYX(3));
end

function motorStatusCallback(msg)
    left_leg1_pos = msg.position(1) ;
    left_leg2_pos = msg.position(2) ;
    left_leg3_pos = msg.position(3) ;
    left_leg4_pos = msg.position(4) ;
    
    right_leg1_pos = msg.position(5) ;
    right_leg2_pos = msg.position(6) ;
    right_leg3_pos = msg.position(7) ;
    right_leg4_pos = msg.position(8) ;

    fprintf('LeftMotorStatus:\n left_leg1_pos: %f\n left_leg2_pos: %f\n left_leg3_pos: %f\n left_leg4_pos: %f\n',left_leg1_pos,left_leg2_pos,left_leg3_pos,left_leg4_pos);
    fprintf('RightMotorStatus:\n right_leg1_pos: %f\n right_leg2_pos: %f\n right_leg3_pos: %f\n right_leg4_pos: %f\n',right_leg1_pos,right_leg2_pos,right_leg3_pos,right_leg4_pos);
end

function batteryLeftStatusCallback(msg)
    fprintf('Left Battery Percentage: %f%%\n', msg.percentage);
end

function batteryRightStatusCallback(msg)
    fprintf('Right Battery Percentage: %f%%\n', msg.percentage);
end
