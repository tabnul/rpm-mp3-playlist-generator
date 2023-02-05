# rpm-mp3-playlist-generator
Script to generate audio playlists for RPM indoor cycling workouts

# Context
When the COVID pandemic started i had to quit the RPM indoor cycling workouts in the gym and bought my own spinning bike.
I needed a way to generate my own music playlists for the workout. 

The Les Mills RPM program always has the same setup for the workout (e.g. track 1 is for warming up, track 5 interval, track 6 sprinting).
The tracks/music style always matches the type of exercise during the workout.

I needed to increase the total workout time, increase focus on certain exercises and always have a unique set of tracks.

# Using the script
- Copy your audio files to a directory and make sure all tracks start with a number (1, 2, 3)
  (e.g. files starting with '1' would all be warming up tracks)
- fill in the parameters in the powershell file
- adjust the csv file to your needs. 
  This file defines how many of the track-types will be used, in my example track 1 will only be used once, but will always have 2 intervall and sprinting tracks (5 and 6)
- execute the script

The script will create seperate folders for your playlists.