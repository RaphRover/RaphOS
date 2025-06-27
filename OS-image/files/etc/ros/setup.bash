# Source the ROS workspace
# source /opt/ros/jazzy/setup.bash
source /home/ibis/ros_ws/install/setup.bash

# Source aliases for systemd user services
source /etc/ros/aliases


### Robot Configuration

# Namespace of the robot
# Affects all node namespaces (except the controller node) and URDF link names
export ROBOT_NAMESPACE=""


### Start scripts variables

# Path to the launch file to start.
LAUNCH_FILE="/etc/ros/robot.launch.xml"

# Arguments passed to ros2 launch command
LAUNCH_ARGS=""

# Arguments passed to Micro-ROS agent
UROS_AGENT_ARGS="udp4 -d -p 8888"

# The ID of the discovery server.
DISCOVERY_SERVER_ID=0


### ROS Environment Variables

#export ROS_DOMAIN_ID=10
#export ROS_LOCALHOST_ONLY=1
export RCUTILS_COLORIZED_OUTPUT=1
export ROS_DISCOVERY_SERVER="127.0.0.1:11811"
export ROS_SUPER_CLIENT=true
export RMW_IMPLEMENTATION_WRAPPER=rmw_stats_shim
