import java.awt.Frame;
import java.awt.BorderLayout;
import javax.swing.JOptionPane;
import controlP5.*; // http://www.sojamo.de/libraries/controlP5/
import processing.serial.*;

// Colors
color bgColor = color(10, 10, 10);
color bgColor2 = color(27, 27, 28);
color fgColor = color(230, 230, 230);

color xColor = color(235, 75, 75);
color yColor = color(26, 255, 0);
color zColor = color(71, 187, 245);
color defaultColor = color(255, 184, 54);

color[] graphColors = {xColor, yColor, zColor};

// Interface
ControlP5 cp5;
PImage logo;

Graph oriGraph = new Graph(1900 - 275, 130 + 30, 260, 140, fgColor);
Graph accelGraph = new Graph(1900 - 275, 350 + 30, 260, 140, fgColor);;
Graph gyroGraph = new Graph(1900 - 275, 570 + 30, 260, 140, fgColor);;
Graph altitudeGraph = new Graph(1900 - 275, 790 + 30, 260, 140, fgColor);;
Graph velocityGraph = new Graph(60, 165 + (3*230 + 15), 260, 90, fgColor);;

// Datas
int dataSeconds = 5;
int dataHz = 15;
float[] dataSamples = new float[dataSeconds * dataHz];

float[][] oriValues = new float[3][dataSamples.length];
float oriMax = 0;
float oriMin = 0;

float[][] accelValues = new float[3][dataSamples.length];
float accelMax = 0;
float accelMin = 0;

float[][] gyroValues = new float[3][dataSamples.length];
float gyroMax = 0;
float gyroMin = 0;

float[] altitudeValues = new float[dataSamples.length];
float altitudeMax = 0;
float altitudelMin = 0;

float[] velocityValues = new float[dataSamples.length];
float velocityMax = 0;
float velocityMin = 0;

// Current data
float oriX = 0;
float oriY = 0;
float oriZ = 0;
float accelX = 0;
float accelY = 0;
float accelZ = 0;
float gyroX = 0;
float gyroY = 0;
float gyroZ = 0;
float altitude = 0;
float tvcY = 0;
float tvcZ = 0;
float rollX = 0;
float altBias = 0;
float vX = 0;
float pressure = 0;
float imuTemp = 0;
float baroTemp = 0;
float battV = 0;
int state = 0;
int abort = 0;
int abortEn = 0;
float mass = 0;
int p1s = 0;
int p2s = 0;
int p3s = 0;
int p1c = 0;
int p2c = 0;
int p3c = 0;

float oldOnTimeSec = 0;
float onTimeSec = 0;
float flightTimeSec = 0;

// Data in
String COMt = "N/A";
String COMx = "N/A";
Serial inPort;

String data = "";

long nextUpdateMillis = 0;

PFont mainFont;
ControlFont buttonFont;

boolean running = true;

int buttonMargin = 190;
int buttonPadding = 30;

int buttonWidth = (1100 - (190) - (buttonPadding * 2)) / 3;
int buttonHeight = 150;

void chooseInput()
{
  COMt = COMx;
  if(inPort != null) inPort.stop();
  try {
    
    COMx = (String) JOptionPane.showInputDialog(null, 
    "Select COM Port", 
    "Select COM Port", 
    JOptionPane.QUESTION_MESSAGE, 
    null, 
    Serial.list(), 
    null
    );
     
    if (COMx == null || COMx.isEmpty()) COMx = COMt;
    
    if(COMx != "N/A")
    {
      inPort = new Serial(this, COMx, 115200); // change baud rate to your liking
      inPort.bufferUntil('\n'); // buffer until CR/LF appears, but not required..
    }
    
    nextUpdateMillis = millis();
  }
  catch (Exception e)
  { //Print the type of error
    JOptionPane.showMessageDialog(frame, "COM port " + COMx + " is not available.");
    println("Error:", e);
    COMx = "N/A";
  }
}

void enableLaunch(){
  if(!running || COMx == "N/A") return;
  if(state != 1) return;
  inPort.write("<LAUNCH_EN>\n");
}

void abortFlight(){
  if(!running || COMx == "N/A") return;
  if(state != 2) return;
  inPort.write("<ABORT>\n");
}

void togglePiston(){
  if(!running || COMx == "N/A") return;
  if(state != 1) return;
  inPort.write("<PISTON>\n");
}

void toggleCameras(){
  if(!running || COMx == "N/A") return;
  if(state != 1) return;
  inPort.write("<CAM>\n");
}

