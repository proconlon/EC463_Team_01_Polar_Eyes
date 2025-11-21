//
// Power Controller for Raspberry Pi (Nano Version)
// Dual Pulse Mode: Both Boot and Shutter are pulsed together (for now!!)
// - for turning on the Pi 4 and taking photos/videos

// - Every time we trigger (Video or Photo), we pulse BOTH:
//   1. Pin 3 (Shutter) -> Triggers the Python Listener
//   2. Pin 6 (Boot)    -> Ensures Pi is awake/resets watchdog

// ---------- Pin Assignments ----------
const int PIR_PIN        = A5; 
const int RADAR_GPIO_PIN = 4;  
const int RADAR_EN_PIN   = 7;


// --- PI INTERFACE ---
const int SHUTTER_PIN    = 3;   // Trigger Line (Active LOW)
const int PI_MODE_PIN    = 5;   // HIGH = Video, LOW = Photo
const int BOOT_PI_PIN    = 6;   // Safety Boot Line (Active LOW)


// LEDs
const int PIR_LED_PIN      = 8;  
const int RADAR_LED_PIN    = 9;  
const int CONFIRM_LED_PIN  = 13; 


// ---------- Configurable Parameters ----------
const float VREF = 5.0;
const float PIR_TRIGGER_VOLTAGE = 1.6;
const float PIR_CLEAR_VOLTAGE   = 1.3;


// Radar Logic
int   radarDebounceCounter       = 0;
const int radarDebounceThreshold = 5;          
const unsigned long radarPowerWindowMs = 5000UL;  


// -----------------------------------------------------------
// TIMING CONFIGURATION
// -----------------------------------------------------------


// 1. SHUTTER DEBOUNCE (Safety Lockout)
const unsigned long piTriggerDebounceMs = 45000UL;  


// 2. PHOTO INTERVAL: 3 Minutes (180s)
const unsigned long photoIntervalMs  = 90000UL;  


unsigned long lastTriggerTimestamp   = 0;
unsigned long lastPhotoWakeTime      = 0;


// Boot State Tracker
bool hasPerformedBoot = false;


// ---------- State Variables ----------
bool pirDetected       = false;  
bool pirDetectedPrev   = false;  
bool radarPowerOn      = false;  
unsigned long radarPowerStartTime = 0;
bool radarRawDetected        = false;
bool radarDetectedDebounced  = false;
bool presenceConfirmed         = false;


// 0 = none, 1 = video, 2 = photo
const int PI_MODE_NONE  = 0;
const int PI_MODE_VIDEO = 1;
const int PI_MODE_PHOTO = 2;
int lastTriggerMode = PI_MODE_NONE;




// ===============================================================
// Helper: Check Debounce
// ===============================================================
bool canTriggerPi(unsigned long now) {
 if (lastTriggerTimestamp == 0) return true;
 return (now - lastTriggerTimestamp) >= piTriggerDebounceMs;
}


// ===============================================================
// Send DUAL Pulse (Pin 3 AND Pin 6)
// ===============================================================
void sendDualPulse() {
 // 1. Configure both as OUTPUT
 pinMode(SHUTTER_PIN, OUTPUT);
 pinMode(BOOT_PI_PIN, OUTPUT);
  // 2. Drive both LOW simultaneously
 digitalWrite(SHUTTER_PIN, LOW);
 digitalWrite(BOOT_PI_PIN, LOW);
  // 3. Hold
 delay(200);                   
  // 4. Release both (High-Z)
 pinMode(SHUTTER_PIN, INPUT);
 pinMode(BOOT_PI_PIN, INPUT);
}


// ===============================================================
// Helper: Trigger VIDEO
// ===============================================================
bool triggerVideo(unsigned long now) {
 if (!canTriggerPi(now)) return false;


 digitalWrite(PI_MODE_PIN, HIGH); // Video Mode
  // Sends both pulses
 sendDualPulse();


 lastTriggerTimestamp = now;      
 lastTriggerMode      = PI_MODE_VIDEO;
 lastPhotoWakeTime   = now;


 Serial.println(">> DUAL PULSE SENT (VIDEO Mode)");
 return true;
}


// ===============================================================
// Helper: Trigger PHOTO
// ===============================================================
bool triggerPhoto(unsigned long now) {
 if (!canTriggerPi(now)) return false;


 digitalWrite(PI_MODE_PIN, LOW); // Photo Mode
  // Now sends both pulses
 sendDualPulse();


 lastTriggerTimestamp = now;     
 lastTriggerMode      = PI_MODE_PHOTO;
 lastPhotoWakeTime    = now;


 Serial.println(">> DUAL PULSE SENT (PHOTO Mode)");
 return true;
}


// ===============================================================
// Setup
// ===============================================================
void setup() {
 Serial.begin(9600);


 pinMode(RADAR_GPIO_PIN, INPUT);  
 pinMode(RADAR_EN_PIN, OUTPUT);


 // --- PI PINS ---
 pinMode(SHUTTER_PIN, INPUT);    
 pinMode(BOOT_PI_PIN, INPUT);    
  pinMode(PI_MODE_PIN, OUTPUT);
 digitalWrite(PI_MODE_PIN, LOW); 


 pinMode(PIR_LED_PIN, OUTPUT);
 pinMode(RADAR_LED_PIN, OUTPUT);
 pinMode(CONFIRM_LED_PIN, OUTPUT);


 digitalWrite(RADAR_EN_PIN, LOW); 


 Serial.println("System: Pi Controller (Dual Pulse Mode)");
 Serial.println("Cols: PIR_Raw PIR_V PIR_Detected Radar_Powered "
                "Radar_Raw Radar_Debounced Presence_Confirmed "
                "BootPulse_Sent Shutter_Sent Trigger_Mode Debounce_s NextPhoto_s");
 Serial.println("------------------------------------------------------------");
  lastPhotoWakeTime = millis();
}


