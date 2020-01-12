Stats On Sight
This was a project developed at nwHacks 2020 with Arsh Ganda (@arshganda) and Sumeet Grewal (@sumeetgrewal). Find our full devpost article [here](https://devpost.com/software/stats-on-sight), and the repository to the back end app [here](https://github.com/arshganda/stats_on_sight).

## Inspiration
For our second time around at nwHacks, we wanted to be adventurous and try our hands at a new piece of tech -- augmented reality. We're all big sports guys and have this problem where we're watching a game at a bar without sound, sometimes far from the screen so we're not getting the usual stats from the announcers over the course of the game. With Stats on Sight we wanted to make live game statistics more digestible from our phones. 

## What it does
Stats on Sight uses your phone camera to capture a live NHL broadcast, determine which teams are playing from the screen and then it displays a variety of statistics in augmented reality around the screen.

## How we built it
We built an iOS app with **Swift** that identifies a vertical plane (the screen you're pointing at) with **ARKit**. Then, also with ARKit, we crop a rectangular image of the NHL game from the camera view and upload it to Google **Cloud Storage** via our **Node.js** API hosted with Google **App Engine**. 

We then pass the image through Google Cloud's **Vision AI** and identify which two teams are playing. Given the two team names we can pull live stats from the **NHL's public API** and return that to the client, displaying the stats in an **AR** dashboard.

## Challenges we ran into
ARKit was entirely new to our team. The documentation was really poor and hard to navigate which made it challenging to work with. We were also not expecting to be fooling around with 3D geometry or doing matrix transformations at 3 AM.  
  
At some point in the middle of the night, Google Vision AI was having a lot of trouble processing our images for some reason which stalled our progress. 

The most technically challenging part of this project was anchoring the stats that we wanted to render with ARKit to the actual laptop screen. The reason this was hard was because the "anchor" that we attach our AR stats to is the live-broadcasted game which is constantly changing.

## Accomplishments that we're proud of
- How quickly and easily we were able to deploy our services to Google Cloud
- Figuring out how to piece ARKit together

## What we learned
- How to store data in Google Cloud Storage and access bucket data
- Re-learned everything we had forgotten from linear algebra class
- How to navigate new technology as we did with ARKit

## What's next for Stats on Sight
Its evolution into a cool party trick to show friends.