void setup()
{
  surface.setTitle("Telemetry Ground Station");
  surface.setResizable(true);
  size(1920, 1080);
  
  frameRate(60);
  
  // GUI
  mainFont = createFont("Arial Bold", 27);
  buttonFont = new ControlFont(mainFont);
  
  cp5 = new ControlP5(this);
  
  cp5.addButton("chooseInput")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 1, height - (buttonMargin + (buttonHeight + buttonPadding) * 2.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(0, 115, 255))
    .setColorForeground(color(0, 93, 207))
    .setColorActive(color(0, 93, 207))
    .setBroadcast(true)
    .setLabel("Choose Input")
    .getCaptionLabel()
    .setFont(mainFont);
  
  cp5.addButton("abortFlight")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 2, height - (buttonMargin + (buttonHeight + buttonPadding) * 2.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(255, 8, 8))
    .setColorForeground(color(189, 4, 4))
    .setColorActive(color(189, 4, 4))
    .setBroadcast(true)
    .setLabel("ABORT FLIGHT")
    .getCaptionLabel()
    .setFont(mainFont);
  
  cp5.addButton("togglePiston")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 3, height - (buttonMargin + (buttonHeight + buttonPadding) * 2.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(134, 179, 0))
    .setColorForeground(color(96, 128, 0))
    .setColorActive(color(96, 128, 0))
    .setBroadcast(true)
    .setLabel("Toggle Piston")
    .getCaptionLabel()
    .setFont(mainFont);
  
  cp5.addButton("toggleCameras")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 1, height - (buttonMargin + (buttonHeight + buttonPadding) * 1.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(252, 148, 3))
    .setColorForeground(color(217, 127, 2))
    .setColorActive(color(217, 127, 2))
    .setBroadcast(true)
    .setLabel("Toggle Cameras")
    .getCaptionLabel()
    .setFont(mainFont);
  
  cp5.addButton("enableLaunch")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 2, height - (buttonMargin + (buttonHeight + buttonPadding) * 1.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(97, 48, 166))
    .setColorForeground(color(74, 36, 128))
    .setColorActive(color(74, 36, 128))
    .setBroadcast(true)
    .setLabel("Enable Launch")
    .getCaptionLabel()
    .setFont(mainFont);
  
  cp5.addButton("reserved6")
    .setBroadcast(false)
    .setPosition(buttonMargin + (buttonWidth + buttonPadding) * 3, height - (buttonMargin + (buttonHeight + buttonPadding) * 1.5 - buttonPadding))
    .setSize(buttonWidth, buttonHeight)
    .setColorBackground(color(80))
    .setColorForeground(color(100))
    .setColorActive(color(100))
    .setBroadcast(true)
    .setLabel("N/A")
    .getCaptionLabel()
    .setFont(mainFont);
  
  logo = loadImage("logo.png");
  logo.resize(logo.width * (80 / logo.height), 80);
  
  // Graphs
  oriGraph.xLabel = "";
  oriGraph.yLabel = "";
  oriGraph.Title = "";
  oriGraph.xMin = -dataSeconds;
  oriGraph.xMax = 0;
  oriGraph.xDiv = dataSeconds;
  
  accelGraph.xLabel = "";
  accelGraph.yLabel = "";
  accelGraph.Title = "";
  accelGraph.xMin = -dataSeconds;
  accelGraph.xMax = 0;
  accelGraph.xDiv = dataSeconds;
  
  gyroGraph.xLabel = "";
  gyroGraph.yLabel = "";
  gyroGraph.Title = "";
  gyroGraph.xMin = -dataSeconds;
  gyroGraph.xMax = 0;
  gyroGraph.xDiv = dataSeconds;
  
  altitudeGraph.xLabel = "";
  altitudeGraph.yLabel = "";
  altitudeGraph.Title = "";
  altitudeGraph.xMin = -dataSeconds;
  altitudeGraph.xMax = 0;
  altitudeGraph.xDiv = dataSeconds;
  
  velocityGraph.xLabel = "";
  velocityGraph.yLabel = "";
  velocityGraph.Title = "";
  velocityGraph.xMin = -dataSeconds;
  velocityGraph.xMax = 0;
  velocityGraph.xDiv = dataSeconds;
  
  clearGraphs();
}

