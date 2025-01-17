0.2.2 (2025-01-17)
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
