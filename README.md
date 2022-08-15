# Create a 3D model of an interior room by guiding the user through an AR experience
Adapted example of Roomkit: to augment the scanning experience, it shows labels for object category and provides auditory feedback.

Highlight physical structures and display text that guides a user to scan the shape of their physical environment using a framework-provided view. 


## Overview

- Note: This adapted sample code project is associated with WWDC22 session [10127: Create parametric 3D room scans with RoomPlan](https://developer.apple.com/wwdc22/10127).
- Note: Furthermore, there are some adaptations due to the incorrect behaviour of iOS 14 since beta 4

## Configure the sample code project

Set the run destination to an iOS 16 device with a LiDAR Scanner. This sample app requires augmented reality so it doesn't support Simulator. 