void draw()
{
  background(bgColor);
  
  // New data
  if(COMx != "N/A")
  {
    while(inPort.available() > 0)
    {
      char in = inPort.readChar();
      
      if(in == '\n')
      {
        if(running) parseData(data);
        data = "";
        
      }
      else
      {
        data += in;
      }
    }
  }
  checkData();
  
  image(logo, 10, 20);
  
  // Draw spacing rectangles
  stroke(fgColor);
  strokeWeight(2);
  fill(bgColor2);
  rect(logo.width + 30, -10, width + 10, 120, 10);
  for(int y = 0; y < 4; y++)
  {
    rect(width - (345), 130 + (y * 220), 320 + 20 - 1, 200 - 1, 10);
  }
  
  rect(10, 130 + (3*230 + 15), 320 + 20 - 1, 200 - 46, 10);
  rect(10, 130, 320 + 20 - 1, 199/2 + 40, 10);
  rect(10, 130 + 160, 320 + 20 - 1, 420 + 102, 10);
  
  // Draw titles
  fill(fgColor);
  textSize(20);
  textAlign(CENTER, TOP);
  
  text("Orientation",    width - (340 / 2), 20 + 110 + 5);
  text("Accelerometers", width - (340 / 2), 240 + 110 + 5);
  text("Gyroscopes",     width - (340 / 2), 460 + 110 + 5);
  text("Altitude",       width - (340 / 2), 680 + 110 + 5);
  text("Vertical Velocity",       175, 680 + 150 + 10);
  
  textSize(25);
  text("Attitude Control",     175, 140);
  text("Raw Telemetry Data",       175, 305);
  
  textAlign(LEFT, CENTER);
  textSize(31);
  
  text("VOT: " + nf((int(onTimeSec) % 86400 ) / 3600, 2) + ":" + nf(((int(onTimeSec) % 86400 ) % 3600 ) / 60, 2) + ":" + nf(((int(onTimeSec) % 86400 ) % 3600 ) % 60, 2), 1005, 51);
  text("MET: " + nf((int(flightTimeSec) % 86400 ) / 3600, 2) + ":" + nf(((int(flightTimeSec) % 86400 ) % 3600 ) / 60, 2) + ":" + nf(((int(flightTimeSec) % 86400 ) % 3600 ) % 60, 2), 1290, 51);
  text("Date: " + nf(month(), 2) + "." + nf(day(), 2) + "." + year(), 400, 51);
  text("Local: " + nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2), 720, 51);
  
  textSize(20);
  textAlign(CENTER, BOTTOM);
  
  drawState();
  
  float[] minMaxOri = minMaxValue2D(oriValues);
  oriGraph.yMin = min(minMaxOri[0], -1); // - (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  oriGraph.yMax = max(minMaxOri[1], 1); // + (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  
  float[] minMaxAccel = minMaxValue2D(accelValues);
  accelGraph.yMin = min(minMaxAccel[0], -1); // - (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  accelGraph.yMax = max(minMaxAccel[1], 1); // + (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  
  float[] minMaxGyro = minMaxValue2D(gyroValues);
  gyroGraph.yMin = min(minMaxGyro[0], -1); // - (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  gyroGraph.yMax = max(minMaxGyro[1], 1); // + (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  
  float[] minMaxAltitude = {min(altitudeValues), max(altitudeValues)};
  altitudeGraph.yMin = min(minMaxAltitude[0], 0); // - (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  altitudeGraph.yMax = max(minMaxAltitude[1], 1); // + (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  
  float[] minMaxVelocity = {min(velocityValues), max(velocityValues)};
  velocityGraph.yMin = min(minMaxVelocity[0], -1); // - (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  velocityGraph.yMax = max(minMaxVelocity[1], 1); // + (abs(minMaxAccel[1] - minMaxAccel[0]) / 10);
  
  oriGraph.DrawAxis();
  accelGraph.DrawAxis();
  gyroGraph.DrawAxis();
  altitudeGraph.DrawAxis();
  velocityGraph.DrawAxis();
  for(int i = 0; i < 3; i++)
  {
    oriGraph.GraphColor = graphColors[i];
    accelGraph.GraphColor = graphColors[i];
    gyroGraph.GraphColor = graphColors[i];
    
    oriGraph.LineGraph(dataSamples, oriValues[i]);
    accelGraph.LineGraph(dataSamples, accelValues[i]);
    gyroGraph.LineGraph(dataSamples, gyroValues[i]);
  }
  altitudeGraph.GraphColor = defaultColor;
  altitudeGraph.LineGraph(dataSamples, altitudeValues);
  velocityGraph.GraphColor = defaultColor;
  velocityGraph.LineGraph(dataSamples, velocityValues);
  
  // Raw telem values
  noStroke();
  fill(fgColor);
  textAlign(LEFT, CENTER);
  textSize(15);
  text("oX:  " + nf(oriX, 0, 2), 40, 360);
  text("oY:  " + nf(oriY, 0, 2), 40, 390);
  text("oZ:  " + nf(oriZ, 0, 2), 40, 420);
  
  text("aX:  " + nf(accelX, 0, 2), 40, 450);
  text("aY:  " + nf(accelY, 0, 2), 40, 480);
  text("aZ:  " + nf(accelZ, 0, 2), 40, 510);
  
  text("gX:  " + nf(gyroX, 0, 2), 40, 540);
  text("gY:  " + nf(gyroY, 0, 2), 40, 570);
  text("gZ:  " + nf(gyroZ, 0, 2), 40, 600);
  
  text("alt:  " + nf(altitude, 0, 2), 40, 630);
  
  text("altBias:  " + nf(altBias, 0, 2), 40, 660);
  
  text("vX:  " + nf(vX, 0, 2), 40, 690);
  
  text("p:  " + nf(pressure, 0, 2), 40, 720);
  
  text("IMU T:  " + nf(imuTemp, 0, 2), 40, 750);
  text("baro T:  " + nf(baroTemp, 0, 2), 40, 780);
    
  text("state:  " + state, 200, 360);
  text("abort:  " + abort, 200, 390);
  text("AFTSEn:  " + abortEn, 200, 420);
  text("mass:  " + nf(mass, 0, 3), 200, 450);
  text("P1s:  " + p1s, 200, 480);
  text("P2s:  " + p2s, 200, 510);
  text("P3s:  " + p3s, 200, 540);
  text("P1c:  " + p1c, 200, 570);
  text("P2c:  " + p2c, 200, 600);
  text("P3c:  " + p3c, 200, 630);
  text("volts:  " + nf(battV, 0, 2), 200, 660);
  
  if((oldOnTimeSec - onTimeSec) == 0){
    text("TLM:  " + nf(0, 0, 2), 200, 690);
  } else {
    text("TLM:  " + nf(1 / (onTimeSec - oldOnTimeSec), 0, 2), 200, 690);
  }
  
  text("TLM Δ:  " + nf(onTimeSec - oldOnTimeSec, 0, 3), 200, 720);
   
  textAlign(RIGHT, CENTER);
  text("°", 170, 360);
  text("°", 170, 390);
  text("°", 170, 420);
  text("m/s²", 170, 450);
  text("m/s²", 170, 480);
  text("m/s²", 170, 510);
  text("°/s", 170, 540);
  text("°/s", 170, 570);
  text("°/s", 170, 600);
  text("m", 170, 630);
  text("m", 170, 660);
  text("m/s", 170, 690);
  text("hPa", 170, 720);
  text("°C", 170, 750);
  text("°C", 170, 780);
  
  text("kg", 330, 450);
  text("V", 330, 660);
  text("Hz", 330, 690);
  text("s", 330, 720);
  
  textAlign(LEFT, CENTER);
  textSize(18);

  text("TVC Y: " + nf(tvcY, 0, 2) + "°", 40, 200);
  text("TVC Z: " + nf(tvcZ, 0, 2) + "°", 200, 200);
  text("RW X: " + nf(rollX, 0, 2), 40, 230);
  
  if(state == 3){
    text("TWR: " + nf((mass * accelX) / (mass * 9.81), 0, 2), 200, 230);
  } else {
    text("TWR: " + nf(0, 0, 2), 200, 230);
  }
}

