# source /opt/ros/jazzy/setup.bash
source /home/ibis/ros_ws/install/setup.bash

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
UROS_AGENT_ARGS="upd4 -d -p 8888"


### ROS Environment Variables

#export ROS_DOMAIN_ID=10
#export ROS_LOCALHOST_ONLY=1
export RCUTILS_COLORIZED_OUTPUT=1