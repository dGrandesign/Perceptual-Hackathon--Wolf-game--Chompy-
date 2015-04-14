import oscP5.*;    //OSC used to talk to Unity
import netP5.*;

import intel.pcsdk.*;  //Library for Intel gesture Camera

OscP5 oscP5;

NetAddress myBroadcastLocation;

boolean fingerTracking = true;
boolean handTracking = true;
short[] depthMap;

float[] pointPos = new float[8];
float jawOpenDist=0, jawOpenDist_raw=0;
int factor= 4;
float wolfPos_x= 0, wolfPos_y=0 ;

float jawOpenDist_mapped=0;
float wolfPos_xmapped= 0, wolfPos_ymapped=0 ;

int[] depth_size = new int[2];
int[] lm_size = new int[2];
ArrayList<PVector> mHandsPos = new ArrayList<PVector>();
ArrayList<PVector> mSectionsPos = new ArrayList<PVector>();


private static PImage display, depthImage;

PXCUPipeline session;
PXCMGesture.GeoNode mNode;

int[] mHands = {
  PXCMGesture.GeoNode.LABEL_BODY_HAND_PRIMARY, PXCMGesture.GeoNode.LABEL_BODY_HAND_SECONDARY
};

int[] mSections = {
  PXCMGesture.GeoNode.LABEL_HAND_FINGERTIP, 
  PXCMGesture.GeoNode.LABEL_HAND_UPPER, 
  PXCMGesture.GeoNode.LABEL_HAND_MIDDLE, 
  PXCMGesture.GeoNode.LABEL_HAND_LOWER
};


void setup() {

  size(320, 240);

  /************* OSC Inititalization **************/

  session = new PXCUPipeline(this);

  oscP5 = new OscP5(this, 12000);

  myBroadcastLocation = new NetAddress("127.0.0.1", 8000);


  /**************** Camera session ****************/
  if (!session.Init(PXCUPipeline.GESTURE|PXCUPipeline.COLOR_VGA|PXCUPipeline.DEPTH_QVGA))
  {
    print("Failed to initialize\n");
    exit();
  }

  if (session.QueryDepthMapSize(lm_size))
    display = createImage(lm_size[0], lm_size[1], RGB);

  if (session.QueryDepthMapSize(depth_size)) {
    depthMap = new short[depth_size[0] * depth_size[1]];
    depthImage = createImage(depth_size[0], depth_size[1], ALPHA);
  }

  mNode = new PXCMGesture.GeoNode();
}

void draw() {

  background(0);

  if (session.AcquireFrame(false))
  {
    mHandsPos.clear();
    mSectionsPos.clear();
    // mFingersPos.clear();

    session.QueryLabelMapAsImage(display);

    //    if(session.QueryDepthMap(depthMap)){
    //      depthImage.loadPixels();
    //      
    //      for(int i=0; i< depth_size[0]*depth_size[1]; i++){
    //      
    //       depthImage.pixels[i] = color(map(depthMap[i],0,4000,0,255));
    //      
    //      }
    //      depthImage.updatePixels();
    //    
    //    }

    /********* Start hand tracking ***********************/
    if (session.QueryGeoNode(PXCMGesture.GeoNode.LABEL_BODY_HAND_PRIMARY|PXCMGesture.GeoNode.LABEL_MASK_DETAILS, mNode))
      mHandsPos.add(new PVector(mNode.positionImage.x, mNode.positionImage.y));

    if (handTracking) {

      for (int i=0; i<mHands.length; ++i) {

        for (int j=0; j<mSections.length; ++j) {
          if (session.QueryGeoNode(mHands[i]|mSections[j], mNode))
            mSectionsPos.add(new PVector(mNode.positionImage.x, mNode.positionImage.y));
        }
      }
    }


    session.ReleaseFrame();
  }

  image(display, 0, 0);


  pushStyle();
  for (int i=0; i<mSectionsPos.size (); ++i)
  {
    if (i<4) {
      println("i="+i);  
      PVector p = (PVector)mSectionsPos.get(i);
      noFill();
      stroke(255, 0, 0);
      strokeWeight(3);
      ellipse(p.x, p.y, 15, 15);
      // println(i);
      //println(p.x);
      //println(p.y);

      pointPos[2*i]= p.x;
      pointPos[2*i+1]= p.y;
    }
  }
  println("*****");
  //for(int i=0; i<8; ++i){
  //  
  //  println(pointPos[i]);
  //  
  //}

  /*********** Calculate Wolf's position (hand position) and how open its jaw is *************/ 
  wolfPos_x = wolfPos_x +(pointPos[4] - wolfPos_x)/factor;
  wolfPos_y = wolfPos_y +(pointPos[5] - wolfPos_y)/factor;
  println("Wolf pivot="+ wolfPos_x + "," + wolfPos_y);
  jawOpenDist_raw = dist(pointPos[2], pointPos[3], pointPos[6], pointPos[7]);
  jawOpenDist = jawOpenDist +(jawOpenDist_raw- jawOpenDist)/factor;  // Low pass FIR filter

  // x: -10 to 6
  // y: 0 to 5
  println("dist="+jawOpenDist);
  //println("-----------------");
  popStyle();

 //Map position values to Unity screen size
  wolfPos_xmapped= map((wolfPos_x), 0, 320, -10, 6);
  wolfPos_ymapped= map(wolfPos_y, 0, 240, 0, 5);

 /****** Send position data to Unity *******/
  OscMessage myOscMsg = new OscMessage((int)jawOpenDist);

  myOscMsg.add((int)wolfPos_xmapped);

  myOscMsg.add((int)wolfPos_ymapped);
  oscP5.send(myOscMsg, myBroadcastLocation);
}