void drawState()
{
  color stateColor;
  String stateString;
  
  switch(state)
  {
    case 1:
      stateColor = color(51, 137, 242);
      stateString = "Ground Idle";
      break;
    case 2:
      stateColor = color(68, 184, 81);
      stateString = "Ready For Launch";
      break;
    case 3:
      stateColor = color(242, 140, 51);
      stateString = "Powered Ascent";
      break;
    case 4:
      stateColor = color(9, 183, 222);
      stateString = "Unpowered Ascent";
      break;
    case 5:
      stateColor = color(190, 109, 207);
      stateString = "Freefall Descent";
      break;
    case 6:
      stateColor = color(230, 222, 7);
      stateString = "Parachute Descent";
      break;
    case 7:
      stateColor = color(16, 224, 214);
      stateString = "Landing Detection";
      break;
    case 8:
      stateColor = color(68, 184, 81);
      stateString = "Mission Complete";
      break;
    default:
      stateColor = color(217, 15, 15);
      stateString = "Invalid State";
      break;
  }
  
  fill(stateColor);
  noStroke();
  textAlign(CENTER, CENTER);
  rect(width - 315 - 10, 20, 300, 70, 10);
  textSize(30);
  fill(255);
  text(stateString, width - 165 - 10, 51);
}

float[] minMaxValue2D(float[][] input)
{
  float[] minMax = {0, 0};
  
  for(int i = 0; i < input.length; i++)
  {
    for(int j = 0; j < input[i].length; j++)
    {
      minMax[0] = min(minMax[0], input[i][j]);
      minMax[1] = max(minMax[1], input[i][j]);
    }
  }
  
  return minMax;
}

