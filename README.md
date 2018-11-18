# FlyBuy

## What it does
The FlyBuy app performs fully automatic inventory checking in a supermarket using an unmanned, autonomous aerial vehicle. 
The system is able to perform every task in this process without the need for a human operator.


## How We built it
The system utilizes a positioning system that replaces GPS in an indoor scenario for flight path coordination.
Using QR codes that are mounted on the floor, the drone is able to accurately determine its position with a precision of around 3cm in each horizontal direction.
The drone uses its positional information to follow a predetermined flight path around the shelves in the supermarket and to take pictures of products in regular intervals. 
The products are recognized using a InceptionV3 based deep convolutional neural network.
The system also scans the barcode that is mounted below the product.
It is checked, whether barcode and recognized product match and in case of a mismatch, a human is notified, who will resolve this issue.


## Challenges we ran into
- The dataset provided by Kaufland left a lot to be desired regarding size and variation
- DJI Mobile SDK unexpectedly ignored flight commands
- It was not possible to scan the provided barcodes reliably


## What's next for FlyBuy
Other vehicles could be explored instead of a drone. While drones are easily accessible for a hackathon, in a real world scenario it may be more suitable to use a robot that drives on wheels, as noise and the risk of collisions is significantly reduced.
