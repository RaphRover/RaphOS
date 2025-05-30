0.5.0
-----------
* New button mapping for the Steam Deck controller.
    * L1 is no longer gimbal deadmans' switch. Instead, it switches between driving mode and gimbal mode. In Gimbal mode left joystick serves as steering for the gimbal, in Driving mode left joystick serves as forward and reverse for the robot.
    * R2 now triggers photos - in gimbal mode it triggers only Sony ILX photo, in driving mode it triggers photos with all cameras.
* Auto switch between "Centerline view" and "Gimbal control" sidebar modes when switching between driving and gimbal modes.
* Fixed an issue with infinite loading toasts when clicking a button for homing the gimbal.
* Limited number of toasts displayed in the WebUI to 7 at a time.
* Added "Dismiss all toasts" button to the Service menu.
* Reversed IMU roll and pitch axes in the WebUI to adhere to the right-hand rule convention.
* Updated system packages to the latest versions.

0.4.1
-----------
* Moved Insta camera position in URDF 90mm up the Z axis.
* Fixed IMU orientation in URDF (was rotated 180 degrees around the Z axis).
* Fixed a bug in Sony Cr Wrapper which leaked memory on each photo taken and caused it to freeze after >100 photos.
* Updated UI favicon.

0.4.0
-----------
* Revised blade side labeling for the Sony and Oak cameras to follow the new specification.
* Fixed an issue which resulted in data not being recorded to bag files while the insta360 photos were being processed.
* Added current LED settings and gimbal encoder data to recorded bags and inspection files.
* Added a filter that removes some of the "phantom" lidar points that are reflected from the lidar cage.
* Added input field for setting arbitrary values for control manager distance in the `Settings` panel. Also increased max value on the slider to 1.5m.
* Added beacon status monitoring. The WebUI will now display a notification when the beacon stops measuring distance and a warning will pop out when trying to start inspection when beacon is not working.
* Added an option to set manual aperture (F-Number) for the Sony camera. This can be set in the `Settings` panel in the WebUI. The slider allows choosing values from standard full-stop f-number scale. The input field allows putting arbitrary values (useful for lens supporting one-half-stop, one-third-stop, etc.).
* Added "Reboot gimbal" button to service menu.
* Some stability fixes to Beacon wrapper and Led wrapper nodes.

0.3.0
-----------
* The bootstrapper will now display the OS flashing procedure status using bottom LED panels. The 3 displayed states include:

    1. Left and right panels blinking alternately - the flashing procedure will start in 5 seconds.
    2. Both panels breathing - the flashing procedure is in progress.
    3. Both panels blinking in short bursts - the flashing procedure has finished, unplug the USB drive.
* The user can no longer take photos if the inspection is stopped, unless they toggle the debug mode (available through the service menu). This is to prevent the user from accidentally running the inspection without first starting it.
* The automatic photo mode now has an option to trigger photos from the Sony camera (disabled by default).
* Added `Roll` and `Tilt` angle feedback to the `Gimbal control` display.
* Added preview stream feature for the Insta360 camera. The preview stream is disabled by default and can be enabled in the `Settings` panel in the WebUI. After enabling, a new stream should appear in the `Stream selection` dropdown. **WARNING**: The preview stream is an experimental feature and may cause the camera to crash. Moreover, it WILL cause the picture taking to be slower while enabled.
* Added a feature to manually trigger Sony camera focus without taking a picture. This can be done by pressing the `Sony focus` button, which is visible when the sidebar is set to `Gimbal control` mode. **WARNING**: Not tested with the Sony camera, may not work as expected.
* Added runtime parameter for EV (Exposure Value) bias for the Insta360 camera. This can be set in the `Settings` panel in the WebUI.
* The "Reboot" and "Power Off" buttons in the WebUI now work (they don't power off the whole robot, just the onboard computer).
* While manually triggering photos from multiple cameras, the requests are now sent in parallel instead of sequentially.
* Fixed a bug which caused the gimbal to not stop moving after releasing the deadman switch.
* The list of topics in the `Stream selection` dropdown is now automatically refreshed every 3 seconds.
* Inspection status no longer displays "stopped" before retrieving the status from the rover.
* The radio buttons in the data collection menu can now be clicked on the text as well as the radio button itself. This should make it easier to operate from a touch screen.
* The menu drawer in the WebUI has been reworked.
* Updated the Steam Deck mapping illustration.
* Included newer SDK version for the Insta360 camera which might improve the camera's stability and performance.
* The current OS version is now included in the MOTD (message of the day) displayed upon SSH login.
* Some small stability and error logging improvements.

0.2.2 (2025-01-17)
------------------
* Fixed an issue with missing external disk mountpoint directory.

0.2.1 (2025-01-16)
------------------
* The JPG filenames in the output inspections are now prefixed with the camera output name and the number of seconds since epoch.
* Previously for the external disk to be mounted, the disk had to have the first partition formatted as exFAT. Now the exFat partition can be the first OR the second patition on the disk. This should make it work with the stock partition layout of the Lexar disk.

0.2.0 (2025-01-15)
------------------
* Sony camera image file type is now automatically set to JPEG upon connection. No longer need to manually set it on every camera.
* Insta360 camera capture settings (white balance, saturation, contrast, brightness, sharpness) and exposure settings are automatically set to default values upon connection. No longer need to manually set them on every camera.
* Automatic photo capture feature can now take pictures from the Oak cameras as well as the Insta360 camera. The WebUI allows setting which cameras to take pictures from in the `Config settings` panel. By default both Insta360 and Oak cameras are enabled.
* Added more error handling to start inspection procedure. Starting inspection will now fail if the disk is not mounted or the inspection manager fails to create directories for bag and inspection data. 
* Fixed an issue with external drive sporadically failing to mount upon boot.
* Added a "loading" toast to WebUI when stopping the inspection to indicate that the rover is still processing data.
* The logs directory is now hosted at http://10.10.0.2/logs/ . The WebUI includes buttons for accessing the whole directory as well as the file with the latest logs.