void checkData()
{
  if(!running || COMx == "N/A") return;
  if(millis() > nextUpdateMillis)
  {
    // Rotate arrays
    for(int j = 0; j < 3; j++)
    {
      for(int i = 0; i < dataSamples.length - 1; i++)
      {
        oriValues[j][i] = oriValues[j][i + 1];
        accelValues[j][i] = accelValues[j][i + 1];
        gyroValues[j][i] = gyroValues[j][i + 1];
        if(j == 0) // Hacky way to do this once
        {
          altitudeValues[i] = altitudeValues[i + 1];
          velocityValues[i] = velocityValues[i + 1];
        }
      }
    }
    
    oriValues[0][dataSamples.length - 1] = oriX;
    oriValues[1][dataSamples.length - 1] = oriY;
    oriValues[2][dataSamples.length - 1] = oriZ;
    
    accelValues[0][dataSamples.length - 1] = accelX;
    accelValues[1][dataSamples.length - 1] = accelY;
    accelValues[2][dataSamples.length - 1] = accelZ;
    
    gyroValues[0][dataSamples.length - 1] = gyroX;
    gyroValues[1][dataSamples.length - 1] = gyroY;
    gyroValues[2][dataSamples.length - 1] = gyroZ;
    
    altitudeValues[dataSamples.length - 1] = altitude;
    velocityValues[dataSamples.length - 1] = vX;
    
    nextUpdateMillis += 1000 / dataHz;
  }
}

int parseData(String data)
{
  // Check data is good
  if(data.length() == 0) return -1;
  if(data.charAt(0) != 'T' || data.charAt(1) != 'L' || data.charAt(2) != 'M') return -1;

  String[] dataBits = split(data.substring(3), ',');

  if(dataBits.length != 31) return -1;
  
  oldOnTimeSec = onTimeSec;

  oriX = parseFloat(dataBits[0]);
  oriY = parseFloat(dataBits[1]);
  oriZ = parseFloat(dataBits[2]);
  accelX = parseFloat(dataBits[3]);
  accelY = parseFloat(dataBits[4]);
  accelZ = parseFloat(dataBits[5]);
  gyroX = parseFloat(dataBits[6]);
  gyroY = parseFloat(dataBits[7]);
  gyroZ = parseFloat(dataBits[8]);
  altitude = parseFloat(dataBits[9]);
  tvcY = parseFloat(dataBits[10]);
  tvcZ = parseFloat(dataBits[11]);
  rollX = parseFloat(dataBits[12]);
  altBias = parseFloat(dataBits[13]);
  vX = parseFloat(dataBits[14]);
  pressure = parseFloat(dataBits[15]);
  imuTemp = parseFloat(dataBits[16]);
  baroTemp = parseFloat(dataBits[17]);
  battV = parseFloat(dataBits[18]);
  state = parseInt(dataBits[19]);
  abort = parseInt(dataBits[20]);
  abortEn = parseInt(dataBits[21]);
  mass = parseFloat(dataBits[22]);
  p1s = parseInt(dataBits[23]);
  p2s = parseInt(dataBits[24]);
  p3s = parseInt(dataBits[25]);
  p1c = parseInt(dataBits[26]);
  p2c = parseInt(dataBits[27]);
  p3c = parseInt(dataBits[28]);
  onTimeSec = parseFloat(dataBits[29]);
  flightTimeSec = parseFloat(dataBits[30]);
  
  return 0;
}

void startSerial()
{
  if(COMx != "N/A")
  {
    running = true;
    nextUpdateMillis = millis();
  }
}

void clearGraphs()
{
  for(int i = 0; i < dataSamples.length; i++)
  {
    dataSamples[i] = ((float)i / dataHz);
    
    for(int j = 0; j < 3; j++)
    {
      oriValues[j][i] = 0;
      accelValues[j][i] = 0;
      gyroValues[j][i] = 0;
    }
    
    altitudeValues[i] = 0;
    velocityValues[i] = 0;
  }
}