// ===============================================================
// Main Loop
// ===============================================================
void loop() {
 unsigned long now = millis();
  // Momentary Debug Variables
 bool bootPulseSentNow = false;
 bool shutterSentNow   = false;


 // 1. SAFETY BOOT SEQUENCE (Runs Once)
 if (!hasPerformedBoot) {
   Serial.println(">> PERFORMING INITIAL SAFETY BOOT SEQUENCE...");
  
   // We use the Dual Pulse here too for consistency
   digitalWrite(PI_MODE_PIN, LOW); // Default to Photo Mode
   delay(100);
   sendDualPulse();
  
   bootPulseSentNow = true;
   shutterSentNow   = true;


   hasPerformedBoot = true;
   lastTriggerTimestamp = now;
   lastPhotoWakeTime = now;
 }


 // 2. Calculate Timers
 unsigned long debounceRemainingMs = 0;
 if (lastTriggerTimestamp != 0) {
   unsigned long timeSinceLast = now - lastTriggerTimestamp;
   if (timeSinceLast < piTriggerDebounceMs) {
     debounceRemainingMs = piTriggerDebounceMs - timeSinceLast;
   }
 }
 bool triggersAllowed = (debounceRemainingMs == 0);


 unsigned long photoTimerRemainingMs = 0;
 unsigned long timeSinceLastPhoto = now - lastPhotoWakeTime;
 if (timeSinceLastPhoto < photoIntervalMs) {
   photoTimerRemainingMs = photoIntervalMs - timeSinceLastPhoto;
 }


 // 3. PIR Reading
 int   pirRawValue = analogRead(PIR_PIN);
 float pirVoltage  = (pirRawValue / 1023.0) * VREF;
 if (!pirDetected && pirVoltage > PIR_TRIGGER_VOLTAGE) pirDetected = true;
 else if (pirDetected && pirVoltage < PIR_CLEAR_VOLTAGE) pirDetected = false;


 bool pirRisingEdge = (!pirDetectedPrev && pirDetected);
 pirDetectedPrev = pirDetected;


 // 4. Radar Window
 if (pirRisingEdge) {
   radarPowerOn = true;
   radarPowerStartTime = now;
   radarDebounceCounter = 0;
   digitalWrite(RADAR_EN_PIN, HIGH);
 }
 if (radarPowerOn && (now - radarPowerStartTime >= radarPowerWindowMs)) {
   radarPowerOn = false;
   digitalWrite(RADAR_EN_PIN, LOW);
   radarDetectedDebounced = false;
 }


 // 5. Video Logic (INTERRUPT)
 radarRawDetected = false;
 if (radarPowerOn) {
   radarRawDetected = (digitalRead(RADAR_GPIO_PIN) == HIGH);
   if (radarRawDetected) {
     if (radarDebounceCounter < radarDebounceThreshold) radarDebounceCounter++;
   } else {
     radarDebounceCounter = 0;
   }
   radarDetectedDebounced = (radarDebounceCounter >= radarDebounceThreshold);


   if (radarDetectedDebounced) {
     presenceConfirmed = true;
    
     if (triggersAllowed) {
       if (triggerVideo(now)) {
         shutterSentNow = true;
         bootPulseSentNow = true; // Now linked
       }
     }
   }
 } else {
   radarDetectedDebounced = false;
 }
 if (!radarPowerOn) presenceConfirmed = false;




 // 6. Photo Logic (INTERVAL)
 if (!radarPowerOn && !shutterSentNow) {
   if (photoTimerRemainingMs == 0) {
     if (triggersAllowed) {
       if (triggerPhoto(now)) {
         shutterSentNow = true;
         bootPulseSentNow = true; // Now linked
       }
     }
   }
 }


 // 7. Output
 digitalWrite(PIR_LED_PIN, pirDetected);
 digitalWrite(RADAR_LED_PIN, (radarPowerOn && radarRawDetected));
 digitalWrite(CONFIRM_LED_PIN, presenceConfirmed);


 Serial.print("PIR_Raw=");   Serial.print(pirRawValue);
 Serial.print("  PIR_V=");   Serial.print(pirVoltage, 3);
 Serial.print("  PIR_Detected="); Serial.print(pirDetected);
 Serial.print("  Radar_Powered=");   Serial.print(radarPowerOn);
 Serial.print("  Radar_Raw=");       Serial.print(radarRawDetected);
 Serial.print("  Radar_Debounced="); Serial.print(radarDetectedDebounced);
 Serial.print("  Presence_Confirmed="); Serial.print(presenceConfirmed);
  Serial.print("  BootPulse_Sent=");   Serial.print(bootPulseSentNow);
 Serial.print("  Shutter_Sent=");     Serial.print(shutterSentNow);
  Serial.print("  Trigger_Mode=");     Serial.print(lastTriggerMode);
 Serial.print("  Debounce_s=");
 Serial.print(debounceRemainingMs / 1000);


 Serial.print("  NextPhoto_s=");
 Serial.print(photoTimerRemainingMs / 1000);


 Serial.println();


 delay(100);
}



