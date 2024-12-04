%% Set environment and initialize node
% setenv("ROS_DOMAIN_ID", "42");% use your DOMIAN_ID to replace 42
run get_tita_namespace.m ;

matlab_tita_teleop_node = ros2node("/matlab_tita_teleop_node");
pause(3) % Ensure connection is established
%%
global key_input ;
key_input = '';

% Keyboard listener for teleoperation
clc;
fprintf('Teleop start now!\n');
disp('you can press Esc to exit the teleop control node');
keyboard_listener_fig = figure('KeyPressFcn', @(src, event) keyboardListener(src, event));
set(keyboard_listener_fig, 'Name', 'Teleop Control', 'NumberTitle', 'off');
text_handle = text(0.5, 0.5, '', 'HorizontalAlignment', 'center', 'FontSize', 10,'Interpreter', 'none');
axis off;

% Control message structure
ctrlMsgs = initializeMotionCtrlMsg();
tita_ctrl_topic = ['/',tita_namespace,'/command/user/command'];
TITACmdPub = ros2publisher(matlab_tita_teleop_node,tita_ctrl_topic,"tita_locomotion_interfaces/LocomotionCmd");

% rad 
global pitch_cmd roll_cmd
pitch_cmd = 0.0;
roll_cmd = 0.0;

%% Main loop
while true
    if ~isempty(key_input)
        key = key_input;
        disp(key);
        if key == "escape"
            break;  % Exit the loop
        else
            ctrlMsgs = generateMsgs(ctrlMsgs, key);
            send(TITACmdPub, ctrlMsgs);  % Publish the message
            key_input = '';
        end
    else
        % Default message when no key pressed
        ctrlMsgs.twist.linear.x = 0.0 ;
        ctrlMsgs.twist.angular.z = 0.0 ;
        send(TITACmdPub, ctrlMsgs);
    end
    msg_str = struct2str(ctrlMsgs); 
    set(text_handle, 'String', msg_str); 
    pause(0.04);  % 40 ms sleep
end

fprintf('exit!\n');
clear TITACmdPub matlab_tita_teleop_node

%% Keyboard listener
function keyboardListener(src, event)
    global key_input ;
    key_input= event.Key;
    if src == gcf
        if strcmp(event.Key, 'escape')
            disp('press Esc, exit the teleop control node...');
            close(src);  % Close figure window
        end
    end
end

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
    global pitch_cmd roll_cmd
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
            roll_cmd = 0.1;
        case 'q'
            roll_cmd = -0.1;
        case 'r'
            roll_cmd = 0.0;
        case 'h'
            ctrlMsgs.pose.position.z = 0.0;
        case 'j'
            ctrlMsgs.pose.position.z = 0.3;
        case 'k'
            ctrlMsgs.pose.position.z = 0.15;
        case 'u'
            pitch_cmd = 0.5;
        case 'i'
            pitch_cmd = 0.0;
        case 'o'
            pitch_cmd = -0.5;
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
    orientastion_cmd = eul2quat([0.0 pitch_cmd roll_cmd],'ZYX');
    ctrlMsgs.pose.orientation.w = orientastion_cmd(1);
    ctrlMsgs.pose.orientation.x = orientastion_cmd(2);
    ctrlMsgs.pose.orientation.y = orientastion_cmd(3);
    ctrlMsgs.pose.orientation.z = orientastion_cmd(4);
end

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